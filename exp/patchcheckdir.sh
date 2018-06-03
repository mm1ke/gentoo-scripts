#!/bin/bash

# Filename: patchcheckdir
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

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/patchcheckdir/"
#export PORTTREE=/usr/portage/

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
SCRIPT_NAME="patchcheckdir"
SCRIPT_SHORT="PCD"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}/"

array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_unused_patches_folder"									#Index 0
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

_gen_whitelist(){
	if [ -e ${startdir}/whitelist ]; then
		source ${startdir}/whitelist
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
	local absolute_path=${1}
	local category="$(echo ${absolute_path}|cut -d'/' -f2)"
	local package="$(echo ${absolute_path}|cut -d'/' -f3)"
	local filename="$(echo ${absolute_path}|cut -d'/' -f4)"
	local packagename="${filename%.*}"
	local full_path="${PORTTREE}/${category}/${package}"
	local full_path_ebuild="${PORTTREE}/${category}/${package}/${filename}"
	local maintainer="$(get_main_min "${category}/${package}")"

	# check if the patches folder exist
	if [ -e ${full_path}/files ]; then
		if ! $(echo ${whitelist[@]}|grep "${category}/${package}" > /dev/null); then
			for entry in ${full_path}/files/*; do
				if [ -d ${entry} ]; then
					echo ${entry}
				fi
			done
		fi
	fi
}

depth_set ${1}
cd ${PORTTREE}
export -f main get_main_min array_names
export WORKDIR startdir SCRIPT_SHORT
export whitelist=$(_gen_whitelist)
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}

find ./${level} -mindepth ${MIND} -maxdepth ${MAXD} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type d -print | parallel main {}

if ${SCRIPT_MODE}; then
	gen_sort_main_v2 ${RUNNING_CHECKS[0]} 2

	copy_checks checks
	rm -rf ${WORKDIR}
fi
