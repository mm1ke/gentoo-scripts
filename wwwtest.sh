#!/bin/bash

# Filename: wwwtest
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 19/02/2017

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
# simple scirpt to find broken websites

#export SCRIPT_MODE=true
#export PORTTREE="/usr/portage/"
#export SITEDIR="${HOME}/wwwtest/"

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
#${ENABLE_MD5} || exit 0
#${ENABLE_GIT} || exit 0

SCRIPT_NAME="wwwtest"
SCRIPT_SHORT="WWT"
SCRIPT_TYPE="checks"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"
TMPFILE="/tmp/${SCRIPT_NAME}-$(date +%y%m%d)-${RANDOM}.txt"
TMPCHECK="/tmp/${SCRIPT_NAME}-tmp-${RANDOM}.txt"
JOBS="50"
TIMEOUT="20"

# need the array in a function in order
# to be able to export the array
array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_homepage_http_statuscode"									#Index 0
	"${WORKDIR}/${SCRIPT_SHORT}-IMP-ebuild_homepage_301_redirections"									#Index 1
	"${WORKDIR}/${SCRIPT_SHORT}-IMP-ebuild_homepage_redirection_missing_slash_www"		#Index 2
	"${WORKDIR}/${SCRIPT_SHORT}-IMP-ebuild_homepage_redirection_http_to_https"				#Index 3
	"${WORKDIR}/${SCRIPT_SHORT}-BUG-ebuild_homepage_upstream_shutdown"								#Index 4
	"${WORKDIR}/${SCRIPT_SHORT}-IMP-ebuild_homepage_unsync"														#Index 5
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#


301check() {
	# needed to get the names
	array_names

	local hp=${1}
	local cat=${2}
	local pak=${3}
	local main=${4}
	local full_ebuild=${5}

	local found=false
	local lastchar="${hp: -1}"

	if echo ${hp}|grep 'http://' > /dev/null; then

		_sitemuts=("${hp/http:\/\//https:\/\/}" \
			"${hp/http:\/\//https:\/\/www.}")

		if ! [ "${lastchar}" = "/" ]; then
			_sitemuts+=("${hp/http:\/\//https:\/\/}/" \
				"${hp/http:\/\//https:\/\/www.}/")
		fi

		for sitemut in ${_sitemuts[@]}; do
			local _code="$(get_code ${sitemut})"
			if [ ${_code} = 200 ]; then
				found=true
				if ${SCRIPT_MODE}; then
					echo "$(get_eapi ${full_ebuild})${DL}${cat}/${pak}${DL}${hp}${DL}${sitemut}${DL}${main}" >> ${RUNNING_CHECKS[3]}/full.txt
				else
					echo "$(get_eapi ${full_ebuild})${DL}${cat}/${pak}${DL}${hp}${DL}${sitemut}${DL}${main}"
				fi
				break
			fi
		done

	else

		_sitemuts_v2=("${hp/https:\/\//https:\/\/www.}" \
			"${hp/http:\/\//http:\/\/www.}")

		if ! [ "${lastchar}" = "/" ]; then
			_sitemuts_v2+=("${hp}/" \
			"${hp/https:\/\//https:\/\/www.}/" \
			"${hp/http:\/\//http:\/\/www.}/")
		fi

		if ! ${found}; then
			for sitemut in ${_sitemuts_v2[@]}; do
				local _code="$(get_code ${sitemut})"
				if [ ${_code} = 200 ]; then
					found=true
					if ${SCRIPT_MODE}; then
						echo "$(get_eapi ${full_ebuild})${DL}${cat}/${pak}${DL}${hp}${DL}${sitemut}${DL}${main}" >> ${RUNNING_CHECKS[2]}/full.txt
					else
						echo "$(get_eapi ${full_ebuild})${DL}${cat}/${pak}${DL}${hp}${DL}${sitemut}${DL}${main}"
					fi
					break
				fi
			done
		fi
	fi

	if ! ${found}; then
		local correct_site="$(curl -Ls -o /dev/null --silent --max-time ${TIMEOUT} --head -w %{url_effective} ${hp})"
		new_code="$(get_code ${correct_site})"
		if ${SCRIPT_MODE}; then
			echo "$(get_eapi ${full_ebuild})${DL}${new_code}${DL}${cat}/${pak}${DL}${hp}${DL}${correct_site}${DL}${main}" >> ${RUNNING_CHECKS[1]}/full.txt
		else
			echo "$(get_eapi ${full_ebuild})${DL}${new_code}${DL}${cat}/${pak}${DL}${hp}${DL}${correct_site}${DL}${main}"
		fi
	fi
}

get_code() {
	local code="$(curl -o /dev/null --silent --max-time ${TIMEOUT} --head --write-out '%{http_code}\n' ${1})"
	echo ${code}
}

