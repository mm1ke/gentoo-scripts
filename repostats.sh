#!/bin/bash

# Filename: repostats.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 09/05/2021

# Copyright (C) 2021  Michael Mair-Keimberger
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
#	script for generating statistics regarding gentoo repositories

# override REPOTREE,FILERESULTS,RESULTSDIR settings
#export REPOTREE=/usr/portage/
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/repostats/"
# enabling debug output
#export DEBUG=true
#export DEBUGLEVEL=1
#export DEBUGFILE=/tmp/repostats.log

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
${ENABLE_MD5} || exit 0					# only works with md5 cache
${ENABLE_GIT} || exit 0					# only works with git tree

SCRIPT_TYPE="stats"
WORKDIR="/tmp/repostats-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/ebuild_eapi_statistics"						# Index 0
		"${WORKDIR}/ebuild_live_statistics"						# Index 1
		"${WORKDIR}/ebuild_eclass_statistics"					# Index 2
		"${WORKDIR}/ebuild_licenses_statistics"				# Index 3
		"${WORKDIR}/ebuild_keywords_statistics"				# Index 4
		"${WORKDIR}/ebuild_virtual_use_statistics"		# Index 5
		"${WORKDIR}/ebuild_obsolete_eapi"							# Index 6
		"${WORKDIR}/ebuild_cleanup_candidates"				# Index 7
		"${WORKDIR}/ebuild_stable_candidates"					# Index 8
		"${WORKDIR}/ebuild_glep81_group_statistics"		# Index 9
		"${WORKDIR}/ebuild_glep81_user_statistics"		# Index 10
	)
}
output_format(){
	index=(
"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${maintainer}"
"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${maintainer}"
"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${ebuild_eclasses}${DL}${maintainer}"
"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${ebuild_licenses}${DL}${maintainer}"
"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${ebuild_keywords}${DL}${maintainer}"
"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${ebuild_virt_in_use}${DL}${maintainer}"
"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${maintainer}"
"${ebuild_eapi}\
${DL}${old_ebuild_created}${DL}${old_ebuild_last_modified}\
${DL}${eapi_found_ebuild}\
${DL}${new_ebuild_created}${DL}${new_ebuild_last_modified}\
${DL}${package_bugs}${DL}${cat}/${pak}\
${DL}${org_name}${DL}${norm_name}-r${i}${DL}${maintainer}"
"${ebuild_eapi}\
${DL}${old_ebuild_created}${DL}${old_ebuild_last_modified}\
${DL}${eapi_found_ebuild}\
${DL}${new_ebuild_created}${DL}${new_ebuild_last_modified}\
${DL}${package_bugs}${DL}${cat}/${pak}\
${DL}${org_name}${DL}${norm_name}-r${i}${DL}${maintainer}"
"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${ebuild_group_use}${DL}${maintainer}"
"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${ebuild_user_use}${DL}${maintainer}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_default0 <<- EOM
Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_default1 <<- EOM
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
A simple list of all ebuilds with it's corresponding EAPI Version. Also includes all maintainers to the package
<a href=ebuild_eapi_statistics-detailed.html>EAPI Statistics</a>

${info_default0}
EOM
read -r -d '' info_index1 <<- EOM
A simple list of all live ebuilds and it's corresponding EAPI Version and maintainer(s).

${info_default0}
EOM
read -r -d '' info_index2 <<- EOM
Lists the eclasses used by every ebuild.
Not including packages which don't inherit anything. Also not included are eclasses inherited by other eclasses.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|eutils:elisp|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
eutils:elisp                                eclasses which the ebuild inherit (implicit inherit not included)
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index3 <<- EOM
Lists the licenses used by every ebuild (not taking contional licenses into account).

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|GPL-2:BSD|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
GPL-2:BSD                                   licenses used the ebuild, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index4 <<- EOM
Lists the keywords used by every ebuild.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|~amd64:x86|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
~amd64:x86                                  keywords used by the ebuild, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index5 <<- EOM
Lists virtual usage by ebuilds.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|virtual/ooo|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
virtual/ooo                                 virtual(s) used by this ebuild, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index6 <<- EOM
Lists all ebuilds which have an obsolete EAPI

${info_default0}
EOM

read -r -d '' info_index7 <<- EOM
This script searches if there is a newer revision (-rX) available. In case a newer revision is found KEYWORDS are
gonna be checked as well. If both keywords are the same for both ebuilds the older one is considered as a removal
candidate.

${info_default1}
EOM
read -r -d '' info_index8 <<- EOM
This script searches if there is a newer revision (-rX) available. In case a newer revision is found KEYWORDS are
gonna be checked as well. In case keywords differ, the newer ebuild is considered as a candidate for
stablization.

${info_default1}
EOM
read -r -d '' info_index9 <<- EOM
Lists acct-group/* usage by ebuilds.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|acct-group/gdm|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
acct-group/gdm                              group(s) used by this ebuild, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index10 <<- EOM
Lists acct-user/* usage by ebuilds.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|acct-user/gdm|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
acct-user/gdm                               user(s) used by this ebuild, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM

	description=( "${info_index0}" "${info_index1}" "${info_index2}" \
		"${info_index3}" "${info_index4}" "${info_index5}" "${info_index6}" \
		"${info_index7}" "${info_index8}" "${info_index9}" "${info_index10}" )
	echo "${description[$1]}"
}
#
### IMPORTANT SETTINGS END ###
#

main() {
	array_names
	[ ${DEBUGLEVEL} -ge 2 ] && echo "generating standard information for ${1}" | (debug_output)

	# everything below $min_allow_eapi is considered deprecated
	local min_allow_eapi=6

	local rel_path=${1}																								# path relative to ${REPOTREE}:	./app-admin/salt/salt-0.5.2.ebuild
	local cat="$(echo ${rel_path}|cut -d'/' -f1)"											# package category:							app-admin
	local pak="$(echo ${rel_path}|cut -d'/' -f2)"											# package name:									salt
	local filename="$(echo ${rel_path}|cut -d'/' -f3)"								# package filename:							salt-0.5.2.ebuild
	local pakname="${filename%.*}"																		# package name-version:					salt-0.5.2
	local pakver="${pakname/${pak}-/}"																# package version								0.5.2
	local abs_path="${REPOTREE}/${cat}/${pak}"												# full path:										/usr/portage/app-admin/salt
	local abs_path_ebuild="${REPOTREE}/${cat}/${pak}/${filename}"			# full path ebuild:							/usr/portage/app-admin/salt/salt-0.5.2.ebuild

	[ ${DEBUGLEVEL} -ge 2 ] && echo "generating detailed information for ${1}" | (debug_output)
	local maintainer="$(get_main_min "${cat}/${pak}")"								# maintainer of package:				foo@gentoo.org:bar@gmail.com
	#local fileage="$(get_age "${cat}/${pak}/${filename}")"						# age of ebuild in days:				145
	local ebuild_eapi="$(get_eapi ${rel_path})"												# eapi of ebuild:								6
	local ebuild_eclasses="$(get_eclasses "${cat}/${pak}/${pakname}")"
	local ebuild_licenses="$(get_licenses "${cat}/${pakname}")"
	local ebuild_keywords="$(get_keywords "${cat}/${pakname}")"
	local ebuild_depend="$(get_depend "${cat}/${pak}/${pakname}")"

	if [ "${pakname: -3}" = "-r${pakname: -1}" ]; then
		start=$(expr ${pakname: -1} + 1)
		local org_name=${pakname}
		local norm_name=${pakname::-3}
	else
		start=1
		local org_name=${pakname}
		local norm_name=${pakname}
	fi

	output() {
		local id=${1}
		if ${FILERESULTS}; then
			output_format ${id} >> ${RUNNING_CHECKS[${id}]}/full.txt
		else
			echo "${RUNNING_CHECKS[${id}]##*/}${DL}$(output_format ${id})"
		fi
	}

	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for stable and cleanup candidates" | (debug_output)
	local i
	# check for maximal 9 reversion
	for i in $(seq $start 9); do
		if [ -e ${abs_path}/${norm_name}-r${i}.ebuild ]; then
			local found_ebuild="${cat}/${norm_name}-r${i}"
			local eapi_found_ebuild="$(get_eapi ${abs_path}/${norm_name}-r${i}.ebuild)"
			# only ebuild with a greater eapi then $min_allow_eapi are considered
			# candidates for stable requests/cleanup
			if [ ${eapi_found_ebuild} -ge ${min_allow_eapi} ] && ! $(check_mask ${found_ebuild}); then

				local old_ebuild="${cat}/${pak}/${org_name}.ebuild"
				local new_ebuild="${cat}/${pak}/${norm_name}-r${i}.ebuild"

				if $(count_keywords "${org_name}" "${norm_name}-r${i}" ${cat} ${pak}); then

					local old_ebuild_created="$(get_git_age ${old_ebuild} "ct" "A" "first")"
					local old_ebuild_last_modified="$(get_git_age ${old_ebuild} "ct" "M" "last")"
					local new_ebuild_created="$(get_git_age ${new_ebuild} "ct" "A" "first")"
					local new_ebuild_last_modified="$(get_git_age ${new_ebuild} "ct" "M" "last")"
					local package_bugs="__C6__"

					if $(compare_keywords "${org_name}" "${norm_name}-r${i}" ${cat} ${pak}); then
						output 7
					else
						output 8
					fi
				fi
				break 2
			fi
		fi
	done

	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for live ebuilds" | (debug_output)
	if $(echo ${pakver}|grep -q 9999); then
		[ -z "${ebuild_keywords}" ] && ebuild_keywords="none"
		output 1
	fi

	[ ${DEBUGLEVEL} -ge 2 ] && echo "looking for inherited eclasses" | (debug_output)
	[ -n "${ebuild_eclasses}" ] && output 2
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for used licenses" | (debug_output)
	[ -n "${ebuild_licenses}" ] && output 3

	if [ -n "${ebuild_depend}" ]; then
		local vir_tmp=( $(echo ${ebuild_depend}|tr ':' '\n'|grep "virtual/"|cut -d'/' -f2) )
		local group_tmp=( $(echo ${ebuild_depend}|tr ':' '\n'|grep "acct-group/"|cut -d'/' -f2) )
		local user_tmp=( $(echo ${ebuild_depend}|tr ':' '\n'|grep "acct-user/"|cut -d'/' -f2) )
		local ebuild_virt_in_use="$(echo ${vir_tmp[@]}|tr ' ' ':')"
		local ebuild_group_use="$(echo ${group_tmp[@]}|tr ' ' ':')"
		local ebuild_user_use="$(echo ${user_tmp[@]}|tr ' ' ':')"

		[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for used virtuals" | (debug_output)
		[ -n "${ebuild_virt_in_use}" ] && output 5
		[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for used acct-group packages" | (debug_output)
		[ -n "${ebuild_group_use}" ] && output 9
		[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for used acct-user packages" | (debug_output)
		[ -n "${ebuild_user_use}" ] && output 10
	fi


	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for obsolete ebuilds (min EAPI is: ${min_allow_eapi})" | (debug_output)
	if [ ${ebuild_eapi} -lt ${min_allow_eapi} ]; then
		output 6
	fi

	[ ${DEBUGLEVEL} -ge 2 ] && echo "keywords statistics" | (debug_output)
	output 4
	[ ${DEBUGLEVEL} -ge 2 ] && echo "eapi statistics" | (debug_output)
	output 0

	[ ${DEBUGLEVEL} -ge 2 ] && echo "finished with ${1}" | (debug_output)
	[ ${DEBUGLEVEL} -ge 2 ] && echo | (debug_output)
}

upd_results(){
	if ${FILERESULTS}; then
		for rcid in $(seq 7 8); do
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
	fi
}

find_func(){
	[ ${DEBUGLEVEL} -ge 1 ] && echo "starting find with MIND:${MIND} and MAXD:${MAXD}" | (debug_output)

	if [ ${DEBUGLEVEL} -ge 2 ]; then
		[ ${DEBUGLEVEL} -ge 2 ] && echo "NORMAL run: searchpattern is ${searchp[@]}" | (debug_output)
		find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.ebuild" 2>/dev/null | while read -r line; do main ${line}; done
	else
		[ ${DEBUGLEVEL} -ge 1 ] && echo "PARALLEL run: searchpattern is ${searchp[@]}" | (debug_output)
		find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.ebuild" 2>/dev/null | parallel main {}
	fi


	# check for empty results and remove them
	clean_results

	[ ${DEBUGLEVEL} -ge 2 ] && echo "fileresults is: ${FILERESULTS}" | (debug_output)
	if ${FILERESULTS}; then

		[ ${DEBUGLEVEL} -ge 1 ] && echo "calling gen_descriptions" | (debug_output)
		gen_descriptions
		[ ${DEBUGLEVEL} -ge 1 ] && echo "calling upd_results" | (debug_output)
		upd_results

		[ ${DEBUGLEVEL} -ge 1 ] && echo "calling sort_result_v4" | (debug_output)
		# sort the results
		sort_result_v4 2 0
		sort_result_v4 2 1
		sort_result_v4 2 2
		sort_result_v4 2 3
		sort_result_v4 2 4
		sort_result_v4 2 5
		sort_result_v4 2 6
		sort_result_v4 "1,1 -k8,8" 7
		sort_result_v4 "1,1 -k8,8" 8
		sort_result_v4 2 9
		sort_result_v4 2 10

		[ ${DEBUGLEVEL} -ge 1 ] && echo "calling sort_eapi" | (debug_output)
		# filter after EAPI/filter
		gen_sort_eapi_v1 ${RUNNING_CHECKS[0]}
		gen_sort_eapi_v1 ${RUNNING_CHECKS[1]}
		gen_sort_eapi_v1 ${RUNNING_CHECKS[6]}
		[ ${DEBUGLEVEL} -ge 1 ] && echo "calling sort_filter" | (debug_output)
		gen_sort_filter_v1 4 ${RUNNING_CHECKS[2]}
		gen_sort_filter_v1 4 ${RUNNING_CHECKS[3]}
		gen_sort_filter_v1 4 ${RUNNING_CHECKS[4]}
		gen_sort_filter_v1 4 ${RUNNING_CHECKS[5]}
		gen_sort_filter_v1 4 ${RUNNING_CHECKS[9]}
		gen_sort_filter_v1 4 ${RUNNING_CHECKS[10]}

		[ ${DEBUGLEVEL} -ge 1 ] && echo "calling sort_main_v4" | (debug_output)
		gen_sort_main_v4
		[ ${DEBUGLEVEL} -ge 1 ] && echo "calling sort_pak_v4" | (debug_output)
		gen_sort_pak_v4

		[ ${DEBUGLEVEL} -ge 1 ] && echo "calling copy_checks" | (debug_output)
		copy_checks ${SCRIPT_TYPE}
	fi
}

[ ${DEBUGLEVEL} -ge 1 ] && echo "*** starting repostats" | (debug_output)
cd ${REPOTREE}
array_names
export WORKDIR
export -f main array_names output_format
# create a list and create corresponding folders and files of all available
# eclasses and licenses before running the check - this way we also see
# eclasses and licenses without customers.
if ${FILERESULTS}; then
	[ ${DEBUGLEVEL} -ge 1 ] && echo "generating various directories" | (debug_output)
	mkdir -p ${RUNNING_CHECKS[@]}
	if ${TREE_IS_MASTER}; then
		eclass_list=( $(find ${REPOTREE}/eclass/*.eclass -maxdepth 1 -type f) )
		eclass_list=( ${eclass_list[@]##*/} )
		for ecl in ${eclass_list[@]}; do
			mkdir -p ${RUNNING_CHECKS[2]}/sort-by-filter/${ecl%.*}
			touch ${RUNNING_CHECKS[2]}/sort-by-filter/${ecl%.*}/full.txt
		done
		if [ -d "${REPOTREE}/licenses/" ]; then
			licenses_list=( $(find ${REPOTREE}/licenses/* -maxdepth 1 -type f) )
			licenses_list=( ${licenses_list[@]##*/} )
			for lic in ${licenses_list[@]}; do
				mkdir -p ${RUNNING_CHECKS[3]}/sort-by-filter/${lic}
				touch ${RUNNING_CHECKS[3]}/sort-by-filter/${lic}/full.txt
			done
		fi
	fi
	if [ -d "${REPOTREE}/virtual/" ]; then
		virtual_list=( $(find ${REPOTREE}/virtual/* -maxdepth 1 -type d) )
		virtual_list=( ${virtual_list[@]##*/} )
		for vir in ${virtual_list[@]}; do
			mkdir -p ${RUNNING_CHECKS[5]}/sort-by-filter/${vir}
			touch ${RUNNING_CHECKS[5]}/sort-by-filter/${vir}/full.txt
		done
	fi
	if [ -d "${REPOTREE}/acct-group/" ]; then
		group_list=( $(find ${REPOTREE}/acct-group/* -maxdepth 1 -type d) )
		group_list=( ${group_list[@]##*/} )
		for grp in ${group_list[@]}; do
			mkdir -p ${RUNNING_CHECKS[9]}/sort-by-filter/${grp}
			touch ${RUNNING_CHECKS[9]}/sort-by-filter/${grp}/full.txt
		done
	fi
	if [ -d "${REPOTREE}/acct-user/" ]; then
		user_list=( $(find ${REPOTREE}/acct-user/* -maxdepth 1 -type d) )
		user_list=( ${user_list[@]##*/} )
		for user in ${user_list[@]}; do
			mkdir -p ${RUNNING_CHECKS[10]}/sort-by-filter/${user}
			touch ${RUNNING_CHECKS[10]}/sort-by-filter/${user}/full.txt
		done
	fi
fi
depth_set_v3 ${1}
${FILERESULTS} && rm -rf ${WORKDIR}

[ ${DEBUGLEVEL} -ge 1 ] && echo "*** finished repostats" | (debug_output)
