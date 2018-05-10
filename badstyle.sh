#!/bin/bash

# Filename: badstyle.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 14/01/2018

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
#	checks for multiple package dependencies in one line

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#SCRIPT_MODE=false
#SITEDIR="${HOME}/badstyle/"
#PORTTREE=/usr/portage/

# get dirpath and load funcs.sh
startdir="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
if [ -e ${startdir}/funcs.sh ]; then
	source ${startdir}/funcs.sh
else
	echo "Missing funcs.sh"
	exit 1
fi

#
### IMPORTANT SETTINGS START ###
#
SCRIPT_NAME="badstyle"
SCRIPT_SHORT="BAS"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-IMP-ebuild_multiple_deps_per_line"					#Index 0
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

main() {
	array_names
	local absolute_path=${1}
	local category="$(echo ${absolute_path}|cut -d'/' -f2)"
	local package="$(echo ${absolute_path}|cut -d'/' -f3)"
	local filename="$(echo ${absolute_path}|cut -d'/' -f4)"
	local maintainer="$(get_main_min "${category}/${package}")"

	if ${SCRIPT_MODE}; then
		echo "${category}/${package}${DL}${filename}${DL}${maintainer}" >> ${RUNNING_CHECKS[0]}/full.txt
	else
		echo "${category}/${package}${DL}${filename}${DL}${maintainer}"
	fi
}

# set the search depth
depth_set ${1}
# switch to the PORTTREE dir
cd ${PORTTREE}
# export important variables and functions
export WORKDIR SCRIPT_SHORT
export -f main array_names
# create all folders
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}

pattern=(
	"dev-libs/openssl:dev-libs/libressl"
	)

for pat in ${pattern[@]}; do
	a="$(echo ${pat}|cut -d':' -f1)"
	b="$(echo ${pat}|cut -d':' -f2)"

	find ./${level} \( \
		-path ./scripts/\* -o \
		-path ./profiles/\* -o \
		-path ./packages/\* -o \
		-path ./licenses/\* -o \
		-path ./distfiles/\* -o \
		-path ./metadata/\* -o \
		-path ./eclass/\* -o \
		-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec egrep -l "${a}.*${b}|${b}.*${a}" {} \; | parallel main {}
done

if ${SCRIPT_MODE}; then
	gen_sort_main_v2 ${RUNNING_CHECKS[0]} 3
	gen_sort_pak_v2 ${RUNNING_CHECKS[0]} 1

	copy_checks checks
	rm -rf ${WORKDIR}
fi
