#!/bin/bash

# Filename: trailwhite.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 15/04/2018

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
# a spinoff of simplechecks, only for finding trailing and leading whitespaces
# in variables

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export PORTTREE=/usr/portage/
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/trailwhite/"

# load repo specific settings
startdir="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
if [ -e ${startdir}/repo ]; then
	source ${startdir}/repo
fi

# get dirpath and load funcs.sh
realdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${realdir}/_funcs.sh ]; then
	source ${realdir}/_funcs.sh
else
	echo "Missing _funcs.sh"
	exit 1
fi

#
### IMPORTANT SETTINGS START ###
#
SCRIPT_NAME="trailwhite"
SCRIPT_SHORT="TRW"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/${SCRIPT_SHORT}-IMP-ebuild_leading_trailing_whitespaces_in_variables"	# Index 0
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

main() {
	array_names

	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package="$(echo ${full_package}|cut -d'/' -f3)"
	local filename="$(echo ${full_package}|cut -d'/' -f4)"

	local maintainer="$(get_main_min "${category}/${package}")"

	if ${SCRIPT_MODE}; then
		echo "${VARI}${category}/${package}${DL}${filename}${DL}${maintainer}" >> ${RUNNING_CHECKS[0]}/full.txt
	else
		echo "${VARI}${RUNNING_CHECKS[0]##*/}${DL}${category}/${package}${DL}${filename}${DL}${maintainer}"
	fi
}

depth_set ${1}
cd ${PORTTREE}
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}
export -f main get_main_min array_names
export WORKDIR SCRIPT_SHORT

# ebuild_leading_trailing_whitespaces_in_variables
_varibales="DESCRIPTION LICENSE KEYWORDS IUSE RDEPEND DEPEND SRC_URI"
for var in ${_varibales}; do
	export VARI="${var}${DL}"
	find ./${level} \( \
		-path ./scripts/\* -o \
		-path ./profiles/\* -o \
		-path ./packages/\* -o \
		-path ./licenses/\* -o \
		-path ./distfiles/\* -o \
		-path ./metadata/\* -o \
		-path ./eclass/\* -o \
		-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec egrep -l "^${var}=\" |^${var}=\".* \"$" {} \; | parallel main {}

	if ${SCRIPT_MODE}; then
		mkdir -p ${RUNNING_CHECKS[0]}/sort-by-filter/${var}/
		grep "^${VARI}" ${RUNNING_CHECKS[0]}/full.txt > ${RUNNING_CHECKS[0]}/sort-by-filter/${var}/full.txt
		gen_sort_main_v2 ${RUNNING_CHECKS[0]}/sort-by-filter/${var}/ 4
		gen_sort_pak_v2 ${RUNNING_CHECKS[0]}/sort-by-filter/${var}/ 2
	fi
done

if ${SCRIPT_MODE}; then
	gen_sort_main_v2 ${RUNNING_CHECKS[0]} 4
	gen_sort_pak_v2 ${RUNNING_CHECKS[0]} 2

	copy_checks checks
	rm -rf ${WORKDIR}
fi
