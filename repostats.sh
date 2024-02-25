#!/bin/bash

# Filename: repostats.sh
# Autor: Michael Mair-Keimberger (mmk AT levelnine DOT at)
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
#export RESULTSDIR="${HOME}/$(basename ${0})/"
# enabling debug output
#export DEBUG=true
#export DEBUGLEVEL=1
#export DEBUGFILE=/tmp/$(basename ${0}).log

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
WORKDIR="/tmp/$(basename ${0})-${RANDOM}"

array_names(){
	SELECTED_CHECKS=(
		rs_eaps
		rs_livs
		rs_ecls
		rs_lics
		rs_keys
		rs_vius
		rs_clec rs_stac
		rs_ggrs
		rs_guss
	)
	declare -gA FULL_CHECKS=(
		[rs_eaps]="${WORKDIR}/ebuild_eapi_statistics"
		[rs_livs]="${WORKDIR}/ebuild_live_statistics"
		[rs_ecls]="${WORKDIR}/ebuild_eclass_statistics"
		[rs_lics]="${WORKDIR}/ebuild_licenses_statistics"
		[rs_keys]="${WORKDIR}/ebuild_keywords_statistics"
		[rs_vius]="${WORKDIR}/ebuild_virtual_use_statistics"
		[rs_clec]="${WORKDIR}/ebuild_cleanup_candidates"
		[rs_stac]="${WORKDIR}/ebuild_stable_candidates"
		[rs_ggrs]="${WORKDIR}/ebuild_glep81_group_statistics"
		[rs_guss]="${WORKDIR}/ebuild_glep81_user_statistics"
	)
}

