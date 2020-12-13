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
#${TREE_IS_MASTER} || exit 0		# only works with gentoo main tree
#${ENABLE_MD5} || exit 0				# only works with md5 cache
#${ENABLE_GIT} || exit 0				# only works with git tree

SCRIPT_NAME="trailwhite"
SCRIPT_SHORT="TRW"
SCRIPT_TYPE="checks"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/${SCRIPT_SHORT}-IMP-ebuild_leading_trailing_whitespaces_in_variables"	# Index 0
	)
}
array_names
#
### IMPORTANT SETTINGS END ###
#

main() {
	array_names

	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f1)"
	local package="$(echo ${full_package}|cut -d'/' -f2)"
	local filename="$(echo ${full_package}|cut -d'/' -f3)"

	local maintainer="$(get_main_min "${category}/${package}")"

	local _varibales="DESCRIPTION LICENSE KEYWORDS IUSE RDEPEND DEPEND SRC_URI"
	local _tl_vars=( )
	for var in ${_varibales}; do
		if $(egrep -q "^${var}=\" |^${var}=\".* \"$" ${full_package}); then
			_tl_vars+=( ${var} )
		fi
	done

	if [ -n "${_tl_vars}" ]; then
		if ${SCRIPT_MODE}; then
			echo "${category}/${package}${DL}${filename}${DL}$(echo ${_tl_vars[@]}|tr ' ' ':')${DL}${maintainer}" >> ${RUNNING_CHECKS[0]}/full.txt
		else
			echo "${category}/${package}${DL}${filename}${DL}$(echo ${_tl_vars[@]}|tr ' ' ':')${DL}${maintainer}"
		fi
	fi
}


find_func(){
	find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
		-type f -name "*.ebuild" -print | parallel main {}
}

gen_results(){
	if ${SCRIPT_MODE}; then
		sort_result_v2
		gen_sort_main_v3
		gen_sort_pak_v3

		for file in $(cat ${RUNNING_CHECKS[0]}/full.txt); do
			for ec in $(echo ${file}|cut -d'|' -f3|tr ':' ' '); do
				mkdir -p ${RUNNING_CHECKS[0]}/sort-by-filter/${ec}
				echo ${file} >> ${RUNNING_CHECKS[0]}/sort-by-filter/${ec}/full.txt
			done
		done

		for ecd in $(ls ${RUNNING_CHECKS[0]}/sort-by-filter/); do
			gen_sort_main_v3 ${RUNNING_CHECKS[0]}/sort-by-filter/${ecd}
			gen_sort_pak_v3 ${RUNNING_CHECKS[0]}/sort-by-filter/${ecd}
		done

		copy_checks ${SCRIPT_TYPE}
	fi
}

cd ${PORTTREE}
export -f main get_main_min array_names
export WORKDIR SCRIPT_SHORT
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}
depth_set_v2 ${1}
${SCRIPT_MODE} && rm -rf ${WORKDIR}
