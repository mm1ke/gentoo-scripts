#!/bin/bash

# Filename: repochecks.sh
# Autor: Michael Mair-Keimberger (mmk AT levelnine DOT at)
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
# This script finds simple errors in ebuilds.

#override REPOTREE,FILERESULTS,RESULTSDIR settings
#export REPOTREE=/usr/portage/
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/$(basename ${0})/"
# enabling debug output
#export DEBUG=true
#export DEBUGLEVEL=1
#export DEBUGFILE=/tmp/${0}.log

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
${ENABLE_MD5} || exit 0					# only works with md5 cache
#${ENABLE_GIT} || exit 0				# only works with git tree

# set whilelist file
if [ -z "${PT_WHITELIST}" ]; then
	WFILE="${realdir}/whitelist"
else
	WFILE="${realdir}/${PT_WHITELIST}"
fi
# try to use default portage tree if GTREE is not set
if [ -z "${GTREE}" ]; then
	gtree_location="$(grep location /etc/portage/repos.conf/gentoo.conf | cut -d' ' -f3)"
	if [ "$(cat ${gtree_location}/profiles/repo_name)" = "gentoo" ]; then
		GTREE="${gtree_location}"
	fi
fi

SCRIPT_TYPE="checks"
WORKDIR="/tmp/$(basename ${0})-${RANDOM}"
TMPCHECK="/tmp/$(basename ${0})-tmp-${RANDOM}.txt"
TMPIPCHECK="/tmp/$(basename ${0})-tmpip-${RANDOM}.txt"

array_names(){
	SELECTED_CHECKS=(
		eb_iwfi
		eb_obdt
		eb_obsr
		eb_obds
		eb_obvi eb_node
		eb_vamb
		eb_ingu
		eb_ltwv
		eb_mude
		eb_miec eb_unec eb_mief
		eb_mizd eb_sruo eb_srub
		eb_srsm eb_srfo
		eb_inpp
		pa_unpa
		pa_inis
		pa_hobs pa_hore #pa_hobr #- disable this check for now - needs api key
		pa_pksc
		me_miin
		me_mipm
		me_duud
		me_mmri
	)
	declare -gA FULL_CHECKS=(
		[eb_iwfi]="${WORKDIR}/ebuild_install_worthless_file_install"
		[eb_obdt]="${WORKDIR}/ebuild_obsolete_dependency_tracking"
		[eb_obsr]="${WORKDIR}/ebuild_obsolete_silent_rules"
		[eb_obds]="${WORKDIR}/ebuild_obsolete_disable_static"
		[eb_obvi]="${WORKDIR}/ebuild_obsolete_virtual"
		[eb_node]="${WORKDIR}/ebuild_nonexist_dependency"
		[eb_vamb]="${WORKDIR}/ebuild_variable_missing_braces"
		[eb_ingu]="${WORKDIR}/ebuild_insecure_git_uri_usage"
		[eb_ltwv]="${WORKDIR}/ebuild_leading_trailing_whitespaces_in_variables"
		[eb_mude]="${WORKDIR}/ebuild_multiple_deps_per_line"
		[eb_miec]="${WORKDIR}/ebuild_missing_eclasses"
		[eb_unec]="${WORKDIR}/ebuild_unused_eclasses"
		[eb_mief]="${WORKDIR}/ebuild_missing_eclasses_fatal"
		[eb_mizd]="${WORKDIR}/ebuild_missing_zip_dependency"
		[eb_sruo]="${WORKDIR}/ebuild_src_uri_offline"
		[eb_srub]="${WORKDIR}/ebuild_src_uri_bad"
		[eb_srfo]="${WORKDIR}/ebuild_src_uri_file_offline"
		[eb_srsm]="${WORKDIR}/ebuild_src_uri_size_mismatch"
		[eb_inpp]="${WORKDIR}/ebuild_insecure_pkg_post_config"
		[pa_unpa]="${WORKDIR}/ebuild_unused_patches"
		[pa_inis]="${WORKDIR}/ebuild_insecure_init_scripts"
		[pa_hobs]="${WORKDIR}/ebuild_homepage_bad_statuscode"
		[pa_hore]="${WORKDIR}/ebuild_homepage_redirections"
		[pa_hobr]="${WORKDIR}/ebuild_homepage_bad_rating"
		[pa_pksc]="${WORKDIR}/packages_pkgcheck_scan"
		[me_miin]="${WORKDIR}/metadata_mixed_indentation"
		[me_mipm]="${WORKDIR}/metadata_missing_proxy_maintainer"
		[me_duud]="${WORKDIR}/metadata_duplicate_useflag_description"
		[me_mmri]="${WORKDIR}/metadata_missing_remote_id"
	)
}

