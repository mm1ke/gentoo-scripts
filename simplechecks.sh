#!/bin/bash

# Filename: simplechecks.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 26/08/2017

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
# This script finds simple errors in ebuilds and other files. For now it can
# 	ebuilds: check for trailing whitespaces
# 	metadata: mixed indentation (mixed tabs & whitespaces)



if [ "$(hostname)" = methusalix ]; then
	script_mode=true
	_wwwdir="/var/www/gentoo.levelnine.at/simplechecks/"
	PORTTREE="/usr/portage/"
else
	script_mode=false
	_wwwdir="/home/ai/simplechecks/"
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
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package="$(echo ${full_package}|cut -d'/' -f3)"
	local filename="$(echo ${full_package}|cut -d'/' -f4)"

	local maintainer="$(get_main_min "${category}/${package}")"
	if [ -z "${maintainer}" ]; then
			maintainer="maintainer-needed@gentoo.org:"
	fi

	if ${script_mode}; then
		mkdir -p /${_wwwdir}/${NAME}/
		echo "${category}/${package}/${filename};${maintainer}" >> /${_wwwdir}/${NAME}/${NAME}.txt
	else
		echo "${category}/${package}/${filename};${maintainer}"
	fi
}

gen_sortings() {
	# sort by packages
	f_packages="$(cat ${_wwwdir}/${NAME}/${NAME}.txt| cut -d ';' -f1|sort|uniq)"
	for i in ${f_packages}; do
		f_cat="$(echo $i|cut -d'/' -f1)"
		f_pak="$(echo $i|cut -d'/' -f2)"
		mkdir -p ${_wwwdir}/${NAME}/sort-by-package/${f_cat}
		grep "${i}" ${_wwwdir}/${NAME}/${NAME}.txt > ${_wwwdir}/${NAME}/sort-by-package/${f_cat}/${f_pak}.txt
	done

	mkdir -p ${_wwwdir}/${NAME}/sort-by-maintainer/
	# sort by maintainer, ignoring "good" codes
	for a in $(cat ${_wwwdir}/${NAME}/${NAME}.txt |cut -d';' -f2|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
		grep "${a}" ${_wwwdir}/${NAME}/${NAME}.txt > ${_wwwdir}/${NAME}/sort-by-maintainer/"$(echo ${a}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
	done
}

# find trailing whitespaces
NAME="trailing_whitespaces"
find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec egrep -l " +$" {} \; | while read -r line; do
	main ${line}
done
${script_mode} && gen_sortings

NAME="mixed_indentation"
find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.xml" -exec grep -l "^ " {} \; | while read -r line; do
	if grep $'\t' $line >/dev/null; then
		main $line
	fi
done
${script_mode} && gen_sortings

NAME="gentoo_mirror_missuse"
find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l 'SRC_URI="mirror://gentoo' {} \; | while read -r line; do
	main $line
done
${script_mode} && gen_sortings

NAME="epatch_in_eapi6"
find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l 'epatch' {} \; | while read -r line; do
	if [ "$(grep EAPI $line|tr -d '"'|cut -d'=' -f2)" = "6" ]; then
		main $line
	fi
done
${script_mode} && gen_sortings

NAME="dohtml_in_eapi6"
find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l 'dohtml' {} \; | while read -r line; do
	if [ "$(grep EAPI $line|tr -d '"'|cut -d'=' -f2)" = "6" ]; then
		main $line
	fi
done
${script_mode} && gen_sortings

NAME="DESCRIPTION_over_80"
find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l 'DESCRIPTION' {} \; | while read -r line; do
	if [ $(grep DESCRIPTION $line | wc -m) -gt 95 ]; then
		main $line
	fi
done
${script_mode} && gen_sortings

#NAME="missing_LICENSE"
#find ./${level}  \( \
#	-path ./scripts/\* -o \
#	-path ./profiles/\* -o \
#	-path ./packages/\* -o \
#	-path ./licenses/\* -o \
#	-path ./distfiles/\* -o \
#	-path ./metadata/\* -o \
#	-path ./.git/\* \) -prune -o -type f \( -name "*.ebuild" -o -name "*.eclass" \) -exec grep -L '^LICENSE' {} \; | while read -r line; do
#	main $line
#done
#${script_mode} && gen_sortings

#NAME="missing_SLOT"
#find ./${level}  \( \
#	-path ./scripts/\* -o \
#	-path ./profiles/\* -o \
#	-path ./packages/\* -o \
#	-path ./licenses/\* -o \
#	-path ./distfiles/\* -o \
#	-path ./metadata/\* -o \
#	-path ./eclass/\* -o \
#	-path ./virtual/\* -o \
#	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -L '^SLOT' {} \; | while read -r line; do
#	main $line
#done
#${script_mode} && gen_sortings
#
