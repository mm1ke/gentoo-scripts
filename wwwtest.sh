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

SCRIPT_MODE=false
WWWDIR="${HOME}/wwwtest/"
WORKDIR="/tmp/wwwtest-${RANDOM}"
PORTTREE="/usr/portage/"
TMPFILE="/tmp/wwwtest-$(date +%y%m%d)-${RANDOM}.txt"
TMPCHECK="/tmp/wwwtest-tmp-${RANDOM}.txt"
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
	WWWDIR="/var/www/gentoo.levelnine.at/wwwtest/"
fi

cd ${PORTTREE}
depth_set ${1}

# touch file first, otherwise the _checktmp could fail because of
# the missing file
touch ${TMPCHECK}
mkdir -p ${WORKDIR}/{special,sort-by-{filter,maintainer,package,httpcode}}
mkdir -p ${WORKDIR}/special/{unsync-homepages,301_redirections,301_slash_https_www}

301check() {
	local hp=${1}
	local cat=${2}
	local pak=${3}
	local main=${4}
	local found=false
	local lastchar="${hp: -1}"

	_sitemuts=("${hp/http:\/\//https:\/\/}" \
		"${hp/http:\/\//https:\/\/www.}" \
		"${hp/https:\/\//https:\/\/www.}" \
		"${hp/http:\/\//http:\/\/www.}")
	if ! [ "${lastchar}" = "/" ]; then
		_sitemuts+=("${hp}/" \
		"${hp/http:\/\//https:\/\/}/" \
		"${hp/http:\/\//https:\/\/www.}/" \
		"${hp/https:\/\//https:\/\/www.}/" \
		"${hp/http:\/\//http:\/\/www.}/")
	fi

	for sitemut in ${_sitemuts[@]}; do
		local _code="$(get_code ${sitemut})"
		if [ ${_code} = 200 ]; then
			found=true
			${SCRIPT_MODE} &&
				echo "${cat}/${pak}${DL}${hp}${DL}${sitemut}${DL}${main}" >> ${WORKDIR}/special/301_slash_https_www/301_slash_https_www.txt ||
				echo "${cat}/${pak}${DL}${hp}${DL}${sitemut}${DL}${main}"
			break
		fi
	done
	if ! ${found}; then
		local correct_site="$(curl -Ls -o /dev/null --silent --max-time 10 --head -w %{url_effective} ${hp})"
		new_code="$(get_code ${correct_site})"
		${SCRIPT_MODE} &&
			echo "${new_code}${DL}${cat}/${pak}${DL}${hp}${DL}${correct_site}${DL}${main}" >> ${WORKDIR}/special/301_redirections/301_redirections.txt ||
			echo "${new_code}${DL}${cat}/${pak}${DL}${hp}${DL}${correct_site}${DL}${main}"
	fi
}