var_descriptions(){
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

	read -r -d '' eb_iwfi <<- EOM
	Ebuilds shouldn't install "INSTALL". (with exceptions)
	Also see: <a href="https://devmanual.gentoo.org/general-concepts/mirrors/">Link</a>

	${info_default0}
	EOM
	read -r -d '' eb_obdt <<- EOM
	Ebuilds don't need to specifiy --disable-dependency-tracking in econf.
	This is automatically specified from EAPI4.
	Also see: <a href="https://dev.gentoo.org/~zmedico/portage/doc/ch06s03s05.html">Link</a>

	${info_default0}
	EOM
	read -r -d '' eb_obsr <<- EOM
	Ebuilds don't need to specifiy --disable-silent-rules in econf.
	This is automatically specified from EAPI5.
	Also see: <a href="https://devmanual.gentoo.org/ebuild-writing/eapi/index.html">Link</a>

	${info_default0}
	EOM
	read -r -d '' eb_obds <<- EOM
	Ebuilds don't need to specifiy --disable-static in econf.
	This is automatically specified from EAPI8.
	Also see: <a href="https://devmanual.gentoo.org/ebuild-writing/eapi/index.html">Link</a>

	${info_default0}
	EOM
	read -r -d '' eb_obvi <<- EOM
	Lists virtuals were only one provider is still available.

	${info_default0}
	EOM
	read -r -d '' eb_node <<- EOM
	This checks the ebuilds *DEPEND* Blocks for packages which doesn't exist anymore.

	Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|sys-apps/bar:dev-libs/libdir(2015-08-13)|dev@gentoo.org:loper@foo.de ):
	7                                           EAPI Version
	dev-libs/foo                                package category/name
	foo-1.12-r2.ebuild                          full filename
	sys-apps/bar:dev-libs/libdir(2015-08-13)    non-existing package(s). If removed after git migration a removal date is shown.
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' eb_vamb <<- EOM
	Simple check to find variables which not use curly braces.
	Only a certain set of variables are being checked.

	Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|DEPEND:SRC_URI|dev@gentoo.org:loper@foo.de ):
	7                                           EAPI Version
	dev-libs/foo                                package category/name
	foo-1.12-r2.ebuild                          full filename
	DEPEND:SRC_URI                              list of variables which not use curly braces, seperated by ':'
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' eb_ingu <<- EOM
	Ebuilds shouldn't use git:// for git repos because its insecure. Should be replaced with https://
	Also see: <a href="https://gist.github.com/grawity/4392747">Link</a>

	${info_default0}
	EOM
	read -r -d '' eb_ltwv <<- EOM
	Simple check to find leading or trailing whitespaces in a set of variables.
	For example: SRC_URI=" www.foo.com/bar.tar.gz "

	Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|DEPEND:SRC_URI|dev@gentoo.org:loper@foo.de ):
	7                                           EAPI Version
	dev-libs/foo                                package category/name
	foo-1.12-r2.ebuild                          full filename
	DEPEND:SRC_URI                              list of variables which have unusual whitespaces, seperated by ':'
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' eb_mude <<- EOM
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
	read -r -d '' eb_miec <<- EOM
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
	read -r -d '' eb_unec <<- EOM
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
	read -r -d '' eb_mief <<- EOM
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
	read -r -d '' eb_mizd <<- EOM
	Packages which downlaods ZIP files but misses app-arch/unzip in DEPEND.

	Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com/bar.zip|dev@gentoo.org:loper@foo.de ):
	7                                           EAPI Version
	dev-libs/foo                                package category/name
	foo-1.12-r2.ebuild                          full filename
	https://foo.bar.com/bar.zip                 zip file which is downloaded by the ebuild
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' eb_sruo <<- EOM
	Packages which can't be installed because the SRC_URI is offline and RESTRICT="mirror" enabled.

	Data Format ( 7|2021-06-01|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com/bar.zip|dev@gentoo.org:loper@foo.de ):
	7                                           EAPI Version
	2021-06-01                                  date of check
	dev-libs/foo                                package category/name
	foo-1.12-r2.ebuild                          full filename
	https://foo.bar.com/bar.zip                 file which is not available and mirror restricted
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' eb_srub <<- EOM
	This check uses wget's spider functionality to check if a ebuild's SRC_URI link still works.
	The timeout to try to get a file is 15 seconds. This exculdes mirror:// links.

	Data Format ( 7|2021-06-01|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com/bar.zip|dev@gentoo.org:loper@foo.de ):
	7                                           EAPI Version
	2021-06-01                                  date of check
	dev-libs/foo                                package category/name
	foo-1.12-r2.ebuild                          full filename
	https://foo.bar.com/bar.zip                 file which is not available
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' eb_srfo <<- EOM
	Similar to ebuild_src_uri_bad this tries to download the sources from a ebuild. However it simply uses ebuild ... fetch in order
	todo so. This way mirror:// links won't be excluded.

	Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|dev@gentoo.org:loper@foo.de ):
	7                                           EAPI Version
	dev-libs/foo                                package category/name
	foo-1.12-r2.ebuild                          full filename
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' eb_srsm <<- EOM
	Calls GENTOO_MIRRORS="" ebuild package fetch. This should catch problems like fetches file(s) that do not match recorded_size

	Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|dev@gentoo.org:loper@foo.de ):
	7                                           EAPI Version
	dev-libs/foo                                package category/name
	foo-1.12-r2.ebuild                          full filename
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' eb_inpp <<- EOM
	Ebuilds shouldn't use chown -R or chmod -R in pkg_postinst and pkg_config. This is a security threat
	Also see: <a href="http://michael.orlitzky.com/articles/end_root_chowning_now_%28make_pkg_postinst_great_again%29.xhtml">Link</a>

	${info_default0}
	EOM
	read -r -d '' pa_unpa <<- EOM
	Extensive check to find unused pachtes. In order to reduce flase positives it uses a whilelist to exclude them.

	Data Format ( dev-libs/foo|foo-fix-1.12.patch|dev@gentoo.org:loper@foo.de ):
	dev-libs/foo                                package category/name
	foo-fix-1.12.patch                          patch which is not used by any ebuild
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' pa_inis <<- EOM
	Ebuilds shouldn't use chown -R or chmod -R in init scripts. This is a security threat.
	Also see: <a href="http://michael.orlitzky.com/articles/end_root_chowning_now_%28make_etc-init.d_great_again%29.xhtml">Link</a>

	Data Format ( dev-libs/foo|dev@gentoo.org:loper@foo.de ):
	dev-libs/foo                                package category/name
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' pa_hobs <<- EOM
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
	read -r -d '' pa_hore <<- EOM
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
	read -r -d '' pa_hobr <<- EOM
	Lists ebuilds with a Homepage(IP) which has an bad rating from abuseipdb

	Data Format ( 7|100|2021-06-01|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com|dev@gentoo.org:loper@foo.de ):
	7                                           EAPI Version
	100                                         rating from abuseipdb (everything above 0)
	2021-06-01                                  date of check
	dev-libs/foo                                package category/name
	foo-1.12-r2.ebuild                          full filename
	https://foo.bar.com                         original hommepage in ebuild
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' pa_pksc <<- EOM
	A script which runs 'pkgcheck scan --net --keywords=-info -q' on every package. The result is also filtered
	by pkgcheck keywords.

	Data Format ( dev-libs/foo|RequiredUseDefaults:RedirectedUrl|dev@gentoo.org:loper@foo.de ):
	dev-libs/foo                                package category/name
	RequiredUseDefaults:RedirectedUrl           pkgcheck problem(s), seperated by ':'
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' me_miin <<- EOM
	Checks metadata files (metadata.xml) if it uses mixed tabs and whitespaces.

	${info_default1}
	EOM
	read -r -d '' me_mipm <<- EOM
	Checks the metadata.xml of proxy maintained packages if it includes actually a
	non gentoo email address (address of proxy maintainer).
	Reason: There can't be a proxy maintained package without a proxy maintainer in metadata.xml

	${info_default1}
	EOM
	read -r -d '' me_duud <<- EOM
	Lists packages which define use flags locally in metadata.xml, which already exists as
	a global use flag.

	Data Format ( dev-libs/foo|gtk[:X:qt:zlib]|dev@gentoo.org:loper@foo.de ):
	dev-libs/foo                                package category/name
	gtk[:X:qt:zlib]                             list of USE flags which already exists as a global flag.
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' me_mmri <<- EOM
	Lists packages which has a certain homepage (github, sourceforge) but doesn't set remote-id in metadata.xml

	Data Format ( dev-libs/foo|github[:sourceforge]|dev@gentoo.org:loper@foo.de ):
	dev-libs/foo                                package category/name
	github[:sourceforge]                        list of remote-id's which are missing
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
}
#
### IMPORTANT SETTINGS END ###
#

