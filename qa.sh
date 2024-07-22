#!/bin/bash

# logfile
LOGFILE="/tmp/qa-scripts.log"
ERRFILE="/tmp/qa-scripts-err.log"
logstd() { while IFS='' read -r line; do echo "($(date '+%Y-%m-%d %H:%M')) ${0##*/} Info: $line" >> ${LOGFILE}; done }
logerr() { while IFS='' read -r line; do echo "($(date '+%Y-%m-%d %H:%M')) ${0##*/} Error: $line" >> ${ERRFILE}; done }

# define repos which will be checked
# the name correspond to the github/gentoo-mirror/${REPO} name and must exist.
# the website correspond to the official/mirrored website and can be anything
# (not needed for and script related doings)
REPOSITORIES=(
	"gentoo|https://github.com/gentoo/gentoo"
	"kde|https://github.com/gentoo/kde"
	"guru|https://github.com/gentoo/guru"
	"science|https://github.com/gentoo/sci"
	"pentoo|https://github.com/pentoo/pentoo-overlay"
)

# enable diffmode per default
DIFFMODE=true
# write DB entries
DBWRITE=true
# create website data
SITEGEN=true
# remove previous log file
CLEANLOG=true
# set directory were the scripts are
SCRIPTDIR="/home/bob/qa/"

#
## important settings
# global variables
export DRYRUN=false
export DEBUG=false
export FILERESULTS=true
export TIMELOG="/tmp/qa-time-$(date -I).log"
export SITEDIR="/mnt/data/qa/gentooqa.levelnine.at/gentooqa/www/"
# gentoo main tree directory, requried for certain checks
export GTREE="/mnt/data/qa/repos/gentoo/"
export GITINFO="${SCRIPTDIR}/gitinfo"
mkdir -p "${GITINFO}"
# testvars
#export SITEDIR="/tmp/wwwsite/"

${CLEANLOG} && rm ${LOGFILE} ${ERRFILE}
cd ${SCRIPTDIR}

