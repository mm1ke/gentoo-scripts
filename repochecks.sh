#!/bin/bash

# Filename: repochecks.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 16/05/2021

# Copyright (C) 2021  Michael Mair-Keimberger
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
# This script finds simple errors in ebuilds and other files.

#override REPOTREE,FILERESULTS,RESULTSDIR settings
#export REPOTREE=/usr/portage/
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/repochecks/"
# enabling debug output
#export DEBUG=true
#export DEBUGLEVEL=1
#export DEBUGFILE=/tmp/repostats.log

# get dirpath and load funcs.sh
realdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${realdir}/_funcs.sh ]; then
	source ${realdir}/_funcs.sh
else
	echo "Missing _funcs.sh"
	exit 1
fi

#
### IMPORTANT SETTINGS START ###
#
#${TREE_IS_MASTER} || exit 0		# only works with gentoo main tree
${ENABLE_MD5} || exit 0					# only works with md5 cache
#${ENABLE_GIT} || exit 0				# only works with git tree

# set whilelist file
if [ -z "${PT_WHITELIST}" ]; then
	WFILE="${realdir}/whitelist"
else
	WFILE="${realdir}/${PT_WHITELIST}"
fi
# try to use /usr/portage if GTREE is not set
if [ -z "${GTREE}" ]; then
	if [ "$(cat /usr/portage/profiles/repo_name)" = "gentoo" ]; then
		GTREE="/usr/portage"
	fi
fi

