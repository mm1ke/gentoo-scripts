#!/bin/bash

# Filename: deadeclasses.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 24/05/2018

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
# lists deprecated eclasses

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export PORTTREE=/usr/portage/
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/deadeclasses/"

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

# feature requirements
#${TREE_IS_MASTER} || exit 0
#${ENABLE_MD5} || exit 0
#${ENABLE_GIT} || exit 0

SCRIPT_NAME="deadeclasses"
SCRIPT_SHORT="DEL"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"
SCRIPT_TYPE="checks"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_deprecated_eclasses"				#Index 0
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

main() {
	array_names
	local relative_path=${1}
	local category="$(echo ${relative_path}|cut -d'/' -f1)"
	local package="$(echo ${relative_path}|cut -d'/' -f2)"
	local filename="$(echo ${relative_path}|cut -d'/' -f3)"
	local packagename="${filename%.*}"
	local full_path="${PORTTREE}/${category}/${package}"
	local full_path_ebuild="${PORTTREE}/${category}/${package}/${filename}"
	local maintainer="$(get_main_min "${category}/${package}")"
	# https://github.com/gentoo/portage/blob/master/repoman/lib/repoman/modules/linechecks/deprecated/inherit.py
	local dead_eclasses=( readme.gentoo autotools-multilib autotools-utils base bash-completion boost-utils clutter cmake-utils confutils distutils epatch fdo-mime games gems git-2 gpe gst-plugins-bad gst-plugins-base gst-plugins-good gst-plugins-ugly gst-plugins10 ltprune mono python ruby user versionator x-modular xfconf )
	local found_usage=( )

	for eclass in ${dead_eclasses[@]}; do
		if $(check_eclasses_usage ${full_path_ebuild} ${eclass}); then
			found_usage+=( ${eclass} )
		fi
	done


	if [ -n "${found_usage}" ]; then
		if ${SCRIPT_MODE}; then
			echo "$(get_eapi ${full_path_ebuild})${DL}${category}/${package}${DL}${filename}${DL}$(echo ${found_usage[@]}|tr ' ' ':')${DL}${maintainer}" >> ${RUNNING_CHECKS[0]}/full.txt
		else
			echo "$(get_eapi ${full_path_ebuild})${DL}${category}/${package}${DL}${filename}${DL}$(echo ${found_usage[@]}|tr ' ' ':')${DL}${maintainer}"
		fi
	fi
}

find_func(){
	find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
		-type f -name "*.ebuild" -exec egrep -l "inherit" {} \; | parallel main {}
}

gen_results(){
	sort_result_v2 2

	if ${SCRIPT_MODE}; then
		for file in $(cat ${RUNNING_CHECKS[0]}/full.txt); do
			for ec in $(echo ${file}|cut -d'|' -f4|tr ':' ' '); do
				mkdir -p ${RUNNING_CHECKS[0]}/sort-by-filter/${ec}.eclass
				echo ${file} >> ${RUNNING_CHECKS[0]}/sort-by-filter/${ec}.eclass/full.txt
			done
		done

		for ecd in $(ls ${RUNNING_CHECKS[0]}/sort-by-filter/); do
			gen_sort_main_v3 ${RUNNING_CHECKS[0]}/sort-by-filter/${ecd}
			gen_sort_pak_v3 ${RUNNING_CHECKS[0]}/sort-by-filter/${ecd}
		done

		gen_sort_main_v3
		gen_sort_pak_v3

		copy_checks ${SCRIPT_TYPE}
	fi
}

# switch to the PORTTREE dir
cd ${PORTTREE}
# export important variables
export WORKDIR SCRIPT_SHORT
export -f main array_names
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}
# set the search depth
depth_set_v2 ${1}
# cleanup
${SCRIPT_MODE} && rm -rf ${WORKDIR}
