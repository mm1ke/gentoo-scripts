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

SCRIPT_MODE=false
PORTTREE="/usr/portage/"
WWWDIR="${HOME}/patchtest/"
TMPFILE="/tmp/patchtest-$(date +%y%m%d).txt"

if [ "$(hostname)" = methusalix ]; then
	SCRIPT_MODE=true
	WWWDIR="/var/www/gentoo.levelnine.at/patchtest/"
fi

cd ${PORTTREE}

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

main(){
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

			# special naming
			if $(grep -E "^MY_PN=|^MY_P=|^MY_PV=" ${ebuild} >/dev/null); then
				local var_my_pn='${MY_PN}'
				local var_my_p='${MY_P}'
				local var_my_pv='${MY_PV}'

				local package_name_ver="${package_name}-${ebuild_version}"

				my_pn_name="$(grep ^MY_PN ${ebuild})"
				my_p_name="$(grep ^MY_P ${ebuild})"
				my_pv_name="$(grep ^MY_PV ${ebuild})"

				[ -n "${my_pn_name}" ] && \
					eval my_pn_name="$(echo ${my_pn_name:6}|sed "s|PN|package_name|g")" >/dev/null 2>&1
				[ -n "${my_pv_name}" ] && \
					eval my_pv_name="$(echo ${my_pv_name:6}|sed "s|PV|ebuild_version|g")" >/dev/null 2>&1
				[ -n "${my_p_name}" ] && \
					eval my_p_name="$(echo ${my_p_name:5}|sed "s|P|package_name_ver|g")" >/dev/null 2>&1

				$DEBUG && >&2 echo "***DEBUG: Found MY_P* vars: $my_pv_name, $my_pn_name, $my_p_name"

				[ -n "${my_pn_name}" ] && cn+=("${patchfile/${my_pn_name}/${var_my_pn}}")
				[ -n "${my_pv_name}" ] && cn+=("${patchfile/${my_pv_name}/${var_my_pv}}")
				[ -n "${my_p_name}" ] && cn+=("${patchfile/${my_p_name}/${var_my_p}}")
			fi

			# add special naming if there is a revision
			if [ -n "${ebuild_revision}" ]; then
				cn+=("${patchfile/${package_name}-${ebuild_version}-${ebuild_revision}/${pf}}")
				cn+=("${patchfile/${ebuild_version}-${ebuild_revision}/${pvr}}")
			fi
			# looks for names with slotes, if slot is not 0
			if [ -n "${ebuild_slot}" ] && ! [ "${ebuild_slot}" = "0" ]; then
				cn+=("${patchfile/${ebuild_slot}/${slot}}")
				name_slot="${patchfile/${package_name}/${pn}}"
				name_slot="${name_slot/${ebuild_slot}/${slot}}"
				cn+=("${name_slot}")
			fi
			# find vmware-modules patches
			if [ "${package_name}" = "vmware-modules" ]; then
				local pv_major='${PV_MAJOR}'
				cn+=("${patchfile/${ebuild_version%%.*}/${pv_major}}")
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

	find_braces_candidates(){
		local work_list=("${unused_patches[@]}")
		local patch
		local pat_found=()
		local count

		$DEBUG && >&2 echo
		$DEBUG && >&2 echo "*DEBUG: find_braces_candidates"

		#echo "worklist: ${work_list[@]}"
		# expect patches in braces to use name+version or $PN
		# thus the first 2 part (cut with -) ar similar
		#
		# first generate a list of files which fits the rule
		for patch in "${work_list[@]}"; do
			local deli=$(echo ${patch%.patch}|grep -o '-'|wc -w)
			if [ $deli -ge 2 ]; then
				pat_found+=("$(echo $patch|cut -d '-' -f1-$deli)")
				$DEBUG && >&2 echo "***DEBUG: ${patch} could fit (found ${deli} matching \"-\" in filename)"
				$DEBUG && >&2 echo "***DEBUG: saving file as $(echo $patch|cut -d '-' -f1-$deli)"
			fi
		done
		# create a list of duplicates
		dup_list=()
		for patch in "${pat_found[@]}"; do
			# search for every element in the array
			$DEBUG && >&2 echo "**DEBUG: check for pattern ${patch}"

			count=$(echo ${pat_found[@]}|grep -P -o "${patch}(?=\s|$)"|wc -w)
			if [ $count -gt 1 ]; then
				dup_list+=($patch)
				$DEBUG && >&2 echo "***DEBUG: ${patch} matches more than 1"
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

	local prechecks=true
	local package=${1}
	local category="$(echo ${package}|cut -d'/' -f2)"

	package_name=${package##*/}
	fullpath="/${PORTTREE}/${package}"

	$DEBUG && >&2 echo "DEBUG: checking: ${category}/${package_name}"
	# check if the patches folder exist
	if [ -e ${fullpath}/files ]; then
		$DEBUG && >&2 echo "DEBUG: found files dir in ${category}/${package_name}"

		# before checking, we have to generate a list of patches which we have to check
		patch_list=()
		for file in ${fullpath}/files/*; do
			if ! [ -d ${file} ]; then
				file="${file##*/}"
				# reduce false positive by making some pre-checks
				# check for vdr-plugin-2 eclass which installs rc-addon.sh files
				if [ "${file}" = "rc-addon.sh" ]; then
					${prechecks} && $(grep vdr-plugin-2 ${fullpath}/*.ebuild >/dev/null) || patch_list+=("${file}")
				# check for vdr-plugin-2 eclass which installs confd files if exists
				elif [ "${file}" = "confd" ]; then
					${prechecks} && $(grep vdr-plugin-2 ${fullpath}/*.ebuild > /dev/null) || patch_list+=("${file}")
				# check for games-mods eclass which install server.cfg files
				elif [ "${file}" = "server.cfg" ]; then
					${prechecks} && $(grep games-mods ${fullpath}/*.ebuild >/dev/null) || patch_list+=("${file}")
				# check for apache-module eclass which installs conf files if a APACHE2_MOD_CONF is set
				elif [ "${file##*.}" = "conf" ]; then
					${prechecks} && $(grep apache-module ${fullpath}/*.ebuild > /dev/null) && \
						$(grep APACHE2_MOD_CONF ${fullpath}/*.ebuild > /dev/null) || patch_list+=("${file}")
				# check for elisp eclass which install el files if a SITEFILE is set
				elif [ "${file##*.}" = "el" ]; then
					${prechecks} && $(grep elisp ${fullpath}/*.ebuild > /dev/null) && \
						$(grep SITEFILE ${fullpath}/*.ebuild > /dev/null) || patch_list+=("${file}")
				# ignoring README.gentoo files
				elif ! $(echo ${file}|grep -i README.gentoo >/dev/null); then
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
			if ${SCRIPT_MODE}; then
				for upatch in "${unused_patches[@]}"; do
					echo -e "${category}/${package_name};${upatch};${main}" >> ${TMPFILE}
				done
			else
				for upatch in "${unused_patches[@]}"; do
					echo -e "${category}/${package_name};${upatch};${main}"
				done
			fi
		fi

		$DEBUG && >&2 echo && >&2 echo

	fi
}

export -f main get_perm get_main_min
export TMPFILE PORTTREE WWWDIR SCRIPT_MODE DEBUG

# Don't use parallel if DEBUG is enabled
if ${DEBUG}; then
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
else
	find ./${level} -mindepth $MIND -maxdepth $MAXD \( \
		-path ./scripts/\* -o \
		-path ./profiles/\* -o \
		-path ./packages/\* -o \
		-path ./licenses/\* -o \
		-path ./distfiles/\* -o \
		-path ./metadata/\* -o \
		-path ./eclass/\* -o \
		-path ./.git/\* \) -prune -o -type d -print | parallel main {}
fi

if ${SCRIPT_MODE}; then
	# remove old data
	rm -rf ${WWWDIR}/*

	f_packages="$(cat ${TMPFILE} | cut -d';' -f1|sort|uniq)"
	for i in ${f_packages}; do
		f_cat="$(echo ${i}|cut -d'/' -f1)"
		f_pak="$(echo ${i}|cut -d'/' -f2)"
		mkdir -p ${WWWDIR}/sort-by-package/${f_cat}
		grep ${i} ${TMPFILE} > ${WWWDIR}/sort-by-package/${f_cat}/${f_pak}.txt
	done
	for a in $(cat ${TMPFILE} |cut -d';' -f3|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
		mkdir -p ${WWWDIR}/sort-by-maintainer/
		grep "${a}" ${TMPFILE} > ${WWWDIR}/sort-by-maintainer/"$(echo ${a}| sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
	done
	cp ${TMPFILE} ${WWWDIR}/full-with-maintainers.txt
	rm ${TMPFILE}
fi
