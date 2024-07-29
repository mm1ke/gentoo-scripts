#!/bin/bash

# Filename: _funcs.sh
# Autor: Michael Mair-Keimberger (mmk AT levelnine DOT at)
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
# globally vars - can be used everywhere (exported)
#
BUGTMPDIR="/tmp/buglists/"
DL='|'
export FDL=4

# settings which shouldn't be in _funcs.sh
# like api keys
if [ -e ~/.config/checks.conf ]; then
	source ~/.config/checks.conf
fi

# check and set DEBUG
if [ -z "${DEBUG}" ]; then
	export DEBUG=false
	export DEBUGLEVEL=0
else
	if ${DEBUG}; then
		if [ -z "${DEBUGLEVEL}" ]; then
			# set debuglevel to 1 if nothing is set
			export DEBUGLEVEL=1
		fi
	else
		export DEBUGLEVEL=0
	fi
fi
[ -z "${DRYRUN}" ] && DRYRUN=false
# check and set set the REPOTREE
if [ -z "${REPOTREE}" ]; then
	if [ -d /var/db/repos/gentoo/metadata/ ]; then
		REPOTREE="/var/db/repos/gentoo/"
		export REPOTREE
	else
		echo "No portage tree set"
		exit 1
	fi
else
	if ! [ -d ${REPOTREE} ]; then
		echo "${REPOTREE} doesn't exists"
		exit 1
	fi
fi
[ -z "${FILERESULTS}" ] && FILERESULTS=false
[ -z "${RESULTSDIR}" ] && RESULTSDIR="${HOME}/checks-${RANDOM}/"
[ -z "${REPOCHECK}" ] && REPOCHECK=false
# in order to make check certain things for overlays we need to know the were
# the main gentoo tree is because informations depend on them
if [ -n "${GTREE}" ]; then
	if ! [ "$(cat ${GTREE}/profiles/repo_name)" = "gentoo" ]; then
		GTREE=""
	fi
fi

# Feature settings
ENABLE_GIT=false
ENABLE_MD5=false
ENABLE_ABUSECHECK=false
TREE_IS_MASTER=false
[ -e "${REPOTREE}/.git" ] && ENABLE_GIT=true
[ -e "${REPOTREE}/metadata/md5-cache" ] && ENABLE_MD5=true
[ "$(cat ${REPOTREE}/profiles/repo_name)" = "gentoo" ] && TREE_IS_MASTER=true
[ -n "${ABUSEAPIKEY}" ] && ENABLE_ABUSECHECK=true

export ENABLE_GIT ENABLE_MD5 ENABLE_ABUSECHECK DEBUG DL BUGTMPDIR TREE_IS_MASTER \
	FILERESULTS RESULTSDIR REPOCHECK DRYRUN GTREE
#
# globaly vars END
#

# DRYRUN - only print vars and exit
if ${DRYRUN}; then
	echo _funcs
	echo "Repo: ${REPO}"
	echo "Porttree: ${REPOTREE}"
	echo "Gentoo tree: ${GTREE} (optional)"
	echo "Enable git: ${ENABLE_GIT}"
	echo "Enable md5: ${ENABLE_MD5}"
	echo "Tree is master: ${TREE_IS_MASTER}"
	echo "Sitedir: ${RESULTSDIR}"
	echo "Repocheck: ${REPOCHECK}"
	echo "ScriptMode: ${FILERESULTS}"
	echo "Debug: ${DEBUG}"
	echo "Whitelist: ${PT_WHITELIST}"
	exit 1
fi

### LOCAL FUNCTIONS ###
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
				s|</a></li>||; \
				s|&gt;||; \
				s|&lt;||;" \
				${bugfile}

			cat ${bugfile} >> ${BUGTMPDIR}/full-$(date -I).txt
		done
	fi
}
_update_buglists

_find_package_location(){
	[ ${DEBUGLEVEL} -ge 2 ] && echo ">>> calling ${FUNCNAME[0]}" | (debug_output)
	local rc_id=${1}
	local x i
	# find pakackge location in result first
	if [ -s "${rc_id}" ]; then
		# check the first 10 entries
		for x in $(head -n10 ${rc_id}); do
			for i in $(seq 1 $(expr $(echo ${x} |grep -o '|' | wc -l) + 1)); do
				if [ -d "${REPOTREE}/$(echo ${x}| cut -d'|' -f${i})" ]; then
					[ ${DEBUGLEVEL} -ge ${FDL} ] && echo " ${FUNCNAME[0]}: found location: ${i}" | (debug_output)
					echo ${i}
					return 0
				fi
			done
		done
	fi
}
### LOCAL FUNCTIONS END ###

# simple usage info of how to use these scripts
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

# dummy function which can be used by script individually
upd_results() {
	return 0
}

# used for debug output, either into a file or directly to stderr
debug_output() {
	while IFS='' read -r line; do
		if [ -n "${DEBUGFILE}" ]; then
			echo "$(date +%F-%H:%M:%S) ${0##*/}: ${line}" >> ${DEBUGFILE}
		else
			>&2 echo "$(date +%F-%H:%M:%S) ${0##*/}: ${line}"
		fi
	done
}