for repodir in ${REPOSITORIES[@]}; do
	# set important variables
	export REPO="$(echo ${repodir%%|*})"
	REPOLINK="https://github.com/gentoo-mirror/${REPO}"
	export RESULTSDIR="/${SITEDIR}/results/${REPO}/"
	export REPOTREE="/mnt/data/qa/repos/${REPO}/"
	export PT_WHITELIST="${REPO}-whitelist"
	# testvars
	#export RESULTSDIR="/${SITEDIR}/results/${REPO}/"
	#export REPOTREE="/mnt/data/repos/${REPO}/"
	#export HASHTREE="/mnt/data/repohashs/${REPO}/"

	echo -e "\nChecking ${REPO}\n" | (logstd)
	# the repositories need to exists in order to be updated
	# check if directory exists
	# > if not, create dir, clone repo
	if ! [ -d "${REPOTREE}" ]; then
		mkdir -p "${REPOTREE}"
		git clone ${REPOLINK} ${REPOTREE} 1> /dev/null 2> >(logerr)
	# directory exists but is empty
	# > clone repo
	elif [ -z "$(ls -A ${REPOTREE})" ]; then
		git clone ${REPOLINK} ${REPOTREE} 1> /dev/null 2> >(logerr)
	# repo exists, sync it
	else
		if $(git -C ${REPOTREE} status 1> >(logstd) 2> >(logerr)); then
			# if the keephead file exists, don't update repo-head file
			# this way an older head (for example form the day before) could be used
			# to run the scripts. this file will be removed at the end.
			if [ -e "/tmp/keephead" ]; then
				git -C ${REPOTREE} pull 1> /dev/null 2> >(logerr)
			else
				git -C ${REPOTREE} rev-parse HEAD > ${GITINFO}/${REPO}-head
				git -C ${REPOTREE} pull 1> /dev/null 2> >(logerr)
			fi
		else
			echo "Error syncing ${REPO} git tree. Exiting" | (logstd)
			exit
		fi
	fi

	if [ -s "${GITINFO}/${REPO}-head" ]; then
		echo -e "\nFind changed packages for ${REPO}" | (logstd)
		git -C ${REPOTREE} diff --name-only $(<${GITINFO}/${REPO}-head) HEAD \
			| cut -d'/' -f1,2|sort -u|grep  -e '\([a-z0-9].*-[a-z0-9].*/\|virtual/\)' \
			>> ${GITINFO}/${REPO}-catpak.log
		echo -e "\nFind removed packages for ${REPO}" | (logstd)
		git -C ${REPOTREE} diff --diff-filter=D --summary $(<${GITINFO}/${REPO}-head) HEAD \
			| grep metadata.xml | cut -d' ' -f5 \
			>> ${GITINFO}/${REPO}-catpak-rm.log
	else
		DIFFMODE=false
	fi

	echo -e "\nUpdate pkgcheck cache for ${REPO}" | (logstd)
	pkgcheck cache -r ${REPOTREE} -uf | (logstd)

	scripts_diff="repostats.sh repochecks.sh"
	for s_v2 in ${scripts_diff}; do
		printf "${s_v2}|" >> ${TIMELOG}
		echo "Processing script: ${s_v2}" | (logstd)
		export SCRIPT_NAME=${s_v2%%.*}
		# if /tmp/${SCRIPT_NAME} exist run in normal mode this way it's possible
		# to override the diff mode this is usefull when the script got updates
		# which should run on the whole tree
		if ${DIFFMODE} && ! [[ -e "/tmp/${SCRIPT_NAME}" ]]; then
			/usr/bin/time -q -f %e -a -o ${TIMELOG} ${SCRIPTDIR}/${s_v2} diff 1> >(logstd) 2> >(logerr)
		else
			/usr/bin/time -q -f %e -a -o ${TIMELOG} ${SCRIPTDIR}/${s_v2} full 1> >(logstd) 2> >(logerr)
		fi
	done

	echo -e "\nFinishing checks for ${REPO}\n" | (logstd)
	mv ${GITINFO}/${REPO}-catpak.log ${GITINFO}/${REPO}-changes-$(date -I).log
	mv ${GITINFO}/${REPO}-catpak-rm.log ${GITINFO}/${REPO}-deletes-$(date -I).log
	find ${GITINFO} -name "${REPO}-changes-*" -type f -printf '%T@ %p\n' \
		| sort -k1 -n | head -n-7 | cut -d' ' -f2 | xargs -r rm
	find ${GITINFO} -name "${REPO}-deletes-*" -type f -printf '%T@ %p\n' \
		| sort -k1 -n | head -n-7 | cut -d' ' -f2 | xargs -r rm

	# create full package/maintainer lists
	echo "Processing script: genlists" | (logstd)
	${SCRIPTDIR}/genlists.sh 1> >(logstd) 2> >(logerr)

	# write results into database
	# must be done while the for loop since benchmark statistics are being
	# overwriten each run
	if ${DBWRITE}; then
		SITESCRIPTS=$(dirname ${SITEDIR})
		echo -e "\nCreating Database Entries for ${REPO}\n" | (logstd)
		${SITESCRIPTS}/dbinsert.sh 1> >(logstd) 2> >(logerr)
	fi

	rm ${TIMELOG}
done

echo -e "\nFinish with checking all repos\n" | (logstd)
if ${SITEGEN}; then
	export REPOS="$(echo ${REPOSITORIES[@]})"
	SITESCRIPTS=$(dirname ${SITEDIR})
	echo -e "Generating HTML output:\n" | (logstd)
	${SITESCRIPTS}/sitegen.sh 1> >(logstd) 2> >(logerr)
fi

	echo -e "Finish generating HTML output\n" | (logstd)

# with /tmp/${scriptname} it's possible to override the default DIFFMODE to
# force a full run. Since this should only be done once, we remove existings
# files so that next time the default settings is used again
for diff_s in ${scripts_diff}; do
	rm -f /tmp/${diff_s%.*}
done
# the same as with the temporay scriptname file, remove /tmp/keephead
rm -f /tmp/keephead

echo -e "\nDONE" | (logstd)
