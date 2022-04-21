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
WORKDIR="/tmp/$(basename ${0})-${RANDOM}"
TMPCHECK="/tmp/$(basename ${0})-tmp-${RANDOM}.txt"

array_names(){
	SELECTED_CHECKS=(
		eb_trwh
		eb_deec									# remove? (available via stats)
		eb_obge
		eb_obvi eb_node
		eb_epe6									# remove when EAPI6 is gone
		eb_doe6									# remove when EAPI6 is gone
		eb_de80									# remove? (available via repoman checks)
		eb_vamb
		eb_vaho
		eb_ingu
		eb_ltwv
		eb_mude
		eb_miec eb_unec eb_mief
		eb_hous
		eb_mizd eb_sruo eb_srub
		eb_inpp
		pa_houn
		pa_unps
		pa_inis
		pa_hobs pa_hore
		me_miin
		me_mipm
		me_duud
	)
	declare -gA FULL_CHECKS=(
		[eb_trwh]="${WORKDIR}/ebuild_trailing_whitespaces"
		[eb_deec]="${WORKDIR}/ebuild_deprecated_eclasses"
		[eb_obge]="${WORKDIR}/ebuild_obsolete_gentoo_mirror_usage"
		[eb_obvi]="${WORKDIR}/ebuild_obsolete_virtual"
		[eb_node]="${WORKDIR}/ebuild_nonexist_dependency"
		[eb_epe6]="${WORKDIR}/ebuild_epatch_in_eapi6"
		[eb_doe6]="${WORKDIR}/ebuild_dohtml_in_eapi6"
		[eb_de80]="${WORKDIR}/ebuild_description_over_80"
		[eb_vamb]="${WORKDIR}/ebuild_variable_missing_braces"
		[eb_vaho]="${WORKDIR}/ebuild_variables_in_homepages"
		[eb_ingu]="${WORKDIR}/ebuild_insecure_git_uri_usage"
		[eb_ltwv]="${WORKDIR}/ebuild_leading_trailing_whitespaces_in_variables"
		[eb_mude]="${WORKDIR}/ebuild_multiple_deps_per_line"
		[eb_miec]="${WORKDIR}/ebuild_missing_eclasses"
		[eb_unec]="${WORKDIR}/ebuild_unused_eclasses"
		[eb_mief]="${WORKDIR}/ebuild_missing_eclasses_fatal"
		[eb_hous]="${WORKDIR}/ebuild_homepage_upstream_shutdown"
		[eb_mizd]="${WORKDIR}/ebuild_missing_zip_dependency"
		[eb_sruo]="${WORKDIR}/ebuild_src_uri_offline"
		[eb_srub]="${WORKDIR}/ebuild_src_uri_bad"
		[eb_inpp]="${WORKDIR}/ebuild_insecure_pkg_post_config"
		[pa_houn]="${WORKDIR}/ebuild_homepage_unsync"
		[pa_unps]="${WORKDIR}/ebuild_unused_patches_simple"
		[pa_inis]="${WORKDIR}/ebuild_insecure_init_scripts"
		[pa_hobs]="${WORKDIR}/ebuild_homepage_bad_statuscode"
		[pa_hore]="${WORKDIR}/ebuild_homepage_redirections"
		[me_miin]="${WORKDIR}/metadata_mixed_indentation"
		[me_mipm]="${WORKDIR}/metadata_missing_proxy_maintainer"
		[me_duud]="${WORKDIR}/metadata_duplicate_useflag_description"
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

	read -r -d '' eb_trwh <<- EOM
	Simple check to find leading or trailing whitespaces in a set of variables.
	For example: SRC_URI=" www.foo.com/bar.tar.gz "

	${info_default0}
	EOM
	read -r -d '' eb_deec <<- EOM
	Lists ebuilds who use deprecated or obsolete eclasses.

	Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|user:cmake-utils|dev@gentoo.org:loper@foo.de ):
	7                                           EAPI Version
	dev-libs/foo                                package category/name
	foo-1.12-r2.ebuild                          full filename
	user:cmake-utils                            list obsolete eclasse(s), seperated by ':'
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' eb_obge <<- EOM
	Ebuilds shouldn't use mirror://gentoo in SRC_URI because it's deprecated.
	Also see: <a href="https://devmanual.gentoo.org/general-concepts/mirrors/">Link</a>

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
	read -r -d '' eb_epe6 <<- EOM
	'epatch' is deprecated and should be replaced by 'eapply'.
	Also see: <a href="https://blogs.gentoo.org/mgorny/2015/11/13/the-ultimate-guide-to-eapi-6/">Link</a>

	${info_default0}
	EOM
	read -r -d '' eb_doe6 <<- EOM
	'dohtml' is deprecated in EAPI6 and banned in EAPI7.
	This check lists EAPI6 ebuilds which still use 'dohtml'
	Also see: <a href="https://blogs.gentoo.org/mgorny/2015/11/13/the-ultimate-guide-to-eapi-6/">Link</a>

	${info_default0}
	EOM
	read -r -d '' eb_de80 <<- EOM
	Checks ebuilds if the DESCRIPTION is longer than 80 characters.

	${info_default0}
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
	read -r -d '' eb_vaho <<- EOM
	Simple check to find variables in HOMEPAGE. While not technically a bug, this shouldn't be used.
	See Tracker bug: <a href="https://bugs.gentoo.org/408917">Link</a>
	Also see bug: <a href="https://bugs.gentoo.org/562812">Link</a>

	${info_default0}
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
	read -r -d '' eb_hous <<- EOM
	This checks lists ebuilds which still use a homepage of a know dead upstrem site.
	Also see: <a href="https://wiki.gentoo.org/wiki/Upstream_repository_shutdowns">Link</a>

	Data Format ( 7|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com|dev@gentoo.org:loper@foo.de ):
	7                                           EAPI Version
	dev-libs/foo                                package category/name
	foo-1.12-r2.ebuild                          full filename
	https://foo.bar.com                         homepage(s) which are going to be removed, seperated by ':'
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
	The timeout to try to get a file is 15 seconds.

	Data Format ( 7|2021-06-01|dev-libs/foo|foo-1.12-r2.ebuild|https://foo.bar.com/bar.zip|dev@gentoo.org:loper@foo.de ):
	7                                           EAPI Version
	2021-06-01                                  date of check
	dev-libs/foo                                package category/name
	foo-1.12-r2.ebuild                          full filename
	https://foo.bar.com/bar.zip                 file which is not available
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' eb_inpp <<- EOM
	Ebuilds shouldn't use chown -R or chmod -R in pkg_postinst and pkg_config. This is a security threat
	Also see: <a href="http://michael.orlitzky.com/articles/end_root_chowning_now_%28make_pkg_postinst_great_again%29.xhtml">Link</a>

	${info_default0}
	EOM
	read -r -d '' pa_houn <<- EOM
	Lists packages who have different homepages over it's ebuild versions.

	Data Format ( 2|dev-libs/foo|dev@gentoo.org:loper@foo.de ):
	2                                           number of different homepages found over all ebuilds
	dev-libs/foo                                package category/name
	dev@gentoo.org:loper@foo.de                 maintainer(s), seperated by ':'
	EOM
	read -r -d '' pa_unps <<- EOM
	Very limited check to find unused patches, mostly without false positives

	Data Format ( dev-libs/foo|dev@gentoo.org:loper@foo.de ):
	dev-libs/foo                                package category/name
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
}
#
### IMPORTANT SETTINGS END ###
#

ebuild-check() {
	array_names
	[[ ${DEBUGLEVEL} -ge 2 ]] && echo "generating standard information for ${1}" | (debug_output)

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

	# trailing whitespace [eb_trwh]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_trwh " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_trwh]/${WORKDIR}\/}" | (debug_output)
		$(egrep -q " +$" ${rel_path}) && output eb_def0 eb_trwh
	fi

	# epatch usage [eb_epe6]
	if [[ "${ebuild_eapi}" = "6" ]] && [[ " ${SELECTED_CHECKS[*]} " =~ " eb_epe6 " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_epe6]/${WORKDIR}\/}" | (debug_output)
		$(grep -q "\<epatch\>" ${rel_path}) && output eb_def0 eb_epe6
	fi

	# dohtml usage [eb_doe6]
	if [[ "${ebuild_eapi}" = "6" ]] && [[ " ${SELECTED_CHECKS[*]} " =~ " eb_doe6 " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_doe6]/${WORKDIR}\/}" | (debug_output)
		$(grep -q "\<dohtml\>" ${rel_path}) && output eb_def0 eb_doe6
	fi

	# DESCRIPTION over 80 [eb_de80]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_de80 " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_de80]/${WORKDIR}\/}" | (debug_output)
		[[ $(grep DESCRIPTION ${abs_md5_path} | wc -m) -gt 95 ]] && output eb_def0 eb_de80
	fi

		# mirror usage [eb_obge]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_obge " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_obge]/${WORKDIR}\/}" | (debug_output)
		$(grep -q 'mirror://gentoo' ${rel_path}) && output eb_def0 eb_obge
	fi

	# HOMEPAGE with variables [eb_vaho]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_vaho " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_vaho]/${WORKDIR}\/}" | (debug_output)
		if $(grep -q "HOMEPAGE=.*\${" ${rel_path}); then
			$(grep -q 'HOMEPAGE=.*${HOMEPAGE}' ${rel_path}) && output eb_def0 eb_vaho
		fi
	fi

	# insecure git usage [eb_ingu]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_ingu " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_ingu]/${WORKDIR}\/}" | (debug_output)
		$(grep -q "EGIT_REPO_URI=\"git://" ${rel_path}) && output eb_def0 eb_ingu
	fi

	# dead eclasses [eb_deec]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_deec " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_deec]/${WORKDIR}\/}" | (debug_output)
		local _dead_eclasses=( cmake-utils epatch ltprune mono user versionator )
		local array_results1=( )
		for dead_eclass in ${_dead_eclasses[@]}; do
			if $(check_eclasses_usage ${rel_path} ${dead_eclass}); then
				array_results1+=( ${dead_eclass} )
			fi
		done
		[[ -n "${array_results1}" ]] && output eb_def1 eb_deec
	fi

	# trailing/leading whitespaces in variables [eb_ltwv]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_deec " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_ltwv]/${WORKDIR}\/}" | (debug_output)
		local _varibales="DESCRIPTION LICENSE KEYWORDS IUSE RDEPEND DEPEND SRC_URI"
		local array_results1=( )
		for var in ${_varibales}; do
			if $(egrep -q "^${var}=\" |^${var}=\".* \"$" ${rel_path}); then
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
				if $(grep -v '^\s*$\|^\s*\#' ${rel_path}| grep -wq ${var}); then
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


				if $(grep "^[^#;]" ${rel_path} | egrep -q "$(echo ${z[@]}|tr ' ' '|')" ); then
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

	# eclass checks, only check if ECLASSES is not empty [eb_miec & eb_unec
	# & eb_mief]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_miec " ]] \
		|| [[ " ${SELECTED_CHECKS[*]} " =~ " eb_unec " ]] \
		|| [[ " ${SELECTED_CHECKS[*]} " =~ " eb_mief " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_miec]/${WORKDIR}\/} and ${FULL_CHECKS[eb_unec]/${WORKDIR}\/} and ${FULL_CHECKS[eb_mief]/${WORKDIR}\/}" | (debug_output)

		if [ -n "${ECLASSES}" ]; then
			if $(grep -q "inherit" ${rel_path}); then
				if [ "${ebuild_eapi}" = "6" ] || [ "${ebuild_eapi}" = "7" ]; then

					local array_results1=( )
					local array_results3=( )
					local array_results2=( )

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
							${catch} || array_results1+=( ${eclass} )
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
	fi

	# check for upstream shutdowns [eb_hous]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_hous " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_hous]/${WORKDIR}\/}" | (debug_output)
		_filters=(
			'berlios.de' 'gitorious.org' 'codehaus.org' 'code.google.com'
			'fedorahosted.org' 'gna.org' 'freecode.com' 'freshmeat.net'
		)
		local site single_hp
		local array_results1=( )
		local ebuild_hps="$(grep ^HOMEPAGE= ${abs_md5_path}|cut -d'=' -f2-)"
		for site in ${_filters[@]}; do
			for single_hp in ${ebuild_hps}; do
				if $(echo ${single_hp}|grep -q ${site}); then
					array_results1+=( ${single_hp} )
				fi
			done
		done
		[ -n "${array_results1}" ] && output eb_def1 eb_hous
	fi


	# check if upstream source is available (only if mirror restricted) + missing
	# unzip dependency
	if [[ " ${SELECTED_CHECKS[*]} " =~ " eb_mizd " ]] \
		|| [[ " ${SELECTED_CHECKS[*]} " =~ " eb_sruo " ]] \
		|| [[ " ${SELECTED_CHECKS[*]} " =~ " eb_srub " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[eb_mizd]/${WORKDIR}\/} and ${FULL_CHECKS[eb_sruo]/${WORKDIR}\/} and ${FULL_CHECKS[eb_srub]/${WORKDIR}\/}" | (debug_output)
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
			[ -n "${array_results1}" ] && output eb_def0 eb_mizd
			[ -n "${file_offline}" ] && output eb_sruo eb_sruo
			[ -n "${bad_file_status}" ] && output eb_srub eb_srub
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
	[[ ${DEBUGLEVEL} -ge 2 ]] && echo "generating standard information for ${1}" | (debug_output)

	array_names
	local rel_path=${1}																		# path relative to ${REPOTREE}:	./app-admin/salt/
	local cat="$(echo ${rel_path}|cut -d'/' -f1)"					# package category:							app-admin
	local pak="$(echo ${rel_path}|cut -d'/' -f2)"					# package name:									salt
	local maintainer="$(get_main_min "${cat}/${pak}")"		# maintainer of package:				foo@gentoo.org:bar@gmail.com

	output_formats(){
		declare -gA array_formats=(
			[pa_def0]="${cat}/${pak}${DL}${maintainer}"
			[pa_houn]="${hp_count}${DL}${cat}/${pak}${DL}${maintainer}"
			[pa_hobs]="${ebuild_eapi}${DL}${statuscode}${DL}$(date -I)${DL}${cat}/${pak}${DL}${filename}${DL}${hp}${DL}${maintainer}"
			[pa_hore]="${ebuild_eapi}${DL}${new_code}${DL}$(date -I)${DL}${cat}/${pak}${DL}${filename}${DL}${hp}${DL}${correct_site}${DL}${maintainer}"
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

	# check for unsync homepages [pa_houn]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " pa_houn " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[pa_houn]/${WORKDIR}\/}" | (debug_output)
		local hp_count="$(grep "^HOMEPAGE=" ${REPOTREE}/metadata/md5-cache/${cat}/${pak}-[0-9]* | cut -d'=' -f2|sort -u |wc -l)"
		[ "${hp_count}" -gt 1 ] && output pa_houn pa_houn
	fi

	# simple patchtest [pa_unps]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " pa_unps " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[pa_unps]/${WORKDIR}\/}" | (debug_output)
		local eclasses="apache-module|elisp|vdr-plugin-2|ruby-ng|readme.gentoo-r1|java-vm-2|php-ext-source-r3|selinux-policy-2|toolchain-glibc"
		if [ -d "${REPOTREE}/${rel_path}/files" ]; then
			if ! $(echo ${WHITELIST}|grep -q "${cat}/${pak}"); then
				if ! $(grep -q -E ".diff|.patch|FILESDIR|${eclasses}" ${REPOTREE}/${rel_path}/*.ebuild); then
					output pa_def0 pa_unps
				fi
			fi
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

	# check if homepage is reachable and if it redirects to another link. [pa_hobs
	# & pa_hore]
	if [[ " ${SELECTED_CHECKS[*]} " =~ " pa_hobs " ]] || [[ " ${SELECTED_CHECKS[*]} " =~ " pa_hore " ]]; then
		[[ ${DEBUGLEVEL} -ge 2 ]] && echo "checking for ${FULL_CHECKS[pa_hobs]/${WORKDIR}\/} and ${FULL_CHECKS[pa_hore]/${WORKDIR}\/}" | (debug_output)
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
}

metadata-check() {
	array_names
	[[ ${DEBUGLEVEL} -ge 2 ]] && echo "generating standard information for ${1}" | (debug_output)

	array_names
	local rel_path=${1}																		# path relative to ${REPOTREE}:	./app-admin/salt/metadata.xml
	local cat="$(echo ${rel_path}|cut -d'/' -f1)"					# package category:							app-admin
	local pak="$(echo ${rel_path}|cut -d'/' -f2)"					# package name:									salt
	local maintainer="$(get_main_min "${cat}/${pak}")"		# maintainer of package:				foo@gentoo.org:bar@gmail.com

	output_formats(){
		declare -gA array_formats=(
			[me_def0]="${cat}/${pak}${DL}${filename}${DL}${maintainer}"
			[me_duud]="${cat}/${pak}${DL}$(echo ${dup_use[@]}|tr ' ' ':')${DL}${maintainer}"
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
		local etc=( optfeature wrapper edos2unix ltprune eutils estack preserve-libs \
			vcs-clean epatch desktop versionator user user-info flag-o-matic xdg-utils \
			libtool udev eapi7-ver pam ssl-cert toolchain-funcs )

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

	# do not run in parallel if DEBUGLEVEL -ge 2
	if [[ ${DEBUGLEVEL} -ge 2 ]]; then
		find ${SEARCHPATTERN[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.ebuild" -print 2>/dev/null | while read -r line; do ebuild-check ${line}; done
		find ${SEARCHPATTERN[@]} -mindepth ${MIND} -maxdepth ${MAXD} \
			-type d -print 2>/dev/null | while read -r line; do package-check ${line}; done
		find ${SEARCHPATTERN[@]} -mindepth ${MIND} -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.xml" -print 2>/dev/null | while read -r line; do metadata-check ${line}; done
	else
		find ${SEARCHPATTERN[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.ebuild" -print 2>/dev/null | parallel ebuild-check {}
		find ${SEARCHPATTERN[@]} -mindepth ${MIND} -maxdepth ${MAXD} \
			-type d -print 2>/dev/null | parallel package-check {}
		find ${SEARCHPATTERN[@]} -mindepth ${MIND} -maxdepth $(expr ${MAXD} + 1) \
			-type f -name "*.xml" -print 2>/dev/null | parallel metadata-check {}
	fi

	[[ ${DEBUGLEVEL} -ge 2 ]] && echo "*** fileresults enabled: ${FILERESULTS}" | (debug_output)
	if ${FILERESULTS}; then
		clean_results
		var_descriptions
		for s in ${SELECTED_CHECKS[@]}; do
			echo "${!s}" >> ${FULL_CHECKS[${s}]}/description.txt
		done

		sort_result_v5
		gen_sort_filter_v2 4 "${FULL_CHECKS[eb_deec]}"
		gen_sort_filter_v2 4 "${FULL_CHECKS[eb_vamb]}"
		gen_sort_filter_v2 4 "${FULL_CHECKS[eb_node]}"
		gen_sort_filter_v2 4 "${FULL_CHECKS[eb_ltwv]}"
		gen_sort_filter_v2 4 "${FULL_CHECKS[eb_miec]}"
		gen_sort_filter_v2 4 "${FULL_CHECKS[eb_unec]}"
		gen_sort_filter_v2 4 "${FULL_CHECKS[eb_mief]}"
		gen_sort_filter_v2 2 "${FULL_CHECKS[pa_hobs]}"
		gen_sort_filter_v2 2 "${FULL_CHECKS[me_duud]}"
		gen_sort_pak_v5
		gen_sort_main_v5
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
export WORKDIR TMPCHECK

depth_set_v4 ${1}

${FILERESULTS} && rm -rf ${WORKDIR}
rm ${TMPCHECK}

[[ ${DEBUGLEVEL} -ge 1 ]] && echo "*** finished ${0}" | (debug_output)
