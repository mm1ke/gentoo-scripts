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
#export PORTTREE=/usr/portage/
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/srctest/"

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

# feature requirements
#${TREE_IS_MASTER} || exit 0
${ENABLE_MD5} || exit 0
#${ENABLE_GIT} || exit 0

SCRIPT_NAME="srctest"
SCRIPT_SHORT="SRT"
SCRIPT_TYPE="checks"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"
TMPCHECK="/tmp/${SCRIPT_NAME}-tmp-${RANDOM}.txt"
JOBS="50"

# need the array in a function in order
# to be able to export the array
array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_src_uri_check"									#Index 0
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_src_uri_offline"								#Index 1
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_missing_zip_dependency"				#Index 2
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

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
	local category="$(echo ${full_package}|cut -d'/' -f1)"
	local package="$(echo ${full_package}|cut -d'/' -f2)"
	local maintainer="$(get_main_min "${category}/${package}")"
	local openbugs="$(get_bugs "${category}/${package}")"
	if ! [ -z "${openbugs}" ]; then
		openbugs="${DL}${openbugs}"
	fi

	# ignore the following packagelist for now.
	# all inheriting the toolchain-{binutils,glibc} eclass which generates the
	# SRC_URI somehow and probably generates lots of false positives
	local _ignore_list=(
	dev-lang/gnat-gpl
	sys-devel/gcc
	sys-devel/kgcc64
	sys-devel/binutils
	sys-devel/binutils-hppa64
	sys-libs/glibc
	)
	for iglist in ${_ignore_list[@]}; do
		if [ "${category}/${package}" = "${iglist}" ]; then
			return 0
		fi
	done

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
					# check for zip dependecy first
					local _fileformat="$(echo ${i: -4})"
					if [ "${_fileformat}" = ".zip" ]; then
						if ! $(grep "app-arch/unzip" ${PORTTREE}/metadata/md5-cache/${category}/${ebuild} >/dev/null ); then
							mode ${RUNNING_CHECKS[2]} \
									"${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}${openbugs}" \
									missing_zip
						fi
					fi
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
							if $(grep -e "^RESTRICT=.*mirror" ${eb} >/dev/null); then
								mode ${RUNNING_CHECKS[1]} \
									"${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}${openbugs}" \
									offline
							fi
							echo "not_available ${i}" >> ${TMPCHECK}
						fi
					fi
				done
			done
		fi
	done
}

find_func() {
	find ${searchp[@]} -mindepth ${MIND} -maxdepth ${MAXD} \
		-type d -print | parallel -j ${JOBS} main {}
}

gen_results() {
	if ${SCRIPT_MODE}; then
		cp ${RUNNING_CHECKS[0]}/full_not_available.txt ${RUNNING_CHECKS[0]}/full.txt
		cp ${RUNNING_CHECKS[1]}/full_offline.txt ${RUNNING_CHECKS[1]}/full.txt
		cp ${RUNNING_CHECKS[2]}/full_missing_zip.txt ${RUNNING_CHECKS[2]}/full.txt

		sort_result_v2
		gen_sort_main_v3
		gen_sort_pak_v3

		copy_checks ${SCRIPT_TYPE}
	fi
}

cd ${PORTTREE}
export -f main get_main_min array_names
export WORKDIR TMPCHECK SCRIPT_SHORT
touch ${TMPCHECK}
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}
if [ "${1}" = "diff" ]; then
	depth_set_v2 full
else
	depth_set_v2 ${1}
fi
${SCRIPT_MODE} && rm -rf ${WORKDIR}
rm ${TMPCHECK}
