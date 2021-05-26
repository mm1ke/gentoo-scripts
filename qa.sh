#!/bin/bash

# define repos which will be checked
# the name correspond to the github/gentoo-mirror/${REPO} name and must exist.
# the website correspond to the official/mirrored website and can be anything
# (not needed for and script related doings)
REPOSITORIES=(
	"gentoo|https://github.com/gentoo/gentoo"
	"kde|https://github.com/gentoo/kde"
	"guru|https://github.com/gentoo/guru"
	"science|https://github.com/gentoo/sci"
	"rust|https://github.com/gentoo/gentoo-rust"
	"pentoo|https://github.com/pentoo/pentoo-overlay"
	)

# enable diffmode per default
DIFFMODE=true
# write DB entries
DBWRITE=true
# create website data
SITEGEN=true
# create git commit
GITCOMMIT=true
GITDIR="/media/qa/git/"
# remove previous log file
CLEANLOG=true
# set directory were the scripts are
SCRIPTDIR="/home/bob/qa/"
# logfile
LOGFILE="/tmp/qa-scripts.log"

mkdir -p ${GITINFO}

#
## important settings
# global variables
export DRYRUN=false
export DEBUG=false
export FILERESULTS=true
export TIMELOG="/tmp/qa-time-$(date -I).log"
export SITEDIR="/media/qa/gentooqa/www/"
# gentoo main tree directory, requried for certain checks
export GTREE="/tmp/repos/gentoo/"
export GITINFO="${SCRIPTDIR}/gitinfo"
# testvars
#export SITEDIR="/tmp/wwwsite/"

${CLEANLOG} && rm ${LOGFILE}

for repodir in ${REPOSITORIES[@]}; do
	# set important variables
	export REPO="$(echo ${repodir%%|*})"
	REPOLINK="https://github.com/gentoo-mirror/${REPO}"
	export RESULTSDIR="/${SITEDIR}/results/${REPO}/"
	export REPOTREE="/tmp/repos/${REPO}/"
	export PT_WHITELIST="${REPO}-whitelist"
	# testvars
	#export RESULTSDIR="/${SITEDIR}/results/${REPO}/"
	#export REPOTREE="/tmp/repos/${REPO}/"
	#export HASHTREE="/tmp/repohashs/${REPO}/"


	echo -e "\nChecking ${REPO}\n" >> ${LOGFILE}
	# the repositories need to exists in order to be updated
	if ! [ -d ${REPOTREE} ]; then
		mkdir -p ${REPOTREE}
		git clone ${REPOLINK} ${REPOTREE} >/dev/null 2>&1
	elif [ -z "$(ls -A ${REPOTREE})" ]; then
		git clone ${REPOLINK} ${REPOTREE} >/dev/null 2>&1
	else
		git -C ${REPOTREE} rev-parse HEAD > ${GITINFO}/${REPO}-head
		git -C ${REPOTREE} pull >/dev/null 2>&1
	fi

	echo -e "\nFind changed packages for ${REPO}" >> ${LOGFILE}
	if [ -s "${GITINFO}/${REPO}-head" ]; then
		git -C ${REPOTREE} diff --name-only $(<${GITINFO}/${REPO}-head) HEAD \
			| cut -d'/' -f1,2|sort -u|grep  -e '\([a-z0-9].*-[a-z0-9].*/\|virtual/\)' \
			>> ${GITINFO}/${REPO}-catpak.log
	else
		DIFFMODE=false
	fi

	scripts_diff="wwwtest.sh srctest.sh repostats.sh repochecks.sh \
		repomancheck.sh patchtest.sh"
	for s_v2 in ${scripts_diff}; do
		printf "${s_v2}|" >> ${TIMELOG}
		echo "Processing script: ${s_v2}" >> ${LOGFILE}
		export SCRIPT_NAME=${s_v2%%.*}
		if ${DIFFMODE}; then
			/usr/bin/time -f %e -a -o ${TIMELOG} ${SCRIPTDIR}/${s_v2} diff >>${LOGFILE} 2>&1
		else
			/usr/bin/time -f %e -a -o ${TIMELOG} ${SCRIPTDIR}/${s_v2} full >>${LOGFILE} 2>&1
		fi
	done

	echo -e "\nFinishing checks for ${REPO}\n" >> ${LOGFILE}
	mv ${GITINFO}/${REPO}-catpak.log ${GITINFO}/${REPO}-changes-$(date -I).log
	find ${GITINFO} -name "${REPO}-changes-*" -type f -printf '%T@ %p\n' \
		| sort -k1 -n | head -n-7 | cut -d' ' -f2 | xargs -r rm

	# create full package/maintainer lists
	echo "Processing script: genlists" >> ${LOGFILE}
	${SCRIPTDIR}/genlists.sh >>${LOGFILE} 2>&1

	# write results into database
	# must be done while the for loop since benchmark statistics are being
	# overwriten each run
	if ${DBWRITE}; then
		SITESCRIPTS=$(dirname ${SITEDIR})
		echo -e "\nCreating Database Entries for ${REPO}\n" >>${LOGFILE}
		${SITESCRIPTS}/dbinsert.sh >>${LOGFILE} 2>&1
	fi

	rm ${TIMELOG}
done

echo -e "\nFinish with checking all repos\n" >>${LOGFILE}
if ${SITEGEN}; then
	export REPOS="$(echo ${REPOSITORIES[@]})"
	SITESCRIPTS=$(dirname ${SITEDIR})
	echo -e "\nGenerating HTML output:\n" >>${LOGFILE}
	${SITESCRIPTS}/sitegen.sh >>${LOGFILE} 2>&1
fi

echo -e "\nFinish generating HTML output\n" >>${LOGFILE}
if ${GITCOMMIT}; then
	echo -e "\nCreating git commit:\n" >>${LOGFILE}
	# first remove old results
	[ -n "${GITDIR}" ] && rm -rf /${GITDIR}/*
	cd /${SITEDIR}/results/
	## copy resutls to the git dir
	find -mindepth 4 -maxdepth 4 -name full*.txt -exec cp --parent {} /${GITDIR}/ \;
	## create git commit
	cd /${GITDIR}/
	git add -A . >/dev/null 2>&1
	git commit -m "automated update @ $(date +%x%t%T)" >/dev/null 2>&1
	git push
fi

# with /tmp/${scriptname} it's possible to override the default DIFFMODE to
# force a full run. Since this should only be done once, we remove existings
# files so that next time the default settings is used again
for diff_s in ${scripts_diff}; do
	rm -f /tmp/${diff_s%.*}
done

echo -e "\nDONE" >>${LOGFILE}
