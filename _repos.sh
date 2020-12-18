#!/bin/bash

# Filename: _repos.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 13/12/2020

# Copyright (C) 2020  Michael Mair-Keimberger
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
# provides various informatin about repositories
# This is only needed when running automated, not when running manually

repo="${1}"

# if the repo isn't found (case '*'), this variable is set to "true" and script
# will exit before running anythin
export REPO_ERROR=false
# if DRYRUN is set to try, scripts are going to exit after sourcing _funcs.sh
# and printing out some variables.
export DRYRUN=false

case ${repo} in
	gentoo)
		REPO="gentoo"
		DBNAME="qa_repo_${REPO}"
		SCRIPT_MODE="true"
		RESULTS_BASEDIR="/media/qa/"
		SITEDIR="${RESULTS_BASEDIR}/gentooqa.levelnine.at/results/${REPO}/"
		PORTTREE="${RESULTS_BASEDIR}/repos/${REPO}/"
		HASHTREE="${RESULTS_BASEDIR}/repohashs/${REPO}/"
		PT_WHITELIST="${REPO}-whitelist"
		export REPO DBNAME SCRIPT_MODE SITEDIR PORTTREE HASHTREE PT_WHITELIST
		;;
	pentoo)
		REPO="pentoo"
		DBNAME="qa_repo_${REPO}"
		SCRIPT_MODE="true"
		RESULTS_BASEDIR="/media/qa/"
		SITEDIR="${RESULTS_BASEDIR}/gentooqa.levelnine.at/results/${REPO}/"
		PORTTREE="${RESULTS_BASEDIR}/repos/${REPO}/"
		HASHTREE="${RESULTS_BASEDIR}/repohashs/${REPO}/"
		PT_WHITELIST="${REPO}-whitelist"
		export REPO DBNAME SCRIPT_MODE SITEDIR PORTTREE HASHTREE PT_WHITELIST
		;;
	guru)
		REPO="guru"
		DBNAME="qa_repo_${REPO}"
		SCRIPT_MODE="true"
		RESULTS_BASEDIR="/media/qa/"
		SITEDIR="${RESULTS_BASEDIR}/gentooqa.levelnine.at/results/${REPO}/"
		PORTTREE="${RESULTS_BASEDIR}/repos/${REPO}/"
		HASHTREE="${RESULTS_BASEDIR}/repohashs/${REPO}/"
		PT_WHITELIST="${REPO}-whitelist"
		export REPO DBNAME SCRIPT_MODE SITEDIR PORTTREE HASHTREE PT_WHITELIST
		;;
	kde)
		REPO="kde"
		DBNAME="qa_repo_${REPO}"
		SCRIPT_MODE="true"
		RESULTS_BASEDIR="/media/qa/"
		SITEDIR="${RESULTS_BASEDIR}/gentooqa.levelnine.at/results/${REPO}/"
		PORTTREE="${RESULTS_BASEDIR}/repos/${REPO}/"
		HASHTREE="${RESULTS_BASEDIR}/repohashs/${REPO}/"
		PT_WHITELIST="${REPO}-whitelist"
		export REPO DBNAME SCRIPT_MODE SITEDIR PORTTREE HASHTREE PT_WHITELIST
		;;
	rust)
		REPO="rust"
		DBNAME="qa_repo_${REPO}"
		SCRIPT_MODE="true"
		RESULTS_BASEDIR="/media/qa/"
		SITEDIR="${RESULTS_BASEDIR}/gentooqa.levelnine.at/results/${REPO}/"
		PORTTREE="${RESULTS_BASEDIR}/repos/${REPO}/"
		HASHTREE="${RESULTS_BASEDIR}/repohashs/${REPO}/"
		PT_WHITELIST="${REPO}-whitelist"
		export REPO DBNAME SCRIPT_MODE SITEDIR PORTTREE HASHTREE PT_WHITELIST
		;;
	science)
		REPO="science"
		DBNAME="qa_repo_${REPO}"
		SCRIPT_MODE="true"
		RESULTS_BASEDIR="/media/qa/"
		SITEDIR="${RESULTS_BASEDIR}/gentooqa.levelnine.at/results/${REPO}/"
		PORTTREE="${RESULTS_BASEDIR}/repos/${REPO}/"
		HASHTREE="${RESULTS_BASEDIR}/repohashs/${REPO}/"
		PT_WHITELIST="${REPO}-whitelist"
		export REPO DBNAME SCRIPT_MODE SITEDIR PORTTREE HASHTREE PT_WHITELIST
		;;
	*)
		REPO="FAIL"
		SCRIPT_MODE="false"
		REPO_ERROR="true"
		export REPO SCRIPT_MODE REPO_ERROR
		;;
esac

#	*)
#		REPO="reponame"																						# general repo name
#		DBNAME="qa_repo_${REPO}"																	# database name
#		SCRIPT_MODE="true"																				# running in script mode
#		RESULTS_BASEDIR="/media/qa"																# base dir of all files
#		SITEDIR="${RESULTS_BASEDIR}/sitedir/results/${REPO}/"			# sitedir
#		PORTTREE="${RESULTS_BASEDIR}/repos/${REPO}"								# portdir (sync)
#		HASHTREE="${RESULTS_BASEDIR}/repohashs/${REPO}"						# hashdir
#		export REPO DBNAME SCRIPT_MODE SITEDIR PORTTREE HASHTREE	# export all vars
#		;;
