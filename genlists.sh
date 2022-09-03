#!/bin/bash

# Filename: genlists.sh
# Autor: Michael Mair-Keimberger (mmk AT levelnine DOT at)
# Date: 12/11/2017

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
# create full lists per packages and maintainers, replaces full_gen

#override RESULTSDIR settings
#export RESULTSDIR="${HOME}/st/guru/"

realdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${realdir}/_funcs.sh ]; then
	source ${realdir}/_funcs.sh
else
	echo "Missing _funcs{-httpgen}.sh"
	exit 1
fi

#
### IMPORTANT SETTINGS START ###
#
WORKDIR="/tmp/full-gen-${RANDOM}"
#
### IMPORTANT SETTINGS END ###
#

# switch to RESULTSDIR to avoid access denied errors
cd ${RESULTSDIR}

mkdir -p ${WORKDIR}/{sort-by-package,sort-by-maintainer}

### full list generation start ###
#
# full list gen - maintainer sorting
for check in $(find ${RESULTSDIR}/checks/ -mindepth 1 -maxdepth 1 -type d -print|sort); do
	if [ -d ${check}/sort-by-maintainer/ ]; then
		for main in $(ls ${check}/sort-by-maintainer/); do
			echo "<<< ${check##*/} >>>" >> ${WORKDIR}/sort-by-maintainer/${main}
			cat ${check}/sort-by-maintainer/${main} | sed 's/^/  /g' >> ${WORKDIR}/sort-by-maintainer/${main}
		done
	fi
done

# full list gen - package sorting
for check in $(find ${RESULTSDIR}/checks/ -mindepth 1 -maxdepth 1 -type d -print|sort); do
	if [ -d ${check}/sort-by-package/ ]; then
		for cat in $(ls ${check}/sort-by-package/); do
			mkdir -p ${WORKDIR}/sort-by-package/${cat}
			for pack in $(ls ${check}/sort-by-package/${cat}/); do
				echo "<<< ${check##*/} >>>" >> ${WORKDIR}/sort-by-package/${cat}/${pack}
				cat ${check}/sort-by-package/${cat}/${pack} | sed 's/^/  /g' >> ${WORKDIR}/sort-by-package/${cat}/${pack}
			done
		done
	fi
done

# add bug information to the packages
for cat in $(ls ${WORKDIR}/sort-by-package/); do
	for pack in $(ls ${WORKDIR}/sort-by-package/${cat}/); do
		openbugs="$(get_bugs_full "${cat}/${pack::-4}")"
		# only add openbugs information when they are any open bugs
		if [ -n "${openbugs}" ]; then
			echo "<<< open bugs >>>" >> ${WORKDIR}/sort-by-package/${cat}/${pack}
			echo "${openbugs}" | sed 's/^/  /g' >> ${WORKDIR}/sort-by-package/${cat}/${pack}
		fi
	done
done
### full list generation end ###

# remove old listings and replace it with the new one
if [ -e "${RESULTSDIR}/listings/" ]; then
	rm -rf ${RESULTSDIR}/listings/*
else
	mkdir -p "${RESULTSDIR}/listings/"
fi
cp -r ${WORKDIR}/* ${RESULTSDIR}/listings/
rm -rf ${WORKDIR}