main() {
	mode() {
		local msg=${1}
		if ${SCRIPT_MODE}; then
			echo "${msg}" >> ${TMPFILE}
		else
			echo "${msg}"
		fi
	}

	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f1)"
	local package="$(echo ${full_package}|cut -d'/' -f2)"
	local maintainer="$(get_main_min "${category}/${package}")"
	local openbugs="$(get_bugs "${category}/${package}")"
	if ! [ -z "${openbugs}" ]; then
		openbugs="${DL}${openbugs}"
	fi

	for eb in ${PORTTREE}/${full_package}/*.ebuild; do
		ebuild=$(basename ${eb%.*})

		if ${ENABLE_MD5}; then
			_hp="$(grep ^HOMEPAGE= ${PORTTREE}/metadata/md5-cache/${category}/${ebuild})"
			_hp="${_hp:9}"
		else
			_hp="$(grep ^HOMEPAGE= ${eb}|cut -d'"' -f2)"
		fi

		if [ -n "${_hp}" ]; then
			for i in ${_hp}; do
				local _checktmp="$(grep "${DL}${i}${DL}" ${TMPCHECK}|head -1)"

				if echo ${i}|grep ^ftp >/dev/null;then
					mode "FTP${DL}${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}${openbugs}"
				elif echo ${i}|grep '${' >/dev/null; then
					mode "VAR${DL}${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}${openbugs}"
				elif [ -n "${_checktmp}" ]; then
					# don't check again
					mode "${_checktmp:0:3}${DL}${category}/${package}${DL}${ebuild}${DL}${_checktmp:4:-1}${DL}${maintainer}${openbugs}"
				else
					# get http status code
					_code="$(get_code ${i})"
					mode "${_code}${DL}${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}${openbugs}"
					echo "${_code}${DL}${i}${DL}" >> ${TMPCHECK}

					case ${_code} in
						301)
							301check "${i}" "${category}" "${package}" "${maintainer}" "${eb}"
							;;
						esac

				fi
			done
		fi
	done
}

find_func() {
	find ${searchp[@]} -mindepth ${MIND} -maxdepth ${MAXD} \
		-type d -print | parallel -j ${JOBS} main {}
}

gen_results(){
	if ${SCRIPT_MODE}; then
		# sort after http codes (including all codes)
		for i in $(cat ${TMPFILE}|cut -d "${DL}" -f1|sort -u); do
			mkdir -p ${RUNNING_CHECKS[0]}/sort-by-filter/${i}/
			grep "^${i}" ${TMPFILE} > ${RUNNING_CHECKS[0]}/sort-by-filter/${i}/full.txt
		done

		# copy full log
		cp ${TMPFILE} ${RUNNING_CHECKS[0]}/full-unfiltered.txt

		# copy full log, ignoring "good" codes
		sed -i "/^VAR/d; \
			/^FTP/d; \
			/^200/d; \
			/^301/d; \
			/^302/d; \
			/^307/d; \
			/^400/d; \
			/^503/d; \
			/^429/d; \
			" ${TMPFILE}
		cp ${TMPFILE} ${RUNNING_CHECKS[0]}/full.txt

		# special filters - ebuild_homepage_upstream_shutdown
		_filters=('berlios.de' 'gitorious.org' 'codehaus.org' 'code.google.com' 'fedorahosted.org' 'gna.org' 'freecode.com' 'freshmeat.net')
		for site in ${_filters[@]}; do
			mkdir -p "${RUNNING_CHECKS[4]}/sort-by-filter/${site}"
			if $(grep -q ${site} ${RUNNING_CHECKS[0]}/full-unfiltered.txt); then
				grep ${site} ${RUNNING_CHECKS[0]}/full-unfiltered.txt >> ${RUNNING_CHECKS[4]}/full.txt
				grep ${site} ${RUNNING_CHECKS[0]}/full-unfiltered.txt >> ${RUNNING_CHECKS[4]}/sort-by-filter/${site}/full.txt
				gen_sort_main_v3 ${RUNNING_CHECKS[4]}/sort-by-filter/${site}
				gen_sort_pak_v3 ${RUNNING_CHECKS[4]}/sort-by-filter/${site}
			fi
		done

		# ebuild_homepage_unsync
		# find different homepages in same packages
		for i in $(cat ${RUNNING_CHECKS[0]}/full-unfiltered.txt | cut -d'|' -f2|sort -u); do
			# get all HOMEPAGEs from every package,
			# lists them and count the lines.
			# if homepages are sync, the line count should be 1
			# --- works best with the md5-cache ---
			if ${ENABLE_MD5}; then
				hp_lines="$(grep "HOMEPAGE=" ${PORTTREE}/metadata/md5-cache/${i}-[0-9]* | cut -d'=' -f2|sort -u|wc -l)"
			else
				hp_lines="$(grep "HOMEPAGE=" ${PORTTREE}/${i}/*.ebuild | cut -d'=' -f2|sort -u|wc -l)"
			fi
			if [ "${hp_lines}" -gt 1 ]; then
				mkdir -p "${RUNNING_CHECKS[5]}/sort-by-package/${i%%/*}"
				# only category/package and maintainer went into the full.txt
				# via cut ... -f2,5 (needs update if data format changes
				grep "${DL}${i}${DL}" ${RUNNING_CHECKS[0]}/full-unfiltered.txt | head -n1 | cut -d'|' -f2,5  >> ${RUNNING_CHECKS[5]}/full.txt
			fi
		done

		sort_result_v2
		gen_sort_pak_v3
		gen_sort_main_v3

		copy_checks ${SCRIPT_TYPE}
	fi
}

cd ${PORTTREE}
# touch file first, otherwise the _checktmp could fail because of
# the missing file
touch ${TMPCHECK}
${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}
# for parallel execution
export -f main get_code 301check array_names
export TMPCHECK TMPFILE WORKDIR SCRIPT_SHORT TIMEOUT
if [ "${1}" = "diff" ]; then
	depth_set_v2 full
else
	depth_set_v2 ${1}
fi
${SCRIPT_MODE} && rm ${TMPFILE}
${SCRIPT_MODE} && rm -rf ${WORKDIR}
rm ${TMPCHECK}