var_descriptions(){
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
read -r -d '' rs_eaps <<- EOM
A simple list of all ebuilds with it's corresponding EAPI Version. Also includes all maintainers to the package
<a href=ebuild_eapi_statistics-detailed.html>EAPI Statistics</a>

${info_default0}
EOM
read -r -d '' rs_livs <<- EOM
A simple list of all live ebuilds and it's corresponding EAPI Version and maintainer(s).

${info_default0}
EOM
read -r -d '' rs_ecls <<- EOM
Lists the eclasses used by every ebuild.
Not including packages which don't inherit anything. Also not included are eclasses inherited by other eclasses.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|eutils:elisp|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
eutils:elisp                                eclasses which the ebuild inherit (implicit inherit not included)
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' rs_lics <<- EOM
Lists the licenses used by every ebuild (not taking contional licenses into account).

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|GPL-2:BSD|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
GPL-2:BSD                                   licenses used the ebuild, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' rs_keys <<- EOM
Lists the keywords used by every ebuild.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|~amd64:x86|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
~amd64:x86                                  keywords used by the ebuild, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' rs_vius <<- EOM
Lists virtual usage by ebuilds.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|virtual/ooo|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
virtual/ooo                                 virtual(s) used by this ebuild, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' rs_clec <<- EOM
This script searches if there is a newer revision (-rX) available. In case a newer revision is found KEYWORDS are
gonna be checked as well. If both keywords are the same for both ebuilds the older one is considered as a removal
candidate.

${info_default1}
EOM
read -r -d '' rs_stac <<- EOM
This script searches if there is a newer revision (-rX) available. In case a newer revision is found KEYWORDS are
gonna be checked as well. In case keywords differ, the newer ebuild is considered as a candidate for
stablization.

${info_default1}
EOM
read -r -d '' rs_ggrs <<- EOM
Lists acct-group/* usage by ebuilds.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|acct-group/gdm|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
acct-group/gdm                              group(s) used by this ebuild, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' rs_guss <<- EOM
Lists acct-user/* usage by ebuilds.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|acct-user/gdm|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
acct-user/gdm                               user(s) used by this ebuild, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
}
#
### IMPORTANT SETTINGS END ###
#

main() {
	array_names
	[ ${DEBUGLEVEL} -ge 2 ] && echo "generating standard information for ${1}" | (debug_output)

	# everything below $min_allow_eapi is considered deprecated
	local min_allow_eapi=6

	local rel_path=${1}																									# path relative to ${REPOTREE}:	./app-admin/salt/salt-0.5.2.ebuild
	local cat="$(echo ${rel_path}|cut -d'/' -f1)"												# package category:							app-admin
	local pak="$(echo ${rel_path}|cut -d'/' -f2)"												# package name:									salt
	local filename="$(echo ${rel_path}|cut -d'/' -f3)"									# package filename:							salt-0.5.2.ebuild
	local pakname="${filename%.*}"																			# package name-version:					salt-0.5.2
	local pakver="${pakname/${pak}-/}"																	# package version								0.5.2
	local abs_path="${REPOTREE}/${cat}/${pak}"													# full path:										/usr/portage/app-admin/salt
	local abs_path_ebuild="${REPOTREE}/${cat}/${pak}/${filename}"				# full path ebuild:							/usr/portage/app-admin/salt/salt-0.5.2.ebuild

	[ ${DEBUGLEVEL} -ge 2 ] && echo "generating detailed information for ${1}" | (debug_output)
	local maintainer="$(get_main_min "${cat}/${pak}")"									# maintainer of package:				foo@gentoo.org:bar@gmail.com
	local ebuild_eapi="$(get_eapi ${rel_path})"													# eapi of ebuild:								6
	local ebuild_eclasses="$(get_eclasses "${cat}/${pak}/${pakname}")"	# elasses inherited by ebuild:	pam:udev
	local ebuild_licenses="$(get_licenses "${cat}/${pakname}")"					# licenses set by ebuild:				GPL2+:BSD-2
	local ebuild_keywords="$(get_keywords_v2 "${cat}/${pakname}")"			# keywords set by ebuild:				amd64:x86
	local ebuild_depend="$(get_depend "${cat}/${pak}/${pakname}")"			# dependencies set by ebuild:		dev-libs/gdl:app-admin/diradm

	if [ "${pakname: -3}" = "-r${pakname: -1}" ]; then
		start=$(expr ${pakname: -1} + 1)
		local org_name=${pakname}
		local norm_name=${pakname::-3}
	else
		start=1
		local org_name=${pakname}
		local norm_name=${pakname}
	fi

	output_formats(){
		declare -gA array_formats=(
			[def0]="${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${maintainer}"
			[def1]="${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${results1}${DL}${maintainer}"
			[def2]="${ebuild_eapi}${DL}${oec}${DL}${oelm}${DL}${eapi_found_ebuild}${DL}${nec}${DL}${nelm}${DL}${package_bugs}${DL}${cat}/${pak}${DL}${org_name}${DL}${norm_name}-r${i}${DL}${maintainer}"
		)
		echo "${array_formats[${1}]}"
	}

	output(){
		local output="${1}"
		local file="${FULL_CHECKS[${2}]}"
		if ${FILERESULTS}; then
			output_formats ${output} >> ${file}/full.txt
		else
			echo "${file##*/}${DL}$(output_formats ${output})"
		fi
	}

	# eapi statistics [rs_eaps]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " rs_eaps " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[rs_eaps]/${WORKDIR}\/}" | (debug_output)
		output def0 rs_eaps
	fi

	# keywords statistics [rs_keys]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " rs_keys " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[rs_keys]/${WORKDIR}\/}" | (debug_output)
		results1="${ebuild_keywords}"
		output def1 rs_keys
	fi

	# license statistics [rs_lics]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " rs_lics " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[rs_lics]/${WORKDIR}\/}" | (debug_output)
		local results1="${ebuild_licenses}"
		[[ -n "${results1}" ]] && output def1 rs_lics
	fi

	# inherited eclasses statistics [rs_ecls]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " rs_ecls " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[rs_ecls]/${WORKDIR}\/}" | (debug_output)
		results1="${ebuild_eclasses}"
		[[ -n "${results1}" ]] && output def1 rs_ecls
	fi

	# live ebuilds [rs_livs]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " rs_livs " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[rs_livs]/${WORKDIR}\/}" | (debug_output)
		if $(echo ${pakver}|grep -q 9999) && [[ "${ebuild_keywords}" = "none" ]]; then
			output def0 rs_livs
		fi
	fi

	if [ -n "${ebuild_depend}" ]; then
		# virtual usage statistics [rs_vius]
		if [[ " ${SELECTED_CHECKS[*]} " =~ " rs_vius " ]]; then
			[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[rs_vius]/${WORKDIR}\/}" | (debug_output)
			local vir_tmp=( $(echo ${ebuild_depend}|tr ':' '\n'|grep "virtual/"|cut -d'/' -f2) )
			local results1="$(echo ${vir_tmp[@]}|tr ' ' ':')"
			[ -n "${results1}" ] && output def1 rs_vius
		fi
		# acct group statistics [rs_ggrs]
		if [[ " ${SELECTED_CHECKS[*]} " =~ " rs_ggrs " ]]; then
			[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[rs_ggrs]/${WORKDIR}\/}" | (debug_output)
			local group_tmp=( $(echo ${ebuild_depend}|tr ':' '\n'|grep "acct-group/"|cut -d'/' -f2) )
			local results1="$(echo ${group_tmp[@]}|tr ' ' ':')"
			[ -n "${results1}" ] && output def1 rs_ggrs
		fi
		# acct user statistics [rs_guss]
		if [[ " ${SELECTED_CHECKS[*]} " =~ " rs_guss " ]]; then
			[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[rs_guss]/${WORKDIR}\/}" | (debug_output)
			local user_tmp=( $(echo ${ebuild_depend}|tr ':' '\n'|grep "acct-user/"|cut -d'/' -f2) )
			local results1="$(echo ${user_tmp[@]}|tr ' ' ':')"
			[ -n "${results1}" ] && output def1 rs_guss
		fi
	fi

	# cleanup/stable candidates [rs_clec & rs_stac]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " rs_clec " ]] || [[ " ${SELECTED_CHECKS[*]} " =~ " rs_stac " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[rs_clec]/${WORKDIR}\/} and ${FULL_CHECKS[rs_clec]/${WORKDIR}\/}" | (debug_output)
		local i
		# check for maximal 9 reversion
		for i in $(seq $start 9); do
			if [ -e ${abs_path}/${norm_name}-r${i}.ebuild ]; then
				local found_ebuild="${cat}/${norm_name}-r${i}"
				local eapi_found_ebuild="$(get_eapi ${abs_path}/${norm_name}-r${i}.ebuild)"
				# only ebuild with a greater eapi then $min_allow_eapi are considered
				# candidates for stable requests/cleanup
				# also check if ebuild is masked
				if [ ${eapi_found_ebuild} -ge ${min_allow_eapi} ] && ! $(check_mask ${found_ebuild}); then

					local old_ebuild="${cat}/${pak}/${org_name}.ebuild"
					local new_ebuild="${cat}/${pak}/${norm_name}-r${i}.ebuild"

					if $(count_keywords "${org_name}" "${norm_name}-r${i}" ${cat} ${pak}); then

						local oec="$(get_git_age ${old_ebuild} "ct" "A" "first")"
						local oelm="$(get_git_age ${old_ebuild} "ct" "M" "last")"
						local nec="$(get_git_age ${new_ebuild} "ct" "A" "first")"
						local nelm="$(get_git_age ${new_ebuild} "ct" "M" "last")"
						local package_bugs="__C6__"

						if $(compare_keywords "${org_name}" "${norm_name}-r${i}" ${cat} ${pak}); then
							output def2 rs_clec
						else
							output def2 rs_stac
						fi
					fi
					break 2
				fi
			fi
		done
	fi

	[ ${DEBUGLEVEL} -ge 2 ] && echo "finished with ${1}" | (debug_output)
}

