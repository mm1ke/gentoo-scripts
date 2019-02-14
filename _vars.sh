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
		info_full="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S) | OPENBUGS"
		info_main="${info_full}"
		info_pack="${info_full}"
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
		info_full="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S) | OPENBUGS"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Packages which can't be installed because the SRC_URI is offline and RESTRICT="mirror" enabled.
		EOM
		;;
	ebuild_missing_zip_dependency)
		scriptname="srctest.sh"
		databasename="ebuildMissingZipDependency"
		databasevalue="sValue"
		label="Missing Zip Dependency"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S) | OPENBUGS"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Packages which downlaods ZIP files but misses app-arch/unzip in DEPEND.
		EOM
		;;
	ebuild_multiple_deps_per_line)
		scriptname="badstyle.sh"
		databasename="sBadstyle"
		databasevalue="sValue"
		label="Badstyle ebuilds"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Ebuilds which have multiple dependencies written in one line like:
			|| ( app-arch/foo app-arch/bar )
		Should look like:
			|| (
				app-arch/foo
				app-arch/bar
			)
		Also see at: <a href="https://devmanual.gentoo.org/general-concepts/dependencies/">Link</a>
		EOM
		;;
	metadata_duplicate_useflag_description)
		scriptname="dupuse.sh"
		databasename="sDupuse"
		databasevalue="sValue"
		label="Duplicate Uses"
		title="${label}"
		info_full="CATEGORY/PACKAGE | USEFLAG(S) | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Lists packages which define use flags locally in metadata.xml, which already exists as
		a global use flag.
		EOM
		;;
	ebuild_unused_patches_simple)
		scriptname="patchcheck.sh"
		databasename="sPatchCheck"
		databasevalue="sValue"
		label="Unused patches"
		title="${label}"
		info_full="CATEGORY/PACKAGE | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="PATCHES NOT USED"
		read -r -d '' chart_description <<- EOM
		Very limited check to find unused patches, mostly without false positives
		EOM
		;;
	ebuild_unused_patches)
		scriptname="patchtest.sh"
		databasename="sPatchTest"
		databasevalue="sValue"
		label="Unused patches"
		title="${label}"
		info_full="CATEGORY/PACKAGE | PATCH/FILE | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Extensive check to find unused pachtes. In order to reduce flase positives it uses a whilelist to exclude them.
		EOM
		;;
	ebuild_description_over_80)
		scriptname="simplechecks.sh"
		databasename="ssDesOver80"
		databasevalue="sValue"
		label="Description over 80"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Checks ebuilds if the DESCRIPTION is longer than 80 characters.
		EOM
		;;
	ebuild_dohtml_in_eapi6)
		scriptname="simplechecks.sh"
		databasename="ssDohtmlInE6"
		databasevalue="sValue"
		label="dohtml in EAPI6"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		'dohtml' is deprecated in EAPI6 and banned in EAPI7.
		This check lists EAPI6 ebuilds which still use 'dohtml'
		Also see: <a href="https://blogs.gentoo.org/mgorny/2015/11/13/the-ultimate-guide-to-eapi-6/">Link</a>
		EOM
		;;
	ebuild_epatch_in_eapi6)
		scriptname="simplechecks.sh"
		databasename="ssEpatchInE6"
		databasevalue="sValue"
		label="Epatch in EAPI6"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		'epatch' is deprecated and should be replaced by 'eapply'.
		Also see: <a href="https://blogs.gentoo.org/mgorny/2015/11/13/the-ultimate-guide-to-eapi-6/">Link</a>
		EOM
		;;
	ebuild_insecure_git_uri_usage)
		scriptname="simplechecks.sh"
		databasename="ebuildEgitRepoUri"
		databasevalue="sValue"
		label="git:// usage"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Ebuilds shouldn't use git:// for git repos because its insecure. Should be replaced with https://
		Also see: <a href="https://gist.github.com/grawity/4392747">Link</a>
		EOM
		;;
	ebuild_obsolete_gentoo_mirror_usage)
		scriptname="simplechecks.sh"
		databasename="ssMirrorMisuse"
		databasevalue="sValue"
		label="ebuilds using mirror://"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Ebuilds shouldn't use mirror://gentoo in SRC_URI because it's deprecated.
		Also see: <a href="https://devmanual.gentoo.org/general-concepts/mirrors/">Link</a>
		EOM
		;;
	ebuild_variables_in_homepages)
		scriptname="simplechecks.sh"
		databasename="sHomepagesVars"
		databasevalue="sValue"
		label="ebuilds with variables in HOMEPAGE"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Simple check to find variables in HOMEPAGE. While not technically a bug, this shouldn't be used.
		See Tracker bug: <a href="https://bugs.gentoo.org/408917">Link</a>
		Also see bug: <a href="https://bugs.gentoo.org/562812">Link</a>
		EOM
		;;
	ebuild_leading_trailing_whitespaces_in_variables)
		scriptname="trailwhite.sh"
		databasename="sLeadingTrailingVars"
		databasevalue="sValue"
		label="ebuilds with leading/trailing whitespaces in variables"
		title="${label}"
		info_full="VARIABLE | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Simple check to find leading or trailing whitespaces in a set of variables.
		For example: SRC_URI=" www.foo.com/bar.tar.gz "
		EOM
		;;
	ebuild_trailing_whitespaces)
		scriptname="simplechecks.sh"
		databasename="ssTrailingWhitespace"
		databasevalue="sValue"
		label="Trailing Whitespaces"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Simple checks which lists ebuilds who contain trailing whitespaces.
		EOM
		;;
	metadata_mixed_indentation)
		scriptname="simplechecks.sh"
		databasename="ssMixedIndentation"
		databasevalue="sValue"
		label="Mixed Indentation"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Checks metadata files (metadata.xml) if it uses mixed tabs and whitespaces.
		EOM
		;;
	metadata_missing_proxy_maintainer)
		scriptname="simplechecks.sh"
		databasename="ssProxyMaintainerCheck"
		databasevalue="sValue"
		label="Proxy Maintainers"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Checks the metadata.xml of proxy maintained packages if it includes actually a
		non gentoo email address (address of proxy maintainer).
		Reason: There can't be a proxy maintained package without a proxy maintainer in metadata.xml
		EOM
		;;
	ebuild_homepage_http_statuscode)
		scriptname="wwwtest.sh"
		databasename="ebuildHomepageStatus"
		databasevalue="sValue"
		label="Broken Websites"
		title="${label}"
		info_full="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		This checks tests every homepage and gets their http return code. The list contain packages with
		a bad returncode.
		Following statuscodes are ignored: VAR, FTP, 200, 301, 302, 307, 400, 503.
		<a href="his/www-sites.html">Status Code History</a>
		EOM
		;;
	ebuild_homepage_upstream_shutdown)
		scriptname="wwwtest.sh"
		databasename="sUpstreamShutdown"
		databasevalue="sValue"
		label="Dead Sites"
		title="${label}"
		info_full="HTTPCODE | CATEGORY/PACKAGE | EBUILD | HOMEPAGE | MAINTAINER(S) | OPENBUGS"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		This checks lists ebuilds which still use a homepage of a know dead site.
		Also see: <a href="https://wiki.gentoo.org/wiki/Upstream_repository_shutdowns">Link</a>
		EOM
		;;
	ebuild_homepage_301_redirections)
		scriptname="wwwtest.sh"
		databasename="s301Redirctions"
		databasevalue="sValue"
		label="Redirected Sites"
		title="${label}"
		info_full="(Real)HTTPCODE | CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Lists ebuilds with a Homepage which actually redirects to another sites.
		EOM
		;;
	ebuild_homepage_redirection_http_to_https)
		scriptname="wwwtest.sh"
		databasename="sRedirHttpToHttps"
		databasevalue="sValue"
		label="Https Redirections"
		title="${label}"
		info_full="EAPI | CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Lists ebuids who's homepage redirects to the same site only via HTTPS.
		EOM
		;;
	ebuild_homepage_redirection_missing_slash_www)
		scriptname="wwwtest.sh"
		databasename="sRedirSlashWww"
		databasevalue="sValue"
		label="Slash/WWW Redirections"
		title="${label}"
		info_full="EAPI | CATEGORY/PACKAGE | HOMEPAGE | HOMEPAGE(Real) | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Lists ebuild who's homepage redirects to the same site only including a "www" or a missing "/" at the end (or both)
		EOM
		;;
	ebuild_homepage_unsync)
		scriptname="wwwtest.sh"
		databasename="sUnsyncHomepages"
		databasevalue="sValue"
		label="Unsync Homepages"
		title="${label}"
		info_full="DIFFERNT SITES | CATEGORY/PACKAGE | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Lists packages who have different homepages over it's ebuild versions.
		EOM
		;;
	ebuild_obsolete_eapi)
		scriptname="eapichecks.sh"
		databasename="sBumpNeeded"
		databasevalue="sValue"
		label="Unattended ebuilds"
		title="${label}"
		info_full="EAPI | OPENBUGS | BUGSCOUNT | OTHER EAPI | FILEAGE | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		This scirpt lists every ebuild with a EAPI 0-4. The first column prints the ebuilds EAPI, the second column
		prints the EAPI Versions of the packages other version (if available). This should make easier to find packages which
		can be removed and also package which need some attention.
		EOM
		;;
	ebuild_cleanup_candidates)
		scriptname="eapichecks.sh"
		databasename="sBumpNeededMatchingKeywords"
		databasevalue="sValue"
		label="Removal canditates"
		title="${label}"
		info_full="EAPI | FILE AGE | EAPI(NV) | FILE AGE(NV) | OPENBUGS | CATEGORY/PACKAGE | EBUILD | EBUILD (NV) | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		This script searches for ebuilds with EAPI 0-5 and checks if there is a newer EAPI6 reversion (-r1).
		If found it also checks if the KEYWORDS are the same. In this case the older versions is a good canditate to be removed.
		NV=Newer Version
		EOM
		;;
	ebuild_stable_candidates)
		scriptname="eapichecks.sh"
		databasename="sBumpNeededNonMatchingKeywords"
		databasevalue="sValue"
		label="Stable request canditates"
		title="${label}"
		info_full="EAPI | FILE AGE | EAPI(NV) | FILE AGE(NV) | OPENBUGS | CATEGORY/PACKAGE | EBUILD | EBUILD (NV) | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Also checks for ebuilds with EAPI 0-5 and a newer EAPI6 reversion (-r1).
		In this the newer version has different KEYWORDS which most likely means it haven't been stabilized, why these ebuilds are good
		stable request canditates
		NV=Newer Version
		EOM
		;;
	ebuild_eapi_statistics)
		scriptname="eapistats.sh"
		databasename="sEapiHistory"
		databasevalue="sValue"
		label="Eapistats"
		title="${label}"
		info_full="EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		A simple list of all ebuilds with it's corresponding EAPI Version. Also includes all maintainers to the package
		<a href=his/eapi-stats.html>EAPI Statistics</a>
		EOM
		;;
	ebuild_eapi_live_statistics)
		scriptname="eapistats.sh"
		databasename="ebuildEapiLiveHistory"
		databasevalue="sValue"
		label="Eapistats"
		title="${label}"
		info_full="EAPI | CATEGORY/PACKAGE | EBUILD | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		A simple list of all live ebuilds and it's corresponding EAPI Version. Also includes all maintainers to the package.
		EOM
		;;
	ebuild_nonexist_dependency)
		scriptname="depcheck.sh"
		databasename="ebuildNonexistDependency"
		databasevalue="sValue"
		label="Obsolete Dependencies"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | OBSOLETE DEPENDENSY(S) | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Checks ebuilds *DEPEND* Blocks for packages which doesn't exist anymore.
		EOM
		;;
	ebuild_deprecated_eclasses)
		scriptname="deadeclasses.sh"
		databasename="ebuildObsoleteEclass"
		databasevalue="sValue"
		label="obsolete usage"
		title="${label}"
		info_full="EAPI | CATEGORY/PACKAGE | EBUILD | ECLASSES | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Lists ebuilds who use deprecated or obsolete eclasses.
		Currently looks for following eclasses:
			fdo-mime, games, git-2, ltprune, readme.gentoo, autotools-multilib, autotools-utils and versionator
		EOM
		;;
	ebuild_eclass_statistics)
		scriptname="eclassstats.sh"
		databasename="ebuildEclassStatistics"
		databasevalue="sValue"
		label="Eclasses used"
		title="${label}"
		info_full="CATEGORY/PACKAGE | EBUILD | ECLASSES | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Lists the eclasses used by every ebuild.
		Not including packages which don't inherit anything. Also not included are eclasses inherited by other eclasses.
		EOM
		;;
	packages_full_repoman)
		scriptname="repomancheck.sh"
		databasename="packagesFullRepoman"
		databasevalue="sValue"
		label="affected checks"
		title="${label}"
		info_full="CATEGORY/PACKAGE | REPOMANPROBLEMS | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="DETAILED LISTING"
		read -r -d '' chart_description <<- EOM
		A script which runs 'repoman full' on every package. The result is also filtered
		by repomans checks.
		EOM
		;;
	ebuild_missing_eclasses)
		scriptname="eclassusage.sh"
		databasename="ebuildEclassMissing"
		databasevalue="sValue"
		label="Eclasses missing"
		title="${label}"
		info_full="EAPI | CATEGORY/PACKAGE | EBUILD | MISSING ECLASSES | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Lists ebuilds which use functions of eclasses which are not directly inherited. (usually inherited implicit)
		Following eclasses are checked:
			ltprune, eutils, estack, preserve-libs, vcs-clean, epatch, desktop, versionator, user, eapi7-ver, flag-o-matic, libtool, pam, udev, xdg-utils
		EOM
		;;
	ebuild_unused_eclasses)
		scriptname="eclassusage.sh"
		databasename="ebuildEclassUnused"
		databasevalue="sValue"
		label="Eclasses unused"
		title="${label}"
		info_full="EAPI | CATEGORY/PACKAGE | EBUILD | UNUSED ECLASSES | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		Lists ebuilds which inherit eclasses but doesn't use their features.
		Following eclasses are checked:
			ltprune, eutils, estack, preserve-libs, vcs-clean, epatch, desktop, versionator, user, eapi7-ver, flag-o-matic, libtool, pam, udev, xdg-utils
		EOM
		;;
	*)
		scriptname="scriptname.sh"	# scriptname
		databasename="sTable"				# databasetable
		databasevalue="sValue"			# databaserow
		label="check ebuilds"				# label for graph
		title="${label}"						# title for graph (not shown)
		info_full="CATEGORY/PACKAGE | EBUILD | SRCFILE | MAINTAINER(S)"
		info_main="${info_full}"
		info_pack="${info_full}"
		read -r -d '' chart_description <<- EOM
		a longer description about the script
		can be multiline
		EOM
		;;
esac


