#!/bin/bash

# Filename: whitecheck
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 02/02/2018

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
# script for checking the whitelist for obsolete entries

PORTTREE="/mnt/data/gentoo/"

if [ -z "${1}" ]; then
	echo "You need to provide a whitelist file"
	exit 1
else
	if ! [ -e ${1} ]; then
		echo "Whitelist file doesn't exist"
		exit 1
	else
		source ${1}
	fi
fi

for white in ${white_list[@]}; do
	cat_pak="$(echo ${white}|cut -d';' -f1)"
	white_file="$(echo ${white}|cut -d';' -f2)"
	white_ebuild="$(echo ${white}|cut -d';' -f3)"

	if ! [ -e ${PORTTREE}/${cat_pak}/files/${white_file} ]; then
		echo "removing ${cat_pak};${white_file}"
		sed -i "/${white_file}/d" ${1}
	fi
done
