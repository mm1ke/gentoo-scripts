#!/bin/bash

# Filename: full_gen.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
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
# create full bug lists per packages and maintainers

# load repo specific settings
startdir="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
if [ -e ${startdir}/repo ]; then
	source ${startdir}/repo
fi

realdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${realdir}/_funcs-httpgen.sh ]; then
	source ${realdir}/_funcs.sh
	source ${realdir}/_funcs-httpgen.sh
else
	echo "Missing _funcs{-httpgen}.sh"
	exit 1
fi

WORKDIR="/tmp/full-gen-${RANDOM}"

search_pattern="*-*-*"
mkdir -p ${WORKDIR}/{sort-by-package,sort-by-maintainer}

for check in ${SITEDIR}/checks/${search_pattern}; do
	for main in $(ls ${check}/sort-by-maintainer/); do
		echo "<<< ${check##*/} >>>" >> ${WORKDIR}/sort-by-maintainer/${main}
		cat ${check}/sort-by-maintainer/${main} >> ${WORKDIR}/sort-by-maintainer/${main}
	done
done

for check in ${SITEDIR}/checks/${search_pattern}; do
	for cat in $(ls ${check}/sort-by-package/); do
		mkdir -p ${WORKDIR}/sort-by-package/${cat}
		for pack in $(ls ${check}/sort-by-package/${cat}/); do
			echo "<<< ${check##*/} >>>" >> ${WORKDIR}/sort-by-package/${cat}/${pack}
			cat ${check}/sort-by-package/${cat}/${pack} >> ${WORKDIR}/sort-by-package/${cat}/${pack}
		done
	done
done

for cat in $(ls ${WORKDIR}/sort-by-package/); do
	for pack in $(ls ${WORKDIR}/sort-by-package/${cat}/); do
		echo "<<< open bugs >>>" >> ${WORKDIR}/sort-by-package/${cat}/${pack}
		openbugs="$(get_bugs_full "${cat}/${pack::-4}")"
		echo "${openbugs}" >> ${WORKDIR}/sort-by-package/${cat}/${pack}
	done
done

if [ -e "${SITEDIR}/listings/" ]; then
	rm -rf ${SITEDIR}/listings/*
else
	mkdir -p "${SITEDIR}/listings/"
fi
cp -r ${WORKDIR}/* ${SITEDIR}/listings/
rm -rf ${WORKDIR}

# generate html output for listings
gen_http_sort_main_v2 fullpak ${SITEDIR}/listings > ${SITEDIR}/listings/index-pak.html
gen_http_sort_main_v2 main ${SITEDIR}/listings > ${SITEDIR}/listings/index.html

# generate html output (overview/results)
gen_http_sort_main_v2 results ${SITEDIR}/checks > ${SITEDIR}/checks/index.html
gen_http_sort_main_v2 results ${SITEDIR}/stats > ${SITEDIR}/stats/index.html

# generate html output (maintainer/results)
gen_html_top > ${SITEDIR}/checks.html
gen_html_top > ${SITEDIR}/stats.html
for ce in $(find ${SITEDIR}/checks/ -mindepth 1 -maxdepth 1 -type d|sort); do
	gen_html_out ${ce##*/} checks >> ${SITEDIR}/checks.html
	gen_http_sort_main_v2 main ${ce} > ${ce}/index.html
	if [ -e "${ce}/sort-by-filter" ]; then
		for fce in $(find ${ce}/sort-by-filter/ -mindepth 1 -maxdepth 1 -type d|sort); do
			gen_http_sort_main_v2 main ${fce} > ${fce}/index.html
		done
	elif [ -e "${ce}/sort-by-eapi" ]; then
		for fce in $(find ${ce}/sort-by-eapi/ -mindepth 1 -maxdepth 1 -type d|sort); do
			gen_http_sort_main_v2 main ${fce} > ${fce}/index.html
		done
	fi
done
for st in $(find ${SITEDIR}/stats/ -mindepth 1 -maxdepth 1 -type d|sort); do
	gen_html_out ${st##*/} stats >> ${SITEDIR}/stats.html
	gen_http_sort_main_v2 main ${st} > ${st}/index.html
	if [ -e "${st}/sort-by-filter" ]; then
		for fst in $(find ${st}/sort-by-filter/ -mindepth 1 -maxdepth 1 -type d|sort); do
			gen_http_sort_main_v2 main ${fst} > ${fst}/index.html
		done
	elif [ -e "${st}/sort-by-eapi" ]; then
		for fst in $(find ${st}/sort-by-eapi/ -mindepth 1 -maxdepth 1 -type d|sort); do
			gen_http_sort_main_v2 main ${fst} > ${fst}/index.html
		done
	fi
done
gen_html_bottom >> ${SITEDIR}/stats.html
gen_html_bottom >> ${SITEDIR}/checks.html
