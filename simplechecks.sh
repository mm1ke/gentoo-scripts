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
# 	ebuilds: check for trailing whitespaces
# 	metadata: mixed indentation (mixed tabs & whitespaces)


SCRIPT_MODE=false
SCRIPT_NAME="simplechecks"
SCRIPT_SHORT="SIC"
SITEDIR="${HOME}/${SCRIPT_NAME}/"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"
PORTTREE="/usr/portage/"
DL='|'

startdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${startdir}/funcs.sh ]; then
	source ${startdir}/funcs.sh
else
	echo "Missing funcs.sh"
	exit 1
fi

if [ "$(hostname)" = s6 ]; then
	SCRIPT_MODE=true
	SITEDIR="/var/www/gentooqa.levelnine.at/results/"
fi

cd ${PORTTREE}
depth_set ${1}

main() {
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package="$(echo ${full_package}|cut -d'/' -f3)"
	local filename="$(echo ${full_package}|cut -d'/' -f4)"

	local maintainer="$(get_main_min "${category}/${package}")"

	if ${SCRIPT_MODE}; then
		mkdir -p /${WORKDIR}/${NAME}/
		echo "${VARI}${category}/${package}/${filename}${DL}${maintainer}" >> /${WORKDIR}/${NAME}/full.txt
	else
		echo "${VARI}${NAME}${DL}${category}/${package}/${filename}${DL}${maintainer}"
	fi
}

gen_sortings() {
	foldername="${NAME}"
	newpath="${WORKDIR}/${NAME}"

	gen_sort_main ${newpath}/full.txt 2 ${newpath} ${DL}
	gen_sort_pak ${newpath}/full.txt 1 ${newpath} ${DL}

	rm -rf ${SITEDIR}/checks/${foldername}
	cp -r ${newpath} ${SITEDIR}/checks/
	rm -rf ${WORKDIR}
}

gen_sortings_v2() {
	local package_location=${1}
	local maintainer_location=${2}
	foldername="${NAME}"
	newpath="${WORKDIR}/${NAME}"

	gen_sort_main ${newpath}/full.txt ${maintainer_location} ${newpath} ${DL}
	gen_sort_pak ${newpath}/full.txt ${package_location} ${newpath} ${DL}

	rm -rf ${SITEDIR}/checks/${foldername}
	cp -r ${newpath} ${SITEDIR}/checks/
	rm -rf ${WORKDIR}
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

export -f main get_main_min
export -f pre_check_eapi6 pre_check_mixed_indentation pre_check_description_over_80 pre_proxy_maint_check pre_check_homepage_var
export PORTTREE WORKDIR SCRIPT_MODE DL SCRIPT_SHORT

# find trailing whitespaces
export NAME="${SCRIPT_SHORT}-IMP-trailing_whitespaces"
find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec egrep -l " +$" {} \; | parallel main {}
${SCRIPT_MODE} && gen_sortings

export NAME="${SCRIPT_SHORT}-IMP-mixed_indentation"
find ./${level} -maxdepth 1 \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.xml" -exec grep -l "^ " {} \; | parallel pre_check_mixed_indentation {}
${SCRIPT_MODE} && gen_sortings

export NAME="${SCRIPT_SHORT}-BUG-gentoo_mirror_missuse"
find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l 'mirror://gentoo' {} \; | parallel main {}
${SCRIPT_MODE} && gen_sortings

export NAME="${SCRIPT_SHORT}-BUG-epatch_in_eapi6"
find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l "\<epatch\>" {} \; | parallel pre_check_eapi6 {}
${SCRIPT_MODE} && gen_sortings

export NAME="${SCRIPT_SHORT}-BUG-dohtml_in_eapi6"
find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l "\<dohtml\>" {} \; | parallel pre_check_eapi6 {}
${SCRIPT_MODE} && gen_sortings

export NAME="${SCRIPT_SHORT}-BUG-description_over_80"
find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -print | parallel pre_check_description_over_80 {}
${SCRIPT_MODE} && gen_sortings

export NAME="${SCRIPT_SHORT}-BUG-proxy_maint_check"
find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.xml" -exec grep -l "proxy-maint@gentoo.org" {} \; | parallel pre_proxy_maint_check {}
${SCRIPT_MODE} && gen_sortings

export NAME="${SCRIPT_SHORT}-BUG-fdo_mime_check"
find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l "inherit.* fdo-mime" {} \; | parallel main {}
${SCRIPT_MODE} && gen_sortings

_varibales="DESCRIPTION LICENSE KEYWORDS IUSE RDEPEND DEPEND SRC_URI"
for var in ${_varibales}; do
	export NAME="${SCRIPT_SHORT}-IMP-leading_trailing_whitespace_${var}"
	find ./${level}  \( \
		-path ./scripts/\* -o \
		-path ./profiles/\* -o \
		-path ./packages/\* -o \
		-path ./licenses/\* -o \
		-path ./distfiles/\* -o \
		-path ./metadata/\* -o \
		-path ./eclass/\* -o \
		-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec egrep -l "^${var}=\" |^${var}=\".* \"$" {} \; | parallel main {}
	${SCRIPT_MODE} && gen_sortings
done

export NAME="${SCRIPT_SHORT}-BUG-homepage_with_vars"
find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l "HOMEPAGE=.*\${" {} \; | parallel pre_check_homepage_var {}
${SCRIPT_MODE} && gen_sortings

_varibales="DESCRIPTION LICENSE KEYWORDS IUSE RDEPEND DEPEND SRC_URI"
for var in ${_varibales}; do
	export VARI="${var}${DL}"
	export NAME="${SCRIPT_SHORT}-IMP-leading_trailing_whitespace"
	find ./${level}  \( \
		-path ./scripts/\* -o \
		-path ./profiles/\* -o \
		-path ./packages/\* -o \
		-path ./licenses/\* -o \
		-path ./distfiles/\* -o \
		-path ./metadata/\* -o \
		-path ./eclass/\* -o \
		-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec egrep -l "^${var}=\" |^${var}=\".* \"$" {} \; | parallel main {}
done
${SCRIPT_MODE} && gen_sortings_v2 2 3
