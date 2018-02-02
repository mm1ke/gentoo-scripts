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

SCRIPT_MODE=false
PORTTREE="/usr/portage/"
WWWDIR="${HOME}/srctest/"
WORKDIR="/tmp/srctest-${RANDOM}"
TMPCHECK="/tmp/srctest-tmp-${RANDOM}.txt"
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
	WWWDIR="/var/www/gentoo.levelnine.at/srctest/"
fi

touch ${TMPCHECK}
${SCRIPT_MODE} && mkdir -p ${WORKDIR}

cd ${PORTTREE}
depth_set ${1}

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
		local msg=${1}
		local status=${2}
		if ${SCRIPT_MODE}; then
			echo "${msg}" >> "${WORKDIR}/full_${status}.txt"
			echo "${status}${DL}${msg}" >> "${WORKDIR}/full.txt"
		else
			echo "${status}${DL}${msg}"
		fi
	}

	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package=${full_package##*/}
	local maintainer="$(get_main_min "${category}/${package}")"
	local md5portage=false

#	code_available='HTTP/1.0 200 OK|HTTP/1.1 200 OK'
	code_available='Remote file exists.'
	maybe_available='HTTP/1.0 403 Forbidden|HTTP/1.1 403 Forbidden'

	if [ -z "${maintainer}" ]; then
			maintainer="maintainer-needed@gentoo.org:"
	fi

	# only works best with the md5-cache
	if ! [ -e "${PORTTREE}/metadata/md5-cache" ]; then
		exit 1
	fi

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
						mode "${category}/${package}${DL}${ebuild}${DL}$(echo ${_checktmp} | cut -d' ' -f2-)${DL}${maintainer}" "$(echo ${_checktmp} | cut -d' ' -f1)"
					else
						if $(get_status ${i} "${code_available}"); then
							mode "${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}" available
							echo "available ${i}" >> ${TMPCHECK}
						elif $(get_status ${i} "${maybe_available}"); then
							mode "${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}" maybe_available
							echo "maybe_available ${i}" >> ${TMPCHECK}
						else
							mode "${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}" not_available
							echo "not_available ${i}" >> ${TMPCHECK}
						fi
					fi
				done
			done
		fi
	done
}

export -f main get_main_min
export PORTTREE WORKDIR SCRIPT_MODE TMPCHECK DL

find ./${level} -mindepth $MIND -maxdepth $MAXD \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type d -print | parallel main {}

if ${SCRIPT_MODE}; then
	# sort by packages, ignoring "good" codes
	gen_sort_pak ${WORKDIR}/full_not_available.txt 1 ${WORKDIR} ${DL}
	# sort by maintainer, ignoring "good" codes
	gen_sort_main ${WORKDIR}/full_not_available.txt 4 ${WORKDIR} ${DL}
	# copy files to wwwdir
	script_mode_copy
fi
rm ${TMPCHECK}
