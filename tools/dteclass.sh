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

#override REPOTREE,FILERESULTS,SITEDIR settings
#export REPOTREE=/mnt/data/gentoo/
#export FILERESULTS=true
#export SITEDIR="${HOME}/tmpcheck/"

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
WORKDIR="/tmp/dteclass-${RANDOM}"

array_names(){
	RUNNING_CHECKS=(
	"${WORKDIR}/deptree_eclasses"									#Index 0
	)
}
array_names
#
### IMPORTANT SETTINGS STOP ###
#

get_inherits(){
	local eclass=${1}
	# get the eclasses inherited by a eclass:
	# 1(sed): catch eclasses which are cut over multiple lines (remove newline)
	# 2(sed): remove leading spaces
	# 2(grep): remove all lines starting with '#' (comments)
	# 3(grep): search for lines starting with 'inherit ' or lines containing '&& inherit '
	# 4(cut): remove inherit from result
	# 5(sed): remove comments at the end of lines (see darcs.eclass)
	local eclass_inherit=( $( sed -e :a -e '/\\$/N; s/\\\n//; ta' ${1} \
		| sed "s/^[ \t]*//" \
		| grep "^[^#]" \
		| grep "^inherit \|&& inherit \|*) inherit " \
		| sed 's/^.*\(inherit .*\).*$/\1/' \
		| cut -c9- \
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

	if [ -e "${REPOTREE}/eclass/${ecl}.eclass" ]; then
		local ec_in=( $(get_inherits "${REPOTREE}/eclass/${ecl}.eclass") )
		if [ -n "${ec_in}" ]; then
			for tec in ${dupcheck}; do
				if $(echo ${ec_in[@]}|tr ' ' ':'|grep -q -P -o "${tec}(?=:|$)"); then
					echo -e "!C${tabdeep}| CIRCULAR DEEP with ${tec}"
					return
				fi
			done
			for e in $(echo ${ec_in[@]}); do
				if [ -e "${REPOTREE}/eclass/${e}.eclass" ]; then
					echo -e "${tabdeep}| ${e}"
					rec_dt_eclass ${tabdeep} "${e}" "${dupcheck}"
				else
					echo -e "!N${tabdeep}| ${e}.eclass doesn't exist"
				fi
			done
		fi
	else
		echo -e "!N${tabdeep}| ${ecl}.eclass doesn't exist"
	fi
}

main() {
	array_names
	local relative_path=${1}																								# path relative to ${REPOTREE}:	./app-admin/salt/salt-0.5.2.ebuild
	local eclassfile="$(echo ${relative_path}|cut -d'/' -f3)"									# package filename:							salt-0.5.2.ebuild
	local eclass="${eclassfile%.*}"																			# package name-version:					salt-0.5.2

	# get a list of all inherits, looks like: "git-r3 eutils user"
	local ec_inherit=( $(get_inherits ${REPOTREE}/${relative_path}) )

	if ${FILERESULTS}; then
		echo "${eclass}" >> ${RUNNING_CHECKS[0]}/full.txt
	else
		echo "${eclassfile}"
		if [ -n "${ec_inherit}" ]; then
			rec_dt_eclass "" "${eclass}" ""
		fi
	fi
}

if [ -n "${1}" ]; then
	# check if eclass exists
	if ! [ -e "${REPOTREE}/eclass/${1}.eclass" ]; then
		echo "Error: ${1}.eclass not found"
		exit 1
	fi
fi
# switch to the REPOTREE dir
cd ${REPOTREE}
# export important variables
export WORKDIR
export -f main array_names get_inherits rec_dt_eclass

${FILERESULTS} && mkdir -p ${RUNNING_CHECKS[@]}

if [ -n "${1}" ]; then
	main "/eclass/${1}.eclass"
else
	find ./eclass \
		-type f -name "*.eclass" -print | sort | while read -r line; do main ${line}; done
fi

if ${FILERESULTS}; then
	gen_sort_main_v3 ${RUNNING_CHECKS[0]} 5
	gen_sort_pak_v3 ${RUNNING_CHECKS[0]} 3

	copy_checks checks
	rm -rf ${WORKDIR}
fi
