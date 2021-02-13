#!/bin/bash

# Filename: _funcs-httpgen.sh
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

startdir="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
if ! [ -e ${startdir}/_vars.sh ]; then
	echo "Missing _vars.sh"
	exit 1
fi

js_template="/home/bob/scripts/_files/_data_template.js"

gen_http_sort_main_v2(){
	local type="${1}"
	local dir="${2}"
	local value_pack=""
	local value_filter=""
	local value_full=""
	local value_main=""

	# set values
	case ${type} in
		results)
			local value_title="${dir##*/}"
			local value_line="Checks proceeded: <b>$(find ${dir} -mindepth 1 -maxdepth 1 -type d 2>/dev/null|wc -l)"
			;;
		main)
			local value_title="${dir##*/}"
			local value_line="Total Maintainers: <b>$(find ${dir}/sort-by-maintainer/ -mindepth 1 -maxdepth 1 -type f 2>/dev/null|wc -l)"
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
		fullpak)
			local value_title="${dir##*/}"
			local value_line="Packages affected: <b>$(find ${dir}/sort-by-package/ -type f|wc -l)"
			;;
	esac

# set top info of html page
read -r -d '' TOP <<- EOM
<html>
\t<head>
\t\t<style type="text/css"> li a { font-family: monospace; display:block; float: left; }</style>
\t\t<title>Gentoo QA: ${value_title}</title>
\t</head>
\t<body text="black" bgcolor="white">
\t\tList generated on $(date -I)</br>
\t\t${value_line}</b>
\t<pre><a href="../">../</a>  <a href="#" onclick="history.go(-1)">Back</a>  <a href="https://gentooqa.levelnine.at/">Home</a></pre>
\t\t<pre>${value_full}
${value_main}
${value_pack}
${value_filter}
\t\t</pre><hr><pre>
EOM

	echo -e "${TOP}"

	case ${type} in
		results)
			echo "QTY     Check"
			for u in $(find ${dir} -maxdepth 1 -mindepth 1 -type d 2>/dev/null|sort ); do
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
			for i in $(for x in $(ls ${dir}/sort-by-maintainer/ 2>/dev/null); do echo "$(cat ${dir}/sort-by-maintainer/$x|wc -l)|$x"; done|sort -nr); do
				main="${i##*|}"
				val="$(cat ${dir}/sort-by-maintainer/${main} | wc -l)"

				a="<a href=\"sort-by-maintainer/${main}\">${main::-4}</a>"
				line='      '
				printf "%s%s%s\n" "${line:${#val}}" "${val}" "  ${a}"
			done
			;;
		fullpak)
			echo "QTY     Package"
			for z in $(for b in $(find ${dir}/sort-by-package/ -type f 2>/dev/null); do echo "$(grep "<<<" ${b}|wc -l)|${b/${dir}\/sort-by-package\//}"; done|sort -nr); do
				local tmp_pak="${z##*|}"
				local pak="${tmp_pak/\//-}"
				local val="${z%%|*}"

				a="<a href=\"sort-by-package/${tmp_pak}\">${pak::-4}</a>"
				line='      '
				printf "%s%s%s\n" "${line:${#val}}" "${val}" "  ${a}"
			done
			;;
	esac

	echo -e "\t\t</table>\n\t</pre></hr></body>\n</html>"
}

gen_html_out(){
	local chart="${1##*/}"						# Foldername: SRT-BUG-src_uri_check
	local type="${2}"									# type: checks/stats
	local chart_name="${chart##*-}"		# chartname: src_uri_check

	if [ -e ${SITEDIR}/${type}/${chart}/full.txt ]; then

		# get the needed information from the _vars file
		source ${startdir}/_vars.sh "${chart_name}"

		mkdir -p ${SITEDIR}/charts-gen/
		cp ${js_template} ${SITEDIR}/charts-gen/${chart_name}.js

		# DBNAME comes from funcs.sh
		# other values comes from _vars.sh
		sed -i "s|DATABASENAME|${databasename}|; \
			s|DATABASEVALUE|${databasevalue}|; \
			s|DATABASE|${DBNAME}|; \
			s|CANVASID|${chart_name}|; \
			s|LABEL|${label}|; \
			s|TITLE|${title}|;" \
			${SITEDIR}/charts-gen/${chart_name}.js
		chmod 755 ${SITEDIR}/charts-gen/${chart_name}.js

		local value_filter=""
		if [ -d ${SITEDIR}/${type}/${chart}/sort-by-filter/ ];then
			local value_filter=" | <a href=\"${type}/${chart}/sort-by-filter\">filter</a>"
		elif [ -d ${SITEDIR}/${type}/${chart}/sort-by-eapi/ ];then
			local value_filter=" | <a href=\"${type}/${chart}/sort-by-eapi\">eapi</a>"
		fi

		read -r -d '' OUT <<- EOM
		\t\t\t<li>
		\t\t\t\t<script type="text/javascript" src="charts-gen/${chart_name}.js"></script>
		\t\t\t\t<div id="chart-container">
		\t\t\t\t\t<canvas id="${chart_name}"></canvas>
		\t\t\t\t</div>
		\t\t\t\t<h3><a href="${type}/${chart}/">${chart_name}</a></h3>
		\t\t\t\t<pre><a href="${type}/${chart}/full.txt">full</a> | <a href="${type}/${chart}/sort-by-maintainer">main</a> | <a href="${type}/${chart}/sort-by-package">pack</a>${value_filter}
		<p>${chart_description}</p>
		<a href="${type}/${chart}/full.txt">full</a>     ${info_full}
		<a href="${type}/${chart}/sort-by-maintainer">main</a>     ${info_main}
		<a href="${type}/${chart}/sort-by-package">pack</a>     ${info_pack}
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
\t\t<script type="text/javascript" src="../../js/jquery-3.2.1.min.js"></script>
\t\t<script type="text/javascript" src="../../js/Chart.min.js"></script>
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
	echo -e "\t\t</table>\n\t</pre></hr></body>\n</html>"
}
