#!/bin/bash

# Filename: eclassusage.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 26/05/2018

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
#	checks correct usage of eclasses

#override REPOTREE,FILERESULTS,RESULTSDIR settings
#export REPOTREE=/usr/portage/
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/eclassusage/"

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
${ENABLE_MD5} || exit 0				# only works with md5 cache
#${ENABLE_GIT} || exit 0				# only works with git tree

SCRIPT_TYPE="checks"
WORKDIR="/tmp/eclassusage-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/ebuild_missing_eclasses"						#Index 0
		"${WORKDIR}/ebuild_unused_eclasses"							#Index 1
		"${WORKDIR}/ebuild_missing_eclasses_fatal"			#Index 2
	)
}
output_format(){
	index=(
		"${ebuild_eapi}${DL}${category}/${package}${DL}${filename}${DL}$(echo ${missing_ecl[@]}|tr ' ' ':')${DL}${maintainer}"
		"${ebuild_eapi}${DL}${category}/${package}${DL}${filename}${DL}$(echo ${obsol_ecl[@]}|tr ' ' ':')${DL}${maintainer}"
		"${ebuild_eapi}${DL}${category}/${package}${DL}${filename}${DL}$(echo ${missing_ecl_fatal[@]}|tr ' ' ':')${DL}${maintainer}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_index0 <<- EOM
Lists ebuilds which use functions of eclasses which are not directly inherited. (usually inherited implicit)
Following eclasses are checked:
 ltprune, eutils, estack, preserve-libs, vcs-clean, epatch,
 desktop, versionator, user, eapi7-ver, flag-o-matic, libtool, pam, udev, xdg-utils

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|user(enewuser):udev(edev_get)|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
user(enewuser):udev(edev_get)               eclasse(s) and function name the ebuild uses but not inherits, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index1 <<- EOM
Lists ebuilds which inherit eclasses but doesn't use their features.
Following eclasses are checked:
 ltprune, eutils, estack, preserve-libs, vcs-clean, epatch, desktop,
 versionator, user, eapi7-ver, flag-o-matic, libtool, pam, udev, xdg-utils

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|user:udev|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
user:udev                                   eclasse(s) the ebuild inherits but not uses, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index2 <<- EOM
Lists ebuilds which use functions of eclasses which are not directly or indirectly (implicit) inherited.
This would be an fatal error since the ebuild would use a feature which it doesn't know.
Following eclasses are checked:
 ltprune, eutils, estack, preserve-libs, vcs-clean, epatch,
 desktop, versionator, user, eapi7-ver, flag-o-matic, libtool, pam, udev, xdg-utils

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|user(enewuser):udev(edev_get)|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
user(enewuser):udev(edev_get)               eclasse(s) and function name the ebuild uses but not inherits, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
	description=( "${info_index0}" "${info_index1}" "${info_index2}" )
	echo "${description[$1]}"
}
#
### IMPORTANT SETTINGS END ###
#

array_eclasses(){
	ECLASSES=( \
		"optfeature;optfeature" \
		"wrapper;make_wrapper" \
		"edos2unix;edos2unix" \
		"ltprune;prune_libtool_files" \
		"l10n;strip-linguas:l10n_get_locales:l10n_find_plocales_changes:l10n_for_each_disabled_locale_do:l10n_for_each_locale_do" \
		"eutils;emktemp:path_exists:use_if_iuse:ebeep:in_iuse" \
		"estack;estack_push:estack_pop:evar_push:evar_push_set:evar_pop:eshopts_push:eshopts_pop:eumask_push:eumask_pop:isdigit" \
		"preserve-libs;preserve_old_lib:preserve_old_lib_notify" \
		"vcs-clean;ecvs_clean:esvn_clean:egit_clean" \
		"epatch;epatch:epatch_user" \
		"desktop;make_desktop_entry:make_session_desktop:domenu:newmenu:newicon:doicon" \
		"versionator;get_all_version_components:get_version_components:get_major_version:get_version_component_range:get_after_major_version:replace_version_separator:replace_all_version_separators:delete_version_separator:delete_all_version_separators:get_version_component_count:get_last_version_component_index:version_is_at_least:version_compare:version_sort:version_format_string"
		"user;egetent:enewuser:enewgroup:egethome:egetshell:esethome" \
		"flag-o-matic;filter-flags:filter-lfs-flags:filter-ldflags:append-cppflags:append-cflags:append-cxxflags:append-fflags:append-lfs-flags:append-ldflags:append-flags:replace-flags:replace-cpu-flags:is-flagq:is-flag:is-ldflagq:is-ldflag:filter-mfpmath:strip-flags:test-flag-CC:test-flag-CXX:test-flag-F77:test-flag-FC:test-flags-CC:test-flags-CXX:test-flags-F77:test-flags-FC:test-flags:test_version_info:strip-unsupported-flags:get-flag:replace-sparc64-flags:append-libs:raw-ldflags:no-as-needed" \
		"xdg-utils;xdg_environment_reset:xdg_desktop_database_update:xdg_icon_cache_update:xdg_mimeinfo_database_update" \
		"libtool;elibtoolize" \
		"udev;udev_get_udevdir:get_udevdir:udev_dorules:udev_newrules:udev_reload" \
		"eapi7-ver;ver_cut:ver_rs:ver_test" \
		"pam;dopamd:newpamd:dopamsecurity:newpamsecurity:getpam_mod_dir:pammod_hide_symbols:dopammod:newpammod:pamd_mimic_system:pamd_mimic:cleanpamd:pam_epam_expand" \
		"ssl-cert;gen_cnf:get_base:gen_key:gen_csr:gen_crt:gen_pem:install_cert"
	)
}

main() {
	array_names
	array_eclasses

	local relative_path=${1}
	local category="$(echo ${relative_path}|cut -d'/' -f1)"
	local package="$(echo ${relative_path}|cut -d'/' -f2)"
	local filename="$(echo ${relative_path}|cut -d'/' -f3)"
	local packagename="${filename%.*}"
	local full_path="${REPOTREE}/${category}/${package}"
	local maintainer="$(get_main_min "${category}/${package}")"
	local ebuild_eapi="$(get_eapi ${relative_path})"
	local full_md5path="${REPOTREE}/metadata/md5-cache/${category}/${packagename}"

	output(){
		local checkid=${1}
		if ${FILERESULTS}; then
			output_format ${checkid} >> ${RUNNING_CHECKS[${checkid}]}/full.txt
		else
			echo "${RUNNING_CHECKS[${checkid}]##*/}${DL}$(output_format ${checkid})"
		fi
	}


	if [ "${ebuild_eapi}" = "6" ] || [ "${ebuild_eapi}" = "7" ]; then

		local obsol_ecl=( )
		local missing_ecl=( )
		local missing_ecl_fatal=( )
		local func_in_use=( )
		local func_in_use_fatal=( )

		for echeck in ${ECLASSES[@]}; do
			local eclass="$(echo ${echeck}|cut -d';' -f1)"
			local eclass_funcs="$(echo ${echeck}|cut -d';' -f2|tr ':' ' ')"

			# don't check for eapi7-ver at EAPI=7 ebuilds
			if [ "${eclass}" = "eapi7-ver" ] && [ "${ebuild_eapi}" = "7" ]; then
				continue
			fi

			# check if ebuild uses ${eclass}
			if $(check_eclasses_usage ${relative_path} ${eclass}); then
				# check if ebuild uses one of the functions provided by the eclass
				local catch=false
				for i in ${eclass_funcs}; do
					if $(grep -qP "^(?!#).*(?<!-)((^|\W)${i}(?=\W|$))" ${relative_path}); then
						catch=true
						break
					fi
				done
				${catch} || obsol_ecl+=( ${eclass} )
			# check the ebuild if one the eclass functions are used
			else
				# get the fucntion(s) which are used by the ebuild, if any
				for e in ${eclass_funcs}; do
					if $(grep -qP "^(?!.*#).*(?<!-)((^|\W)${e}(?=\W|$))" ${relative_path}); then
						# in_iuse (from eutils) is implemented in pms from EAPI6 onward
						if [ "${e}" == "in_iuse" ] && [ ${ebuild_eapi} -ge 6 ]; then
							continue
						fi
						# check if ebuild provides function by its own
						if ! $(grep -qP "^(?!.*#).*(?<!-)(${e}\(\)(?=\s|$))" ${relative_path}); then
							# if the ebuild uses one of the function, check if the eclass is
							# inherited implicit (most likley), otherwise it's a clear error
							local all_eclasses="$(get_eclasses_real ${full_md5path})"
							if ! $(echo "${all_eclasses}" | grep -q ${eclass}); then
								func_in_use_fatal+=( ${e} )
							fi
							func_in_use+=( ${e} )
						fi
					fi
				done
				[ -n "${func_in_use}" ] && \
					missing_ecl+=( "${eclass}($(echo ${func_in_use[@]}|tr ' ' ','))" )
				[ -n "${func_in_use_fatal}" ] && \
					missing_ecl_fatal+=( "${eclass}($(echo ${func_in_use_fatal[@]}|tr ' ' ','))" )
			fi
			func_in_use=( )
			func_in_use_fatal=( )
		done

		[ -n "${obsol_ecl}" ] && output 1
		[ -n "${missing_ecl}" ] && output 0
		[ -n "${missing_ecl_fatal}" ] && output 2

	fi
}

find_func(){
	find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
		-type f -name "*.ebuild" -exec egrep -l "inherit" {} \; | parallel main {}
}

gen_results(){
	if ${FILERESULTS}; then
		gen_descriptions
		sort_result_v2 2

		for rc in ${RUNNING_CHECKS[@]}; do
			for file in $(cat ${rc}/full.txt); do
				for ec in $(echo ${file}|cut -d'|' -f4|tr ':' '\n'|cut -d'(' -f1); do
					mkdir -p ${rc}/sort-by-filter/${ec}.eclass
					echo ${file} >> ${rc}/sort-by-filter/${ec}.eclass/full.txt
				done
			done
		done

		for rc2 in ${RUNNING_CHECKS[@]}; do
			for ecf in $(ls ${rc2}/sort-by-filter/); do
				gen_sort_main_v3 ${rc2}/sort-by-filter/${ecf}
				gen_sort_pak_v3 ${rc2}/sort-by-filter/${ecf}
			done
		done

		gen_sort_main_v3
		gen_sort_pak_v3

		copy_checks ${SCRIPT_TYPE}
	fi
}

array_names
# switch to the REPOTREE dir
cd ${REPOTREE}
# export important variables
export WORKDIR
export -f main array_names array_eclasses output_format
${FILERESULTS} && mkdir -p ${RUNNING_CHECKS[@]}
# set the search depth
depth_set_v2 ${1}
# cleanup tmp files
${FILERESULTS} && rm -rf ${WORKDIR}
