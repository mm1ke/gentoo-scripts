#!/bin/bash

# Filename: patchtest
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 01/08/2016

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
# simple scirpt to find unused patches in the gentoo portage tree

DEBUG=false

script_mode_tmp="/tmp/patchtest-$(date +%y%m%d).txt"
script_mode_tmp_full="/tmp/patchtest-$(date +%y%m%d)-full.txt"
MAXD=2
MIND=2

if [ "$(hostname)" = methusalix ]; then
	PORTTREE="/usr/portage/"
	script_mode=true
	script_mode_dir="/var/www/gentoo.levelnine.at/patchtest/"
else
	PORTTREE="/mnt/data/gentoo/"
	script_mode=false
	script_mode_dir="/home/ai/patchtest/"
fi

cd ${PORTTREE}

# print maintainer info
print_main=true

# for xargs...
#export -f main

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

if ! $script_mode; then
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
fi

# python script to extract maintainers
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

find_braces_candidates(){

	local work_list=("${unused_patches[@]}")
	local patch
	local pat_found=()
	local count

	#echo "worklist: ${work_list[@]}"
	# expect patches in braces to use name+version or $PN
	# thus the first 2 part (cut with -) ar similar
	#
	# first generate a list of files which fits the rule
	for patch in "${work_list[@]}"; do
		local deli=$(echo ${patch%.patch}|grep -o '-'|wc -w)
		if [ $deli -ge 2 ]; then
			pat_found+=("$(echo $patch|cut -d '-' -f1-$deli)")
		fi
	done
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
	#echo "duplist ${dup_list[@]}"
}

