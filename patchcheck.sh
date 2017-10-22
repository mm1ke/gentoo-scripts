#!/bin/bash

# Filename: patchtest
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 07/08/2017

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
# simple scirpt to find unused scripts directories in the gentoo tree


SCRIPT_MODE=false
PORTTREE="/usr/portage"
WWWDIR="${HOME}/patchcheck/"
DL='|'

if [ "$(hostname)" = methusalix ]; then
	SCRIPT_MODE=true
	WWWDIR="/var/www/gentoo.levelnine.at/patchcheck/"
fi

${SCRIPT_MODE} && rm -rf ${WWWDIR}/*

startdir="$(dirname $(readlink -f $BASH_SOURCE))"
cd ${PORTTREE}

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
		_cat=${1%%/*}
		_pac=${1##*/}
		if [ -z "${_pac}" ] || [ "${_cat}" == "${_pac}" ]; then
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
for x in e.iterfind("./maintainer/email"):
	c+=(x.text+':')
print(c)
END`
	echo ${ret// /_}
}

main(){
	local package=${1}

	local category="$(echo ${package}|cut -d'/' -f2)"
	local package_name=${package##*/}
	local fullpath="/${PORTTREE}/${package}"

	if [ -e ${startdir}/whitelist ]; then
		source ${startdir}/whitelist
		for i in ${white_list[@]}; do
			whitelist+=("$(echo ${i}|cut -d'/' --output-delimiter='/' -f2,3)")
		done
	else
		whitelist=()
	fi
	# remove duplicates
	mapfile -t whitelist < <(printf '%s\n' "${whitelist[@]}"|sort -u)

	local eclasses="apache-module|elisp|vdr-plugin-2|games-mods|ruby-ng|readme.gentoo|readme.gentoo-r1|bzr|bitcoincore|gnatbuild|gnatbuild-r1|java-vm-2|mysql-cmake|mysql-multilib-r1|php-ext-source-r2|php-ext-source-r3|php-pear-r1|selinux-policy-2|toolchain-binutils|toolchain-glibc|x-modular"

	# check if the patches folder exist
	if [ -e ${fullpath}/files ]; then
		if ! echo ${whitelist[@]}|grep "${category}/${package_name}" > /dev/null; then
			if ! grep -E ".diff|.patch|FILESDIR|${eclasses}" ${fullpath}/*.ebuild >/dev/null; then
				main=$(get_main_min "${category}/${package_name}")
				if [ -z "${main}" ]; then
					main="maintainer-needed@gentoo.org:"
				fi
				if ${SCRIPT_MODE}; then
					mkdir -p ${WWWDIR}/sort-by-package/${category}
					ls ${PORTTREE}/${category}/${package_name}/files/* > ${WWWDIR}/sort-by-package/${category}/${package_name}.txt
					echo -e "${category}/${package_name}${DL}${main}" >> ${WWWDIR}/full-with-maintainers.txt
				else
					echo "${category}/${package_name}${DL}${main}"
				fi
			fi
		fi
	fi
}

export -f main get_main_min
export WWWDIR PORTTREE SCRIPT_MODE DL startdir

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
	for a in $(cat ${WWWDIR}/full-with-maintainers.txt |cut -d "${DL}" -f2|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
		mkdir -p ${WWWDIR}/sort-by-maintainer/
		grep "${a}" ${WWWDIR}/full-with-maintainers.txt > ${WWWDIR}/sort-by-maintainer/"$(echo ${a}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
	done
fi
