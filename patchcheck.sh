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
SCRIPT_NAME="patchtest"
PORTTREE="/usr/portage"
WWWDIR="${HOME}/${SCRIPT_NAME}/"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}/"
DL='|'

startdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${startdir}/funcs.sh ]; then
	source ${startdir}/funcs.sh
else
	echo "Missing funcs.sh"
	exit 1
fi

if [ "$(hostname)" = s6 ]; then
	SCRIPT_MODE=true
	WWWDIR="/var/www/gentoo.levelnine.at/${SCRIPT_NAME}/"
fi

cd ${PORTTREE}
depth_set ${1}

main(){
	local package=${1}

	local category="$(echo ${package}|cut -d'/' -f2)"
	local package_name=${package##*/}
	local fullpath="/${PORTTREE}/${package}"

	if [ -e ${startdir}/whitelist ]; then
		source ${startdir}/whitelist
		for i in ${white_list[@]}; do
			whitelist+=("$(echo ${i}|cut -d';' -f1)")
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
				if ${SCRIPT_MODE}; then
					mkdir -p ${WORKDIR}/sort-by-package/${category}
					ls ${PORTTREE}/${category}/${package_name}/files/* > ${WORKDIR}/sort-by-package/${category}/${package_name}.txt
					echo -e "${category}/${package_name}${DL}${main}" >> ${WORKDIR}/full-with-maintainers.txt
				else
					echo "${category}/${package_name}${DL}${main}"
				fi
			fi
		fi
	fi
}

export -f main get_main_min
export WORKDIR PORTTREE SCRIPT_MODE DL startdir

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
	gen_sort_main ${WORKDIR}/full-with-maintainers.txt 2 ${WORKDIR} ${DL}

	mkdir -p ${WORKDIR/-/_}
	gen_sort_main ${WORKDIR}/full-with-maintainers.txt 2 ${WORKDIR/-/_}/${SCRIPT_NAME} ${DL}
	rm -rf /var/www/gentooqa.levelnine.at/results/${SCRIPT_NAME}*
	cp -r ${WORKDIR/-/_}/* /var/www/gentooqa.levelnine.at/results/checks/
	rm -rf ${WORKDIR/-/_}

	script_mode_copy
fi
