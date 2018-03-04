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
SCRIPT_NAME="wwwtest"
SCRIPT_SHORT="WWT"
SITEDIR="${HOME}/${SCRIPT_NAME}/"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"
PORTTREE="/usr/portage/"
TMPFILE="/tmp/${SCRIPT_NAME}-$(date +%y%m%d)-${RANDOM}.txt"
TMPCHECK="/tmp/${SCRIPT_NAME}-tmp-${RANDOM}.txt"
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
	SITEDIR="/var/www/gentooqa.levelnine.at/results/"
fi

cd ${PORTTREE}
depth_set ${1}

# touch file first, otherwise the _checktmp could fail because of
# the missing file
touch ${TMPCHECK}
#mkdir -p ${WORKDIR}/{special,sort-by-{filter,maintainer,package,httpcode}}
#mkdir -p ${WORKDIR}/special/{unsync-homepages,301_redirections,301_slash_https_www}
mkdir -p ${WORKDIR}/${SCRIPT_SHORT}-IMP-301_slash_https_www
mkdir -p ${WORKDIR}/${SCRIPT_SHORT}-IMP-301_redirections
mkdir -p ${WORKDIR}/${SCRIPT_SHORT}-IMP-redirection_missing_slash_www
mkdir -p ${WORKDIR}/${SCRIPT_SHORT}-IMP-redirection_http_to_https

