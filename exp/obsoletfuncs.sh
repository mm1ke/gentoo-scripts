#!/bin/bash

# Filename: obsoletfuncs.sh
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
#export SITEDIR="${HOME}/obsoletfuncs/"

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
SCRIPT_NAME="obsoletfuncs"
SCRIPT_SHORT="OSF"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_eapi6_funcs"									#Index 0
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

main() {
	array_names
	local relative_path=${1}
	local category="$(echo ${relative_path}|cut -d'/' -f2)"
	local package="$(echo ${relative_path}|cut -d'/' -f3)"
	local filename="$(echo ${relative_path}|cut -d'/' -f4)"
	local packagename="${filename%.*}"
	local full_path="${PORTTREE}/${category}/${package}"
	local full_path_ebuild="${PORTTREE}/${category}/${package}/${filename}"
	local maintainer="$(get_main_min "${category}/${package}")"

	if ${DEBUG}; then
		echo "relative path: ${relative_path}"				# path relative to ${PORTTREE}:	./app-admin/salt/salt-0.5.2.ebuild
		echo "full path: ${full_path}"								# full path:										/usr/portage/app-admin/salt
		echo "full path ebuild: ${full_path_ebuild}"	# full path ebuild:							/usr/portage/app-admin/salt/salt-0.5.2.ebuild
		echo "category: ${category}"									# package category:							app-admin
		echo "package: ${package}"										# package name:									salt
		echo "filename: ${filename}"									# package filename:							salt-0.5.2.ebuild
		echo "packagename: ${packagename}"						# package name-version:					salt-0.5.2
		echo "fileage: $(get_age "${filename}")"			# age of ebuild in days:				145
		echo "maintainer: ${maintainer}"							# maintainer of package					foo@gentoo.org:bar@gmail.com
		echo
	fi

	if [ "$(get_eapi ${full_path_ebuild})" = "6" ]; then
		if [ "$(sed -n '/src_install/,/^}/p' ${full_path_ebuild} | wc -l)" = 4 ]; then
			if $(sed -n '/src_install/,/^}/p' ${full_path_ebuild} |  pcregrep -qM "emake.*DESTDIR.*\n.*default" ${full_path_ebuild}); then
				if ${SCRIPT_MODE}; then
					echo "${category}/${package}${DL}${filename}${DL}${maintainer}" >> ${RUNNING_CHECKS[0]}/full.txt
				else
					echo "${category}/${package}${DL}${filename}${DL}${maintainer}"
				fi
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
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec egrep -l "\<src_install\>" {} \; | parallel main {}

if ${SCRIPT_MODE}; then
	gen_sort_main_v2 ${RUNNING_CHECKS[0]} 5
	gen_sort_pak_v2 ${RUNNING_CHECKS[0]} 3

	copy_checks checks
	rm -rf ${WORKDIR}
fi