get_code() {
	local code="$(curl -o /dev/null --silent --max-time 10 --head --write-out '%{http_code}\n' ${1})"
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
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package=${full_package##*/}
	local maintainer="$(get_main_min "${category}/${package}")"
	local md5portage=false

	if [ -z "${maintainer}" ]; then
			maintainer="maintainer-needed@gentoo.org:"
	fi
	if [ -e "${PORTTREE}/metadata/md5-cache" ]; then
		md5portage=true
	fi


	for eb in ${PORTTREE}/${full_package}/*.ebuild; do
		ebuild=$(basename ${eb%.*})

		if ${md5portage}; then
			_hp="$(grep ^HOMEPAGE= ${PORTTREE}/metadata/md5-cache/${category}/${ebuild})"
			_hp="${_hp:9}"
		else
			_hp="$(grep ^HOMEPAGE= ${eb}|cut -d'"' -f2)"
		fi

		if [ -n "${_hp}" ]; then
			for i in ${_hp}; do
				local _checktmp="$(grep -P "(^|\s)\K${i}(?=\s|$)" ${TMPCHECK}|sort -u)"

				if echo ${i}|grep ^ftp >/dev/null;then
					mode "FTP${DL}${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}"
				elif echo ${i}|grep '${' >/dev/null; then
					mode "VAR${DL}${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}"
				elif [ -n "${_checktmp}" ]; then
					# don't check again
					mode "${_checktmp:0:3}${DL}${category}/${package}${DL}${ebuild}${DL}${_checktmp:4}${DL}${maintainer}"
				else
					# get http status code
					_code="$(get_code ${i})"
					mode "${_code}${DL}${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}"
					echo "${_code} ${i}" >> ${TMPCHECK}

					case ${_code} in
						301)
							301check "${i}" "${category}" "${package}" "${maintainer}"
							;;
						esac

				fi
			done
		fi
	done
}

# for parallel execution
export -f main get_code 301check
export PORTTREE TMPCHECK TMPFILE SCRIPT_MODE WORKDIR DL

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
	# sort after http codes
	for i in $(cat ${TMPFILE}|cut -d "${DL}" -f1|sort|uniq); do
		grep "^${i}" ${TMPFILE} > ${WORKDIR}/sort-by-httpcode/${i}.txt
	done

	# copy full log
	cp ${TMPFILE} ${WORKDIR}/full.txt
	# copy full log, ignoring "good" codes
	sed -i "/^VAR/d; \
		/^FTP/d; \
		/^200/d; \
		/^301/d; \
		/^302/d; \
		/^307/d; \
		/^400/d; \
		/^503/d; \
		" ${TMPFILE}
	cp ${TMPFILE} ${WORKDIR}/full-filtered.txt

	# special filters
	_filters=('berlios.de' 'gitorious.org' 'codehaus.org' 'code.google.com' 'fedorahosted.org' 'gna.org' 'freecode.com' 'freshmeat.net')
	for site in ${_filters[@]}; do
		mkdir -p ${WORKDIR}/sort-by-filter/${site}
		grep ${site} ${WORKDIR}/full.txt > ${WORKDIR}/sort-by-filter/${site}/${site}.txt
		gen_sort_main ${WORKDIR}/sort-by-filter/${site}/${site}.txt 5 ${WORKDIR}/sort-by-filter/${site}/ ${DL}
		gen_sort_pak ${WORKDIR}/sort-by-filter/${site}/${site}.txt 2 ${WORKDIR}/sort-by-filter/${site}/ ${DL}
	done

	# find different homepages in same packages
	for i in $(cat ${WORKDIR}/full.txt | cut -d'|' -f2|sort -u); do
		hp_lines="$(grep "HOMEPAGE=" ${PORTTREE}/metadata/md5-cache/${i}-[0-9]* | cut -d'=' -f2|sort -u|wc -l)"
		if [ "${hp_lines}" -gt 1 ]; then
			mkdir -p ${WORKDIR}/special/unsync-homepages/sort-by-package/${i%%/*}
			grep "|${i}|" ${WORKDIR}/full.txt > ${WORKDIR}/special/unsync-homepages/sort-by-package/${i}.txt
			grep "|${i}|" ${WORKDIR}/full.txt |head -n1| cut -d'|' -f2,5  >> ${WORKDIR}/special/unsync-homepages/full.txt
		fi
	done
	# sort unsync homepages by maintainer
	gen_sort_main ${WORKDIR}/special/unsync-homepages/full.txt 2 ${WORKDIR}/special/unsync-homepages/ ${DL}

	# create sortings for 301_redirections
	gen_sort_pak ${WORKDIR}/special/301_redirections/301_redirections.txt 2 ${WORKDIR}/special/301_redirections/ ${DL}
	gen_sort_main ${WORKDIR}/special/301_redirections/301_redirections.txt 5 ${WORKDIR}/special/301_redirections/ ${DL}

	# create sortings for 301_slash_https_www
	gen_sort_pak ${WORKDIR}/special/301_slash_https_www/301_slash_https_www.txt 1 ${WORKDIR}/special/301_slash_https_www/ ${DL}
	gen_sort_main ${WORKDIR}/special/301_slash_https_www/301_slash_https_www.txt 4 ${WORKDIR}/special/301_slash_https_www/ ${DL}

	# sort by packages, ignoring "good" codes
	gen_sort_pak ${WORKDIR}/full-filtered.txt 2 ${WORKDIR} ${DL}

	# sort by maintainer, ignoring "good" codes
	gen_sort_main ${WORKDIR}/full-filtered.txt 5 ${WORKDIR} ${DL}

	# remove tmpfile
	rm ${TMPFILE}
	script_mode_copy
fi
rm ${TMPCHECK}
