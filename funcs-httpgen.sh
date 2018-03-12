#!/bin/bash

# Filename: funcs-httpgen.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 12/03/2018

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
# this file only provides functions for generating html site outputs


gen_http_sort_main(){
	local type="${1}"
	local dir="${2}"
	local value_pack=""
	local value_filter=""
	local value_full=""
	local value_main=""

	case ${type} in
		results)
			local value_title="${dir##*/}"
			local value_line="Checks proceeded: <b>$(find ${dir} -mindepth 1 -maxdepth 1 -type d|wc -l)"
			;;
		main)
			local value_title="${dir##*/}"
			local value_line="Total Maintainers: <b>$(find ${dir}/sort-by-maintainer/ -mindepth 1 -maxdepth 1 -type f|wc -l)"
			if [ -e ${dir}/full.txt ];then
				local value_full="<a href=\"full.txt\">TXT-full.txt</a>"
			fi
			if [ -e ${dir}/sort-by-maintainer/ ];then
				local value_main="<a href=\"sort-by-maintainer\">TXT-sort-by-maintainer</a>"
			fi
			if [ -e ${dir}/sort-by-package/ ];then
				local value_pack="<a href=\"sort-by-package\">TXT-sort-by-package</a>"
			fi
			if [ -e ${dir}/sort-by-filter/ ];then
				local value_filter="<a href=\"sort-by-filter\">TXT-sort-by-filter</a>"
			elif [ -e ${dir}/sort-by-eapi/ ];then
				local value_filter="<a href=\"sort-by-eapi\">TXT-sort-by-eapi</a>"
			fi

			;;
	esac


read -r -d '' TOP <<- EOM
<html>
\t<head>
\t\t<style type="text/css"> li a { font-family: monospace; display:block; float: left; }</style>
\t\t<title>Gentoo QA: ${value_title}</title>
\t</head>
\t<body text="black" bgcolor="white">
\t\tList generated on $(date -I)</br>
\t\t${value_line}</b>
\t<pre><a href="../">../</a>  <a href="#" onclick="history.go(-1)">Back</a>  <a href="https://gentooqa.levelnine.at/results/">Home</a></pre>
\t\t<pre>${value_full}
${value_main}
${value_pack}
${value_filter}
\t\t</pre><hr><pre>
EOM

read -r -d '' BOTTOM <<- EOM
\t\t</table>
\t</pre></hr></body>
</html>
EOM
	echo -e "${TOP}"

	case ${type} in
		results)
			echo "QTY     Check"
			for u in $(find ${dir} -maxdepth 1 -mindepth 1 -type d|sort ); do
				if ! [ -e ${u}/full.txt ]; then
					val="0"
				else
					val="$(cat ${u}/full.txt | wc -l)"
				fi

				a="<a href=\"${u##*/}/index.html\">${u##*/}</a>"
				line='      '
				printf "%s%s%s\n" "${line:${#val}}" "${val}" "  ${a}"
			done
		;;

		main)
			echo "QTY     Maintainer"
			for i in $(ls ${dir}/sort-by-maintainer/); do
				main="${i}"
				val="$(cat ${dir}/sort-by-maintainer/${main} | wc -l)"

				a="<a href=\"sort-by-maintainer/${main}\">${main::-4}</a>"
				line='      '
				printf "%s%s%s\n" "${line:${#val}}" "${val}" "  ${a}"
			done
		;;
	esac

	echo -e "${BOTTOM}"
}
