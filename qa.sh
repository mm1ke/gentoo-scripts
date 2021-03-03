#!/bin/bash

# define repos which will be checked
# the name correspond to the github/gentoo-mirror/${REPO} name and must exist.
# the website correspond to the official/mirrored website and can be anything
# (not needed for and script related doings)
REPOSITORIES=(
	#"gentoo|https://github.com/gentoo/gentoo"
	#"kde|https://github.com/gentoo/kde"
	#"guru|https://github.com/gentoo/guru"
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
# remove previous log file
CLEANLOG=false
# set directory were the scripts are
SCRIPTDIR="/home/bob/qa/"
# get todays date
TODAY="$(date -I)"
YESTERDAY="$(date -I -d -2days)"

#
## important settings
# global variables
export DRYRUN=false
export DEBUG=false
export FILERESULTS=true
export TIMELOG="/tmp/qa-time-${TODAY}.log"
export SITEDIR="/media/qa/gentooqa/www/"
LOGFILE="/tmp/qa-scripts.log"
# testvars
#export SITEDIR="/tmp/wwwsite/"

for repodir in ${REPOSITORIES[@]}; do
	# set important variables
	export REPO="$(echo ${repodir%%|*})"
	REPOLINK="https://github.com/gentoo-mirror/${REPO}"
	export RESULTSDIR="/${SITEDIR}/results/${REPO}/"
	export REPOTREE="/tmp/repos/${REPO}/"
	export HASHTREE="/media/qa/repohashs/${REPO}/"
	export PT_WHITELIST="${REPO}-whitelist"
	# testvars
	#export RESULTSDIR="/${SITEDIR}/results/${REPO}/"
	#export REPOTREE="/tmp/repos/${REPO}/"
	#export HASHTREE="/tmp/repohashs/${REPO}/"

	${CLEANLOG} && rm ${LOGFILE}

	echo -e "\nChecking ${REPO}\n" >> ${LOGFILE}

	# the repositories need to exists in order to be updated
	if ! [ -d ${REPOTREE} ]; then
		mkdir -p ${REPOTREE}
		git clone ${REPOLINK} ${REPOTREE} >/dev/null 2>&1
	elif [ -z "$(ls -A ${REPOTREE})" ]; then
		git clone ${REPOLINK} ${REPOTREE} >/dev/null 2>&1
	else
		git -C ${REPOTREE} pull >/dev/null 2>&1
	fi

	# disable diffmode if repohashs doesn't exists (eg: new repo)
	! [ -d ${HASHTREE} ] && DIFFMODE=false
	# generate treehashes
	printf "hashtree|" >> ${TIMELOG}
	echo "Processing script: hashtree" >> ${LOGFILE}
	/usr/bin/time -f %e -a -o ${TIMELOG} ${SCRIPTDIR}/treehashgen.sh >>${LOGFILE} 2>&1

	# script which shouldn't run in diff mode
	scripts="wwwtest.sh srctest.sh"
	for s in ${scripts}; do
		printf "${s}|" >> ${TIMELOG}
		echo "Processing script: ${s}" >> ${LOGFILE}
		export SCRIPT_NAME=${s%%.*}
		/usr/bin/time -f %e -a -o ${TIMELOG} ${SCRIPTDIR}/${s} full >>${LOGFILE} 2>&1
	done

	scripts_diff="repomancheck.sh eclassusage.sh eclassstats.sh eapichecks.sh badstyle.sh \
		deadeclasses.sh eapistats.sh depcheck.sh dupuse.sh patchcheck.sh patchtest.sh \
		trailwhite.sh simplechecks.sh"
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

	# copy todays full result from treehashgen to the full-last.log
	# only after all scripts were proceded.
	cp ${HASHTREE}/full-${TODAY}.log ${HASHTREE}/full-last.log >/dev/null 2>&1
	gzip ${HASHTREE}/full-${YESTERDAY}.log >/dev/null 2>&1
	gzip ${HASHTREE}/results/results-${YESTERDAY}.log >/dev/null 2>&1

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

echo -e "\nFinish with checking REPOS\n" >>${LOGFILE}
if ${SITEGEN}; then
	export REPOS="$(echo ${REPOSITORIES[@]})"
	SITESCRIPTS=$(dirname ${SITEDIR})
	echo -e "\nGenerating HTML output:\n" >>${LOGFILE}
	${SITESCRIPTS}/sitegen.sh >>${LOGFILE} 2>&1
fi

# with /tmp/${scriptname} it's possible to override the default DIFFMODE to
# force a full run. Since this should only be done once, we remove existings
# files so that next time the default settings is used again
for diff_s in ${scripts_diff}; do
	rm -f /tmp/${diff_s%.*}
done

## copy resutls to the git dir
#rm -rf /media/qa/git/*
#cd /media/qa/gentooqa.levelnine.at/results/
#find -mindepth 4 -maxdepth 4 -name full*.txt -exec cp --parent {} /media/qa/git/ \;
#
## create git commit
#cd /media/qa/git/
#git add -A . >/dev/null 2>&1
#git commit -m "automated update @ $(date +%x%t%T)" >/dev/null 2>&1
#git push
#
## copy results to vs4
#rsync -aq --delete /media/qa/gentooqa.levelnine.at/* root@vs4:/var/www/gentooqa.levelnine.at/
