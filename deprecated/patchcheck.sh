#!/bin/bash

# Filename: patchtest
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 07/08/2017

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
# simple scirpt to find unused scripts directories in the gentoo tree

#override REPOTREE,FILERESULTS,RESULTSDIR settings
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/patchcheck/"
#export REPOTREE=/usr/portage/

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
WORKDIR="/tmp/patchcheck-${RANDOM}/"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/ebuild_unused_patches_simple"									#Index 0
	)
}
output_format(){
	index=(
		"${category}/${package_name}${DL}${main}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_index0 <<- EOM
Very limited check to find unused patches, mostly without false positives

Data Format ( dev-libs/foo|dev@gentoo.org:loper@foo.de ):
dev-libs/foo                                package category/name
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
	description=( "${info_index0}" )
	echo "${description[$1]}"
}
#
### IMPORTANT SETTINGS END ###
#

_gen_whitelist(){
	if [ -e ${WFILE} ]; then
		source ${WFILE}
		for i in ${white_list[@]}; do
			whitelist+=("$(echo ${i}|cut -d';' -f1)")
		done
	else
		whitelist=()
	fi
	# remove duplicates
	mapfile -t whitelist < <(printf '%s\n' "${whitelist[@]}"|sort -u)
	echo ${whitelist[@]}
}

main(){
	array_names
	local eclasses="apache-module|elisp|vdr-plugin-2|ruby-ng|readme.gentoo|readme.gentoo-r1|java-vm-2|php-ext-source-r3|selinux-policy-2|toolchain-glibc"
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f1)"
	local package_name="$(echo ${full_package}|cut -d'/' -f2)"
	local fullpath="/${REPOTREE}/${full_package}"

	output() {
		local id=${1}
		if ${FILERESULTS}; then
			output_format ${id} >> ${RUNNING_CHECKS[${id}]}/full.txt
		else
			output_format ${id}
		fi
	}

	# check if the patches folder exist
	if [ -e ${fullpath}/files ]; then
		if ! echo ${whitelist[@]}|grep "${category}/${package_name}" > /dev/null; then
			if ! grep -E ".diff|.patch|FILESDIR|${eclasses}" ${fullpath}/*.ebuild >/dev/null; then
				main=$(get_main_min "${category}/${package_name}")
				output 0
			fi
		fi
	fi
}

find_func(){
	find ${searchp[@]} -mindepth ${MIND} -maxdepth ${MAXD} \
		-type d -print | parallel main {}
}

gen_results(){
	if ${FILERESULTS}; then
		gen_descriptions
		sort_result_v2
		gen_sort_main_v3
		gen_sort_pak_v3

		copy_checks ${SCRIPT_TYPE}
	fi
}

array_names
cd ${REPOTREE}
export WORKDIR
export whitelist=$(_gen_whitelist)
export -f main array_names output_format
${FILERESULTS} && mkdir -p ${RUNNING_CHECKS[@]}
depth_set_v2 ${1}
${FILERESULTS} && rm -rf ${WORKDIR}
