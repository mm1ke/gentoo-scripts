#!/bin/bash

# Filename: dupuse.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 11/02/2018

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
#	find duplicate use flag descriptions

#override REPOTREE,FILERESULTS,RESULTSDIR settings
#export REPOTREE=/usr/portage/
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/dupuse/"

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
${TREE_IS_MASTER} || exit 0			# only works with gentoo main tree
#${ENABLE_MD5} || exit 0				# only works with md5 cache
#${ENABLE_GIT} || exit 0				# only works with git tree

SCRIPT_TYPE="checks"
WORKDIR="/tmp/dupuse-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/metadata_duplicate_useflag_description"									#Index 0
	)
}
output_format(){
	index=(
		"${category}/${package}${DL}${dupuse::-1}${DL}${maintainer}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_index0 <<- EOM
Lists packages which define use flags locally in metadata.xml, which already exists as
a global use flag.

|||                  +------->  list of USE flags which already
||F                  |          exists as a global flag.
D|O                  |
A|R  dev-libs/foo | gtk[:X:qt:zlib] | developer@gentoo.org
T|M    |                                           |
A|A    |               ebuild maintainer(s)  <-----+
||T    +---> package category/name
EOM
	description=( "${info_index0}" )
	echo "${description[$1]}"
}
#
### IMPORTANT SETTINGS END ###
#

main() {
	array_names
	local absolute_path=${1}
	local category="$(echo ${absolute_path}|cut -d'/' -f1)"
	local package="$(echo ${absolute_path}|cut -d'/' -f2)"
	local maintainer="$(get_main_min "${category}/${package}")"

	output() {
		local id=${1}
		if ${FILERESULTS}; then
			output_format ${id} >> ${RUNNING_CHECKS[${id}]}/full.txt
		else
			output_format ${id}
		fi
	}

	localuses="$(grep "flag name" ${absolute_path} | cut -d'"' -f2)"

	if [ -n "${localuses}" ]; then
		for use in ${localuses}; do
			if $(tail -n+6 ${REPOTREE}/profiles/use.desc|cut -d'-' -f1|grep "\<${use}\>" > /dev/null); then
				dupuse="${use}:${dupuse}"
			fi
		done
	fi

	if [ -n "${dupuse}" ]; then
		output 0
	fi
}

find_func(){
	find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
		-type f -name "*.xml" -print | parallel main {}
}

gen_results() {
	if ${FILERESULTS}; then
		gen_descriptions
		sort_result_v2

		for file in $(cat ${RUNNING_CHECKS[0]}/full.txt); do
			for fp in $(echo ${file}|cut -d'|' -f2|tr ':' ' '); do
				mkdir -p ${RUNNING_CHECKS[0]}/sort-by-filter/${fp}
				echo ${file} >> ${RUNNING_CHECKS[0]}/sort-by-filter/${fp}/full.txt
			done
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
