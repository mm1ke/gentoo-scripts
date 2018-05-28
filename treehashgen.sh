#!/bin/bash

# Filename: treehashgen.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 23/05/2018

# Copyright (C) 2018  Michael Mair-Keimberger
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
#	script to generate hashes of the gentoo tree

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/eapistats/"
#export PORTTREE=/usr/portage/

# load repo specific settings
startdir="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
if [ -e ${startdir}/repo ]; then
	source ${startdir}/repo
fi

# get dirpath and load funcs.sh
realdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${realdir}/_funcs.sh ]; then
	source ${realdir}/_funcs.sh
else
	echo "Missing _funcs.sh"
	exit 1
fi

[ -z "${REPO}" ] && REPO="gentoo"
RESULTDIR="/root/treehashs/${REPO}/"
date_today="$(date -I)"
#
### IMPORTANT SETTINGS START ###
#
SCRIPT_NAME="treehashgen"
WORKDIR="/var/tmp/${SCRIPT_NAME}/${REPO}"
#
### IMPORTANT SETTINGS STOP ###
#



if [ -e ${RESULTDIR} ]; then
	if ! [ -e ${RESULTDIR}/full-${date_today}.log ]; then
		mkdir -p ${WORKDIR}
		# generate hashes for every package
		for cate in $(find ${PORTTREE} -mindepth 1 -maxdepth 1 -type d \
			-not -path '*/\.*' \
			-not -path '*/profiles' \
			-not -path '*/metadata' \
			-not -path '*/eclass' \
			-not -path '*/scripts' \
			-not -path '*/licenses' \
			-not -path '*/packages' \
			-not -path '*/distfiles'); do
			for paka in $(find ${cate} -mindepth 1 -maxdepth 1 -type d); do
				mkdir -p ${WORKDIR}/${paka/${PORTTREE}/}
				find ${paka} -type f -exec xxh64sum {} \; > ${WORKDIR}/${paka/${PORTTREE}/}/package-xhash.xha
			done
		done

		# generate hashes for every category based on the package hashes
		for cat in $(find ${WORKDIR} -mindepth 1 -maxdepth 1 -type d); do
			find ${cat} -mindepth 2 -type f -name *.xha -exec xxh64sum {} \; \
				| tee -a ${cat}/category-xhash.xha ${RESULTDIR}/full-${date_today}.log >/dev/null
		done

		find ${WORKDIR} -mindepth 2 -maxdepth 2 -type f -name *.xha -exec xxh64sum {} \; \
			| tee -a ${WORKDIR}/tree-xhash.xha ${RESULTDIR}/full-${date_today}.log >/dev/null

		if [ -e ${RESULTDIR}/full-last.log ]; then
			for cat in $(find ${WORKDIR} -mindepth 1 -maxdepth 1 -type d); do
				cat_hash_last="$(grep ${cat}/category-xhash.xha ${RESULTDIR}/full-last.log | cut -d ' ' -f1)"
				cat_hash_today="$(grep ${cat}/category-xhash.xha ${RESULTDIR}/full-${date_today}.log| cut -d' ' -f1)"
				if ! [ "${cat_hash_last}" = "${cat_hash_today}" ]; then
					for pak in $(find ${cat} -mindepth 1 -maxdepth 1 -type d); do

						pak_hash_last="$(grep ${pak}/package-xhash.xha ${RESULTDIR}/full-last.log | cut -d ' ' -f1)"
						pak_hash_today="$(grep ${pak}/package-xhash.xha ${RESULTDIR}/full-${date_today}.log| cut -d' ' -f1)"

						if ! [ "${pak_hash_last}" = "${pak_hash_today}" ]; then
							echo "${pak/${WORKDIR}/} changed since yesterday"
							echo "${pak/${WORKDIR}/}" >> ${RESULTDIR}/results/results-${date_today}.log
						fi
					done
				fi
			done
		fi
		cp ${RESULTDIR}/full-${date_today}.log ${RESULTDIR}/full-last.log
		rm -rf ${WORKDIR}
	fi
fi