SCRIPT_TYPE="checks"
WORKDIR="/tmp/repochecks-${RANDOM}"
TMPCHECK="/tmp/repochecks-tmp-${RANDOM}.txt"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/ebuild_trailing_whitespaces"						# Index 0
		"${WORKDIR}/ebuild_obsolete_gentoo_mirror_usage"		# Index 1
		"${WORKDIR}/ebuild_epatch_in_eapi6"									# Index 2
		"${WORKDIR}/ebuild_dohtml_in_eapi6"									# Index 3
		"${WORKDIR}/ebuild_description_over_80"							# Index 4
		"${WORKDIR}/ebuild_variables_in_homepages"					# Index 5
		"${WORKDIR}/ebuild_insecure_git_uri_usage"					# Index 6
		"${WORKDIR}/ebuild_deprecated_eclasses"							# Index 7
		"${WORKDIR}/ebuild_leading_trailing_whitespaces_in_variables"	# Index 8
		"${WORKDIR}/ebuild_multiple_deps_per_line"					# Index 9
		"${WORKDIR}/ebuild_nonexist_dependency"							# Index 10
		"${WORKDIR}/ebuild_obsolete_virtual"								# Index 11
		"${WORKDIR}/ebuild_missing_eclasses"								# Index 12
		"${WORKDIR}/ebuild_unused_eclasses"									# Index 13
		"${WORKDIR}/ebuild_missing_eclasses_fatal"					# Index 14
		"${WORKDIR}/ebuild_homepage_upstream_shutdown"			# Index 15
		"${WORKDIR}/ebuild_homepage_unsync"									# Index 16
		"${WORKDIR}/ebuild_missing_zip_dependency"					# Index 17
		"${WORKDIR}/ebuild_src_uri_offline"									# Index 18
		"${WORKDIR}/ebuild_unused_patches_simple"						# Index 19
		"${WORKDIR}/metadata_mixed_indentation"							# Index 20
		"${WORKDIR}/metadata_missing_proxy_maintainer"			# Index 21
		"${WORKDIR}/metadata_duplicate_useflag_description"	# Index 22
		"${WORKDIR}/ebuild_insecure_pkg_post_config"				# Index 23
		"${WORKDIR}/ebuild_insecure_init_scripts"						# Index 24
		"${WORKDIR}/ebuild_homepage_bad_statuscode"					# Index 25
		"${WORKDIR}/ebuild_homepage_redirections"						# Index 26
		"${WORKDIR}/ebuild_src_uri_bad"											# Index 27
	)
}
output_format(){
	index=(
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}$(echo ${dead_ec_used[@]}|tr ' ' ':')${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}$(echo ${lt_vars_used[@]}|tr ' ' ':')${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}$(echo ${non_exist_dep[@]}|tr ' ' ':')${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}$(echo ${missing_ecl[@]}|tr ' ' ':')${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}$(echo ${obsol_ecl[@]}|tr ' ' ':')${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}$(echo ${missing_ecl_fatal[@]}|tr ' ' ':')${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}$(echo ${hp_shutdown[@]}|tr ' ' ':')${DL}${maintainer}"
		"${hp_count}${DL}${cat}/${pak}${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}$(echo ${missing_zip[@]}|tr ' ' ':')${DL}${maintainer}"
		"${ebuild_eapi}${DL}$(date -I)${DL}${cat}/${pak}${DL}${filename}${DL}$(echo ${file_offline[@]}|tr ' ' ':')${DL}${maintainer}"
		"${cat}/${pak}${DL}${maintainer}"
		"${cat}/${pak}${DL}${filename}${DL}${maintainer}"
		"${cat}/${pak}${DL}${filename}${DL}${maintainer}"
		"${cat}/${pak}${DL}$(echo ${dup_use[@]}|tr ' ' ':')${DL}${maintainer}"
		"${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${maintainer}"
		"${cat}/${pak}${DL}${maintainer}"
		"${ebuild_eapi}${DL}${statuscode}${DL}$(date -I)${DL}${cat}/${pak}${DL}${filename}${DL}${hp}${DL}${maintainer}"
		"${ebuild_eapi}${DL}${new_code}${DL}$(date -I)${DL}${cat}/${pak}${DL}${filename}${DL}${hp}${DL}${correct_site}${DL}${maintainer}"
		"${ebuild_eapi}${DL}$(date -I)${DL}${cat}/${pak}${DL}${filename}${DL}$(echo ${bad_file_status[@]}|tr ' ' ':')${DL}${maintainer}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_default0 <<- EOM
Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_default1 <<- EOM
Data Format ( dev-libs/foo|metadata.xml|dev@gentoo.org:loper@foo.de ):
dev-libs/foo                                package category/name
metadata.xml                                metadata filename
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index0 <<- EOM
Simple check to find leading or trailing whitespaces in a set of variables.
For example: SRC_URI=" www.foo.com/bar.tar.gz "

${info_default0}
EOM
read -r -d '' info_index1 <<- EOM
Ebuilds shouldn't use mirror://gentoo in SRC_URI because it's deprecated.
Also see: <a href="https://devmanual.gentoo.org/general-concepts/mirrors/">Link</a>

${info_default0}
EOM
read -r -d '' info_index2 <<- EOM
'epatch' is deprecated and should be replaced by 'eapply'.
Also see: <a href="https://blogs.gentoo.org/mgorny/2015/11/13/the-ultimate-guide-to-eapi-6/">Link</a>

${info_default0}
EOM
read -r -d '' info_index3 <<- EOM
'dohtml' is deprecated in EAPI6 and banned in EAPI7.
This check lists EAPI6 ebuilds which still use 'dohtml'
Also see: <a href="https://blogs.gentoo.org/mgorny/2015/11/13/the-ultimate-guide-to-eapi-6/">Link</a>

${info_default0}
EOM
read -r -d '' info_index4 <<- EOM
Checks ebuilds if the DESCRIPTION is longer than 80 characters.

${info_default0}
EOM
read -r -d '' info_index5 <<- EOM
Simple check to find variables in HOMEPAGE. While not technically a bug, this shouldn't be used.
See Tracker bug: <a href="https://bugs.gentoo.org/408917">Link</a>
Also see bug: <a href="https://bugs.gentoo.org/562812">Link</a>

${info_default0}
EOM
read -r -d '' info_index6 <<- EOM
Ebuilds shouldn't use git:// for git repos because its insecure. Should be replaced with https://
Also see: <a href="https://gist.github.com/grawity/4392747">Link</a>

${info_default0}
EOM
read -r -d '' info_index7 <<- EOM
Lists ebuilds who use deprecated or obsolete eclasses.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|user:cmake-utils|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
user:cmake-utils                            list obsolete eclasse(s), seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index8 <<- EOM
Simple check to find leading or trailing whitespaces in a set of variables.
For example: SRC_URI=" www.foo.com/bar.tar.gz "

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|DEPEND:SRC_URI|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
DEPEND:SRC_URI                              list of variables which have unusual whitespaces, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index9 <<- EOM
Ebuilds which have multiple dependencies written in one line like: || ( app-arch/foo app-arch/bar )
Should look like: || (
 app-arch/foo
 app-arch/bar
)
Also see at: <a href="https://devmanual.gentoo.org/general-concepts/dependencies/">Link</a>

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM

read -r -d '' info_index10 <<- EOM
This checks the ebuilds *DEPEND* Blocks for packages which doesn't exist anymore.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|sys-apps/bar:dev-libs/libdir(2015-08-13)|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
sys-apps/bar:dev-libs/libdir(2015-08-13)    non-existing package(s). If removed after git migration a removal date is shown.
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index11 <<- EOM
Lists virtuals were only one provider is still available.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index12 <<- EOM
Lists ebuilds which use functions of eclasses which are not directly inherited. (usually inherited implicit)
Following eclasses are checked:
 ltprune, eutils, estack, preserve-libs, vcs-clean, epatch,
 desktop, versionator, user, eapi7-ver, flag-o-matic, libtool, pam, udev, xdg-utils

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|user(enewuser):udev(edev_get)|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
user(enewuser):udev(edev_get)               eclasse(s) and function name the ebuild uses but not inherits, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index13 <<- EOM
Lists ebuilds which inherit eclasses but doesn't use their features.
Following eclasses are checked:
 ltprune, eutils, estack, preserve-libs, vcs-clean, epatch, desktop,
 versionator, user, eapi7-ver, flag-o-matic, libtool, pam, udev, xdg-utils

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|user:udev|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
user:udev                                   eclasse(s) the ebuild inherits but not uses, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index14 <<- EOM
Lists ebuilds which use functions of eclasses which are not directly or indirectly (implicit) inherited.
This would be an fatal error since the ebuild would use a feature which it doesn't know.
Following eclasses are checked:
 ltprune, eutils, estack, preserve-libs, vcs-clean, epatch,
 desktop, versionator, user, eapi7-ver, flag-o-matic, libtool, pam, udev, xdg-utils

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|user(enewuser):udev(edev_get)|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
user(enewuser):udev(edev_get)               eclasse(s) and function name the ebuild uses but not inherits, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index15 <<- EOM
This checks lists ebuilds which still use a homepage of a know dead upstrem site.
Also see: <a href="https://wiki.gentoo.org/wiki/Upstream_repository_shutdowns">Link</a>

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
https://foo.bar.com                         homepage(s) which are going to be removed, seperated by ':'
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index16 <<- EOM
Lists packages who have different homepages over it's ebuild versions.

Data Format ( 2|dev-libs/foo|dev@gentoo.org:loper@foo.de ):
2                                           number of different homepages found over all ebuilds
dev-libs/foo                                package category/name
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index17 <<- EOM
Packages which downlaods ZIP files but misses app-arch/unzip in DEPEND.

Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com/bar.zip|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
https://foo.bar.com/bar.zip                 zip file which is downloaded by the ebuild
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index18 <<- EOM
Packages which can't be installed because the SRC_URI is offline and RESTRICT="mirror" enabled.

Data Format ( 7|2021-06-01|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com/bar.zip|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
2021-06-01                                  date of check
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
https://foo.bar.com/bar.zip                 file which is not available and mirror restricted
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index19 <<- EOM
Very limited check to find unused patches, mostly without false positives

Data Format ( dev-libs/foo|dev@gentoo.org:loper@foo.de ):
dev-libs/foo                                package category/name
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index23 <<- EOM
Ebuilds shouldn't use chown -R or chmod -R in pkg_postinst and pkg_config. This is a security threat
Also see: <a href="http://michael.orlitzky.com/articles/end_root_chowning_now_%28make_pkg_postinst_great_again%29.xhtml">Link</a>

${info_default0}
EOM
read -r -d '' info_index24 <<- EOM
Ebuilds shouldn't use chown -R or chmod -R in init scripts. This is a security threat.
Also see: <a href="http://michael.orlitzky.com/articles/end_root_chowning_now_%28make_etc-init.d_great_again%29.xhtml">Link</a>

Data Format ( dev-libs/foo|dev@gentoo.org:loper@foo.de ):
dev-libs/foo                                package category/name
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index25 <<- EOM
This checks tests every homepage and gets their http return code. The list contain packages with a bad returncodes.
Following statuscodes are ignored: FTP, 200, 301, 302, 307, 400, 503.
This check only runs if a package changed, thus the acutal status might not be correct anymore.

Data Format ( 7|404|2021-06-01|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
404                                         http statuscode
2021-06-01                                  date of check
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
https://foo.bar.com                         homepage corresponding to the statuscode
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index26 <<- EOM
Lists ebuilds with a Homepage which actually redirects to another sites.
This check only runs if a package changed, thus the acutal status might not be correct anymore.

Data Format ( 7|404|2021-06-01|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com|https://bar.foo.com|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
404                                         http statuscode of redirected website
2021-06-01                                  date of check
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
https://foo.bar.com                         original hommepage in ebuild
https://bar.foo.com                         redirected homepage
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
read -r -d '' info_index27 <<- EOM
This check uses wget's spider functionality to check if a ebuild's SRC_URI link still works.
The timeout to try to get a file is 15 seconds.

Data Format ( 7|2021-06-01|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com/bar.zip|dev@gentoo.org:loper@foo.de ):
7                                           EAPI Version
2021-06-01                                  date of check
dev-libs/foo                                package category/name
foo-1.12-r2.ebuild                          full filename
https://foo.bar.com/bar.zip                 file which is not available
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM

# metadata checks
read -r -d '' info_index20 <<- EOM
Checks metadata files (metadata.xml) if it uses mixed tabs and whitespaces.

${info_default1}
EOM
read -r -d '' info_index21 <<- EOM
Checks the metadata.xml of proxy maintained packages if it includes actually a
non gentoo email address (address of proxy maintainer).
Reason: There can't be a proxy maintained package without a proxy maintainer in metadata.xml

${info_default1}
EOM
read -r -d '' info_index22 <<- EOM
Lists packages which define use flags locally in metadata.xml, which already exists as
a global use flag.

Data Format ( dev-libs/foo|gtk[:X:qt:zlib]|dev@gentoo.org:loper@foo.de ):
dev-libs/foo                                package category/name
gtk[:X:qt:zlib]                             list of USE flags which already exists as a global flag.
dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
EOM
	description=( "${info_index0}" "${info_index1}" "${info_index2}" \
		"${info_index3}" "${info_index4}" "${info_index5}" "${info_index6}" \
		"${info_index7}" "${info_index8}" "${info_index9}" "${info_index10}" \
		"${info_index11}" "${info_index12}" "${info_index13}" "${info_index14}" \
		"${info_index15}" "${info_index16}" "${info_index17}" "${info_index18}" \
		"${info_index19}" "${info_index20}" "${info_index21}" "${info_index22}" \
		"${info_index23}" "${info_index24}" "${info_index25}" "${info_index26}" \
		"${info_index27}"
	)
	echo "${description[$1]}"
}
#
### IMPORTANT SETTINGS END ###
#

ebuild-check() {
	array_names
	[ ${DEBUGLEVEL} -ge 2 ] && echo "generating standard information for ${1}" | (debug_output)

	local rel_path=${1}																									# path relative to ${REPOTREE}:	./app-admin/salt/salt-0.5.2.ebuild
	local cat="$(echo ${rel_path}|cut -d'/' -f1)"												# package category:							app-admin
	local pak="$(echo ${rel_path}|cut -d'/' -f2)"												# package name:									salt
	local filename="$(echo ${rel_path}|cut -d'/' -f3)"									# package filename:							salt-0.5.2.ebuild
	local pakname="${filename%.*}"																			# package name-version:					salt-0.5.2
	local pakver="${pakname/${pak}-/}"																	# package version								0.5.2
	local abs_path="${REPOTREE}/${cat}/${pak}"													# full path:										/usr/portage/app-admin/salt
	local abs_path_ebuild="${REPOTREE}/${cat}/${pak}/${filename}"				# full path ebuild:							/usr/portage/app-admin/salt/salt-0.5.2.ebuild
	local abs_md5_path="${REPOTREE}/metadata/md5-cache/${cat}/${pakname}" # full md5 path:							/usr/portage/metadata/md5-cache/app-admin/salt-0.5.2

	[ ${DEBUGLEVEL} -ge 2 ] && echo "generating detailed information for ${1}" | (debug_output)
	local maintainer="$(get_main_min "${cat}/${pak}")"									# maintainer of package:				foo@gentoo.org:bar@gmail.com
	local ebuild_eapi="$(get_eapi ${rel_path})"													# eapi of ebuild:								6

	output(){
		local checkid=${1}
		if ${FILERESULTS}; then
			output_format ${checkid} >> ${RUNNING_CHECKS[${checkid}]}/full.txt
		else
			echo "${RUNNING_CHECKS[${checkid}]##*/}${DL}$(output_format ${checkid})"
		fi
	}

	# trailing whitespace
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for trailing whitespaces" | (debug_output)
	$(egrep -q " +$" ${rel_path}) && output 0

	# mirror usage
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for mirror:// usage" | (debug_output)
	$(grep -q 'mirror://gentoo' ${rel_path}) && output 1

	if [ "${ebuild_eapi}" = "6" ]; then
		[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for epatch/dohtml usage" | (debug_output)
		# epatch usage
		$(grep -q "\<epatch\>" ${rel_path}) && output 2
		# dohtml usage
		$(grep -q "\<dohtml\>" ${rel_path}) && output 3
	fi
	# DESCRIPTION over 80
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for description over 80" | (debug_output)
	[ $(grep DESCRIPTION ${abs_md5_path} | wc -m) -gt 95 ] && output 4

	# HOMEPAGE with variables
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for variables in homepages" | (debug_output)
	if $(grep -q "HOMEPAGE=.*\${" ${rel_path}); then
		$(grep -q 'HOMEPAGE=.*${HOMEPAGE}' ${rel_path}) && output 5
	fi
	# insecure git usage
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for git:// usage" | (debug_output)
	$(grep -q "EGIT_REPO_URI=\"git://" ${rel_path}) && output 6

	# dead eclasses
	local _dead_eclasses=( readme.gentoo base bash-completion boost-utils clutter \
		cmake-utils confutils distutils epatch fdo-mime games gems git-2 gpe \
		gst-plugins-bad gst-plugins-base gst-plugins-good gst-plugins-ugly \
		gst-plugins10 ltprune mono python ruby user versionator x-modular xfconf )
	local dead_ec_used=( )
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for DEAD eclasses usage" | (debug_output)
	for dead_eclass in ${_dead_eclasses[@]}; do
		if $(check_eclasses_usage ${rel_path} ${dead_eclass}); then
			dead_ec_used+=( ${dead_eclass} )
		fi
	done
	[ -n "${dead_ec_used}" ] && output 7

	# trailing/leading whitespaces in variables
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for trailing leading whitespaces in certain variables" | (debug_output)
	local _varibales="DESCRIPTION LICENSE KEYWORDS IUSE RDEPEND DEPEND SRC_URI"
	local lt_vars_used=( )
	for var in ${_varibales}; do
		if $(egrep -q "^${var}=\" |^${var}=\".* \"$" ${rel_path}); then
			lt_vars_used+=( ${var} )
		fi
	done
	[ -n "${lt_vars_used}" ] && output 8

	# badstyle in ebuilds
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for badstyle in ebuilds" | (debug_output)
	if $(grep -q "DEPEND" ${rel_path}); then
		local used_cats=( )
		local repo_cat
		for repo_cat in ${CATEGORIES}; do
			if $(grep DEPEND ${abs_md5_path} | grep -q ${repo_cat}); then
				used_cats+=( "${repo_cat}" )
			fi
		done

		if [ -n "${used_cats}" ]; then
			#remove duplicates from found categories
			cat_to_check=($(printf "%s\n" "${used_cats[@]}" | sort -u))

			x=0
			y="${#cat_to_check[@]}"
			z=( )

			for a in ${cat_to_check[@]}; do
				for b in ${cat_to_check[@]:${x}:${y}}; do
					if [ "${a}" = "${b}" ]; then
						z+=( "${a}/.*${b}/.*" )
					else
						z+=( "${a}/.*${b}/.*|${b}/.*${a}/.*" )
					fi
				done
				# search the pattern
				x=$(expr ${x} + 1)
			done


			if $(grep "^[^#;]" ${rel_path} | egrep -q "$(echo ${z[@]}|tr ' ' '|')" ); then
				output 9
			fi
		fi
	fi

	# dependency checks
	if ${TREE_IS_MASTER}; then
		[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for noexist dependencies" | (debug_output)
		if $(grep -q "DEPEND" ${rel_path}); then
			local non_exist_dep=()
			local _dependencies=( $(grep DEPEND ${abs_md5_path}|grep -oE "[a-zA-Z0-9-]{3,30}/[+a-zA-Z_0-9-]{2,80}"|sed 's/-[0-9].*//g'|sort -u) )

			for dep in ${_dependencies[@]}; do
				if $(grep ${dep} ${rel_path} >/dev/null 2>&1); then
					if ! [ -e "${REPOTREE}/${dep}" ]; then
						# provide gitage if git is available
						if ${ENABLE_GIT}; then
							local deadage="$(get_age_last "${dep}")"
							if [ -n "${deadage}" ]; then
								dep="${dep}(${deadage})"
							fi
						fi
						non_exist_dep+=( "${dep}" )
						found=true
					fi
				fi
			done

			if [ -n "${non_exist_dep=}" ] && [ "${cat}" = "virtual" ]; then
				if [ $(expr ${#_dependencies[@]}) -eq 1 ] && [ $(grep ${_dependencies[0]} ${rel_path} | wc -l) -gt 1 ]; then
					continue
				else
					if [ $(expr ${#_dependencies[@]} - ${#non_exist_dep[@]}) -le 1 ]; then
						output 11
					fi
				fi
			fi

			[ -n "${non_exist_dep}" ] && output 10
		fi
	fi

	# eclass checks, only check if ECLASSES is not empty
	if [ -n "${ECLASSES}" ]; then
		[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for eclass misusage" | (debug_output)
		if $(grep -q "inherit" ${rel_path}); then
			if [ "${ebuild_eapi}" = "6" ] || [ "${ebuild_eapi}" = "7" ]; then

				local obsol_ecl=( )
				local missing_ecl=( )
				local missing_ecl_fatal=( )
				local func_in_use=( )
				local func_in_use_fatal=( )

				for echeck in ${ECLASSES}; do
					local eclass="$(echo ${echeck}|cut -d';' -f1)"
					local eclass_funcs="$(echo ${echeck}|cut -d';' -f2|tr ':' ' ')"

					# don't check for eapi7-ver at EAPI=7 ebuilds
					if [ "${eclass}" = "eapi7-ver" ] && [ "${ebuild_eapi}" = "7" ]; then
						continue
					fi

					# check if ebuild uses ${eclass}
					if $(check_eclasses_usage ${rel_path} ${eclass}); then
						# check if ebuild uses one of the functions provided by the eclass
						local catch=false
						for i in ${eclass_funcs}; do
							if $(grep -qP "^(?!#).*(?<!-)((^|\W)${i}(?=\W|$))" ${rel_path}); then
								catch=true
								break
							fi
						done
						${catch} || obsol_ecl+=( ${eclass} )
					# check the ebuild if one the eclass functions are used
					else
						# get the fucntion(s) which are used by the ebuild, if any
						for e in ${eclass_funcs}; do
							if $(grep -qP "^(?!.*#).*(?<!-)((^|\W)${e}(?=\W|$))" ${rel_path}); then
								# check if ebuild provides function by its own
								if ! $(grep -qP "^(?!.*#).*(?<!-)(${e}\(\)(?=\s|$))" ${rel_path}); then
									# if the ebuild uses one of the function, check if the eclass is
									# inherited implicit (most likley), otherwise it's a clear error
									local all_eclasses="$(get_eclasses_real_v2 "${cat}/${pak}/${pakname}")"
									if ! $(echo "${all_eclasses}" | grep -q ${eclass}); then
										func_in_use_fatal+=( ${e} )
									fi
									func_in_use+=( ${e} )
								fi
							fi
						done
						[ -n "${func_in_use}" ] && \
							missing_ecl+=( "${eclass}($(echo ${func_in_use[@]}|tr ' ' ','))" )
						[ -n "${func_in_use_fatal}" ] && \
							missing_ecl_fatal+=( "${eclass}($(echo ${func_in_use_fatal[@]}|tr ' ' ','))" )
					fi
					func_in_use=( )
					func_in_use_fatal=( )
				done

				[ -n "${missing_ecl}" ] && output 12
				[ -n "${obsol_ecl}" ] && output 13
				[ -n "${missing_ecl_fatal}" ] && output 14
			fi
		fi
	fi

	# check for upstream shutdowns
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for dead upstreams" | (debug_output)
	_filters=(
		'berlios.de' 'gitorious.org' 'codehaus.org' 'code.google.com'
		'fedorahosted.org' 'gna.org' 'freecode.com' 'freshmeat.net'
	)
	local site single_hp
	local hp_shutdown=( )
	local ebuild_hps="$(grep ^HOMEPAGE= ${abs_md5_path}|cut -d'=' -f2-)"
	for site in ${_filters[@]}; do
		for single_hp in ${ebuild_hps}; do
			if $(echo ${single_hp}|grep -q ${site}); then
				hp_shutdown+=( ${single_hp} )
			fi
		done
	done
	[ -n "${hp_shutdown}" ] && output 15

	# check if upstream source is available (only if mirror restricted) + missing
	# unzip dependency
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for unavailable upstreams + missing unzip dependency" | (debug_output)
	local _src_links=( $(grep ^SRC_URI= ${abs_md5_path}|cut -d'=' -f2-) )
	local missing_zip=( )
	local file_offline=( )
	local bad_file_status=( )
	if [ -n "${_src_links}" ]; then
		for l in ${_src_links}; do
			if $(echo ${l} | grep -q -E "^http://|^https://"); then
				# missing zip dep
				if [ "$(echo ${l: -4})" == ".zip" ]; then
					if ! $(grep -q "app-arch/unzip" ${abs_md5_path}); then
						missing_zip+=( ${l} )
					fi
				fi
				# exclude ebuilds which inherit one of the following eclasses:
				# toolchain-binutils toolchain-glibc texlive-module
				# these generate lots of false postive by generating SRC_URI via the
				# eclasses
				if ! $(get_eclasses "${cat}/${pak}/${pakname}" | grep -q -E "toolchain-binutils|toolchain-glibc|texlive-module"); then
					if $(get_file_status_detailed ${l}); then
						if $(grep -q -e "^RESTRICT=.*mirror" ${rel_path}); then
							# offline (restrict)
							file_offline+=( ${l} )
						fi
						bad_file_status+=( ${l} )
					fi
				fi
			fi
		done
		[ -n "${missing_zip}" ] && output 17
		[ -n "${file_offline}" ] && output 18
		[ -n "${bad_file_status}" ] && output 27
	fi

	# inscure pkg_config or pkg_postinst
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for insecure chown/chmod usage" | (debug_output)
	if $(grep -q -E "^pkg_config|^pkg_postinst" ${rel_path}); then
		if $(awk '/^pkg_config|^pkg_postinst/,/^}/' ${rel_path} | grep -q -P "^\tchmod -R|^\tchown -R"); then
			output 23
		fi
	fi
}

package-check(){
	array_names
	local rel_path=${1}																		# path relative to ${REPOTREE}:	./app-admin/salt/
	local cat="$(echo ${rel_path}|cut -d'/' -f1)"					# package category:							app-admin
	local pak="$(echo ${rel_path}|cut -d'/' -f2)"					# package name:									salt
	local maintainer="$(get_main_min "${cat}/${pak}")"		# maintainer of package:				foo@gentoo.org:bar@gmail.com

	output(){
		local checkid=${1}
		if ${FILERESULTS}; then
			output_format ${checkid} >> ${RUNNING_CHECKS[${checkid}]}/full.txt
		else
			echo "${RUNNING_CHECKS[${checkid}]##*/}${DL}$(output_format ${checkid})"
		fi
	}

	# check for unsync homepages
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for unsync homepages" | (debug_output)
	local hp_count="$(grep "^HOMEPAGE=" ${REPOTREE}/metadata/md5-cache/${cat}/${pak}-[0-9]* | cut -d'=' -f2|sort -u |wc -l)"
	[ "${hp_count}" -gt 1 ] && output 16

	# simple patchtest
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for unused patches (simple)" | (debug_output)
	local eclasses="apache-module|elisp|vdr-plugin-2|ruby-ng|readme.gentoo|readme.gentoo-r1|java-vm-2|php-ext-source-r3|selinux-policy-2|toolchain-glibc"
	if [ -d "${REPOTREE}/${rel_path}/files" ]; then
		if ! $(echo ${WHITELIST}|grep -q "${cat}/${pak}"); then
			if ! $(grep -q -E ".diff|.patch|FILESDIR|${eclasses}" ${REPOTREE}/${rel_path}/*.ebuild); then
				output 19
			fi
		fi
	fi

	# insecure chown/chown in init scripts
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for insecure chown/chmod usage in init scripts" | (debug_output)
	if [ -d "${REPOTREE}/${rel_path}/files" ]; then
		local init_count=( $(find ${REPOTREE}/${rel_path}/files/ -maxdepth 1 -name "*init*" ) )
		if [ ${#init_count[@]} -gt 0 ]; then
			if $(awk '/^start/,/^}/' ${REPOTREE}/${rel_path}/files/*init* | grep -q -P "chmod -R|chown -R|chmod --recursive|chown --recursive"); then
				if ! $(awk '/^start/,/^}/' ${REPOTREE}/${rel_path}/files/*init* | grep -q "checkpath"); then
					output 24
				fi
			fi
		fi
	fi

	# check if homepage is reachable and if it redirects to another link.
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for unreachable sites or homepage which redirect" | (debug_output)
	for eb in ${REPOTREE}/${rel_path}/*.ebuild; do
		local ebuild_eapi="$(get_eapi ${eb})"
		local ebuild=$(basename ${eb%.*})
		local filename="${ebuild}.ebuild"
		local cat="$(echo ${rel_path}|cut -d'/' -f1)"													# package category:						app-admin
		local abs_md5_path="${REPOTREE}/metadata/md5-cache/${cat}/${ebuild}"	# full md5 path:							/usr/portage/metadata/md5-cache/app-admin/salt-0.5.2

		local ebuild_hps="$(grep ^HOMEPAGE= ${abs_md5_path}|cut -d'=' -f2-)"

		if [ -n "${ebuild_hps}" ]; then
			local hp
			for hp in ${ebuild_hps}; do
				[ ${DEBUGLEVEL} -ge 2 ] && echo "checking following sites: ${ebuild_hps}" | (debug_output)
				if $(echo ${hp}|grep -q ^ftp); then
					[ ${DEBUGLEVEL} -ge 2 ] && echo "${hp} is a ftp link" | (debug_output)
					local statuscode="FTP"
				else
					local _checktmp="$(grep "${DL}${hp}${DL}" ${TMPCHECK}|head -1)"
					if [ -z "${_checktmp}" ]; then
						[ ${DEBUGLEVEL} -ge 2 ] && echo "checking site status ${hp}" | (debug_output)
						local statuscode="$(get_site_status ${hp})"
						echo "${ebuild_eapi}${DL}${statuscode}${DL}${hp}${DL}" >> ${TMPCHECK}
					else
						[ ${DEBUGLEVEL} -ge 2 ] && echo "found ${hp} in ${TMPCHECK}" | (debug_output)
						statuscode="${_checktmp:2:3}"
					fi
				fi

				case ${statuscode} in
					301)
						local correct_site="$(curl -Ls -o /dev/null --silent --max-time 20 --head -w %{url_effective} ${hp})"
						local new_code="$(get_site_status ${correct_site})"
						output 26
						;;
					FTP|200|302|307|400|429|503)
						continue
						;;
					*)
						output 25
						;;
				esac
			done
		fi
	done
}

metadata-check(){
	array_names
	local rel_path=${1}																		# path relative to ${REPOTREE}:	./app-admin/salt/metadata.xml
	local cat="$(echo ${rel_path}|cut -d'/' -f1)"					# package category:							app-admin
	local pak="$(echo ${rel_path}|cut -d'/' -f2)"					# package name:									salt
	local maintainer="$(get_main_min "${cat}/${pak}")"		# maintainer of package:				foo@gentoo.org:bar@gmail.com

	output(){
		local checkid=${1}
		if ${FILERESULTS}; then
			output_format ${checkid} >> ${RUNNING_CHECKS[${checkid}]}/full.txt
		else
			echo "${RUNNING_CHECKS[${checkid}]##*/}${DL}$(output_format ${checkid})"
		fi
	}

	# mixed indentation
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for mixed indentation" | (debug_output)
	if $(grep -q "^ " ${rel_path}); then
		$(grep -q $'\t' ${rel_path}) && output 20
	fi

	# missing proxy maintainer
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for missing proxy maintainer mails" | (debug_output)
	local _found_go_mail=false
	if $(grep -q "proxy-maint@gentoo.org" ${rel_path}); then
		local i
		for i in $(echo ${maintainer}|tr ':' '\n'); do
			if ! $(echo ${i} | grep -q "@gentoo.org"); then
				_found_go_mail=true
			fi
		done
		${_found_go_mail} || output 21
	fi

	# duplicate use flag description
	[ ${DEBUGLEVEL} -ge 2 ] && echo "checking for dupclicate use flag description" | (debug_output)
	if ${TREE_IS_MASTER}; then
		local _localuses="$(grep "flag name" ${rel_path} | cut -d'"' -f2)"
		local dup_use=( )

		if [ -n "${_localuses}" ]; then
			for use in ${_localuses}; do
				if $(tail -n+6 ${REPOTREE}/profiles/use.desc|cut -d'-' -f1|grep "\<${use}\>" > /dev/null); then
					dup_use+=( ${use} )
				fi
			done
		fi
		[ -n "${dup_use}" ] && output 22
	fi
}

# create a list of categories in ${REPOTREE}
gen_repo_categories(){
	local all_cat=( $(find ${REPOTREE} -mindepth 1 -maxdepth 1 -type d -regextype sed -regex "./*[a-z0-9].*-[a-z0-9].*" -printf '%P\n') )
	[ -e ${REPOTREE}/virtual ] && all_cat+=( "virtual" )

	CATEGORIES="$(echo ${all_cat[@]})"
	export CATEGORIES
}

# certain set of ebuilds which we check for their functions. For this check we
# need to know where the main gentoo tree resides. GTREE is usually set in qa.sh
gen_eclass_funcs(){
	if [ -n "${GTREE}" ]; then
		# a list of eclass which we going to check
		local etc=( optfeature wrapper edos2unix ltprune l10n eutils estack preserve-libs \
			vcs-clean epatch desktop versionator user user-info flag-o-matic xdg-utils \
			libtool udev eapi7-ver pam ssl-cert toolchain-funcs )

		local eclasses_with_funcs=( )

		local i x
		for i in ${etc[@]}; do
			# check if the eclass exports functions (these eclass cannot be checked)
			if ! $(grep -q "EXPORT_FUNCTIONS" /${GTREE}/eclass/${i}.eclass); then
				# get all functions of the eclass
				local efuncs="$(sed -n 's/# @FUNCTION: //p' "/${GTREE}/eclass/${i}.eclass" | sed ':a;N;$!ba;s/\n/ /g')"
				local f=( )
				# only continue if we found functions
				if [ -n "${efuncs}" ]; then
					for x in ${efuncs}; do
						if ! $(grep "@FUNCTION: ${x}" -A3 -m1 /${GTREE}/eclass/${i}.eclass |grep -q "@INTERNAL"); then
							case "${i}" in
								eutils)
									case "${x}" in
										usex) continue ;;					#available from EAPI6
										in_iuse) continue ;;			#available from EAPI6
										eqawarn) continue ;;			#ignore for now
										einstalldocs) continue ;;	#available from EAPI6
										*) f+=( "${x}" )
									esac ;;
								toolchain-funcs)
									case "${x}" in
										gen_usr_ldscript) continue ;;		#deprecated, use it from usr-ldscriplt.eclass
										*) f+=( "${x}" )
									esac ;;
								*)
									f+=( "${x}" ) ;;
							esac
						fi
					done
					eclasses_with_funcs+=( "$(echo ${i##*/}|cut -d '.' -f1);$(echo ${f[@]}|tr ' ' ':')" )
				fi
			else
				echo "ERR: ${i} exports functions"
			fi
		done

		ECLASSES="$(echo ${eclasses_with_funcs[@]})"
		export ECLASSES
	fi
}

gen_whitelist(){
	local _wlist=( )
	if [ -e ${WFILE} ]; then
		source ${WFILE}
		for i in ${white_list[@]}; do
			_wlist+=("$(echo ${i}|cut -d';' -f1)")
		done
	else
		_wlist=()
	fi
	# remove duplicates
	mapfile -t _wlist < <(printf '%s\n' "${_wlist[@]}"|sort -u)

	WHITELIST="$(echo ${_wlist[@]})"
	export WHITELIST
}

find_func(){
	[ ${DEBUGLEVEL} -ge 1 ] && echo "starting find with MIND:${MIND} and MAXD:${MAXD}" | (debug_output)

	if [ ${DEBUGLEVEL} -ge 2 ]; then
		[ ${DEBUGLEVEL} -ge 2 ] && echo "NORMAL run: searchpattern is ${searchp[@]}" | (debug_output)
		find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.ebuild" -print 2>/dev/null | while read -r line; do ebuild-check ${line}; done

		find ${searchp[@]} -mindepth ${MIND} -maxdepth ${MAXD} \
			-type d -print 2>/dev/null | while read -r line; do package-check ${line}; done

		find ${searchp[@]} -mindepth ${MIND} -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.xml" -print 2>/dev/null | while read -r line; do metadata-check ${line}; done
	else
		[ ${DEBUGLEVEL} -ge 1 ] && echo "PARALLEL run: searchpattern is ${searchp[@]}" | (debug_output)
		find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.ebuild" -print 2>/dev/null | parallel ebuild-check {}

		find ${searchp[@]} -mindepth ${MIND} -maxdepth ${MAXD} \
			-type d -print 2>/dev/null | parallel package-check {}

		find ${searchp[@]} -mindepth ${MIND} -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.xml" -print 2>/dev/null | parallel metadata-check {}
	fi

	# check for empty results and remove them
	clean_results

	[ ${DEBUGLEVEL} -ge 2 ] && echo "fileresults is: ${FILERESULTS}" | (debug_output)
	if ${FILERESULTS}; then
		[ ${DEBUGLEVEL} -ge 1 ] && echo "calling gen_descriptions" | (debug_output)
		gen_descriptions
		[ ${DEBUGLEVEL} -ge 1 ] && echo "calling sort_result_v4" | (debug_output)
		sort_result_v4

		#gen_sort_eapi_v1 ${RUNNING_CHECKS[1]}
		[ ${DEBUGLEVEL} -ge 1 ] && echo "calling sort_filter" | (debug_output)
		gen_sort_filter_v1 4 ${RUNNING_CHECKS[7]}
		gen_sort_filter_v1 4 ${RUNNING_CHECKS[8]}
		gen_sort_filter_v1 4 ${RUNNING_CHECKS[10]}
		gen_sort_filter_v1 4 ${RUNNING_CHECKS[12]}
		gen_sort_filter_v1 4 ${RUNNING_CHECKS[13]}
		gen_sort_filter_v1 4 ${RUNNING_CHECKS[14]}
		gen_sort_filter_v1 4 ${RUNNING_CHECKS[15]}
		gen_sort_filter_v1 2 ${RUNNING_CHECKS[22]}
		gen_sort_filter_v1 2 ${RUNNING_CHECKS[25]}

		[ ${DEBUGLEVEL} -ge 1 ] && echo "calling sort_main_v4" | (debug_output)
		gen_sort_main_v4
		[ ${DEBUGLEVEL} -ge 1 ] && echo "calling sort_pak_v4" | (debug_output)
		gen_sort_pak_v4

		[ ${DEBUGLEVEL} -ge 1 ] && echo "calling copy_checks" | (debug_output)
		copy_checks ${SCRIPT_TYPE}
	fi
}

[ ${DEBUGLEVEL} -ge 1 ] && echo "*** starting repochecks" | (debug_output)

cd ${REPOTREE}
touch ${TMPCHECK}
array_names
gen_eclass_funcs
gen_repo_categories
gen_whitelist
${FILERESULTS} && mkdir -p ${RUNNING_CHECKS[@]}
export -f metadata-check ebuild-check package-check array_names output_format
export WORKDIR TMPCHECK
depth_set_v3 ${1}
${FILERESULTS} && rm -rf ${WORKDIR}
rm ${TMPCHECK}

[ ${DEBUGLEVEL} -ge 1 ] && echo "*** finished repostats" | (debug_output)
