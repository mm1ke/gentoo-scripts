#!/bin/bash

# Filename: eapistats.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 07/09/2017

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
# simple script for generating EAPI statistics

#override REPOTREE,FILERESULTS,RESULTSDIR settings
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/eapistats/"
#export REPOTREE=/usr/portage/

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

WORKDIR="/tmp/eapistats-${RANDOM}"
SCRIPT_TYPE="stats"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/ebuild_eapi_statistics"						#Index 0
		"${WORKDIR}/ebuild_eapi_live_statistics"			#Index 1
	)
}
output_format(){
	index=(
		"${eapi}${DL}${category}/${package}${DL}${filename}${DL}${maintainer}${openbugs}"
		"${eapi}${DL}${category}/${package}${DL}${filename}${DL}${maintainer}${openbugs}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_default0 <<- EOM
||F  +----> ebuild EAPI     +----> full ebuild filename
D|O  |                      |
A|R  7 | dev-libs/foo | foo-1.12-r2.ebuild | developer@gentoo.org
T|M       |                                                  |
A|A       |                        ebuild maintainer(s) <----+
||T       +----> package category/name
EOM
read -r -d '' info_index0 <<- EOM
A simple list of all ebuilds with it's corresponding EAPI Version. Also includes all maintainers to the package
<a href=ebuild_eapi_statistics-detailed.html>EAPI Statistics</a>

${info_default0}
EOM
read -r -d '' info_index1 <<- EOM
A simple list of all live ebuilds and it's corresponding EAPI Version and maintainers.

${info_default0}
EOM
	description=( "${info_index0}" "${info_index1}" )
	echo "${description[$1]}"
}
#
### IMPORTANT SETTINGS END ###
#

main() {
	array_names
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f1)"
	local package="$(echo ${full_package}|cut -d'/' -f2)"
	local filename="$(echo ${full_package}|cut -d'/' -f3)"
	local packagename="${filename%.*}"
	local fileversion="${packagename/${package}-/}"
	local maintainer="$(get_main_min "${category}/${package}")"
	local openbugs="$(get_bugs ${category}/${package})"
	if ! [ -z "${openbugs}" ]; then
		openbugs="${DL}${openbugs}"
	fi
	local eapi="$(get_eapi ${full_package})"

	output() {
		local id=${1}
		if ${FILERESULTS}; then
			output_format ${id} >> ${RUNNING_CHECKS[${id}]}/full.txt
		else
			echo "${RUNNING_CHECKS[${checkid}]##*/}${DL}$(output_format ${id})"
		fi
	}

	if $(echo ${fileversion}|grep -q 9999); then
		output 1
	fi

	output 0
}


find_func(){
	find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
		-type f -name "*.ebuild" -print | parallel main {}
}

gen_results() {
	if ${FILERESULTS}; then
		gen_descriptions
		sort_result_v2 2
		# filter after EAPI
		for eapi in $(cut -c-1 ${RUNNING_CHECKS[0]}/full.txt|sort -u); do
			mkdir -p ${RUNNING_CHECKS[0]}/sort-by-eapi/EAPI${eapi}
			grep ^${eapi}${DL} ${RUNNING_CHECKS[0]}/full.txt > ${RUNNING_CHECKS[0]}/sort-by-eapi/EAPI${eapi}/full.txt

			gen_sort_main_v3 ${RUNNING_CHECKS[0]}/sort-by-eapi/EAPI${eapi}/full.txt
			gen_sort_pak_v3 ${RUNNING_CHECKS[0]}/sort-by-eapi/EAPI${eapi}/full.txt
		done
		gen_sort_main_v3 ${RUNNING_CHECKS[0]}

		for eapi in $(cut -c-1 ${RUNNING_CHECKS[1]}/full.txt|sort -u); do
			mkdir -p ${RUNNING_CHECKS[1]}/sort-by-eapi/EAPI${eapi}
			grep ^${eapi}${DL} ${RUNNING_CHECKS[1]}/full.txt > ${RUNNING_CHECKS[1]}/sort-by-eapi/EAPI${eapi}/full.txt

			gen_sort_main_v3 ${RUNNING_CHECKS[1]}/sort-by-eapi/EAPI${eapi}/full.txt
			gen_sort_pak_v3 ${RUNNING_CHECKS[1]}/sort-by-eapi/EAPI${eapi}/full.txt
		done

		gen_sort_main_v3 ${RUNNING_CHECKS[1]}
		gen_sort_pak_v3 ${RUNNING_CHECKS[1]}

		copy_checks ${SCRIPT_TYPE}
		rm -rf ${WORKDIR}
	fi
}

array_names
cd ${REPOTREE}
export -f main array_names output_format
export WORKDIR
${FILERESULTS} && mkdir -p ${RUNNING_CHECKS[@]}
depth_set_v2 ${1}
${FILERESULTS} && rm -rf ${WORKDIR}
