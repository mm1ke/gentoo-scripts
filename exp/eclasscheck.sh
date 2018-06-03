#!/bin/bash

# Filename: patchtest
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 01/08/2016

# Copyright (C) 2016  Michael Mair-Keimberger
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
# simple scirpt to find unused patches in the gentoo portage tree

if [ "$(hostname)" = methusalix ]; then
	PORTTREE="/usr/portage"
	script_mode=true
	script_mode_dir="/var/www/gentoo.levelnine.at/eclasscheck/"
else
	PORTTREE="/mnt/data/gentoo/"
	script_mode=false
fi
cd ${PORTTREE}

usage() {
	echo "You need an argument"
}

if [ -z "${1}" ]; then
	usage
	exit 1
else
	if [ -d "${PORTTREE}/${1}" ]; then
		level="${1}"
		MAXD=0
		MIND=0
		_cat=${1%%/*}
		_pac=${1##*/}
		if [ -z "${_pac}" ] || [ "${_cat}" == "${_pac}" ]; then
			MAXD=1
			MIND=1
		fi
	elif [ "${1}" == "full" ]; then
		level=""
		MAXD=2
		MIND=2
	else
		echo "${PORTTREE}/${1}: Path not found"
	fi
fi


get_main_min(){
	local ret=`/usr/bin/python3 - $1 <<END
import xml.etree.ElementTree
import sys
pack = str(sys.argv[1])
projxml = "/usr/portage/" + pack + "/metadata.xml"
e = xml.etree.ElementTree.parse(projxml).getroot()
c = ""
for i in e:
	for v in i.iter('maintainer'):
		b=str(v[0].text)
		c+=str(b)+':'
print(c)
END`
	echo $ret
}

check_by_usage(){
	_filter_vars="SOURCE|DESCRIPTION|HOMEPAGE|LICENSE|EAPI|BUILD|SRC_URI|DOCS|PATCHES|PREFIX|EPREFIX"
	ebuild=$1
	echo "checking $ebuild"
	eclasses=()
	eclasses_ext=()
	for ec in ${PORTTREE}/eclass/*.eclass; do
		# quickcheck
		_all_e_fun_var="$(grep -E "@ECLASS-VARIABLE|@FUNCTION" ${ec} | grep -v -E "${_filter_vars}" |cut -d ':' -f2|tr -d ' '|tr '\n' '|')"
		if $(grep -E "${_all_e_fun_var:1:-1}" ${ebuild} >/dev/null); then
			local _e_funcs="$(grep "@FUNCTION" ${ec} | cut -d ':' -f2|tr -d ' '|tr '\n' ' ')"
			for f in ${_e_funcs}; do
				if [ -n "$(grep "\<$f\>" $ebuild)" ]; then
					eclasses+=("$(basename ${ec%.eclass})")
					eclasses_ext+=("${f}:$(basename ${ec%.eclass})")
					#break
					echo " $package_name uses function $f from $(basename $ec)"
				fi
			done
			_e_vars="$(grep "@ECLASS-VARIABLE" ${ec} | cut -d ':' -f2|tr -d ' '|tr '\n' ' '|grep -v -E "${_filter_vars}")"
			for v in ${_e_vars}; do
				if [ -n "$(grep "\<$v\>" $ebuild)" ]; then
					eclasses+=("$(basename ${ec%.eclass})")
					eclasses_ext+=("${v}:$(basename ${ec%.eclass})")
					#break
					echo " $package_name uses variable $v from $(basename $ec)"
				fi
			done
		fi
		


	done
#	echo ${eclasses_ext[@]}

	m_ecl=()
	l_ecl=()
	for match in ${eclasses_ext[@]}; do
		func=${match%%:*}
		ecla=${match##*/}
		u=$(printf -- '%s\n' "${eclasses_ext[@]}"|grep "\<${func}\>:"|cut -d':' -f2)
		c=$(echo $u|sed 's/ /:/g')
		b=$(echo $u|sed 's/ /\|\|/g')
#		echo $u|sed 's/ /\|\|/g'
		m_ecl+=("${c}")
		l_ecl+=("${b}")
		#m_ecl+=("$(printf -- '%s\n' "${eclasses_ext[@]}"|grep "\<$func\>"|cut -d':' -f2)")
