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
# this file only provides functions for different scripts

#
# globally vars - can be used everywhere (exported)
#
# enabling debuging (if available)
BUGTMPDIR="/tmp/buglists/"
DEBUG=false
DL='|'

# set the PORTTREE
if [ -z "${PORTTREE}" ]; then
	if [ -e /usr/portage/metadata/ ]; then
		PORTTREE="/usr/portage/"
		export PORTTREE
	else
		exit "No portage tree set"
		exit 1
	fi
fi
[ -z "${SCRIPT_MODE}" ] && \
	SCRIPT_MODE=false && \
	export SCRIPT_MODE
[ -z "${SITEDIR}" ] && \
	SITEDIR="${HOME}/checks-${RANDOM}/" && \
	export SITEDIR

ENABLE_GIT=false
ENABLE_MD5=false
TREE_IS_MASTER=false
if [ -e ${PORTTREE} ]; then
	[ -e "${PORTTREE}/.git" ] && ENABLE_GIT=true
	[ -e "${PORTTREE}/metadata/md5-cache" ] && ENABLE_MD5=true
	[ "$(cat ${PORTTREE}/profiles/repo_name)" = "gentoo" ] && TREE_IS_MASTER=true
fi

export ENABLE_GIT ENABLE_MD5 DEBUG DL BUGTMPDIR TREE_IS_MASTER
#

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

# function to sort the output, takes two argument, where the second is optional.
# The first argument is the file to sort (usually full.txt)
# the second is the column number to sort after
sort_result(){
	local workfile="${1}"
	local column="${2}"

	if [ -d ${workfile} ]; then
		if [ -e "${workfile}/full.txt" ]; then
			local workfile="${workfile}/full.txt"
		else
			return 1
		fi
	elif ! [ -e ${workfile} ]; then
		return 1
	fi

	if [ -z "${column}" ]; then
		sort -o ${workfile} ${workfile}
	else
		sort -t"${DL}" -k${column} -o${workfile} ${workfile}
	fi
}

compare_keywords(){
	local ebuild1="${1}"
	local ebuild2="${2}"
	local category="${3}"
	local package="${4}"

	if ${ENABLE_MD5}; then
		if [ "$(grep ^KEYWORDS ${PORTTREE}/metadata/md5-cache/${category}/${ebuild1})" = \
			"$(grep ^KEYWORDS ${PORTTREE}/metadata/md5-cache/${category}/${ebuild2})" ]; then
			return 0
		else
			return 1
		fi
	else
		if [ "$(grep ^KEYWORDS ${PORTTREE}/${category}/${package}/${ebuild1}.ebuild | sed -e 's/^[ \t]*//')" = \
			"$(grep ^KEYWORDS ${PORTTREE}/${category}/${package}/${ebuild2}.ebuild | sed -e 's/^[ \t]*//')" ]; then
			return 0
		else
			return 1
		fi
	fi
}

# function which sorts a list by it's maintainer
gen_sort_main_v2(){
	local workfile="${1}"
	local main_loc="${2}"
	local main

	if [ -d ${workfile} ]; then
		if [ -e "${workfile}/full.txt" ]; then
			local workfile="${workfile}/full.txt"
		else
			return 1
		fi
	elif ! [ -e ${workfile} ]; then
		return 1
	fi

	mkdir -p ${workfile%/*}/sort-by-maintainer
	for main in $(cat ${workfile} |cut -d "${DL}" -f${main_loc}|tr ':' '\n'| grep -v "^[[:space:]]*$"|sort -u); do
		grep "${main}" ${workfile} > ${workfile%/*}/sort-by-maintainer/"$(echo ${main}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
	done
}

# function which sorts a list by it's package
gen_sort_pak_v2() {
	local workfile="${1}"
	local pak_loc="${2}"
	local pack

	if [ -d ${workfile} ]; then
		if [ -e "${workfile}/full.txt" ]; then
			local workfile="${workfile}/full.txt"
		else
			return 1
		fi
	elif ! [ -e ${workfile} ]; then
		return 1
	fi

	local f_packages="$(cat ${workfile}| cut -d "${DL}" -f${pak_loc} |sort -u)"
	for pack in ${f_packages}; do
		f_cat="$(echo ${pack}|cut -d'/' -f1)"
		f_pak="$(echo ${pack}|cut -d'/' -f2)"
		mkdir -p ${workfile%/*}/sort-by-package/${f_cat}
		grep "\<${pack}\>" ${workfile} > ${workfile%/*}/sort-by-package/${f_cat}/${f_pak}.txt
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

depth_set() {
	arg="${1}"

	if [ -z "${arg}" ]; then
		usage
		exit 1
	else
		# test if user provided input exist
		if [ -d "${PORTTREE}/${arg}" ]; then
			level="${arg}"
			MAXD=0
			MIND=0
			# case if user provides only category
			# if there is a '/', everything after need to be empty
			# if there are no '/', both checks (arg%%/* and arg##*/) print the same
			if [ -z "${arg##*/}" ] || [ "${arg%%/*}" = "${arg##*/}" ]; then
				MAXD=1
				MIND=1
			fi
		elif [ "${arg}" = "full" ] || [ "${arg}" = "diff" ]; then
			level=""
			MAXD=2
			MIND=2
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
			"$(date '+%s' -d $(git -C ${PORTTREE} log --format="format:%ci" --name-only --diff-filter=A ${PORTTREE}/${category}/${package}/${file} \
			| head -1|cut -d' ' -f1) 2>/dev/null )" \) / 86400 2>/dev/null)"
		echo "${fileage}"
	else
		echo ""
	fi
}

