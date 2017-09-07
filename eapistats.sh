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



if [ "$(hostname)" = methusalix ]; then
	script_mode=true
	_wwwdir="/var/www/gentoo.levelnine.at/eapistats/"
	PORTTREE="/usr/portage/"
else
	script_mode=false
	_wwwdir="/home/ai/eapistats/"
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
	
	if ${script_mode}; then
		mkdir -p /${_wwwdir}/
		echo "${eapi};${category}/${package}/${filename};${maintainer}" >> /${_wwwdir}/full.txt
	else
		echo "${eapi};${category}/${package}/${filename};${maintainer}"
	fi
}

gen_sortings() {
	for i in $(cut -c-1 ${_wwwdir}/full.txt|sort -u); do
		mkdir -p ${_wwwdir}/${i}
		grep ^${i}\; ${_wwwdir}/full.txt > ${_wwwdir}/${i}/EAPI${i}.txt

		# sort by packages
		f_packages="$(cat ${_wwwdir}/${i}/EAPI${i}.txt| cut -d ';' -f2|sort|uniq)"
		for u in ${f_packages}; do
			f_cat="$(echo $i|cut -d'/' -f1)"
			f_pak="$(echo $i|cut -d'/' -f2)"
			mkdir -p ${_wwwdir}/${i}/sort-by-package/${f_cat}
			grep "${u}" ${_wwwdir}/${i}/EAPI${i}.txt > ${_wwwdir}/${i}/sort-by-package/${f_cat}/${f_pak}.txt
		done
	
		mkdir -p ${_wwwdir}/${i}/sort-by-maintainer/
		for a in $(cat ${_wwwdir}/${i}/EAPI${i}.txt |cut -d';' -f3|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
			grep "${a}" ${_wwwdir}/${i}/EAPI${i}.txt > ${_wwwdir}/${i}/sort-by-maintainer/"$(echo ${a}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
		done
	done
}

find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -print | while read -r line; do
	if grep ^EAPI $line >/dev/null; then
		main $line $(grep EAPI $line|tr -d '"'|cut -d'=' -f2)
	else
		main $line 0
	fi
done

${script_mode} && gen_sortings
