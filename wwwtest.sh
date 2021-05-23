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

#export FILERESULTS=true
#export REPOTREE="/usr/portage/"
#export RESULTSDIR="${HOME}/wwwtest/"
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
#${ENABLE_MD5} || exit 0				# only works with md5 cache
#${ENABLE_GIT} || exit 0				# only works with git tree

SCRIPT_TYPE="checks"
WORKDIR="/tmp/wwwtest-${RANDOM}"
TMPFILE="/tmp/wwwtest-$(date +%y%m%d)-${RANDOM}.txt"
TMPCHECK="/tmp/wwwtest-tmp-${RANDOM}.txt"
JOBS="50"
TIMEOUT="20"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/ebuild_homepage_http_statuscode"									#Index 0
		"${WORKDIR}/ebuild_homepage_301_redirections"									#Index 1
		"${WORKDIR}/ebuild_homepage_redirection_missing_slash_www"		#Index 2
		"${WORKDIR}/ebuild_homepage_redirection_http_to_https"				#Index 3
	)
}
output_format(){
	index=(
		not_used0
		"${ebuild_eapi}${DL}${new_code}${DL}${cat}/${pak}${DL}${ebuild}${DL}${hp}${DL}${correct_site}${DL}${main}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${ebuild}${DL}${hp}${DL}${sitemut}${DL}${main}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${ebuild}${DL}${hp}${DL}${sitemut}${DL}${main}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_index0 <<- EOM
This checks tests every homepage and gets their http return code. The list contain packages with a bad returncode.
Following statuscodes are ignored: VAR, FTP, 200, 301, 302, 307, 400, 503.
<a href="ebuild_homepage_http_statuscode-detailed.html">Status Code History</a>

Data Format ( 7|404|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com|dev@gentoo.org:loper@foo.de|754124:612230 ):
7                                           EAPI Version
404                                         http statuscode
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
https://foo.bar.com                         homepage corresponding to the statuscode
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
754124:612230                               open bug ids related to this package
EOM
read -r -d '' info_index1 <<- EOM
Lists ebuilds with a Homepage which actually redirects to another sites.

Data Format ( 7|404|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com|https://bar.foo.com|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
404                                         http statuscode of redirected website
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
https://foo.bar.com                         original hommepage in ebuild
https://bar.foo.com                         redirected homepage
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index2 <<- EOM
Lists ebuild who's homepage redirects to the same site only including a "www" or a missing "/" at the end (or both)

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com|https://foo.bar.com/|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
https://foo.bar.com                         original hommepage in ebuild
https://foo.bar.com/                        same homepage, only with a slash at the end
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index3 <<- EOM
Lists ebuids who's homepage redirects to the same site only via HTTPS.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|http://foo.bar.com|https://foo.bar.com|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
http://foo.bar.com                          original hommepage in ebuild
https://foo.bar.com                         same homepage, only with https
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM

	description=( "${info_index0}" "${info_index1}" "${info_index2}" \
		"${info_index3}" )
	echo "${description[$1]}"
}
#
### IMPORTANT SETTINGS END ###
#


301check() {
	# needed to get the names
	array_names

	local hp=${1}
	local cat=${2}
	local pak=${3}
	local main=${4}
	local ebuild="$(basename ${5})"
	local ebuild_eapi=${6}

	local found=false
	local lastchar="${hp: -1}"

	output(){
		local checkid=${1}
		if ${FILERESULTS}; then
			output_format ${checkid} >> ${RUNNING_CHECKS[${checkid}]}/full.txt
		else
			output_format ${checkid}
		fi
	}

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
				output 3
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
					output 2
					break
				fi
			done
		fi
	fi

	if ! ${found}; then
		local correct_site="$(curl -Ls -o /dev/null --silent --max-time ${TIMEOUT} --head -w %{url_effective} ${hp})"
		new_code="$(get_code ${correct_site})"
		output 1
	fi
}

get_code() {
	local code="$(curl -o /dev/null --silent --max-time ${TIMEOUT} --head --write-out '%{http_code}\n' ${1})"
	echo ${code}
}

main() {
	mode() {
		local msg=${1}
		if ${FILERESULTS}; then
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

	for eb in ${REPOTREE}/${full_package}/*.ebuild; do

		local ebuild_eapi="$(get_eapi ${eb})"
		local ebuild=$(basename ${eb%.*})

		if ${ENABLE_MD5}; then
			_hp="$(grep ^HOMEPAGE= ${REPOTREE}/metadata/md5-cache/${category}/${ebuild})"
			_hp="${_hp:9}"
		else
			_hp="$(grep ^HOMEPAGE= ${eb}|cut -d'"' -f2)"
		fi

		if [ -n "${_hp}" ]; then
			for i in ${_hp}; do
				local _checktmp="$(grep "${DL}${i}${DL}" ${TMPCHECK}|head -1)"

				if echo ${i}|grep ^ftp >/dev/null;then
					mode "${ebuild_eapi}${DL}FTP${DL}${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}${openbugs}"
				elif echo ${i}|grep '${' >/dev/null; then
					mode "${ebuild_eapi}${DL}VAR${DL}${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}${openbugs}"
				elif [ -n "${_checktmp}" ]; then
					# don't check again
					mode "${ebuild_eapi}${DL}${_checktmp:2:3}${DL}${category}/${package}${DL}${ebuild}${DL}${_checktmp:6:-1}${DL}${maintainer}${openbugs}"
				else
					# get http status code
					_code="$(get_code ${i})"
					mode "${ebuild_eapi}${DL}${_code}${DL}${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}${openbugs}"
					echo "${ebuild_eapi}${DL}${_code}${DL}${i}${DL}" >> ${TMPCHECK}

					case ${_code} in
						301)
							301check "${i}" "${category}" "${package}" "${maintainer}" "${eb}" "${ebuild_eapi}"
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

	if ${FILERESULTS}; then
		gen_descriptions
		# sort after http codes (including all codes)
		for i in $(cat ${TMPFILE}|cut -d "${DL}" -f2|sort -u); do
			mkdir -p ${RUNNING_CHECKS[0]}/sort-by-filter/${i}/
			grep "${DL}${i}${DL}" ${TMPFILE} > ${RUNNING_CHECKS[0]}/sort-by-filter/${i}/full.txt
		done

		# copy full log
		cp ${TMPFILE} ${RUNNING_CHECKS[0]}/full-unfiltered.txt

		# copy full log, ignoring "good" codes
		sed -i "/${DL}VAR${DL}/d; \
			/${DL}FTP${DL}/d; \
			/${DL}200${DL}/d; \
			/${DL}301${DL}/d; \
			/${DL}302${DL}/d; \
			/${DL}307${DL}/d; \
			/${DL}400${DL}/d; \
			/${DL}503${DL}/d; \
			/${DL}429${DL}/d; \
			" ${TMPFILE}
		cp ${TMPFILE} ${RUNNING_CHECKS[0]}/full.txt

		sort_result_v3
		gen_sort_pak_v3
		gen_sort_main_v3

		copy_checks ${SCRIPT_TYPE}
	fi
}

array_names
cd ${REPOTREE}
# touch file first, otherwise the _checktmp could fail because of
# the missing file
touch ${TMPCHECK}
${FILERESULTS} && mkdir -p ${RUNNING_CHECKS[@]}
# for parallel execution
export -f main get_code 301check array_names output_format
export TMPCHECK TMPFILE WORKDIR TIMEOUT
if [ "${1}" = "diff" ]; then
	depth_set_v3 full
else
	depth_set_v3 ${1}
fi
${FILERESULTS} && rm ${TMPFILE}
${FILERESULTS} && rm -rf ${WORKDIR}
rm ${TMPCHECK}
