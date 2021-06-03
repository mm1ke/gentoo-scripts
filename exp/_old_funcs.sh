#!/bin/bash

# Filename: _funcs.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 03/06/2021

# Copyright (C) 2021  Michael Mair-Keimberger
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
# these are functions which were used at some point but are not used anymore,
# keep here for later usage.


### NOTUSED ###
# returns the amout of bugs found - 3 digits long
get_bugs_count(){
	local value="${1}"
	local return="$(grep ${value} ${BUGTMPDIR}/full-$(date -I).txt | cut -d' ' -f2 | wc -l)"

	if [ -n "${return}" ]; then
		printf "%03d\n" "${return}"
	else
		echo "000"
	fi
}

### NOTUSED ###
# returns a list of Bug Numbers for a given ebuild
get_bugs(){
	local value="${1}"
	local return="$(grep ${value} ${BUGTMPDIR}/full-$(date -I).txt | cut -d' ' -f2 | tr '\n' ':')"

	[ -n "${return}" ] && echo "${return::-1}"
}

### NOTUSED ###
# return true or false if file exits remotly (or not)
get_file_status(){
	local uri="${1}"

	if $(timeout 15 wget -T 10 --no-check-certificate -q --method=HEAD ${uri}); then
		return 1
	else
		return 0
	fi
}

### NOTUSED ###
count_ebuilds(){
	local epath="${1}"
	local return="$(find ${epath} -mindepth 1 -maxdepth 1 -type f -name "*.ebuild" | wc -l)"

	[ -n "${return}" ] && echo "${return}"
}

### NOTUSED ###
# this function get the age (file creation) of a particular ebuild file
# depends on ${ENABLE_GIT}
# returns the age in days
get_age() {
	local file=${1}
	local date_today="$(date '+%s' -d today)"

	if ${ENABLE_GIT}; then
		fileage="$(expr \( "${date_today}" - \
			"$(date '+%s' -d $(git -C ${REPOTREE} log --format="format:%ci" --name-only --diff-filter=A ${REPOTREE}/${file} \
			| head -1|cut -d' ' -f1) 2>/dev/null )" \) / 86400 2>/dev/null)"
		printf "%05d\n" "${fileage}"
	else
		echo "-----"
	fi
}

### NOTUSED ###
get_age_v2() {
	local filedate="${1}"
	local date_today="$(date '+%s' -d today)"

	if ${ENABLE_GIT}; then
		if [ -n "${filedate}" ]; then
			fileage="$(expr \( "${date_today}" - "$(date '+%s' -d ${filedate})" \) / 86400 2>/dev/null)"
			printf "%05d\n" "${fileage}"
		else
			echo "-----"
		fi
	else
		echo "-----"
	fi
}

### NOTUSED ###
get_age_v3() {
	local filedate="${1}"
	local date_today="$(date '+%s' -d today)"

	if ${ENABLE_GIT}; then
		if [ -n "${filedate}" ]; then
			fileage="$(expr \( "${date_today}" - "${filedate}" \) / 86400 2>/dev/null)"
			printf "%05d\n" "${fileage}"
		else
			echo "-----"
		fi
	else
		echo "-----"
	fi
}

### NOTUSED ###
# list all eapi versions for a given package only showing used EAPIs. the list
# looks like following:
# 7(1):6(2):5(1)
get_eapi_pak(){
	local package=${1}
	local eapi_list=( $(grep EAPI ${package}/*.ebuild 2> /dev/null | cut -d'=' -f2 | cut -d' ' -f1 | grep -Eo '[0-9]' | sort | uniq -c | sed 's/^\s*//'|tr ' ' '_') )

	local x
	local return_string=( )
	for x in ${eapi_list[@]}; do
		local eapi=$(echo ${x}|rev|cut -d'_' -f1)
		local count=$(echo ${x}|cut -d'_' -f1)
		return_string+=( "${eapi}(${count})" )
	done

	IFS=$'\n' return_string=($(sort -r <<<"${return_string[*]}"))

	echo "$(echo ${return_string[@]}|tr ' ' ':')"
}

### NOTUSED ###
# list all eapi's for a given package. the list looks like following:
# EAPI Version:		0 1 2 3 4 5 6 7			(not outputed)
# EAPI Count:			0:0:0:0:0:1:2:0
get_eapi_list(){
	local package=${1}
	local eapi_list=( )
	for eapi in $(seq 0 7); do
		eapi_list+=( $(grep -h EAPI ${package}/*.ebuild |cut -d' ' -f1 | grep ${eapi}| wc -l) )
	done
	echo "$(echo ${eapi_list[@]}|tr ' ' ':')"
}

### NOTUSED ###
# return all eclasses inherited by a ebuild
# the list is generated from the md5-cache, which means it also includes
# eclasses inherited by other eclasses
get_eclasses_real() {
	local md5_file=${1}

	if ${ENABLE_MD5}; then
		local real_eclasses=( $(grep '_eclasses_=' ${md5_file}|cut -c12-|sed 's/\(\t[^\t]*\)\t/\1\n/g'|cut -d$'\t' -f1) )
		echo ${real_eclasses[@]}|tr ' ' ':'
	fi
}

### NOTUSED ###
# list all eclasses used by a given ebuild file
# returns the list as followed:
#  eclass1:eclass2
# NOTE: metadata files also include a INHERIT variable, but for some reason not
# for every ebuild.
get_eclasses_file() {
	local md5_file=${1}
	local real_file=${2}

	if ${ENABLE_MD5}; then
		local real_eclasses=( $(grep '_eclasses_=' ${md5_file}|cut -c12-|sed 's/\(\t[^\t]*\)\t/\1\n/g'|cut -d$'\t' -f1) )
		local file_eclasses=( )
		local eclass_var="$(grep ^inherit ${real_file} |grep -o $\{.*\}|sed 's/${\(.*\)}/\1/')"
		if [ -n "${eclass_var}" ]; then
			eclass_in_var="$(grep -o "${eclass_var}=.*" ${real_file} | tail -n1 | tr -d '"' | cut -d '=' -f2 | cut -d ' ' -f1 )"
			if $(echo ${real_eclasses[@]}|grep -q ${eclass_in_var}); then
				file_eclasses+=( "${eclass_in_var}" )
			fi
		fi
		for ecl in ${real_eclasses[@]}; do
			if $(sed -e :a -e '/\\$/N; s/\\\n//; s/\t/ /; ta' ${real_file} | grep inherit | grep -q " ${ecl} \\| ${ecl}\$"); then
				file_eclasses+=( ${ecl} )
			fi
		done
		echo ${file_eclasses[@]}|tr ' ' ':'
	fi
}
