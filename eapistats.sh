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

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/eapistats/"
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

#
### IMPORTANT SETTINGS START ###
#
SCRIPT_NAME="eapistats"
SCRIPT_SHORT="EAS"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"
SCRIPT_TYPE="stats"

array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-STA-ebuild_eapi_statistics"						#Index 0
	"${WORKDIR}/${SCRIPT_SHORT}-STA-ebuild_eapi_live_statistics"			#Index 1
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
	local packagename="${filename%.*}"
	local fileversion="${packagename/${package}-/}"
	local maintainer="$(get_main_min "${category}/${package}")"
	local openbugs="$(get_bugs ${category}/${package})"
	if ! [ -z "${openbugs}" ]; then
		openbugs="${DL}${openbugs}"
	fi
	local eapi="$(get_eapi ${full_package})"

	if $(echo ${fileversion}|grep -q 9999); then
		if ${SCRIPT_MODE}; then
			echo "${eapi}${DL}${category}/${package}${DL}${filename}${DL}${maintainer}${openbugs}" >> ${RUNNING_CHECKS[1]}/full.txt
		else
			echo "live_stats${DL}${eapi}${DL}${category}/${package}${DL}${filename}${DL}${maintainer}${openbugs}"
		fi
	fi

	if ${SCRIPT_MODE}; then
		echo "${eapi}${DL}${category}/${package}${DL}${filename}${DL}${maintainer}${openbugs}" >> ${RUNNING_CHECKS[0]}/full.txt
	else
		echo "${eapi}${DL}${category}/${package}${DL}${filename}${DL}${maintainer}${openbugs}"
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

gen_results() {
	if ${SCRIPT_MODE}; then
		# filter after EAPI
		for eapi in $(cut -c-1 ${RUNNING_CHECKS[0]}/full.txt|sort -u); do
			mkdir -p ${RUNNING_CHECKS[0]}/sort-by-eapi/EAPI${eapi}
			grep ^${eapi}${DL} ${RUNNING_CHECKS[0]}/full.txt > ${RUNNING_CHECKS[0]}/sort-by-eapi/EAPI${eapi}/full.txt

			gen_sort_main_v2 ${RUNNING_CHECKS[0]}/sort-by-eapi/EAPI${eapi}/full.txt 4
			gen_sort_pak_v2 ${RUNNING_CHECKS[0]}/sort-by-eapi/EAPI${eapi}/full.txt 2
		done
		gen_sort_main_v2 ${RUNNING_CHECKS[0]} 4

		for eapi in $(cut -c-1 ${RUNNING_CHECKS[1]}/full.txt|sort -u); do
			mkdir -p ${RUNNING_CHECKS[1]}/sort-by-eapi/EAPI${eapi}
			grep ^${eapi}${DL} ${RUNNING_CHECKS[1]}/full.txt > ${RUNNING_CHECKS[1]}/sort-by-eapi/EAPI${eapi}/full.txt

			gen_sort_main_v2 ${RUNNING_CHECKS[1]}/sort-by-eapi/EAPI${eapi}/full.txt 4
			gen_sort_pak_v2 ${RUNNING_CHECKS[1]}/sort-by-eapi/EAPI${eapi}/full.txt 2
		done

		gen_sort_main_v2 ${RUNNING_CHECKS[1]} 4
		gen_sort_pak_v2 ${RUNNING_CHECKS[1]} 2

		copy_checks ${SCRIPT_TYPE}
		rm -rf ${WORKDIR}
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
			diff_rm_dropped_paks 2
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
