#!/bin/bash

# Filename: patchtest
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 01/08/2016

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
# simple scirpt to find unused patches in the gentoo portage tree

#override REPOTREE,FILERESULTS,RESULTSDIR settings
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/patchtest/"
#export REPOTREE=/usr/portage/
# enabling debug output
#export DEBUG=true
#export DEBUGLEVEL=1
#export DEBUGFILE=/tmp/patchtest.log

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

if [ -z "${PT_WHITELIST}" ]; then
	WFILE="${realdir}/whitelist"
else
	WFILE="${realdir}/${PT_WHITELIST}"
fi

SCRIPT_TYPE="checks"
WORKDIR="/tmp/patchtest-${RANDOM}/"
array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/ebuild_unused_patches"									#Index 0
	)
}
output_format(){
	index=(
		"${category}/${package}${DL}${upatch}${DL}${main}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_index0 <<- EOM
Extensive check to find unused pachtes. In order to reduce flase positives it uses a whilelist to exclude them.

Data Format ( dev-libs/foo|foo-fix-1.12.patch|dev@gentoo.org:loper@foo.de ):
dev-libs/foo                                package category/name
foo-fix-1.12.patch                          patch which is not used by any ebuild
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
	description=( "${info_index0}" )
	echo "${description[$1]}"
}
#
### IMPORTANT SETTINGS END ###
#

main(){
	check_ebuild(){

		local patchfile=$1

		local found=false

		local pn='${PN}'
		local p='${P}'
		local pf='${PF}'
		local pv='${PV}'
		local pvr='${PVR}'
		local slot='${SLOT}'
		local var_my_pn='${MY_PN}'
		local var_my_p='${MY_P}'
		local var_my_pv='${MY_PV}'
		local var_mod_ver='${MODULE_VERSION}'
		local var_dist_ver='${DIST_VERSION}'
		local var_x509_ver='${X509_VER}'
		local var_hpn_ver='${HPN_VER}'

		[ ${DEBUGLEVEL} -ge 2 ] && echo " 1-check_ebuild: checking: ${patchfile}" | (debug_output)

		for ebuild in ${fullpath}/*.ebuild; do
			[ ${DEBUGLEVEL} -ge 2 ] && echo " 1-check_ebuild:  looking into: ${ebuild}" | (debug_output)

			# get ebuild detail
			local ebuild_full=$(basename ${ebuild%.*})
			local ebuild_version=$(echo ${ebuild_full/${package}}|cut -d'-' -f2)
			local ebuild_revision=$(echo ${ebuild_full/${package}}|cut -d'-' -f3)
			local ebuild_slot="$(grep ^SLOT $ebuild|cut -d'"' -f2)"
			local package_name_ver="${package}-${ebuild_version}"

			[ ${DEBUGLEVEL} -ge 3 ] && echo " 1-check_ebuild:  ebuild details: ver: $ebuild_version rever: $ebuild_revision slot: $ebuild_slot" | (debug_output)

			local cn_name_vers="${patchfile/${package}/${pn}}"
			local cn=( )

			# create custom names to check
			cn+=("${patchfile}")
			cn+=("${patchfile/${package}/${pn}}")
			cn+=("${patchfile/${package}-${ebuild_version}/${p}}")
			cn+=("${patchfile/${ebuild_version}/${pv}}")

			cn+=("${cn_name_vers/${ebuild_version}/${pv}}")
			# add special naming if there is a revision
			if [ -n "${ebuild_revision}" ]; then
				cn+=("${patchfile/${package}-${ebuild_version}-${ebuild_revision}/${pf}}")
				cn+=("${patchfile/${ebuild_version}-${ebuild_revision}/${pvr}}")
			fi
			# looks for names with slotes, if slot is not 0
			if [ -n "${ebuild_slot}" ] && ! [ "${ebuild_slot}" = "0" ]; then
				cn+=("${patchfile/${ebuild_slot}/${slot}}")
				cn+=("${cn_name_vers/${ebuild_slot}/${slot}}")
			fi

			# special naming
			if $(grep -q -E "^MY_PN=|^MY_P=|^MY_PV=|^MODULE_VERSION=|^DIST_VERSION=|^X509_VER=|^HPN_VER=" ${ebuild}); then

				# get the variables from the ebuilds

				# MY_PN and other such variables often are constructed with the usage of
				# global variables like $PN and $PV.
				# With using eval these variables are replaces by it's real content
				my_pn_name="$(grep ^MY_PN\= ${ebuild} | cut -d' ' -f1 | cut -d'=' -f2 | sed -e "s|PN|package|g" -e 's|"||g')"
				[ -n "${my_pn_name}" ] && eval my_pn_name="$(echo ${my_pn_name})" >/dev/null 2>&1
				my_pv_name="$(grep ^MY_PV\= ${ebuild} | cut -d' ' -f1 | cut -d'=' -f2 | sed -e "s|PV|ebuild_version|g" -e 's|"||g')"
				[ -n "${my_pv_name}" ] && eval my_pv_name="$(echo ${my_pv_name})" >/dev/null 2>&1
				my_p_name="$(grep ^MY_P\= ${ebuild} | cut -d' ' -f1 | cut -d'=' -f2 | sed -e "s|P|package_name_ver|g" -e 's|"||g')"
				[ -n "${my_p_name}" ] && eval my_p_name="$(echo ${my_p_name})" >/dev/null 2>&1

				my_mod_ver="$(grep ^MODULE_VERSION\= ${ebuild} | cut -d' ' -f1 | cut -d'=' -f2 | sed -e 's|"||g')"
				my_dist_ver="$(grep ^DIST_VERSION\= ${ebuild} | cut -d' ' -f1 | cut -d'=' -f2 | sed -e 's|"||g')"
				my_x509_ver="$(grep ^X509_VER\= ${ebuild} | cut -d' ' -f1 | cut -d'=' -f2 | sed -e 's|"||g')"
				my_hpn_ver="$(grep ^HPN_VER\= ${ebuild} | cut -d' ' -f1 | cut -d'=' -f2 | sed -e 's|"||g')"


				[ ${DEBUGLEVEL} -ge 3 ] && echo " 1-check_ebuild:  Found special vars: $my_pv_name, $my_pn_name, $my_p_name, $my_mod_ver, $my_dist_ver, $my_x509_ver, $my_hpn_ver" | (debug_output)

				[ -n "${my_pn_name}" ] && cn+=("${patchfile/${my_pn_name}/${var_my_pn}}")
				[ -n "${my_pv_name}" ] && cn+=("${patchfile/${my_pv_name}/${var_my_pv}}")
				[ -n "${my_p_name}" ] && cn+=("${patchfile/${my_p_name}/${var_my_p}}")

				local tmpvar=""

				if [ -n "${my_mod_ver}" ]; then
					cn+=("${patchfile/${my_mod_ver}/${var_mod_ver}}")
					tmpvar="${patchfile/${my_mod_ver}/${var_mod_ver}}"
					cn+=("${tmpvar/${package}/${pn}}")
				fi

				if [ -n "${my_dist_ver}" ]; then
					cn+=("${patchfile/${my_dist_ver}/${var_dist_ver}}")
					tmpvar="${patchfile/${my_dist_ver}/${var_dist_ver}}"
					cn+=("${tmpvar/${package}/${pn}}")
				fi

				if [ -n "${my_x509_ver}" ]; then
					cn+=("${patchfile/${my_x509_ver}/${var_x509_ver}}")
					tmpvar="${patchfile/${my_x509_ver}/${var_x509_ver}}"
					cn+=("${tmpvar/${package}/${pn}}")
					cn+=("${tmpvar/${package}-${ebuild_version}/${p}}")
				fi

				if [ -n "${my_hpn_ver}" ]; then
					cn+=("${patchfile/${my_hpn_ver}/${var_hpn_ver}}")
					tmpvar="${patchfile/${my_hpn_ver}/${var_hpn_ver}}"
					cn+=("${tmpvar/${package}/${pn}}")
					cn+=("${tmpvar/${package}-${ebuild_version}/${p}}")
				fi
			fi

			# remove duplicates
			mapfile -t cn < <(printf '%s\n' "${cn[@]}"|sort -u)
			# replace list with newpackages
			local searchpattern="$(echo ${cn[@]}|tr ' ' '\n')"
			[ ${DEBUGLEVEL} -ge 3 ] && echo " 1-check_ebuild:  Custom names: $(echo ${cn[@]}|tr ' ' ':')" | (debug_output)

			# check ebuild for the custom names
			if $(sed 's|"||g' ${ebuild} | grep -q -F "${searchpattern}"); then
				[ ${DEBUGLEVEL} -ge 2 ] && echo " 1-check_ebuild: FOUND: ${patchfile}" | (debug_output)
				return 0
			else
				[ ${DEBUGLEVEL} -ge 3 ] && echo " 1-check_ebuild: NOT FOUND: ${patchfile}" | (debug_output)
			fi
		done

		return 1
	}

	# white list checking
	white_check() {
		local pfile=${1}
		[ ${DEBUGLEVEL} -ge 3 ] && echo " 0-whitelist: checking ${pfile} in ${WFILE}" | (debug_output)

		if [ -e ${WFILE} ]; then
			source ${WFILE}
		else
			[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-whitelist: ${WFILE} - file not found" | (debug_output)
			return 1
		fi

		if $(echo ${white_list[@]} | grep -q "${category}/${package};${pfile}"); then
			# detailed output only if debugging is enabled
			if [ ${DEBUGLEVEL} -ge 2 ]; then
				for white in ${white_list[@]}; do
					local cat_pak="$(echo ${white}|cut -d';' -f1)"
					local white_file="$(echo ${white}|cut -d';' -f2)"
					local white_ebuild="$(echo ${white}|cut -d';' -f3)"
					if [ "${category}/${package};${pfile}" = "${cat_pak};${white_file}" ]; then
						if [ "${white_ebuild}" = "*" ]; then
							[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-whitelist: found patch ${pfile} in all ebuilds" | (debug_output)
							return 0
						else
							for wbuild in $(echo ${white_ebuild} | tr ':' ' '); do
								if [ -e "${REPOTREE}/${full_package}/${wbuild}" ]; then
									[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-whitelist: found patch ${pfile} in ${wbuild}" | (debug_output)
									return 0
								fi
							done
						fi
						[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-whitelist: error in whitecheck with ${pfile}" | (debug_output)
						return 1
					fi
				done
			fi
			return 0
		else
			return 1
		fi
	}

	eclass_prechecks() {
		local pfile="${1}"

		if [ "${pfile}" = "rc-addon.sh" ]; then
			if $(grep -q vdr-plugin-2 ${fullpath}/*.ebuild); then
				[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-prechecks: file is rc-addon.sh and used in vdr-plugin-2.eclass" | (debug_output)
				return 0
			else
				return 1
			fi
		# check for vdr-plugin-2 eclass which installs confd files if exists
		elif [ "${pfile}" = "confd" ]; then
			if $(grep -q vdr-plugin-2 ${fullpath}/*.ebuild); then
				[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-prechecks: file is confd and used in vdr-plugin-2.eclass" | (debug_output)
				return 0
			else
				return 1
			fi
		# check for apache-module eclass which installs conf files if a APACHE2_MOD_CONF is set
		elif [ "${pfile##*.}" = "conf" ]; then
			if $(grep -q apache-module ${fullpath}/*.ebuild) && \
				$(grep -q APACHE2_MOD_CONF ${fullpath}/*.ebuild); then
				[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-prechecks: file is conf and used in apache-module.eclass" | (debug_output)
				return 0
			else
				return 1
			fi
		# check for elisp eclass which install el files if a SITEFILE is set
		elif [ "${pfile##*.}" = "el" ]; then
			if $(grep -q elisp ${fullpath}/*.ebuild) && \
				$(grep -q SITEFILE ${fullpath}/*.ebuild); then
				[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-prechecks: file is el and used in elisp.eclass" | (debug_output)
				return 0
			else
				return 1
			fi
		# ignoring README.gentoo files
		elif $(echo ${pfile}|grep -i README.gentoo >/dev/null); then
			if $(grep -q readme.gentoo ${fullpath}/*.ebuild); then
				[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-prechecks: file is readme.gentoo and used in readme.gentoo-r1.eclass" | (debug_output)
				return 0
			else
				return 1
			fi
		else
			[ ${DEBUGLEVEL} -ge 3 ] && echo " 0-prechecks: ${pfile} is not used in inherited eclasses!" | (debug_output)
			return 1
		fi
	}

	# output function
	output() {
		local id=${1}
		if ${FILERESULTS}; then
			for upatch in "${unused_patches[@]}"; do
				output_format ${id} >> ${RUNNING_CHECKS[${id}]}/full.txt
			done
		else
			for upatch in "${unused_patches[@]}"; do
				output_format ${id}
			done
		fi
	}

	# expect patches in braces to look like
	# 	packagename-{patch1,patch2}
	# 	$PN-{patch1,patch2}
	#   or
	# 	packagename-version-{patch1,patch2}
	# 	${P}-${PV}-{patch1,patch2}
	#   or
	# 	packagename-versoin-genname-{patch1,patch2}
	#
	# This means 1-3 parts of a filename before '-' should be
	# found at least 2 times
	find_patches_in_braces() {
		local work_list=( $(echo ${1}|tr ':' ' ') )

		[ ${DEBUGLEVEL} -ge 2 ] && echo " 2-brace_patches: checking ${work_list[@]}" | (debug_output)

		local common_pattern=( )
		local patches_to_remove=( )
		local patch
		for patch in "${work_list[@]}"; do
			# how often contains the name the seperator '-'
			local deli=$(echo ${patch%.patch}|grep -o '-'|wc -w)
			# try find duplicates, starting with the highest count of $deli
			for n in $(echo $(seq 1 ${deli})|rev); do
				if [ $(echo ${work_list[@]}|tr ' ' '\n'|grep $(echo ${patch}|cut -d'-' -f1-${n})|wc -l) -gt 1 ]; then
					[ ${DEBUGLEVEL} -ge 3 ] && echo " 2-brace_patches: pattern candidate: $(echo ${patch}|cut -d'-' -f1-${n})" | (debug_output)
					common_pattern+=("$(echo ${patch}|cut -d'-' -f1-${n})")
					break
				fi
			done
		done
		# remove duplicates from array
		mapfile -t common_pattern < <(printf '%s\n' ${common_pattern[@]}|sort -u)

		if [ -n "${common_pattern}" ]; then
			[ ${DEBUGLEVEL} -ge 3 ] && echo " 2-brace_patches: found patterns ${common_pattern[@]}" | (debug_output)
			local x p
			for x in ${common_pattern[@]}; do
				local braces_patches=( )
				[ ${DEBUGLEVEL} -ge 2 ] && echo " 2-brace_patches: checking pattern ${x}" | (debug_output)

				# find duplicates files by pattern $x and strip everything away
				local matching=( $(find ${fullpath}/files/ -type f -name "${x}*" -printf '%f\n'|sed -e 's/.patch//' -e "s/${x}-//") )

				# do not make permutations with greater then 5 matchings
				if [ ${#matching[@]} -le 5 ]; then
					local permutations=$(get_perm "$(echo ${matching[@]})")
					[ ${DEBUGLEVEL} -ge 3 ] && echo " 2-brace_patches: create permutations with $(echo ${matching[@]})" | (debug_output)
					for p in ${permutations}; do
						braces_patches+=("$(echo ${x}-{${p}}.patch)")
					done

					[ ${DEBUGLEVEL} -ge 2 ] && echo " 2-brace_patches: found ${braces_patches[@]}" | (debug_output)
					local t u
					for t in ${braces_patches[@]}; do
						if $(check_ebuild ${t}); then
							for u in ${matching[@]}; do
								patches_to_remove+=( "${x}-${u}.patch" )
							done
							break
						fi
					done
				else
					[ ${DEBUGLEVEL} -ge 3 ] && echo " 2-brace_patches: to much candidates, skipping" | (debug_output)
				fi
			done
			echo "${patches_to_remove[@]}"
		else
			echo ""
		fi
	}

	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f1)"
	package="$(echo ${full_package}|cut -d'/' -f2)"
	main="$(get_main_min "${category}/${package}")"
	fullpath="/${REPOTREE}/${full_package}"

	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking: ${category}/${package}" | (debug_output)
	# check if the patches folder exist
	if [ -e ${fullpath}/files ]; then
		[ ${DEBUGLEVEL} -ge 3 ] && echo "found files dir in: ${category}/${package}/files" | (debug_output)

		# before checking, we have to generate a list of patches which we have to check
		patch_list=()

		# prechecks and patchlist generation
		#  every file found will be checked against the whitelist (white_check) and
		#  checked for the usage of certain eclasses (which are know to use certain
		#  files from the FILESDIR directory directly.
		[ ${DEBUGLEVEL} -ge 3 ] && echo "prechecks: whitelist and special eclasses" | (debug_output)
		for file in ${fullpath}/files/*; do
			# ignore directories
			if ! [ -d ${file} ]; then
				file="${file##*/}"
				if ! $(white_check ${file}); then
					# elcass-prechecks
					if $(echo ${file##*/}|grep -q -E "\.el|conf|rc-addon.sh|README*"); then
						if ! $(eclass_prechecks ${file}); then
							patch_list+=("${file}")
						fi
					else
						patch_list+=("${file}")
					fi
				fi
			fi
		done
		[ ${DEBUGLEVEL} -ge 2 ] && echo "prechecks done: patchlist: ${patch_list[@]}" | (debug_output)


		# only continue if we found actually files to check
		if [ -n "${patch_list}" ]; then

			# first check
			#  every patchfile from $patch_list gets passed to check_ebuild, which
			#  replaces names and version with their corresponding ebuild name
			#  ($PN, PV, ..) and grep's the ebuild with them.
			[ ${DEBUGLEVEL} -ge 3 ] && echo "starting basic check for: ${patch_list[@]}" | (debug_output)
			unused_patches=()
			for patchfile in "${patch_list[@]}"; do
				if ! $(check_ebuild "${patchfile}"); then
					unused_patches+=("${patchfile}")
				fi
			done
			[ ${DEBUGLEVEL} -ge 2 ] && echo "basic check done, unused patches are: ${unused_patches[@]}" | (debug_output)

			# second check
			# find patches in braces (works only with *.patch files)
			# short description:
			#  find_braces_candidates:
			#   this function takes a list of patch file, and looks if the names
			#   look similar (except for the last part: patch-1, patch-2, ...)
			#   If yes it returns back that part of the filename which is the same.

			#  braces_patches:
			#   this function takes the filename which is the same and add the different
			#   ending in braces (like patch-{1,2,3}). In order to get other combinations
			#   it uses a python script to generate permutations.
			#   Also generates a list of filenames with the correct names, in order to remove the
			#   patches from the list if found.

			#  The filename list which was generated by the braces_patches function gets
			#  checked against the ebuilds via check_ebuild
			#
			# examples: app-editors/zile, app-office/scribus, app-office/libreoffice,
			# dev-cpp/antlr-cpp, dev-qt/qtcore, games-arcade/supertux
			[ ${DEBUGLEVEL} -ge 3 ] && echo "starting second check for: ${unused_patches[@]}" | (debug_output)
			if [ ${#unused_patches[@]} -ge 1 ]; then
				for patchfile in $(find_patches_in_braces "$(echo ${unused_patches[@]}|tr ' ' ':')"); do
					[ ${DEBUGLEVEL} -ge 2 ] && echo "patch to remove: ${patchfile}" | (debug_output)
					for target in "${!unused_patches[@]}"; do
						if [ "${unused_patches[target]}" = "${patchfile}" ]; then
							unset 'unused_patches[target]'
						fi
					done
				done
			fi
			[ ${DEBUGLEVEL} -ge 2 ] && echo "NEW finish second check, remaining patches: ${unused_patches[@]}" | (debug_output)

			# third check
			# find pachtes which are called with an asterix (*)
			# net-misc/icaclient, app-admin/consul
			if [ -n "${unused_patches}" ]; then
				[ ${DEBUGLEVEL} -ge 3 ] && echo "starting third check for: ${unused_patches[@]}" | (debug_output)
				for aster_ebuild in ${fullpath}/*.ebuild; do
					for a in $(grep -E 'FILESDIR.*\*' ${aster_ebuild} ); do
						[ ${DEBUGLEVEL} -ge 2 ] && echo " 3-asterixes: found asterixes in ebuild" | (debug_output)
						if $(echo ${a}|grep -q FILESDIR); then
							if ! [ $(echo ${a}|grep -o '[/]'|wc -l) -gt 1 ]; then
								snip="$(echo ${a}|cut -d'/' -f2|grep \*|tr -d '"')"

								local pn='${PN}'
								local p='${P}'
								local pv='${PV}'
								local ebuild_full=$(basename ${aster_ebuild%.*})
								local ebuild_version=$(echo ${ebuild_full/${package}}|cut -d'-' -f2)

								snip="${snip/${p}/${package}-${ebuild_version}}"
								snip="${snip/${pv}/${ebuild_version}}"
								snip="${snip/${pn}/${package}}"

								b="ls ${fullpath}/files/${snip}"
								asterix_patches=$(eval ${b} 2> /dev/null)
								[ ${DEBUGLEVEL} -ge 3 ] && echo " 3-asterixes: found following snipped: $(echo ${a}|cut -d'/' -f2|grep \*|tr -d '"')" | (debug_output)
								[ ${DEBUGLEVEL} -ge 2 ] && echo " 3-asterixes: matching following files: ${asterix_patches}" | (debug_output)
								for x in ${asterix_patches}; do
									if $(echo ${unused_patches[@]} | grep $(basename ${x}) >/dev/null); then
										asterix_remove=$(basename ${x})
										[ ${DEBUGLEVEL} -ge 2 ] && echo " 3-asterixes: removing from list: ${asterix_remove}" | (debug_output)
										for target in "${!unused_patches[@]}"; do
											if [ "${unused_patches[target]}" = "${asterix_remove}" ]; then
												unset 'unused_patches[target]'
											fi
										done
									fi
								done
								[ "${#unused_patches[@]}" -eq 0 ] && break 2
							fi
						fi
					done
				done
			fi

			array_names
			if [ ${#unused_patches[@]} -gt 0 ]; then
				[ ${DEBUGLEVEL} -ge 2 ] && echo "found unused patches: ${unused_patches[@]}" | (debug_output)
				output 0
			else
				[ ${DEBUGLEVEL} -ge 3 ] && echo "found zero unused patches" | (debug_output)
			fi

			[ ${DEBUGLEVEL} -ge 2 ] && echo | (debug_output)
			[ ${DEBUGLEVEL} -ge 2 ] && echo | (debug_output)
		else
			[ ${DEBUGLEVEL} -ge 3 ] && echo "skipping: ${category}/${package} has files directory, but no there are no files to check" | (debug_output)
		fi
	else
		[ ${DEBUGLEVEL} -ge 3 ] && echo "skipping: ${category}/${package} has no files directory" | (debug_output)
	fi
}

find_func(){
# Dont use parallel if DEBUG is enabled
	if [ ${DEBUGLEVEL} -ge 2 ]; then
		[ ${DEBUGLEVEL} -ge 2 ] && echo "NORMAL run: searchpattern is ${searchp[@]}" | (debug_output)
		find ${searchp[@]} -mindepth ${MIND} -maxdepth ${MAXD} \
			-type d -print 2>/dev/null | while read -r line; do
			main ${line}
		done
	else
		[ ${DEBUGLEVEL} -ge 1 ] && echo "PARALLEL run: searchpattern is ${searchp[@]}" | (debug_output)
		find ${searchp[@]} -mindepth ${MIND} -maxdepth ${MAXD} \
			-type d -print 2>/dev/null | parallel main {}
	fi

	if ${FILERESULTS}; then
		gen_descriptions
		sort_result_v2
		gen_sort_main_v3
		gen_sort_pak_v3

		copy_checks ${SCRIPT_TYPE}
	fi
}

[ ${DEBUGLEVEL} -ge 1 ] && echo "*** starting patchtest" | (debug_output)

cd ${REPOTREE}
array_names
export -f main array_names output_format
export WORKDIR WFILE
${FILERESULTS} && mkdir -p ${RUNNING_CHECKS[@]}
depth_set_v3 ${1}
${FILERESULTS} && rm -rf ${WORKDIR}

[ ${DEBUGLEVEL} -ge 1 ] && echo "*** finished patchtest" | (debug_output)