depth_set_v4() {
	[ ${DEBUGLEVEL} -ge 1 ] && echo ">>> calling ${FUNCNAME[0]}" | (debug_output)
	arg="${1}"

	_default_full_search() {
		SEARCHPATTERN=( $(find ${REPOTREE} -mindepth 1 -maxdepth 1 \
			-type d -regextype sed -regex "./*[a-z0-9].*-[a-z0-9].*" -printf '%P\n') )
		# virtual wouldn't be included by the find command, adding it manually if
		# it's present
		[[ -e ${REPOTREE}/virtual ]] && SEARCHPATTERN+=( "virtual" )
		# full provides only categories so we need maxd=2 and mind=2
		# setting both vars to 1 because the find command adds 1 anyway
		MAXD=1
		MIND=1
		find_func
	}

	if [[ -z "${arg}" ]]; then
		usage
		exit 1
	else
		# test if user provided input exist
		if [[ -d "${REPOTREE}/${arg}" ]]; then
			MAXD=0
			MIND=0
			# case if user provides only category
			# if there is a '/', everything after need to be empty
			# if there are no '/', both checks (arg%%/* and arg##*/) print the same
			if [[ -z "${arg##*/}" ]] || [[ "${arg%%/*}" = "${arg##*/}" ]]; then
				MAXD=1
				MIND=1
			fi
			SEARCHPATTERN=( ${arg} )
			find_func
		elif [[ "${arg}" = "full" ]]; then
			_default_full_search
		elif [[ "${arg}" = "diff" ]]; then

			local changed_packages="${GITINFO}/${REPO}-catpak.log"

			if ! [[ -f "${changed_packages}" ]]; then
				echo "No diff file found"
				exit 1
			fi
			SEARCHPATTERN=( $(cat ${changed_packages} | sort -u) )

			# diff provides categories/package so we need maxd=1 and mind=1
			# setting both vars to 0 because the find command adds 1 anyway
			MAXD=0
			MIND=0

			# only run diff mode if todaychecks exist and doesn't have zero bytes
			if [[ -s ${changed_packages} ]]; then
				# we need to copy all existing results first and remove packages which
				# were changed (listed in ${changed_packages}). If no results file exists, do
				# nothing - the script would create a new one anyway
				local oldfull oldlog
				for oldfull in ${RUNNING_CHECKS[@]}; do
					# SCRIPT_TYPE = checks or stats
					# first set the full.txt path from the old log
					local oldlog="${RESULTSDIR}/${SCRIPT_TYPE}/${oldfull/${WORKDIR}/}/full.txt"
					# check if the oldlog exist (don't have to be)
					if [[ -e ${oldlog} ]]; then
						# copy old result file to workdir and filter the result
						cp ${oldlog} ${oldfull}/
						cp ${oldlog} ${oldfull}/full-yesterday.txt
						for cpak in $(cat ${changed_packages}); do
							# the substring replacement is important (replaces '/' to '\/'), otherwise the sed command
							# will fail because '/' aren't escapted. also remove first slash
							pakcat="${cpak:1}"
							sed -i "/${pakcat//\//\\/}${DL}/d" ${oldfull}/full.txt
						done
					fi
				done

				# first: remove packages which doesn't exist anymore
				diff_rm_dropped_paks_v3
				# second: run the script only on the changed packages
				find_func

			else
				# if ${changed_packages} has zero bytes, do nothing, except in
				# this case, update old results (git_age or bugs information)
				# this is a special case for scripts who provide gitage or bugs information
				# following function can be configured in each script in order to
				# update git_age or bug information (or anything else)
				# in contrast to gen_results, this function would be also called if
				# nothing changed since last run
				upd_results
			fi
		else
			echo "${REPOTREE}/${arg}: Path not found"
			exit 1
		fi
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

# returns a list of Bugs for a given ebuild. Also includes Bugtitle
get_bugs_full(){
	local value="${1}"
	local return="$(grep ${value} ${BUGTMPDIR}/full-$(date -I).txt | cut -d' ' -f1,3)"

	[ -n "${return}" ] && echo "${return}"
}

# returns a list of possible licenses used by a certain ebuild. (not
# taking contional licenses into account
# list looks like: GPL-2:BSD
get_licenses(){
	local rel_ebuild="${1}"
	local eb_path="${REPOTREE}/metadata/md5-cache/${rel_ebuild}"
	local eb_lics=( $(grep ^LICENSE ${eb_path} |cut -d'=' -f2 | tr ' ' '\n'| awk 'length!=1' | sed -e '/\?$/d' -e '/|$/d' | sort -u) )
	echo ${eb_lics[@]}|tr ' ' ':'
}

# returns a list of keywords set for a certain ebuild
# list looks like: amd64:~x86
get_keywords(){
	local rel_ebuild="${1}"
	local eb_path="${REPOTREE}/metadata/md5-cache/${rel_ebuild}"
	local eb_keywords=( $(grep ^KEYWORDS ${eb_path} |cut -d'=' -f2 | tr ' ' '\n') )
	echo ${eb_keywords[@]}|tr ' ' ':'
}
get_keywords_v2(){
	local rel_ebuild="${1}"
	local eb_path="${REPOTREE}/metadata/md5-cache/${rel_ebuild}"
	local eb_keywords=( $(grep ^KEYWORDS ${eb_path} |cut -d'=' -f2 | tr ' ' '\n') )
	if [[ -z "${eb_keywords}" ]]; then
		echo "none"
	else
		echo ${eb_keywords[@]}|tr ' ' ':'
	fi
}

# returns all packages set in [R,B]DEPEND, not taking contional dependencies or
# versions into account
# list looks like: dev-lang/go:app-admin/salt
get_depend(){
	[ ${DEBUGLEVEL} -ge ${FDL} ] && echo ">>> get_depend: got ${1}" | (debug_output)
	local ebuild="${1}"

	local cat="$(echo ${ebuild}|cut -d'/' -f1)"
	local pak="$(echo ${ebuild}|cut -d'/' -f2)"
	local eb="$(echo ${ebuild}|cut -d'/' -f3)"

	local md5_file="${REPOTREE}/metadata/md5-cache/${cat}/${eb}"
	local real_file="${REPOTREE}/${ebuild}.ebuild"

	if $(grep -q ^.DEPEND ${md5_file}); then
		local dependencies=( $(grep ^.DEPEND ${md5_file}|grep -oE "[a-zA-Z0-9-]{3,30}/[+a-zA-Z_0-9-]{2,80}"|sed 's/-[0-9].*//g'|sort -u) )
		local d
		local real_dep=( )
		for d in ${dependencies[@]}; do
			if $(grep -q "${d}" "${real_file}"); then
				if [ -d "${REPOTREE}/${d}" ]; then
					real_dep+=( "${d}" )
				else
					[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "  W ${ebuild}: ${d} - doesn't exist in portage" | (debug_output)
				fi
			else
				[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "  W ${ebuild}: ${d} - doesn't exist in ebuild" | (debug_output)
			fi
		done
	else
		real_dep=""
	fi

	[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "<<< get_depend: return $(echo ${real_dep[@]}|tr ' ' ':')" | (debug_output)
	echo ${real_dep[@]}|tr ' ' ':'
}

get_file_status_detailed(){
	local uri="${1}"
	# sort out false positives
	local _code="Remote file exists|403 Forbidden|405 Method Not Allowed"

	if $(timeout 15 wget -T 10 --no-check-certificate -S --spider ${uri} 2>&1 | grep -q -E "${_code}" ); then
		return 1
	else
		return 0
	fi
}

# return the http code of a given homepage
get_site_status(){
	local hp="${1}"
	local code="$(curl -o /dev/null --silent --max-time 20 --head --write-out '%{http_code}\n' ${hp})"
	echo "${code}"
}

# return the site rating of a given homepage
get_site_rating(){
	# ABUSEAPIKEY comes from checks.conf
	local hpip="${1}"
	local abuselink="https://api.abuseipdb.com/api/v2/check"
	local rating="$(curl -s -G ${abuselink} \
		--data-urlencode "ipAddress=${hpip}" \
		-d maxAgeInDays=90 \
		-d verbose \
		-H "Key: ${ABUSEAPIKEY}" \
		-H "Accept: application/json" \
		| jq '.[] | .abuseConfidenceScore')"
	echo "${rating}"
	}

check_mask(){
	local ebuild="${1}"
	if [ -e ${REPOTREE}/profiles/package.mask ]; then
		if $(grep -q ${ebuild} ${REPOTREE}/profiles/package.mask); then
			return 0
		else
			return 1
		fi
	else
		return 1
	fi
}

# function to sort the output, takes one argument (optional)
# the argument is the column number to sort after
sort_result_v4(){
	local fixed_column="${1}"
	local single_rc="${2}"
	local rc_id

	# find pakackge location in result
	_file_sort(){
		local column=""
		[ -n "${fixed_column}" ] && column="${fixed_column}"
		[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "sort_result_v4: sorting ${rc_id}" | (debug_output)
		if [ -z "${column}" ]; then
			local pak_loc="$(_find_package_location "${rc_id}")"
			[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "sort_result_v4: package location found ${pak_loc}" | (debug_output)
			[ -z "${pak_loc}" ] && column=1 || column=${pak_loc}
			[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "sort_result_v4: column set: ${column}" | (debug_output)
		fi

		sort -t"${DL}" -k${column} -o${rc_id} ${rc_id}
	}

	# check input
	_file_check(){
		# check if rc_id is directory
		if [ -d "${rc_id}" ]; then
			if [ -e "${rc_id}/full.txt" ]; then
				rc_id="${rc_id}/full.txt"
				[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "sort_result_v4: rc_id is ${rc_id}" | (debug_output)
				return 0
			else
				[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "sort_result_v4: W: no rc_id set!" | (debug_output)
				return 1
			fi
		# else check if rc_id exists (must be a file then)
		elif ! [ -e ${rc_id} ]; then
			[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "sort_result_v4: W: no rc_id set!" | (debug_output)
			return 1
		# otherwise rc_id doesn't exist
		else
			[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "sort_result_v4: rc_id is ${rc_id}" | (debug_output)
			return 0
		fi
	}

	if [ -z "${single_rc}" ]; then
		[ ${DEBUGLEVEL} -ge ${FDL} ] && echo ">>> sort_result_v4: calling sorting for all running checks (column: ${fixed_column})" | (debug_output)
		for rc_id in ${RUNNING_CHECKS[@]}; do
			[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "sort_result_v4: checking and try sorting ${rc_id}" | (debug_output)
			_file_check && _file_sort
		done
	else
		[ ${DEBUGLEVEL} -ge ${FDL} ] && echo ">>> sort_result_v4: calling sorting for ${RUNNING_CHECKS[${single_rc}]} (column: ${fixed_column})" | (debug_output)
		rc_id="${RUNNING_CHECKS[${single_rc}]}"
		_file_check && _file_sort
	fi
	[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "<<< sort_result_v4: finish sorting" | (debug_output)
}

# sort results after a certain column
sort_result_column_v1(){
	local column="${1}"
	local rc="${2}"

	# find pakackge location in result
	_file_sort(){
		sort -t"${DL}" -k${column} -o${rc} ${rc}
	}

	# check input
	_file_check(){
		# check if rc_id is directory
		if [ -d "${rc}" ]; then
			if [ -e "${rc}/full.txt" ]; then
				rc="${rc}/full.txt"
				[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "${FUNCNAME[0]}: rc is ${rc}" | (debug_output)
				return 0
			else
				[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "${FUNCNAME[0]}: W: full.txt missing in ${rc}!" | (debug_output)
				return 1
			fi
		# else check if rc_id exists (must be a file then)
		elif ! [ -e ${rc} ]; then
			[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "${FUNCNAME[0]}: W: ${rc} doesn't exist!" | (debug_output)
			return 1
		# otherwise rc_id doesn't exist
		else
			[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "${FUNCNAME[0]}: rc is ${rc}" | (debug_output)
			return 0
		fi
	}

	if [[ -n "${rc}" ]] && [[ -n "${column}" ]]; then
		[[ ${DEBUGLEVEL} -ge ${FDL} ]] && echo ">>> ${FUNCNAME[0]}: calling sorting for ${rc} ,column: ${column})" | (debug_output)
		_file_check && _file_sort
	else
		return 1
	fi
	[[ ${DEBUGLEVEL} -ge ${FDL} ]] && echo "<<< ${FUNCNAME[0]}: finish sorting" | (debug_output)
}

sort_result_v5(){
	[ ${DEBUGLEVEL} -ge 1 ] && echo ">>> calling ${FUNCNAME[0]}" | (debug_output)

	if [[ -z "${1}" ]]; then
		local check_files=( "${RUNNING_CHECKS[@]}" )
	else
		local check_files=( "${1}" )
	fi
	local rc_id

	# find pakackge location in result
	_file_sort(){
		local column=""
		[ ${DEBUGLEVEL} -ge ${FDL} ] && echo " ${FUNCNAME[0]}: sorting ${rc_id}" | (debug_output)
		if [ -z "${column}" ]; then
			local pak_loc="$(_find_package_location "${rc_id}")"
			[ ${DEBUGLEVEL} -ge ${FDL} ] && echo " ${FUNCNAME[0]}: got location: ${pak_loc}" | (debug_output)
			[ -z "${pak_loc}" ] && column=1 || column=${pak_loc}
			[ ${DEBUGLEVEL} -ge ${FDL} ] && echo " ${FUNCNAME[0]}: column set: ${column}" | (debug_output)
		fi

		sort -t"${DL}" -k${column} -o${rc_id} ${rc_id}
	}

	# check input
	_file_check(){
		# check if rc_id is directory
		if [[ -d "${rc_id}" ]]; then
			if [[ -e "${rc_id}/full.txt" ]]; then
				rc_id="${rc_id}/full.txt"
				[ ${DEBUGLEVEL} -ge ${FDL} ] && echo " ${FUNCNAME[0]}: rc_id is ${rc_id}" | (debug_output)
				return 0
			else
				[ ${DEBUGLEVEL} -ge ${FDL} ] && echo " ${FUNCNAME[0]}: W: no rc_id(dir) set!" | (debug_output)
				return 1
			fi
		# else check if rc_id exists (must be a file then)
		elif ! [[ -e "${rc_id}" ]]; then
			[ ${DEBUGLEVEL} -ge ${FDL} ] && echo " ${FUNCNAME[0]}: W: no rc_id(file) set!" | (debug_output)
			return 1
		# otherwise rc_id doesn't exist
		else
			[ ${DEBUGLEVEL} -ge ${FDL} ] && echo " ${FUNCNAME[0]}: rc_id is ${rc_id}" | (debug_output)
			return 0
		fi
	}

	if [[ -n "${check_files}" ]]; then
		for rc_id in ${check_files[@]}; do
			_file_check && _file_sort
		done
	fi
	[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "<<< ${FUNCNAME[0]}: finish sorting" | (debug_output)
}

sort_result_v6(){
	[ ${DEBUGLEVEL} -ge 1 ] && echo ">>> calling ${FUNCNAME[0]}" | (debug_output)

	if [[ -z "${1}" ]]; then
		local check_files=( "${RUNNING_CHECKS[@]}" )
	else
		local check_files=( "${1}" )
	fi

	# find pakackge location in result
	_file_sort(){
		local column=""
		local rc_id="${1}"

		# check if rc_id is directory
		if [[ -d "${rc_id}" ]]; then
			if [[ -e "${rc_id}/full.txt" ]]; then
				rc_id="${rc_id}/full.txt"
				[ ${DEBUGLEVEL} -ge ${FDL} ] && echo " ${FUNCNAME[0]}: rc_id is ${rc_id}" | (debug_output)
			else
				[ ${DEBUGLEVEL} -ge ${FDL} ] && echo " ${FUNCNAME[0]}: W: no rc_id(dir) set!" | (debug_output)
				return 0
			fi
		# else check if rc_id exists (must be a file then)
		elif ! [[ -e "${rc_id}" ]]; then
			[ ${DEBUGLEVEL} -ge ${FDL} ] && echo " ${FUNCNAME[0]}: W: no rc_id(file) set!" | (debug_output)
			return 0
		fi

		[ ${DEBUGLEVEL} -ge ${FDL} ] && echo " ${FUNCNAME[0]}: sorting ${rc_id}" | (debug_output)
		if [ -z "${column}" ]; then
			local pak_loc="$(_find_package_location "${rc_id}")"
			[ ${DEBUGLEVEL} -ge ${FDL} ] && echo " ${FUNCNAME[0]}: got location: ${pak_loc}" | (debug_output)
			[ -z "${pak_loc}" ] && column=1 || column=${pak_loc}
			[ ${DEBUGLEVEL} -ge ${FDL} ] && echo " ${FUNCNAME[0]}: column set: ${column}" | (debug_output)
		fi

		sort -t"${DL}" -k${column} -o${rc_id} ${rc_id}
	}

	local id v d
	if [[ -n "${check_files}" ]]; then
		for id in ${check_files[@]}; do
			for v in sort-by-filter sort-by-eapi; do
				if [ -d "${id}/${v}" ]; then
					for d in $(find ${id}/${v}/* -type d); do
						_file_sort "${d}" &
					done
				fi
			done
			_file_sort "${id}" &
		done
	fi
	[ ${DEBUGLEVEL} -ge ${FDL} ] && echo "<<< ${FUNCNAME[0]}: finish sorting" | (debug_output)
}

count_keywords(){
	local ebuild1="${1}"
	local ebuild2="${2}"
	local category="${3}"
	local package="${4}"

	local a b

	if ${ENABLE_MD5}; then
		a="$(grep ^KEYWORDS ${REPOTREE}/metadata/md5-cache/${category}/${ebuild1})"
		b="$(grep ^KEYWORDS ${REPOTREE}/metadata/md5-cache/${category}/${ebuild2})"
		if [ $(echo ${a}|wc -w) -eq $(echo ${b}|wc -w) ]; then
			return 0
		else
			return 1
		fi
	else
		a="$(grep ^KEYWORDS ${REPOTREE}/${category}/${package}/${ebuild1}.ebuild | sed -e 's/^[ \t]*//')"
		b="$(grep ^KEYWORDS ${REPOTREE}/${category}/${package}/${ebuild2}.ebuild | sed -e 's/^[ \t]*//')"
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
		a="$(grep ^KEYWORDS ${REPOTREE}/metadata/md5-cache/${category}/${ebuild1})"
		b="$(grep ^KEYWORDS ${REPOTREE}/metadata/md5-cache/${category}/${ebuild2})"
		if [ "${a}" = "${b}" ]; then
			return 0
		else
			return 1
		fi
	else
		a="$(grep ^KEYWORDS ${REPOTREE}/${category}/${package}/${ebuild1}.ebuild | sed -e 's/^[ \t]*//')"
		b="$(grep ^KEYWORDS ${REPOTREE}/${category}/${package}/${ebuild2}.ebuild | sed -e 's/^[ \t]*//')"
		if [ "${a}" = "${b}" ]; then
			return 0
		else
			return 1
		fi
	fi
}

# function which sorts a list by it's maintainer
gen_sort_main_v4(){
	if [ -z "${1}" ]; then
		local check_files=( "${RUNNING_CHECKS[@]}" )
	else
		local check_files=( "${1}" )
	fi

	local id d v

	_gen_sort(){
		local rc_id="${1}"

		if [ -d "${rc_id}" ]; then
			if [ -e "${rc_id}/full.txt" ]; then
				rc_id="${rc_id}/full.txt"
			else
				return 0
			fi
		elif ! [ -e "${rc_id}" ]; then
			return 0
		fi

		# find pakackge location in result first
		local pak_loc="$(_find_package_location "${rc_id}")"
		if [ -s "${rc_id}" ]; then
			# check the first 10 entries
			for x in $(head -n10 "${rc_id}"); do
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
			mkdir -p "${rc_id%/*}/sort-by-maintainer"
			local main
			for main in $(cat "${rc_id}" |cut -d "${DL}" -f${main_loc}|tr ':' '\n'| grep -v "^[[:space:]]*$"|sort -u); do
				grep "${main}" "${rc_id}" > "${rc_id%/*}/sort-by-maintainer/"$(echo ${main}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt"
			done
		fi
	}

	for id in ${check_files[@]}; do
		for v in sort-by-filter sort-by-eapi; do
			if [ -d "${id}/${v}" ]; then
				for d in $(find ${id}/${v}/* -type d); do
					_gen_sort "${d}" &
				done
			fi
		done
		_gen_sort "${id}" &
	done
	wait
}

# function which sorts a list by it's maintainer
gen_sort_main_v5(){
	[ ${DEBUGLEVEL} -ge 1 ] && echo ">>> calling ${FUNCNAME[0]}" | (debug_output)
	if [ -z "${1}" ]; then
		if [ -n "${EXCLUDE_SORT_MAIN}" ]; then
			local del
			local RUNNING_CHECKS_FILTERED=($(echo ${RUNNING_CHECKS[@]}))
			for del in ${EXCLUDE_SORT_MAIN}; do
				RUNNING_CHECKS_FILTERED=("${RUNNING_CHECKS_FILTERED[@]/${del}}")
			done
			local check_files=( "${RUNNING_CHECKS_FILTERED[@]}" )
		else
			local check_files=( "${RUNNING_CHECKS[@]}" )
		fi
	else
		local check_files=( "${1}" )
	fi

	local id d v

	_gen_sort(){
		local rc_id="${1}"

		if [ -d "${rc_id}" ]; then
			if [ -e "${rc_id}/full.txt" ]; then
				rc_id="${rc_id}/full.txt"
			else
				return 0
			fi
		elif ! [ -e "${rc_id}" ]; then
			return 0
		fi
		[ ${DEBUGLEVEL} -ge 2 ] && echo "*** ${FUNCNAME[0]}: checking ${rc_id}" | (debug_output)

		# find pakackge location in result first
		local pak_loc="$(_find_package_location "${rc_id}")"
		if [ -s "${rc_id}" ]; then
			# check the first 10 entries
			for x in $(head -n10 "${rc_id}"); do
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
			mkdir -p "${rc_id%/*}/sort-by-maintainer"
			local main
			for main in $(cat "${rc_id}" |cut -d "${DL}" -f${main_loc}|tr ':' '\n'| grep -v "^[[:space:]]*$"|sort -u); do
				grep "${main}" "${rc_id}" > "${rc_id%/*}/sort-by-maintainer/"$(echo ${main}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt"
			done
		fi
	}

	[ ${DEBUGLEVEL} -ge 3 ] && echo ">>> full list: ${check_files[@]}" | (debug_output)
	for id in ${check_files[@]}; do
		for v in sort-by-filter sort-by-eapi; do
			if [ -d "${id}/${v}" ]; then
				for d in $(find ${id}/${v}/* -type d); do
					_gen_sort "${d}" &
				done
			fi
		done
		_gen_sort "${id}" &
	done
	wait
}

# function which sorts a list by it's package
gen_sort_pak_v4() {
	if [ -z "${1}" ]; then
		local check_files=( "${RUNNING_CHECKS[@]}" )
	else
		local check_files=( "${1}" )
	fi

	local id d v

	_gen_sort(){
		local rc_id="${1}"

		if [ -d "${rc_id}" ]; then
			# check input
			if [ -e "${rc_id}/full.txt" ]; then
				rc_id="${rc_id}/full.txt"
			else
				return 0
			fi
		elif ! [ -e "${rc_id}" ]; then
			return 0
		fi

		# find pakackge location in result
		pak_loc="$(_find_package_location "${rc_id}")"
		# only create package sorting if we found package location
		if [ -n "${pak_loc}" ]; then
			local f_packages="$(cat "${rc_id}"| cut -d "${DL}" -f${pak_loc} |sort -u)"
			local pack
			for pack in ${f_packages}; do
				local f_cat="$(echo ${pack}|cut -d'/' -f1)"
				local f_pak="$(echo ${pack}|cut -d'/' -f2)"
				mkdir -p "${rc_id%/*}/sort-by-package/${f_cat}"
				grep "\<${pack}\>" "${rc_id}" > "${rc_id%/*}/sort-by-package/${f_cat}/${f_pak}.txt"
			done
		fi
	}

	for id in ${check_files[@]}; do
		for v in sort-by-filter sort-by-eapi; do
			if [ -d "${id}/${v}" ]; then
				for d in $(find ${id}/${v}/* -type d); do
					_gen_sort "${d}" &
				done
			fi
		done
		_gen_sort "${id}" &
	done
	wait
}

# function which sorts a list by it's package
gen_sort_pak_v5() {
	[ ${DEBUGLEVEL} -ge 1 ] && echo ">>> calling ${FUNCNAME[0]}" | (debug_output)

	if [ -z "${1}" ]; then
		if [ -n "${EXCLUDE_SORT_PAK}" ]; then
			local del
			local RUNNING_CHECKS_FILTERED=($(echo ${RUNNING_CHECKS[@]}))
			for del in ${EXCLUDE_SORT_PAK}; do
				RUNNING_CHECKS_FILTERED=("${RUNNING_CHECKS_FILTERED[@]/${del}}")
			done
			local check_files=( "${RUNNING_CHECKS_FILTERED[@]}" )
		else
			local check_files=( "${RUNNING_CHECKS[@]}" )
		fi
	else
		local check_files=( "${1}" )
	fi


	local id d v

	_gen_sort(){
		local rc_id="${1}"

		if [ -d "${rc_id}" ]; then
			# check input
			if [ -e "${rc_id}/full.txt" ]; then
				rc_id="${rc_id}/full.txt"
			else
				return 0
			fi
		elif ! [ -e "${rc_id}" ]; then
			return 0
		fi
		[ ${DEBUGLEVEL} -ge 2 ] && echo "*** ${FUNCNAME[0]}: checking ${rc_id}" | (debug_output)

		# find pakackge location in result
		pak_loc="$(_find_package_location "${rc_id}")"
		# only create package sorting if we found package location
		if [ -n "${pak_loc}" ]; then
			local f_packages="$(cat "${rc_id}"| cut -d "${DL}" -f${pak_loc} |sort -u)"
			local pack
			for pack in ${f_packages}; do
				local f_cat="$(echo ${pack}|cut -d'/' -f1)"
				local f_pak="$(echo ${pack}|cut -d'/' -f2)"
				mkdir -p "${rc_id%/*}/sort-by-package/${f_cat}"
				grep "\<${pack}\>" "${rc_id}" > "${rc_id%/*}/sort-by-package/${f_cat}/${f_pak}.txt"
			done
		fi
	}

	[ ${DEBUGLEVEL} -ge 3 ] && echo ">>> full list: ${check_files[@]}" | (debug_output)
	for id in ${check_files[@]}; do
		for v in sort-by-filter sort-by-eapi; do
			if [ -d "${id}/${v}" ]; then
				for d in $(find ${id}/${v}/* -type d); do
					_gen_sort "${d}" &
				done
			fi
		done
		_gen_sort "${id}" &
	done
	wait
}

gen_sort_eapi_v1(){
	[ ${DEBUGLEVEL} -ge 1 ] && echo "calling ${FUNCNAME[0]}" | (debug_output)
	if [ -z "${1}" ]; then
		local check_files=( "${RUNNING_CHECKS[@]}" )
	else
		local check_files=( "${1}" )
	fi

	local eapi rc_id

	_gen_sort_eapi(){
		local eapi="${1}"
		mkdir -p "${rc_id}/sort-by-eapi/EAPI${eapi}"
		grep "^${eapi}${DL}" "${rc_id}/full.txt" > "${rc_id}/sort-by-eapi/EAPI${eapi}/full.txt"
	}

	local _eapi
	for rc_id in ${check_files[@]}; do
		if [ -e "${rc_id}/full.txt" ]; then
			for _eapi in $(cut -c-1 ${rc_id}/full.txt|sort -u); do
				_gen_sort_eapi "${_eapi}" &
			done
		fi
	done
	wait
}

gen_sort_filter_v1(){
	local column="${1}"
	if [ -z "${2}" ]; then
		local check_files=( "${RUNNING_CHECKS[@]}" )
	else
		local check_files=( "${2}" )
	fi

	local rc_id file ec ecd

	_gen_sort_filter() {
		local file="${1}"
		local col="${2}"
		local ec
		for ec in $(echo "${file}"|cut -d'|' -f${col}|tr ':' ' '|cut -d'(' -f1); do
			mkdir -p "${rc_id}/sort-by-filter/$(echo ${ec}|tr '/' '_')"
			echo "${file}" >> "${rc_id}/sort-by-filter/$(echo ${ec}|tr '/' '_')/full.txt"
		done
	}

	local _file
	for rc_id in ${check_files[@]}; do
		if [ -e "${rc_id}/full.txt" ]; then
			for _file in $(cat "${rc_id}/full.txt"); do
				_gen_sort_filter "${_file}" "${column}" &
			done
		fi
	done
	wait
}

gen_sort_filter_v2(){
	[ ${DEBUGLEVEL} -ge 1 ] && echo ">>> calling ${FUNCNAME[0]}" | (debug_output)
	local column="${1}"
	if [ -z "${2}" ]; then
		local check_files=( "${RUNNING_CHECKS[@]}" )
	else
		local check_files=( "${2}" )
	fi

	local rc_id file ec ecd

	_gen_sort_filter() {
		local file="${1}"
		local col="${2}"
		local ec
		for ec in $(echo "${file}"|cut -d'|' -f${col}|tr ':' ' '|cut -d'(' -f1); do
			mkdir -p "${rc_id}/sort-by-filter/$(echo ${ec}|tr '/' '_')"
			echo "${file}" >> "${rc_id}/sort-by-filter/$(echo ${ec}|tr '/' '_')/full.txt"
		done
	}

	local _file
	for rc_id in ${check_files[@]}; do
		if [ -e "${rc_id}/full.txt" ]; then
			for _file in $(cat "${rc_id}/full.txt"); do
				_gen_sort_filter "${_file}" "${column}" &
			done
		fi
	done
	wait
}

gen_descriptions(){
	for i in $(seq 0 $(expr ${#RUNNING_CHECKS[@]} - 1)); do
		data_descriptions ${i} >> "${RUNNING_CHECKS[${i}]}/description.txt"
	done
}

clean_results(){
	[ ${DEBUGLEVEL} -ge 1 ] && echo ">>> calling ${FUNCNAME[0]}" | (debug_output)
	local c
	for c in ${RUNNING_CHECKS[@]}; do
		if [ -e "${c}/full.txt" ]; then
			if ! [ -s "${c}/full.txt" ]; then
				rm ${c}/full.txt
			fi
		fi
	done
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

# like get_age but returns the date of the last commit regarding a package
get_age_last() {
	local file=${1}

	if ${ENABLE_GIT}; then
		filedate="$(git -C ${REPOTREE} log --full-history -1 --format="format:%cs" -- ${REPOTREE}/${file})"
		echo "${filedate}"
	else
		echo ""
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

get_git_age() {
	local file="${1}"
	local time_format="${2}"
	local diff_filter="${3}"
	local position="${4}"

	if ${ENABLE_GIT}; then
		case "${position}" in
			first)
				filedate="$(git -C ${REPOTREE} log --format="format:%${time_format}" --diff-filter=${diff_filter} -- ${REPOTREE}/${file} | tail -1)"
			;;
			last)
				filedate="$(git -C ${REPOTREE} log --format="format:%${time_format}" --diff-filter=${diff_filter} -- ${REPOTREE}/${file} | head -1)"
			;;
			all)
				filedate="$(git -C ${REPOTREE} log --format="format:%${time_format}" --diff-filter=${diff_filter} -- ${REPOTREE}/${file})"
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


get_eclasses_real_v2() {
	local ebuild="${1}"

	local cat="$(echo ${ebuild}|cut -d'/' -f1)"
	local pak="$(echo ${ebuild}|cut -d'/' -f2)"
	local eb="$(echo ${ebuild}|cut -d'/' -f3)"

	local md5_file="${REPOTREE}/metadata/md5-cache/${cat}/${eb}"

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

	if $(sed -e :a -e '/\\$/N; s/\\\n//; s/\t/ /; ta' ${real_file} | grep "${search_pattern}" | grep -q "\"${eclass_var}\"\\| ${eclass_name} \\|${eclass_name} \\| ${eclass_name}\$"); then
		return 0
	else
		return 1
	fi
}

get_eclasses() {
	local ebuild="${1}"

	local cat="$(echo ${ebuild}|cut -d'/' -f1)"
	local pak="$(echo ${ebuild}|cut -d'/' -f2)"
	local eb="$(echo ${ebuild}|cut -d'/' -f3)"

	local md5_file="${REPOTREE}/metadata/md5-cache/${cat}/${eb}"
	local real_file="${REPOTREE}/${ebuild}.ebuild"

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
		if $(sed -e :a -e '/\\$/N; s/\\\n//; s/\t/ /; ta' ${real_file} | grep inherit | grep -q " ${ecl} \\| ${ecl}\$"); then
			file_eclasses+=( ${ecl} )
		fi
	done
	echo ${file_eclasses[@]}|tr ' ' ':'
}

# this function simply copies all results from the WORKDIR to
# the RESULTSDIR
copy_checks() {
	[ ${DEBUGLEVEL} -ge 1 ] && echo "calling ${FUNCNAME[0]}" | (debug_output)
	local type=${1}

	if ! [ -e ${RESULTSDIR}/${type}/ ]; then
		mkdir -p ${RESULTSDIR}/${type}
		cp -r ${RUNNING_CHECKS[@]} ${RESULTSDIR}/${type}/
	else
		for lcheck in ${RUNNING_CHECKS[@]}; do
			rm -rf ${RESULTSDIR}/${type}/${lcheck##*/}
		done
		cp -r ${RUNNING_CHECKS[@]} ${RESULTSDIR}/${type}/
	fi
}

#pre_checks() {
#
#}

post_checks() {
	[ ${DEBUGLEVEL} -ge 1 ] && echo ">>> calling ${FUNCNAME[0]}" | (debug_output)
	local type=${1}

	if ! [ -e ${RESULTSDIR}/${type}/ ]; then
		mkdir -p ${RESULTSDIR}/${type}
		cp -r ${RUNNING_CHECKS[@]} ${RESULTSDIR}/${type}/
	else
		for lcheck in ${RUNNING_CHECKS[@]}; do
			rm -rf ${RESULTSDIR}/${type}/${lcheck##*/}
		done
		cp -r ${RUNNING_CHECKS[@]} ${RESULTSDIR}/${type}/
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
					if [ -d "${REPOTREE}/$(echo ${x}| cut -d'|' -f${i})" ]; then
						local l=${i}
						break 2
					fi
				done
			done

			if [ -n "${l}" ]; then
				p_list=( $(cut -d'|' -f${l} ${c}/full.txt) )
				for p in ${p_list[@]}; do
					if ! [ -d ${REPOTREE}/${p} ]; then
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

get_main_min(){
	if [ -e "${REPOTREE}/${1}/metadata.xml" ]; then
		local maint=`/usr/bin/python3 - "${1}" <<END
import xml.etree.ElementTree
import sys
pack = str(sys.argv[1])
projxml = "${REPOTREE}" + pack + "/metadata.xml"
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

export -f get_main_min get_perm get_eapi check_eclasses_usage count_keywords \
	compare_keywords get_bugs_bool get_age_last get_git_age date_update \
	get_time_diff sort_result_v4 check_mask gen_sort_eapi_v1 gen_sort_filter_v1 \
	get_licenses get_eclasses get_keywords get_depend gen_sort_main_v4 \
	gen_sort_pak_v4 get_eclasses_real_v2 clean_results debug_output \
	get_site_status get_file_status_detailed get_age_v3 post_checks \
	sort_result_v5 gen_sort_pak_v5 gen_sort_main_v5 gen_sort_filter_v2 \
	get_keywords_v2 sort_result_column_v1 sort_result_v6 get_site_rating