upd_results(){
	if ${FILERESULTS}; then
		# only update rs_clec and rs_stac
		for rcid in rs_clec rs_stac; do
			# check if results were generated
			if [[ -e ${FULL_CHECKS[${rcid}]}/full.txt ]]; then
				local file="${FULL_CHECKS[${rcid}]}/full.txt"
			# otherwise check if old results exists
			elif [[ -e ${RESULTSDIR}/${SCRIPT_TYPE}/${FULL_CHECKS[${rcid}]/${WORKDIR}/}/full.txt ]]; then
				local file="${RESULTSDIR}/${SCRIPT_TYPE}/${FULL_CHECKS[${rcid}]/${WORKDIR}/}/full.txt"
			# unlikly case, do nothing
			else
				local file=""
			fi

			if [[ -n "${file}" ]]; then
				#get time diff since last run
				local indexfile="${RESULTSDIR}/${SCRIPT_TYPE}/${FULL_CHECKS[${rcid}]/${WORKDIR}/}/index.html"
				local time_diff="$(get_time_diff "${indexfile}")"
				for id in $(cat "${file}"); do

					# old ebuild created
					local oec="$(date_update "$(echo ${id}|cut -d'|' -f2)" "${time_diff}")"
					# old ebuild last modified
					local oelm="$(date_update "$(echo ${id}|cut -d'|' -f3)" "${time_diff}")"
					# new ebuild created
					local nec="$(date_update "$(echo ${id}|cut -d'|' -f5)" "${time_diff}")"
					# new ebuild last modified
					local nelm="$(date_update "$(echo ${id}|cut -d'|' -f6)" "${time_diff}")"
					local package="$(echo ${id}|cut -d'|' -f8)"
					$(get_bugs_bool "${package}") && local package_bugs="+" || local package_bugs="-"

					local new_id=$(
						echo "${id}" | gawk -F'|' '{$2=v2; $3=v3; $5=v5; $6=v6; $7=v7}1' \
						v2="${oec}" \
						v3="${oelm}" \
						v5="${nec}" \
						v6="${nelm}" \
						v7="${package_bugs}" OFS='|'
					)

					sed -i "s ${id} ${new_id} g" ${file}
				done
			fi
		done
	fi
}

