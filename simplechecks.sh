#!/bin/bash

# Filename: simplechecks.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 26/08/2017

# Copyright (C) 2017  Michael Mair-Keimberger
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
# This script finds simple errors in ebuilds and other files. For now it can
#  ebuilds: check for trailing whitespaces
#  metadata: mixed indentation (mixed tabs & whitespaces)

#override REPOTREE,FILERESULTS,RESULTSDIR settings
#export REPOTREE=/usr/portage/
#export FILERESULTS=true
#export RESULTSDIR="${HOME}/simplechecks/"

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

SCRIPT_TYPE="checks"
WORKDIR="/tmp/simplechecks-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
		"${WORKDIR}/ebuild_trailing_whitespaces"						# Index 0
		"${WORKDIR}/metadata_mixed_indentation"							# Index 1
		"${WORKDIR}/ebuild_obsolete_gentoo_mirror_usage"		# Index 2
		"${WORKDIR}/ebuild_epatch_in_eapi6"									# Index 3
		"${WORKDIR}/ebuild_dohtml_in_eapi6"									# Index 4
		"${WORKDIR}/ebuild_description_over_80"							# Index 5
		"${WORKDIR}/metadata_missing_proxy_maintainer"			# Index 6
		"${WORKDIR}/ebuild_variables_in_homepages"					# Index 7
		"${WORKDIR}/ebuild_insecure_git_uri_usage"					# Index 8
	)
}
output_format(){
	index=(
		"${ebuild_eapi}${DL}${category}/${package}${DL}${filename}${DL}${maintainer}"
		"${category}/${package}${DL}${filename}${DL}${maintainer}"
	)
	echo "${index[$1]}"
}
data_descriptions(){
read -r -d '' info_default0 <<- EOM
||F  +----> ebuild EAPI     +----> full ebuild filename
D|O  |                      |
A|R  7 | dev-libs/foo | foo-1.12-r2.ebuild | developer@gentoo.org
T|M       |                                                  |
A|A       |                        ebuild maintainer(s) <----+
||T       +----> package category/name
EOM
read -r -d '' info_default1 <<- EOM
||F                   +----> metadata filename
D|O                   |
A|R  dev-libs/foo | metadata.xml | developer@gentoo.org
T|M   |                                         |
A|A   |               ebuild maintainer(s) <----+
||T   +----> package category/name
EOM

read -r -d '' info_index0 <<- EOM
Simple check to find leading or trailing whitespaces in a set of variables.
For example: SRC_URI=" www.foo.com/bar.tar.gz "

${info_default0}
EOM
read -r -d '' info_index1 <<- EOM
Checks metadata files (metadata.xml) if it uses mixed tabs and whitespaces.

${info_default1}
EOM
read -r -d '' info_index2 <<- EOM
Ebuilds shouldn't use mirror://gentoo in SRC_URI because it's deprecated.
Also see: <a href="https://devmanual.gentoo.org/general-concepts/mirrors/">Link</a>

${info_default0}
EOM
read -r -d '' info_index3 <<- EOM
'epatch' is deprecated and should be replaced by 'eapply'.
Also see: <a href="https://blogs.gentoo.org/mgorny/2015/11/13/the-ultimate-guide-to-eapi-6/">Link</a>

${info_default0}
EOM
read -r -d '' info_index4 <<- EOM
'dohtml' is deprecated in EAPI6 and banned in EAPI7.
This check lists EAPI6 ebuilds which still use 'dohtml'
Also see: <a href="https://blogs.gentoo.org/mgorny/2015/11/13/the-ultimate-guide-to-eapi-6/">Link</a>

${info_default0}
EOM
read -r -d '' info_index5 <<- EOM
Checks ebuilds if the DESCRIPTION is longer than 80 characters.

${info_default0}
EOM
read -r -d '' info_index6 <<- EOM
Checks the metadata.xml of proxy maintained packages if it includes actually a
non gentoo email address (address of proxy maintainer).
Reason: There can't be a proxy maintained package without a proxy maintainer in metadata.xml

${info_default1}
EOM
read -r -d '' info_index7 <<- EOM
Simple check to find variables in HOMEPAGE. While not technically a bug, this shouldn't be used.
See Tracker bug: <a href="https://bugs.gentoo.org/408917">Link</a>
Also see bug: <a href="https://bugs.gentoo.org/562812">Link</a>

${info_default0}
EOM
read -r -d '' info_index8 <<- EOM
Ebuilds shouldn't use git:// for git repos because its insecure. Should be replaced with https://
Also see: <a href="https://gist.github.com/grawity/4392747">Link</a>

${info_default0}
EOM

	description=( "${info_index0}" "${info_index1}" "${info_index2}" \
		"${info_index3}" "${info_index4}" "${info_index5}" "${info_index6}" \
		"${info_index7}" "${info_index8}" \
	)
	echo "${description[$1]}"
}
#
### IMPORTANT SETTINGS END ###
#

