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
SITEDIR="${HOME}/wwwtest/"
PORTTREE="/usr/portage/"
TMPFILE="/tmp/wwwtest-$(date +%y%m%d)-${RANDOM}.txt"
TMPCHECK="/tmp/wwwtest-tmp-${RANDOM}.txt"
DL='|'

if [ "$(hostname)" = methusalix ]; then
	SCRIPT_MODE=true
	SITEDIR="/var/www/gentoo.levelnine.at/wwwtest/"
fi

cd ${PORTTREE}

# touch file first, otherwise the _checktmp could fail because of
# the missing file
touch ${TMPCHECK}

# TODO:
# Remove code below and point to a website (github) for the descripton
if ${SCRIPT_MODE}; then
	rm -rf ${SITEDIR}/* && mkdir -p ${SITEDIR}/{special,sort-by-{filter,maintainer,package,httpcode}}
	filename="000-DATA-USAGE"
	echo "HTTP-CODE ; PACKAGE-CATEGORY ; PACKAGE-NAME ; EBUILD ; HOMEPAGE ; MAINTAINER" > ${SITEDIR}/${filename}.txt
	echo "PACKAGE-CATEGORY ; PACKAGE-NAME ; HOMEPAGE ; REAL-HOMEPAGE ; MAINTAINER" > ${SITEDIR}/special/301_slash_https_www_DATA-USAGE.txt
	echo "REAL-HTTP-CODE ; PACKAGE-CATEGORY ; PACKAGE-NAME ; HOMEPAGE ; REAL-HOMEPAGE ; MAINTAINER" > ${SITEDIR}/special/301_redirections_DATA-USAGE.txt
	for _dir in maintainer package httpcode filter; do
		echo "HTTP-CODE ; PACKAGE-CATEGORY ; PACKAGE-NAME ; EBUILD ; HOMEPAGE ; MAINTAINER" > ${SITEDIR}/sort-by-${_dir}/${filename}.txt
	done
fi

usage() {
	echo "You need at least one argument:"
	echo
	echo "${0} full"
	echo -e "\tCheck against the full tree"
	echo "${0} app-admin"
	echo -e "\tCheck against the category app-admin"
	echo "${0} app-admin/diradm"
	echo -e "\tCheck against the package app-admin/diradm"
}

if [ -z "${1}" ]; then
	usage
	exit 1
else
	if [ -d "${PORTTREE}/${1}" ]; then
		level="${1}"
		MAXD=0
		MIND=0
		if [ -z "${1##*/}" ] || [ "${1%%/*}" == "${1##*/}" ]; then
			MAXD=1
			MIND=1
		fi
	elif [ "${1}" == "full" ]; then
		level=""
		MAXD=2
		MIND=2
	else
		echo "${PORTTREE}/${1}: Path not found"
	fi
fi

get_main_min(){
	local ret=`/usr/bin/python3 - $1 <<END
import xml.etree.ElementTree
import sys
pack = str(sys.argv[1])
projxml = "/usr/portage/" + pack + "/metadata.xml"
e = xml.etree.ElementTree.parse(projxml).getroot()
c = ""
for i in e:
	for v in i.iter('maintainer'):
		b=str(v[0].text)
		c+=str(b)+':'
print(c)
END`
	echo $ret
}

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
			$SCRIPT_MODE &&
				echo "${cat}/${pak}${DL}${hp}${DL}${sitemut}${DL}${main}" >> ${SITEDIR}/special/301_slash_https_www.txt ||
				echo "${cat}/${pak}${DL}${hp}${DL}${sitemut}${DL}${main}"
			break
		fi
	done
	if ! ${found}; then
		local correct_site="$(curl -Ls -o /dev/null --silent --max-time 10 --head -w %{url_effective} ${hp})"
		new_code="$(get_code ${correct_site})"
		${SCRIPT_MODE} &&
			echo "${new_code}${DL}${cat}/${pak}${DL}${hp}${DL}${correct_site}${DL}${main}" >> ${SITEDIR}/special/301_redirections.txt ||
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
				local _checktmp="$(grep -P "(^|\s)\K${i}(?=\s|$)" ${TMPCHECK})"

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
export -f main get_main_min get_code 301check
export PORTTREE TMPCHECK TMPFILE SCRIPT_MODE SITEDIR

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
		grep "^${i}" ${TMPFILE} > ${SITEDIR}/sort-by-httpcode/${i}.txt
	done

	# copy full log
	cp ${TMPFILE} ${SITEDIR}/full.txt

	# special filters
	_filters=('berlios.de' 'gitorious.org' 'codehaus.org' 'code.google.com' 'fedorahosted.org' 'gna.org')
	for site in ${_filters[@]}; do
		grep ${site} ${SITEDIR}/full.txt > ${SITEDIR}/sort-by-filter/${site}.txt
	done

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
	cp ${TMPFILE} ${SITEDIR}/full-filtered.txt

	# sort by packages, ignoring "good" codes
	f_packages="$(cat ${TMPFILE}| cut -d "${DL}" -f2 |sort|uniq)"
	for i in ${f_packages}; do
		f_cat="$(echo $i|cut -d'/' -f1)"
		f_pak="$(echo $i|cut -d'/' -f2)"
		mkdir -p ${SITEDIR}/sort-by-package/${f_cat}
		grep "${i}" ${TMPFILE} > ${SITEDIR}/sort-by-package/${f_cat}/${f_pak}.txt
	done

	# sort by maintainer, ignoring "good" codes
	for a in $(cat ${TMPFILE} |cut -d "${DL}" -f5|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
		grep "${a}" ${TMPFILE} > ${SITEDIR}/sort-by-maintainer/"$(echo ${a}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
	done
fi
# remove tmpfile
rm ${TMPFILE}