ebuild-check() {
	array_names
	[[ ${DEBUGLEVEL} -ge 2 ]] && echo "generating ebuild-check standard information for ${1}" | (debug_output)

	local rel_path=${1}																									# path relative to ${REPOTREE}:	./app-admin/salt/salt-0.5.2.ebuild
	local cat="$(echo ${rel_path}|cut -d'/' -f1)"												# package category:							app-admin
	local pak="$(echo ${rel_path}|cut -d'/' -f2)"												# package name:									salt
	local filename="$(echo ${rel_path}|cut -d'/' -f3)"									# package filename:							salt-0.5.2.ebuild
	local pakname="${filename%.*}"																			# package name-version:					salt-0.5.2
	local pakver="${pakname/${pak}-/}"																	# package version								0.5.2
	local abs_path="${REPOTREE}/${cat}/${pak}"													# full path:										/usr/portage/app-admin/salt
	local abs_path_ebuild="${REPOTREE}/${cat}/${pak}/${filename}"				# full path ebuild:							/usr/portage/app-admin/salt/salt-0.5.2.ebuild
	local abs_md5_path="${REPOTREE}/metadata/md5-cache/${cat}/${pakname}" # full md5 path:							/usr/portage/metadata/md5-cache/app-admin/salt-0.5.2
	local maintainer="$(get_main_min "${cat}/${pak}")"									# maintainer of package:				foo@gentoo.org:bar@gmail.com
	local ebuild_eapi="$(get_eapi ${rel_path})"													# eapi of ebuild:								6

	output_formats(){
		declare -gA array_formats=(
			[eb_def0]="${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}${maintainer}"
			[eb_def1]="${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}$(echo ${array_results1[@]}|tr ' ' ':')${DL}${maintainer}"
			[eb_def2]="${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}$(echo ${array_results2[@]}|tr ' ' ':')${DL}${maintainer}"
			[eb_def3]="${ebuild_eapi}${DL}${cat}/${pak}${DL}${filename}${DL}$(echo ${array_results3[@]}|tr ' ' ':')${DL}${maintainer}"
			[eb_sruo]="${ebuild_eapi}${DL}$(date -I)${DL}${cat}/${pak}${DL}${filename}${DL}$(echo ${file_offline[@]}|tr ' ' ':')${DL}${maintainer}"
			[eb_srub]="${ebuild_eapi}${DL}$(date -I)${DL}${cat}/${pak}${DL}${filename}${DL}$(echo ${bad_file_status[@]}|tr ' ' ':')${DL}${maintainer}"
		)
		echo "${array_formats[${1}]}"
	}

	output(){
		local output="${1}"
		local file="${FULL_CHECKS[${2}]}"
		if ${FILERESULTS}; then
			output_formats ${output} >> ${file}/full.txt
		else
			echo "${file##*/}${DL}$(output_formats ${output})"
		fi
	}

	# disable-dependency-tracking check [eb_obdt]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_obdt " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_obdt]/${WORKDIR}\/}" | (debug_output)
		$(grep -q 'disable-dependency-tracking' ${rel_path}) && output eb_def0 eb_obdt
	fi

	# disable-silent-rules check [eb_obsr]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_obsr " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_obsr]/${WORKDIR}\/}" | (debug_output)
		$(grep -q 'disable-silent-rules' ${rel_path}) && output eb_def0 eb_obsr
	fi

	# disable-static check [eb_obds]
	if [[ "${ebuild_eapi}" = "8" ]] && [[ " ${SELECTED_CHECKS[*]} " =~ " eb_obds " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_obds]/${WORKDIR}\/}" | (debug_output)
		$(grep -q 'disable-static' ${rel_path}) && output eb_def0 eb_obds
	fi

	# check if INSTALL file would be installed in DOCS or dodoc [eb_iwfi]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_iwfi " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_iwfi]/${WORKDIR}\/}" | (debug_output)
		if $(grep dodoc ${rel_path} | grep -q INSTALL); then
			output eb_def0 eb_iwfi
		elif $(grep DOCS ${rel_path} | grep -v INSTALL_ | grep -q INSTALL ); then
			output eb_def0 eb_iwfi
		fi
	fi

	# insecure git usage [eb_ingu]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_ingu " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_ingu]/${WORKDIR}\/}" | (debug_output)
		$(grep -q "EGIT_REPO_URI=\"git://" ${rel_path}) && output eb_def0 eb_ingu
	fi

	# trailing/leading whitespaces in variables [eb_ltwv]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_ltwv " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_ltwv]/${WORKDIR}\/}" | (debug_output)
		local _varibales="DESCRIPTION LICENSE KEYWORDS IUSE RDEPEND DEPEND SRC_URI"
		local array_results1=( )
		for var in ${_varibales}; do
			if $(grep -Eq "^${var}=\" |^${var}=\".* \"$" ${rel_path}); then
				array_results1+=( ${var} )
			fi
		done
		[ -n "${array_results1}" ] && output eb_def1 eb_ltwv
	fi

	# variables not useing braces [eb_vamb]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_vamb " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_vamb]/${WORKDIR}\/}" | (debug_output)
		local _variables=(
			'$PN' '$P' '$PV' '$FILESDIR' '$WORKDIR' '$T' '$D' '$DISTDIR' '$DEPEND' '$KEYWORDS' '$SLOT' '$SRC_URI'
			'$BDEPEND' '$RDEPEND' '$S' '$DOCS' '$MY_P' '$MY_PN'
		)
		local array_results1=( )
		if grep -Fq "$(echo ${_variables[@]}|tr ' ' '\n')" ${rel_path}; then
			for var in ${_variables[@]}; do
				if $(grep -v '^\s*$\|^\s*#' ${rel_path}| grep -wq ${var}); then
					array_results1+=( ${var/$} )
				fi
			done
		fi
		[[ -n "${array_results1}" ]] && output eb_def1 eb_vamb
	fi

	# badstyle in ebuilds [eb_mude]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_mude " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_mude]/${WORKDIR}\/}" | (debug_output)
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


				if $(grep "^[^#;]" ${rel_path} | grep -Eq "$(echo ${z[@]}|tr ' ' '|')" ); then
					output eb_def0 eb_mude
				fi
			fi
		fi
	fi

	# dependency checks [eb_obvi & eb_node]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_obvi " ]] || [[ " ${SELECTED_CHECKS[*]} " =~ " eb_node " ]]; then
		if ${TREE_IS_MASTER}; then
			[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_obvi]/${WORKDIR}\/} and ${FULL_CHECKS[eb_node]/${WORKDIR}\/}" | (debug_output)
			if $(grep -q "DEPEND" ${rel_path}); then
				local array_results1=()
				local _dependencies=( $(grep DEPEND ${abs_md5_path}|grep -oE "[a-zA-Z0-9-]{3,30}/[+a-zA-Z_0-9-]{2,80}"|sed 's/-[0-9].*//g'|sort -u) )

				for dep in ${_dependencies[@]}; do
					if $(grep ${dep} ${rel_path} >/dev/null 2>&1); then
						if ! [[ -e "${REPOTREE}/${dep}" ]]; then
							# provide gitage if git is available
							if ${ENABLE_GIT}; then
								local deadage="$(get_age_last "${dep}")"
								if [[ -n "${deadage}" ]]; then
									dep="${dep}(${deadage})"
								fi
							fi
							array_results1+=( "${dep}" )
							found=true
						fi
					fi
				done

				if [[ -n "${array_results1=}" ]] && [[ "${cat}" = "virtual" ]]; then
					if [ $(expr ${#_dependencies[@]}) -eq 1 ] && [ $(grep ${_dependencies[0]} ${rel_path} | wc -l) -gt 1 ]; then
						continue
					else
						if [[ $(expr ${#_dependencies[@]} - ${#array_results1[@]}) -le 1 ]]; then
							output eb_def0 eb_obvi
						fi
					fi
				fi

				[[ -n "${array_results1}" ]] && output eb_def1 eb_node
			fi
		fi
	fi

	# eclass checks, only check if ECLASSES is not empty [eb_miec & eb_unec & eb_mief]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_miec " ]] \
		|| [[ " ${SELECTED_CHECKS[*]} " =~ " eb_unec " ]] \
		|| [[ " ${SELECTED_CHECKS[*]} " =~ " eb_mief " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_miec]/${WORKDIR}\/} and ${FULL_CHECKS[eb_unec]/${WORKDIR}\/} and ${FULL_CHECKS[eb_mief]/${WORKDIR}\/}" | (debug_output)

		if [ -n "${ECLASSES}" ]; then
			if $(grep -q "inherit" ${rel_path}); then
				local array_results1=( )
				local array_results3=( )
				local array_results2=( )

				local func_in_use=( )
				local func_in_use_fatal=( )

				for echeck in ${ECLASSES}; do
					local eclass="$(echo ${echeck}|cut -d';' -f1)"
					local eclass_funcs="$(echo ${echeck}|cut -d';' -f2|tr ':' ' ')"

					# don't check for eapi7-ver at ebuilds greater EAPI=7
					if [ "${eclass}" = "eapi7-ver" ] && [ "${ebuild_eapi}" -gt 6 ]; then
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
						${catch} || array_results1+=( ${eclass} )
					# check the ebuild if one the eclass functions are used
					else
						# ignore case were functions from xdg-utils are used but only xdg is
						# inherited (xdg inherits xdg-utils)
						if [ "${eclass}" == "xdg-utils" ] && $(check_eclasses_usage ${rel_path} xdg); then
							continue
						else
							# get the function(s) which are used by the ebuild, if any
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
						fi
						[ -n "${func_in_use}" ] && \
							array_results3+=( "${eclass}($(echo ${func_in_use[@]}|tr ' ' ','))" )
						[ -n "${func_in_use_fatal}" ] && \
							array_results2+=( "${eclass}($(echo ${func_in_use_fatal[@]}|tr ' ' ','))" )
					fi
					func_in_use=( )
					func_in_use_fatal=( )
				done

				[ -n "${array_results3}" ] && output eb_def3 eb_miec
				[ -n "${array_results1}" ] && output eb_def1 eb_unec
				[ -n "${array_results2}" ] && output eb_def2 eb_mief
			fi
		fi
	fi

	# check if upstream source is available (only if mirror restricted) + missing
	# unzip dependency
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_mizd " ]] \
		|| [[ " ${SELECTED_CHECKS[*]} " =~ " eb_sruo " ]] \
		|| [[ " ${SELECTED_CHECKS[*]} " =~ " eb_srub " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_mizd]/${WORKDIR}\/} \
			and ${FULL_CHECKS[eb_sruo]/${WORKDIR}\/} \
			and ${FULL_CHECKS[eb_srub]/${WORKDIR}\/}" | (debug_output)
		local _src_links=( $(grep ^SRC_URI= ${abs_md5_path}|cut -d'=' -f2-) )
		local array_results1=( )
		local file_offline=( )
		local bad_file_status=( )
		if [ -n "${_src_links}" ]; then
			for l in ${_src_links}; do
				if $(echo ${l} | grep -q -E "^http://|^https://"); then
					# missing zip dep
					if [ "$(echo ${l: -4})" == ".zip" ]; then
						if ! $(grep -q "app-arch/unzip" ${abs_md5_path}); then
							array_results1+=( ${l} )
						fi
					fi
					# exclude ebuilds which inherit one of the following eclasses:
					# texlive-module
					# these generate lots of false postive by generating SRC_URI via the
					# eclasses
					if ! $(get_eclasses "${cat}/${pak}/${pakname}" | grep -q -E "texlive-module"); then
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
			[ -n "${array_results1}" ] && output eb_def1 eb_mizd
			[ -n "${file_offline}" ] && output eb_sruo eb_sruo
			[ -n "${bad_file_status}" ] && output eb_srub eb_srub
			if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_srsm " ]] || [[ " ${SELECTED_CHECKS[*]} " =~ " eb_srfo " ]]; then
				[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_srsm]/${WORKDIR}\/} \
					and ${FULL_CHECKS[eb_srfo]/${WORKDIR}\/}" | (debug_output)
				# only run if previous checks were without results
				if [ -z "${array_results1}" ] && [ -z "${file_offline}" ] && [ -z "${bad_file_status}" ]; then
					if ! $(echo ${pakver}|grep -q 9999) && \
						! $(grep -q -e "^RESTRICT=.*mirror" ${rel_path}) && \
						! $(grep -q -e "^SRC_URI=.*dev.gentoo.org" ${abs_md5_path}) ; then
						local tmpdir="$(mktemp -p /var/tmp -d)"
						local fetchlog="$(mktemp)"
						# first download and see if it fails
						if ! $(DISTDIR="${tmpdir}" GENTOO_MIRRORS="" /usr/bin/ebuild ${abs_path_ebuild} fetch >${fetchlog} 2>&1); then
							# if fails, see if the log contains REQUIRED_USE settings -> ignore these
							if ! $(grep -q REQUIRED_USE ${fetchlog}); then
								if $(grep -q "VERIFY FAILED" ${fetchlog}); then
									output eb_def0 eb_srsm
								else
									output eb_def0 eb_srfo
								fi
							fi
						fi
						rm "${fetchlog}"
						rm -rf "${tmpdir}"
					fi
				fi
			fi
		fi
	fi

	# inscure pkg_config or pkg_postinst [eb_inpp]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_inpp " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_inpp]/${WORKDIR}\/}" | (debug_output)
		if $(grep -q -E "^pkg_config|^pkg_postinst" ${rel_path}); then
			if $(awk '/^pkg_config|^pkg_postinst/,/^}/' ${rel_path} | grep -q -P "^\tchmod -R|^\tchown -R"); then
				output eb_def0 eb_inpp
			fi
		fi
	fi
}

package-check() {
	array_names
	[[ ${DEBUGLEVEL} -ge 2 ]] && echo "generating package-check standard information for ${1}" | (debug_output)

	array_names
	local rel_path=${1}																		# path relative to ${REPOTREE}:	./app-admin/salt/
	local cat="$(echo ${rel_path}|cut -d'/' -f1)"					# package category:							app-admin
	local pak="$(echo ${rel_path}|cut -d'/' -f2)"					# package name:									salt
	local abs_path="${REPOTREE}/${cat}/${pak}"						# full path:										/usr/portage/app-admin/salt
	local maintainer="$(get_main_min "${cat}/${pak}")"		# maintainer of package:				foo@gentoo.org:bar@gmail.com

	output_formats(){
		declare -gA array_formats=(
			[pa_def0]="${cat}/${pak}${DL}${maintainer}"
			[pa_def1]="${cat}/${pak}${DL}$(echo ${array_results1[@]}|tr ' ' ':')${DL}${maintainer}"
			[pa_hobs]="${ebuild_eapi}${DL}${statuscode}${DL}$(date -I)${DL}${cat}/${pak}${DL}${ebuild_filename}${DL}${hp}${DL}${maintainer}"
			[pa_hore]="${ebuild_eapi}${DL}${new_code}${DL}$(date -I)${DL}${cat}/${pak}${DL}${ebuild_filename}${DL}${hp}${DL}${correct_site}${DL}${maintainer}"
			[pa_hobr]="${ebuild_eapi}${DL}${siterating}${DL}$(date -I)${DL}${cat}/${pak}${DL}${ebuild_filename}${DL}${hp}${DL}${hpip}${DL}${maintainer}"
			[pa_unpa]="${cat}/${pak}${DL}${upatch}${DL}${maintainer}"
		)
		echo "${array_formats[${1}]}"
	}

	output(){
		local output="${1}"
		local file="${FULL_CHECKS[${2}]}"
		if ${FILERESULTS}; then
			output_formats ${output} >> ${file}/full.txt
		else
			echo "${file##*/}${DL}$(output_formats ${output})"
		fi
	}

	output-unpa() {
		local output="${1}"
		local file="${FULL_CHECKS[${2}]}"
		if ${FILERESULTS}; then
			for upatch in "${unused_patches[@]}"; do
				output_formats ${output} >> ${file}/full.txt
			done
		else
			for upatch in "${unused_patches[@]}"; do
				echo "${file##*/}${DL}$(output_formats ${output})"
			done
		fi
	}

	# unused patches [pa_unpa]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " pa_unpa " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[pa_unpa]/${WORKDIR}\/}" | (debug_output)
		check_ebuild(){
			local patchfile=$1

			local pn='${PN}'
			local p='${P}'
			local pf='${PF}'
			local pv='${PV}'
			local pvr='${PVR}'
			local slot='${SLOT}'
			local var_my_pn='${MY_PN}'
			local var_my_p='${MY_P}'
			local var_my_pv='${MY_PV}'
			local var_mod_ver='${MODULE_VERSION}'
			local var_dist_ver='${DIST_VERSION}'
			local var_x509_ver='${X509_VER}'
			local var_hpn_ver='${HPN_VER}'

			[ ${DEBUGLEVEL} -ge 2 ] && echo " 1-check_ebuild: checking: ${patchfile}" | (debug_output)

			for ebuild in ${fullpath}/*.ebuild; do
				[ ${DEBUGLEVEL} -ge 2 ] && echo " 1-check_ebuild:  looking into: ${ebuild}" | (debug_output)

				# get ebuild detail
				local ebuild_full=$(basename ${ebuild%.*})
				local ebuild_version=$(echo ${ebuild_full/${pak}}|cut -d'-' -f2)
				local ebuild_revision=$(echo ${ebuild_full/${pak}}|cut -d'-' -f3)
				local ebuild_slot="$(grep ^SLOT $ebuild|cut -d'"' -f2)"
				local package_name_ver="${pak}-${ebuild_version}"

				[ ${DEBUGLEVEL} -ge 3 ] && echo " 1-check_ebuild:  ebuild details: ver: $ebuild_version rever: $ebuild_revision slot: $ebuild_slot" | (debug_output)

				local cn_name_vers="${patchfile/${pak}/${pn}}"
				local cn=( )

				# create custom names to check
				cn+=("${patchfile}")
				cn+=("${patchfile/${pak}/${pn}}")
				cn+=("${patchfile/${pak}-${ebuild_version}/${p}}")
				cn+=("${patchfile/${ebuild_version}/${pv}}")

				cn+=("${cn_name_vers/${ebuild_version}/${pv}}")
				cn+=("${patchfile/${pak}-${ebuild_version}/${pf}}")
				# add special naming if there is a revision
				if [ -n "${ebuild_revision}" ]; then
					cn+=("${patchfile/${pak}-${ebuild_version}-${ebuild_revision}/${pf}}")
					cn+=("${patchfile/${ebuild_version}-${ebuild_revision}/${pvr}}")
				fi
				# looks for names with slotes, if slot is not 0
				if [ -n "${ebuild_slot}" ] && ! [ "${ebuild_slot}" = "0" ]; then
					cn+=("${patchfile/${ebuild_slot}/${slot}}")
					cn+=("${cn_name_vers/${ebuild_slot}/${slot}}")
				fi

				# special naming
				if $(grep -q -E "^MY_PN=|^MY_P=|^MY_PV=|^MODULE_VERSION=|^DIST_VERSION=|^X509_VER=|^HPN_VER=" ${ebuild}); then

					# get the variables from the ebuilds

					# MY_PN and other such variables often are constructed with the usage of
					# global variables like $PN and $PV.
					# With using eval these variables are replaces by it's real content,
					# which must be replaced by our variable names first
					my_pn_name="$(grep ^MY_PN\= ${ebuild} | cut -d' ' -f1 | cut -d'=' -f2 | sed -e "s|PN|pak|g" -e 's|"||g')"
					[ -n "${my_pn_name}" ] && eval my_pn_name="$(echo ${my_pn_name})" >/dev/null 2>&1
					my_pv_name="$(grep ^MY_PV\= ${ebuild} | cut -d' ' -f1 | cut -d'=' -f2 | sed -e "s|PV|ebuild_version|g" -e 's|"||g')"
					[ -n "${my_pv_name}" ] && eval my_pv_name="$(echo ${my_pv_name})" >/dev/null 2>&1
					my_p_name="$(grep ^MY_P\= ${ebuild} | cut -d' ' -f1 | cut -d'=' -f2 | sed -e "s|P|package_name_ver|g" -e 's|"||g')"
					[ -n "${my_p_name}" ] && eval my_p_name="$(echo ${my_p_name})" >/dev/null 2>&1

					my_mod_ver="$(grep ^MODULE_VERSION\= ${ebuild} | cut -d' ' -f1 | cut -d'=' -f2 | sed -e 's|"||g')"
					my_dist_ver="$(grep ^DIST_VERSION\= ${ebuild} | cut -d' ' -f1 | cut -d'=' -f2 | sed -e 's|"||g')"
					my_x509_ver="$(grep ^X509_VER\= ${ebuild} | cut -d' ' -f1 | cut -d'=' -f2 | sed -e 's|"||g')"
					my_hpn_ver="$(grep ^HPN_VER\= ${ebuild} | cut -d' ' -f1 | cut -d'=' -f2 | sed -e 's|"||g')"


					[ ${DEBUGLEVEL} -ge 3 ] && echo " 1-check_ebuild:  Found special vars: $my_pv_name, $my_pn_name, $my_p_name, $my_mod_ver, $my_dist_ver, $my_x509_ver, $my_hpn_ver" | (debug_output)

					[ -n "${my_pn_name}" ] && cn+=("${patchfile/${my_pn_name}/${var_my_pn}}")
					[ -n "${my_pv_name}" ] && cn+=("${patchfile/${my_pv_name}/${var_my_pv}}")
					[ -n "${my_p_name}" ] && cn+=("${patchfile/${my_p_name}/${var_my_p}}")

					local tmpvar=""

					if [ -n "${my_mod_ver}" ]; then
						cn+=("${patchfile/${my_mod_ver}/${var_mod_ver}}")
						tmpvar="${patchfile/${my_mod_ver}/${var_mod_ver}}"
						cn+=("${tmpvar/${pak}/${pn}}")
					fi

					if [ -n "${my_dist_ver}" ]; then
						cn+=("${patchfile/${my_dist_ver}/${var_dist_ver}}")
						tmpvar="${patchfile/${my_dist_ver}/${var_dist_ver}}"
						cn+=("${tmpvar/${pak}/${pn}}")
					fi

					if [ -n "${my_x509_ver}" ]; then
						cn+=("${patchfile/${my_x509_ver}/${var_x509_ver}}")
						tmpvar="${patchfile/${my_x509_ver}/${var_x509_ver}}"
						cn+=("${tmpvar/${pak}/${pn}}")
						cn+=("${tmpvar/${pak}-${ebuild_version}/${p}}")
					fi

					if [ -n "${my_hpn_ver}" ]; then
						cn+=("${patchfile/${my_hpn_ver}/${var_hpn_ver}}")
						tmpvar="${patchfile/${my_hpn_ver}/${var_hpn_ver}}"
						cn+=("${tmpvar/${pak}/${pn}}")
						cn+=("${tmpvar/${pak}-${ebuild_version}/${p}}")
					fi
				fi

				# remove duplicates
				mapfile -t cn < <(printf '%s\n' "${cn[@]}"|sort -u)
				# replace list with newpackages
				local searchpattern="$(echo ${cn[@]}|tr ' ' '\n')"
				[ ${DEBUGLEVEL} -ge 3 ] && echo " 1-check_ebuild:  Custom names: $(echo ${cn[@]}|tr ' ' ':')" | (debug_output)

				# check ebuild for the custom names
				if $(sed 's|"||g' ${ebuild} | grep -q -F "${searchpattern}"); then
					[ ${DEBUGLEVEL} -ge 2 ] && echo " 1-check_ebuild: FOUND: ${patchfile}" | (debug_output)
					return 0
				else
					[ ${DEBUGLEVEL} -ge 3 ] && echo " 1-check_ebuild: NOT FOUND: ${patchfile}" | (debug_output)
				fi
			done

			return 1
		}

		# white list checking
		white_check() {
			local pfile=${1}
			[ ${DEBUGLEVEL} -ge 3 ] && echo " 0-whitelist: checking ${pfile} in ${WFILE}" | (debug_output)

			if [ -e ${WFILE} ]; then
				source ${WFILE}
			else
				[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-whitelist: ${WFILE} - file not found" | (debug_output)
				return 1
			fi

			# check if the file in in the whitelist
			if $(echo ${white_list[@]} | grep -q "${cat}/${pak};${pfile};"); then
				# detailed output only if debugging is enabled
				if [ ${DEBUGLEVEL} -ge 2 ]; then
					for white in ${white_list[@]}; do
						local cat_pak="$(echo ${white}|cut -d';' -f1)"
						local white_file="$(echo ${white}|cut -d';' -f2)"
						local white_ebuild="$(echo ${white}|cut -d';' -f3)"
						# only continue if we found the right line
						if [ "${cat}/${pak};${pfile}" = "${cat_pak};${white_file}" ]; then
							if [ "${white_ebuild}" = "all" ]; then
								[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-whitelist: found patch ${pfile} in all ebuilds" | (debug_output)
								return 0
							else
								for wbuild in $(echo ${white_ebuild} | tr ':' ' '); do
									if [ -e "${REPOTREE}/${rel_path}/${wbuild}" ]; then
										[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-whitelist: found patch ${pfile} in ${wbuild}" | (debug_output)
										return 0
									fi
								done
							fi
							[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-whitelist: ${pfile} not found" | (debug_output)
							return 1
						fi
					done
				fi
				for ebx in $(grep "${cat}/${pak};${pfile};" ${WFILE} | sed 's|"||g' | cut -d ';' -f 3 | tr ':' ' '); do
					if [ "${ebx}" = "all" ]; then
						return 0
					elif [ -e "${REPOTREE}/${rel_path}/${ebx}" ]; then
						return 0
					fi
				done
				return 1
			else
				return 1
			fi
		}

		eclass_prechecks() {
			local pfile="${1}"

			if [ "${pfile}" = "rc-addon.sh" ]; then
				if $(grep -q vdr-plugin-2 ${fullpath}/*.ebuild); then
					[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-prechecks: file is rc-addon.sh and used in vdr-plugin-2.eclass" | (debug_output)
					return 0
				else
					return 1
				fi
			# check for vdr-plugin-2 eclass which installs confd files if exists
			elif [ "${pfile}" = "confd" ]; then
				if $(grep -q vdr-plugin-2 ${fullpath}/*.ebuild); then
					[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-prechecks: file is confd and used in vdr-plugin-2.eclass" | (debug_output)
					return 0
				else
					return 1
				fi
			# check for apache-module eclass which installs conf files if a APACHE2_MOD_CONF is set
			elif [ "${pfile##*.}" = "conf" ]; then
				if $(grep -q apache-module ${fullpath}/*.ebuild) && \
					$(grep -q APACHE2_MOD_CONF ${fullpath}/*.ebuild); then
					[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-prechecks: file is conf and used in apache-module.eclass" | (debug_output)
					return 0
				else
					return 1
				fi
			# check for elisp eclass which install el files if a SITEFILE is set
			elif [ "${pfile##*.}" = "el" ]; then
				if $(grep -q elisp ${fullpath}/*.ebuild) && \
					$(grep -q SITEFILE ${fullpath}/*.ebuild); then
					[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-prechecks: file is el and used in elisp.eclass" | (debug_output)
					return 0
				else
					return 1
				fi
			# ignoring README.gentoo files
			elif $(echo ${pfile}|grep -i README.gentoo >/dev/null); then
				if $(grep -q readme.gentoo ${fullpath}/*.ebuild); then
					[ ${DEBUGLEVEL} -ge 2 ] && echo " 0-prechecks: file is readme.gentoo and used in readme.gentoo-r1.eclass" | (debug_output)
					return 0
				else
					return 1
				fi
			else
				[ ${DEBUGLEVEL} -ge 3 ] && echo " 0-prechecks: ${pfile} is not used in inherited eclasses!" | (debug_output)
				return 1
			fi
		}

		# find_patches_in_braces
		# this function takes a list of patchfiles, and looks if the names
		# are similar by cutting the names at '-' starting with the last position.
		#
		# The similar part to the files found are being removed and with the
		# remaning part of the name we generate verions of how the patches can
		# be called like:
		# $PN-{patch2,patch1} or $PN-{patch1,patch2}
		#
		# Lastly we check again with check_ebuild to look if the ebuild use one
		# of the version profided and - if found - remove them from the
		# $unused_patches variable
		find_patches_in_braces() {
			local work_list=( $(echo ${1}|tr ':' ' ') )

			[ ${DEBUGLEVEL} -ge 2 ] && echo " 2-brace_patches: checking ${work_list[@]}" | (debug_output)

			local common_pattern=( )
			local patches_to_remove=( )
			local patch
			for patch in "${work_list[@]}"; do
				# how often contains the name the seperator '-'
				local deli=$(echo ${patch%.patch}|grep -o '-'|wc -w)
				# try find duplicates, starting with the highest count of $deli
				for n in $(echo $(seq 1 ${deli})|rev); do
					if [ $(echo ${work_list[@]}|tr ' ' '\n'|grep $(echo ${patch}|cut -d'-' -f1-${n})|wc -l) -gt 1 ]; then
						[ ${DEBUGLEVEL} -ge 3 ] && echo " 2-brace_patches: pattern candidate: $(echo ${patch}|cut -d'-' -f1-${n})" | (debug_output)
						common_pattern+=("$(echo ${patch}|cut -d'-' -f1-${n})")
						break
					fi
				done
			done
			# remove duplicates from array
			mapfile -t common_pattern < <(printf '%s\n' ${common_pattern[@]}|sort -u)

			if [ -n "${common_pattern}" ]; then
				[ ${DEBUGLEVEL} -ge 3 ] && echo " 2-brace_patches: found patterns ${common_pattern[@]}" | (debug_output)
				local x p
				for x in ${common_pattern[@]}; do
					local braces_patches=( )
					[ ${DEBUGLEVEL} -ge 2 ] && echo " 2-brace_patches: checking pattern ${x}" | (debug_output)

					# find duplicates files by pattern $x and strip everything away
					local matching=( $(find ${fullpath}/files/ -type f -name "${x}*" -printf '%f\n'|sed -e 's/.patch//' -e "s/${x}-//") )

					# do not make permutations with greater then 5 matchings
					if [ ${#matching[@]} -le 5 ]; then
						local permutations=$(get_perm "$(echo ${matching[@]})")
						[ ${DEBUGLEVEL} -ge 3 ] && echo " 2-brace_patches: create permutations with $(echo ${matching[@]})" | (debug_output)
						for p in ${permutations}; do
							braces_patches+=("$(echo ${x}-{${p}}.patch)")
						done

						[ ${DEBUGLEVEL} -ge 2 ] && echo " 2-brace_patches: found ${braces_patches[@]}" | (debug_output)
						local t u
						for t in ${braces_patches[@]}; do
							if $(check_ebuild ${t}); then
								for u in ${matching[@]}; do
									patches_to_remove+=( "${x}-${u}.patch" )
								done
								break
							fi
						done
					else
						[ ${DEBUGLEVEL} -ge 3 ] && echo " 2-brace_patches: to much candidates, skipping" | (debug_output)
					fi
				done
				echo "${patches_to_remove[@]}"
			else
				echo ""
			fi
		}

		# find_patches_with_asterisk
		# check for a certain text (FILESDIR.*\*) which is an indicater that files are
		# being used by using '*'. In this case we are checking what files are
		# matching and remove the from the unused_patches list
		find_patches_with_asterisk() {
			local work_list=( $(echo ${1}|tr ':' ' ') )

			local ebuild
			local candidate
			local found_patches=( )

			for ebuild in ${fullpath}/*.ebuild; do
				# look for matching FILESDIR.*\*, remove path part, replace some patterns
				# like ';', '"' and replace curly braces (and everthing between) with '*'
				for candidate in $(grep -oP "FILESDIR.*\*(\S+|$)" ${ebuild} | rev | cut -d'/' -f1 | rev | sort -u |sed -e 's/"//g' -e 's/;//g' -e 's/[{].*[}]/*/g'); do
					[ ${DEBUGLEVEL} -ge 2 ] && echo " 3-asterixes: found asterixes in ebuild ${candidate[@]}" | (debug_output)

					local matching_asterisk=( $(find ${fullpath}/files/${candidate} -type f -printf '%f\n' 2>/dev/null) )
					[ ${DEBUGLEVEL} -ge 2 ] && echo " 3-asterixes: matching following files: ${matching_asterisk[@]}" | (debug_output)

					for p in ${matching_asterisk[@]}; do
						if $(echo ${work_list[@]} | grep -q ${p}); then
							[ ${DEBUGLEVEL} -ge 3 ] && echo " 3-asterixes: adding to remove list: ${p}" | (debug_output)
							found_patches+=( ${p} )
						fi
					done
				done
			done

			if [ -n "${found_patches}" ]; then
				[ ${DEBUGLEVEL} -ge 2 ] && echo " 3-asterixes: removing from unused_patches: $(echo ${found_patches[@]}|tr ' ' '\n'|sort -u| tr '\n' ' ')" | (debug_output)
				echo ${found_patches[@]}|tr ' ' '\n'|sort -u
			else
				echo
			fi
		}

		local fullpath="/${REPOTREE}/${rel_path}"

		[ ${DEBUGLEVEL} -ge 2 ] && echo "checking: ${cat}/${pak}" | (debug_output)
		# check if the patches folder exist
		if [ -e ${fullpath}/files ]; then

			local cat="$(echo ${rel_path}|cut -d'/' -f1)"
			local pak="$(echo ${rel_path}|cut -d'/' -f2)"
			local maintainer="$(get_main_min "${cat}/${pak}")"
			local patch_list=()

			[ ${DEBUGLEVEL} -ge 3 ] && echo "found files dir in: ${cat}/${pak}/files" | (debug_output)


			# prechecks and patchlist generation
			#  every file found will be checked against the whitelist (white_check) and
			#  checked for the usage of certain eclasses (which are know to use certain
			#  files from the FILESDIR directory directly.
			[ ${DEBUGLEVEL} -ge 3 ] && echo "prechecks: whitelist and special eclasses" | (debug_output)
			for file in ${fullpath}/files/*; do
				# ignore directories
				if ! [ -d ${file} ]; then
					file="${file##*/}"
					if ! $(white_check ${file}); then
						# elcass-prechecks
						if $(echo ${file##*/}|grep -q -E "\.el|conf|rc-addon.sh|README*"); then
							if ! $(eclass_prechecks ${file}); then
								patch_list+=("${file}")
							fi
						else
							patch_list+=("${file}")
						fi
					fi
				fi
			done
			[ ${DEBUGLEVEL} -ge 2 ] && echo "prechecks done: patchlist: ${patch_list[@]}" | (debug_output)


			# only continue if we found actually files to check
			if [ -n "${patch_list}" ]; then

				# first check
				#  every patchfile from $patch_list gets passed to check_ebuild, which
				#  replaces names and version with their corresponding ebuild name
				#  ($PN, PV, ..) and grep's the ebuild with them.
				[ ${DEBUGLEVEL} -ge 3 ] && echo "starting basic check for: ${patch_list[@]}" | (debug_output)
				unused_patches=()
				for patchfile in "${patch_list[@]}"; do
					if ! $(check_ebuild "${patchfile}"); then
						unused_patches+=("${patchfile}")
					fi
				done
				[ ${DEBUGLEVEL} -ge 2 ] && echo "basic check done, unused patches are: ${unused_patches[@]}" | (debug_output)

				# second check
				# find patches in braces (works only with *.patch files)
				# examples: app-editors/zile, app-office/scribus, app-office/libreoffice,
				# dev-cpp/antlr-cpp, dev-qt/qtcore, games-arcade/supertux
				[ ${DEBUGLEVEL} -ge 3 ] && echo "starting second check for: ${unused_patches[@]}" | (debug_output)
				if [ ${#unused_patches[@]} -ge 1 ]; then
					for patchfile in $(find_patches_in_braces "$(echo ${unused_patches[@]}|tr ' ' ':')"); do
						[ ${DEBUGLEVEL} -ge 2 ] && echo "patch to remove: ${patchfile}" | (debug_output)
						for target in "${!unused_patches[@]}"; do
							if [ "${unused_patches[target]}" = "${patchfile}" ]; then
								unset 'unused_patches[target]'
							fi
						done
					done
					[ ${DEBUGLEVEL} -ge 2 ] && echo "finish second check, remaining patches: ${unused_patches[@]}" | (debug_output)
				fi

				# third check
				# find pachtes which are called with an asterix (*)
				# examples: net-misc/icaclient, app-admin/consul
				[ ${DEBUGLEVEL} -ge 3 ] && echo "starting third check for: ${unused_patches[@]}" | (debug_output)
				if [ -n "${unused_patches}" ]; then
					for patchfile in $(find_patches_with_asterisk "$(echo ${unused_patches[@]}|tr ' ' ':')"); do
						[ ${DEBUGLEVEL} -ge 2 ] && echo "patch to remove: ${patchfile}" | (debug_output)
						for target in "${!unused_patches[@]}"; do
							if [ "${unused_patches[target]}" = "${patchfile}" ]; then
								unset 'unused_patches[target]'
							fi
						done
					done
					[ ${DEBUGLEVEL} -ge 2 ] && echo "finish third check, remaining patches: ${unused_patches[@]}" | (debug_output)
				fi

				array_names
				if [ ${#unused_patches[@]} -gt 0 ]; then
					[ ${DEBUGLEVEL} -ge 2 ] && echo "found unused patches: ${unused_patches[@]}" | (debug_output)
					output-unpa pa_unpa pa_unpa
				else
					[ ${DEBUGLEVEL} -ge 3 ] && echo "found zero unused patches" | (debug_output)
				fi

				[ ${DEBUGLEVEL} -ge 2 ] && echo | (debug_output)
				[ ${DEBUGLEVEL} -ge 2 ] && echo | (debug_output)
			else
				[ ${DEBUGLEVEL} -ge 3 ] && echo "skipping: ${cat}/${pak} has files directory, but no there are no files to check" | (debug_output)
			fi
		else
			[ ${DEBUGLEVEL} -ge 3 ] && echo "skipping: ${cat}/${pak} has no files directory" | (debug_output)
		fi
	fi

	# insecure chown/chown in init scripts [pa_inis]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " pa_inis " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[pa_inis]/${WORKDIR}\/}" | (debug_output)
		if [ -d "${REPOTREE}/${rel_path}/files" ]; then
			local init_count=( $(find ${REPOTREE}/${rel_path}/files/ -maxdepth 1 -name "*init*" ) )
			if [ ${#init_count[@]} -gt 0 ]; then
				if $(awk '/^start/,/^}/' ${REPOTREE}/${rel_path}/files/*init* | grep -q -P "chmod -R|chown -R|chmod --recursive|chown --recursive"); then
					if ! $(awk '/^start/,/^}/' ${REPOTREE}/${rel_path}/files/*init* | grep -q "checkpath"); then
						output pa_def0 pa_inis
					fi
				fi
			fi
		fi
	fi

	# check if homepage is reachable and if it redirects to another link. [pa_hobs & pa_hore]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " pa_hobs " ]] || [[ " ${SELECTED_CHECKS[*]} " =~ " pa_hore " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[pa_hobs]/${WORKDIR}\/} and \
			${FULL_CHECKS[pa_hore]/${WORKDIR}\/}" | (debug_output)
		for eb in ${abs_path}/*.ebuild; do
			local ebuild_eapi="$(get_eapi ${eb})"
			local ebuild_filename="$(basename ${eb})"
			local ebuild_name="${ebuild_filename%.*}"
			local abs_md5_path="${REPOTREE}/metadata/md5-cache/${cat}/${ebuild_name}"	# full md5 path:							/usr/portage/metadata/md5-cache/app-admin/salt-0.5.2
			local ebuild_hps="$(grep ^HOMEPAGE= ${abs_md5_path}|cut -d'=' -f2-)"

			if [ -n "${ebuild_hps}" ]; then
				local hp
				for hp in ${ebuild_hps}; do
					[ ${DEBUGLEVEL} -ge 2 ] && echo "checking following sites: ${ebuild_hps}" | (debug_output)
					if $(echo ${hp}|grep -q ^ftp); then
						[ ${DEBUGLEVEL} -ge 2 ] && echo "${hp} is a ftp link" | (debug_output)
						local statuscode="FTP"
					# ignore metacpan.org redirections
					elif $(echo ${hp}|grep -q metacpan.org/release); then
						continue
					else
						# get ip of homepage
						local _checktmp="$(grep "${DL}${hp}${DL}" ${TMPCHECK}|head -1)"

						# check site status
						if [ -z "${_checktmp}" ]; then
							[ ${DEBUGLEVEL} -ge 2 ] && echo "checking site status ${hp}" | (debug_output)
							local statuscode="$(get_site_status ${hp})"
							echo "${ebuild_eapi}${DL}${statuscode}${DL}${hp}${DL}" >> ${TMPCHECK}
						else
							[ ${DEBUGLEVEL} -ge 2 ] && echo "found ${hp} in ${TMPCHECK}" | (debug_output)
							statuscode="${_checktmp:2:3}"
						fi

						# check site rating status
						if [[ " ${SELECTED_CHECKS[*]} " =~ " pa_hobr " ]]; then
							# only run abusecheck if api key is available
							if ${ENABLE_ABUSECHECK}; then
								[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[pa_hobr]/${WORKDIR}\/}" | (debug_output)
								hpip="$(dig +short "$(echo ${hp} | sed -e 's|https://||g' -e 's|http://||g' | cut -d'/' -f1)" | grep '^[.0-9]*$' |  head -1)"
								[ -n "${hpip}" ] && local _checktmpip="$(grep "${DL}${hpip}${DL}" ${TMPIPCHECK}|head -1)"
								if [ -n "${hpip}" ]; then
									if [ -z "${_checktmpip}" ]; then
										[ ${DEBUGLEVEL} -ge 2 ] && echo "checking rating status ${hp}" | (debug_output)
										local siterating="$(get_site_rating ${hpip})"
										echo "${ebuild_eapi}${DL}${siterating}${DL}${hpip}${DL}" >> ${TMPIPCHECK}
										if [ "${siterating}" != "0" ]; then
											[ ${DEBUGLEVEL} -ge 2 ] && echo "rating for ${hpip} is ${siterating}" | (debug_output)
											output pa_hobr pa_hobr
										fi
									else
										[ ${DEBUGLEVEL} -ge 2 ] && echo "found ${hpip} in ${TMPIPCHECK}" | (debug_output)
										# filter out only the rating
										siterating="$(echo ${_checktmpip} | cut -d"${DL}" -f2)"
										if [ "${siterating}" != "0" ]; then
											[ ${DEBUGLEVEL} -ge 2 ] && echo "rating for ${hpip} is ${siterating}" | (debug_output)
											output pa_hobr pa_hobr
										fi
									fi
								fi
							fi
						fi
					fi

					case ${statuscode} in
						301)
							local correct_site="$(curl -Ls -o /dev/null --silent --max-time 20 --head -w %{url_effective} ${hp})"
							local new_code="$(get_site_status ${correct_site})"
							output pa_hore pa_hore
							;;
						FTP|200|302|307|400|429|503)
							continue
							;;
						*)
							output pa_hobs pa_hobs
							;;
					esac
				done
			fi
		done
	fi

	# pkgcheck check [pa_pksc]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " pa_pksc " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[pa_pksc]/${WORKDIR}\/}" | (debug_output)
		# remove old results first (previosly restored at the begining of the script)
		# we remove the file in case problems got resolved and the file would be
		# changed
		if ${FILERESULTS}; then
			rm -f ${FULL_CHECKS[pa_pksc]}/sort-by-package/${cat}/${pak}.txt
		fi

		cd ${abs_path}
		local TMPFILE="/tmp/${cat}-${pak}-${RANDOM}.log"
		/usr/bin/pkgcheck scan -r ${REPOTREE%/} --net --keywords=-info --color=n > ${TMPFILE}

		local array_results1=( $(grep '^  [a-zA-Z].*' ${TMPFILE} | cut -d':' -f1| sort -u ) )

		if [ -s ${TMPFILE} ]; then
			if ${FILERESULTS}; then
				mkdir -p ${FULL_CHECKS[pa_pksc]}/sort-by-package/${cat}/
				tail -n+2 ${TMPFILE} > ${FULL_CHECKS[pa_pksc]}/sort-by-package/${cat}/${pak}.txt
				output pa_def1 pa_pksc
			else
				output pa_def1 pa_pksc
			fi
		fi
		rm ${TMPFILE}
	fi
}

metadata-check() {
	array_names
	[[ ${DEBUGLEVEL} -ge 2 ]] && echo "generating metadata-check standard information for ${1}" | (debug_output)

	array_names
	local rel_path=${1}																		# path relative to ${REPOTREE}:	./app-admin/salt/metadata.xml
	local cat="$(echo ${rel_path}|cut -d'/' -f1)"					# package category:							app-admin
	local pak="$(echo ${rel_path}|cut -d'/' -f2)"					# package name:									salt
	local maintainer="$(get_main_min "${cat}/${pak}")"		# maintainer of package:				foo@gentoo.org:bar@gmail.com
	local abs_path="${REPOTREE}/${cat}/${pak}"						# full path:										/usr/portage/app-admin/salt

	output_formats(){
		declare -gA array_formats=(
			[me_def0]="${cat}/${pak}${DL}${filename}${DL}${maintainer}"
			[me_duud]="${cat}/${pak}${DL}$(echo ${dup_use[@]}|tr ' ' ':')${DL}${maintainer}"
			[me_mmri]="${cat}/${pak}${DL}$(echo ${mri[@]}|tr ' ' ':')${DL}${maintainer}"
		)
		echo "${array_formats[${1}]}"
	}

	output(){
		local output="${1}"
		local file="${FULL_CHECKS[${2}]}"
		if ${FILERESULTS}; then
			output_formats ${output} >> ${file}/full.txt
		else
			echo "${file##*/}${DL}$(output_formats ${output})"
		fi
	}

	# mixed indentation [me_miin]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " me_miin " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[me_miin]/${WORKDIR}\/}" | (debug_output)
		if $(grep -q "^ " ${rel_path}); then
			$(grep -q $'\t' ${rel_path}) && output me_def0 me_miin
		fi
	fi

	# missing proxy maintainer [me_mipm]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " me_mipm " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[me_mipm]/${WORKDIR}\/}" | (debug_output)
		local _found_go_mail=false
		if $(grep -q "proxy-maint@gentoo.org" ${rel_path}); then
			local i
			for i in $(echo ${maintainer}|tr ':' '\n'); do
				if ! $(echo ${i} | grep -q "@gentoo.org"); then
					_found_go_mail=true
				fi
			done
			${_found_go_mail} || output me_def0 me_mipm
		fi
	fi

	# duplicate use flag description [me_duud]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " me_duud " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[me_duud]/${WORKDIR}\/}" | (debug_output)
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
			[ -n "${dup_use}" ] && output me_duud me_duud
		fi
	fi

	# missing remote-id [me_mmri]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " me_mmri " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[me_mmri]/${WORKDIR}\/}" | (debug_output)
		local mri=( )
		local eb=""

		for eb in ${abs_path}/*.ebuild; do
			local ebuild_check="${eb##*/}"
			local pakname=${ebuild_check%.ebuild}
			local abs_md5_path="${REPOTREE}/metadata/md5-cache/${cat}/${pakname}"
			local ebuild_hps="$(grep ^HOMEPAGE= ${abs_md5_path}|cut -d'=' -f2-)"

			[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking: ${pakname}" | (debug_output)


			# get siteid's
			#  cd /mnt/data/git/gentoo
			#  grep -R remote-id|cut -d'"' -f2|sort -u
			# find all of one siteid
			#  grep -Re "remote-id.*rubygems"

			local siteid
			for siteid in github.com sourceforge.net pypi.org gitlab.com; do
				if $(grep ^HOMEPAGE= ${abs_md5_path} | grep -q ${siteid}); then
					if ! $(grep -qe "remote-id.*\"${siteid%.*}\"" ${rel_path}); then
						mri+=( ${siteid} )
					fi
				fi
			done
		done

		# remove duplicates
		mapfile -t mri < <(printf '%s\n' "${mri[@]}"|sort -u)
		[ -n "${mri}" ] && output me_mmri me_mmri
	fi
	
}

# create a list of categories in ${REPOTREE}
_gen_repo_categories(){
	[[ ${DEBUGLEVEL} -ge 2 ]] && echo ">>> calling ${FUNCNAME[0]}" | (debug_output)
	local all_cat=( $(find ${REPOTREE} -mindepth 1 -maxdepth 1 -type d -regextype sed -regex "./*[a-z0-9].*-[a-z0-9].*" -printf '%P\n') )
	[[ -e ${REPOTREE}/virtual ]] && all_cat+=( "virtual" )

	CATEGORIES="$(echo ${all_cat[@]})"
	export CATEGORIES
}

# certain set of ebuilds which we check for their functions. For this check we
# need to know where the main gentoo tree resides. GTREE is usually set in qa.sh
_gen_gentoo_eclasses(){
	[[ ${DEBUGLEVEL} -ge 2 ]] && echo ">>> calling ${FUNCNAME[0]}" | (debug_output)
	if [[ -n "${GTREE}" ]]; then
		# a list of eclass which we're going to check
		local etc=( optfeature wrapper edos2unix estack preserve-libs \
			vcs-clean desktop versionator user-info flag-o-matic xdg-utils \
			libtool udev pam ssl-cert toolchain-funcs )

		local eclasses_with_funcs=( )

		local i x
		for i in ${etc[@]}; do
			# check if the eclass exports EXPORT_FUNCTIONS (these eclass cannot be checked)
			if ! $(grep -q "EXPORT_FUNCTIONS" /${GTREE}/eclass/${i}.eclass); then
				# get all functions of the eclass
				local efuncs="$(sed -n 's/# @FUNCTION: //p' "/${GTREE}/eclass/${i}.eclass" | sed ':a;N;$!ba;s/\n/ /g')"
				local f=( )
				# only continue if we found functions
				if [[ -n "${efuncs}" ]]; then
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

_gen_repo_whitelist(){
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
	[[ ${DEBUGLEVEL} -ge 1 ]] && echo ">>> calling ${FUNCNAME[0]} (MIND:${MIND} MAXD:${MAXD})" | (debug_output)
	[[ ${DEBUGLEVEL} -ge 2 ]] && echo "*** searchpattern is: ${SEARCHPATTERN[@]}" | (debug_output)
	[[ ${DEBUGLEVEL} -ge 2 ]] && echo "*** packages to check: ${#SEARCHPATTERN[@]}" | (debug_output)

	# restore results for pa_pksc since they are not generated via
	# gen_sort_pak_v5 for them
	if ${FILERESULTS}; then
		if [[ " ${SELECTED_CHECKS[*]} " =~ " pa_pksc " ]]; then
				cp -r ${RESULTSDIR}/${SCRIPT_TYPE}/${FULL_CHECKS[pa_pksc]/${WORKDIR}/}/sort-by-package ${FULL_CHECKS[pa_pksc]}/
		fi
	fi

	# do not run in parallel if DEBUGLEVEL -ge 2
	if [[ ${DEBUGLEVEL} -ge 2 ]]; then
		find ${SEARCHPATTERN[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.ebuild" -print 2>/dev/null | while read -r line; do ebuild-check ${line}; done
		find ${SEARCHPATTERN[@]} -mindepth ${MIND} -maxdepth ${MAXD} \
			-type d -print 2>/dev/null | while read -r line; do package-check ${line}; done
		find ${SEARCHPATTERN[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.xml" -print 2>/dev/null | while read -r line; do metadata-check ${line}; done
	else
		find ${SEARCHPATTERN[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.ebuild" -print 2>/dev/null | parallel ebuild-check {}
		find ${SEARCHPATTERN[@]} -mindepth ${MIND} -maxdepth ${MAXD} \
			-type d -print 2>/dev/null | parallel package-check {}
		find ${SEARCHPATTERN[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.xml" -print 2>/dev/null | parallel metadata-check {}
	fi

	[[ ${DEBUGLEVEL} -ge 2 ]] && echo "*** fileresults enabled: ${FILERESULTS}" | (debug_output)
	if ${FILERESULTS}; then
		clean_results
		var_descriptions
		for s in ${SELECTED_CHECKS[@]}; do
			echo "${!s}" >> ${FULL_CHECKS[${s}]}/description.txt
		done

		sort_result_v6
		gen_sort_filter_v2 4 "${FULL_CHECKS[eb_vamb]}"
		gen_sort_filter_v2 4 "${FULL_CHECKS[eb_node]}"
		gen_sort_filter_v2 4 "${FULL_CHECKS[eb_ltwv]}"
		gen_sort_filter_v2 4 "${FULL_CHECKS[eb_miec]}"
		gen_sort_filter_v2 4 "${FULL_CHECKS[eb_unec]}"
		gen_sort_filter_v2 4 "${FULL_CHECKS[eb_mief]}"
		gen_sort_filter_v2 2 "${FULL_CHECKS[pa_hobs]}"
		gen_sort_filter_v2 2 "${FULL_CHECKS[me_duud]}"
		gen_sort_filter_v2 2 "${FULL_CHECKS[pa_pksc]}"

		# excldue pa_pksc from package sort
		EXCLUDE_SORT_PAK="${FULL_CHECKS[pa_pksc]}"
		gen_sort_pak_v5

		EXCLUDE_SORT_MAIN=""
		gen_sort_main_v5

		# additional sortings for pa_pksc
		local y
		if [ -d "${FULL_CHECKS[pa_pksc]}/sort-by-filter/" ]; then
			for y in $(ls ${FULL_CHECKS[pa_pksc]}/sort-by-filter/); do
				gen_sort_pak_v5 "${FULL_CHECKS[pa_pksc]}/sort-by-filter/${y}"
			done
		fi
		post_checks ${SCRIPT_TYPE}
	fi
}

if [[ ${DEBUGLEVEL} -ge 2 ]]; then
	[[ ${DEBUGLEVEL} -ge 2 ]] && echo "*** starting ${0} (NON-PARALLEL)" | (debug_output)
else
	[[ ${DEBUGLEVEL} -ge 1 ]] && echo "*** starting ${0} (PARALLEL)" | (debug_output)
fi

cd ${REPOTREE}

touch ${TMPCHECK}
touch ${TMPIPCHECK}
array_names
_gen_gentoo_eclasses
_gen_repo_categories
_gen_repo_whitelist

RUNNING_CHECKS=( )
for s in ${SELECTED_CHECKS[@]}; do
	RUNNING_CHECKS+=(${FULL_CHECKS[${s}]})
done
${FILERESULTS} && mkdir -p ${RUNNING_CHECKS[@]}

export -f ebuild-check package-check metadata-check array_names
export WORKDIR TMPCHECK TMPIPCHECK WFILE

depth_set_v4 ${1}

${FILERESULTS} && rm -rf ${WORKDIR}
rm ${TMPCHECK}
rm ${TMPIPCHECK}

[[ ${DEBUGLEVEL} -ge 1 ]] && echo "*** finished ${0}" | (debug_output)
