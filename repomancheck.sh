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

#override REPOTREE,FILERESULTS,RESULTSDIR settings
#export REPOTREE=/usr/portage/
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/repomancheck/"

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

SCRIPT_TYPE="checks"
WORKDIR="/tmp/repomancheck-${RANDOM}"
REPOCHECK=true

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/packages_full_repoman"									#Index 0
	)
}
output_format(){
	index=(
		"${category}/${package}${DL}$(echo ${affected_checks[@]}|tr ' ' ':')${DL}${maintainer}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_index0 <<- EOM
A script which runs 'repoman full' on every package. The result is also filtered
by repomans checks.

||F                        +----> repoman problem(s)
D|O                        |
A|R  dev-libs/foo | inherit.deprecated:uri.https | developer@gentoo.org
T|M       |                                                 |
A|A       |                       ebuild maintainer(s) <----+
||T       +----> package category/name
EOM
	description=( "${info_index0}" "${info_index1}" )
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
	local full_path="${REPOTREE}/${category}/${package}"
	local maintainer="$(get_main_min "${category}/${package}")"

	cd ${full_path}
	local TMPFILE="/tmp/${category}-${package}-${RANDOM}.log"
	/usr/bin/repoman -q full > ${TMPFILE}

	local affected_checks=( $(grep '^  [a-zA-Z].*' ${TMPFILE} | cut -d' ' -f3 ) )

	if ! [ "$(cat ${TMPFILE})" = "No QA issues found" ]; then
		if ${FILERESULTS}; then
			mkdir -p ${RUNNING_CHECKS[0]}/sort-by-package/${category}/
			head -n-1 ${TMPFILE} > ${RUNNING_CHECKS[0]}/sort-by-package/${category}/${package}.txt
			output_format 0 >> ${RUNNING_CHECKS[0]}/full.txt
		else
			if [ "${1}" = "full" ]; then
				output_format 0
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
	if ${FILERESULTS}; then
		gen_descriptions
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

array_names
# switch to the REPOTREE dir
cd ${REPOTREE}
# export important variables
export WORKDIR REPOCHECK
export -f main array_names output_format
${FILERESULTS} && mkdir -p ${RUNNING_CHECKS[@]}
# set the search depth
depth_set_v2 ${1}
${FILERESULTS} && rm -rf ${WORKDIR}
