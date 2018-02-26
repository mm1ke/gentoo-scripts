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
SCRIPT_NAME="eapistats"
SCRIPT_SHORT="EAS"
SITEDIR="${HOME}/${SCRIPT_NAME}/"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"
PORTTREE="/usr/portage/"
DL='|'

if [ "$(hostname)" = s6 ]; then
	SCRIPT_MODE=true
	SITEDIR="/var/www/gentooqa.levelnine.at/results/"

fi

startdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${startdir}/funcs.sh ]; then
	source ${startdir}/funcs.sh
else
	echo "Missing funcs.sh"
	exit 1
fi

cd ${PORTTREE}
depth_set ${1}
${SCRIPT_MODE} && mkdir -p ${WORKDIR}/${SCRIPT_SHORT}-STA-eapi_statistics/

main() {
	local full_package=${1}
	local eapi=${2}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package="$(echo ${full_package}|cut -d'/' -f3)"
	local filename="$(echo ${full_package}|cut -d'/' -f4)"

	local maintainer="$(get_main_min "${category}/${package}")"

	if ${SCRIPT_MODE}; then
		echo "${eapi}${DL}${category}/${package}/${filename}${DL}${maintainer}" >> /${WORKDIR}/${SCRIPT_SHORT}-STA-eapi_statistics/full.txt
	else
		echo "${eapi}${DL}${category}/${package}/${filename}${DL}${maintainer}"
	fi
}

gen_sortings() {
	foldername="${SCRIPT_SHORT}-STA-eapi_statistics"
	newpath="${WORKDIR}/${foldername}"

	for i in $(cut -c-1 ${newpath}/full.txt|sort -u); do
		mkdir -p ${newpath}/${i}
		grep ^${i}${DL} ${newpath}/full.txt > ${newpath}/${i}/EAPI${i}.txt

		# sort by packages
		f_packages="$(cat ${newpath}/${i}/EAPI${i}.txt| cut -d "${DL}" -f2|sort|uniq)"
		for u in ${f_packages}; do
			f_cat="$(echo $u|cut -d'/' -f1)"
			f_pak="$(echo $u|cut -d'/' -f2)"
			mkdir -p ${newpath}/${i}/sort-by-package/${f_cat}
			grep "${u}" ${newpath}/${i}/EAPI${i}.txt > ${newpath}/${i}/sort-by-package/${f_cat}/${f_pak}.txt
		done
	
		mkdir -p ${newpath}/${i}/sort-by-maintainer/
		for a in $(cat ${newpath}/${i}/EAPI${i}.txt |cut -d "${DL}" -f3|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
			grep "${a}" ${newpath}/${i}/EAPI${i}.txt > ${newpath}/${i}/sort-by-maintainer/"$(echo ${a}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
		done
	done
	rm -rf ${SITEDIR}/stats/${foldername}
	cp -r ${newpath} ${SITEDIR}/stats/
	rm -rf ${WORKDIR}

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
export SCRIPT_MODE WORKDIR PORTTREE DL SCRIPT_SHORT

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
fi

