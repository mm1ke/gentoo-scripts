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
#${ENABLE_MD5} || exit 0				# only works with md5 cache
#${ENABLE_GIT} || exit 0				# only works with git tree

SCRIPT_TYPE="checks"
WORKDIR="/tmp/eclassusage-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/ebuild_missing_eclasses"						#Index 0
		"${WORKDIR}/ebuild_unused_eclasses"							#Index 1
	)
}
output_format(){
	index=(
		"${ebuild_eapi}${DL}${category}/${package}${DL}${filename}${DL}${m_eclass}${DL}${maintainer}"
		"${ebuild_eapi}${DL}${category}/${package}${DL}${filename}${DL}${o_eclass}${DL}${maintainer}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_index0 <<- EOM
Lists ebuilds which use functions of eclasses which are not directly inherited. (usually inherited implicit)
Following eclasses are checked:
	ltprune, eutils, estack, preserve-libs, vcs-clean, epatch,
	desktop, versionator, user, eapi7-ver, flag-o-matic, libtool, pam, udev, xdg-utils

||F  +---> ebuild EAPI   +---> full ebuild name       ebuild maintainer(s) <---+
D|O  |                   |                                                     |
A|R  7 | dev-libs/foo | foo-1.12-r2.ebuild | user:cmake-utils | developer@gentoo.org
T|M       |                                   |
A|A       +---> package category/name         +---> list of eclasses the ebuild should inherit because it uses
||T                                                 functions from it. eclasses are seperated by ':'
EOM
read -r -d '' info_index1 <<- EOM
Lists ebuilds which inherit eclasses but doesn't use their features.
Following eclasses are checked:
	ltprune, eutils, estack, preserve-libs, vcs-clean, epatch, desktop,
	versionator, user, eapi7-ver, flag-o-matic, libtool, pam, udev, xdg-utils

||F  +---> ebuild EAPI   +---> full ebuild name       ebuild maintainer(s) <---+
D|O  |                   |                                                     |
A|R  7 | dev-libs/foo | foo-1.12-r2.ebuild | user:cmake-utils | developer@gentoo.org
T|M       |                                   |
A|A       +---> package category/name         +---> list of eclasses the ebuild inherits but not uses
||T                                                 eclasses are seperated by ':'
EOM
	description=( "${info_index0}" "${info_index1}" )
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
	local full_path_ebuild="${REPOTREE}/${category}/${package}/${filename}"
	local maintainer="$(get_main_min "${category}/${package}")"
	local ebuild_eapi="$(get_eapi ${full_path_ebuild})"

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

		for echeck in ${ECLASSES[@]}; do
			local eclass="$(echo ${echeck}|cut -d';' -f1)"
			local eclass_funcs="$(echo ${echeck}|cut -d';' -f2|tr ':' '|')"

			# don't check for eapi7-ver at EAPI=7 ebuilds
			if [ "${eclass}" = "eapi7-ver" ] && [ "${ebuild_eapi}" = "7" ]; then
				continue
			fi

			# check if ebuild uses ${eclass}
			if $(check_eclasses_usage ${full_path_ebuild} ${eclass}); then
				if ! $(grep -qP "^(?!#).*(?<!-)(${eclass_funcs})" ${full_path_ebuild}); then
					obsol_ecl+=( ${eclass} )
				fi
			# if ebuild doesn't use eclass check the ebuild if one of the functions
			# are used over implicited inheriting
			else
				if $(grep -qP "^(?!.*#).*(?<!-)(${eclass_funcs})" ${full_path_ebuild}); then
					missing_ecl+=( ${eclass} )
				fi
			fi
		done

		[ -n "${obsol_ecl}" ] && local o_eclass="$(echo ${obsol_ecl[@]}|tr ' ' ':')"
		[ -n "${missing_ecl}" ] && local m_eclass="$(echo ${missing_ecl[@]}|tr ' ' ':')"

		if [ -n "${o_eclass}" ]; then
			output 1
		fi
		if [ -n "${m_eclass}" ]; then
			output 0
		fi

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

		for file in $(cat ${RUNNING_CHECKS[0]}/full.txt); do
			for ec in $(echo ${file}|cut -d'|' -f4|tr ':' ' '); do
				mkdir -p ${RUNNING_CHECKS[0]}/sort-by-filter/${ec}.eclass
				echo ${file} >> ${RUNNING_CHECKS[0]}/sort-by-filter/${ec}.eclass/full.txt
			done
		done

		for file2 in $(cat ${RUNNING_CHECKS[1]}/full.txt); do
			for ec2 in $(echo ${file2}|cut -d'|' -f4|tr ':' ' '); do
				mkdir -p ${RUNNING_CHECKS[1]}/sort-by-filter/${ec2}.eclass
				echo ${file2} >> ${RUNNING_CHECKS[1]}/sort-by-filter/${ec2}.eclass/full.txt
			done
		done

		for ecd in $(ls ${RUNNING_CHECKS[0]}/sort-by-filter/); do
			gen_sort_main_v3 ${RUNNING_CHECKS[0]}/sort-by-filter/${ecd}
			gen_sort_pak_v3 ${RUNNING_CHECKS[0]}/sort-by-filter/${ecd}
		done

		for ecd2 in $(ls ${RUNNING_CHECKS[1]}/sort-by-filter/); do
			gen_sort_main_v3 ${RUNNING_CHECKS[1]}/sort-by-filter/${ecd2}
			gen_sort_pak_v3 ${RUNNING_CHECKS[1]}/sort-by-filter/${ecd2}
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
