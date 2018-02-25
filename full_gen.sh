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

#WWWDIR="/var/www/gentoo.levelnine.at/"
WORKDIR="/tmp/full-gen-${RANDOM}"
SITEDIR="/var/www/gentooqa.levelnine.at/results/"

mkdir -p ${WORKDIR}

#_dirs_to_check="patchcheck \
#	patchtest \
#	simplechecks/DESCRIPTION_over_80 \
#	simplechecks/dohtml_in_eapi6 \
#	simplechecks/epatch_in_eapi6 \
#	simplechecks/fdo-mime-check \
#	simplechecks/gentoo_mirror_missuse \
#	simplechecks/leading_trailing_whitespace_DEPEND \
#	simplechecks/leading_trailing_whitespace_DESCRIPTION \
#	simplechecks/leading_trailing_whitespace_IUSE \
#	simplechecks/leading_trailing_whitespace_KEYWORDS \
#	simplechecks/leading_trailing_whitespace_LICENSE \
#	simplechecks/leading_trailing_whitespace_RDEPEND \
#	simplechecks/leading_trailing_whitespace_SRC_URI \
#	simplechecks/mixed_indentation \
#	simplechecks/proxy-maint-check \
#	simplechecks/trailing_whitespaces \
#	srctest \
#	wwwtest \
#	wwwtest/special/unsync-homepages \
#	wwwtest/special/301_redirections \
#	wwwtest/special/301_slash_https_www \
#	wwwtest/sort-by-filter/berlios.de \
#	wwwtest/sort-by-filter/code.google.com \
#	wwwtest/sort-by-filter/codehaus.org \
#	wwwtest/sort-by-filter/fedorahosted.org \
#	wwwtest/sort-by-filter/freecode.com \
#	wwwtest/sort-by-filter/freshmeat.net \
#	wwwtest/sort-by-filter/gitorious.org \
#	wwwtest/sort-by-filter/gna.org \
#	badstyle
#	dupuse"

mkdir -p ${WORKDIR}/0_full_list/{sort-by-maintainer,sort-by-package}

for typ in IMP BUG; do

	mkdir -p ${WORKDIR}/0_full_list_${typ}/{sort-by-package,sort-by-maintainer}

	for check in ${SITEDIR}/checks/*-${typ}-*; do
		for main in $(ls ${check}/sort-by-maintainer/); do
			echo "<<< ${check##*/} >>>" >> ${WORKDIR}/0_full_list_${typ}/sort-by-maintainer/${main}
			cat ${check}/sort-by-maintainer/${main} >> ${WORKDIR}/0_full_list_${typ}/sort-by-maintainer/${main}
		done
	done

	for check in ${SITEDIR}/checks/*-${typ}-*; do
		for cat in $(ls ${check}/sort-by-package/); do
			mkdir -p ${WORKDIR}/0_full_list_${typ}/sort-by-package/${cat}
			for pack in $(ls ${check}/sort-by-package/${cat}/); do
				echo "<<< ${check##*/} >>>" >> ${WORKDIR}/0_full_list_${typ}/sort-by-package/${cat}/${pack}
				cat ${check}/sort-by-package/${cat}/${pack} >> ${WORKDIR}/0_full_list_${typ}/sort-by-package/${cat}/${pack}
			done
		done
	done

	if [ "${typ}" = "BUG" ]; then
		for cat in $(ls ${WORKDIR}/0_full_list_${typ}/sort-by-package/); do
			for pack in $(ls ${WORKDIR}/0_full_list_${typ}/sort-by-package/${cat}/); do
				echo "<<< open bugs >>>" >> ${WORKDIR}/0_full_list_${typ}/sort-by-package/${cat}/${pack}
				openbugs="$(get_bugs_full "${cat}/${pack::-4}")"
				echo "${openbugs}" >> ${WORKDIR}/0_full_list_${typ}/sort-by-package/${cat}/${pack}
			done
		done
	fi

	[ -n "${SITEDIR}/checks/0_full_list_${typ}" ] && rm -rf ${SITEDIR}/checks/0_full_list_${typ}/
	cp -r ${WORKDIR}/0_full_list_${typ} ${SITEDIR}/checks/
	rm -rf ${WORKDIR}
done

mkdir -p ${WORKDIR}/0_full_list/{sort-by-package,sort-by-maintainer}

for check in ${SITEDIR}/checks/*-*-*; do
	for main in $(ls ${check}/sort-by-maintainer/); do
		echo "<<< ${check##*/} >>>" >> ${WORKDIR}/0_full_list/sort-by-maintainer/${main}
		cat ${check}/sort-by-maintainer/${main} >> ${WORKDIR}/0_full_list/sort-by-maintainer/${main}
	done
done

for check in ${SITEDIR}/checks/*-*-*; do
	for cat in $(ls ${check}/sort-by-package/); do
		mkdir -p ${WORKDIR}/0_full_list/sort-by-package/${cat}
		for pack in $(ls ${check}/sort-by-package/${cat}/); do
			echo "<<< ${check##*/} >>>" >> ${WORKDIR}/0_full_list/sort-by-package/${cat}/${pack}
			cat ${check}/sort-by-package/${cat}/${pack} >> ${WORKDIR}/0_full_list/sort-by-package/${cat}/${pack}
		done
	done
done

for cat in $(ls ${WORKDIR}/0_full_list/sort-by-package/); do
	for pack in $(ls ${WORKDIR}/0_full_list/sort-by-package/${cat}/); do
		echo "<<< open bugs >>>" >> ${WORKDIR}/0_full_list/sort-by-package/${cat}/${pack}
		openbugs="$(get_bugs_full "${cat}/${pack::-4}")"
		echo "${openbugs}" >> ${WORKDIR}/0_full_list/sort-by-package/${cat}/${pack}
	done
done

[ -n "${SITEDIR}/checks/0_full_list" ] && rm -rf ${SITEDIR}/checks/0_full_list/
cp -r ${WORKDIR}/0_full_list ${SITEDIR}/checks/
rm -rf ${WORKDIR}

