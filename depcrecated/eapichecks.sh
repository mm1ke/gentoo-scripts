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

#override REPOTREE,FILERESULTS,RESULTSDIR settings
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/eapichecks/"
#export REPOTREE="/usr/portage/"

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
#${ENABLE_MD5} || exit 0					# only works with md5 cache
#${ENABLE_GIT} || exit 0				# only works with git tree

SCRIPT_TYPE="stats"
WORKDIR="/tmp/eapichecks-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/ebuild_cleanup_candidates"					#Index 0
		"${WORKDIR}/ebuild_stable_candidates"						#Index 1
		"${WORKDIR}/ebuild_obsolete_eapi"								#Index 2
	)
}
output_format(){
	index=(
"${ebuild_eapi}\
${DL}${old_ebuild_created}${DL}${old_ebuild_last_modified}\
${DL}${eapi_found_ebuild}\
${DL}${new_ebuild_created}${DL}${new_ebuild_last_modified}\
${DL}${package_bugs}${DL}${category}/${package}\
${DL}${org_name}${DL}${name}-r${i}${DL}${maintainer}"
"${ebuild_eapi}\
${DL}${old_ebuild_created}${DL}${old_ebuild_last_modified}\
${DL}${eapi_found_ebuild}\
${DL}${new_ebuild_created}${DL}${new_ebuild_last_modified}\
${DL}${package_bugs}${DL}${category}/${package}\
${DL}${org_name}${DL}${name}-r${i}${DL}${maintainer}"
"${ebuild_eapi}\
${DL}__C2__${DL}__C3__${DL}${eapilist}${DL}${eapi_fileage}\
${DL}${category}/${package}${DL}${org_name}${DL}${maintainer}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_default0 <<- EOM
Data Format ( 6|01865|01311|6|00649|-----|+|dev-libs/foo|foo-1.12-r1|foo-1.12-r2|dev@gentoo.org:loper@foo.de ):
6|01865|01311|                              EAPI Version (older) | days since created | days since last modified
6|00649|-----|                              EAPI Version (newer) | days since created | days since last modified
+                                           indicates if bugs are open to this package (+=yes, -=no)
dev-libs/foo                                package category/name
foo-1.12-r1.ebuild                          full filename (older)
foo-1.12-r2.ebuild                          full filename (newer)
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM

read -r -d '' info_index0 <<- EOM
This script searches if there is a newer revision (-rX) available. In case a newer revision is found KEYWORDS are
gonna be checked as well. If both keywords are the same for both ebuilds the older one is considered as a removal
candidate.

${info_default0}
EOM
read -r -d '' info_index1 <<- EOM
This script searches if there is a newer revision (-rX) available. In case a newer revision is found KEYWORDS are
gonna be checked as well. In case keywords differ, the newer ebuild is considered as a candidate for
stablization.

${info_default0}
EOM
read -r -d '' info_index2 <<- EOM
This scirpt lists every ebuild with a EAPI <6. It list all other available ebuild EAPIs too which should make it easier
to find packages which can be removed or need some attention.

Data Format ( 5|-|000|0:0:0:0:0:1:0:0|02016|dev-libs/foo|foo-1.12-r2|dev@gentoo.org:loper@foo.de ):
5                                           EAPI Version
-                                           indicates if bugs are open to this package (+=yes, -=no)
000                                         number of bugs found on bugs.gentoo.org for this package
0:0:0:0:0:1:0:0                             list of available EAPIs each number represents a EAPI version (first EAPI0, last EAPI7)
02016                                       days since created
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
	description=( "${info_index0}" "${info_index1}" "${info_index2}" )
	echo "${description[$1]}"
}
#
### IMPORTANT SETTINGS END ###
#

main() {
	array_names
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f1)"
	local package="$(echo ${full_package}|cut -d'/' -f2)"
	local filename="$(echo ${full_package}|cut -d'/' -f3)"
	local name="${filename%.*}"
	local ebuild_eapi="$(get_eapi ${full_package})"

	local date_today="$(date '+%s' -d today)"
	local package_path="/${REPOTREE}/${category}/${package}"

	local maintainer="$(get_main_min "${category}/${package}")"

	if [ "${name: -3}" = "-r${name: -1}" ]; then
		start=$(expr ${name: -1} + 1)
		org_name=${name}
		name=${name::-3}
	else
		start=1
		org_name=${name}
	fi

	output(){
		local checkid=${1}
		if ${FILERESULTS}; then
			output_format ${checkid} >> ${RUNNING_CHECKS[${checkid}]}/full.txt
		else
			echo "${RUNNING_CHECKS[${checkid}]##*/}${DL}$(output_format ${checkid})"
		fi
	}

	local i

	# check for maximal 9 reversion
	for i in $(seq $start 9); do
		if [ -e ${package_path}/${name}-r${i}.ebuild ]; then
			local found_ebuild="${category}/${name}-r${i}"
			local eapi_found_ebuild="$(get_eapi ${package_path}/${name}-r${i}.ebuild)"

			if [ ${eapi_found_ebuild} -ge 6 ] && ! $(check_mask ${found_ebuild}); then

				local old_ebuild="${category}/${package}/${org_name}.ebuild"
				local new_ebuild="${category}/${package}/${name}-r${i}.ebuild"

				if $(count_keywords "${org_name}" "${name}-r${i}" ${category} ${package}); then

					local old_ebuild_created="$(get_git_age ${old_ebuild} "ct" "A" "first")"
					local old_ebuild_last_modified="$(get_git_age ${old_ebuild} "ct" "M" "last")"
					local new_ebuild_created="$(get_git_age ${new_ebuild} "ct" "A" "first")"
					local new_ebuild_last_modified="$(get_git_age ${new_ebuild} "ct" "M" "last")"
					local package_bugs="__C6__"

					if $(compare_keywords "${org_name}" "${name}-r${i}" ${category} ${package}); then
						output 0
					else
						output 1
					fi
				fi
				break 2
			fi
		fi
	done
	# everything below EAPI=6 is considered obsolete
	if [ ${ebuild_eapi} -lt 6 ]; then
		local eapilist="$(get_eapi_list ${package_path})"
		local eapi_fileage="$(get_git_age ${full_package} "ct" "A" "first")"
		output 2
	fi
}

