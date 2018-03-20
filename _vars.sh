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
	trailing_whitespaces)
		local database="gentoo_stats_test"				# database
		local databasename="ssTrailingWhitespace"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="Trailing Whitespaces"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		local info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Simple checks which lists ebuilds who contain trailing whitespaces
		EOM
		;;
	www_status_code)
		local database="gentoo_stats_test"				# database
		local databasename="sWWWtest"			# databasetable
		local databasevalue="sFilteredValue"		# row of interrest
		local label="Broken Websites"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		local info_main="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		local info_pack="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		read -r -d '' chart_description <<- EOM
		This checks tests every homepage and gets their http return code. The list contain packages with
		a bad returncode. Following statuscodes are ignored: VAR, FTP, 200, 301, 302, 307, 400, 503.
		<a href="www-sites.html">Status Code History</a>
		EOM
		;;
	www_upstream_shutdown)
		local database="gentoo_stats_test"				# database
		local databasename="sUpstreamShutdown"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="Dead Sites"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		local info_main="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		local info_pack="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		read -r -d '' chart_description <<- EOM
		This checks list ebuilds which still use a homepage of a know dead site.
		Also see: <a href="https://wiki.gentoo.org/wiki/Upstream_repository_shutdowns">Link</a>
		<a href="www-sites-his.html">Broken Sites History</a>
		EOM
		;;
	301_redirections)
		local database="gentoo_stats_test"				# database
		local databasename="s301Redirctions"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="Redirected Sites"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="(Real)HTTPCODE | CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		local info_main="(Real)HTTPCODE | CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		local info_pack="(Real)HTTPCODE | CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		This lists every ebuild with a Homepage which actually redirects to another or similar sites.
		The list also includes the statuscode of the real homepage.
		EOM
		;;
	redirection_http_to_https)
		local database="gentoo_stats_test"				# database
		local databasename="sRedirHttpToHttps"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="Https Redirections"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		local info_pack="CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Lists only ebuids who's homepage redirects to the same site only via HTTPS.
		Also only lists available sites.
		EOM
		;;
	redirection_missing_slash_www)
		local database="gentoo_stats_test"				# database
		local databasename="sRedirSlashWww"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="Slash/WWW Redirections"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		local info_pack="CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Lists only ebuild who's homepage redirects to the same site where there is only included a "www" or a missing "/" at the end (or both)
		Also only lists available sites.
		EOM
		;;
	unsync_homepages)
		local database="gentoo_stats_test"				# database
		local databasename="sUnsyncHomepages"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="Unsync Homepages"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="CATEGORY/PACKAGE | MAINTAINER(S)"
		local info_main="CATEGORY/PACKAGE | MAINTAINER(S)"
		local info_pack="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Lists ebuilds/packages where the homepages are different over it's versions.
		EOM
		;;
	obsolete_eapi_packages)
		local database="gentoo_stats_test"				# database
		local databasename="sBumpNeeded"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="Unattended ebuilds"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="EAPI | OTHER EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S) | OPENBUGS"
		local info_main="EAPI | OTHER EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S) | OPENBUGS"
		local info_pack="EAPI | OTHER EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S) | OPENBUGS"
		read -r -d '' chart_description <<- EOM
		This scirpt lists every ebuild with a EAPI 0-4. The first column prints the ebuilds EAPI, the second column
		prints the EAPI Versions of the packages other version (if available). This should make easier to find packages which
		can be removed and also package which need some attention.
		EOM
		;;
	removal_candidates)
		local database="gentoo_stats_test"				# database
		local databasename="sBumpNeededMatchingKeywords"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="Removal canditates"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="EAPI | FILE AGE | CATEGORY/PACKAGE | EBUILD | EAPI(NV) | EBUILD AGE(NV) | EBUILD (NV) | MAINTAINER(S) | OPENBUGS"
		local info_main="EAPI | FILE AGE | CATEGORY/PACKAGE | EBUILD | EAPI(NV) | EBUILD AGE(NV) | EBUILD (NV) | MAINTAINER(S) | OPENBUGS"
		local info_pack="EAPI | FILE AGE | CATEGORY/PACKAGE | EBUILD | EAPI(NV) | EBUILD AGE(NV) | EBUILD (NV) | MAINTAINER(S) | OPENBUGS"
		read -r -d '' chart_description <<- EOM
		This script searches for ebuilds with EAPI 0-5 and checks if there is a newer reversion (-r1) which also is at EAPI6.
		If found it also checks if the KEYWORDS are the same. In this case the older versions is a good canditate to be removed.
		NV=Newer Version
		EOM
		;;
	stable_request_candidates)
		local database="gentoo_stats_test"				# database
		local databasename="sBumpNeededNonMatchingKeywords"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="Stable request canditates"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="EAPI | FILE AGE | CATEGORY/PACKAGE | EBUILD | EAPI(NV) | EBUILD AGE(NV) | EBUILD (NV) | MAINTAINER(S) | OPENBUGS"
		local info_main="EAPI | FILE AGE | CATEGORY/PACKAGE | EBUILD | EAPI(NV) | EBUILD AGE(NV) | EBUILD (NV) | MAINTAINER(S) | OPENBUGS"
		local info_pack="EAPI | FILE AGE | CATEGORY/PACKAGE | EBUILD | EAPI(NV) | EBUILD AGE(NV) | EBUILD (NV) | MAINTAINER(S) | OPENBUGS"
		read -r -d '' chart_description <<- EOM
		Also checks for ebuilds with EAPI 0-5 and a newer reversion (-r1) at EAPI6.
		In this the newer version has different KEYWORDS which most likely means it haven't been stabilized, why these ebuilds are good
		stable request canditates
		NV=Newer Version
		EOM
		;;
	eapi_statistics)
		local database="gentoo_stats_test"				# database
		local databasename="sEapiHistory"			# databasetable
		local databasevalue="sValue"		# row of interrest
		local label="Eapistats"			# label of graph
		local title="${label}"					# grapth title (not shown)
		local info_full="EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		local info_main="EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		local info_pack="EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		A simple list of all packages and it's corresponding EAPI Version. Also includes all maintainers to the package
		<a href=eapi-stats.html>EAPI Statistics</a>
		EOM
		;;
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


