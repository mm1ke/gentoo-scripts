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
#PORTTREE=/usr/portage/
#SCRIPT_MODE=true
#SITEDIR="${HOME}/simplechecks/"

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
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_obsolete_fdo_mime_usage"										# Index 7
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_variables_in_homepages"										# Index 8
	"${WORKDIR}/${SCRIPT_SHORT}-IMP-ebuild_insecure_git_uri_usage"										# Index 9
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_obsolete_git_2_usage"											# Index 10
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_obsolete_games_usage"											# Index 11
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_obsolete_ltprune_usage"										# Index 12
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

main() {
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package="$(echo ${full_package}|cut -d'/' -f3)"
	local filename="$(echo ${full_package}|cut -d'/' -f4)"

	local maintainer="$(get_main_min "${category}/${package}")"

	if ${SCRIPT_MODE}; then
		echo "${VARI}${category}/${package}/${filename}${DL}${maintainer}" >> ${NAME}/full.txt
	else
		echo "${VARI}${NAME##*/}${DL}${category}/${package}/${filename}${DL}${maintainer}"
	fi
}

pre_check_metadata_mixed_indentation() {
	if grep $'\t' ${1} >/dev/null; then
		main ${1}
	fi
}

pre_check_eapi6() {
	if [ "$(get_eapi ${1})" = "6" ]; then
		main ${1}
	fi
}

pre_check_homepage_var() {
	if ! grep 'HOMEPAGE=.*${HOMEPAGE}' ${1} >/dev/null; then
		main ${1}
	fi
}

pre_check_ebuild_description_over_80() {
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local filename="$(echo ${full_package}|cut -d'/' -f4)"

	if [ $(grep DESCRIPTION ${PORTTREE}/metadata/md5-cache/${category}/${filename%.*} | wc -m) -gt 95 ]; then
		main ${1}
	fi
}

pre_metadata_missing_proxy_maintainer() {
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package="$(echo ${full_package}|cut -d'/' -f3)"

	local maintainer="$(get_main_min "${category}/${package}")"
	local ok=false

	for i in $(echo ${maintainer}|tr ':' '\n'); do
		if ! $(echo $i | grep "@gentoo.org" >/dev/null ); then
			ok=true
		fi
	done

	${ok} || main ${1}
}

depth_set ${1}
cd ${PORTTREE}
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}
export -f main get_main_min array_names
export -f pre_check_eapi6 pre_check_metadata_mixed_indentation pre_check_ebuild_description_over_80 pre_metadata_missing_proxy_maintainer pre_check_homepage_var
export WORKDIR SCRIPT_SHORT

# ebuild_trailing_whitespaces
export NAME="${RUNNING_CHECKS[0]}"
find ./${level} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec egrep -l " +$" {} \; | parallel main {}

# metadata_mixed_indentation
export NAME="${RUNNING_CHECKS[1]}"
find ./${level} -maxdepth 1 \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.xml" -exec grep -l "^ " {} \; | parallel pre_check_metadata_mixed_indentation {}

# ebuild_obsolete_gentoo_mirror_usage
export NAME="${RUNNING_CHECKS[2]}"
find ./${level} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l 'mirror://gentoo' {} \; | parallel main {}

# ebuild_epatch_in_eapi6
export NAME="${RUNNING_CHECKS[3]}"
find ./${level} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l "\<epatch\>" {} \; | parallel pre_check_eapi6 {}

# ebuild_dohtml_in_eapi6
export NAME="${RUNNING_CHECKS[4]}"
find ./${level} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l "\<dohtml\>" {} \; | parallel pre_check_eapi6 {}

# ebuild_description_over_80
# only works with md5-cache
if ${ENABLE_MD5}; then
	export NAME="${RUNNING_CHECKS[5]}"
	find ./${level} \( \
		-path ./scripts/\* -o \
		-path ./profiles/\* -o \
		-path ./packages/\* -o \
		-path ./licenses/\* -o \
		-path ./distfiles/\* -o \
		-path ./metadata/\* -o \
		-path ./eclass/\* -o \
		-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -print | parallel pre_check_ebuild_description_over_80 {}
fi

# metadata_missing_proxy_maintainer
export NAME="${RUNNING_CHECKS[6]}"
find ./${level} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.xml" -exec grep -l "proxy-maint@gentoo.org" {} \; | parallel pre_metadata_missing_proxy_maintainer {}

# ebuild_obsolete_fdo_mime_usage
export NAME="${RUNNING_CHECKS[7]}"
find ./${level} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l "inherit.* fdo-mime" {} \; | parallel main {}

# ebuild_variables_in_homepages
export NAME="${RUNNING_CHECKS[8]}"
find ./${level} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l "HOMEPAGE=.*\${" {} \; | parallel pre_check_homepage_var {}

# egit_repo_uri
export NAME="${RUNNING_CHECKS[9]}"
find ./${level} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l "EGIT_REPO_URI=\"git://" {} \; | parallel main {}

# ebuild_obsolete_git_2_usage
export NAME="${RUNNING_CHECKS[10]}"
find ./${level} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l "inherit.* git-2" {} \; | parallel main {}

# ebuild_obsolete_games_usage
export NAME="${RUNNING_CHECKS[11]}"
find ./${level} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l "inherit.* games" {} \; | parallel main {}

# ebuild_obsolete_ltprune_usage
export NAME="${RUNNING_CHECKS[12]}"
find ./${level} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l "inherit.* ltprune" {} \; | parallel main {}

if ${SCRIPT_MODE}; then
	gen_sort_main_v2 ${RUNNING_CHECKS[0]} 2
	gen_sort_pak_v2 ${RUNNING_CHECKS[0]} 1

	gen_sort_main_v2 ${RUNNING_CHECKS[1]} 2
	gen_sort_pak_v2 ${RUNNING_CHECKS[1]} 1

	gen_sort_main_v2 ${RUNNING_CHECKS[2]} 2
	gen_sort_pak_v2 ${RUNNING_CHECKS[2]} 1

	gen_sort_main_v2 ${RUNNING_CHECKS[3]} 2
	gen_sort_pak_v2 ${RUNNING_CHECKS[3]} 1

	gen_sort_main_v2 ${RUNNING_CHECKS[4]} 2
	gen_sort_pak_v2 ${RUNNING_CHECKS[4]} 1

	gen_sort_main_v2 ${RUNNING_CHECKS[5]} 2
	gen_sort_pak_v2 ${RUNNING_CHECKS[5]} 1

	gen_sort_main_v2 ${RUNNING_CHECKS[6]} 2
	gen_sort_pak_v2 ${RUNNING_CHECKS[6]} 1

	gen_sort_main_v2 ${RUNNING_CHECKS[7]} 2
	gen_sort_pak_v2 ${RUNNING_CHECKS[7]} 1

	gen_sort_main_v2 ${RUNNING_CHECKS[8]} 2
	gen_sort_pak_v2 ${RUNNING_CHECKS[8]} 1

	gen_sort_main_v2 ${RUNNING_CHECKS[9]} 2
	gen_sort_pak_v2 ${RUNNING_CHECKS[9]} 1

	gen_sort_main_v2 ${RUNNING_CHECKS[10]} 2
	gen_sort_pak_v2 ${RUNNING_CHECKS[10]} 1

	gen_sort_main_v2 ${RUNNING_CHECKS[11]} 2
	gen_sort_pak_v2 ${RUNNING_CHECKS[11]} 1

	gen_sort_main_v2 ${RUNNING_CHECKS[12]} 2
	gen_sort_pak_v2 ${RUNNING_CHECKS[12]} 1

	copy_checks checks
	rm -rf ${WORKDIR}
fi