find_func(){
	find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
		-type f -name "*.ebuild" -print | parallel main {}
}

upd_results(){
	if ${FILERESULTS}; then
		for rcid in $(seq 0 1); do
			if [ -e ${RUNNING_CHECKS[${rcid}]}/full.txt ]; then
				#get time diff since last run
				local indexfile="${RESULTSDIR}/${SCRIPT_TYPE}/${RUNNING_CHECKS[${rcid}]/${WORKDIR}/}/index.html"
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
			local indexfile="${RESULTSDIR}/${SCRIPT_TYPE}/${RUNNING_CHECKS[2]/${WORKDIR}/}/index.html"
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
	if ${FILERESULTS}; then
		gen_descriptions
		# update results with actual git age/bugs information
		upd_results
		# sort the results
		sort_result_v4 "1,1 -k8,8" 0
		sort_result_v4 "1,1 -k8,8" 1
		sort_result_v4 "1,1 -k6,6" 2
		# create maintainer/package listings
		gen_sort_main_v3
		gen_sort_pak_v3
		# copy results to sitedir
		copy_checks ${SCRIPT_TYPE}
	fi
}

array_names
cd ${REPOTREE}
export WORKDIR
export -f main array_names output_format
${FILERESULTS} && mkdir -p ${RUNNING_CHECKS[@]}
depth_set_v2 ${1}
# cleanup tmp files
${FILERESULTS} && rm -rf ${WORKDIR}