# get the date when the package got removed (removed via git)
get_dead_age() {
	local package=${1}
	local date_today="$(date '+%s' -d today)"

	if ${ENABLE_GIT}; then
		#deadage="$(expr \( "${date_today}" - \
		#	"$(date '+%s' -d $(git -C ${PORTTREE} log --format="format:%ci" --name-only --diff-filter=A -- ${PORTTREE}/${package} \
		#	| head -1 | cut -d' ' -f1) 2>/dev/null )" \) / 86400 2>/dev/null)"
		deadage="$(git -C ${PORTTREE} log --format="format:%ci" --name-only --diff-filter=A -- ${PORTTREE}/${package} \
			| head -1 | cut -d' ' -f1)"
		echo "${deadage}"
	else
		echo ""
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

	if $(sed -e :a -e '/\\$/N; s/\\\n//; ta' ${real_file} | grep "${search_pattern}" | grep -q "\"${eclass_var}\"\\| ${eclass_name} \\| ${eclass_name}\$"); then
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
diff_rm_dropped_paks(){
	local l=${1}			# package location (row)
	local c
	local p
	local p_list=( )

	# only run if we get a package location
	if [ -n "${l}" ]; then
		for c in ${RUNNING_CHECKS[@]}; do
			if [ -s ${c}/full.txt ]; then
				p_list=( $(cut -d'|' -f${l} ${c}/full.txt) )
				for p in ${p_list[@]}; do
					if ! [ -d ${PORTTREE}/${p} ]; then
						sed -i "/${p//\//\\/}${DL}/d" ${c}/full.txt
					fi
				done
			fi
		done
	fi
}

diff_rm_dropped_paks_v2(){
	local l=${1}			# package location (row)
	local id=${2}			# RUNNING_CHECKS Id (can be empty)
	local c
	local p

	p_list=( )

	_cleanup() {
		local file=${1}
		for p in ${p_list[@]}; do
			if ! [ -d ${PORTTREE}/${p} ]; then
				sed -i "/${p//\//\\/}${DL}/d" ${file}
			fi
		done
	}

	# only run if we get a package location
	if [ -n "${l}" ]; then
		if [ -n "${id}" ]; then
			if [ -s ${RUNNING_CHECKS[${id}]} ]; then
				p_list=( $(cut -d'|' -f${l} ${RUNNING_CHECKS[${id}]}/full.txt) )
				_cleanup "${RUNNING_CHECKS[${id}]}/full.txt"
			fi
		else
			for c in ${RUNNING_CHECKS[@]}; do
				if [ -s ${c}/full.txt ]; then
					p_list=( $(cut -d'|' -f${l} ${c}/full.txt) )
					_cleanup "${c}/full.txt"
				fi
			done
		fi
	fi
}

get_main_min(){
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
	get_eclasses_real check_eclasses_usage get_eapi_pak get_eapi_list sort_result \
	compare_keywords diff_rm_dropped_paks get_dead_age
