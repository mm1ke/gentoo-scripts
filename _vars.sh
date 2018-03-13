#!/bin/bash

# Filename: _vars.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 13/03/2018

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
# provides various information for all checks

dir="${1}"

case ${dir} in
	src_uri_check)
		local database="gentoo_stats_test"
		local databasename="sSRCtest"
		local databasevalue="sNotAvailable"
		local label="Broken SRC_URIs"
		local title="SRC Uri Test"			#invisible
		local data_info1="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		local data_info2="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		local data_info3="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		I check for broken SRC_URIs
		Check this out
		EOM
		;;
	multiple_deps_on_per_line)
		local database="gentoo_stats_test"
		local databasename="sBadstyle"
		local databasevalue="sValue"
		local label="Badstyle ebuilds"
		local title="SRC Uri Test"			#invisible
		local data_info1="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		local data_info2="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		local data_info3="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		I check for broken badsyle in ebuilds
		Check this out
		EOM
		;;
	*)
		exit 1
esac


