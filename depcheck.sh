#!/bin/bash

# Filename: depcheck.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 28/03/2018

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
# simply script to find packages in (R)DEPEND block which
# doesn't exist anymore (mainly obsolete blocks via !category/package)

#override REPOTREE,FILERESULTS,RESULTSDIR settings
#export REPOTREE=/usr/portage/
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/depcheck/"

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
# don't run on overlays because dependencies are most likely only
# available at the main tree
${TREE_IS_MASTER} || exit 0			# only works with gentoo main tree
${ENABLE_MD5} || exit 0					# only works with md5 cache
#${ENABLE_GIT} || exit 0				# only works with git tree

WORKDIR="/tmp/depcheck-${RANDOM}"
SCRIPT_TYPE="checks"

array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/ebuild_nonexist_dependency"									#Index 0
	"${WORKDIR}/ebuild_obsolete_virtual"										#Index 1
	)
}
output_format(){
	index=(
		"$(get_eapi ${full_path_ebuild})${DL}${category}/${package}${DL}${filename}${DL}$(echo ${obsolete_dep[@]}|tr ' ' ':')${DL}${maintainer}"
		"$(get_eapi ${full_path_ebuild})${DL}${category}/${package}${DL}${filename}${DL}${maintainer}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_index0 <<- EOM
This checks the ebuilds *DEPEND* Blocks for packages which doesn't exist anymore.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|sys-apps/bar:dev-libs/libdir(2015-08-13)|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
sys-apps/bar:dev-libs/libdir(2015-08-13)    non-existing package(s). If removed after git migration a removal date is shown.
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index1 <<- EOM
Lists virtuals were only one provider is still available.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
	description=( "${info_index0}" "${info_index1}" )
	echo "${description[$1]}"
}
#
### IMPORTANT SETTINGS END ###
#

main() {
	array_names
	local absolute_path=${1}
	local category="$(echo ${absolute_path}|cut -d'/' -f1)"
	local package="$(echo ${absolute_path}|cut -d'/' -f2)"
	local filename="$(echo ${absolute_path}|cut -d'/' -f3)"
	local packagename="${filename%.*}"
	local full_path="${REPOTREE}/${category}/${package}"
	local full_path_ebuild="${REPOTREE}/${category}/${package}/${filename}"
	local maintainer="$(get_main_min "${category}/${package}")"


	local found=false
	local obsolete_dep=()
	local dependencies=( $(grep DEPEND /${REPOTREE}/metadata/md5-cache/${category}/${packagename}|grep -oE "[a-zA-Z0-9-]{2,30}/[+a-zA-Z_0-9-]{2,80}"|sed 's/-[0-9].*//g'|sort -u) )

	for dep in ${dependencies[@]}; do
		if $(grep ${dep} ${full_path_ebuild} >/dev/null 2>&1); then
			if ! [ -e "${REPOTREE}/${dep}" ]; then
				# provide gitage if git is available
				if ${ENABLE_GIT}; then
					local deadage="$(get_age_date "${dep}")"
					if [ -n "${deadage}" ]; then
						dep="${dep}(${deadage})"
					fi
				fi
				obsolete_dep+=( "${dep}" )
				found=true
			fi
		fi
	done

	output() {
		local id=${1}
		if ${FILERESULTS}; then
			output_format ${id} >> ${RUNNING_CHECKS[${id}]}/full.txt
		else
			output_format ${id}
		fi
	}

	if ${found} && [ "${category}" = "virtual" ]; then
		if [ $(expr ${#dependencies[@]}) -eq 1 ] && [ $(grep ${dependencies[0]} ${full_path_ebuild} | wc -l) -gt 1 ]; then
			continue
		else
			if [ $(expr ${#dependencies[@]} - ${#obsolete_dep[@]}) -le 1 ]; then
				output 1
			fi
		fi
	fi


	if ${found}; then
		output 0
	fi
}

find_func(){
	find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
		-type f -name "*.ebuild" -exec egrep -l "DEPEND" {} \; | parallel main {}
}

gen_results() {
	if ${FILERESULTS}; then
		gen_descriptions
		sort_result_v2 2

		for file in $(cat ${RUNNING_CHECKS[0]}/full.txt); do
			for fp in $(echo ${file}|cut -d'|' -f4|tr ':' ' '); do
				mkdir -p ${RUNNING_CHECKS[0]}/sort-by-filter/$(echo ${fp}|tr '/' '_')
				echo ${file} >> ${RUNNING_CHECKS[0]}/sort-by-filter/$(echo ${fp}|tr '/' '_')/full.txt
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
export -f main array_names output_format
${FILERESULTS} && mkdir -p ${RUNNING_CHECKS[@]}
depth_set_v2 ${1}
${FILERESULTS} && rm -rf ${WORKDIR}
