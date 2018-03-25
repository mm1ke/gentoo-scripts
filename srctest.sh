#!/bin/bash

# Filename: srctest
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 12/08/2017

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
# simple scirpt to find broken SRC_URI links

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#PORTTREE=/usr/portage/
#SCRIPT_MODE=true
#SITEDIR="${HOME}/srctest/"

startdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${startdir}/funcs.sh ]; then
	source ${startdir}/funcs.sh
else
	echo "Missing funcs.sh"
	exit 1
fi

#
### IMPORTANT SETTINGS START ###
#
SCRIPT_NAME="srctest"
SCRIPT_SHORT="SRT"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"
TMPCHECK="/tmp/${SCRIPT_NAME}-tmp-${RANDOM}.txt"
JOBS="50"

# need the array in a function in order
# to be able to export the array
array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-src_uri_check"									#Index 0
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

# only works with md5-cache
if ! ${ENABLE_MD5}; then
	exit 1
fi

main() {
	get_status() {
		local uri="${1}"
		local code="${2}"
		if $(timeout 15 wget -T 10 --no-check-certificate -S --spider ${uri} 2>&1 | grep -E "${code}" >/dev/null); then
			echo true
		else
			echo false
		fi
	}

	mode() {
		local check=${1}
		local msg=${2}
		local status=${3}

		if ${SCRIPT_MODE}; then
			echo "${msg}" >> "${check}/full_${status}.txt"
			echo "${status}${DL}${msg}" >> "${check}/full-unfiltered.txt"
		else
			echo "${status}${DL}${msg}"
		fi
	}

	array_names

	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package=${full_package##*/}
	local maintainer="$(get_main_min "${category}/${package}")"
	local openbugs="$(get_bugs "${category}/${package}")"
	if ! [ -z "${openbugs}" ]; then
		openbugs="${DL}${openbugs}"
	fi

#	code_available='HTTP/1.0 200 OK|HTTP/1.1 200 OK'
	code_available='Remote file exists.'
	maybe_available='HTTP/1.0 403 Forbidden|HTTP/1.1 403 Forbidden'

	for eb in ${PORTTREE}/${full_package}/*.ebuild; do
		local ebuild=$(basename ${eb%.*})

		local _src="$(grep ^SRC_URI= ${PORTTREE}/metadata/md5-cache/${category}/${ebuild})"
		local _src=${_src:8}

		if [ -n "${_src}" ]; then
			# the variable SRC_URI sometimes has more data than just download links like
			# useflags or renamings, so just grep each text for http/https
			for u in ${_src}; do
				# add ^mirror:// to the grep, somehow we should be able to test them too
				for i in $(echo $u | grep -E "^http://|^https://"); do
					local _checktmp="$(grep -P "(^|\s)\K${i}(?=\s|$)" ${TMPCHECK}|sort -u)"
					if [ -n "${_checktmp}" ]; then
						mode ${RUNNING_CHECKS[0]} \
							"${category}/${package}${DL}${ebuild}${DL}$(echo ${_checktmp} | cut -d' ' -f2-)${DL}${maintainer}${openbugs}" \
							"$(echo ${_checktmp} | cut -d' ' -f1)"
					else
						if $(get_status ${i} "${code_available}"); then
							mode ${RUNNING_CHECKS[0]} \
								"${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}${openbugs}" \
								available
							echo "available ${i}" >> ${TMPCHECK}
						elif $(get_status ${i} "${maybe_available}"); then
							mode ${RUNNING_CHECKS[0]} \
								"${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}${openbugs}" \
								maybe_available
							echo "maybe_available ${i}" >> ${TMPCHECK}
						else
							mode ${RUNNING_CHECKS[0]} \
								"${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}${openbugs}" \
								not_available
							echo "not_available ${i}" >> ${TMPCHECK}
						fi
					fi
				done
			done
		fi
	done
}

depth_set ${1}
cd ${PORTTREE}
export -f main get_main_min array_names
export WORKDIR TMPCHECK SCRIPT_SHORT
touch ${TMPCHECK}
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}

find ./${level} -mindepth ${MIND} -maxdepth ${MAXD} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type d -print | parallel -j ${JOBS} main {}


if ${SCRIPT_MODE}; then
	cp ${RUNNING_CHECKS[0]}/full_not_available.txt ${RUNNING_CHECKS[0]}/full.txt

	gen_sort_main_v2 ${RUNNING_CHECKS[0]} 4
	gen_sort_pak_v2 ${RUNNING_CHECKS[0]} 1

	copy_checks checks
	rm -rf ${WORKDIR}
fi
rm ${TMPCHECK}
