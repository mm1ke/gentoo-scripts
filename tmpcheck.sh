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

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export PORTTREE=/usr/portage/
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/tmpcheck/"

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
SCRIPT_NAME="tmpcheck"
SCRIPT_SHORT="TMC"
SCRIPT_TYPE="checks"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-IMP-tmpcheck"									#Index 0
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

main() {
	array_names
	local relative_path=${1}																								# path relative to ${PORTTREE}:	./app-admin/salt/salt-0.5.2.ebuild
	local category="$(echo ${relative_path}|cut -d'/' -f2)"									# package category:							app-admin
	local package="$(echo ${relative_path}|cut -d'/' -f3)"									# package name:									salt
	local filename="$(echo ${relative_path}|cut -d'/' -f4)"									# package filename:							salt-0.5.2.ebuild
	local packagename="${filename%.*}"																			# package name-version:					salt-0.5.2
	local full_path="${PORTTREE}/${category}/${package}"										# full path:										/usr/portage/app-admin/salt
	local full_path_ebuild="${PORTTREE}/${category}/${package}/${filename}"	# full path ebuild:							/usr/portage/app-admin/salt/salt-0.5.2.ebuild
	local maintainer="$(get_main_min "${category}/${package}")"							# maintainer of package					foo@gentoo.org:bar@gmail.com
	local fileage="$(get_age "${category}/${package}/${filename}")"					# age of ebuild in days:				145

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
# export important variables
export WORKDIR SCRIPT_SHORT
export -f main array_names

${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}

find ./${level} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec egrep -l 'dev-libs/openssl.*dev-libs/libressl' {} \; | parallel main {}

if ${SCRIPT_MODE}; then
	gen_sort_main_v2 ${RUNNING_CHECKS[0]} 5
	gen_sort_pak_v2 ${RUNNING_CHECKS[0]} 3

	copy_checks ${SCRIPT_TYPE}
	rm -rf ${WORKDIR}
fi
