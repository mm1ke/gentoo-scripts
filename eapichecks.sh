#!/bin/bash

# Filename: eapichecks.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 20/11/2017

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
# This scripts checks eapi usage. it looks for ebuils with old eapi
# and checks if there is a revision/version bump with a newer eapi

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/eapichecks/"
#export PORTTREE="/usr/portage/"

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
SCRIPT_NAME="eapichecks"
SCRIPT_SHORT="EAC"
SCRIPT_TYPE="stats"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-STA-ebuild_cleanup_candidates"					#Index 0
	"${WORKDIR}/${SCRIPT_SHORT}-STA-ebuild_stable_candidates"						#Index 1
	"${WORKDIR}/${SCRIPT_SHORT}-STA-ebuild_obsolete_eapi"								#Index 2
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#


output() {
	local text="${1}"
	local type="${2}"

	if ${SCRIPT_MODE}; then
		echo "${text}" >> /${WORKDIR}/${type}/full.txt
	else
		echo "${text}${DL}${type}"
	fi
}

main() {
	array_names
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f1)"
	local package="$(echo ${full_package}|cut -d'/' -f2)"
	local filename="$(echo ${full_package}|cut -d'/' -f3)"
	local name="${filename%.*}"
	local ebuild_eapi="$(get_eapi ${full_package})"

	local date_today="$(date '+%s' -d today)"
	local package_path="/${PORTTREE}/${category}/${package}"

	local maintainer="$(get_main_min "${category}/${package}")"
	local openbugs="$(get_bugs ${category}/${package})"
	if ! [ -z "${openbugs}" ]; then
		openbugs="${DL}${openbugs}"
	fi

	if [ "${name: -3}" = "-r${name: -1}" ]; then
		start=$(expr ${name: -1} + 1)
		org_name=${name}
		name=${name::-3}
	else
		start=1
		org_name=${name}
	fi

	local i

	# check for maximal 10 reversion
	for i in $(seq $start 10); do
		if [ -e ${package_path}/${name}-r${i}.ebuild ]; then
			local found_ebuild="${package_path}/${name}-r${i}.ebuild"
			local eapi_found_ebuild="$(get_eapi ${found_ebuild})"

			if [ "${eapi_found_ebuild}" = "6" ] || [ "${eapi_found_ebuild}" = "7" ]; then
				local old_file=""
				local new_file=""
				if ${ENABLE_GIT}; then
					old_file="$(get_age "${category}/${package}/${org_name}.ebuild")${DL}"
					new_file="$(get_age "${category}/${package}/${name}-r${i}.ebuild")${DL}"
				fi
				if $(compare_keywords "${org_name}" "${name}-r${i}" ${category} ${package}); then
					output "${ebuild_eapi}${DL}${old_file}${eapi_found_ebuild}${DL}${new_file}${category}/${package}${DL}${org_name}${DL}${name}-r${i}${DL}${maintainer}${openbugs}" \
						"${RUNNING_CHECKS[0]##*/}"
				else
					output "${ebuild_eapi}${DL}${old_file}${eapi_found_ebuild}${DL}${new_file}${category}/${package}${DL}${org_name}${DL}${name}-r${i}${DL}${maintainer}${openbugs}" \
						"${RUNNING_CHECKS[1]##*/}"
				fi
				break 2
			fi
		fi
	done
	if ! [ ${ebuild_eapi} = 5 ]; then
		output "${ebuild_eapi}${DL}$(get_eapi_pak ${package_path})${DL}${category}/${package}${DL}${org_name}${DL}${maintainer}${openbugs}" \
			"${RUNNING_CHECKS[2]##*/}"
	fi
}

pre_check(){
	if ! [ "$(get_eapi ${1})" = "6" ] && ! [ "$(get_eapi ${1})" = "7" ]; then
		main ${1}
	fi
}

depth_set ${1}
cd ${PORTTREE}
export WORKDIR SCRIPT_SHORT
export -f main output array_names pre_check
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}

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
		-type f -name "*.ebuild" -print | parallel pre_check {}
}

gen_results(){
	if ${SCRIPT_MODE}; then
		sort_result ${RUNNING_CHECKS[2]} "1,1 -k3,3"
		sort_result ${RUNNING_CHECKS[1]} $(${ENABLE_GIT} && echo "1,1 -k5,5" || echo "1,1 -k3,3")
		sort_result ${RUNNING_CHECKS[0]} $(${ENABLE_GIT} && echo "1,1 -k5,5" || echo "1,1 -k3,3")

		gen_sort_main_v2 ${RUNNING_CHECKS[2]} 5
		gen_sort_pak_v2 ${RUNNING_CHECKS[2]} 3

		gen_sort_main_v2 ${RUNNING_CHECKS[0]} $(${ENABLE_GIT} && echo 8 || echo 6)
		gen_sort_pak_v2 ${RUNNING_CHECKS[0]} $(${ENABLE_GIT} && echo 5 || echo 3)

		gen_sort_main_v2 ${RUNNING_CHECKS[1]} $(${ENABLE_GIT} && echo 8 || echo 6)
		gen_sort_pak_v2 ${RUNNING_CHECKS[1]} $(${ENABLE_GIT} && echo 5 || echo 3)

		copy_checks ${SCRIPT_TYPE}
	fi
}

increase_git_age(){
	local fullfile=${1}
	# before doing anything check if there even exists a full.txt
	if [ -e "${fullfile}" ]; then
		# count the occurences of '|' as it's possible to not have any git age
		# information in the full file at all. If there is that information
		# there must be either 7 or 8 occurences of '|'
		local check_deli="$(head -n1 ${fullfile} | grep -o '|' | wc -l)"
		if [ ${check_deli} -eq 8 ] || [ ${check_deli} -eq 7 ]; then
			# increase the git age by +1 for both rows
			gawk -i inplace -F'|' '{$2=$2+1}1' OFS='|' ${fullfile}
			gawk -i inplace -F'|' '{$4=$4+1}1' OFS='|' ${fullfile}
		fi
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

			# special case for cleanup candidates and stable candidates.
			# this increases the second and fourth row by 1. This row contain the git
			# age of the ebuild which should got older by one day. Since we don't
			# check full we have to increase it manually
			increase_git_age "${RUNNING_CHECKS[0]}/full.txt"
			increase_git_age "${RUNNING_CHECKS[1]}/full.txt"

			# run the script only on the changed packages
			find_func ${1}
			# remove dropped packages
			diff_rm_dropped_paks_v2 $(${ENABLE_GIT} && echo 5 || echo 3) 0
			diff_rm_dropped_paks_v2 $(${ENABLE_GIT} && echo 5 || echo 3) 1
			diff_rm_dropped_paks_v2 3 2
			gen_results

		else
			# if ${TODAYCHECKS} doesn't exist or has zero bytes, do nothing, except in
			# this case, increase the git age:
			increase_git_age "${SITEDIR}/${SCRIPT_TYPE}/${RUNNING_CHECKS[0]/${WORKDIR}/}/full.txt"
			increase_git_age "${SITEDIR}/${SCRIPT_TYPE}/${RUNNING_CHECKS[1]/${WORKDIR}/}/full.txt"
		fi
	else
		find_func full
		gen_results
	fi
else
	find_func ${1}
	gen_results
fi

# cleanup tmp files
${SCRIPT_MODE} && rm -rf ${WORKDIR}
