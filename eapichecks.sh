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
SCRIPT_NAME="eapichecks"
PORTTREE="/usr/portage/"
WWWDIR="${HOME}/${SCRIPT_NAME}/"
if [ "$(hostname)" = s6 ]; then
	SCRIPT_MODE=true
	PORTTREE="/mnt/gentootree/gentoo-github"
	WWWDIR="/var/www/gentoo.levelnine.at/${SCRIPT_NAME}/"
fi

WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"
DL='|'

startdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${startdir}/funcs.sh ]; then
	source ${startdir}/funcs.sh
else
	echo "Missing funcs.sh"
	exit 1
fi

cd ${PORTTREE}
depth_set ${1}
export PORTTREE WORKDIR SCRIPT_MODE DL


output() {
	local text="${1}"
	local type="${2}"

	if ${SCRIPT_MODE}; then
		mkdir -p /${WORKDIR}/${type}/
		echo "${text}" >> /${WORKDIR}/${type}/full.txt
	else
		echo "${text}${DL}${type}"
	fi
}

main() {
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package="$(echo ${full_package}|cut -d'/' -f3)"
	local filename="$(echo ${full_package}|cut -d'/' -f4)"
	local name="${filename%.*}"

	if ! $(cat ${full_package} | grep ^EAPI >/dev/null ); then
		local ebuild_eapi="0"
	else
		local ebuild_eapi="$(grep ^EAPI ${full_package} |tr -d '"'|cut -d'=' -f2|cut -c1-2)"
	fi

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

	# check for maximal 10 reversion
	for i in $(seq $start 10); do
		if [ -e ${package_path}/${name}-r${i}.ebuild ]; then
			local found_ebuild="${package_path}/${name}-r${i}.ebuild"
			if [ "$(grep ^EAPI ${found_ebuild} |tr -d '"'|cut -d'=' -f2)" = "6" ]; then
				local old_file=""
				local new_file=""
				if ${ENABLE_GIT}; then
					old_file="$(get_age "${org_name}.ebuild")${DL}"
					new_file="$(get_age "${name}-r${i}.ebuild")${DL}"
				fi
				if [ "$(grep KEYWORDS\= ${package_path}/${org_name}.ebuild)" = "$(grep KEYWORDS\= ${package_path}/${name}-r${i}.ebuild)" ]; then
					output "${ebuild_eapi}${DL}${old_file}${category}/${package}${DL}${org_name}${DL}6${DL}${new_file}${category}/${name}-r${i}${DL}${maintainer}${openbugs}" \
						"bump_matchingkeywords"

				else
					output "${ebuild_eapi}${DL}${old_file}${category}/${package}${DL}${org_name}${DL}6${DL}${new_file}${category}/${name}-r${i}${DL}${maintainer}${openbugs}" \
						"bump_nonmatchingkeyword"
				fi
				break 2
			fi
		fi
	done
	if ! [ ${ebuild_eapi} = 5 ]; then
		other_ebuild_eapi=($(grep ^EAPI ${category}/${package}/*.ebuild |tr -d '"'|cut -d'=' -f2|sort -u))
		[ -z "${other_ebuild_eapi}" ] && other_ebuild_eapi=0
		output "${ebuild_eapi}${DL}$(echo ${other_ebuild_eapi[@]})${DL}${category}/${package}${DL}${org_name}${DL}${maintainer}${openbugs}" \
			"bump_needed"
	fi
}

export -f main output

find ./${level}  \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec grep -L "^EAPI" {} \; | parallel main {}

for e in $(seq 1 5); do
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
	gen_sort_main ${WORKDIR}/bump_needed/full.txt 5 ${WORKDIR}/bump_needed/ ${DL}
	gen_sort_pak ${WORKDIR}/bump_needed/full.txt 3 ${WORKDIR}/bump_needed/ ${DL}

	gen_sort_main ${WORKDIR}/bump_nonmatchingkeyword/full.txt $(${ENABLE_GIT} && echo 8 || echo 6) ${WORKDIR}/bump_nonmatchingkeyword/ ${DL}
	gen_sort_pak ${WORKDIR}/bump_nonmatchingkeyword/full.txt $(${ENABLE_GIT} && echo 3 || echo 2) ${WORKDIR}/bump_nonmatchingkeyword/ ${DL}

	gen_sort_main ${WORKDIR}/bump_matchingkeywords/full.txt $(${ENABLE_GIT} && echo 8 || echo 6) ${WORKDIR}/bump_matchingkeywords/ ${DL}
	gen_sort_pak ${WORKDIR}/bump_matchingkeywords/full.txt $(${ENABLE_GIT} && echo 3 || echo 2) ${WORKDIR}/bump_matchingkeywords/ ${DL}


	mkdir -p ${WORKDIR/-/_}
	gen_sort_main ${WORKDIR}/bump_needed/full.txt 5 ${WORKDIR/-/_}/${SCRIPT_NAME}-bump_needed/ ${DL}
	gen_sort_pak ${WORKDIR}/bump_needed/full.txt 3 ${WORKDIR/-/_}/${SCRIPT_NAME}-bump_needed/ ${DL}

	gen_sort_main ${WORKDIR}/bump_nonmatchingkeyword/full.txt $(${ENABLE_GIT} && echo 8 || echo 6) ${WORKDIR/-/_}/${SCRIPT_NAME}-bump_nonmatchingkeyword/ ${DL}
	gen_sort_pak ${WORKDIR}/bump_nonmatchingkeyword/full.txt $(${ENABLE_GIT} && echo 3 || echo 2) ${WORKDIR/-/_}/${SCRIPT_NAME}-bump_nonmatchingkeyword/ ${DL}

	gen_sort_main ${WORKDIR}/bump_matchingkeywords/full.txt $(${ENABLE_GIT} && echo 8 || echo 6) ${WORKDIR/-/_}/${SCRIPT_NAME}-bump_matchingkeywords/ ${DL}
	gen_sort_pak ${WORKDIR}/bump_matchingkeywords/full.txt $(${ENABLE_GIT} && echo 3 || echo 2) ${WORKDIR/-/_}/${SCRIPT_NAME}-bump_matchingkeywords/ ${DL}
	rm -rf /var/www/gentooqa.levelnine.at/results/${SCRIPT_NAME}*
	cp -r ${WORKDIR/-/_}/* /var/www/gentooqa.levelnine.at/results/checks/
	rm -rf ${WORKDIR/-/_}

	script_mode_copy
fi
