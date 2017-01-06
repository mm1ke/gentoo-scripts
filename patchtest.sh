#!/bin/bash

# Filename: patchtest
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 01/08/2016

# Copyright (C) 2016  Michael Mair-Keimberger
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
# simple scirpt to find unused patches in the gentoo portage tree

PORTTREE="/mnt/data/gentoo/"
cd ${PORTTREE}

pn='${PN}'
p='${P}'
pf='${PF}'
pv='${PV}'
pvr='${PVR}'

print_main=true

usage() {
	echo "You need an argument"
}

if [ -z "${1}" ]; then
	usage
else
	if [ -d "${PORTTREE}/${1}" ]; then
		cat=${1%%/*}
		pac=${1##*/}
		if [ -z "${pac}" ] || [ "${cat}" == "${pac}" ]; then
			pac="*"
		fi
	elif [ "${1}" == "full" ]; then
		cat="*"
		pac="*"
	else
		echo "${PORTTREE}/${1}: Path not found"
	fi
fi

# python script to extract maintainers
get_main(){
	local ret=`/usr/bin/python3 - $1 <<END
import xml.etree.ElementTree
import sys
pack = str(sys.argv[1])
projxml = "/usr/portage/" + pack + "/metadata.xml"
e = xml.etree.ElementTree.parse(projxml).getroot()
c = ""
for i in e:
	for v in i.iter('maintainer'):
		try:
			a=str(v[1].text)
		except IndexError:
			a="empty"
		b=str(v[0].text)
		c+=str(a)+' ('+str(b)+') // '
print(c)
END`
	echo $ret
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
	echo $ret
}

add_brace_patches(){

	local work_list=("${patch_list[@]}")
	local patch
	local pat_found=()
	local doubles=()
	local count
	
	# expect patches in braces to use name+version or $PN
	# thus the first 2 part (cut with -) ar similar
	#
	# first generate a list of files which fits the rule
	for patch in "${work_list[@]}"; do
		local deli=$(echo ${patch%.patch}|grep -o '-'|wc -w)
		if [ $deli -ge 1 ]; then
			pat_found+=("$(echo $patch|cut -d '-' -f1-$deli)")
		fi
	done
	#echo "patternfound ${pat_found[@]}"
	# create a list of duplicates
	dup_list=()
	for patch in "${pat_found[@]}"; do
		# search for every element in the array
		count=$(echo ${pat_found[@]}|grep -P -o "${patch}(?=\s|$)"|wc -w)
		if [ $count -gt 1 ]; then
			dup_list+=($patch)
		fi
	done
	# remove duplicates from list
	mapfile -t dup_list < <(printf '%s\n' "${dup_list[@]}"|sort -u)

	#echo "dupfound ${dup_list[@]}"
	# add matches to the patch_list
	if [ -n "${dup_list}" ]; then
		for patch in "${dup_list[@]}"; do
			matches=()
			for ffile in $(ls ${fullpath}/files/ |grep $patch); do
				ffile="${ffile%.patch}"
				#echo "filefound: $ffile"
				matches+=("${ffile##*-}")
			done
			# set the maximum permutations number (5-6 works)
			if [ ${#matches[@]} -le 5 ]; then
				matches="${matches[@]}"
				local perm_list=$(get_perm "$matches")
				for search_patch in $perm_list; do
					braces_patch_list+=("$(echo $patch-{$search_patch}.patch)")
				done
			fi
		done
	fi
}


ls -d ${cat}/${pac} |grep -E -v "distfiles|metadata|eclass" | while read -r line; do

	category=${line%%/*}
	package_name=${line##*/}
	fullpath="/${PORTTREE}/${line}"

	# check if the patches folder exist
	if [ -e ${fullpath}/files ]; then
		patch_list=()
		for file in ${fullpath}/files/*; do
			file="${file##*/}"
			if ! [ -d ${file} ]; then
				if  ! [ "${file}" = "README.gentoo" ]; then
					patch_list+=("${file}")
				fi
			fi
		done
		braces_patch_list=()
		add_brace_patches
		
		for patchfile in "${patch_list[@]}"; do
			# check every ebuild
			for ebuild in ${fullpath}/*.ebuild; do
				# get ebuild detail
				ebuild_full=$(basename ${ebuild%.*})
				ebuild_version=$(echo ${ebuild_full/${package_name}}|cut -d'-' -f2)
				ebuild_reversion=$(echo ${ebuild_full/${package_name}}|cut -d'-' -f3)
				# create custom names to check
				custom_name_1=${patchfile/${package_name}/${pn}}
				custom_name_2=${patchfile/${package_name}-${ebuild_version}/${p}}
				custom_name_4=${patchfile/${ebuild_version}/${pv}}
				if [ -n "${ebuild_reversion}" ]; then
					custom_name_3=${patchfile/${package_name}-${ebuild_version}-${ebuild_reversion}/${pf}}
					custom_name_5=${patchfile/${ebuild_version}-${ebuild_reversion}/${pvr}}
				else
					custom_name_5=${patchfile/${ebuild_version}/${pvr}}
				fi
				# check ebuild for the custom names
				if $(sed 's|"||g' ${ebuild} | grep ${patchfile} >/dev/null); then
					found=true
				elif $(sed 's|"||g' ${ebuild} | grep ${custom_name_1} >/dev/null); then
					found=true
				elif $(sed 's|"||g' ${ebuild} | grep ${custom_name_2} >/dev/null); then
					found=true
				elif [ -n "${ebuild_reversion}" ] && $(sed 's|"||g' ${ebuild} | grep ${custom_name_3} >/dev/null); then
					found=true
				elif $(sed 's|"||g' ${ebuild} | grep ${custom_name_5} >/dev/null); then
					found=true
				elif $(sed 's|"||g' ${ebuild} | grep ${custom_name_4} >/dev/null); then
					found=true
				else
					found=false
				fi

				$found && break
			done

			if ! $found; then
				if $print_main; then
					main=$(get_main "${category}/${package_name}")
					echo -e "$line: ${patchfile}\t\t${main}"
				else
					echo -e "$line: ${patchfile}"
				fi
			fi

			found=false
		done
	fi
done

