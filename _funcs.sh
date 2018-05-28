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
if [ -e ${PORTTREE} ] && [ -n "${PORTTREE}" ]; then
	[ -e "${PORTTREE}/.git" ] && ENABLE_GIT=true
	[ -e "${PORTTREE}/metadata/md5-cache" ] && ENABLE_MD5=true
fi
[ "$(cat ${PORTTREE}/profiles/repo_name)" = "gentoo" ] && TREE_IS_MASTER=true

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

get_bugs(){
	local value="${1}"
	local return="$(grep ${value} ${BUGTMPDIR}/full-$(date -I).txt | cut -d' ' -f2 | tr '\n' ':')"

	[ -n "${return}" ] && echo "${return::-1}"
}

get_bugs_full(){
	local value="${1}"
	local return="$(grep ${value} ${BUGTMPDIR}/full-$(date -I).txt | cut -d' ' -f1,3)"

	[ -n "${return}" ] && echo "${return}"
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
		if [ -d "${PORTTREE}/${arg}" ]; then
			level="${arg}"
			MAXD=0
			MIND=0
			if [ -z "${arg##*/}" ] || [ "${arg%%/*}" == "${arg##*/}" ]; then
				MAXD=1
				MIND=1
			fi
		elif [ "${arg}" == "full" ]; then
			level=""
			MAXD=2
			MIND=2
		else
			echo "${PORTTREE}/${arg}: Path not found"
		fi
	fi
}

# this function get the age (file creation) of a particular ebuild
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

# return the EAPI of a given ebuild
get_eapi() {
	local file=${1}
	local eapi="$(grep ^EAPI ${file}|cut -d' ' -f1|grep -Eo '[0-9]')"
	[ -n "${eapi}" ] && echo ${eapi} || echo "0"
}

# return all eclasses inherited by a ebuild
get_eclasses_real() {
	local md5_file=${1}

	if ${ENABLE_MD5}; then
		local real_eclasses=( $(grep '_eclasses_=' ${md5_file}|cut -c12-|sed 's/\(\t[^\t]*\)\t/\1\n/g'|cut -d$'\t' -f1) )
		echo ${real_eclasses[@]}|tr ' ' ':'
	fi
}

check_eclasses_usage() {
	local real_file=${1}
	local eclass_name=${2}

	local eclass_var="$(grep ^inherit ${real_file} |grep -o $\{.*\}|sed 's/${\(.*\)}/\1/')"
	if [ -z "${eclass_var}" ]; then
		search_pattern="inherit"
	else
		search_pattern="${eclass_var}\=\|inherit"
	fi

	if $(sed -e :a -e '/\\$/N; s/\\\n//; ta' ${real_file} | grep "${search_pattern}" | grep -q " ${eclass_name} \\| ${eclass_name}\$"); then
		return 0
	else
		return 1
	fi
}

get_eclasses_file() {
	local md5_file=${1}
	local real_file=${2}

	if ${ENABLE_MD5}; then
		local real_eclasses=( $(grep '_eclasses_=' ${md5_file}|cut -c12-|sed 's/\(\t[^\t]*\)\t/\1\n/g'|cut -d$'\t' -f1) )
		local file_eclasses=( )
		local eclass_var="$(grep ^inherit ${real_file} |grep -o $\{.*\}|sed 's/${\(.*\)}/\1/')"
		if [ -n "${eclass_var}" ]; then
			file_eclasses+=( "$(grep -o "${eclass_var}=.*" ${real_file} | tail -n1 | tr -d '"' | cut -d '=' -f2 | cut -d ' ' -f1 )" )
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

export -f get_main_min get_perm get_age get_bugs get_eapi get_eclasses_file get_eclasses_real check_eclasses_usage