find_func(){
	[[ ${DEBUGLEVEL} -ge 1 ]] && echo ">>> calling ${FUNCNAME[0]} (MIND:${MIND} MAXD:${MAXD})" | (debug_output)
	[[ ${DEBUGLEVEL} -ge 2 ]] && echo "*** searchpattern is: ${SEARCHPATTERN[@]}" | (debug_output)

	if [ ${DEBUGLEVEL} -ge 2 ]; then
		find ${SEARCHPATTERN[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.ebuild" 2>/dev/null | while read -r line; do main ${line}; done
	else
		find ${SEARCHPATTERN[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.ebuild" 2>/dev/null | parallel main {}
	fi


	# check for empty results and remove them
	clean_results

	[[ ${DEBUGLEVEL} -ge 2 ]] && echo "*** fileresults enabled: ${FILERESULTS}" | (debug_output)
	if ${FILERESULTS}; then
		#gen_descriptions
		var_descriptions
		for s in ${SELECTED_CHECKS[@]}; do
			echo "${!s}" >> ${FULL_CHECKS[${s}]}/description.txt
		done
		upd_results

		# sort the results
		sort_result_v5

		# special sorting for stable/cleanup candidates
		sort_result_column_v1 "1,1 -k8,8" ${FULL_CHECKS[rs_clec]}
		sort_result_column_v1 "1,1 -k8,8" ${FULL_CHECKS[rs_stac]}

		# filter after EAPI/filter
		gen_sort_eapi_v1 ${FULL_CHECKS[rs_eaps]}
		gen_sort_eapi_v1 ${FULL_CHECKS[rs_livs]}
		gen_sort_eapi_v1 ${FULL_CHECKS[rs_obse]}

		gen_sort_filter_v2 4 ${FULL_CHECKS[rs_ecls]}
		gen_sort_filter_v2 4 ${FULL_CHECKS[rs_lics]}
		gen_sort_filter_v2 4 ${FULL_CHECKS[rs_keys]}
		gen_sort_filter_v2 4 ${FULL_CHECKS[rs_vius]}
		gen_sort_filter_v2 4 ${FULL_CHECKS[rs_ggrs]}
		gen_sort_filter_v2 4 ${FULL_CHECKS[rs_guss]}

		gen_sort_main_v5
		gen_sort_pak_v5

		post_checks ${SCRIPT_TYPE}
	fi
}

if [[ ${DEBUGLEVEL} -ge 2 ]]; then
	[[ ${DEBUGLEVEL} -ge 2 ]] && echo "*** starting ${0} (NON-PARALLEL)" | (debug_output)
else
	[[ ${DEBUGLEVEL} -ge 1 ]] && echo "*** starting ${0} (PARALLEL)" | (debug_output)
fi
cd ${REPOTREE}

array_names
RUNNING_CHECKS=( )
for s in ${SELECTED_CHECKS[@]}; do
	RUNNING_CHECKS+=(${FULL_CHECKS[${s}]})
done

export WORKDIR
export -f main array_names
if ${FILERESULTS}; then
	mkdir -p ${RUNNING_CHECKS[@]}
	# create a list and create corresponding folders and files of all available
	# eclasses and licenses before running the check - this way we also see
	# eclasses and licenses without customers.
	[[ ${DEBUGLEVEL} -ge 1 ]] && echo "*** generating various directories" | (debug_output)
	if ${TREE_IS_MASTER}; then
		eclass_list=( $(find ${REPOTREE}/eclass/*.eclass -maxdepth 1 -type f) )
		eclass_list=( ${eclass_list[@]##*/} )
		for ecl in ${eclass_list[@]}; do
			mkdir -p ${FULL_CHECKS[rs_ecls]}/sort-by-filter/${ecl%.*}
			touch ${FULL_CHECKS[rs_ecls]}/sort-by-filter/${ecl%.*}/full.txt
		done
		if [ -d "${REPOTREE}/licenses/" ]; then
			licenses_list=( $(find ${REPOTREE}/licenses/* -maxdepth 1 -type f) )
			licenses_list=( ${licenses_list[@]##*/} )
			for lic in ${licenses_list[@]}; do
				mkdir -p ${FULL_CHECKS[rs_lics]}/sort-by-filter/${lic}
				touch ${FULL_CHECKS[rs_lics]}/sort-by-filter/${lic}/full.txt
			done
		fi
	fi
	if [ -d "${REPOTREE}/virtual/" ]; then
		virtual_list=( $(find ${REPOTREE}/virtual/* -maxdepth 1 -type d) )
		virtual_list=( ${virtual_list[@]##*/} )
		for vir in ${virtual_list[@]}; do
			mkdir -p ${FULL_CHECKS[rs_vius]}/sort-by-filter/${vir}
			touch ${FULL_CHECKS[rs_vius]}/sort-by-filter/${vir}/full.txt
		done
	fi
	if [ -d "${REPOTREE}/acct-group/" ]; then
		group_list=( $(find ${REPOTREE}/acct-group/* -maxdepth 1 -type d) )
		group_list=( ${group_list[@]##*/} )
		for grp in ${group_list[@]}; do
			mkdir -p ${FULL_CHECKS[rs_ggrs]}/sort-by-filter/${grp}
			touch ${FULL_CHECKS[rs_ggrs]}/sort-by-filter/${grp}/full.txt
		done
	fi
	if [ -d "${REPOTREE}/acct-user/" ]; then
		user_list=( $(find ${REPOTREE}/acct-user/* -maxdepth 1 -type d) )
		user_list=( ${user_list[@]##*/} )
		for user in ${user_list[@]}; do
			mkdir -p ${FULL_CHECKS[rs_guss]}/sort-by-filter/${user}
			touch ${FULL_CHECKS[rs_guss]}/sort-by-filter/${user}/full.txt
		done
	fi
fi
depth_set_v4 ${1}
${FILERESULTS} && rm -rf ${WORKDIR}

[[ ${DEBUGLEVEL} -ge 1 ]] && echo "*** finished ${0}" | (debug_output)
