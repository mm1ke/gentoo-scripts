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

#override REPOTREE,FILERESULTS,RESULTSDIR settings
#export REPOTREE=/usr/portage/
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/deadeclasses/"

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
#${TREE_IS_MASTER} || exit 0		# only works with gentoo main tree
#${ENABLE_MD5} || exit 0				# only works with md5 cache
#${ENABLE_GIT} || exit 0				# only works with git tree

WORKDIR="/tmp/deadeclasses-${RANDOM}"
SCRIPT_TYPE="checks"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/ebuild_deprecated_eclasses"				#Index 0
	)
}
output_format(){
	index=(
		"$(get_eapi ${full_path_ebuild})${DL}${category}/${package}${DL}${filename}${DL}$(echo ${found_usage[@]}|tr ' ' ':')${DL}${maintainer}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_index0 <<- EOM
Lists ebuilds who use deprecated or obsolete eclasses.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|user:cmake-utils|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
user:cmake-utils                            list obsolete eclasse(s), seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
	description=( "${info_index0}" )
	echo "${description[$1]}"
}
#
### IMPORTANT SETTINGS END ###
#

main() {
	array_names
	local relative_path=${1}
	local category="$(echo ${relative_path}|cut -d'/' -f1)"
	local package="$(echo ${relative_path}|cut -d'/' -f2)"
	local filename="$(echo ${relative_path}|cut -d'/' -f3)"
	local packagename="${filename%.*}"
	local full_path="${REPOTREE}/${category}/${package}"
	local full_path_ebuild="${REPOTREE}/${category}/${package}/${filename}"
	local maintainer="$(get_main_min "${category}/${package}")"
	# https://github.com/gentoo/portage/blob/master/repoman/lib/repoman/modules/linechecks/deprecated/inherit.py
	local dead_eclasses=( readme.gentoo base bash-completion boost-utils clutter cmake-utils confutils distutils epatch fdo-mime games gems git-2 gpe gst-plugins-bad gst-plugins-base gst-plugins-good gst-plugins-ugly gst-plugins10 ltprune mono python ruby user versionator x-modular xfconf )
	local found_usage=( )

	output() {
		local id=${1}
		if ${FILERESULTS}; then
			output_format ${id} >> ${RUNNING_CHECKS[${id}]}/full.txt
		else
			output_format ${id}
		fi
	}

	for eclass in ${dead_eclasses[@]}; do
		if $(check_eclasses_usage ${full_path_ebuild} ${eclass}); then
			found_usage+=( ${eclass} )
		fi
	done


	if [ -n "${found_usage}" ]; then
		output 0
	fi
}

find_func(){
	find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
		-type f -name "*.ebuild" -exec egrep -l "inherit" {} \; | parallel main {}
}

gen_results(){
	if ${FILERESULTS}; then
		gen_descriptions
		sort_result_v2 2
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

array_names
# switch to the REPOTREE dir
cd ${REPOTREE}
# export important variables
export WORKDIR
export -f main array_names output_format
${FILERESULTS} && mkdir -p ${RUNNING_CHECKS[@]}
# set the search depth
depth_set_v2 ${1}
# cleanup
${FILERESULTS} && rm -rf ${WORKDIR}