main() {
	array_names
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f1)"
	local package="$(echo ${full_package}|cut -d'/' -f2)"
	local filename="$(echo ${full_package}|cut -d'/' -f3)"

	local maintainer="$(get_main_min "${category}/${package}")"
	local ebuild_eapi="$(get_eapi ${full_package})"

	output(){
		local checkid=${1}
		if ${FILERESULTS}; then
			output_format 0 >> ${RUNNING_CHECKS[${checkid}]}/full.txt
		else
			echo "${RUNNING_CHECKS[${checkid}]##*/}${DL}$(output_format 0)"
		fi
	}

	# trailing whitespace
	if $(egrep -q " +$" ${full_package}); then
		output 0
	fi
	# mirror usage
	if $(grep -q 'mirror://gentoo' ${full_package}); then
		output 2
	fi

	if [ "${ebuild_eapi}" = "6" ]; then
		# epatch usage
		if $(grep -q "\<epatch\>" ${full_package}); then
			output 3
		fi
		# dohtml usage
		if $(grep -q "\<dohtml\>" ${full_package}); then
			output 4
		fi
	fi
	# DESCRIPTION over 80
	if [ $(grep DESCRIPTION ${REPOTREE}/metadata/md5-cache/${category}/${filename%.*} | wc -m) -gt 95 ]; then
		output 5
	fi
	# HOMEPAGE with variables
	if $(grep -q "HOMEPAGE=.*\${" ${full_package}); then
		if ! $(grep -q 'HOMEPAGE=.*${HOMEPAGE}' ${full_package}); then
			output 7
		fi
	fi
	# insecure git usage
	if $(grep -q "EGIT_REPO_URI=\"git://" ${full_package}); then
		output 8
	fi
}

main-xml(){
	array_names
	local full_package=${1}
	local category="$(echo ${full_package}|cut -d'/' -f1)"
	local package="$(echo ${full_package}|cut -d'/' -f2)"
	local filename="metadata.xml"

	if [ -e ${REPOTREE}/${category}/${package}/metadata.xml ]; then
		local maintainer="$(get_main_min "${category}/${package}")"
	fi

	output(){
		local checkid=${1}
		if ${FILERESULTS}; then
			output_format 1 >> ${RUNNING_CHECKS[${checkid}]}/full.txt
		else
			echo "${RUNNING_CHECKS[${checkid}]##*/}${DL}$(output_format 1)"
		fi
	}

	# mixed indentation
	if $(grep -q "^ " ${full_package}); then
		if $(grep -q $'\t' ${full_package}); then
			output 1
		fi
	fi
	# missing proxy maintainer
	local ok=false
	if $(grep -q "proxy-maint@gentoo.org" ${full_package}); then
		local i
		for i in $(echo ${maintainer}|tr ':' '\n'); do
			if ! $(echo ${i} | grep -q "@gentoo.org"); then
				ok=true
			fi
		done

		if ! ${ok}; then
			output 6
		fi
	fi
}


find_func(){
	find ${searchp[@]} -mindepth $(expr ${MIND} + 1) -maxdepth $(expr ${MAXD} + 1) \
		-type f -name "*.ebuild" -print | parallel main {}

	find ${searchp[@]} -mindepth ${MIND} -maxdepth $(expr ${MAXD} + 1) \
		-type f -name "*.xml" -print | parallel main-xml {}
}

gen_results(){
	if ${FILERESULTS}; then
		gen_descriptions
		sort_result_v3
		gen_sort_main_v3
		gen_sort_pak_v3

		copy_checks ${SCRIPT_TYPE}
	fi
}

array_names
cd ${REPOTREE}
${FILERESULTS} && mkdir -p ${RUNNING_CHECKS[@]}
export -f main main-xml array_names output_format
export WORKDIR
depth_set_v2 ${1}
${FILERESULTS} && rm -rf ${WORKDIR}
