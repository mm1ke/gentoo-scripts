#!/bin/bash

# Filename: funcs.sh
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

# check for porttree features
BUGTMPDIR="/tmp/buglists/"
ENABLE_GIT=false
ENABLE_MD5=false
if [ -e ${PORTTREE} ] && [ -n "${PORTTREE}" ]; then
	[ -e "${PORTTREE}/.git" ] && ENABLE_GIT=true
	[ -e "${PORTTREE}/metadata/md5-cache" ] && ENABLE_MD5=true
else
	echo "Please check settings. ${PORTTREE} not found"
fi
export ENABLE_GIT ENABLE_MD5 BUGTMPDIR

_update_buglists(){
	local BUG_FILES="UNCONFIRMED CONFIRMED IN_PROGRESS"

	mkdir -p ${BUGTMPDIR}

	if ! [ -e "${BUGTMPDIR}/full-$(date -I).txt" ]; then

		find ${BUGTMPDIR}/* -mtime +2 -exec rm -f {} \; >/dev/null 2>&1

		for file in ${BUG_FILES}; do
			local bugfile="${BUGTMPDIR}/${file}-$(date -I).txt"
			curl -s https://bugs.gentoo.org/data/cached/buglist-${file}.html > ${bugfile}

			sed -i -e 1,3d ${bugfile}
			sed -i '$ d' ${bugfile}
			sed -i "s/<div><ul>//g" ${bugfile}
			sed -i "s/ /_/g" ${bugfile}

			sed -i "s|<li><a_href='||; \
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


gen_http_sort_main(){
	local type="${1}"
	local dir="${2}"
	local value_pack=""
	local value_filter=""
	local value_full=""
	local value_main=""

	case ${type} in
		results)
			local value_title="${dir##*/}"
			local value_line="Checks proceeded: <b>$(find ${dir} -mindepth 1 -maxdepth 1 -type d|wc -l)"
			;;
		main)
			local value_title="${dir##*/}"
			local value_line="Total Maintainers: <b>$(find ${dir}/sort-by-maintainer/ -mindepth 1 -maxdepth 1 -type f|wc -l)"
			if [ -e ${dir}/full.txt ];then
				local value_full="<a href=\"full.txt\">TXT-full.txt</a>"
			fi
			if [ -e ${dir}/sort-by-maintainer/ ];then
				local value_main="<a href=\"sort-by-maintainer\">TXT-sort-by-maintainer</a>"
			fi
			if [ -e ${dir}/sort-by-package/ ];then
				local value_pack="<a href=\"sort-by-package\">TXT-sort-by-package</a>"
			fi
			if [ -e ${dir}/sort-by-filter/ ];then
				local value_filter="<a href=\"sort-by-filter\">TXT-sort-by-filter</a>"
			elif [ -e ${dir}/sort-by-eapi/ ];then
				local value_filter="<a href=\"sort-by-eapi\">TXT-sort-by-eapi</a>"
			fi

			;;
	esac


read -r -d '' TOP <<- EOM
<html>
\t<head>
\t\t<style type="text/css"> li a { font-family: monospace; display:block; float: left; }</style>
\t\t<title>Gentoo QA: ${value_title}</title>
\t</head>
\t<body text="black" bgcolor="white">
\t\tList generated on $(date -I)</br>
\t\t${value_line}</b>
\t<pre><a href="../">../</a>  <a href="#" onclick="history.go(-1)">Back</a>  <a href="https://gentooqa.levelnine.at/results/">Home</a></pre>
\t\t<pre>${value_full}
${value_main}
${value_pack}
${value_filter}
\t\t</pre><hr><pre>
EOM

read -r -d '' BOTTOM <<- EOM
\t\t</table>
\t</pre></hr></body>
</html>
EOM
	echo -e "${TOP}"

	case ${type} in
		results)
			echo "QTY     Check"
			for u in $(find ${dir} -maxdepth 1 -mindepth 1 -type d|sort ); do
				val="$(cat ${u}/full.txt | wc -l)"

				a="<a href=\"${u##*/}/index.html\">${u##*/}</a>"
				line='      '
				printf "%s%s%s\n" "${line:${#val}}" "${val}" "  ${a}"
			done
		;;

		main)
			echo "QTY     Maintainer"
			for i in $(ls ${dir}/sort-by-maintainer/); do
				main="${i}"
				val="$(cat ${dir}/sort-by-maintainer/${main} | wc -l)"

				a="<a href=\"sort-by-maintainer/${main}\">${main::-4}</a>"
				line='      '
				printf "%s%s%s\n" "${line:${#val}}" "${val}" "  ${a}"
			done
		;;
	esac

	echo -e "${BOTTOM}"
}

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
gen_sort_main(){
	local workfile="${1}"
	local main_loc="${2}"
	local dest_dir="${3}"
	local DL="${4}"
	local main

	if [ -e ${workfile} ]; then
		mkdir -p ${dest_dir}/sort-by-maintainer
		for main in $(cat ${workfile} |cut -d "${DL}" -f${main_loc}|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
			grep "${main}" ${workfile} > ${dest_dir}/sort-by-maintainer/"$(echo ${main}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
		done
	fi
}

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
gen_sort_pak() {
	local workfile="${1}"
	local pak_loc="${2}"
	local dest_dir="${3}"
	local DL="${4}"
	local pack

	if [ -e ${workfile} ]; then
		local f_packages="$(cat ${workfile}| cut -d "${DL}" -f${pak_loc} |sort|uniq)"
		for pack in ${f_packages}; do
			f_cat="$(echo ${pack}|cut -d'/' -f1)"
			f_pak="$(echo ${pack}|cut -d'/' -f2)"
			mkdir -p ${dest_dir}/sort-by-package/${f_cat}
			grep "${pack}" ${workfile} > ${dest_dir}/sort-by-package/${f_cat}/${f_pak}.txt
		done
	fi
}

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
		grep "${pack}" ${workfile} > ${workfile%/*}/sort-by-package/${f_cat}/${f_pak}.txt
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

get_main_min(){
	local maint=`/usr/bin/python3 - "${1}" <<END
import xml.etree.ElementTree
import sys
pack = str(sys.argv[1])
projxml = "/usr/portage/" + pack + "/metadata.xml"
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

export -f get_main_min get_perm get_age get_bugs
