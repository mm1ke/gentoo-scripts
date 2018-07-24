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
	ebuild_src_uri_check)
		scriptname="srctest.sh"
		databasename="ebuildSrcUriStatus"
		databasevalue="sValue"
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
	ebuild_src_uri_offline)
		scriptname="srctest.sh"
		databasename="ebuildSrcUriOffline"
		databasevalue="sValue"
		label="Offline Packages"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S) | OPENBUGS"
		info_pack="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Lists packages which can't be installed because the SRC_URI is offline and the
		ebuild has RESTRICT="mirror" enabled.
		EOM
		;;
	ebuild_missing_zip_dependency)
		scriptname="srctest.sh"
		databasename="ebuildMissingZipDependency"
		databasevalue="sValue"
		label="Missing Zip Dependency"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S) | OPENBUGS"
		info_pack="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		This check looks the the SRC_URI files. If there are ZIP Files to be downloaded it
		also checks if the ebuild has app-arch/unzip in it's dependencies. This is needed
		because portage won't be able to extract it otherwise.
		EOM
		;;
	ebuild_multiple_deps_per_line)
		scriptname="badstyle.sh"
		databasename="sBadstyle"
		databasevalue="sValue"
		label="Badstyle ebuilds"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Some ebuilds have multiple dependencies written on the same line. While it's not a bug it's a bad behaviour.
		As of today only looks for 'libressl' and 'openssl' on the same line
		Also see at: <a href="https://devmanual.gentoo.org/general-concepts/dependencies/">Link</a>
		The checks tries to find such ebuilds.
		EOM
		;;
	metadata_duplicate_useflag_description)
		scriptname="dupuse.sh"
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
	ebuild_unused_patches_simple)
		scriptname="patchcheck.sh"
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
	ebuild_unused_patches)
		scriptname="patchtest.sh"
		databasename="sPatchTest"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Unused patches"			# label of graph
		title="${label}"		# grapth title (not shown)
		info_full="CATEGORY/PACKAGE | PATCH/FILE | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE | PATCH/FILE | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE | PATCH/FILE | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Like ebuild_unused_patches_simple this check looks for unused patches in packages. While it's much more powerfull
		it also generates quite often false positive. A seperate whitelist file excludes false positives.
		EOM
		;;
	ebuild_description_over_80)
		scriptname="simplechecks.sh"
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
	ebuild_dohtml_in_eapi6)
		scriptname="simplechecks.sh"
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
	ebuild_epatch_in_eapi6)
		scriptname="simplechecks.sh"
		databasename="ssEpatchInE6"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Epatch in EAPI6"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		epatch is deprecated and should be replaced by eapply.
		Also see: <a href="https://blogs.gentoo.org/mgorny/2015/11/13/the-ultimate-guide-to-eapi-6/">Link</a>
		EOM
		;;
	ebuild_obsolete_fdo_mime_usage)
		scriptname="simplechecks.sh"
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
	ebuild_insecure_git_uri_usage)
		scriptname="simplechecks.sh"
		databasename="ebuildEgitRepoUri"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="git:// usage"			# label of graph
		title="${label}"		# grapth title (not shown)
		info_full="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_main="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		info_pack="CATEGORY/PACKAGE/EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		Checks if ebuilds using git:// for git repos, which is insecure. Should be replaced with https://
		Also see: <a href="https://gist.github.com/grawity/4392747">Link</a>
		EOM
		;;
	ebuild_obsolete_gentoo_mirror_usage)
		scriptname="simplechecks.sh"
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
	ebuild_variables_in_homepages)
		scriptname="simplechecks.sh"
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
	ebuild_leading_trailing_whitespaces_in_variables)
		scriptname="trailwhite.sh"
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
		EOM
		;;
	ebuild_trailing_whitespaces)
		scriptname="simplechecks.sh"
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
	metadata_mixed_indentation)
		scriptname="simplechecks.sh"
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
	metadata_missing_proxy_maintainer)
		scriptname="simplechecks.sh"
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
	ebuild_homepage_http_statuscode)
		scriptname="wwwtest.sh"
		databasename="ebuildHomepageStatus"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Broken Websites"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		info_main="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		info_pack="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		read -r -d '' chart_description <<- EOM
		This checks tests every homepage and gets their http return code. The list contain packages with
		a bad returncode. Following statuscodes are ignored: VAR, FTP, 200, 301, 302, 307, 400, 503.
		<a href="his/www-sites.html">Status Code History</a>
		EOM
		;;
	ebuild_homepage_upstream_shutdown)
		scriptname="wwwtest.sh"
		databasename="sUpstreamShutdown"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Dead Sites"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		info_main="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		info_pack="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		read -r -d '' chart_description <<- EOM
		This checks lists ebuilds which still use a homepage of a know dead site.
		Also see: <a href="https://wiki.gentoo.org/wiki/Upstream_repository_shutdowns">Link</a>
		EOM
		;;
	ebuild_homepage_301_redirections)
		scriptname="wwwtest.sh"
		databasename="s301Redirctions"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Redirected Sites"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="EAPI | (Real)HTTPCODE | CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		This lists every ebuild with a Homepage which actually redirects to another sites.
		The list also includes the statuscode of the real homepage.
		EOM
		;;
	ebuild_homepage_redirection_http_to_https)
		scriptname="wwwtest.sh"
		databasename="sRedirHttpToHttps"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Https Redirections"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="EAPI | CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Lists only ebuids who's homepage redirects to the same site only via HTTPS.
		Also only lists available sites.
		EOM
		;;
	ebuild_homepage_redirection_missing_slash_www)
		scriptname="wwwtest.sh"
		databasename="sRedirSlashWww"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Slash/WWW Redirections"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="EAPI | CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Lists only ebuild who's homepage redirects to the same site where there is only included a "www" or a missing "/" at the end (or both)
		Also only lists available sites.
		EOM
		;;
	ebuild_homepage_unsync)
		scriptname="wwwtest.sh"
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
	ebuild_obsolete_eapi)
		scriptname="eapichecks.sh"
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
	ebuild_cleanup_candidates)
		scriptname="eapichecks.sh"
		databasename="sBumpNeededMatchingKeywords"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Removal canditates"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="EAPI | FILE AGE | EAPI(NV) | FILE AGE(NV) | CATEGORY/PACKAGE | EBUILD | EBUILD (NV) | MAINTAINER(S) | OPENBUGS"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		This script searches for ebuilds with EAPI 0-5 and checks if there is a newer reversion (-r1) which also is at EAPI6.
		If found it also checks if the KEYWORDS are the same. In this case the older versions is a good canditate to be removed.
		NV=Newer Version
		EOM
		;;
	ebuild_stable_candidates)
		scriptname="eapichecks.sh"
		databasename="sBumpNeededNonMatchingKeywords"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Stable request canditates"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="EAPI | FILE AGE | EAPI(NV) | FILE AGE(NV) | CATEGORY/PACKAGE | EBUILD | EBUILD (NV) | MAINTAINER(S) | OPENBUGS"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Also checks for ebuilds with EAPI 0-5 and a newer reversion (-r1) at EAPI6.
		In this the newer version has different KEYWORDS which most likely means it haven't been stabilized, why these ebuilds are good
		stable request canditates
		NV=Newer Version
		EOM
		;;
	ebuild_eapi_statistics)
		scriptname="eapistats.sh"
		databasename="sEapiHistory"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Eapistats"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_pack="EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		A simple list of all packages and it's corresponding EAPI Version. Also includes all maintainers to the package
		<a href=his/eapi-stats.html>EAPI Statistics</a>
		EOM
		;;
	ebuild_eapi_live_statistics)
		scriptname="eapistats.sh"
		databasename="ebuildEapiLiveHistory"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Eapistats"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_pack="EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		read -r -d '' chart_description <<- EOM
		A simple list of all live packages and it's corresponding EAPI Version. Also includes all maintainers to the package.
		EOM
		;;
	ebuild_nonexist_dependency)
		scriptname="depcheck.sh"	# scriptname
		databasename="ebuildNonexistDependency"				# databasetable
		databasevalue="sValue"			# row of interrest
		label="Obsolete Dependencies"				# label of graph
		title="${label}"						# grapth title (not shown)
		info_full="CATEGORY/PACKAGE | EBUILD | OBSOLETE DEPENDENSY(S) | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		This script checks every ebuilds *DEPEND* Blocks for packages which doesn't exist anymore.
		These are mostly blockers (like !app-admin/foo).
		EOM
		;;
	ebuild_deprecated_eclasses)
		scriptname="deadeclasses.sh"
		databasename="ebuildObsoleteEclass"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="obsolete usage"			# label of graph
		title="${label}"		# grapth title (not shown)
		info_full="EAPI | CATEGORY/PACKAGE | EBUILD | ECLASSES | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		This check lists multiple eclasses which are deprecated or obsolete and should be removed.
		Currently looks for following eclasses: fdo-mime, games, git-2, ltprune, readme.gentoo and versionator
		EOM
		;;
	ebuild_eclass_statistics)
		scriptname="eclassstats.sh"
		databasename="ebuildEclassStatistics"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Eclasses used"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="CATEGORY/PACKAGE | EBUILD | ECLASSES | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		A simple list of all packages and the eclasses it's inheriting.
		Not including packages which don't inherit anything (also not included are eclasses inherited by other eclasses)
		Also includes all maintainers to the package.
		EOM
		;;
	packages_full_repoman)
		scriptname="repomancheck.sh"
		databasename="packagesFullRepoman"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="affected checks"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="CATEGORY/PACKAGE | REPOMANPROBLEMS | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="DETAILED LISTING"
		read -r -d '' chart_description <<- EOM
		This is a simple script which runs repoman full on every package and
		generates lists of found problems.
		EOM
		;;
	ebuild_missing_eclasses)
		scriptname="eclassusage.sh"
		databasename="ebuildEclassMissing"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Eclasses missing"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="EAPI | CATEGORY/PACKAGE | EBUILD | MISSING ECLASSES | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		This check looks for ebuilds, who uses eclasses which are not inherit. Usually such eclasses get inherited
		implicit by other eclasses.
		Following eclasses are checked: ltprune, eutils, estack, preserve-libs, vcs-clean, epatch, desktop, versionator, user
		EOM
		;;
	ebuild_unused_eclasses)
		scriptname="eclassusage.sh"
		databasename="ebuildEclassUnused"			# databasetable
		databasevalue="sValue"		# row of interrest
		label="Eclasses unused"			# label of graph
		title="${label}"					# grapth title (not shown)
		info_full="EAPI | CATEGORY/PACKAGE | EBUILD | UNUSED ECLASSES | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		This check looks for ebuilds who inherit a eclass but doesn't use a feature of it.
		Following eclasses are checked: ltprune, eutils, estack, preserve-libs, vcs-clean, epatch, desktop, versionator, user
		EOM
		;;
	*)
		scriptname="scriptname.sh"	# scriptname
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


