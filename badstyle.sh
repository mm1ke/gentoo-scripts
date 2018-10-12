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

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export SCRIPT_MODE=false
#export SITEDIR="${HOME}/badstyle/"
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
SCRIPT_NAME="badstyle"
SCRIPT_SHORT="BAS"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-IMP-ebuild_multiple_deps_per_line"					#Index 0
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

main() {
	array_names
	local absolute_path=${1}
	local category="$(echo ${absolute_path}|cut -d'/' -f1)"
	local package="$(echo ${absolute_path}|cut -d'/' -f2)"
	local filename="$(echo ${absolute_path}|cut -d'/' -f3)"
	local maintainer="$(get_main_min "${category}/${package}")"

	if ${SCRIPT_MODE}; then
		echo "${category}/${package}${DL}${filename}${DL}${maintainer}" >> ${RUNNING_CHECKS[0]}/full.txt
	else
		echo "${category}/${package}${DL}${filename}${DL}${maintainer}"
	fi
}

# set the search depth
depth_set ${1}
# switch to the PORTTREE dir
cd ${PORTTREE}
# export important variables and functions
export WORKDIR SCRIPT_SHORT
export -f main array_names
# create all folders
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}

all_cat=( $(find -mindepth 1 -maxdepth 1 -type d -regextype sed -regex "./*[a-z0-9].*-[a-z0-9].*" -printf '%P\n') )
[ -e ${PORTTREE}/virtual ] && all_cat+=( "virtual" )

if [ ${1} = "full" ] || [ ${1} = "diff" ]; then
	searchp=( $(find ${PORTTREE} -mindepth 1 -maxdepth 1 -type d -regextype sed -regex "./*[a-z0-9].*-[a-z0-9].*") )
	[ -e ${PORTTREE}/virtual ] && searchp+=( "virtual" )
else
	searchp=( ${1} )
fi

x=0
y="${#all_cat[@]}"
z=( )

for a in ${all_cat[@]}; do
	# we don't put _ALL_ possibilities into one single egrep string since this would
	# made the argument too long (get_conf MAX_ARG). We split arguments into
	# multiple find strings splitted by the categories.
	for b in ${all_cat[@]:${x}:${y}}; do
		z+=( "${a}/.*${b}/.*|${b}/.*${a}/.*" )
	done
	# search the pattern
	find ${searchp[@]} -type f -name "*.ebuild" -exec egrep -l "$(echo ${z[@]} | tr ' ' '|')" {} \; | parallel main {}
	x=$(expr ${x} + 1)
	z=( )
done


if ${SCRIPT_MODE}; then
	# remove duplicate entries
	awk -i inplace '!seen[$0]++' ${RUNNING_CHECKS[0]}/full.txt

	gen_sort_main_v2 ${RUNNING_CHECKS[0]} 3
	gen_sort_pak_v2 ${RUNNING_CHECKS[0]} 1

	copy_checks checks
	rm -rf ${WORKDIR}
fi
