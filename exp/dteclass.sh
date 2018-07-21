#!/bin/bash

# Filename: dteclass.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 21/07/2018

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
#	this script creates a deptree of all eclasses

#override PORTTREE,SCRIPT_MODE,SITEDIR settings
#export PORTTREE=/usr/portage/
#export SCRIPT_MODE=true
#export SITEDIR="${HOME}/tmpcheck/"

# load repo specific settings
startdir="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
if [ -e ${startdir}/repo ]; then
	source ${startdir}/repo
fi

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
SCRIPT_NAME="dteclass"
SCRIPT_SHORT="DTC"			#Dep-Tree-eClass
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/${SCRIPT_SHORT}-STA-deptree_eclasses"									#Index 0
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

get_inherits(){
	local eclass=${1}
	# get the eclasses inherited by a eclass:
	# 1(sed): catch eclasses which are cut over multiple lines (remove newline
	# 2(sed): remove leading spaces
	# after a line ending with '\'
	# 2(grep): remove all lines starting with '#' (comments)
	# 3(grep): search for lines starting with 'inherit ' or lines containing '&& inherit '
	# 4(grep): remove inherit from result
	# 5(sed): remove comments at the end of lines (see darcs.eclass)
	local eclass_inherit=( $( sed -e :a -e '/\\$/N; s/\\\n//; ta' ${1} \
		| sed "s/^[ \t]*//" \
		| grep "^[^#]" \
		| grep "^inherit \|&& inherit \|*) inherit " \
		| sed 's/^.*\(inherit .*\).*$/\1/' \
		|cut -c9- \
		| sed 's/\#.*$//' \
		| sed 's/\;\;//') )

	echo "${eclass_inherit[@]}"
}

rec_dt_eclass(){
	local tabdeep="${1}"
	local ecl="${2}"
	local dupcheck="${3}"

	tabdeep+="\t"
	dupcheck+=" ${ecl}"

	if [ -e "${PORTTREE}/eclass/${ecl}.eclass" ]; then
		local ec_in=( $(get_inherits "${PORTTREE}/eclass/${ecl}.eclass") )
		if [ -n "${ec_in}" ]; then
			for tec in ${dupcheck}; do
				if $(echo ${ec_in[@]}|tr ' ' ':'|grep -q -P -o "${tec}(?=:|$)"); then
					echo -e "!C${tabdeep}|- CIRCULAR DEEP with ${tec}"
					return
				fi
			done
			for e in $(echo ${ec_in[@]}); do
				if [ -e "${PORTTREE}/eclass/${e}.eclass" ]; then
					echo -e "${tabdeep}|- ${e}"
					rec_dt_eclass ${tabdeep} "${e}" "${dupcheck}"
				else
					echo -e "!N${tabdeep}|- ${e}.eclass doesn't exist"
				fi
			done
		fi
	else
		echo -e "!N${tabdeep}|- ${ecl}.eclass doesn't exist"
	fi
}

main() {
	array_names
	local relative_path=${1}																								# path relative to ${PORTTREE}:	./app-admin/salt/salt-0.5.2.ebuild
#	local category="$(echo ${relative_path}|cut -d'/' -f2)"									# package category:							app-admin
#	local package="$(echo ${relative_path}|cut -d'/' -f3)"									# package name:									salt
#	local full_path="${PORTTREE}/${category}/${package}"										# full path:										/usr/portage/app-admin/salt
#	local full_path_ebuild="${PORTTREE}/${category}/${package}/${filename}"	# full path ebuild:							/usr/portage/app-admin/salt/salt-0.5.2.ebuild
#	local maintainer="$(get_main_min "${category}/${package}")"							# maintainer of package					foo@gentoo.org:bar@gmail.com
#	local fileage="$(get_age "${filename}")"																# age of ebuild in days:				145

	local eclassfile="$(echo ${relative_path}|cut -d'/' -f3)"									# package filename:							salt-0.5.2.ebuild
	local eclass="${eclassfile%.*}"																			# package name-version:					salt-0.5.2

	# get a list of all inherits, looks like: "git-r3 eutils user"
	local ec_inherit=( $(get_inherits ${PORTTREE}/${relative_path}) )

	if ${SCRIPT_MODE}; then
		echo "${eclass}" >> ${RUNNING_CHECKS[0]}/full.txt
	else
		echo "${eclassfile}"
		if [ -n "${ec_inherit}" ]; then
			rec_dt_eclass "" "${eclass}" ""
		fi

	#	echo "${eclass}${DL}$(echo ${ec_inherit[@]}|tr ' ' ':')"
		#for ec in $(echo ${ec_inherit[@]}); do
		#	if [ -e ${PORTTREE}/eclass/${ec}.eclass ]; then
		#		if [ -n "$(get_inherits ${PORTTREE}/eclass/${ec}.eclass)" ]; then
		#			#echo -e "\t| ${ec}"
		#			rec_dt_eclass "\t" "${ec}"
		#		else
		#			echo -e "s\t| ${ec}"
		#		fi
		#	else
		#		echo -e "!\t| ${ec}"
		#	fi
		#done
	fi
}

# set the search depth
depth_set ${1}
# switch to the PORTTREE dir
cd ${PORTTREE}
# export important variables
export WORKDIR SCRIPT_SHORT
export -f main array_names get_inherits rec_dt_eclass

${SCRIPT_MODE} && mkdir -p ${RUNNING_CHECKS[@]}

#find ./eclass \
#	-type f -name "*.eclass" -print | sort | parallel main {}

find ./eclass \
	-type f -name "*.eclass" -print | sort | while read -r line; do main ${line}; done

if ${SCRIPT_MODE}; then
	gen_sort_main_v2 ${RUNNING_CHECKS[0]} 5
	gen_sort_pak_v2 ${RUNNING_CHECKS[0]} 3

	copy_checks checks
	rm -rf ${WORKDIR}
fi
