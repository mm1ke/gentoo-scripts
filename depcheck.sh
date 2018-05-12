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

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export PORTTREE=/usr/portage/
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/depcheck/"

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

# don't run on overlays because dependencies are most likely only
# available at the main tree
${TREE_IS_MASTER} || exit 0

#
### IMPORTANT SETTINGS START ###
#
SCRIPT_NAME="depcheck"
SCRIPT_SHORT="DEC"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-IMP-ebuild_nonexist_dependency"									#Index 0
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

# only works with md5-cache
if ! ${ENABLE_MD5}; then
	exit 1
fi

main() {

	array_names
	local absolute_path=${1}
	local category="$(echo ${absolute_path}|cut -d'/' -f2)"
	local package="$(echo ${absolute_path}|cut -d'/' -f3)"
	local filename="$(echo ${absolute_path}|cut -d'/' -f4)"
	local packagename="${filename%.*}"
	local full_path="${PORTTREE}/${category}/${package}"
	local full_path_ebuild="${PORTTREE}/${category}/${package}/${filename}"
	local maintainer="$(get_main_min "${category}/${package}")"

	if ${DEBUG}; then
		# Debug
		echo "absolute path: ${absolute_path}"
		echo "full path: ${full_path}"
		echo "full path ebuild: ${full_path_ebuild}"
		echo "category: ${category}"
		echo "package: ${package}"
		echo "filename: ${filename}"
		echo "packagename: ${packagename}"
		echo "fileage: $(get_age "${filename}")"
		echo "maintainer: ${maintainer}"
		echo
	fi

	local found=false
	local obsolete_dep=()
	local dependencies=( $(grep DEPEND /${PORTTREE}/metadata/md5-cache/${category}/${packagename}|grep -oE "[a-zA-Z0-9-]{2,30}/[+a-zA-Z_0-9-]{2,80}"|sed 's/-[0-9].*//g'|sort -u) )
	for dep in ${dependencies[@]}; do
		if $(grep ${dep} ${full_path_ebuild} >/dev/null 2>&1); then
			if ! [ -e "${PORTTREE}/${dep}" ]; then
				obsolete_dep+=( "${dep}" )
				found=true
			fi
		fi
	done

	if ${found}; then
		if ${SCRIPT_MODE}; then
			echo "${category}/${package}/${filename}${DL}$(echo ${obsolete_dep[@]}|tr ' ' ':')${DL}${maintainer}" >> ${RUNNING_CHECKS[0]}/full.txt
		else
			echo "${category}/${package}/${filename}${DL}$(echo ${obsolete_dep[@]}|tr ' ' ':')${DL}${maintainer}"
		fi
	fi
}

# set the search depth
depth_set ${1}
# switch to the PORTTREE dir
cd ${PORTTREE}
# export important variables
export WORKDIR SCRIPT_SHORT
export -f main array_names

${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}

find ./${level} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec egrep -l 'DEPEND' {} \; | parallel main {}

if ${SCRIPT_MODE}; then
	gen_sort_main_v2 ${RUNNING_CHECKS[0]} 3
	gen_sort_pak_v2 ${RUNNING_CHECKS[0]} 1

	copy_checks checks
	rm -rf ${WORKDIR}
fi
