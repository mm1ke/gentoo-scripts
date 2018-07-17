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

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/eapichecks/"
#export PORTTREE="/usr/portage/"

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
SCRIPT_NAME="eapichecks"
SCRIPT_SHORT="EAC"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-STA-ebuild_cleanup_candidates"					#Index 0
	"${WORKDIR}/${SCRIPT_SHORT}-STA-ebuild_stable_candidates"						#Index 1
	"${WORKDIR}/${SCRIPT_SHORT}-STA-ebuild_obsolete_eapi"								#Index 2
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#


output() {
	local text="${1}"
	local type="${2}"

	if ${SCRIPT_MODE}; then
		echo "${text}" >> /${WORKDIR}/${type}/full.txt
	else
		echo "${text}${DL}${type}"
	fi
}

main() {
	array_names
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package="$(echo ${full_package}|cut -d'/' -f3)"
	local filename="$(echo ${full_package}|cut -d'/' -f4)"
	local name="${filename%.*}"
	local ebuild_eapi="$(get_eapi ${full_package})"

	local date_today="$(date '+%s' -d today)"
	local package_path="/${PORTTREE}/${category}/${package}"

	local maintainer="$(get_main_min "${category}/${package}")"
	local openbugs="$(get_bugs ${category}/${package})"
	if ! [ -z "${openbugs}" ]; then
		openbugs="${DL}${openbugs}"
	fi

	if [ "${name: -3}" = "-r${name: -1}" ]; then
		start=$(expr ${name: -1} + 1)
		org_name=${name}
		name=${name::-3}
	else
		start=1
		org_name=${name}
	fi

	local i

	# check for maximal 10 reversion
	for i in $(seq $start 10); do
		if [ -e ${package_path}/${name}-r${i}.ebuild ]; then
			local found_ebuild="${package_path}/${name}-r${i}.ebuild"
			local eapi_found_ebuild="$(get_eapi ${found_ebuild})"

			if [ "${eapi_found_ebuild}" = "6" ] || [ "${eapi_found_ebuild}" = "7" ]; then
				local old_file=""
				local new_file=""
				if ${ENABLE_GIT}; then
					old_file="$(get_age "${org_name}.ebuild")${DL}"
					new_file="$(get_age "${name}-r${i}.ebuild")${DL}"
				fi
				# TODO: use md5-cache here for KEYWORDS grepping, also maybe write
				# a _func version
				if [ "$(grep KEYWORDS\= ${package_path}/${org_name}.ebuild  | sed -e 's/^[ \t]*//')" = "$(grep KEYWORDS\= ${package_path}/${name}-r${i}.ebuild | sed -e 's/^[ \t]*//')" ]; then
					output "${ebuild_eapi}${DL}${old_file}${eapi_found_ebuild}${DL}${new_file}${category}/${package}${DL}${org_name}${DL}${name}-r${i}${DL}${maintainer}${openbugs}" \
						"${RUNNING_CHECKS[0]##*/}"

				else
					output "${ebuild_eapi}${DL}${old_file}${eapi_found_ebuild}${DL}${new_file}${category}/${package}${DL}${org_name}${DL}${name}-r${i}${DL}${maintainer}${openbugs}" \
						"${RUNNING_CHECKS[1]##*/}"
				fi
				break 2
			fi
		fi
	done
	if ! [ ${ebuild_eapi} = 5 ]; then
		output "${ebuild_eapi}${DL}$(get_eapi_pak ${package_path})${DL}${category}/${package}${DL}${org_name}${DL}${maintainer}${openbugs}" \
			"${RUNNING_CHECKS[2]##*/}"
	fi
}

depth_set ${1}
cd ${PORTTREE}
export WORKDIR SCRIPT_SHORT
export -f main output array_names
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}

for e in $(seq 0 5); do
	find ./${level}  \( \
		-path ./scripts/\* -o \
		-path ./profiles/\* -o \
		-path ./packages/\* -o \
		-path ./licenses/\* -o \
		-path ./distfiles/\* -o \
		-path ./metadata/\* -o \
		-path ./eclass/\* -o \
		-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -l "^EAPI.*${e}" {} \; | parallel main {}
done

if ${SCRIPT_MODE}; then
	gen_sort_main_v2 ${RUNNING_CHECKS[2]} 5
	gen_sort_pak_v2 ${RUNNING_CHECKS[2]} 3

	gen_sort_main_v2 ${RUNNING_CHECKS[0]} $(${ENABLE_GIT} && echo 8 || echo 6)
	gen_sort_pak_v2 ${RUNNING_CHECKS[0]} $(${ENABLE_GIT} && echo 5 || echo 3)

	gen_sort_main_v2 ${RUNNING_CHECKS[1]} $(${ENABLE_GIT} && echo 8 || echo 6)
	gen_sort_pak_v2 ${RUNNING_CHECKS[1]} $(${ENABLE_GIT} && echo 5 || echo 3)

	copy_checks stats
	rm -rf ${WORKDIR}
fi
