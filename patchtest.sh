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

toscan="*"

pn='${PN}'
p='${P}'
pf='${PF}'
pv='${PV}'
pvr='${PVR}'

cd ${PORTTREE}


if [ -n "$1" ]; then
	if [ -d $1 ]; then
		toscan=$1
	else
		echo "$1 doesn't exist. scanning all"
	fi
fi

ls -d ${toscan}/* |grep -E -v "distfiles|metadata|eclass" | while read -r line; do

	category=${line%%/*}
	package_name=${line##*/}

	fullpath="/${PORTTREE}/${line}"
	if [ -e ${fullpath}/files ]; then
		for patchfile in ${fullpath}/files/*; do
			# ignore directories
			if ! [ -d ${patchfile} ]; then
				# patch basename
				patchfile=${patchfile##*/}
				# skip readme files
				if [ "${patchfile}" == "README.gentoo" ]; then
					continue
				fi

				for ebuild in ${fullpath}/*.ebuild; do
					ebuild_full=${ebuild%.*}
					ebuild_full=${ebuild_full##*/}
					ebuild_version=$(echo ${ebuild_full/${package_name}}|cut -d'-' -f2)
					ebuild_reversion=$(echo ${ebuild_full/${package_name}}|cut -d'-' -f3)


					custom_name_1=${patchfile/${package_name}/${pn}}
					custom_name_2=${patchfile/${package_name}-${ebuild_version}/${p}}
					custom_name_4=${patchfile/${ebuild_version}/${pv}}
					if [ -n "${ebuild_reversion}" ]; then
						custom_name_3=${patchfile/${package_name}-${ebuild_version}-${ebuild_reversion}/${pf}}
						custom_name_5=${patchfile/${ebuild_version}-${ebuild_reversion}/${pvr}}
					else
						custom_name_5=${patchfile/${ebuild_version}/${pvr}}
					fi

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
					echo "$line: ${patchfile}"
				fi

				found=false
			fi
		done
	fi
done