301check() {
	local hp=${1}
	local cat=${2}
	local pak=${3}
	local main=${4}
	local found=false
	local lastchar="${hp: -1}"

	_sitemuts=("${hp/http:\/\//https:\/\/}" \
		"${hp/http:\/\//https:\/\/www.}")

	if ! [ "${lastchar}" = "/" ]; then
		_sitemuts+=("${hp/http:\/\//https:\/\/}/" \
			"${hp/http:\/\//https:\/\/www.}/")
	fi

	_sitemuts_v2=("${hp/https:\/\//https:\/\/www.}" \
		"${hp/http:\/\//http:\/\/www.}")

	if ! [ "${lastchar}" = "/" ]; then
		_sitemuts_v2+=("${hp}/" \
		"${hp/https:\/\//https:\/\/www.}/" \
		"${hp/http:\/\//http:\/\/www.}/")
	fi

	for sitemut in ${_sitemuts[@]}; do
		local _code="$(get_code ${sitemut})"
		if [ ${_code} = 200 ]; then
			found=true
			if ${SCRIPT_MODE}; then
				echo "${cat}/${pak}${DL}${hp}${DL}${sitemut}${DL}${main}" >> ${WORKDIR}/${SCRIPT_SHORT}-IMP-301_slash_https_www/full.txt
				echo "${cat}/${pak}${DL}${hp}${DL}${sitemut}${DL}${main}" >> ${WORKDIR}/${SCRIPT_SHORT}-IMP-redirection_http_to_https/full.txt
			else
				echo "${cat}/${pak}${DL}${hp}${DL}${sitemut}${DL}${main}"
			fi
			break
		fi
	done
	if ! ${found}; then
		for sitemut in ${_sitemuts_v2[@]}; do
			local _code="$(get_code ${sitemut})"
			if [ ${_code} = 200 ]; then
				found=true
				if ${SCRIPT_MODE}; then
					echo "${cat}/${pak}${DL}${hp}${DL}${sitemut}${DL}${main}" >> ${WORKDIR}/${SCRIPT_SHORT}-IMP-301_slash_https_www/full.txt
					echo "${cat}/${pak}${DL}${hp}${DL}${sitemut}${DL}${main}" >> ${WORKDIR}/${SCRIPT_SHORT}-IMP-redirection_missing_slash_www/full.txt
				else
					echo "${cat}/${pak}${DL}${hp}${DL}${sitemut}${DL}${main}"
				fi
				break
			fi
		done
	fi

	if ! ${found}; then
		local correct_site="$(curl -Ls -o /dev/null --silent --max-time 10 --head -w %{url_effective} ${hp})"
		new_code="$(get_code ${correct_site})"
		if ${SCRIPT_MODE}; then
			echo "${new_code}${DL}${cat}/${pak}${DL}${hp}${DL}${correct_site}${DL}${main}" >> ${WORKDIR}/${SCRIPT_SHORT}-IMP-301_redirections/full.txt
		else
			echo "${new_code}${DL}${cat}/${pak}${DL}${hp}${DL}${correct_site}${DL}${main}"
		fi
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
				local _checktmp="$(grep -P "(^|\s)\K${i}(?=\s|$)" ${TMPCHECK}|sort -u)"

				if echo ${i}|grep ^ftp >/dev/null;then
					mode "FTP${DL}${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}${openbugs}"
				elif echo ${i}|grep '${' >/dev/null; then
					mode "VAR${DL}${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}${openbugs}"
				elif [ -n "${_checktmp}" ]; then
					# don't check again
					mode "${_checktmp:0:3}${DL}${category}/${package}${DL}${ebuild}${DL}${_checktmp:4}${DL}${maintainer}${openbugs}"
				else
					# get http status code
					_code="$(get_code ${i})"
					mode "${_code}${DL}${category}/${package}${DL}${ebuild}${DL}${i}${DL}${maintainer}${openbugs}"
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
export PORTTREE TMPCHECK TMPFILE SCRIPT_MODE WORKDIR DL SCRIPT_SHORT

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
	mkdir -p ${WORKDIR}/${SCRIPT_SHORT}-BUG-www_status_code/sort-by-httpcode
	# sort after http codes
	for i in $(cat ${TMPFILE}|cut -d "${DL}" -f1|sort|uniq); do
		grep "^${i}" ${TMPFILE} > ${WORKDIR}/${SCRIPT_SHORT}-BUG-www_status_code/sort-by-httpcode/${i}.txt
	done

	# copy full log
	cp ${TMPFILE} ${WORKDIR}/${SCRIPT_SHORT}-BUG-www_status_code/full-unfiltered.txt
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
	cp ${TMPFILE} ${WORKDIR}/${SCRIPT_SHORT}-BUG-www_status_code/full.txt


	# special filters
	_filters=('berlios.de' 'gitorious.org' 'codehaus.org' 'code.google.com' 'fedorahosted.org' 'gna.org' 'freecode.com' 'freshmeat.net')
	for site in ${_filters[@]}; do
		foldername="${SCRIPT_SHORT}-BUG-www_upstream_shutdown_${site}"
		newpath="${WORKDIR}/${foldername}"

		mkdir -p ${WORKDIR}/${foldername}
		grep ${site} ${WORKDIR}/${SCRIPT_SHORT}-BUG-www_status_code/full-unfiltered.txt > ${WORKDIR}/${foldername}/full.txt

		gen_sort_main ${newpath}/full.txt 5 ${newpath}/ ${DL}
		gen_sort_pak ${newpath}/full.txt 2 ${newpath}/ ${DL}

		rm -rf ${SITEDIR}/checks/${foldername}
		cp -r ${newpath} ${SITEDIR}/checks/
	done


	foldername="${SCRIPT_SHORT}-BUG-www_upstream_shutdown"
	newpath="${WORKDIR}/${foldername}"
	for site in ${_filters[@]}; do
		mkdir -p ${WORKDIR}/${foldername}
		grep ${site} ${WORKDIR}/${SCRIPT_SHORT}-BUG-www_status_code/full-unfiltered.txt >> ${WORKDIR}/${foldername}/full.txt

	done
	gen_sort_main ${newpath}/full.txt 5 ${newpath}/ ${DL}
	gen_sort_pak ${newpath}/full.txt 2 ${newpath}/ ${DL}
	rm -rf ${SITEDIR}/checks/${foldername}
	cp -r ${newpath} ${SITEDIR}/checks/


	foldername="${SCRIPT_SHORT}-IMP-unsync_homepages"
	newpath="${WORKDIR}/${foldername}"
	# find different homepages in same packages
	for i in $(cat ${WORKDIR}/${SCRIPT_SHORT}-BUG-www_status_code/full-unfiltered.txt | cut -d'|' -f2|sort -u); do
		hp_lines="$(grep "HOMEPAGE=" ${PORTTREE}/metadata/md5-cache/${i}-[0-9]* | cut -d'=' -f2|sort -u|wc -l)"
		if [ "${hp_lines}" -gt 1 ]; then
			mkdir -p ${WORKDIR}/${foldername}/sort-by-package/${i%%/*}
			grep "|${i}|" ${WORKDIR}/${SCRIPT_SHORT}-BUG-www_status_code/full-unfiltered.txt > ${newpath}/sort-by-package/${i}.txt
			grep "|${i}|" ${WORKDIR}/${SCRIPT_SHORT}-BUG-www_status_code/full-unfiltered.txt |head -n1| cut -d'|' -f2,5  >> ${newpath}/full.txt
		fi
	done
	gen_sort_main ${newpath}/full.txt 2 ${newpath} ${DL}
	rm -rf ${SITEDIR}/checks/${foldername}
	cp -r ${newpath} ${SITEDIR}/checks/


	foldername="${SCRIPT_SHORT}-IMP-redirection_http_to_https"
	newpath="${WORKDIR}/${foldername}"
	gen_sort_pak ${newpath}/full.txt 1 ${newpath} ${DL}
	gen_sort_main ${newpath}/full.txt 4 ${newpath} ${DL}
	rm -rf ${SITEDIR}/checks/${foldername}
	cp -r ${newpath} ${SITEDIR}/checks/

	foldername="${SCRIPT_SHORT}-IMP-redirection_missing_slash_www"
	newpath="${WORKDIR}/${foldername}"
	gen_sort_pak ${newpath}/full.txt 1 ${newpath} ${DL}
	gen_sort_main ${newpath}/full.txt 4 ${newpath} ${DL}
	rm -rf ${SITEDIR}/checks/${foldername}
	cp -r ${newpath} ${SITEDIR}/checks/

	foldername="${SCRIPT_SHORT}-IMP-301_slash_https_www"
	newpath="${WORKDIR}/${foldername}"
	gen_sort_pak ${newpath}/full.txt 1 ${newpath} ${DL}
	gen_sort_main ${newpath}/full.txt 4 ${newpath} ${DL}
	rm -rf ${SITEDIR}/checks/${foldername}
	cp -r ${newpath} ${SITEDIR}/checks/

	foldername="${SCRIPT_SHORT}-IMP-301_redirections"
	newpath="${WORKDIR}/${foldername}"
	gen_sort_pak ${newpath}/full.txt 2 ${newpath} ${DL}
	gen_sort_main ${newpath}/full.txt 5 ${newpath} ${DL}
	rm -rf ${SITEDIR}/checks/${foldername}
	cp -r ${newpath} ${SITEDIR}/checks/

	foldername="${SCRIPT_SHORT}-BUG-www_status_code"
	newpath="${WORKDIR}/${foldername}"
	gen_sort_pak ${newpath}/full.txt 2 ${newpath} ${DL}
	gen_sort_main ${newpath}/full.txt 5 ${newpath} ${DL}
	rm -rf ${SITEDIR}/checks/${foldername}
	cp -r ${newpath} ${SITEDIR}/checks/

	rm -rf ${WORKDIR}
fi
rm ${TMPCHECK}
