#!/bin/bash

# Filename: _funcs.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 26/11/2017

# Copyright (C) 2017  Michael Mair-Keimberger
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Discription:
# this file provides functions and default values for scripts

#
# repo configuration
# this only applies if REPO_TO_CHECK is set to non-zero and the repo set in the
# variable exists in the _repos.sh file. Otherwise the script simply exists.
# if REPO_TO_CHECK is set to zero default values or overrides in every script
# are used.
# Values from _repos.sh are going to be exported as well and can be used in the
# scripts.
#
realdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -n "${REPO_TO_CHECK}" ]; then
	if [ -e ${realdir}/_repos.sh ]; then
		source ${realdir}/_repos.sh ${REPO_TO_CHECK}
		# exit script if the repo doesn't exist in _repos.sh
		${REPO_ERROR} && exit 1
	else
		echo "Missing _repos.sh"
		exit 1
	fi
fi

#
# globally vars - can be used everywhere (exported)
#
# enabling debuging (if available)
BUGTMPDIR="/tmp/buglists/"
DL='|'

# check and set DEBUG
[ -z "${DEBUG}" ] && DEBUG=false
[ -z "${DRYRUN}" ] && DRYRUN=false
# check and set set the PORTTREE
if [ -z "${PORTTREE}" ]; then
	if [ -d /usr/portage/metadata/ ]; then
		PORTTREE="/usr/portage/"
		export PORTTREE
	else
		exit "No portage tree set"
		exit 1
	fi
else
	if ! [ -d ${PORTTREE} ]; then
		echo "${PORTTREE} doesn't exists"
		exit 1
	fi
fi
[ -z "${SCRIPT_MODE}" ] && SCRIPT_MODE=false
[ -z "${SITEDIR}" ] && SITEDIR="${HOME}/checks-${RANDOM}/"
[ -z "${REPOCHECK}" ] && REPOCHECK=false

# Feature settings
ENABLE_GIT=false
ENABLE_MD5=false
TREE_IS_MASTER=false
[ -e "${PORTTREE}/.git" ] && ENABLE_GIT=true
[ -e "${PORTTREE}/metadata/md5-cache" ] && ENABLE_MD5=true
[ "$(cat ${PORTTREE}/profiles/repo_name)" = "gentoo" ] && TREE_IS_MASTER=true

export ENABLE_GIT ENABLE_MD5 DEBUG DL BUGTMPDIR TREE_IS_MASTER \
	SCRIPT_MODE SITEDIR REPOCHECK DRYRUN
#
# globaly vars END
#

# DRYRUN - only print vars and exit
if ${DRYRUN}; then
	echo "Repo: ${REPO}"
	echo "Porttree: ${PORTTREE}"
	echo "Enable git: ${ENABLE_GIT}"
	echo "Enable md5: ${ENABLE_MD5}"
	echo "Tree is master: ${TREE_IS_MASTER}"
	echo "Sitedir: ${SITEDIR}"
	echo "Repocheck: ${REPOCHECK}"
	echo "ScriptMode: ${SCRIPT_MODE}"
	echo "Debug: ${DEBUG}"
	echo "Whitelist: ${PT_WHITELIST}"
	exit 1
fi