#		echo $m_ecl
#		echo
	done

	mapfile -t m_ecl < <(printf '%s\n' "${m_ecl[@]}"|sort -u)
	mapfile -t l_ecl < <(printf '%s\n' "${l_ecl[@]}"|sort -u)

	mapfile -t eclasses < <(printf '%s\n' "${eclasses[@]}"|sort -u)
	
#	ebuild_eclasses=("$(grep inherit ${ebuild}|cut -d ' ' -f2-)")
	ebuild_eclasses=()
	for i in $(grep inherit ${ebuild}|cut -d ' ' -f2-); do
		ebuild_eclasses+=("--${i}--")
	done
	#echo ${ebuild_eclasses[@]}
	tmp_ebuild_eclasses=("${ebuild_eclasses[@]}")
	missing_eclasses=()
	found=false
	for blub in ${m_ecl[@]}; do
		for e in $(echo $blub|tr ':' ' '); do
			#echo $e
			if $(echo ${ebuild_eclasses[@]}|grep "\-\-${e}\-\-" >/dev/null); then
				#echo "found $e"
				tmp_ebuild_eclasses=("${tmp_ebuild_eclasses[@]/\-\-$e\-\-}")
				found=true
				break
			fi
		done
		if ! $found; then
			#echo "not found ${blub}"
			missing_eclasses+=("${blub}")
		fi
		found=false
	done

	#echo " eclasses needed by functions: ${l_ecl[@]}"
	#echo " eclasses by ebuild: $(grep inherit ${ebuild}|cut -d ' ' -f2-)"
#	echo 
	if [ -n "$(echo ${missing_eclasses[@]}|tr -d ' ')" ] || [ -n "$(echo ${tmp_ebuild_eclasses[@]}|tr -d ' ')" ]; then
		echo " eclasses missing: $(echo ${missing_eclasses[@]}|sed 's|:|\|\||g')"
		echo " eclasses to much: $(echo ${tmp_ebuild_eclasses[@]}|sed 's|--||g')"
		echo
	fi

#	echo " eclasses needed: ${eclasses[@]}"
	ebuild_eclasses=()
	tmp_ebuild_eclasses=()
	missing_eclasses=()
	eclasses=()
}

main() {

	category="$(echo ${package}|cut -d'/' -f2)"
	package_name=${line##*/}
	fullpath="/${PORTTREE}/${line}"

	for e in ${fullpath}/*.ebuild; do
		check_by_usage $e
	done

}

if $script_mode; then
	rm -rf ${script_mode_dir}/*
fi

find ./${level} -mindepth $MIND -maxdepth $MAXD \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type d -print | while read -r line; do
	main ${line}
done


#ls -d ${cat}/${pac} |grep -E -v "distfiles|metadata|eclass" | while read -r line; do


#	# check if the patches folder exist
#	if [ -e ${fullpath}/files ]; then
#		if grep -E ".diff|.patch|FILESDIR|apache-module|elisp|vdr-plugin-2|games-mods|ruby-ng|readme.gentoo|readme.gentoo-r1|bzr|bitcoincore|gnatbuild|gnatbuild-r1|java-vm-2|mysql-cmake|mysql-multilib-r1|php-ext-source-r2|php-ext-source-r3|php-pear-r1|selinux-policy-2|toolchain-binutils|toolchain-glibc|x-modular" ${fullpath}/*.ebuild >/dev/null; then
#			continue
#		else
#			if $script_mode; then
#				main=$(get_main_min "${category}/${package_name}")
#				mkdir -p ${script_mode_dir}/sort-by-package/${category}
#				ls ${PORTTREE}/${category}/${package_name}/files/* > ${script_mode_dir}/sort-by-package/${category}/${package_name}.txt
#				echo "${category}/${package_name}" >> ${script_mode_dir}/full.txt
#				echo -e "${category}/${package_name}\t\t${main}" >> ${script_mode_dir}/full-with-maintainers.txt
#
#			else
#				echo "${category}/${package_name}"
#			fi
#		fi
#	fi
#done

if $script_mode; then
	for a in $(cat ${script_mode_dir}/full-with-maintainers.txt |cut -d$'\t' -f3|tr ':' '\n'|tr ' ' '_'| grep -v "^[[:space:]]*$"|sort|uniq); do
		mkdir -p ${script_mode_dir}/sort-by-maintainer/
		grep "${a}" ${script_mode_dir}/full-with-maintainers.txt > ${script_mode_dir}/sort-by-maintainer/"$(echo ${a}|sed "s|@|_at_|; s|gentoo.org|g.o|;")".txt
	done
fi
