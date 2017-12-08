#!/bin/bash

# Filename: eapistats.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 07/09/2017

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
# simple script for generating EAPI statistics


SCRIPT_MODE=false
WWWDIR="${HOME}/eapistats/"
WORKDIR="/tmp/eapistats-${RANDOM}"
PORTTREE="/usr/portage/"
DL='|'

if [ "$(hostname)" = s6 ]; then
	SCRIPT_MODE=true
	WWWDIR="/var/www/gentoo.levelnine.at/eapistats/"
fi

startdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${startdir}/funcs.sh ]; then
	source ${startdir}/funcs.sh
else
	echo "Missing funcs.sh"
	exit 1
fi

cd ${PORTTREE}

${SCRIPT_MODE} && mkdir -p ${WORKDIR}

if [ -z "${1}" ]; then
	usage
	exit 1
else
	if [ -d "${PORTTREE}/${1}" ]; then
		level="${1}"
		MAXD=0
		MIND=0
		if [ -z "${1##*/}" ] || [ "${1%%/*}" == "${1##*/}" ]; then
			MAXD=1
			MIND=1
		fi
	elif [ "${1}" == "full" ]; then
		level=""
		MAXD=2
		MIND=2
	else
		echo "${PORTTREE}/${1}: Path not found"
	fi
fi

main() {
	local full_package=${1}
	local eapi=${2}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package="$(echo ${full_package}|cut -d'/' -f3)"
	local filename="$(echo ${full_package}|cut -d'/' -f4)"

	local maintainer="$(get_main_min "${category}/${package}")"
	if [ -z "${maintainer}" ]; then
			maintainer="maintainer-needed@gentoo.org:"
	fi
	
	if ${SCRIPT_MODE}; then
		echo "${eapi}${DL}${category}/${package}/${filename}${DL}${maintainer}" >> /${WORKDIR}/full.txt
	else
		echo "${eapi}${DL}${category}/${package}/${filename}${DL}${maintainer}"
	fi
}

gen_sortings() {
	for i in $(cut -c-1 ${WORKDIR}/full.txt|sort -u); do
		mkdir -p ${WORKDIR}/${i}
		grep ^${i}${DL} ${WORKDIR}/full.txt > ${WORKDIR}/${i}/EAPI${i}.txt

		# sort by packages
		f_packages="$(cat ${WORKDIR}/${i}/EAPI${i}.txt| cut -d "${DL}" -f2|sort|uniq)"
		for u in ${f_packages}; do
			f_cat="$(echo $u|cut -d'/' -f1)"
			f_pak="$(echo $u|cut -d'/' -f2)"
			mkdir -p ${WORKDIR}/${i}/sort-by-package/${f_cat}
			grep "${u}" ${WORKDIR}/${i}/EAPI${i}.txt > ${WORKDIR}/${i}/sort-by-package/${f_cat}/${f_pak}.txt
		done
	
		mkdir -p ${WORKDIR}/${i}/sort-by-maintainer/
		for a in $(cat ${WORKDIR}/${i}/EAPI${i}.txt |cut -d "${DL}" -f3|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
			grep "${a}" ${WORKDIR}/${i}/EAPI${i}.txt > ${WORKDIR}/${i}/sort-by-maintainer/"$(echo ${a}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
		done
	done
}

eapi_pre_check() {
	local var=${1}
	if grep ^EAPI ${var} >/dev/null; then
		main ${var} $(grep ^EAPI ${var}|tr -d '"'|cut -d'=' -f2)
	else
		main ${var} 0
	fi
}

export -f eapi_pre_check main get_main_min
export SCRIPT_MODE WORKDIR PORTTREE DL

find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -print | parallel eapi_pre_check {}

if ${SCRIPT_MODE}; then
	gen_sortings
	script_mode_copy
fi

