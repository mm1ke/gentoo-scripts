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

SCRIPT_MODE=false
SCRIPT_NAME="simplechecks"
SCRIPT_SHORT="SIC"
SITEDIR="${HOME}/${SCRIPT_NAME}/"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"
PORTTREE="/usr/portage/"
DL='|'

RUNNING_CHECKS=(
"${WORKDIR}/${SCRIPT_SHORT}-IMP-trailing_whitespaces"						# Index 0
"${WORKDIR}/${SCRIPT_SHORT}-IMP-mixed_indentation"							# Index 1
"${WORKDIR}/${SCRIPT_SHORT}-BUG-gentoo_mirror_missuse"					# Index 2
"${WORKDIR}/${SCRIPT_SHORT}-BUG-epatch_in_eapi6"								# Index 3
"${WORKDIR}/${SCRIPT_SHORT}-BUG-dohtml_in_eapi6"								# Index 4
"${WORKDIR}/${SCRIPT_SHORT}-BUG-description_over_80"						# Index 5
"${WORKDIR}/${SCRIPT_SHORT}-BUG-proxy_maint_check"							# Index 6
"${WORKDIR}/${SCRIPT_SHORT}-BUG-fdo_mime_check"									# Index 7
"${WORKDIR}/${SCRIPT_SHORT}-BUG-homepage_with_vars"							# Index 8
"${WORKDIR}/${SCRIPT_SHORT}-IMP-leading_trailing_whitespace"		# Index 9
)

startdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${startdir}/funcs.sh ]; then
	source ${startdir}/funcs.sh
else
	echo "Missing funcs.sh"
	exit 1
fi

if [ "$(hostname)" = vs4 ]; then
	SCRIPT_MODE=true
	SITEDIR="/var/www/gentooqa.levelnine.at/results/"
fi

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

gen_sortings() {
	local check_name=${1}
	[ -z "${2}" ] &&
		local package_location="1" ||
		local package_location="${2}"
	[ -z "${3}" ] &&
		local maintainer_location="2" ||
		local maintainer_location="${3}"

	gen_sort_main_v2 ${check_name} ${maintainer_location}
	gen_sort_pak_v2 ${check_name} ${package_location}

	rm -rf ${SITEDIR}/checks/${check_name##*/}
	cp -r ${check_name} ${SITEDIR}/checks/
	rm -rf ${check_name}
}

pre_check_mixed_indentation() {
	if grep $'\t' ${1} >/dev/null; then
		main ${1}
	fi
}

pre_check_eapi6() {
	if [ "$(grep EAPI ${1}|tr -d '"'|cut -d'=' -f2)" = "6" ]; then
		main ${1}
	fi
}

pre_check_homepage_var() {
	if ! grep 'HOMEPAGE=.*${HOMEPAGE}' ${1} >/dev/null; then
		main ${1}
	fi
}

pre_check_description_over_80() {
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local filename="$(echo ${full_package}|cut -d'/' -f4)"

	if [ $(grep DESCRIPTION ${PORTTREE}/metadata/md5-cache/${category}/${filename%.*} | wc -m) -gt 95 ]; then
		main ${1}
	fi
}

pre_proxy_maint_check() {
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
export -f main get_main_min
export -f pre_check_eapi6 pre_check_mixed_indentation pre_check_description_over_80 pre_proxy_maint_check pre_check_homepage_var
export PORTTREE WORKDIR SCRIPT_MODE DL SCRIPT_SHORT

# trailing_whitespaces
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
${SCRIPT_MODE} && gen_sortings ${NAME}

# mixed_indentation
export NAME="${RUNNING_CHECKS[1]}"
find ./${level} -maxdepth 1 \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.xml" -exec grep -l "^ " {} \; | parallel pre_check_mixed_indentation {}
${SCRIPT_MODE} && gen_sortings ${NAME}

# gentoo_mirror_missuse
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
${SCRIPT_MODE} && gen_sortings ${NAME}

# epatch_in_eapi6
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
${SCRIPT_MODE} && gen_sortings ${NAME}

# dohtml_in_eapi6
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
${SCRIPT_MODE} && gen_sortings ${NAME}

# description_over_80
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
		-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -print | parallel pre_check_description_over_80 {}
	${SCRIPT_MODE} && gen_sortings ${NAME}
fi

# proxy_maint_check
export NAME="${RUNNING_CHECKS[6]}"
find ./${level} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.xml" -exec grep -l "proxy-maint@gentoo.org" {} \; | parallel pre_proxy_maint_check {}
${SCRIPT_MODE} && gen_sortings ${NAME}

# fdo_mime_check
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
${SCRIPT_MODE} && gen_sortings ${NAME}

# homepage_with_vars
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
${SCRIPT_MODE} && gen_sortings ${NAME}

# leading_trailing_whitespace
_varibales="DESCRIPTION LICENSE KEYWORDS IUSE RDEPEND DEPEND SRC_URI"
for var in ${_varibales}; do
	export VARI="${var}${DL}"
	export NAME="${RUNNING_CHECKS[9]}"
	find ./${level} \( \
		-path ./scripts/\* -o \
		-path ./profiles/\* -o \
		-path ./packages/\* -o \
		-path ./licenses/\* -o \
		-path ./distfiles/\* -o \
		-path ./metadata/\* -o \
		-path ./eclass/\* -o \
		-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec egrep -l "^${var}=\" |^${var}=\".* \"$" {} \; | parallel main {}

	if ${SCRIPT_MODE}; then
		mkdir -p ${NAME}/sort-by-filter/${var}/
		grep "^${VARI}" ${NAME}/full.txt > ${NAME}/sort-by-filter/${var}/full.txt
		gen_sort_main_v2 ${NAME}/sort-by-filter/${var}/ 3
		gen_sort_pak_v2 ${NAME}/sort-by-filter/${var}/ 2
	fi
done
${SCRIPT_MODE} && gen_sortings ${NAME} 2 3
${SCRIPT_MODE} && rm -rf ${WORKDIR}
