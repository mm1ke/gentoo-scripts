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

#override REPOTREE,FILERESULTS,RESULTSDIR settings
#export REPOTREE=/usr/portage/
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/srctest/"
# enabling debug output
#export DEBUG=true
#export DEBUGLEVEL=1
#export DEBUGFILE=/tmp/repostats.log

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
#${TREE_IS_MASTER} || exit 0		# only works with gentoo main tree
${ENABLE_MD5} || exit 0					# only works with md5 cache
#${ENABLE_GIT} || exit 0				# only works with git tree

SCRIPT_TYPE="checks"
WORKDIR="/tmp/srctest-${RANDOM}"
TMPCHECK="/tmp/srctest-tmp-${RANDOM}.txt"
JOBS="50"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/ebuild_src_uri_check"									#Index 0
	)
}
output_format(){
	index=(
		"${ebuild_eapi}${DL}${category}/${package}${DL}${ebuild}${DL}${srclink}${DL}${maintainer}${openbugs}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_index0 <<- EOM
This check uses wget's spider functionality to check if a ebuild's SRC_URI link still works.
The timeout to try to get a file is 15 seconds.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com/bar.zip|dev@gentoo.org:loper@foo.de|754124:612230 ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
https://foo.bar.com/bar.zip                 file which is not available
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
754124:612230                               open bug ids related to this package, seperated by ':'
EOM
	description=( "${info_index0}" )
	echo "${description[$1]}"
}
#
### IMPORTANT SETTINGS END ###
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
		local id=${1}
		local status=${2} #	available/maybe_available/not_available

		if ${FILERESULTS}; then
			output_format ${id} >> ${RUNNING_CHECKS[${id}]}/full_${status}.txt
			echo "${status}${DL}$(output_format ${id})" >> "${RUNNING_CHECKS[${id}]}/full-unfiltered.txt"
		else
			echo "${status}${DL}$(output_format ${id})"
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
	app-text/texlive-core
	dev-texlive/texlive-basic
	dev-texlive/texlive-bibtexextra
	dev-texlive/texlive-context
	dev-texlive/texlive-fontsextra
	dev-texlive/texlive-fontsrecommended
	dev-texlive/texlive-fontutils
	dev-texlive/texlive-formatsextra
	dev-texlive/texlive-games
	dev-texlive/texlive-humanities
	dev-texlive/texlive-langarabic
	dev-texlive/texlive-langchinese
	dev-texlive/texlive-langcjk
	dev-texlive/texlive-langcyrillic
	dev-texlive/texlive-langczechslovak
	dev-texlive/texlive-langenglish
	dev-texlive/texlive-langeuropean
	dev-texlive/texlive-langfrench
	dev-texlive/texlive-langgerman
	dev-texlive/texlive-langgreek
	dev-texlive/texlive-langitalian
	dev-texlive/texlive-langjapanese
	dev-texlive/texlive-langkorean
	dev-texlive/texlive-langother
	dev-texlive/texlive-langpolish
	dev-texlive/texlive-langportuguese
	dev-texlive/texlive-langspanish
	dev-texlive/texlive-latex
	dev-texlive/texlive-latexextra
	dev-texlive/texlive-latexrecommended
	dev-texlive/texlive-luatex
	dev-texlive/texlive-mathscience
	dev-texlive/texlive-metapost
	dev-texlive/texlive-music
	dev-texlive/texlive-pictures
	dev-texlive/texlive-plaingeneric
	dev-texlive/texlive-pstricks
	dev-texlive/texlive-publishers
	dev-texlive/texlive-xetex
	)
	for iglist in ${_ignore_list[@]}; do
		if [ "${category}/${package}" = "${iglist}" ]; then
			return 0
		fi
	done

#	code_available='HTTP/1.0 200 OK|HTTP/1.1 200 OK'
	code_available='Remote file exists.'
	maybe_available='HTTP/1.0 403 Forbidden|HTTP/1.1 403 Forbidden'

	for eb in ${REPOTREE}/${full_package}/*.ebuild; do
		local ebuild_eapi="$(get_eapi ${eb})"
		local ebuild=$(basename ${eb%.*})

		local _src="$(grep ^SRC_URI= ${REPOTREE}/metadata/md5-cache/${category}/${ebuild})"
		local _src=${_src:8}

		if [ -n "${_src}" ]; then
			# the variable SRC_URI sometimes has more data than just download links like
			# useflags or renamings, so just grep each text for http/https
			local u
			for u in ${_src}; do
				# add ^mirror:// to the grep, somehow we should be able to test them too
				local i
				for i in $(echo ${u} | grep -E "^http://|^https://"); do
					# check for zip dependecy first
					local srclink=${i}

					local _checktmp="$(grep -P "(^|\s)\K${srclink}(?=\s|$)" ${TMPCHECK}|sort -u)"
					if [ -n "${_checktmp}" ]; then
						srclink="$(echo ${_checktmp}| cut -d' ' -f2-)"
						mode 0 "$(echo ${_checktmp} | cut -d' ' -f1)"
					else
						if $(get_status ${srclink} "${code_available}"); then
							mode 0 available
							echo "available ${srclink}" >> ${TMPCHECK}
						elif $(get_status ${srclink} "${maybe_available}"); then
							mode 0 maybe_available
							echo "maybe_available ${srclink}" >> ${TMPCHECK}
						else
							mode 0 not_available
							echo "not_available ${srclink}" >> ${TMPCHECK}
						fi
					fi
				done
			done
		fi
	done
}

find_func() {
	find ${searchp[@]} -mindepth ${MIND} -maxdepth ${MAXD} \
		-type d -print 2>/dev/null | parallel -j ${JOBS} main {}

	if ${FILERESULTS}; then
		gen_descriptions
		cp ${RUNNING_CHECKS[0]}/full_not_available.txt ${RUNNING_CHECKS[0]}/full.txt 2>/dev/null

		sort_result_v4
		gen_sort_main_v4
		gen_sort_pak_v4

		copy_checks ${SCRIPT_TYPE}
	fi
}

array_names
cd ${REPOTREE}
export -f main array_names output_format
export WORKDIR TMPCHECK
touch ${TMPCHECK}
${FILERESULTS} && mkdir -p ${RUNNING_CHECKS[@]}
if [ "${1}" = "diff" ]; then
	depth_set_v3 full
else
	depth_set_v3 ${1}
fi
${FILERESULTS} && rm -rf ${WORKDIR}
rm ${TMPCHECK}