_update_buglists(){
	local bug_files="UNCONFIRMED CONFIRMED IN_PROGRESS"

	mkdir -p ${BUGTMPDIR}

	if ! [ -e "${BUGTMPDIR}/full-$(date -I).txt" ]; then

		find ${BUGTMPDIR}/* -mtime +2 -exec rm -f {} \; >/dev/null 2>&1

		for file in ${bug_files}; do
			local bugfile="${BUGTMPDIR}/${file}-$(date -I).txt"
			curl -s https://bugs.gentoo.org/data/cached/buglist-${file}.html > ${bugfile}

			sed -i 's/ /_/g' ${bugfile}
			sed -i -e "1,3d; \
				$ d; \
				s|<li><a_href='||; \
				s|<div><ul>||; \
				s|'>Bug:| |; \
				s|_-_\"<em>| |; \
				s|</em>\"_status:| |; \
				s|_resolution:| |; \
				s|_severity:| |; \
				s|</a></li>||;" \
				${bugfile}

			cat ${bugfile} >> ${BUGTMPDIR}/full-$(date -I).txt
		done
	fi
}
_update_buglists

_find_package_location(){
	local rc_id=${1}
	local x
	local i
	# find pakackge location in result first
	if [ -s ${rc_id} ]; then
		# check the first 10 entries
		for x in $(head -n10 ${rc_id}); do
			for i in $(seq 1 $(expr $(echo ${x} |grep -o '|' | wc -l) + 1)); do
				if [ -d "${PORTTREE}/$(echo ${x}| cut -d'|' -f${i})" ]; then
					echo ${i}
					return 0
				fi
			done
		done
	fi
}

# retruns true if bug is found, false if not
get_bugs_bool(){
	local value="${1}"

	if $(grep -q ${value} ${BUGTMPDIR}/full-$(date -I).txt); then
		return 0
	else
		return 1
	fi
}

# returns the amout of bugs found
get_bugs_count(){
	local value="${1}"
	local return="$(grep ${value} ${BUGTMPDIR}/full-$(date -I).txt | cut -d' ' -f2 | wc -l)"

	if [ -n "${return}" ]; then
		printf "%03d\n" "${return}"
	else
		echo "000"
	fi
}

# returns a list of Bug Numbers for a given ebuild
get_bugs(){
	local value="${1}"
	local return="$(grep ${value} ${BUGTMPDIR}/full-$(date -I).txt | cut -d' ' -f2 | tr '\n' ':')"

	[ -n "${return}" ] && echo "${return::-1}"
}

# returns a list of Bugs for a given ebuild. Also includes Bugtitle
get_bugs_full(){
	local value="${1}"
	local return="$(grep ${value} ${BUGTMPDIR}/full-$(date -I).txt | cut -d' ' -f1,3)"

	[ -n "${return}" ] && echo "${return}"
}

count_ebuilds(){
	local epath="${1}"
	local return="$(find ${epath} -mindepth 1 -maxdepth 1 -type f -name "*.ebuild" | wc -l)"

	[ -n "${return}" ] && echo "${return}"
}

# function to sort the output, takes one argument (optional)
# the argument is the column number to sort after
sort_result_v2(){
	local column="${1}"
	local rc_id

	for rc_id in ${RUNNING_CHECKS[@]}; do
		# check input
		if [ -d ${rc_id} ]; then
			if [ -e "${rc_id}/full.txt" ]; then
				rc_id="${rc_id}/full.txt"
			else
				continue
			fi
		elif ! [ -e ${rc_id} ]; then
			continue
		fi

		if [ -z "${column}" ]; then
			sort -o ${rc_id} ${rc_id}
		else
			sort -t"${DL}" -k${column} -o${rc_id} ${rc_id}
		fi
	done
}

sort_result_v3(){
	local column="${1}"
	local rc_id

	for rc_id in ${RUNNING_CHECKS[@]}; do
		# check input
		if [ -d ${rc_id} ]; then
			if [ -e "${rc_id}/full.txt" ]; then
				rc_id="${rc_id}/full.txt"
			else
				continue
			fi
		elif ! [ -e ${rc_id} ]; then
			continue
		fi

		# find pakackge location in result
		if [ -z "${column}" ]; then
			local pak_loc="$(_find_package_location "${rc_id}")"
			[ -z "${pak_loc}" ] && column=1 || column=${pak_loc}
		fi

		sort -t"${DL}" -k${column} -o${rc_id} ${rc_id}
	done
}

sort_result_v4(){
	local column="${1}"
	local single_rc="${2}"
	local rc_id

	# find pakackge location in result
	_file_sort(){
		if [ -z "${column}" ]; then
			local pak_loc="$(_find_package_location "${rc_id}")"
			[ -z "${pak_loc}" ] && column=1 || column=${pak_loc}
		fi

		sort -t"${DL}" -k${column} -o${rc_id} ${rc_id}
	}

	# check input
	_file_check(){
		if [ -d ${rc_id} ]; then
			if [ -e "${rc_id}/full.txt" ]; then
				rc_id="${rc_id}/full.txt"
				return 0
			else
				return 1
			fi
		elif ! [ -e ${rc_id} ]; then
			return 1
		else
			return 0
		fi
	}

	if [ -z "${single_rc}" ]; then
		for rc_id in ${RUNNING_CHECKS[@]}; do
			_file_check && _file_sort
		done
	else
		rc_id="${RUNNING_CHECKS[${single_rc}]}"
		_file_check && _file_sort
	fi
}

count_keywords(){
	local ebuild1="${1}"
	local ebuild2="${2}"
	local category="${3}"
	local package="${4}"

	local a b

	if ${ENABLE_MD5}; then
		a="$(grep ^KEYWORDS ${PORTTREE}/metadata/md5-cache/${category}/${ebuild1})"
		b="$(grep ^KEYWORDS ${PORTTREE}/metadata/md5-cache/${category}/${ebuild2})"
		if [ $(echo ${a}|wc -w) -eq $(echo ${b}|wc -w) ]; then
			return 0
		else
			return 1
		fi
	else
		a="$(grep ^KEYWORDS ${PORTTREE}/${category}/${package}/${ebuild1}.ebuild | sed -e 's/^[ \t]*//')"
		b="$(grep ^KEYWORDS ${PORTTREE}/${category}/${package}/${ebuild2}.ebuild | sed -e 's/^[ \t]*//')"
		if [ $(echo ${a}|wc -w) -eq $(echo ${b}|wc -w) ]; then
			return 0
		else
			return 1
		fi
	fi
}

