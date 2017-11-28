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


WWWDIR="/var/www/gentoo.levelnine.at/"
WORKDIR="/tmp/full-gen-${RANDOM}"

mkdir -p ${WORKDIR}

_dirs_to_check="patchcheck \
	patchtest \
	simplechecks/DESCRIPTION_over_80 \
	simplechecks/dohtml_in_eapi6 \
	simplechecks/epatch_in_eapi6 \
	simplechecks/fdo-mime-check \
	simplechecks/gentoo_mirror_missuse \
	simplechecks/leading_trailing_whitespace_DEPEND \
	simplechecks/leading_trailing_whitespace_DESCRIPTION \
	simplechecks/leading_trailing_whitespace_IUSE \
	simplechecks/leading_trailing_whitespace_KEYWORDS \
	simplechecks/leading_trailing_whitespace_LICENSE \
	simplechecks/leading_trailing_whitespace_RDEPEND \
	simplechecks/leading_trailing_whitespace_SRC_URI \
	simplechecks/mixed_indentation \
	simplechecks/proxy-maint-check \
	simplechecks/trailing_whitespaces \
	srctest \
	wwwtest"

mkdir -p ${WORKDIR}/full-sort-by-{package,maintainer}

for check in ${_dirs_to_check}; do
	for main in $(ls ${WWWDIR}/${check}/sort-by-maintainer/); do
		echo "<<< ${check} >>>" >> ${WORKDIR}/full-sort-by-maintainer/${main}
		cat ${WWWDIR}/${check}/sort-by-maintainer/${main} >> ${WORKDIR}/full-sort-by-maintainer/${main}
	done
done

for check in ${_dirs_to_check}; do
	for cat in $(ls ${WWWDIR}/${check}/sort-by-package/); do
		mkdir -p ${WORKDIR}/full-sort-by-package/${cat}
		for pack in $(ls ${WWWDIR}/${check}/sort-by-package/${cat}/); do
			echo "<<< ${check} >>>" >> ${WORKDIR}/full-sort-by-package/${cat}/${pack}
			cat ${WWWDIR}/${check}/sort-by-package/${cat}/${pack} >> ${WORKDIR}/full-sort-by-package/${cat}/${pack}
		done
	done
done

[ -n "${WWWDIR}" ] && rm -rf ${WWWDIR}/full-sort-by-*
cp -r ${WORKDIR}/* ${WWWDIR}/
rm -rf ${WORKDIR}
