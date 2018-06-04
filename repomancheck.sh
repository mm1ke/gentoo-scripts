#!/bin/bash

# Filename: repomancheck.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 01/06/2018

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
#	simply runs repoman full on every package

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export PORTTREE=/usr/portage/
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/repomancheck/"

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
SCRIPT_NAME="repomancheck"
SCRIPT_SHORT="RMC"
SCRIPT_TYPE="checks"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/${SCRIPT_SHORT}-IMP-packages_full_repoman"									#Index 0
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

	cd ${full_path}
	local TMPFILE="/tmp/${category}-${package}-${RANDOM}.log"
	/usr/bin/repoman -q full > ${TMPFILE}

	local affected_checks=( $(grep '^  [a-zA-Z].*' ${TMPFILE} | cut -d' ' -f3 ) )

	if ! [ "$(cat ${TMPFILE})" = "No QA issues found" ]; then
		if ${SCRIPT_MODE}; then
			mkdir -p ${RUNNING_CHECKS[0]}/sort-by-package/${category}/${package}/
			head -n-1 ${TMPFILE} > ${RUNNING_CHECKS[0]}/sort-by-package/${category}/${package}/${package}.txt
			echo "${category}/${package}${DL}$(echo ${affected_checks[@]}|tr ' ' ':')${DL}${maintainer}" >> ${RUNNING_CHECKS[0]}/full.txt
		else
			if [ "${1}" = "full" ]; then
				echo "${category}/${package}${DL}$(echo ${affected_checks[@]}|tr ' ' ':')${DL}${maintainer}"
			else
				echo "${category}/${package}${DL}${maintainer}"
				head -n-1 ${TMPFILE}
			fi
		fi
	fi

	rm ${TMPFILE}
}

# set the search depth
depth_set ${1}
# switch to the PORTTREE dir
cd ${PORTTREE}
# export important variables
export WORKDIR SCRIPT_SHORT
export -f main array_names

${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}

find_func(){
	find ./${level} -mindepth ${MIND} -maxdepth ${MAXD} \( \
		-path ./scripts/\* -o \
		-path ./profiles/\* -o \
		-path ./packages/\* -o \
		-path ./licenses/\* -o \
		-path ./distfiles/\* -o \
		-path ./metadata/\* -o \
		-path ./eclass/\* -o \
		-path ./.git/\* \) -prune -o -type d -print | parallel main {}
}

if [ "${1}" = "diff" ]; then
	OLDLOG="${SITEDIR}/${SCRIPT_TYPE}/${RUNNING_CHECKS[0]/${WORKDIR}/}/full.txt"
	TODAYCHECKS="${HASHTREE}/results/results-$(date -I).log"
	# only run if there is already a full.txt and a diff result from today.
	if [ -e ${OLDLOG} ] && [ -e ${TODAYCHECKS} ]; then
		cp ${OLDLOG} ${RUNNING_CHECKS[0]}/
		# copying old sort-by-packages files are only important for repomancheck
		# because these files aren't generated via gen_sort_* (like on other scripts)
		cp -r ${SITEDIR}/${SCRIPT_TYPE}/${RUNNING_CHECKS[0]/${WORKDIR}/}/sort-by-package ${RUNNING_CHECKS[0]}/
		for cpak in $(cat ${TODAYCHECKS}); do
			# the substring replacement is important (replaces '/' to '\/'), otherwise the sed command
			# will fail beause '/' aren't escapted.
			sed -i "/${cpak//\//\\/}${DL}/d" ${RUNNING_CHECKS[0]}/full.txt
			# like before, only important on this script (repomancheck)
			rm -rf ${RUNNING_CHECKS[0]}/sort-by-package/${cpak}
		done
		cat ${TODAYCHECKS} | parallel main {}
	else
		find_func
	fi
else
	find_func
fi

if ${SCRIPT_MODE}; then
	gen_sort_main_v2 ${RUNNING_CHECKS[0]} 3

	for file in $(cat ${RUNNING_CHECKS[0]}/full.txt); do
		for fp in $(echo ${file}|cut  -d'|' -f2|tr ':' ' '); do
			mkdir -p ${RUNNING_CHECKS[0]}/sort-by-filter/${fp}
			echo ${file} >> ${RUNNING_CHECKS[@]}/sort-by-filter/${fp}/full.txt
		done
	done

	for ffp in $(ls ${RUNNING_CHECKS[@]}/sort-by-filter/); do
		gen_sort_main_v2 ${RUNNING_CHECKS[0]}/sort-by-filter/${ffp} 3
		gen_sort_pak_v2 ${RUNNING_CHECKS[0]}/sort-by-filter/${ffp} 1
	done

	copy_checks ${SCRIPT_TYPE}
	rm -rf ${WORKDIR}
fi
