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

MAXD=2
MIND=2

if [ "$(hostname)" = methusalix ]; then
	PORTTREE="/usr/portage"
	script_mode=true
	script_mode_dir="/var/www/gentoo.levelnine.at/patchcheck/"
else
	PORTTREE="/mnt/data/gentoo/"
	script_mode=false
fi
cd ${PORTTREE}

usage() {
	echo "You need an argument"
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
for i in e:
	for v in i.iter('maintainer'):
		b=str(v[0].text)
		c+=str(b)+':'
print(c)
END`
	echo $ret
}

if $script_mode; then
	rm -rf ${script_mode_dir}/*
fi

main(){
	package=${1}

	local category="$(echo ${package}|cut -d'/' -f2)"
	local package_name=${package##*/}
	local fullpath="/${PORTTREE}/${package}"

	# check if the patches folder exist
	if [ -e ${fullpath}/files ]; then
		if ! grep -E ".diff|.patch|FILESDIR|apache-module|elisp|vdr-plugin-2|games-mods|ruby-ng|readme.gentoo|readme.gentoo-r1|bzr|bitcoincore|gnatbuild|gnatbuild-r1|java-vm-2|mysql-cmake|mysql-multilib-r1|php-ext-source-r2|php-ext-source-r3|php-pear-r1|selinux-policy-2|toolchain-binutils|toolchain-glibc|x-modular" ${fullpath}/*.ebuild >/dev/null; then
			if $script_mode; then
				main=$(get_main_min "${category}/${package_name}")
				mkdir -p ${script_mode_dir}/sort-by-package/${category}
				ls ${PORTTREE}/${category}/${package_name}/files/* > ${script_mode_dir}/sort-by-package/${category}/${package_name}.txt
				echo "${category}/${package_name}" >> ${script_mode_dir}/full.txt
				echo -e "${category}/${package_name}\t\t${main}" >> ${script_mode_dir}/full-with-maintainers.txt

			else
				echo "${category}/${package_name}"
			fi
		fi
	fi
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


if $script_mode; then
	for a in $(cat ${script_mode_dir}/full-with-maintainers.txt |cut -d$'\t' -f3|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
		mkdir -p ${script_mode_dir}/sort-by-maintainer/
		grep "${a}" ${script_mode_dir}/full-with-maintainers.txt > ${script_mode_dir}/sort-by-maintainer/"$(echo ${a}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
	done
fi
