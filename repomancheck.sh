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

# feature requirements
#${TREE_IS_MASTER} || exit 0
#${ENABLE_MD5} || exit 0
#${ENABLE_GIT} || exit 0

SCRIPT_NAME="repomancheck"
SCRIPT_SHORT="RMC"
SCRIPT_TYPE="checks"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"
REPOCHECK=true

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
	local category="$(echo ${relative_path}|cut -d'/' -f1)"
	local package="$(echo ${relative_path}|cut -d'/' -f2)"
	local full_path="${PORTTREE}/${category}/${package}"
	local maintainer="$(get_main_min "${category}/${package}")"

	cd ${full_path}
	local TMPFILE="/tmp/${category}-${package}-${RANDOM}.log"
	/usr/bin/repoman -q full > ${TMPFILE}

	local affected_checks=( $(grep '^  [a-zA-Z].*' ${TMPFILE} | cut -d' ' -f3 ) )

	if ! [ "$(cat ${TMPFILE})" = "No QA issues found" ]; then
		if ${SCRIPT_MODE}; then
			mkdir -p ${RUNNING_CHECKS[0]}/sort-by-package/${category}/
			head -n-1 ${TMPFILE} > ${RUNNING_CHECKS[0]}/sort-by-package/${category}/${package}.txt
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


find_func(){
	find ${searchp[@]} -mindepth ${MIND} -maxdepth ${MAXD} \
		-type d -print | parallel main {}
}

gen_results(){
	if ${SCRIPT_MODE}; then
		gen_sort_main_v3

		for file in $(cat ${RUNNING_CHECKS[0]}/full.txt); do
			for fp in $(echo ${file}|cut  -d'|' -f2|tr ':' ' '); do
				mkdir -p ${RUNNING_CHECKS[0]}/sort-by-filter/${fp}
				echo ${file} >> ${RUNNING_CHECKS[0]}/sort-by-filter/${fp}/full.txt
			done
		done

		for ffp in $(ls ${RUNNING_CHECKS[0]}/sort-by-filter/); do
			gen_sort_main_v3 ${RUNNING_CHECKS[0]}/sort-by-filter/${ffp}
			gen_sort_pak_v3 ${RUNNING_CHECKS[0]}/sort-by-filter/${ffp}
		done

		copy_checks ${SCRIPT_TYPE}
	fi
}


# switch to the PORTTREE dir
cd ${PORTTREE}
# export important variables
export WORKDIR SCRIPT_SHORT REPOCHECK
export -f main array_names
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}
# set the search depth
depth_set_v2 ${1}
${SCRIPT_MODE} && rm -rf ${WORKDIR}
