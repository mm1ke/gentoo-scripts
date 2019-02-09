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

				# get_age returns "-----" if ENABLE_GIT is disabled
				# of=obsolete file
				# lf=latest file
				local of="$(get_age_date "${category}/${package}/${org_name}.ebuild")"
				local lf="$(get_age_date "${category}/${package}/${name}-r${i}.ebuild")"

				if $(compare_keywords "${org_name}" "${name}-r${i}" ${category} ${package}); then
					output "${ebuild_eapi}${DL}_C2_${DL}${eapi_found_ebuild}${DL}_C4_${DL}_C4_${DL}${category}/${package}${DL}${org_name}(${of})${DL}${name}-r${i}(${lf})${DL}${maintainer}" \
						"${RUNNING_CHECKS[0]##*/}"
				else
					output "${ebuild_eapi}${DL}_C2_${DL}${eapi_found_ebuild}${DL}_C4_${DL}_C5_${DL}${category}/${package}${DL}${org_name}(${of})${DL}${name}-r${i}(${lf})${DL}${maintainer}" \
						"${RUNNING_CHECKS[1]##*/}"
				fi
				break 2
			fi
		fi
	done
	if ! [ ${ebuild_eapi} = 5 ]; then
		local eapilist="$(get_eapi_list ${package_path})"
		local fileage="$(get_age_date ${full_package})"
		# OUTPUT: 0|_|_|0:0:0:0:0:0:0|_|foo/bar|foo/bar-1.0.0|foo@gentoo
		output "${ebuild_eapi}${DL}_C2_${DL}_C3_${DL}${eapilist}${DL}_C5_${DL}${category}/${package}${DL}${org_name}(${fileage})${DL}${maintainer}" \
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

gen_results(){
	if ${SCRIPT_MODE}; then
		sort_result_v2 "1,1 -k6,6"
		sort_result_v2 "1,1 -k6,6"
		sort_result_v2 "1,1 -k6,6"

		gen_sort_main_v3
		gen_sort_pak_v3

		copy_checks ${SCRIPT_TYPE}
	fi
}

upd_results(){
	if ${SCRIPT_MODE}; then
		if [ "${1}" = "old" ]; then
			x=( )
			for i in $(seq 0 $(expr ${#RUNNING_CHECKS[@]} - 1)); do
				x+=( "${SITEDIR}/${SCRIPT_TYPE}/${RUNNING_CHECKS[${i}]/${WORKDIR}/}" )
			done
			local RUNNING_CHECKS=( ${x[@]} )
		fi

		for rcid in $(seq 0 1); do
			gawk -i inplace -F'|' '{$2="_C2_"; $4="_C4_"; $5="_C5_"}1' OFS='|' ${RUNNING_CHECKS[${rcid}]}/full.txt
			for id in $(cat "${RUNNING_CHECKS[${rcid}]}/full.txt"); do
				local p="$(echo ${id}|cut -d'|' -f6)"
				local fd1="$(echo ${id}|cut -d'(' -f2|cut -d')' -f1)"
				local fd2="$(echo ${id}|cut -d'(' -f3|cut -d')' -f1)"

				local of="$(get_age_v2 "${fd1}")"
				local lf="$(get_age_v2 "${fd2}")"
				$(get_bugs_bool ${p}) && local ob="*" || local ob="-"

				local id_new="$(echo ${id}| sed -e "s/_C2_/${of}/g" -e "s/_C4_/${lf}/g" -e "s/_C5_/${ob}/g")"

				sed -i "s ${id} ${id_new} g" ${RUNNING_CHECKS[${rcid}]}/full.txt
			done
		done
		gawk -i inplace -F'|' '{$2="_C2_"; $3="_C3_"; $5="_C5_"}1' OFS='|' ${RUNNING_CHECKS[2]}/full.txt
		for id in $(cat "${RUNNING_CHECKS[2]}/full.txt"); do
			local p="$(echo ${id}|cut -d'|' -f6)"
			local fd="$(echo ${id}|cut -d'(' -f2|cut -d')' -f1)"

			local lf="$(get_age_v2 "${fd1}")"
			$(get_bugs_bool ${p}) && local ob="*" || local ob="-"
			local bc="$(get_bugs_count ${p})"

			local id_new="$(echo ${id}|sed -e "s/_C2_/${ob}/g" -e "s/_C3_/${bc}/g" -e "s/_C5_/${lf}/g")"

			sed -i "s ${id} ${id_new} g" ${RUNNING_CHECKS[2]}/full.txt
		done
	fi
}

cd ${PORTTREE}
export WORKDIR SCRIPT_SHORT
export -f main output array_names pre_check
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}
depth_set_v2 ${1}
# cleanup tmp files
${SCRIPT_MODE} && rm -rf ${WORKDIR}
