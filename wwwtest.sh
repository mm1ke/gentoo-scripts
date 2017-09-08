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

MAXD=2
MIND=2


if [ "$(hostname)" = methusalix ]; then
	script_mode=true
	_wwwdir="/var/www/gentoo.levelnine.at/wwwtest/"
	PORTTREE="/usr/portage/"
else
	script_mode=false
	_wwwdir="/home/ai/wwwtest/"
	PORTTREE="/mnt/data/gentoo/"
fi

cd ${PORTTREE}

_date="$(date +%y%m%d)"
_tmp="/tmp/wwwtest-${_date}-${RANDOM}.txt"
_ctmp="/tmp/wwwtest-tmp-${RANDOM}.txt"
_filters=('berlios.de' 'gitorious.org' 'codehaus.org' 'code.google.com' 'fedorahosted.org' 'gna.org')

touch ${_ctmp}
if ${script_mode}; then
	rm -rf ${_wwwdir}/* && mkdir -p ${_wwwdir}/{special,sort-by-{filter,maintainer,package,httpcode}}
	local filename="000-DATA-USAGE"
	echo "HTTP-CODE ; PACKAGE-CATEGORY ; PACKAGE-NAME ; EBUILD ; HOMEPAGE ; MAINTAINER" > ${_wwwdir}/${filename}.txt
	echo "PACKAGE-CATEGORY ; PACKAGE-NAME ; HOMEPAGE ; REAL-HOMEPAGE ; MAINTAINER" > ${_wwwdir}/special/301_slash_https_www_DATA-USAGE.txt
	echo "REAL-HTTP-CODE ; PACKAGE-CATEGORY ; PACKAGE-NAME ; HOMEPAGE ; REAL-HOMEPAGE ; MAINTAINER" > ${_wwwdir}/special/301_redirections_DATA-USAGE.txt
	for _dir in maintainer package httpcode filter; do
		echo "HTTP-CODE ; PACKAGE-CATEGORY ; PACKAGE-NAME ; EBUILD ; HOMEPAGE ; MAINTAINER" > ${_wwwdir}/sort-by-${_dir}/${filename}.txt
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
			$script_mode &&
				echo "${cat}/${pak};${hp};${sitemut};${main}" >> ${_wwwdir}/special/301_slash_https_www.txt ||
				echo "${cat}/${pak};${hp};${sitemut};${main}"
			break
		fi
	done
	if ! ${found}; then
		local correct_site="$(curl -Ls -o /dev/null --silent --max-time 10 --head -w %{url_effective} ${hp})"
		new_code="$(get_code ${correct_site})"
		${script_mode} &&
			echo "${new_code};${cat}/${pak};${hp};${correct_site};${main}" >> ${_wwwdir}/special/301_redirections.txt ||
			echo "${new_code};${cat}/${pak};${hp};${correct_site};${main}"
	fi
}

get_code() {
	local code="$(curl -o /dev/null --silent --max-time 10 --head --write-out '%{http_code}\n' ${1})"
	echo ${code}
}

mode() {
	local msg=${1}
	if ${script_mode}; then
		echo "${msg}" >> ${_tmp}
	else
		echo "${msg}"
	fi
}

main() {
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f2)"
	local package=${line##*/}
	local maintainer="$(get_main_min "${category}/${package}")"
	local md5portage=false

	if [ -z "${maintainer}" ]; then
			maintainer="maintainer-needed@gentoo.org:"
	fi
	if [ -e "${PORTTREE}/metadata/md5-cache" ]; then
		md5portage=true
	fi


	for eb in ${PORTTREE}/$line/*.ebuild; do
		ebuild=$(basename ${eb%.*})
		
		if ${md5portage}; then 
			_hp="$(grep ^HOMEPAGE= ${PORTTREE}/metadata/md5-cache/${category}/${ebuild})"
			_hp="${_hp:9}"
		else
			_hp="$(grep ^HOMEPAGE= ${eb}|cut -d'"' -f2)"
		fi

		if [ -n "${_hp}" ]; then
			for i in ${_hp}; do
				_check_tmp="$(grep -P "(^|\s)\K${i}(?=\s|$)" ${_ctmp})"
		
				if echo ${i}|grep ^ftp >/dev/null;then
					mode "FTP;${category}/${package};${ebuild};${i};${maintainer}"
				elif echo ${i}|grep '${' >/dev/null; then
					mode "VAR;${category}/${package};${ebuild};${i};${maintainer}"
				elif [ -n "${_check_tmp}" ]; then
					# don't check again
					mode "${_check_tmp:0:3};${category}/${package};${ebuild};${_check_tmp:4};${maintainer}"
				else
					# get http status code
					_code="$(get_code ${i})"
					mode "${_code};${category}/${package};${ebuild};${i};${maintainer}"
					echo "${_code} ${i}" >> ${_ctmp}

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

find ./${level} -mindepth $MIND -maxdepth $MAXD \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type d -print | while read -r line; do
	main ${line}
done


if ${script_mode}; then
	# sort after http codes
	for i in $(cat ${_tmp}|cut -d';' -f1|sort|uniq); do
		grep "^${i}" ${_tmp} > ${_wwwdir}/sort-by-httpcode/${i}.txt
	done
	
	# copy full log
	cp ${_tmp} ${_wwwdir}/full.txt
	# copy full log, ignoring "good" codes
	grep -v -E "^VAR|^FTP|^200|^302|^307|^400|^503" ${_tmp} > ${_ctmp}
	cp ${_ctmp} ${_wwwdir}/full-filtered.txt
	
	# sort by packages, ignoring "good" codes
	f_packages="$(cat ${_ctmp}| cut -d ';' -f2 |sort|uniq)"
	for i in ${f_packages}; do
		f_cat="$(echo $i|cut -d'/' -f1)"
		f_pak="$(echo $i|cut -d'/' -f2)"
		mkdir -p ${_wwwdir}/sort-by-package/${f_cat}
		grep "${i}" ${_ctmp} > ${_wwwdir}/sort-by-package/${f_cat}/${f_pak}.txt
	done
	
	# sort by maintainer, ignoring "good" codes
	for a in $(cat ${_ctmp} |cut -d';' -f5|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
		grep "${a}" ${_ctmp} > ${_wwwdir}/sort-by-maintainer/"$(echo ${a}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
	done

	# special filters
	for site in ${_filters[@]}; do
		grep ${site} ${_wwwdir}/full.txt > ${_wwwdir}/sort-by-filter/${site}.txt
	done

	# remove tmp data
	rm ${_tmp}
fi

rm ${_ctmp}
