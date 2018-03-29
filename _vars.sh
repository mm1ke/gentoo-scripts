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
		scriptname="simplechecks.sh"
		database="gentoo_stats_test"
		databasename="sSRCtest"
		databasevalue="sNotAvailable"
		label="Broken SRC_URIs"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S) | OPENBUGS"
		info_pack="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		This check uses wget's spider functionality to check if a ebuild's SRC_URI link still works.
		The timeout to try to get a file is 15 seconds.
		EOM
		;;
	multiple_deps_on_per_line)
		scriptname="badstyle.sh"
		database="gentoo_stats_test"
		databasename="sBadstyle"
		databasevalue="sValue"
		label="Badstyle ebuilds"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Some ebuilds have multiple dependencies written on the same line. While it's not a bug it's a bad behaviour.
		Also see at: <a href="https://devmanual.gentoo.org/general-concepts/dependencies/">Link</a>
		The checks tries to find such ebuilds.
		EOM
		;;
	duplicate_uses)
		scriptname="dupuse.sh"
		database="gentoo_stats_test"				# database
		databasename="sDupuse"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Duplicate Uses"			# label of graph
		title="${label}"		# grapth title (not shown)
		info_full="CATEGORY/PACKAGE | USEFLAG(S) | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE | USEFLAG(S) | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE | USEFLAG(S) | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		This check looks per package for locally (in metadata.xml) defined use flags, which already exists as
		a global use flag.
		EOM
		;;
	unused_patches_short)
		scriptname="patchcheck.sh"
		database="gentoo_stats_test"				# database
		databasename="sPatchCheck"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Unused patches"			# label of graph
		title="${label}"		# grapth title (not shown)
		info_full="CATEGORY/PACKAGE | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE | MAINTAINER(S)"
		info_pack="PATCHES NOT USED"
		read -r -d '' chart_description <<- EOM
		This is a simple check to find unused patches per package.
		It's search funtionality is very limited but at least mostly without false positives
		EOM
		;;
	unused_patches)
		scriptname="patchtest.sh"
		database="gentoo_stats_test"				# database
		databasename="sPatchTest"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Unused patches"			# label of graph
		title="${label}"		# grapth title (not shown)
		info_full="CATEGORY/PACKAGE | PATCH/FILE | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE | PATCH/FILE | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE | PATCH/FILE | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Like unused_patches_short this check looks for unused patches in pacakges. While it's much more powerfull
		it also generates quite often false positive. A seperate whitelist file actually minimizes the output.
		EOM
		;;
	description_over_80)
		scriptname="simplechecks.sh"
		database="gentoo_stats_test"				# database
		databasename="ssDesOver80"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Description over 80"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		This simple check shows results of ebuilds which has a description longer than 80 characters.
		EOM
		;;
	dohtml_in_eapi6)
		scriptname="simplechecks.sh"
		database="gentoo_stats_test"				# database
		databasename="ssDohtmlInE6"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="dohtml in EAPI6"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		This check looks at EAPI6 ebuilds and if those ebuild are using 'dohtml', which is deprecated.
		Also see: <a href="https://blogs.gentoo.org/mgorny/2015/11/13/the-ultimate-guide-to-eapi-6/">Link</a>
		EOM
		;;
	epatch_in_eapi6)
		scriptname="simplechecks.sh"
		database="gentoo_stats_test"				# database
		databasename="ssEpatchInE6"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Epatch in EAPI6"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		epatch isn't deprecated but eapply should be used instead. This would also reduce a dependency on the eutils.eclass.
		Also see: <a href="https://blogs.gentoo.org/mgorny/2015/11/13/the-ultimate-guide-to-eapi-6/">Link</a>
		EOM
		;;
	fdo_mime_check)
		scriptname="simplechecks.sh"
		database="gentoo_stats_test"				# database
		databasename="ssFdoMimeCheck"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="fdo-mime usage"			# label of graph
		title="${label}"		# grapth title (not shown)
		info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		The fdo-mime eclass is obsolete since 2017-06-19.
		More details and how to fix ebuilds with fdo-mime can be found on <a href="https://wiki.gentoo.org/wiki/Notes_on_ebuilds_with_GUI">Link</a>
		EOM
		;;
	ebuild_egit_repo_uri)
		scriptname="simplechecks.sh"
		database="gentoo_stats_test"				# database
		databasename="ebuildEgitRepoUri"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="git:// usage"			# label of graph
		title="${label}"		# grapth title (not shown)
		info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Checks if ebuilds using git:// for git repos, which is inscure. Should be replaces with https://
		Also see: <a href="https://gist.github.com/grawity/4392747">Link</a>
		EOM
		;;
	gentoo_mirror_missuse)
		scriptname="simplechecks.sh"
		database="gentoo_stats_test"				# database
		databasename="ssMirrorMisuse"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="ebuilds using mirror://"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		This check list results of ebuilds which use mirror://gentoo in SRC_URI, which is deprecated
		See also: <a href="https://devmanual.gentoo.org/general-concepts/mirrors/">Link</a>
		EOM
		;;
	homepage_with_vars)
		scriptname="simplechecks.sh"
		database="gentoo_stats_test"				# database
		databasename="sHomepagesVars"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="ebuilds with variables in HOMEPAGE"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		This check looks for variables in the HOMEPAGE variable. While not technically a bug, this shouldn't be used.
		See Tracker bug: <a href="https://bugs.gentoo.org/408917">Link</a>
		Also see bug: <a href="https://bugs.gentoo.org/562812">Link</a>
		EOM
		;;
	leading_trailing_whitespace)
		scriptname="simplechecks.sh"
		database="gentoo_stats_test"				# database
		databasename="sLeadingTrailingVars"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="ebuilds with leading/trailing whitespaces in variables"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="VARIABLE | CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_main="VARIABLE | CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_pack="VARIABLE | CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Checks for a set of variables if those contain a leading or trailing whitespace.
		For example: SRC_URI=" www.foo.com/bar.tar.gz "
		<a href="leading-trailing-his.html">Leading/Trailing Whitespace History</a>
		EOM
		;;
	trailing_whitespaces)
		scriptname="simplechecks.sh"
		database="gentoo_stats_test"				# database
		databasename="ssTrailingWhitespace"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Trailing Whitespaces"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Simple checks which lists ebuilds who contain trailing whitespaces
		EOM
		;;
	mixed_indentation)
		scriptname="simplechecks.sh"
		database="gentoo_stats_test"				# database
		databasename="ssMixedIndentation"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Mixed Indentation"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Checks metadata files (metadata.xml) if it used tabs and whitespaces
		EOM
		;;
	proxy_maint_check)
		scriptname="simplechecks.sh"
		database="gentoo_stats_test"				# database
		databasename="ssProxyMaintainerCheck"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Proxy Maintainers"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Checks the metadata.xml of proxy maintained packages if it includes actually a
		non gentoo email address (address of proxy maintainer).
		Reason: There can't be a proxy maintained package without a proxy maintainer in
		metadata.xml
		EOM
		;;
	www_status_code)
		scriptname="wwwtest.sh"
		database="gentoo_stats_test"				# database
		databasename="sWWWtest"			# databasetable
		databasevalue="sFilteredValue"		# row of interrest
		label="Broken Websites"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		info_main="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		info_pack="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		read -r -d '' chart_description <<- EOM
		This checks tests every homepage and gets their http return code. The list contain packages with
		a bad returncode. Following statuscodes are ignored: VAR, FTP, 200, 301, 302, 307, 400, 503.
		<a href="www-sites.html">Status Code History</a>
		EOM
		;;
	www_upstream_shutdown)
		scriptname="wwwtest.sh"
		database="gentoo_stats_test"				# database
		databasename="sUpstreamShutdown"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Dead Sites"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		info_main="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		info_pack="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		read -r -d '' chart_description <<- EOM
		This checks list ebuilds which still use a homepage of a know dead site.
		Also see: <a href="https://wiki.gentoo.org/wiki/Upstream_repository_shutdowns">Link</a>
		<a href="www-sites-his.html">Broken Sites History</a>
		EOM
		;;
	301_redirections)
		scriptname="wwwtest.sh"
		database="gentoo_stats_test"				# database
		databasename="s301Redirctions"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Redirected Sites"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="(Real)HTTPCODE | CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		info_main="(Real)HTTPCODE | CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		info_pack="(Real)HTTPCODE | CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		This lists every ebuild with a Homepage which actually redirects to another or similar sites.
		The list also includes the statuscode of the real homepage.
		EOM
		;;
	redirection_http_to_https)
		scriptname="wwwtest.sh"
		database="gentoo_stats_test"				# database
		databasename="sRedirHttpToHttps"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Https Redirections"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Lists only ebuids who's homepage redirects to the same site only via HTTPS.
		Also only lists available sites.
		EOM
		;;
	redirection_missing_slash_www)
		scriptname="wwwtest.sh"
		database="gentoo_stats_test"				# database
		databasename="sRedirSlashWww"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Slash/WWW Redirections"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Lists only ebuild who's homepage redirects to the same site where there is only included a "www" or a missing "/" at the end (or both)
		Also only lists available sites.
		EOM
		;;
	unsync_homepages)
		scriptname="wwwtest.sh"
		database="gentoo_stats_test"				# database
		databasename="sUnsyncHomepages"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Unsync Homepages"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="CATEGORY/PACKAGE | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE | MAINTAINER(S)"
		info_pack="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Lists ebuilds/packages where the homepages are different over it's versions.
		EOM
		;;
	obsolete_eapi_packages)
		scriptname="eapichecks.sh"
		database="gentoo_stats_test"				# database
		databasename="sBumpNeeded"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Unattended ebuilds"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="EAPI | OTHER EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S) | OPENBUGS"
		info_main="EAPI | OTHER EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S) | OPENBUGS"
		info_pack="EAPI | OTHER EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S) | OPENBUGS"
		read -r -d '' chart_description <<- EOM
		This scirpt lists every ebuild with a EAPI 0-4. The first column prints the ebuilds EAPI, the second column
		prints the EAPI Versions of the packages other version (if available). This should make easier to find packages which
		can be removed and also package which need some attention.
		EOM
		;;
	removal_candidates)
		scriptname="eapichecks.sh"
		database="gentoo_stats_test"				# database
		databasename="sBumpNeededMatchingKeywords"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Removal canditates"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="EAPI | FILE AGE | EAPI(NV) | EBUILD AGE(NV) | CATEGORY/PACKAGE | EBUILD | EBUILD (NV) | MAINTAINER(S) | OPENBUGS"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		This script searches for ebuilds with EAPI 0-5 and checks if there is a newer reversion (-r1) which also is at EAPI6.
		If found it also checks if the KEYWORDS are the same. In this case the older versions is a good canditate to be removed.
		NV=Newer Version
		EOM
		;;
	stable_request_candidates)
		scriptname="eapichecks.sh"
		database="gentoo_stats_test"				# database
		databasename="sBumpNeededNonMatchingKeywords"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Stable request canditates"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="EAPI | FILE AGE | EAPI(NV) | EBUILD AGE(NV) | CATEGORY/PACKAGE | EBUILD | EBUILD (NV) | MAINTAINER(S) | OPENBUGS"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Also checks for ebuilds with EAPI 0-5 and a newer reversion (-r1) at EAPI6.
		In this the newer version has different KEYWORDS which most likely means it haven't been stabilized, why these ebuilds are good
		stable request canditates
		NV=Newer Version
		EOM
		;;
	eapi_statistics)
		scriptname="eapistats.sh"
		database="gentoo_stats_test"				# database
		databasename="sEapiHistory"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Eapistats"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_pack="EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		A simple list of all packages and it's corresponding EAPI Version. Also includes all maintainers to the package
		<a href=eapi-stats.html>EAPI Statistics</a>
		EOM
		;;
	ebuild_nonexist_dependency)
		scriptname="depcheck.sh"	# scriptname
		database="gentoo_stats_test"					# database
		databasename="ebuildNonexistDependency"				# databasetable
		databasevalue="sValue"			# row of interrest
		label="Obsolete Dependencies"				# label of graph
		title="${label}"						# grapth title (not shown)
		info_full="CATEGORY/PACKAGE/EBUILD | OBSOLETE DEPENDENSY(S) | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		This script checks every ebuilds *DEPEND* BLOCKS for packages which doesn't exist anymore.
		These are mostly blockers (like !app-admin/foo), which usually can be removed.
		EOM
		;;
	*)
		scriptname="scriptname.sh"	# scriptname
		database="database"					# database
		databasename="sTable"				# databasetable
		databasevalue="sValue"			# row of interrest
		label="check ebuilds"				# label of graph
		title="${label}"						# grapth title (not shown)
		info_full="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		a longer description about the script
		can be multiline
		EOM
		;;
esac


