#!/bin/bash

# Filename: srctest
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 12/08/2017

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
# simple scirpt to find broken SRC_URI links

SCRIPT_MODE=false
PORTTREE="/usr/portage/"
WWWDIR="${HOME}/srctest/"
TMPCHECK="/tmp/srctest-tmp-${RANDOM}.txt"
DL='|'

if [ "$(hostname)" = methusalix ]; then
	SCRIPT_MODE=true
	WWWDIR="/var/www/gentoo.levelnine.at/srctest/"
fi

touch ${TMPCHECK}

cd ${PORTTREE}

${SCRIPT_MODE} && rm -rf /${WWWDIR}/*

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

if [ -z "${1}" ]; then
	usage
	exit 1
else
	if [ -d "${PORTTREE}/${1}" ]; then
		level="${1}"
		MAXD=0
		MIND=0
		if [ -z "${1##*/}" ] || [ "${1%%/*}" == "${1##*/}" ]; then
			MAXD=1
			MIND=1
		fi
	elif [ "${1}" == "full" ]; then
		level=""
		MAXD=2
		MIND=2
	else
		echo "${PORTTREE}/${1}: Path not found"
	fi
fi

get_main_min(){
	local ret=`/usr/bin/python3 - $1 <<END
import xml.etree.ElementTree
import sys
pack = str(sys.argv[1])
projxml = "/usr/portage/" + pack + "/metadata.xml"
e = xml.etree.ElementTree.parse(projxml).getroot()
c = ""
for i in e:
	for v in i.iter('maintainer'):
		b=str(v[0].text)
		c+=str(b)+':'
print(c)
END`
	echo ${ret// /_}
}

main() {
	get_status() {
		local uri="${1}"
		local code="${2}"
		if $(timeout 15 wget -T 10 -S --spider ${uri} 2>&1 | grep "${code}" >/dev/null); then
			echo true
		else
			echo false
		fi
	}

	mode() {
		local msg=${1}
		local status=${2}
		if ${SCRIPT_MODE}; then
			echo "${msg}" >> "${WWWDIR}/full_${status}.txt"
			echo "${status}${DL}${msg}" >> "${WWWDIR}/full.txt"
		else
			echo "${status}${DL}${msg}"
		fi
	}

	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package=${full_package##*/}
	local maintainer="$(get_main_min "${category}/${package}")"
	local md5portage=false

	code_available='HTTP/1.1 200 OK'
	maybe_available='HTTP/1.1 403 Forbidden'

	if [ -z "${maintainer}" ]; then
			maintainer="maintainer-needed@gentoo.org:"
	fi

	# only works best with the md5-cache
	if ! [ -e "${PORTTREE}/metadata/md5-cache" ]; then
		exit 1
	fi

	for eb in ${PORTTREE}/${full_package}/*.ebuild; do
		local ebuild=$(basename ${eb%.*})

		local _src="$(grep ^SRC_URI= ${PORTTREE}/metadata/md5-cache/${category}/${ebuild})"
		local _src=${_src:8}

		if [ -n "${_src}" ]; then
			# the variable SRC_URI sometimes has more data than just download links like
			# useflags or renamings, so just grep each text for http/https
			for u in ${_src}; do
				# add ^mirror:// to the grep, somehow we should be able to test them too
				for i in $(echo $u | grep -E "^http://|^https://"); do
					local _checktmp="$(grep -P "(^|\s)\K${i}(?=\s|$)" ${TMPCHECK}|sort -u)"
					if [ -n "${_checktmp}" ]; then
						mode "${category}/${package}${DL}${ebuild}${DL}$(echo ${_checktmp} | cut -d' ' -f2-)${DL}${maintainer}" "$(echo ${_checktmp} | cut -d' ' -f1)"
					else
						if $(get_status ${i} "${code_available}"); then
							mode "${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}" available
							echo "available ${i}" >> ${TMPCHECK}
						elif $(get_status ${i} "${maybe_available}"); then
							mode "${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}" maybe_available
							echo "maybe_available ${i}" >> ${TMPCHECK}
						else
							mode "${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}" not_available
							echo "not_available ${i}" >> ${TMPCHECK}
						fi
					fi
				done
			done
		fi
	done
}

export -f main get_main_min
export PORTTREE WWWDIR SCRIPT_MODE TMPCHECK DL

find ./${level} -mindepth $MIND -maxdepth $MAXD \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type d -print | parallel main {}

if ${SCRIPT_MODE}; then
	# sort by packages, ignoring "good" codes
	f_packages="$(cat ${WWWDIR}/full_not_available.txt| cut -d "${DL}" -f1|sort|uniq)"
	for i in ${f_packages}; do
		f_cat="$(echo $i|cut -d'/' -f1)"
		f_pak="$(echo $i|cut -d'/' -f2)"
		mkdir -p ${WWWDIR}/sort-by-package/${f_cat}
		grep "${i}" ${WWWDIR}/full_not_available.txt > ${WWWDIR}/sort-by-package/${f_cat}/${f_pak}.txt
	done

	mkdir -p ${WWWDIR}/sort-by-maintainer/
	# sort by maintainer, ignoring "good" codes
	for a in $(cat ${WWWDIR}/full_not_available.txt |cut -d "${DL}" -f4|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
		grep "${a}" ${WWWDIR}/full_not_available.txt > ${WWWDIR}/sort-by-maintainer/"$(echo ${a}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
	done
fi
rm ${TMPCHECK}
