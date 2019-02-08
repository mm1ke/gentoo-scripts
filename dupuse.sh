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

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export PORTTREE=/usr/portage/
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/dupuse/"

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
${TREE_IS_MASTER} || exit 0
#${ENABLE_MD5} || exit 0
#${ENABLE_GIT} || exit 0

SCRIPT_NAME="dupuse"
SCRIPT_SHORT="DUU"
SCRIPT_TYPE="checks"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-metadata_duplicate_useflag_description"									#Index 0
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

main() {
	array_names
	local absolute_path=${1}
	local category="$(echo ${absolute_path}|cut -d'/' -f1)"
	local package="$(echo ${absolute_path}|cut -d'/' -f2)"
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
			echo "${category}/${package}${DL}${dupuse::-1}${DL}${maintainer}" >> ${RUNNING_CHECKS[0]}/full.txt
		else
			echo "${category}/${package}${DL}${dupuse::-1}${DL}${maintainer}"
		fi
	fi
}

find_func(){
	find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
		-type f -name "*.xml" -print | parallel main {}
}

gen_results() {
	if ${SCRIPT_MODE}; then

		for file in $(cat ${RUNNING_CHECKS[0]}/full.txt); do
			for fp in $(echo ${file}|cut -d'|' -f2|tr ':' ' '); do
				mkdir -p ${RUNNING_CHECKS[0]}/sort-by-filter/${fp}
				echo ${file} >> ${RUNNING_CHECKS[0]}/sort-by-filter/${fp}/full.txt
			done
		done

		gen_sort_main_v2 ${RUNNING_CHECKS[0]} 3
		gen_sort_pak_v2 ${RUNNING_CHECKS[0]} 1

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
