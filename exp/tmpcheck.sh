#!/bin/bash

# Filename: tmpcheck.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 12/01/2018

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
#	prototype script for new scripts

#override REPOTREE,FILERESULTS,RESULTSDIR settings
#export REPOTREE=/usr/portage/
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/tmpcheck/"

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
${ENABLE_GIT} || exit 0					# only works with git tree

SCRIPT_TYPE="checks"
WORKDIR="/tmp/tmpcheck-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/tmpcheck"									#Index 0
	)
}
output_format(){
	index=(
		"${category}/${package}${DL}${filename}${DL}${maintainer}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_index0 <<- EOM
Explanation of the check

||F  +----> ebuild EAPI     +----> full ebuild filename
D|O  |                      |
A|R  7 | dev-libs/foo | foo-1.12-r2.ebuild | developer@gentoo.org
T|M       |                                                  |
A|A       |                        ebuild maintainer(s) <----+
||T       +----> package category/name
EOM
	description=( "${info_index0}" )
	echo "${description[$1]}"
}
#
### IMPORTANT SETTINGS END ###
#

main() {
	array_names
	local relative_path=${1}																								# path relative to ${REPOTREE}:	./app-admin/salt/salt-0.5.2.ebuild
	local category="$(echo ${relative_path}|cut -d'/' -f1)"									# package category:							app-admin
	local package="$(echo ${relative_path}|cut -d'/' -f2)"									# package name:									salt
	local filename="$(echo ${relative_path}|cut -d'/' -f3)"									# package filename:							salt-0.5.2.ebuild
	local packagename="${filename%.*}"																			# package name-version:					salt-0.5.2
	local full_path="${REPOTREE}/${category}/${package}"										# full path:										/usr/portage/app-admin/salt
	local full_path_ebuild="${REPOTREE}/${category}/${package}/${filename}"	# full path ebuild:							/usr/portage/app-admin/salt/salt-0.5.2.ebuild
	local maintainer="$(get_main_min "${category}/${package}")"							# maintainer of package					foo@gentoo.org:bar@gmail.com
	local fileage="$(get_age "${category}/${package}/${filename}")"					# age of ebuild in days:				145

	output() {
		local id=${1}
		if ${FILERESULTS}; then
			output_format ${id} >> ${RUNNING_CHECKS[${id}]}/full.txt
		else
			output_format ${id}
		fi
	}

	if yes; then
		output 0
	fi
}


find_func(){
	find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
		-type f -name "*.ebuild" -exec egrep -l "DEPEND" {} \; | parallel main {}
}

gen_results() {
	if ${FILERESULTS}; then
		sort_result_v2
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
# set the search depth
depth_set_v2 ${1}
${FILERESULTS} && rm -rf ${WORKDIR}
