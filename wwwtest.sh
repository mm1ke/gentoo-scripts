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
	_wwwdir="/var/www/gentoo.levelnine.at/wwwtest/"
	PORTTREE="/usr/portage/"
else
	_wwwdir="/home/ai/wwwtest/"
	PORTTREE="/mnt/data/gentoo/"
	_test=true
	_t=0
fi

cd ${PORTTREE}

_date="$(date +%y%m%d)"
_tmp="/tmp/wwwtest-${_date}-${RANDOM}.txt"
_ctmp="/tmp/wwwtest-tmp-${RANDOM}.txt"

touch ${_ctmp}

usage() {
	echo "You need an argument"
}

if [ -z "${1}" ]; then
	usage
	exit 1
else
	if [ -d "${PORTTREE}/${1}" ]; then
		level="${1}"
		MAXD=0
		MIND=0
		_cat=${1%%/*}
		_pac=${1##*/}
		if [ -z "${_pac}" ] || [ "${_cat}" == "${_pac}" ]; then
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

main() {

	local package=${1}
	local category="$(echo ${package}|cut -d'/' -f2)"
	local package_name=${line##*/}
	local maintainer="$(get_main_min "${category}/${package_name}")"

	for eb in $line/*.ebuild; do
		_package=$(basename ${eb%.*})
		_hp="$(cat $eb|grep ^HOMEPAGE=|cut -d'"' -f2)"
		if [ -n "${_hp}" ]; then
			for i in ${_hp}; do
				_check_tmp="$(grep -P "(^|\s)\K${i}(?=\s|$)" ${_ctmp})"
		
				if echo $i|grep ^ftp >/dev/null;then
					echo "FTP ${category}/${package_name} ${category}/${_package} ${i} ${maintainer}" >> ${_tmp}
				elif echo $i|grep '${' >/dev/null; then
					echo "VAR ${category}/${package_name} ${category}/${_package} ${i} ${maintainer}" >> ${_tmp}
				elif [ -n "${_check_tmp}" ]; then
					# don't check again
					echo "${_check_tmp:0:3} ${category}/${package_name} ${category}/${_package} ${_check_tmp:4} ${maintainer}" >> ${_tmp}
				else
					_code="$(curl -o /dev/null --silent --max-time 10 --head --write-out '%{http_code}\n' ${i})"
					echo "${_code} ${category}/${package_name} ${category}/${_package} ${i} ${main}" >> ${_tmp}
					_t=$[$_t+1]
		
					echo "$_code $i" >> ${_ctmp}
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

# remove old data
rm -rf ${_wwwdir}/*

# sort after http codes
for i in $(cat ${_tmp}|cut -d' ' -f1|sort|uniq); do
	mkdir -p ${_wwwdir}/sort-by-httpcode/
	grep ^${i} ${_tmp} > ${_wwwdir}/sort-by-httpcode/${i}.txt
done

# copy full log
cp ${_tmp} ${_wwwdir}/full.txt

# copy full log, ignoring "good" codes
grep -v -E "^VAR|^FTP|^200|^302|^307|^400|^503" ${_tmp} > ${_ctmp}
cp ${_ctmp} ${_wwwdir}/full-filtered.txt

# sort by packages, ignoring "good" codes
f_packages="$(cat ${_ctmp}| cut -d ' ' -f2|sort|uniq)"
for i in $f_packages; do
	f_cat="$(echo $i|cut -d'/' -f1)"
	f_pak="$(echo $i|cut -d'/' -f2)"
	mkdir -p ${_wwwdir}/sort-by-package/${f_cat}
	grep $i ${_ctmp} > ${_wwwdir}/sort-by-package/${f_cat}/${f_pak}.txt
done

#sort by maintainer, ignoring "good" codes
for a in $(cat ${_ctmp} |cut -d' ' -f5|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
	mkdir -p ${_wwwdir}/sort-by-maintainer/
	grep "${a}" ${_ctmp} > ${_wwwdir}/sort-by-maintainer/"$(echo ${a}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
done

rm ${_tmp}
rm ${_ctmp}
