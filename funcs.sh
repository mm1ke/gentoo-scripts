#!/bin/bash

# Filename: funcs.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 26/11/2017

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
# this file only provides functions for different scripts

# function which sorts a list by it's maintainer
gen_sort_main(){
	local workfile="${1}"
	local main_loc="${2}"
	local dest_dir="${3}"
	local DL="${4}"

	if [ -e ${1} ]; then
		mkdir -p ${dest_dir}/sort-by-maintainer
		for a in $(cat ${workfile} |cut -d "${DL}" -f${main_loc}|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
			grep "${a}" ${workfile} > ${dest_dir}/sort-by-maintainer/"$(echo ${a}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
		done
	fi
}

# function which sorts a list by it's package
gen_sort_pak() {
	local workfile="${1}"
	local pak_loc="${2}"
	local dest_dir="${3}"
	local DL="${4}"

	if [ -e ${1} ]; then
		local f_packages="$(cat ${workfile}| cut -d "${DL}" -f${pak_loc} |sort|uniq)"
		for i in ${f_packages}; do
			f_cat="$(echo ${i}|cut -d'/' -f1)"
			f_pak="$(echo ${i}|cut -d'/' -f2)"
			mkdir -p ${dest_dir}/sort-by-package/${f_cat}
			grep "${i}" ${workfile} > ${dest_dir}/sort-by-package/${f_cat}/${f_pak}.txt
		done
	fi
}

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

depth_set() {
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
}

script_mode_copy() {
	[ -n "${WWWDIR}" ] && rm -rf ${WWWDIR}/*
	cp -r ${WORKDIR}/* ${WWWDIR}/
	rm -rf ${WORKDIR}
}

get_main_min(){
	local ret=`/usr/bin/python3 - "${1}" <<END
import xml.etree.ElementTree
import sys
pack = str(sys.argv[1])
projxml = "/usr/portage/" + pack + "/metadata.xml"
e = xml.etree.ElementTree.parse(projxml).getroot()
c = ""
for x in e.iterfind("./maintainer/email"):
	c+=(x.text+':')
print(c)
END`
	echo ${ret// /_}
}

# python script to get permutations
get_perm(){
	local ret=`/usr/bin/python3 - "${1}" <<END
import itertools
import sys
list=sys.argv[1].split(' ')
for perm in itertools.permutations(list):
	string= ','.join(perm)
	print(string)
END`
	echo ${ret// /_}
}

export -f get_main_min get_perm
