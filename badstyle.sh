#!/bin/bash

# Filename: badstyle.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 14/01/2018

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
#	checks for multiple package dependencies in one line

#override REPOTREE,FILERESULTS,RESULTSDIR settings
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/badstyle/"
#export REPOTREE=/usr/portage/

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
#${ENABLE_GIT} || exit 0				# only works with git tree

SCRIPT_TYPE="checks"
WORKDIR="/tmp/badstyle-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/ebuild_multiple_deps_per_line"					#Index 0
	)
}
output_format(){
	index=(
		"${ebuild_eapi}${DL}${category}/${package}${DL}${filename}${DL}${maintainer}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_index0 <<- EOM
Ebuilds which have multiple dependencies written in one line like:
	|| ( app-arch/foo app-arch/bar )
Should look like:
	|| (
		app-arch/foo
		app-arch/bar
	)
Also see at: <a href="https://devmanual.gentoo.org/general-concepts/dependencies/">Link</a>

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
	repo_categories
	local absolute_path=${1}
	local category="$(echo ${absolute_path}|cut -d'/' -f1)"
	local package="$(echo ${absolute_path}|cut -d'/' -f2)"
	local filename="$(echo ${absolute_path}|cut -d'/' -f3)"
	local packagename="${filename%.*}"
	local maintainer="$(get_main_min "${category}/${package}")"
	local ebuild_eapi="$(get_eapi ${absolute_path})"

	local used_cats=( )
	for cat in ${all_cat[@]}; do
		if $(grep DEPEND /${REPOTREE}/metadata/md5-cache/${category}/${packagename} | grep -q ${cat}); then
			used_cats+=( "${cat}" )
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

	if [ -n "${used_cats}" ]; then
		#remove duplicates from found categories
		cat_to_check=($(printf "%s\n" "${used_cats[@]}" | sort -u))

		x=0
		y="${#cat_to_check[@]}"
		z=( )

		for a in ${cat_to_check[@]}; do
			for b in ${cat_to_check[@]:${x}:${y}}; do
				if [ "${a}" = "${b}" ]; then
					z+=( "${a}/.*${b}/.*" )
				else
					z+=( "${a}/.*${b}/.*|${b}/.*${a}/.*" )
				fi
			done
			# search the pattern
			x=$(expr ${x} + 1)
		done


		if $(grep "^[^#;]" ${absolute_path} | egrep -q "$(echo ${z[@]}|tr ' ' '|')" ); then
			output 0
		fi
	fi
}

# create a list of categories in ${REPOTREE}
repo_categories(){
	all_cat=( $(find ${REPOTREE} -mindepth 1 -maxdepth 1 -type d -regextype sed -regex "./*[a-z0-9].*-[a-z0-9].*" -printf '%P\n') )
	[ -e ${REPOTREE}/virtual ] && all_cat+=( "virtual" )
}

find_func(){
	find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
		-type f -name "*.ebuild" -exec egrep -l "DEPEND" {} \; | parallel main {}
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
# switch to the REPOTREE dir
cd ${REPOTREE}
# export important variables and functions
export WORKDIR
export -f main array_names repo_categories output_format
# create all folders
${FILERESULTS} && mkdir -p ${RUNNING_CHECKS[@]}
# set the search depth
depth_set_v2 ${1}
# cleanup
${FILERESULTS} && rm -rf ${WORKDIR}
