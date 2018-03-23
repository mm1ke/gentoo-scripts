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
if [ -e ${startdir}/funcs-httpgen.sh ]; then
	source ${startdir}/funcs-httpgen.sh
else
	echo "Missing funcs-httpgen.sh"
	exit 1
fi

WORKDIR="/tmp/full-gen-${RANDOM}"
SITEDIR="/var/www/gentooqa.levelnine.at/results/"

for typ in IMP BUG FULL; do

	if [ "${typ}" = "FULL" ]; then
		dir_postfix=""
		search_pattern="*-*-*"
	else
		dir_postfix="_${typ}"
		search_pattern="*-${typ}-*"
	fi

	FULLWORKDIR="${WORKDIR}/full_list${dir_postfix}"

	mkdir -p ${FULLWORKDIR}/{sort-by-package,sort-by-maintainer}

	for check in ${SITEDIR}/checks/${search_pattern}; do
		for main in $(ls ${check}/sort-by-maintainer/); do
			echo "<<< ${check##*/} >>>" >> ${FULLWORKDIR}/sort-by-maintainer/${main}
			cat ${check}/sort-by-maintainer/${main} >> ${FULLWORKDIR}/sort-by-maintainer/${main}
		done
	done

	for check in ${SITEDIR}/checks/${search_pattern}; do
		for cat in $(ls ${check}/sort-by-package/); do
			mkdir -p ${FULLWORKDIR}/sort-by-package/${cat}
			for pack in $(ls ${check}/sort-by-package/${cat}/); do
				echo "<<< ${check##*/} >>>" >> ${FULLWORKDIR}/sort-by-package/${cat}/${pack}
				cat ${check}/sort-by-package/${cat}/${pack} >> ${FULLWORKDIR}/sort-by-package/${cat}/${pack}
			done
		done
	done

	if [ "${typ}" = "BUG" ] || [ "${typ}" = "FULL" ]; then
		for cat in $(ls ${FULLWORKDIR}/sort-by-package/); do
			for pack in $(ls ${FULLWORKDIR}/sort-by-package/${cat}/); do
				echo "<<< open bugs >>>" >> ${FULLWORKDIR}/sort-by-package/${cat}/${pack}
				openbugs="$(get_bugs_full "${cat}/${pack::-4}")"
				echo "${openbugs}" >> ${FULLWORKDIR}/sort-by-package/${cat}/${pack}
			done
		done
	fi

	[ -n "${SITEDIR}/full_Lists/full_list${dir_postfix}" ] && rm -rf ${SITEDIR}/full_lists/full_list${dir_postfix}/
	cp -r ${FULLWORKDIR} ${SITEDIR}/full_lists/
	rm -rf ${WORKDIR}
done

# generate html output (overview/results)
gen_http_sort_main_v2 results ${SITEDIR}/checks > ${SITEDIR}/checks/index.html
gen_http_sort_main_v2 results ${SITEDIR}/stats > ${SITEDIR}/stats/index.html
gen_http_sort_main_v2 results ${SITEDIR}/full_lists > ${SITEDIR}/full_lists/index.html

# generate html output (maintainer/results)
gen_html_top > /var/www/gentooqa.levelnine.at/checks.html
gen_html_top > /var/www/gentooqa.levelnine.at/stats.html
for ce in $(find ${SITEDIR}/checks/ -mindepth 1 -maxdepth 1 -type d|sort); do
	gen_html_out ${ce##*/} checks >> /var/www/gentooqa.levelnine.at/checks.html
	gen_http_sort_main_v2 main ${ce} > ${ce}/index.html
done
for st in $(find ${SITEDIR}/stats/ -mindepth 1 -maxdepth 1 -type d|sort); do
	gen_html_out ${st##*/} stats >> /var/www/gentooqa.levelnine.at/stats.html
	gen_http_sort_main_v2 main ${st} > ${st}/index.html
done
for fl in $(find ${SITEDIR}/full_lists/ -mindepth 1 -maxdepth 1 -type d|sort); do
	gen_http_sort_main_v2 main ${fl} > ${fl}/index.html
done
gen_html_bottom >> /var/www/gentooqa.levelnine.at/stats.html
gen_html_bottom >> /var/www/gentooqa.levelnine.at/checks.html
