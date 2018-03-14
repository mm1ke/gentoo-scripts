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
		local title="${label}"
		local info_full="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S) | OPENBUGS"
		local info_pack="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		This check uses wget's spider functionality to check if a ebuild's SRC_URI link still works.
		The timeout to try to get a file is 15 seconds.
		EOM
		;;
	multiple_deps_on_per_line)
		local database="gentoo_stats_test"
		local databasename="sBadstyle"
		local databasevalue="sValue"
		local label="Badstyle ebuilds"
		local title="${label}"
		local info_full="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		local info_pack="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Some ebuilds have multiple dependencies written on the same line. While it's not a bug it's a bad behaviour.
		Also see at: https://devmanual.gentoo.org/general-concepts/dependencies/
		The checks tries to find such ebuilds.
		EOM
		;;
	duplicate_uses)
		local database="gentoo_stats_test"				# database
		local databasename="sDupuse"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="Duplicate Uses"			# label of graph
		local title="${label}"		# grapth title (not shown)
		local info_full="CATEGORY/PACKAGE | USEFLAG(S) | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE | USEFLAG(S) | MAINTAINER(S)"
		local info_pack="CATEGORY/PACKAGE | USEFLAG(S) | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		This check looks per package for locally (in metadata.xml) defined use flags, which already exists as
		a global use flag.
		EOM
	unused_patches_short)
		local database="gentoo_stats_test"				# database
		local databasename="sPatchCheck"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="Unused patches"			# label of graph
		local title="${label}"		# grapth title (not shown)
		local info_full="CATEGORY/PACKAGE | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE | MAINTAINER(S)"
		local info_pack="PATCHES NOT USED"
		read -r -d '' chart_description <<- EOM
		This is a simple check to find unused patches per package.
		It's search funtionality is very limited but at least mostly without false positives
		EOM
	unused_patches)
		local database="gentoo_stats_test"				# database
		local databasename="sPatchTest"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="Unused patches"			# label of graph
		local title="${label}"		# grapth title (not shown)
		local info_full="CATEGORY/PACKAGE | PATCH/FILE | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE | PATCH/FILE | MAINTAINER(S)"
		local info_pack="CATEGORY/PACKAGE | PATCH/FILE | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Like unused_patches_short this check looks for unused patches in pacakges. While it's much more powerfull
		it also generates quite often false positive. A seperate whitelist file actually minimizes the output.
		EOM
	description_over_80)
	dohtml_in_eapi6)
	epatch_in_eapi6)
	fdo_mime_check)
		local database="gentoo_stats_test"				# database
		local databasename="ssFdoMimeCheck"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="fdo-mime usage"			# label of graph
		local title="${label}"		# grapth title (not shown)
		local info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		The fdo-mime eclass is obsolete since 2017-06-19.
		More details and how to fix ebuilds with fdo-mime can be found on https://wiki.gentoo.org/wiki/Notes_on_ebuilds_with_GUI
		EOM
	gentoo_mirror_missuse)
	homepage_with_vars)
	leading_trailing_whitespace)
	trailing_whitespaces)
	www_status_code)
	www_upstream_shutdown)
	301_redirections
	redirection_http_to_https)
	redirection_missing_slash_www)
	unsync_homepages)
	obsolete_eapi_packages)
	removal_candidates)
	stable_request_candidates)
	eapi_statistics)
	*)
		local database="database"				# database
		local databasename="sTable"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="check ebuilds"			# label of graph
		local title="${label}"		# grapth title (not shown)
		local info_full="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		local info_pack="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		a longer description about the script
		can be multiline
		EOM
		exit 1
esac


