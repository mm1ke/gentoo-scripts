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
		Also see at: <a href="https://devmanual.gentoo.org/general-concepts/dependencies/">Link</a>
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
		;;
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
		;;
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
		;;
	description_over_80)
		local database="gentoo_stats_test"				# database
		local databasename="ssDesOver80"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="Description over 80"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		This simple check shows results of ebuilds which has a description longer than 80 characters.
		EOM
		;;
	dohtml_in_eapi6)
		local database="gentoo_stats_test"				# database
		local databasename="ssDohtmlInE6"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="dohtml in EAPI6"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		This check looks at EAPI6 ebuilds and if those ebuild are using 'dohtml', which is deprecated.
		Also see: <a href="https://blogs.gentoo.org/mgorny/2015/11/13/the-ultimate-guide-to-eapi-6/">Link</a>
		EOM
		;;
	epatch_in_eapi6)
		local database="gentoo_stats_test"				# database
		local databasename="ssEpatchInE6"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="Epatch in EAPI6"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		epatch isn't deprecated but eapply should be used instead. This would also reduce a dependency on the eutils.eclass.
		Also see: <a href="https://blogs.gentoo.org/mgorny/2015/11/13/the-ultimate-guide-to-eapi-6/">Link</a>
		EOM
		;;
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
		More details and how to fix ebuilds with fdo-mime can be found on <a href="https://wiki.gentoo.org/wiki/Notes_on_ebuilds_with_GUI">Link</a>
		EOM
		;;
	gentoo_mirror_missuse)
		local database="gentoo_stats_test"				# database
		local databasename="ssMirrorMisuse"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="ebuilds using mirror://"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		This check list results of ebuilds which use mirror://gentoo in SRC_URI, which is deprecated
		See also: <a href="https://devmanual.gentoo.org/general-concepts/mirrors/">Link</a>
		EOM
		;;
	homepage_with_vars)
		local database="gentoo_stats_test"				# database
		local databasename="sHomepagesVars"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="ebuilds with variables in HOMEPAGE"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		This check looks for variables in the HOMEPAGE variable. While not technically a bug, this shouldn't be used.
		See Tracker bug: <a href="https://bugs.gentoo.org/408917">Link</a>
		Also see bug: <a href="https://bugs.gentoo.org/562812">Link</a>
		EOM
		;;
	leading_trailing_whitespace)
		local database="gentoo_stats_test"				# database
		local databasename="sLeadingTrailingVars"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="ebuilds with leading/trailing whitespaces in variables"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="VARIABLE | CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_main="VARIABLE | CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_pack="VARIABLE | CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Checks for a set of variables if those contain a leading or trailing whitespace.
		For example: SRC_URI=" www.foo.com/bar.tar.gz "
		<a href="leading-trailing-his.html">Leading/Trailing Whitespace History</a>
		EOM
		;;
#	trailing_whitespaces)
#	www_status_code)
#	www_upstream_shutdown)
#	301_redirections
#	redirection_http_to_https)
#	redirection_missing_slash_www)
#	unsync_homepages)
#	obsolete_eapi_packages)
#	removal_candidates)
#	stable_request_candidates)
#	eapi_statistics)
	*)
		local database="database"				# database
		local databasename="sTable"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="check ebuilds"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		local info_pack="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		a longer description about the script
		can be multiline
		EOM
		;;
esac


