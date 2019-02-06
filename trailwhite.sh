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

# feature requirements
#${TREE_IS_MASTER} || exit 0
#${ENABLE_MD5} || exit 0
#${ENABLE_GIT} || exit 0

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
### IMPORTANT SETTINGS STOP ###
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

depth_set ${1}
cd ${PORTTREE}
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}
export -f main get_main_min array_names
export WORKDIR SCRIPT_SHORT

find_func(){
	if [ "${1}" = "full" ]; then
		searchp=( $(find ${PORTTREE} -mindepth 1 -maxdepth 1 \
			-type d -regextype sed -regex "./*[a-z0-9].*-[a-z0-9].*" -printf '%P\n') )
		# virtual wouldn't be included by the find command, adding it manually if
		# it's present
		[ -e ${PORTTREE}/virtual ] && searchp+=( "virtual" )
		# full provides only categories so we need maxd=2 and mind=2
		# setting both vars to 1 because the find command adds 1 anyway
		MAXD=1
		MIND=1
	elif [ "${1}" = "diff" ]; then
		searchp=( $(sed -e 's/^.//' ${TODAYCHECKS}) )
		# diff provides categories/package so we need maxd=1 and mind=1
		# setting both vars to 0 because the find command adds 1 anyway
		MAXD=0
		MIND=0
	elif [ -z "${1}" ]; then
		echo "No directory given. Please fix your script"
		exit 1
	else
		searchp=( ${1} )
	fi

	find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
		-type f -name "*.ebuild" -print | parallel main {}
}

gen_results(){
	if ${SCRIPT_MODE}; then
		sort_result ${RUNNING_CHECKS[0]}
		gen_sort_main_v2 ${RUNNING_CHECKS[0]} 4
		gen_sort_pak_v2 ${RUNNING_CHECKS[0]} 1

		for file in $(cat ${RUNNING_CHECKS[0]}/full.txt); do
			for ec in $(echo ${file}|cut -d'|' -f3|tr ':' ' '); do
				mkdir -p ${RUNNING_CHECKS[0]}/sort-by-filter/${ec}
				echo ${file} >> ${RUNNING_CHECKS[0]}/sort-by-filter/${ec}/full.txt
			done
		done

		for ecd in $(ls ${RUNNING_CHECKS[0]}/sort-by-filter/); do
			gen_sort_main_v2 ${RUNNING_CHECKS[0]}/sort-by-filter/${ecd} 4
			gen_sort_pak_v2 ${RUNNING_CHECKS[0]}/sort-by-filter/${ecd} 1
		done

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
			find_func ${1}
			# remove dropped packages
			diff_rm_dropped_paks 1
			gen_results
		fi
	else
		find_func full
		gen_results
	fi
else
	find_func ${1}
	gen_results
fi

${SCRIPT_MODE} && rm -rf ${WORKDIR}
