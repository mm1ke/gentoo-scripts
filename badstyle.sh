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
#export SCRIPT_MODE=false
#export SITEDIR="${HOME}/badstyle/"
#export PORTTREE=/usr/portage/

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

# only works with md5-cache
${ENABLE_MD5} || exit 0

#
### IMPORTANT SETTINGS START ###
#
SCRIPT_NAME="badstyle"
SCRIPT_SHORT="BAS"
SCRIPT_TYPE="checks"
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
	repo_categories
	local absolute_path=${1}
	local category="$(echo ${absolute_path}|cut -d'/' -f1)"
	local package="$(echo ${absolute_path}|cut -d'/' -f2)"
	local filename="$(echo ${absolute_path}|cut -d'/' -f3)"
	local packagename="${filename%.*}"
	local maintainer="$(get_main_min "${category}/${package}")"

	local used_cats=( )
	for cat in ${all_cat[@]}; do
		if $(grep DEPEND /${PORTTREE}/metadata/md5-cache/${category}/${packagename} | grep -q ${cat}); then
			used_cats+=( "${cat}" )
		fi
	done

	if [ -n "${used_cats}" ]; then
		x=0
		y="${#used_cats[@]}"
		z=( )

		for a in ${used_cats[@]}; do
			for b in ${used_cats[@]:${x}:${y}}; do
				if [ "${a}" = "${b}" ]; then
					z+=( "${a}/.*${b}/.*" )
				else
					z+=( "${a}/.*${b}/.*|${b}/.*${a}/.*" )
				fi
			done
			# search the pattern
			x=$(expr ${x} + 1)
		done


		if $(grep "^[^#;]" ${absolute_path} | egrep -q "$(echo ${z[@]}|tr ' ' '|')" ); then
			if ${SCRIPT_MODE}; then
				echo "${category}/${package}${DL}${filename}${DL}${maintainer}" >> ${RUNNING_CHECKS[0]}/full.txt
			else
				echo "${category}/${package}${DL}${filename}${DL}${maintainer}"
			fi
		fi
	fi
}

# set the search depth
depth_set ${1}
# switch to the PORTTREE dir
cd ${PORTTREE}
# create a list of categories in ${PORTTREE}
repo_categories(){
	all_cat=( $(find ${PORTTREE} -mindepth 1 -maxdepth 1 -type d -regextype sed -regex "./*[a-z0-9].*-[a-z0-9].*" -printf '%P\n') )
	[ -e ${PORTTREE}/virtual ] && all_cat+=( "virtual" )
}
# export important variables and functions
export WORKDIR SCRIPT_SHORT
export -f main array_names repo_categories
# create all folders
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}

find_func(){
	if [ ${1} = "full" ]; then
		searchp=( $(find ${PORTTREE} -mindepth 1 -maxdepth 1 -type d -regextype sed -regex "./*[a-z0-9].*-[a-z0-9].*" -printf '%P\n') )
		[ -e ${PORTTREE}/virtual ] && searchp+=( "virtual" )
	else
		searchp=( ${1} )
	fi

	find ${searchp[@]} -type f -name "*.ebuild" -exec egrep -l "DEPEND" {} \; | parallel main {}
}

gen_results(){
	if ${SCRIPT_MODE}; then
		gen_sort_main_v2 ${RUNNING_CHECKS[0]} 3
		gen_sort_pak_v2 ${RUNNING_CHECKS[0]} 1

		copy_checks ${SCRIPT_TYPE}
	fi
}

if [ "${1}" = "diff" ]; then
	# if /tmp/${SCRIPT_NAME} exist run in normal mode
	# this way it's possible to override the diff mode
	# this is usefull when the script got updates which should run
	# on the whole tree
	if ! [ -e "/tmp/${SCRIPT_NAME}" ]; then

		TODAYCHECKS="${HASHTREE}/results/results-$(date -I).log"
		# only run diff mode if todaychecks exist and doesn't have zero bytes
		if [ -s ${TODAYCHECKS} ]; then

			# we need to copy all existing results first and remove packages which
			# were changed (listed in TODAYCHECKS). If no results file exists, do
			# nothing - the script would create a new one anyway
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

			# run the script only on the changed packages
			find $(sed -e 's/^.//' ${TODAYCHECKS}) -type f -name "*.ebuild" \
				-exec egrep -l "DEPEND" {} \; | parallel main {}
			gen_results
		fi
	else
		find_func
		gen_results
	fi
else
	find_func
	gen_results
fi

${SCRIPT_MODE} && rm -rf ${WORKDIR}
