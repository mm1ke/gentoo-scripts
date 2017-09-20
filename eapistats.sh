#!/bin/bash

# Filename: eapistats.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 07/09/2017

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
# simple script for generating EAPI statistics


SCRIPT_MODE=false
WWWDIR="${HOME}/eapistats/"
PORTTREE="/usr/portage/"
DL='|'

if [ "$(hostname)" = methusalix ]; then
	SCRIPT_MODE=true
	WWWDIR="/var/www/gentoo.levelnine.at/eapistats/"
fi

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
	echo $ret
}

main() {
	local full_package=${1}
	local eapi=${2}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package="$(echo ${full_package}|cut -d'/' -f3)"
	local filename="$(echo ${full_package}|cut -d'/' -f4)"

	local maintainer="$(get_main_min "${category}/${package}")"
	if [ -z "${maintainer}" ]; then
			maintainer="maintainer-needed@gentoo.org:"
	fi
	
	if ${SCRIPT_MODE}; then
		mkdir -p /${WWWDIR}/
		echo "${eapi}${DL}${category}/${package}/${filename}${DL}${maintainer}" >> /${WWWDIR}/full.txt
	else
		echo "${eapi}${DL}${category}/${package}/${filename}${DL}${maintainer}"
	fi
}

gen_sortings() {
	for i in $(cut -c-1 ${WWWDIR}/full.txt|sort -u); do
		mkdir -p ${WWWDIR}/${i}
		grep ^${i}\; ${WWWDIR}/full.txt > ${WWWDIR}/${i}/EAPI${i}.txt

		# sort by packages
		f_packages="$(cat ${WWWDIR}/${i}/EAPI${i}.txt| cut -d "${DL}" -f2|sort|uniq)"
		for u in ${f_packages}; do
			f_cat="$(echo $u|cut -d'/' -f1)"
			f_pak="$(echo $u|cut -d'/' -f2)"
			mkdir -p ${WWWDIR}/${i}/sort-by-package/${f_cat}
			grep "${u}" ${WWWDIR}/${i}/EAPI${i}.txt > ${WWWDIR}/${i}/sort-by-package/${f_cat}/${f_pak}.txt
		done
	
		mkdir -p ${WWWDIR}/${i}/sort-by-maintainer/
		for a in $(cat ${WWWDIR}/${i}/EAPI${i}.txt |cut -d "${DL}" -f3|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
			grep "${a}" ${WWWDIR}/${i}/EAPI${i}.txt > ${WWWDIR}/${i}/sort-by-maintainer/"$(echo ${a}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
		done
	done
}

eapi_pre_check() {
	local var=${1}
	if grep ^EAPI ${var} >/dev/null; then
		main ${var} $(grep ^EAPI ${var}|tr -d '"'|cut -d'=' -f2)
	else
		main ${var} 0
	fi
}

export -f eapi_pre_check main get_main_min
export SCRIPT_MODE WWWDIR PORTTREE DL

find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -print | parallel eapi_pre_check {}

${SCRIPT_MODE} && gen_sortings
