#!/bin/bash

# Filename: simplechecks.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 26/08/2017

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
# This script finds simple errors in ebuilds and other files. For now it can
#  ebuilds: check for trailing whitespaces
#  metadata: mixed indentation (mixed tabs & whitespaces)

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export PORTTREE=/usr/portage/
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/simplechecks/"

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
SCRIPT_NAME="simplechecks"
SCRIPT_SHORT="SIC"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-IMP-ebuild_trailing_whitespaces"											# Index 0
	"${WORKDIR}/${SCRIPT_SHORT}-IMP-metadata_mixed_indentation"												# Index 1
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_obsolete_gentoo_mirror_usage"							# Index 2
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_epatch_in_eapi6"														# Index 3
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_dohtml_in_eapi6"														# Index 4
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_description_over_80"												# Index 5
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-metadata_missing_proxy_maintainer"								# Index 6
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_variables_in_homepages"										# Index 7
	"${WORKDIR}/${SCRIPT_SHORT}-IMP-ebuild_insecure_git_uri_usage"										# Index 8
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

main() {
	array_names
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package="$(echo ${full_package}|cut -d'/' -f3)"
	local filename="$(echo ${full_package}|cut -d'/' -f4)"

	local maintainer="$(get_main_min "${category}/${package}")"

	output(){
		local checkid=${1}
		if ${SCRIPT_MODE}; then
			echo "${category}/${package}${DL}${filename}${DL}${maintainer}" >> ${RUNNING_CHECKS[${checkid}]}/full.txt
		else
			echo "${RUNNING_CHECKS[${checkid}]##*/}${DL}${category}/${package}${DL}${filename}${DL}${maintainer}"
		fi
	}

	# trailing whitespace
	if $(egrep -q " +$" ${full_package}); then
		output 0
	fi
	# mirror usage
	if $(grep -q 'mirror://gentoo' ${full_package}); then
		output 2
	fi

	if [ "$(get_eapi ${full_package})" = "6" ]; then
		# epatch usage
		if $(grep -q "\<epatch\>" ${full_package}); then
			output 3
		fi
		# dohtml usage
		if $(grep -q "\<dohtml\>" ${full_package}); then
			output 4
		fi
	fi
	# DESCRIPTION over 80
	if [ $(grep DESCRIPTION ${PORTTREE}/metadata/md5-cache/${category}/${filename%.*} | wc -m) -gt 95 ]; then
		output 5
	fi
	# HOMEPAGE with variables
	if $(grep -q "HOMEPAGE=.*\${" ${full_package}); then
		if ! $(grep -q 'HOMEPAGE=.*${HOMEPAGE}' ${full_package}); then
			output 7
		fi
	fi
	# insecure git usage
	if $(grep -q "EGIT_REPO_URI=\"git://" ${full_package}); then
		output 8
	fi
}

main-xml(){
	array_names
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package="$(echo ${full_package}|cut -d'/' -f3)"
	local filename="metadata.xml"

	if [ -e ${PORTTREE}/${category}/${package}/metadata.xml ]; then
		local maintainer="$(get_main_min "${category}/${package}")"
	fi

	output(){
		local checkid=${1}
		if ${SCRIPT_MODE}; then
			echo "${category}/${package}${DL}${filename}${DL}${maintainer}" >> ${RUNNING_CHECKS[${checkid}]}/full.txt
		else
			echo "${RUNNING_CHECKS[${checkid}]##*/}${DL}${category}/${package}${DL}${filename}${DL}${maintainer}"
		fi
	}

	# mixed indentation
	if $(grep -q "^ " ${full_package}); then
		if $(grep -q $'\t' ${full_package}); then
			output 1
		fi
	fi
	# missing proxy maintainer
	local ok=false
	if $(grep -q "proxy-maint@gentoo.org" ${full_package}); then
		local i
		for i in $(echo ${maintainer}|tr ':' '\n'); do
			if ! $(echo ${i} | grep -q "@gentoo.org"); then
				ok=true
			fi
		done

		if ! ${ok}; then
			output 6
		fi
	fi
}

depth_set ${1}
cd ${PORTTREE}
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}

export -f main main-xml get_main_min array_names
export WORKDIR SCRIPT_SHORT

find ./${level} -mindepth $(expr $MIND + 1) -maxdepth $(expr $MAXD + 1) \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -print | parallel main {}

find ./${level} -mindepth $MIND -maxdepth $(expr $MAXD + 1) \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.xml" -print | parallel main-xml {}


if ${SCRIPT_MODE}; then
	sort_result ${RUNNING_CHECKS[0]}
	gen_sort_main_v2 ${RUNNING_CHECKS[0]} 3
	gen_sort_pak_v2 ${RUNNING_CHECKS[0]} 1

	sort_result ${RUNNING_CHECKS[1]}
	gen_sort_main_v2 ${RUNNING_CHECKS[1]} 3
	gen_sort_pak_v2 ${RUNNING_CHECKS[1]} 1

	sort_result ${RUNNING_CHECKS[2]}
	gen_sort_main_v2 ${RUNNING_CHECKS[2]} 3
	gen_sort_pak_v2 ${RUNNING_CHECKS[2]} 1

	sort_result ${RUNNING_CHECKS[3]}
	gen_sort_main_v2 ${RUNNING_CHECKS[3]} 3
	gen_sort_pak_v2 ${RUNNING_CHECKS[3]} 1

	sort_result ${RUNNING_CHECKS[4]}
	gen_sort_main_v2 ${RUNNING_CHECKS[4]} 3
	gen_sort_pak_v2 ${RUNNING_CHECKS[4]} 1

	sort_result ${RUNNING_CHECKS[5]}
	gen_sort_main_v2 ${RUNNING_CHECKS[5]} 3
	gen_sort_pak_v2 ${RUNNING_CHECKS[5]} 1

	sort_result ${RUNNING_CHECKS[6]}
	gen_sort_main_v2 ${RUNNING_CHECKS[6]} 3
	gen_sort_pak_v2 ${RUNNING_CHECKS[6]} 1

	sort_result ${RUNNING_CHECKS[7]}
	gen_sort_main_v2 ${RUNNING_CHECKS[7]} 3
	gen_sort_pak_v2 ${RUNNING_CHECKS[7]} 1

	sort_result ${RUNNING_CHECKS[8]}
	gen_sort_main_v2 ${RUNNING_CHECKS[8]} 3
	gen_sort_pak_v2 ${RUNNING_CHECKS[8]} 1

	copy_checks checks
	rm -rf ${WORKDIR}
fi
