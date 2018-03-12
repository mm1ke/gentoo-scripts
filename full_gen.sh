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

startdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${startdir}/funcs.sh ]; then
	source ${startdir}/funcs.sh
else
	echo "Missing funcs.sh"
	exit 1
fi
if [ -e ${startdir}/funcs-httpgen.sh ]; then
	source ${startdir}/funcs-httpgen.sh
else
	echo "Missing funcs-httpgen.sh"
	exit 1
fi

WORKDIR="/tmp/full-gen-${RANDOM}"
SITEDIR="/var/www/gentooqa.levelnine.at/results/"

mkdir -p ${WORKDIR}
mkdir -p ${WORKDIR}/full_list/{sort-by-maintainer,sort-by-package}

for typ in IMP BUG; do

	mkdir -p ${WORKDIR}/full_list_${typ}/{sort-by-package,sort-by-maintainer}

	for check in ${SITEDIR}/checks/*-${typ}-*; do
		for main in $(ls ${check}/sort-by-maintainer/); do
			echo "<<< ${check##*/} >>>" >> ${WORKDIR}/full_list_${typ}/sort-by-maintainer/${main}
			cat ${check}/sort-by-maintainer/${main} >> ${WORKDIR}/full_list_${typ}/sort-by-maintainer/${main}
		done
	done

	for check in ${SITEDIR}/checks/*-${typ}-*; do
		for cat in $(ls ${check}/sort-by-package/); do
			mkdir -p ${WORKDIR}/full_list_${typ}/sort-by-package/${cat}
			for pack in $(ls ${check}/sort-by-package/${cat}/); do
				echo "<<< ${check##*/} >>>" >> ${WORKDIR}/full_list_${typ}/sort-by-package/${cat}/${pack}
				cat ${check}/sort-by-package/${cat}/${pack} >> ${WORKDIR}/full_list_${typ}/sort-by-package/${cat}/${pack}
			done
		done
	done

	if [ "${typ}" = "BUG" ]; then
		for cat in $(ls ${WORKDIR}/full_list_${typ}/sort-by-package/); do
			for pack in $(ls ${WORKDIR}/full_list_${typ}/sort-by-package/${cat}/); do
				echo "<<< open bugs >>>" >> ${WORKDIR}/full_list_${typ}/sort-by-package/${cat}/${pack}
				openbugs="$(get_bugs_full "${cat}/${pack::-4}")"
				echo "${openbugs}" >> ${WORKDIR}/full_list_${typ}/sort-by-package/${cat}/${pack}
			done
		done
	fi

	[ -n "${SITEDIR}/full_Lists/full_list_${typ}" ] && rm -rf ${SITEDIR}/full_lists/full_list_${typ}/
	cp -r ${WORKDIR}/full_list_${typ} ${SITEDIR}/full_lists/
	rm -rf ${WORKDIR}
done

mkdir -p ${WORKDIR}/full_list/{sort-by-package,sort-by-maintainer}

for check in ${SITEDIR}/checks/*-*-*; do
	for main in $(ls ${check}/sort-by-maintainer/); do
		echo "<<< ${check##*/} >>>" >> ${WORKDIR}/full_list/sort-by-maintainer/${main}
		cat ${check}/sort-by-maintainer/${main} >> ${WORKDIR}/full_list/sort-by-maintainer/${main}
	done
done

for check in ${SITEDIR}/checks/*-*-*; do
	for cat in $(ls ${check}/sort-by-package/); do
		mkdir -p ${WORKDIR}/full_list/sort-by-package/${cat}
		for pack in $(ls ${check}/sort-by-package/${cat}/); do
			echo "<<< ${check##*/} >>>" >> ${WORKDIR}/full_list/sort-by-package/${cat}/${pack}
			cat ${check}/sort-by-package/${cat}/${pack} >> ${WORKDIR}/full_list/sort-by-package/${cat}/${pack}
		done
	done
done

for cat in $(ls ${WORKDIR}/full_list/sort-by-package/); do
	for pack in $(ls ${WORKDIR}/full_list/sort-by-package/${cat}/); do
		echo "<<< open bugs >>>" >> ${WORKDIR}/full_list/sort-by-package/${cat}/${pack}
		openbugs="$(get_bugs_full "${cat}/${pack::-4}")"
		echo "${openbugs}" >> ${WORKDIR}/full_list/sort-by-package/${cat}/${pack}
	done
done

[ -n "${SITEDIR}/full_lists/full_list" ] && rm -rf ${SITEDIR}/full_lists/full_list/
cp -r ${WORKDIR}/full_list ${SITEDIR}/full_lists/
rm -rf ${WORKDIR}


# generate html output
gen_http_sort_main_v2 results /var/www/gentooqa.levelnine.at/results/checks > /var/www/gentooqa.levelnine.at/results/checks/index.html
gen_http_sort_main_v2 results /var/www/gentooqa.levelnine.at/results/stats > /var/www/gentooqa.levelnine.at/results/stats/index.html
gen_http_sort_main_v2 results /var/www/gentooqa.levelnine.at/results/full_lists > /var/www/gentooqa.levelnine.at/results/full_lists/index.html


for i in $(find /var/www/gentooqa.levelnine.at/results/checks/ -mindepth 1 -maxdepth 1 -type d); do
	gen_http_sort_main_v2 main $i > ${i}/index.html
done
for i in $(find /var/www/gentooqa.levelnine.at/results/stats/ -mindepth 1 -maxdepth 1 -type d); do
	gen_http_sort_main_v2 main $i > ${i}/index.html
done
for i in $(find /var/www/gentooqa.levelnine.at/results/full_lists/ -mindepth 1 -maxdepth 1 -type d); do
	gen_http_sort_main_v2 main $i > ${i}/index.html
done
