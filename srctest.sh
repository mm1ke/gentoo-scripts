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

MAXD=2
MIND=2


if [ "$(hostname)" = methusalix ]; then
	script_mode=true
	_wwwdir="/var/www/gentoo.levelnine.at/srctest/"
	PORTTREE="/usr/portage/"
else
	script_mode=true
	_wwwdir="/home/ai/srctest/"
	PORTTREE="/usr/portage/"
fi

cd ${PORTTREE}

${script_mode} && rm -rf /${_wwwdir}/*


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
	echo $ret
}

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
	if ${script_mode}; then
		echo "${msg}" >> "${_wwwdir}/full_${status}.txt"
		echo "${status};${msg}" >> "${_wwwdir}/full.txt"
	else
		echo "${status};${msg}"
	fi
}

main() {
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package=${line##*/}
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


	for eb in ${PORTTREE}/$line/*.ebuild; do
		ebuild=$(basename ${eb%.*})
		
		_src="$(grep ^SRC_URI= ${PORTTREE}/metadata/md5-cache/${category}/${ebuild}|cut -d'=' -f2)"

		if [ -n "${_src}" ]; then
			# the variable SRC_URI sometimes has more data than just download links like
			# useflags or renamings, so just grep each text for http/https
			for u in ${_src}; do
				# add ^mirror:// to the grep, somehow we should be able to test them too
				for i in $(echo $u | grep -E "^http://|^https://"); do
					first_check=$(get_status ${i} "${code_available}")
					if ${first_check}; then
						mode "${category}/${package};${i};${maintainer}" available
					else
						second_check=$(get_status ${i} "${maybe_available}")
						if ${second_check}; then
							mode "${category}/${package};${i};${maintainer}" maybe_available
						else
							mode "${category}/${package};${i};${maintainer}" not_available
						fi
					fi
				done
			done
		fi
	done

}

find ./${level} -mindepth $MIND -maxdepth $MAXD \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type d -print | while read -r line; do
	main ${line}
done



if ${script_mode}; then

	# sort by packages, ignoring "good" codes
	f_packages="$(cat ${_wwwdir}/full_not_available.txt| cut -d ';' -f1|sort|uniq)"
	for i in ${f_packages}; do
		f_cat="$(echo $i|cut -d'/' -f1)"
		f_pak="$(echo $i|cut -d'/' -f2)"
		mkdir -p ${_wwwdir}/sort-by-package/${f_cat}
		grep "${i}" ${_wwwdir}/full_not_available.txt > ${_wwwdir}/sort-by-package/${f_cat}/${f_pak}.txt
	done
	
	mkdir -p ${_wwwdir}/sort-by-maintainer/
	# sort by maintainer, ignoring "good" codes
	for a in $(cat ${_wwwdir}/full_not_available.txt |cut -d';' -f3|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
		grep "${a}" ${_wwwdir}/full_not_available.txt > ${_wwwdir}/sort-by-maintainer/"$(echo ${a}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
	done

fi