braces_patches() {
	local patch=$1
	# add matches to the patch_list
	local matches=()
	filess=()
	braces_patch_list=()

	for ffile in $(ls ${fullpath}/files/ |grep $patch); do
		filess+=($ffile)
		ffile="${ffile%.patch}"
		matches+=("${ffile##*-}")
	done
	#echo "files: ${filess[@]}"
	#echo "matches: ${matches[@]}"
	# set the maximum permutations number (5-6 works)
	if [ ${#matches[@]} -le 5 ]; then
		matches="${matches[@]}"
		local perm_list=$(get_perm "$matches")
		for search_patch in $perm_list; do
			braces_patch_list+=("$(echo $patch-{$search_patch}.patch)")
		done
	fi
}

check_ebuild(){
	local patchfile=$1
	local found=false
	local pn='${PN}'
	local p='${P}'
	local pf='${PF}'
	local pv='${PV}'
	local pvr='${PVR}'
	local slot='${SLOT}'


	$DEBUG && >&2 echo
	$DEBUG && >&2 echo "*DEBUG: pachfile to check: $patchfile"

	for ebuild in ${fullpath}/*.ebuild; do
		$DEBUG && >&2 echo "**DEBUG: Check ebuild: $ebuild"

		# get ebuild detail
		local ebuild_full=$(basename ${ebuild%.*})
		local ebuild_version=$(echo ${ebuild_full/${package_name}}|cut -d'-' -f2)
		local ebuild_revision=$(echo ${ebuild_full/${package_name}}|cut -d'-' -f3)
		local ebuild_slot="$(grep ^SLOT $ebuild|cut -d'"' -f2)"

		$DEBUG && >&2 echo "**DEBUG: Ebuildvars: ver: $ebuild_version rever: $ebuild_revision slot: $ebuild_slot"

		local cn=()
		# create custom names to check
		cn+=("${patchfile}")
		cn+=("${patchfile/${package_name}/${pn}}")
		cn+=("${patchfile/${package_name}-${ebuild_version}/${p}}")
		cn+=("${patchfile/${ebuild_version}/${pv}}")

		# add special naming if there is a revision
		if [ -n "${ebuild_revision}" ]; then
			cn+=("${patchfile/${package_name}-${ebuild_version}-${ebuild_revision}/${pf}}")
			cn+=("${patchfile/${ebuild_version}-${ebuild_revision}/${pvr}}")
		fi
		# looks for names with slotes, if slot is not 0
		if [ -n "${ebuild_slot}" ] && ! [ "${ebuild_slot}" = "0" ]; then
			cn+=("${patchfile/${ebuild_slot}/${slot}}")
		fi

		# remove duplicates
		mapfile -t cn < <(printf '%s\n' "${cn[@]}"|sort -u)
		# replace list with newpackages
		local searchpattern="$(echo ${cn[@]}|tr ' ' '\n')"

		$DEBUG && >&2 echo "**DEBUG: Custom names: ${cn[@]}"
		$DEBUG && >&2 echo "**DEBUG: Custom names normalized: ${searchpattern}"

		# check ebuild for the custom names
		if $(sed 's|"||g' ${ebuild} | grep -F "${searchpattern}" >/dev/null); then
			found=true
			$DEBUG && >&2 echo "**DEBUG: CHECK: found $patchfile"
		else
			found=false
			$DEBUG && >&2 echo "***DEBUG: CHECK: doesn't found $patchfile"
		fi

		$found && break
	done

	if $found; then
		echo true
	else
		echo false
	fi
}

main(){
	local package=${1}

	category="$(echo ${package}|cut -d'/' -f2)"
	package_name=${package##*/}
	fullpath="/${PORTTREE}/${package}"

	$DEBUG && >&2 echo "DEBUG: checking: ${category}/${package_name}"
	# check if the patches folder exist
	if [ -e ${fullpath}/files ]; then
		$DEBUG && >&2 echo "DEBUG: found files dir in ${category}/${package_name}"

		# before checking, we have to generate a list of patches which we have to
		# check, ignoring README.gentoo files
		patch_list=()
		for file in ${fullpath}/files/*; do
			if ! [ -d ${file} ]; then
				file="${file##*/}"
				if ! $(echo ${file}|grep README.gentoo >/dev/null); then
					patch_list+=("${file}")
				fi
			fi
		done

		$DEBUG && >&2 echo "DEBUG: patchlist: ${patch_list[@]}"
		# first check
		#  every patchfile gets passed to check_ebuild, which replaces
		#  names and version with their corresponding ebuild name ($PN, PV, ..)
		#  and grep's the ebuild with them.
		unused_patches=()
		if [ -n "${patch_list}" ]; then
			for patchfile in "${patch_list[@]}"; do
				found=$(check_ebuild "${patchfile}")
				if ! $found; then
					unused_patches+=("${patchfile}")
				fi
			done
		fi

		# find patches in braces (works only with *.patch files)
		# short description:
		#  find_braces_candidates:
		#   this function takes a list of patch file, and looks if the names
		#   look similar (except for the last part: patch-1, patch-2, ...)
		#   If yes it returns back that part of the filename which is the same.
		#  braces_patches:
		#   this function takes the filename which is the same and add the different
		#   ending in braces (like patch-{1,2,3}). In order to get other combinations
		#   it uses a python script to generate permutations.
		#   Also generates a list of filenames with the correct names, in order to remove the
		#   patches from the list if found.
		#
		#  The filename list which was generated by the braces_patches function gets
		#  checked against the ebuilds via check_ebuild
		find_braces_candidates
		$DEBUG && >&2 echo "DEBUG: duplist: ${dup_list[@]}"
		if [ -n "${dup_list}" ]; then
			for patch in "${dup_list[@]}"; do
				braces_patches ${patch}
				$DEBUG && >&2 echo "DEBUG: brace patches list: ${braces_patch_list[@]}"
				for patchfile in "${braces_patch_list[@]}"; do
					found=$(check_ebuild "${patchfile}")
					if $found; then
						$DEBUG && >&2 echo "DEBUG: found braces: ${patchfile}"
						$DEBUG && >&2 echo "DEBUG: remove from list: ${filess[@]}"
						for toremove in "${filess[@]}"; do
							for target in "${!unused_patches[@]}"; do
								if [ "${unused_patches[target]}" = "${toremove}" ]; then
									unset 'unused_patches[target]'
								fi
							done

						done
						break
					fi
				done
			done
		fi

		$DEBUG && echo >&2 "DEBUG: unused patches: ${unused_patches[@]}"
		$DEBUG && echo >&2

		main="$(get_main_min "${category}/${package_name}")"
		if [ -z "${main}" ]; then
			main="maintainer-needed@gentoo.org:"
		fi


		if [ -n "${unused_patches}" ]; then
			if ${script_mode}; then
				for upatch in "${unused_patches[@]}"; do
					echo -e "$package ${upatch}" >> ${script_mode_tmp}
					echo -e "$package ${upatch}\t\t${main}" >> ${script_mode_tmp_full}
				done
			else
				for upatch in "${unused_patches[@]}"; do
					${print_main} && \
						echo -e "$package: ${upatch}\t\t${main}" || \
						echo -e "$package: ${upatch}"
				done
			fi
		fi

		$DEBUG && >&2 echo && >&2 echo

	fi
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

# xargs versoin - not working yet...
# https://stackoverflow.com/questions/11003418/calling-functions-with-xargs-within-a-bash-script
#find ./${level} -mindepth $MIND -maxdepth $MAXD \( \
#-path ./scripts/\* -o \
#-path ./profiles/\* -o \
#-path ./packages/\* -o \
#-path ./licenses/\* -o \
#-path ./distfiles/\* -o \
#-path ./metadata/\* -o \
#-path ./eclass/\* -o \
#-path ./.git/\* \) -prune -o -type d -print | xargs -n 1 -P 10 -I {} bash -c 'main "$@"' _ {}

if ${script_mode}; then
	# remove old data
	rm -rf ${script_mode_dir}/*

	f_packages="$(cat ${script_mode_tmp} | cut -d' ' -f1|sort|uniq)"
	for i in $f_packages; do
		f_cat="$(echo $i|cut -d'/' -f1)"
		f_pak="$(echo $i|cut -d'/' -f2)"
		mkdir -p ${script_mode_dir}/sort-by-package/${f_cat}
		grep $i ${script_mode_tmp} > ${script_mode_dir}/sort-by-package/${f_cat}/${f_pak}.txt
	done
	for a in $(cat ${script_mode_tmp_full} |cut -d$'\t' -f3|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
		mkdir -p ${script_mode_dir}/sort-by-maintainer/
		grep "${a}" ${script_mode_tmp_full} > ${script_mode_dir}/sort-by-maintainer/"$(echo ${a}| sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
	done
	cp ${script_mode_tmp} ${script_mode_dir}/full.txt
	cp ${script_mode_tmp_full} ${script_mode_dir}/full-with-maintainers.txt
	rm ${script_mode_tmp}
	rm ${script_mode_tmp_full}
fi