compare_keywords(){
	local ebuild1="${1}"
	local ebuild2="${2}"
	local category="${3}"
	local package="${4}"

	local a b

	if ${ENABLE_MD5}; then
		a="$(grep ^KEYWORDS ${PORTTREE}/metadata/md5-cache/${category}/${ebuild1})"
		b="$(grep ^KEYWORDS ${PORTTREE}/metadata/md5-cache/${category}/${ebuild2})"
		if [ "${a}" = "${b}" ]; then
			return 0
		else
			return 1
		fi
	else
		a="$(grep ^KEYWORDS ${PORTTREE}/${category}/${package}/${ebuild1}.ebuild | sed -e 's/^[ \t]*//')"
		b="$(grep ^KEYWORDS ${PORTTREE}/${category}/${package}/${ebuild2}.ebuild | sed -e 's/^[ \t]*//')"
		if [ "${a}" = "${b}" ]; then
			return 0
		else
			return 1
		fi
	fi
}

# function which sorts a list by it's maintainer
gen_sort_main_v3(){
	if [ -z "${1}" ]; then
		local check_files=( "${RUNNING_CHECKS[@]}" )
	else
		local check_files=( "${1}" )
	fi

	local main
	local rc_id

	for rc_id in ${check_files[@]}; do
		if [ -d ${rc_id} ]; then
			if [ -e "${rc_id}/full.txt" ]; then
				rc_id="${rc_id}/full.txt"
			else
				continue
			fi
		elif ! [ -e ${rc_id} ]; then
			continue
		fi

		# find pakackge location in result first
		local pak_loc="$(_find_package_location "${rc_id}")"
		if [ -s ${rc_id} ]; then
			# check the first 10 entries
			for x in $(head -n10 ${rc_id}); do
				local pak="$(echo ${x}|cut -d'|' -f${pak_loc})"
				local pak_main="$(get_main_min ${pak})"
				for i in $(seq 1 $(expr $(echo ${x} |grep -o '|' | wc -l) + 1)); do
					if [ "$(echo ${x}|cut -d'|' -f${i})" = "${pak_main}" ]; then
						local main_loc=${i}
						break 2
					fi
				done
			done
		fi
		# generate maintainer sortings only if we find the location
		if [ -n "${main_loc}" ]; then
			mkdir -p ${rc_id%/*}/sort-by-maintainer
			for main in $(cat ${rc_id} |cut -d "${DL}" -f${main_loc}|tr ':' '\n'| grep -v "^[[:space:]]*$"|sort -u); do
				grep "${main}" ${rc_id} > ${rc_id%/*}/sort-by-maintainer/"$(echo ${main}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
			done
		fi
	done
}

# function which sorts a list by it's package
gen_sort_pak_v3() {
	if [ -z "${1}" ]; then
		local check_files=( "${RUNNING_CHECKS[@]}" )
	else
		local check_files=( "${1}" )
	fi

	local pack
	local rc_id

	for rc_id in ${check_files[@]}; do
		# check input
		if [ -d ${rc_id} ]; then
			if [ -e "${rc_id}/full.txt" ]; then
				rc_id="${rc_id}/full.txt"
			else
				continue
			fi
		elif ! [ -e ${rc_id} ]; then
			continue
		fi

		# find pakackge location in result
		pak_loc="$(_find_package_location "${rc_id}")"
		# only create package sorting if we found package location
		if [ -n "${pak_loc}" ]; then
			local f_packages="$(cat ${rc_id}| cut -d "${DL}" -f${pak_loc} |sort -u)"
			for pack in ${f_packages}; do
				local f_cat="$(echo ${pack}|cut -d'/' -f1)"
				local f_pak="$(echo ${pack}|cut -d'/' -f2)"
				mkdir -p ${rc_id%/*}/sort-by-package/${f_cat}
				grep "\<${pack}\>" ${rc_id} > ${rc_id%/*}/sort-by-package/${f_cat}/${f_pak}.txt
			done
		fi
	done
}

usage() {
	echo "You need at least one argument:"
	echo
	echo "${0} full"
	echo -e "\tCheck against the full tree"
	echo "${0} app-admin"
	echo -e "\tCheck against the category app-admin"
	echo "${0} app-admin/diradm"
	echo -e "\tCheck against the package app-admin/diradm"
}

depth_set_v2() {
	arg="${1}"

	_default_full_search() {
		searchp=( $(find ${PORTTREE} -mindepth 1 -maxdepth 1 \
			-type d -regextype sed -regex "./*[a-z0-9].*-[a-z0-9].*" -printf '%P\n') )
		# virtual wouldn't be included by the find command, adding it manually if
		# it's present
		[ -e ${PORTTREE}/virtual ] && searchp+=( "virtual" )
		# full provides only categories so we need maxd=2 and mind=2
		# setting both vars to 1 because the find command adds 1 anyway
		MAXD=1
		MIND=1
		find_func
		gen_results
	}


	if [ -z "${arg}" ]; then
		usage
		exit 1
	else
		# test if user provided input exist
		if [ -d "${PORTTREE}/${arg}" ]; then
			MAXD=0
			MIND=0
			# case if user provides only category
			# if there is a '/', everything after need to be empty
			# if there are no '/', both checks (arg%%/* and arg##*/) print the same
			if [ -z "${arg##*/}" ] || [ "${arg%%/*}" = "${arg##*/}" ]; then
				MAXD=1
				MIND=1
			fi
			searchp=( ${arg} )
			find_func
			gen_results
		elif [ "${arg}" = "full" ]; then
			_default_full_search
		elif [ "${arg}" = "diff" ]; then

			TODAYCHECKS="${HASHTREE}/results/results-$(date -I).log"

			if ! [ -f "${TODAYCHECKS}" ]; then
				echo "No diff file found"
				exit 1
			fi
			searchp=( $(sed -e 's/^.//' ${TODAYCHECKS} | sort -u) )

			# diff provides categories/package so we need maxd=1 and mind=1
			# setting both vars to 0 because the find command adds 1 anyway
			MAXD=0
			MIND=0

			# if /tmp/${SCRIPT_NAME} exist run in normal mode
			# this way it's possible to override the diff mode
			# this is usefull when the script got updates which should run
			# on the whole tree
			if ! [ -e "/tmp/${SCRIPT_NAME}" ]; then
				# only run diff mode if todaychecks exist and doesn't have zero bytes
				if [ -s ${TODAYCHECKS} ]; then
					# special case for repomancheck
					# copying old sort-by-packages files are only important for repomancheck
					# because these files aren't generated via gen_sort_pak (like on other scripts)
					if ${REPOCHECK}; then
						cp -r ${SITEDIR}/${SCRIPT_TYPE}/${RUNNING_CHECKS[0]/${WORKDIR}/}/sort-by-package ${RUNNING_CHECKS[0]}/
					fi

					# we need to copy all existing results first and remove packages which
					# were changed (listed in TODAYCHECKS). If no results file exists, do
					# nothing - the script would create a new one anyway
					for oldfull in ${RUNNING_CHECKS[@]}; do
						# SCRIPT_TYPE = checks or stats
						# first set the full.txt path from the old log
						OLDLOG="${SITEDIR}/${SCRIPT_TYPE}/${oldfull/${WORKDIR}/}/full.txt"
						# check if the oldlog exist (don't have to be)
						if [ -e ${OLDLOG} ]; then
							# copy old result file to workdir and filter the result
							cp ${OLDLOG} ${oldfull}/
							for cpak in $(cat ${TODAYCHECKS}); do
								# the substring replacement is important (replaces '/' to '\/'), otherwise the sed command
								# will fail because '/' aren't escapted. also remove first slash
								pakcat="${cpak:1}"
								sed -i "/${pakcat//\//\\/}${DL}/d" ${oldfull}/full.txt
								# like before, only important for repomancheck
								if ${REPOCHECK}; then
									rm -rf ${RUNNING_CHECKS[0]}/sort-by-package/${cpak}.txt
								fi
							done
						fi
					done

					# first: remove packages which doesn't exist anymore
					diff_rm_dropped_paks_v3
					# second: run the script only on the changed packages
					find_func
					# third: generate results and copy to SITEDIR
					gen_results

				else
					# if ${TODAYCHECKS} doesn't exist or has zero bytes, do nothing, except in
					# this case, update old results (git_age or bugs information)
					# this is a special case for scripts who provide gitage or bugs information:
					# following function can be configured in each script in order to
					# update git_age or bug information (or anything else)
					# in contrast to gen_results, this function would be also called if
					# nothing changed since last run (see below)
					local x=( )
					local i
					for i in $(seq 0 $(expr ${#RUNNING_CHECKS[@]} - 1)); do
						x+=( "${SITEDIR}/${SCRIPT_TYPE}/${RUNNING_CHECKS[${i}]/${WORKDIR}/}" )
					done
					local RUNNING_CHECKS=( ${x[@]} )
					upd_results
				fi
			else
				# if override is enabled, do a normal full search.
				_default_full_search
			fi
		else
			echo "${PORTTREE}/${arg}: Path not found"
			exit 1
		fi
	fi
}

# this function get the age (file creation) of a particular ebuild file
# depends on ${ENABLE_GIT}
# returns the age in days
get_age() {
	local file=${1}
	local date_today="$(date '+%s' -d today)"

	if ${ENABLE_GIT}; then
		fileage="$(expr \( "${date_today}" - \
			"$(date '+%s' -d $(git -C ${PORTTREE} log --format="format:%ci" --name-only --diff-filter=A ${PORTTREE}/${file} \
			| head -1|cut -d' ' -f1) 2>/dev/null )" \) / 86400 2>/dev/null)"
		printf "%05d\n" "${fileage}"
	else
		echo "-----"
	fi
}

get_age_v2() {
	local filedate="${1}"
	local date_today="$(date '+%s' -d today)"

	if ${ENABLE_GIT}; then
		if [ -n "${filedate}" ]; then
			fileage="$(expr \( "${date_today}" - "$(date '+%s' -d ${filedate})" \) / 86400 2>/dev/null)"
			printf "%05d\n" "${fileage}"
		else
			echo "-----"
		fi
	else
		echo "-----"
	fi
}

get_age_v3() {
	local filedate="${1}"
	local date_today="$(date '+%s' -d today)"

	if ${ENABLE_GIT}; then
		if [ -n "${filedate}" ]; then
			fileage="$(expr \( "${date_today}" - "${filedate}" \) / 86400 2>/dev/null)"
			printf "%05d\n" "${fileage}"
		else
			echo "-----"
		fi
	else
		echo "-----"
	fi
}

date_update(){
	local datevalue="${1}"
	local timediff="${2}"
	if [ "${datevalue}" = "-----" ]; then
		echo "-----"
	elif [ ${#datevalue} -eq 10 ]; then
		echo "$(get_age_v3 ${datevalue})"
	else
		if [ -n "${timediff}" ]; then
			printf "%05d\n" "$(expr ${datevalue} + ${timediff})"
		fi
	fi
}

# like get_age but returns the file creation date (or file removal date)
get_age_date() {
	local file=${1}

	if ${ENABLE_GIT}; then
		filedate="$(git -C ${PORTTREE} log --format="format:%cs" --diff-filter=A -- ${PORTTREE}/${file} | tail -1)"
		echo "${filedate}"
	else
		echo ""
	fi
}

get_git_age() {
	local file="${1}"
	local time_format="${2}"
	local diff_filter="${3}"
	local position="${4}"

	if ${ENABLE_GIT}; then
		case "${position}" in
			first)
				filedate="$(git -C ${PORTTREE} log --format="format:%${time_format}" --diff-filter=${diff_filter} -- ${PORTTREE}/${file} | tail -1)"
			;;
			last)
				filedate="$(git -C ${PORTTREE} log --format="format:%${time_format}" --diff-filter=${diff_filter} -- ${PORTTREE}/${file} | head -1)"
			;;
			all)
				filedate="$(git -C ${PORTTREE} log --format="format:%${time_format}" --diff-filter=${diff_filter} -- ${PORTTREE}/${file})"
			;;
		esac
		if [ "${diff_filter}" = "M" ] && [ -z "${filedate}" ]; then
			filedate="-----"
		fi
		echo "${filedate}"
	else
		echo "-----"
	fi
}

get_time_diff() {
	local running_check="${1}"
	if ${ENABLE_GIT}; then
		if [ -e "${running_check}" ]; then
			local list_age="$(grep "generated" ${running_check} | grep -o 20........)"
			local date_today="$(date '+%s' -d today)"
			if [ -n "${list_age}" ]; then
				local time_diff="$(expr \( "${date_today}" - "$(date '+%s' -d ${list_age})" \) / 86400 2>/dev/null)"
				# since all scripts run daily this always should return 1
				echo "${time_diff}"
			else
				echo "0"
			fi
		else
			echo "0"
		fi
	else
		echo "0"
	fi
}

# return the EAPI of a given ebuild
get_eapi() {
	local file=${1}
	local eapi="$(grep ^EAPI ${file}|cut -d' ' -f1|grep -Eo '[0-9]')"
	[ -n "${eapi}" ] && echo ${eapi} || echo "0"
}

# list all eapi versions for a given package only showing used EAPIs. the list
# looks like following:
# 7(1):6(2):5(1)
get_eapi_pak(){
	local package=${1}
	local eapi_list=( $(grep EAPI ${package}/*.ebuild 2> /dev/null | cut -d'=' -f2 | cut -d' ' -f1 | grep -Eo '[0-9]' | sort | uniq -c | sed 's/^\s*//'|tr ' ' '_') )

	local x
	local return_string=( )
	for x in ${eapi_list[@]}; do
		local eapi=$(echo ${x}|rev|cut -d'_' -f1)
		local count=$(echo ${x}|cut -d'_' -f1)
		return_string+=( "${eapi}(${count})" )
	done

	IFS=$'\n' return_string=($(sort -r <<<"${return_string[*]}"))

	echo "$(echo ${return_string[@]}|tr ' ' ':')"
}

# list all eapi's for a given package. the list looks like following:
# EAPI Version:		0 1 2 3 4 5 6 7			(not outputed)
# EAPI Count:			0:0:0:0:0:1:2:0
get_eapi_list(){
	local package=${1}
	local eapi_list=( )
	for eapi in $(seq 0 7); do
		eapi_list+=( $(grep -h EAPI ${package}/*.ebuild |cut -d' ' -f1 | grep ${eapi}| wc -l) )
	done
	echo "$(echo ${eapi_list[@]}|tr ' ' ':')"
}

# return all eclasses inherited by a ebuild
# the list is generated from the md5-cache, which means it also includes
# eclasses inherited by other eclasses
get_eclasses_real() {
	local md5_file=${1}

	if ${ENABLE_MD5}; then
		local real_eclasses=( $(grep '_eclasses_=' ${md5_file}|cut -c12-|sed 's/\(\t[^\t]*\)\t/\1\n/g'|cut -d$'\t' -f1) )
		echo ${real_eclasses[@]}|tr ' ' ':'
	fi
}

# simply return 0 or 1 (true or false) if a given eclass is used by
# a given ebuild file
check_eclasses_usage() {
	local real_file=${1}
	local eclass_name=${2}

	local eclass_var="$(grep ^inherit ${real_file} |grep -o $\{.*\}|sed 's/${\(.*\)}/\1/')"
	if [ -z "${eclass_var}" ]; then
		search_pattern="inherit"
	else
		search_pattern="${eclass_var}\=\|inherit"
	fi

	if $(sed -e :a -e '/\\$/N; s/\\\n//; ta' ${real_file} | grep "${search_pattern}" | grep -q "\"${eclass_var}\"\\| ${eclass_name} \\|${eclass_name} \\| ${eclass_name}\$"); then
		return 0
	else
		return 1
	fi
}

# list all eclasses used by a given ebuild file
# returns the list as followed:
#  eclass1:eclass2
get_eclasses_file() {
	local md5_file=${1}
	local real_file=${2}

	if ${ENABLE_MD5}; then
		local real_eclasses=( $(grep '_eclasses_=' ${md5_file}|cut -c12-|sed 's/\(\t[^\t]*\)\t/\1\n/g'|cut -d$'\t' -f1) )
		local file_eclasses=( )
		local eclass_var="$(grep ^inherit ${real_file} |grep -o $\{.*\}|sed 's/${\(.*\)}/\1/')"
		if [ -n "${eclass_var}" ]; then
			eclass_in_var="$(grep -o "${eclass_var}=.*" ${real_file} | tail -n1 | tr -d '"' | cut -d '=' -f2 | cut -d ' ' -f1 )"
			if $(echo ${real_eclasses[@]}|grep -q ${eclass_in_var}); then
				file_eclasses+=( "${eclass_in_var}" )
			fi
		fi
		for ecl in ${real_eclasses[@]}; do
			if $(sed -e :a -e '/\\$/N; s/\\\n//; ta' ${real_file} | grep inherit | grep -q " ${ecl} \\| ${ecl}\$"); then
				file_eclasses+=( ${ecl} )
			fi
		done
		echo ${file_eclasses[@]}|tr ' ' ':'
	fi
}

# this function simply copies all results from the WORKDIR to
# the SITEDIR
copy_checks() {
	local type=${1}

	if ! [ -e ${SITEDIR}/${type}/ ]; then
		mkdir -p ${SITEDIR}/${type}
		cp -r ${RUNNING_CHECKS[@]} ${SITEDIR}/${type}/
	else
		for lcheck in ${RUNNING_CHECKS[@]}; do
			rm -rf ${SITEDIR}/${type}/${lcheck##*/}
		done
		cp -r ${RUNNING_CHECKS[@]} ${SITEDIR}/${type}/
	fi
}

# remove dropped packages, needed for diff mode
diff_rm_dropped_paks_v3(){
	local c
	local p
	local p_list=( )

	# only run if we get a package location
	for c in ${RUNNING_CHECKS[@]}; do
		if [ -s ${c}/full.txt ]; then

			# check the first 10 entries
			for x in $(head -n10 ${c}/full.txt); do
				for i in $(seq 1 $(expr $(echo ${x} |grep -o '|' | wc -l) + 1)); do
					if [ -d "${PORTTREE}/$(echo ${x}| cut -d'|' -f${i})" ]; then
						local l=${i}
						break 2
					fi
				done
			done

			if [ -n "${l}" ]; then
				p_list=( $(cut -d'|' -f${l} ${c}/full.txt) )
				for p in ${p_list[@]}; do
					if ! [ -d ${PORTTREE}/${p} ]; then
						sed -i "/${p//\//\\/}${DL}/d" ${c}/full.txt
						if [ -d ${c}/sort-by-package ]; then
							rm -rf ${c}/sort-by-package/${p}.txt
						fi
					fi
				done
			fi
		fi
	done
}

# dummy function which can be used by script individually
upd_results() {
	return 0
}

get_main_min(){
	if [ -e "${PORTTREE}/${1}/metadata.xml" ]; then
		local maint=`/usr/bin/python3 - "${1}" <<END
import xml.etree.ElementTree
import sys
pack = str(sys.argv[1])
projxml = "${PORTTREE}" + pack + "/metadata.xml"
e = xml.etree.ElementTree.parse(projxml).getroot()
c = ""
for x in e.iterfind("./maintainer/email"):
	c+=(x.text+':')
print(c)
END`
	fi
	maint=${maint// /_}
	if [ -z "${maint}" ]; then
		echo "maintainer-needed@gentoo.org"
	else
		echo ${maint::-1}
	fi
}

# python script to get permutations
get_perm(){
	local ret=`/usr/bin/python3 - "${1}" <<END
import itertools
import sys
list=sys.argv[1].split(' ')
for perm in itertools.permutations(list):
	string= ','.join(perm)
	print(string)
END`
	echo ${ret// /_}
}

export -f get_main_min get_perm get_age get_bugs get_eapi get_eclasses_file \
	get_eclasses_real check_eclasses_usage get_eapi_pak get_eapi_list \
	count_keywords compare_keywords get_bugs_bool get_bugs_count \
	get_age_v2 get_age_date get_git_age get_age_v3 date_update sort_result_v3 \
	get_time_diff sort_result_v4 count_ebuilds


