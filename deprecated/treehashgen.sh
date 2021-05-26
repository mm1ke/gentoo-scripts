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

#override REPOTREE settings
#REPOTREE=/usr/portage/
#REPO=gentoo
#HASHTREE=/tmp/treehashtmp


# check and set DEBUG/DRYRUN
[ -z "${DEBUG}" ] && DEBUG=false
[ -z "${DRYRUN}" ] && DRYRUN=false

# check and set set the REPOTREE
[ -z "${REPOTREE}" ] && DRYRUN=true
[ -z "${REPO}" ] && DRYRUN=true
[ -z "${HASHTREE}" ] && DRYRUN=true

#
### IMPORTANT SETTINGS START ###
#
WORKDIR="/var/tmp/treehashgen/${REPO}"
#
### IMPORTANT SETTINGS END ###
#

# DRYRUN - only print vars and exit
if ${DRYRUN}; then
	echo treehashgen
	echo "Repo: ${REPO}"
	echo "Porttree: ${REPOTREE}"
	echo "Debug: ${DEBUG}"
	echo "Hashtree: ${HASHTREE}"
	exit 1
fi

# switch to the repotree first
cd ${REPOTREE}

hash_start(){
	date_today="$(date -I)"
	mkdir -p ${HASHTREE}
	# only run if there doesn't exists a result for today
	if ! [ -e ${HASHTREE}/full-${date_today}.log ]; then
		mkdir -p ${WORKDIR}

		# generate hashes for every package
		# list every category
		local searchp="${REPOTREE}/*-*"
		local searchp=( $(find ${REPOTREE} -mindepth 1 -maxdepth 1 -type d -regextype sed -regex "./*[a-z0-9].*-[a-z0-9].*") )
		[ -d "${REPOTREE}/virtual" ] && searchp+=( "${REPOTREE%/}/virtual" )

		for cate in ${searchp[@]}; do
			for paka in $(find ${cate} -mindepth 1 -maxdepth 1 -type d); do
				mkdir -p ${WORKDIR}/${paka/${REPOTREE}/}
				# list all files in each directory and create hash
				find ${paka} -type f -exec xxh64sum {} \; > ${WORKDIR}/${paka/${REPOTREE}/}/package-xhash.xha
				#echo ${paka} >> /tmp/package-ng-new.log
			done
		done

		# generate hashes for every category based on the package hashes
		for cat in $(find ${WORKDIR} -mindepth 1 -maxdepth 1 -type d); do
			find ${cat} -mindepth 2 -type f -name *.xha -exec xxh64sum {} \; \
				| tee -a ${cat}/category-xhash.xha ${HASHTREE}/full-${date_today}.log >/dev/null
		done
		# generate hash for the full tree
		find ${WORKDIR} -mindepth 2 -maxdepth 2 -type f -name *.xha -exec xxh64sum {} \; \
			| tee -a ${WORKDIR}/tree-xhash.xha ${HASHTREE}/full-${date_today}.log >/dev/null
		# generate results file, based on the diffs from the full-last.log
		# if this file doesn't exist nothing happen.
		if [ -e ${HASHTREE}/full-last.log ]; then
			mkdir -p ${HASHTREE}/results
			touch ${HASHTREE}/results/results-${date_today}.log
			# list every category, save hashes of today and yesterday, compare and
			# if it doesn't match, check every package in that category
			for cat in $(find ${WORKDIR} -mindepth 1 -maxdepth 1 -type d); do
				cat_hash_last="$(grep ${cat}/category-xhash.xha ${HASHTREE}/full-last.log | cut -d ' ' -f1)"
				cat_hash_today="$(grep ${cat}/category-xhash.xha ${HASHTREE}/full-${date_today}.log| cut -d' ' -f1)"
				if ! [ "${cat_hash_last}" = "${cat_hash_today}" ]; then
					for pak in $(find ${cat} -mindepth 1 -maxdepth 1 -type d); do
						pak_hash_last="$(grep ${pak}/package-xhash.xha ${HASHTREE}/full-last.log | cut -d ' ' -f1)"
						pak_hash_today="$(grep ${pak}/package-xhash.xha ${HASHTREE}/full-${date_today}.log| cut -d' ' -f1)"
						if ! [ "${pak_hash_last}" = "${pak_hash_today}" ]; then
							echo "${pak/${WORKDIR}}" >> ${HASHTREE}/results/results-${date_today}.log
						fi
					done
				fi
			done
		fi
		rm -rf ${WORKDIR}
	fi
}

hash_start
