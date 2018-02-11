#!/bin/bash

# Filename: tmpcheck.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 12/01/2018

# Copyright (C) 2018  Michael Mair-Keimberger
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
#	prototype script for new scripts

#
### IMPORTANT SETTINGS START ###
#
DEBUG=false
SCRIPT_NAME="dupuse"
SCRIPT_MODE=false
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"
PORTTREE="/usr/portage/"
DL='|'
# set scriptmode=true on host s6
WWWDIR="${HOME}/${SCRIPT_NAME}/"
if [ "$(hostname)" = s6 ]; then
	SCRIPT_MODE=true
	WWWDIR="/var/www/gentoo.levelnine.at/${SCRIPT_NAME}/"
fi
# get dirpath and load funcs.sh
startdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${startdir}/funcs.sh ]; then
	source ${startdir}/funcs.sh
else
	echo "Missing funcs.sh"
	exit 1
fi
# switch to the PORTTREE dir
cd ${PORTTREE}
# set the search depth
depth_set ${1}
# export important variables
export PORTTREE WORKDIR SCRIPT_MODE DL DEBUG
#
### IMPORTANT SETTINGS STOP ###
#

main() {
	local absolute_path=${1}
	local category="$(echo ${absolute_path}|cut -d'/' -f2)"
	local package="$(echo ${absolute_path}|cut -d'/' -f3)"
#	local filename="$(echo ${absolute_path}|cut -d'/' -f4)"
#	local packagename="${filename%.*}"
#	local full_path="${PORTTREE}/${category}/${package}"
#	local full_path_ebuild="${PORTTREE}/${category}/${package}/${filename}"
	local maintainer="$(get_main_min "${category}/${package}")"

	localuses="$(grep "flag name" ${absolute_path} | cut -d'"' -f2)"

	if [ -n "${localuses}" ]; then
		for use in ${localuses}; do
			if $(tail -n+6 ${PORTTREE}/profiles/use.desc|cut -d'-' -f1|grep "\<${use}\>" > /dev/null); then
				dupuse="${use}:${dupuse}"
			fi
		done
	fi

	if [ -n "${dupuse}" ]; then
		if ${SCRIPT_MODE}; then
			echo "${category}/${package}${DL}${dupuse::-1}${DL}${maintainer}" >> ${WORKDIR}/full.txt
		else
			echo "${category}/${package}${DL}${dupuse::-1}${DL}${maintainer}"
		fi
	fi

}

export -f main

${SCRIPT_MODE} && mkdir -p ${WORKDIR}

find ./${level} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.xml" -print | parallel main {}

if ${SCRIPT_MODE}; then
	gen_sort_main ${WORKDIR}/full.txt 3 ${WORKDIR} ${DL}
	gen_sort_pak ${WORKDIR}/full.txt 1 ${WORKDIR} ${DL}

	script_mode_copy
fi
