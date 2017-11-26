#!/bin/bash

# Filename: eapichecks.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 20/11/2017

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
# This scripts checks eapi usage. it looks for ebuils with old eapi 
# and checks if there is a revision/version bump with a newer eapi

SCRIPT_MODE=false
WWWDIR="${HOME}/eapichecks/"
WORKDIR="/tmp/eapichecks-${RANDOM}"
PORTTREE="/usr/portage/"
DL='|'

if [ "$(hostname)" = s6 ]; then
	SCRIPT_MODE=true
	WWWDIR="/var/www/gentoo.levelnine.at/eapichecks/"
fi

startdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${startdir}/funcs.sh ]; then
	source ${startdir}/funcs.sh
else
	echo "Missing funcs.sh"
	exit 1
fi

cd ${PORTTREE}

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
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package="$(echo ${full_package}|cut -d'/' -f3)"
	local filename="$(echo ${full_package}|cut -d'/' -f4)"

	local maintainer="$(get_main_min "${category}/${package}")"
	if [ -z "${maintainer}" ]; then
			maintainer="maintainer-needed@gentoo.org:"
	fi

	if ${SCRIPT_MODE}; then
		mkdir -p /${WORKDIR}/${NAME}/
		echo "${category}/${package}/${filename}${DL}${maintainer}" >> /${WORKDIR}/${NAME}/${NAME}.txt
	else
		echo "${NAME}${DL}${category}/${package}/${filename}${DL}${maintainer}"
	fi
}

pre_eapi_check() {
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package="$(echo ${full_package}|cut -d'/' -f3)"
	local filename="$(echo ${full_package}|cut -d'/' -f4)"

	local name="${filename%.*}"
	local ebuild_eapi="$(grep ^EAPI ${full_package} |tr -d '"'|cut -d'=' -f2|cut -c1-2)"

	local gitdir="/mnt/data/gentoo/"
	local date_today="$(date '+%s' -d today)"

	local package_path="/${PORTTREE}/${category}/${package}"

	if [ "${name: -3}" = "-r${name: -1}" ]; then
		start=$(expr ${name: -1} + 1)
		org_name=${name}
		name=${name::-3}
	else
		start=1
		org_name=${name}
	fi

	for i in $(seq $start 10); do
		if [ -e ${package_path}/${name}-r$i.ebuild ]; then
			found_ebuild="${package_path}/${name}-r$i.ebuild"
			if [ "$(grep ^EAPI ${found_ebuild} |tr -d '"'|cut -d'=' -f2)" = "6" ]; then

				if [ -e ${gitdir} ]; then
					age_file1=$(expr \( "${date_today}" - \
						"$(date '+%s' -d $(git -C ${gitdir} log --format="format:%ci" --name-only --diff-filter=A ${gitdir}/${category}/${package}/${org_name}.ebuild \
						| head -1|cut -d' ' -f1) 2>/dev/null )" \) / 86400 2>/dev/null)
					age_file2=$(expr \( "${date_today}" - \
						"$(date '+%s' -d $(git -C ${gitdir} log --format="format:%ci" --name-only --diff-filter=A ${gitdir}/${category}/${package}/${name}-r$i.ebuild \
						| head -1|cut -d' ' -f1) 2>/dev/null)" \) / 86400 2>/dev/null)
				else
					age_file1="NULL"
					age_file2="NULL"
				fi

				if [ "$(grep ^KEYWORDS ${package_path}/${org_name}.ebuild)" = "$(grep ^KEYWORDS ${package_path}/${name}-r$i.ebuild)" ]; then
#					echo "${category}/${org_name} (EAPI:${ebuild_eapi} / AGE:${age_file1}) --> ${category}/${name}-r$i (EAPI:6 / AGE:${age_file2})"
					echo "${ebuild_eapi}|${age_file1}|${category}/${org_name}|6|${age_file2}|${category}/${name}-r$i"

				else
#					echo "${category}/${org_name} (EAPI:${ebuild_eapi} / AGE:${age_file1}) --keywordsbump-> ${category}/${name}-r$i (EAPI:6 / AGE:${age_file2})"
					echo "${ebuild_eapi}|${age_file1}|${category}/${org_name}|6|${age_file2}|${category}/${name}-r$i|nonmatchingkeyword"

				fi
				break 2
			fi
		fi
	done
	if [ $i = 10 ]; then
		if ! [ ${ebuild_eapi} = 5 ]; then
			echo "${ebuild_eapi}|${category}/$org_name|needs a bump"
		fi
	fi
}

export -f main get_main_min
export -f pre_eapi_check
export PORTTREE WORKDIR SCRIPT_MODE DL

export NAME="quickbump"
for e in $(seq 1 5); do
	find ./${level}  \( \
		-path ./scripts/\* -o \
		-path ./profiles/\* -o \
		-path ./packages/\* -o \
		-path ./licenses/\* -o \
		-path ./distfiles/\* -o \
		-path ./metadata/\* -o \
		-path ./eclass/\* -o \
		-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l "^EAPI.*${e}" {} \; | parallel pre_eapi_check {}
done

#if ${SCRIPT_MODE}; then
#	gen_sort_main ${WORKDIR}/special/unsync-homepages/full.txt 2 ${WORKDIR}/special/unsync-homepages/ ${DL}
#	gen_sort_pak ${WORKDIR}/special/301_redirections/301_redirections.txt 2 ${WORKDIR}/special/301_redirections/ ${DL}
#fi
