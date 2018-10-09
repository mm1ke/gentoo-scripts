#!/bin/bash

# Filename: eclassstats.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 05/05/2018

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
# lists eclass uses of the tree

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export PORTTREE=/usr/portage/
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/eclassstats/"

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
SCRIPT_NAME="eclassstats"
SCRIPT_SHORT="ECS"
SCRIPT_TYPE="stats"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/${SCRIPT_SHORT}-STA-ebuild_eclass_statistics"				#Index 0
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

main() {
	array_names
	local relative_path=${1}
	local category="$(echo ${relative_path}|cut -d'/' -f2)"
	local package="$(echo ${relative_path}|cut -d'/' -f3)"
	local filename="$(echo ${relative_path}|cut -d'/' -f4)"
	local packagename="${filename%.*}"
	local full_path="${PORTTREE}/${category}/${package}"
	local full_path_ebuild="${PORTTREE}/${category}/${package}/${filename}"
	local maintainer="$(get_main_min "${category}/${package}")"
	local full_md5path="${PORTTREE}/metadata/md5-cache/${category}/${packagename}"

	ebuild_eclass_file=$(get_eclasses_file ${full_md5path} ${full_path_ebuild})
	#ebuild_eclass_real=$(get_eclasses_real ${full_md5path})

	if [ -n "${ebuild_eclass_file}" ]; then
		if ${SCRIPT_MODE}; then
			echo "$(get_eapi ${full_path_ebuild})${DL}${category}/${package}${DL}${filename}${DL}${ebuild_eclass_file}${DL}${maintainer}" >> ${RUNNING_CHECKS[0]}/full.txt
		else
			echo "$(get_eapi ${full_path_ebuild})${DL}${category}/${package}${DL}${filename}${DL}${ebuild_eclass_file}${DL}${maintainer}"
		fi
	fi
}

# set the search depth
depth_set ${1}
# switch to the PORTTREE dir
cd ${PORTTREE}
# export important variables
export WORKDIR SCRIPT_SHORT
export -f main array_names

${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}


if ${SCRIPT_MODE}; then
	# create a list and create corresponding folders and files of all available
	# eclasses before running the check.
	# this way we also see eclasses without customers
	if ${TREE_IS_MASTER}; then
		eclass_list=( $(ls ${PORTTREE}/eclass/*.eclass) )
		eclass_list=( ${eclass_list[@]##*/} )
		for ecl in ${eclass_list[@]}; do
			mkdir -p ${RUNNING_CHECKS[0]}/sort-by-filter/${ecl}
			touch ${RUNNING_CHECKS[0]}/sort-by-filter/${ecl}/full.txt
		done
	fi
fi

find_func(){
	find ./${level} \( \
		-path ./scripts/\* -o \
		-path ./profiles/\* -o \
		-path ./packages/\* -o \
		-path ./licenses/\* -o \
		-path ./distfiles/\* -o \
		-path ./metadata/\* -o \
		-path ./eclass/\* -o \
		-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec egrep -l 'inherit' {} \; | parallel main {}
}

if [ "${1}" = "diff" ]; then
	TODAYCHECKS="${HASHTREE}/results/results-$(date -I).log"
	# default value true, thus we assume we can run in diff mode
	check_status=true

	# if /tmp/${SCRIPT_NAME} exist run in normal mode
	# this way it's possible to override the diff mode
	# this is usefull when the script got updates which should run
	# on the whole tree
	if ! [ -e "/tmp/${SCRIPT_NAME}" ] && [ -e ${TODAYCHECKS} ]; then
		for oldfull in ${RUNNING_CHECKS[@]}; do
			# SCRIPT_TYPE isn't used in the ebuilds usually,
			# thus it has to be set with the other important variables
			#
			# first set the full.txt path from the old log
			OLDLOG="${SITEDIR}/${SCRIPT_TYPE}/${oldfull/${WORKDIR}/}/full.txt"
			# check if the oldlog exist (don't have to be)
			if [ -e ${OLDLOG} ]; then
				# copy old result file to workdir and filter the result
				cp ${OLDLOG} ${oldfull}/
				for cpak in $(cat ${TODAYCHECKS}); do
					# the substring replacement is important (replaces '/' to '\/'), otherwise the sed command
					# will fail because '/' aren't escapted. also remove first slash
					pakcat="${cpak:1}"
					sed -i "/${pakcat//\//\\/}${DL}/d" ${oldfull}/full.txt
				done
			fi
		done
	else
		# disable diff checking
		check_status=false
	fi

	# only run if we could copy all old full results
	if ${check_status}; then
		find $(sed -e 's/^/./' ${TODAYCHECKS}) -type f -name "*.ebuild" \
			-exec egrep -l 'inherit' {} \; | parallel main {}
	else
		find_func
	fi
else
	find_func
fi

if ${SCRIPT_MODE}; then

	for file in $(cat ${RUNNING_CHECKS[0]}/full.txt); do
		for ec in $(echo ${file}|cut -d'|' -f4|tr ':' ' '); do
			mkdir -p ${RUNNING_CHECKS[0]}/sort-by-filter/${ec}.eclass
			echo ${file} >> ${RUNNING_CHECKS[0]}/sort-by-filter/${ec}.eclass/full.txt
		done
	done

	for ecd in $(ls ${RUNNING_CHECKS[0]}/sort-by-filter/); do
		gen_sort_main_v2 ${RUNNING_CHECKS[0]}/sort-by-filter/${ecd} 5
		gen_sort_pak_v2 ${RUNNING_CHECKS[0]}/sort-by-filter/${ecd} 2
	done

	gen_sort_main_v2 ${RUNNING_CHECKS[0]} 5
	gen_sort_pak_v2 ${RUNNING_CHECKS[0]} 2

	copy_checks ${SCRIPT_TYPE}
	rm -rf ${WORKDIR}
fi
