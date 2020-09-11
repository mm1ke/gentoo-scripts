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

# feature requirements
#${TREE_IS_MASTER} || exit 0
#${ENABLE_MD5} || exit 0
#${ENABLE_GIT} || exit 0

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

				local old_ebuild="${category}/${package}/${org_name}.ebuild"
				local new_ebuild="${category}/${package}/${name}-r${i}.ebuild"

				if $(count_keywords "${org_name}" "${name}-r${i}" ${category} ${package}); then

					local old_ebuild_created="$(get_git_age ${old_ebuild} "ct" "A" "first")"
					local old_ebuild_last_modified="$(get_git_age ${old_ebuild} "ct" "M" "last")"
					local new_ebuild_created="$(get_git_age ${new_ebuild} "ct" "A" "first")"
					local new_ebuild_last_modified="$(get_git_age ${new_ebuild} "ct" "M" "last")"
					local package_bugs="__C6__"

					if $(compare_keywords "${org_name}" "${name}-r${i}" ${category} ${package}); then
						output "${ebuild_eapi}\
${DL}${old_ebuild_created}${DL}${old_ebuild_last_modified}\
${DL}${eapi_found_ebuild}\
${DL}${new_ebuild_created}${DL}${new_ebuild_last_modified}\
${DL}${package_bugs}${DL}${category}/${package}\
${DL}${org_name}${DL}${name}-r${i}${DL}${maintainer}" \
							"${RUNNING_CHECKS[0]##*/}"
					else
						output "${ebuild_eapi}\
${DL}${old_ebuild_created}${DL}${old_ebuild_last_modified}\
${DL}${eapi_found_ebuild}\
${DL}${new_ebuild_created}${DL}${new_ebuild_last_modified}\
${DL}${package_bugs}${DL}${category}/${package}\
${DL}${org_name}${DL}${name}-r${i}${DL}${maintainer}" \
							"${RUNNING_CHECKS[1]##*/}"
					fi
				fi
				break 2
			fi
		fi
	done
	if ! [ ${ebuild_eapi} = 5 ]; then
		local eapilist="$(get_eapi_list ${package_path})"
		local eapi4_fileage="$(get_git_age ${full_package} "ct" "A" "first")"
		# OUTPUT: 0|_|_|0:0:0:0:0:0:0|_|foo/bar|foo/bar-1.0.0|foo@gentoo
		output "${ebuild_eapi}\
${DL}__C2__${DL}__C3__${DL}${eapilist}${DL}${eapi4_fileage}\
${DL}${category}/${package}${DL}${org_name}${DL}${maintainer}" \
			"${RUNNING_CHECKS[2]##*/}"
	fi
}

pre_check(){
	if ! [ "$(get_eapi ${1})" = "6" ] && ! [ "$(get_eapi ${1})" = "7" ]; then
		main ${1}
	fi
}

find_func(){
	find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
		-type f -name "*.ebuild" -print | parallel pre_check {}
}

upd_results(){
	if ${SCRIPT_MODE}; then
		for rcid in $(seq 0 1); do
			if [ -e ${RUNNING_CHECKS[${rcid}]}/full.txt ]; then
				#get time diff since last run
				local indexfile="${SITEDIR}/${SCRIPT_TYPE}/${RUNNING_CHECKS[${rcid}]/${WORKDIR}/}/index.html"
				local time_diff="$(get_time_diff "${indexfile}")"
				for id in $(cat "${RUNNING_CHECKS[${rcid}]}/full.txt"); do

					local old_ebuild_created="$(date_update "$(echo ${id}|cut -d'|' -f2)" "${time_diff}")"
					local old_ebuild_last_modified="$(date_update "$(echo ${id}|cut -d'|' -f3)" "${time_diff}")"
					local new_ebuild_created="$(date_update "$(echo ${id}|cut -d'|' -f5)" "${time_diff}")"
					local new_ebuild_last_modified="$(date_update "$(echo ${id}|cut -d'|' -f6)" "${time_diff}")"
					#local package_bugs="$(echo ${id}|cut -d'|' -f7)"
					local package="$(echo ${id}|cut -d'|' -f8)"
					$(get_bugs_bool "${package}") && local package_bugs="+" || local package_bugs="-"

					local new_id=$(
						echo "${id}" | gawk -F'|' '{$2=v2; $3=v3; $5=v5; $6=v6; $7=v7}1' \
						v2="${old_ebuild_created}" \
						v3="${old_ebuild_last_modified}" \
						v5="${new_ebuild_created}" \
						v6="${new_ebuild_last_modified}" \
						v7="${package_bugs}" OFS='|'
					)

					sed -i "s ${id} ${new_id} g" ${RUNNING_CHECKS[${rcid}]}/full.txt

				done
			fi
		done
		# obsolet eapi
		if [ -e ${RUNNING_CHECKS[2]}/full.txt ]; then
			#get time diff since last run
			local indexfile="${SITEDIR}/${SCRIPT_TYPE}/${RUNNING_CHECKS[2]/${WORKDIR}/}/index.html"
			local time_diff="$(get_time_diff "${indexfile}")"
			for id in $(cat "${RUNNING_CHECKS[2]}/full.txt"); do

				local package="$(echo ${id}|cut -d'|' -f6)"
				local old_ebuild_created="$(date_update "$(echo ${id}|cut -d'|' -f5)" "${time_diff}")"
				$(get_bugs_bool "${package}") && local package_bugs="+" || local package_bugs="-"
				local package_bugs_count="$(get_bugs_count ${package})"

				local new_id=$(
					echo "${id}" | gawk -F'|' '{$2=v2; $3=v3; $5=v5}1' \
					v2="${package_bugs}" \
					v3="${package_bugs_count}" \
					v5="${old_ebuild_created}" OFS='|'
				)

				sed -i "s ${id} ${new_id} g" ${RUNNING_CHECKS[2]}/full.txt
			done
		fi
	fi
}

gen_results(){
	if ${SCRIPT_MODE}; then
		# update results with actual git age/bugs information
		upd_results
		# sort the results
		sort_result_v3 "1,1"
		# create maintainer/package listings
		gen_sort_main_v3
		gen_sort_pak_v3
		# copy results to sitedir
		copy_checks ${SCRIPT_TYPE}
	fi
}

cd ${PORTTREE}
export WORKDIR SCRIPT_SHORT
export -f main output array_names pre_check
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}
depth_set_v2 ${1}
# cleanup tmp files
${SCRIPT_MODE} && rm -rf ${WORKDIR}
