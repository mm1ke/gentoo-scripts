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

startdir="$(dirname $(readlink -f $BASH_SOURCE))"
if ! [ -e ${startdir}/_vars.sh ]; then
	echo "Missing _vars.sh"
	exit 1
fi

gen_http_sort_main_v2(){
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

gen_html_out(){
	local chart="${1##*/}"
	local chart_name="${chart##*-}"
# local chart="SRT-BUG-src_uri_check"

	if [ -e /var/www/gentooqa.levelnine.at/results/checks/${1}/full.txt ]; then
		source ${startdir}/_vars.sh "${chart_name}"

		local filename="_data_template.js"

		#	if ! [ -e /var/www/gentooqa.levelnine.at/js/charts-gen/${chart_name}.js ]; then
				cp /root/scripts/${filename} /var/www/gentooqa.levelnine.at/js/charts-gen/${chart_name}.js
				sed -i "s|DATABASENAME|${databasename}|; \
					s|DATABASEVALUE|${databasevalue}|; \
					s|DATABASE|${database}|; \
					s|CANVASID|${chart_name}|; \
					s|LABEL|${label}|; \
					s|TITLE|${title}|;" \
					/var/www/gentooqa.levelnine.at/js/charts-gen/${chart_name}.js
				chmod 755 /var/www/gentooqa.levelnine.at/js/charts-gen/${chart_name}.js
		#	fi

		read -r -d '' OUT <<- EOM
		\t\t\t<li>
		\t\t\t\t<script type="text/javascript" src="js/charts-gen/${chart_name}.js"></script>
		\t\t\t\t<div id="chart-container">
		\t\t\t\t\t<canvas id="${chart_name}"></canvas>
		\t\t\t\t</div>
		\t\t\t\t<h3><a href="results/checks/${chart}/">${chart_name}</a></h3>
		\t\t\t\t<pre><p>${chart_description}</p>
		<a href="results/checks/${chart}/full.txt">full</a>     ${info_full}
		<a href="results/checks/${chart}/sort-by-maintainer">main</a>     ${info_main}
		<a href="results/checks/${chart}/sort-by-package">pack</a>     ${info_pack}
		\t\t\t\t</pre>
		\t\t\t</li>
		EOM

		echo -e "${OUT}"
	fi
}


gen_html_top(){

read -r -d '' TOP <<- EOM
<!DOCTYPE html>
<html>
\t<head>
\t\t<title>Gentoostats</title>
\t\t<h2>Gentoo QA Stats</h2>
\t\t<script type="text/javascript" src="js/jquery-3.2.1.min.js"></script>
\t\t<script type="text/javascript" src="js/Chart.min.js"></script>
\t\t<style type="text/css">
\t\t\t#chart-container {
\t\t\t\twidth: 512px;
\t\t\t\theight: auto;
\t\t\t\tmargin-right: 0 15px 0 0;
\t\t\t\tfloat: left;
\t\t\t\tmargin-right: 30px;
\t\t\t}
\t\t\tul {
\t\t\t\tlist-style-type: none;
\t\t\t\twidth: auto;
\t\t\t}
\t\t\tli {
\t\t\t\tpadding: 10px;
\t\t\t\toverflow: auto;
\t\t\t}
\t\t\tli:hover {
\t\t\t\tbackground: #eee;
\t\t\t}
\t\t</style>
\t</head>
\t<body>
\t\t<ul>
EOM

	echo -e "${TOP}"
}

gen_html_bottom(){
read -r -d '' BOTTOM <<- EOM
\t\t</ul>
\t</body>
</html>
EOM

	echo -e "${BOTTOM}"
}
