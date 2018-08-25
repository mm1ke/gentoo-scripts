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

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export PORTTREE=/usr/portage/
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/eclassusage/"

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
SCRIPT_NAME="eclassusage"
SCRIPT_SHORT="ECU"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_missing_eclasses"						#Index 0
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_unused_eclasses"							#Index 1
	)
}

array_names
#
### IMPORTANT SETTINGS STOP ###
#

array_eclasses(){
	ECLASSES=( \
		"ltprune;prune_libtool_files" \
		"eutils;emktemp:edos2unix:strip-linguas:make_wrapper:path_exists:use_if_iuse:optfeature:ebeep:in_iuse" \
		"estack;estack_push:estack_pop:evar_push:evar_push_set:evar_pop:eshopts_push:eshopts_pop:eumask_push:eumask_pop:isdigit" \
		"preserve-libs;preserve_old_lib:preserve_old_lib_notify" \
		"vcs-clean;ecvs_clean:esvn_clean:egit_clean" \
		"epatch;epatch:epatch_user" \
		"desktop;make_desktop_entry:make_session_desktop:domenu:newmenu:newicon:doicon" \
		"versionator;get_all_version_components:get_version_components:get_major_version:get_version_componet_range:get_after_major_version:replace_version_separator:replace_all_version_separators:delete_version_separator:delete_all_version_separators:get_version_component_count:get_last_version_component_index:version_is_at_least:version_compare:version_sort:version_format_string"
		"user;egetent:enewuser:enewgroup:egethome:egetshell:esethome"
	)
}

main() {
	array_names
	array_eclasses

	local relative_path=${1}
	local category="$(echo ${relative_path}|cut -d'/' -f2)"
	local package="$(echo ${relative_path}|cut -d'/' -f3)"
	local filename="$(echo ${relative_path}|cut -d'/' -f4)"
	local packagename="${filename%.*}"
	local full_path="${PORTTREE}/${category}/${package}"
	local full_path_ebuild="${PORTTREE}/${category}/${package}/${filename}"
	local maintainer="$(get_main_min "${category}/${package}")"

	if [ "$(get_eapi ${full_path_ebuild})" = "6" ]; then

		local obsol_ecl=( )
		local missing_ecl=( )

		for echeck in ${ECLASSES[@]}; do
			local eclass="$(echo ${echeck}|cut -d';' -f1)"
			local eclass_funcs="$(echo ${echeck}|cut -d';' -f2|tr ':' '|')"

			# check if ebuild uses ${eclass}
			if $(check_eclasses_usage ${full_path_ebuild} ${eclass}); then
				if ! $(grep -qE "${eclass_funcs}" ${full_path_ebuild}); then
					obsol_ecl+=( ${eclass} )
				fi
			# if ebuild doesn't use eclass check the ebuild if one of the functions
			# are used over implicited inheriting
			else
				if $(grep -qE "${eclass_funcs}" ${full_path_ebuild}); then
					missing_ecl+=( ${eclass} )
				fi
			fi
		done

		[ -n "${obsol_ecl}" ] && local o_eclass="$(echo ${obsol_ecl[@]}|tr ' ' ':')"
		[ -n "${missing_ecl}" ] && local m_eclass="$(echo ${missing_ecl[@]}|tr ' ' ':')"

		if ${SCRIPT_MODE}; then
			if [ -n "${o_eclass}" ]; then
				echo "$(get_eapi ${full_path_ebuild})${DL}${category}/${package}${DL}${filename}${DL}${o_eclass}${DL}${maintainer}" >> ${RUNNING_CHECKS[1]}/full.txt
			fi
			if [ -n "${m_eclass}" ]; then
				echo "$(get_eapi ${full_path_ebuild})${DL}${category}/${package}${DL}${filename}${DL}${m_eclass}${DL}${maintainer}" >> ${RUNNING_CHECKS[0]}/full.txt
			fi
		fi

		if [ -n "${o_eclass}" ] || [ -n "${m_eclass}" ]; then
			if ! ${SCRIPT_MODE}; then
				echo "$(get_eapi ${full_path_ebuild})${DL}${category}/${package}${DL}${filename}${DL}MISSING:${m_eclass}${DL}UNUSED:${o_eclass}${DL}${maintainer}"
			fi
		fi


	fi
}

# set the search depth
depth_set ${1}
# switch to the PORTTREE dir
cd ${PORTTREE}
# export important variables
export WORKDIR SCRIPT_SHORT
export -f main array_names array_eclasses

${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}

find ./${level} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec egrep -l 'inherit' {} \; | parallel main {}

if ${SCRIPT_MODE}; then

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
		gen_sort_main_v2 ${RUNNING_CHECKS[0]}/sort-by-filter/${ecd} 5
		gen_sort_pak_v2 ${RUNNING_CHECKS[0]}/sort-by-filter/${ecd} 2
	done

	for ecd2 in $(ls ${RUNNING_CHECKS[1]}/sort-by-filter/); do
		gen_sort_main_v2 ${RUNNING_CHECKS[1]}/sort-by-filter/${ecd2} 5
		gen_sort_pak_v2 ${RUNNING_CHECKS[1]}/sort-by-filter/${ecd2} 2
	done

	gen_sort_main_v2 ${RUNNING_CHECKS[0]} 5
	gen_sort_pak_v2 ${RUNNING_CHECKS[0]} 2

	gen_sort_main_v2 ${RUNNING_CHECKS[1]} 5
	gen_sort_pak_v2 ${RUNNING_CHECKS[1]} 2

	copy_checks checks
	rm -rf ${WORKDIR}
fi
