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
# logfile
LOGFILE="/tmp/qa-scripts.log"

#
## important settings
# global variables
export DRYRUN=false
export DEBUG=false
export FILERESULTS=true
export TIMELOG="/tmp/qa-time-$(date -I).log"
export SITEDIR="/mnt/data/qa/gentooqa/www/"
# gentoo main tree directory, requried for certain checks
export GTREE="/tmp/repos/gentoo/"
export GITINFO="${SCRIPTDIR}/gitinfo"
mkdir -p "${GITINFO}"
# testvars
#export SITEDIR="/tmp/wwwsite/"

${CLEANLOG} && rm ${LOGFILE}
cd ${SCRIPTDIR}

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
	# check if directory exists
	# > if not, create dir, clone repo
	if ! [ -d "${REPOTREE}" ]; then
		mkdir -p "${REPOTREE}"
		git clone ${REPOLINK} ${REPOTREE} >/dev/null 2>&1
	# directory exists but is empty
	# > clone repo
	elif [ -z "$(ls -A ${REPOTREE})" ]; then
		git clone ${REPOLINK} ${REPOTREE} >/dev/null 2>&1
	# repo exists, sync it
	else
		if $(git -C ${REPOTREE} status >/dev/null 2>${LOGFILE}); then
			git -C ${REPOTREE} rev-parse HEAD > ${GITINFO}/${REPO}-head
			git -C ${REPOTREE} pull >/dev/null 2>&1
		else
			echo "Error syncing ${REPO} git tree. Exiting" >> ${LOGFILE}
			exit
		fi
	fi

	if [ -s "${GITINFO}/${REPO}-head" ]; then
		echo -e "\nFind changed packages for ${REPO}" >> ${LOGFILE}
		git -C ${REPOTREE} diff --name-only $(<${GITINFO}/${REPO}-head) HEAD \
			| cut -d'/' -f1,2|sort -u|grep  -e '\([a-z0-9].*-[a-z0-9].*/\|virtual/\)' \
			>> ${GITINFO}/${REPO}-catpak.log
		echo -e "\nFind removed packages for ${REPO} >> ${LOGFILE}"
		git -C ${REPOTREE} diff --diff-filter=D --summary $(<${GITINFO}/${REPO}-head) HEAD \
			| grep metadata.xml | cut -d' ' -f5 \
			>> ${GITINFO}/${REPO}-catpak-rm.log
	else
		DIFFMODE=false
	fi

	echo -e "\nUpdate pkgcheck cache for ${REPO}" >> ${LOGFILE}
	pkgcheck cache -r ${REPOTREE} -uf >> ${LOGFILE}

	scripts_diff="repostats.sh repochecks.sh"
	for s_v2 in ${scripts_diff}; do
		printf "${s_v2}|" >> ${TIMELOG}
		echo "Processing script: ${s_v2}" >> ${LOGFILE}
		export SCRIPT_NAME=${s_v2%%.*}
		# if /tmp/${SCRIPT_NAME} exist run in normal mode this way it's possible
		# to override the diff mode this is usefull when the script got updates
		# which should run on the whole tree
		if ${DIFFMODE} && ! [[ -e "/tmp/${SCRIPT_NAME}" ]]; then
			/usr/bin/time -q -f %e -a -o ${TIMELOG} ${SCRIPTDIR}/${s_v2} diff >> ${LOGFILE} 2>&1
		else
			/usr/bin/time -q -f %e -a -o ${TIMELOG} ${SCRIPTDIR}/${s_v2} full >> ${LOGFILE} 2>&1
		fi
	done

	echo -e "\nFinishing checks for ${REPO}\n" >> ${LOGFILE}
	mv ${GITINFO}/${REPO}-catpak.log ${GITINFO}/${REPO}-changes-$(date -I).log
	mv ${GITINFO}/${REPO}-catpak-rm.log ${GITINFO}/${REPO}-deletes-$(date -I).log
	find ${GITINFO} -name "${REPO}-changes-*" -type f -printf '%T@ %p\n' \
		| sort -k1 -n | head -n-7 | cut -d' ' -f2 | xargs -r rm
	find ${GITINFO} -name "${REPO}-deletes-*" -type f -printf '%T@ %p\n' \
		| sort -k1 -n | head -n-7 | cut -d' ' -f2 | xargs -r rm

	# create full package/maintainer lists
	echo "Processing script: genlists" >> ${LOGFILE}
	${SCRIPTDIR}/genlists.sh >> ${LOGFILE} 2>&1

	# write results into database
	# must be done while the for loop since benchmark statistics are being
	# overwriten each run
	if ${DBWRITE}; then
		SITESCRIPTS=$(dirname ${SITEDIR})
		echo -e "\nCreating Database Entries for ${REPO}\n" >> ${LOGFILE}
		${SITESCRIPTS}/dbinsert.sh >> ${LOGFILE} 2>&1
	fi

	rm ${TIMELOG}
done

echo -e "\nFinish with checking all repos\n" >> ${LOGFILE}
if ${SITEGEN}; then
	export REPOS="$(echo ${REPOSITORIES[@]})"
	SITESCRIPTS=$(dirname ${SITEDIR})
	echo -e "Generating HTML output:\n" >> ${LOGFILE}
	${SITESCRIPTS}/sitegen.sh >> ${LOGFILE} 2>&1
fi

echo -e "Finish generating HTML output\n" >> ${LOGFILE}

# with /tmp/${scriptname} it's possible to override the default DIFFMODE to
# force a full run. Since this should only be done once, we remove existings
# files so that next time the default settings is used again
for diff_s in ${scripts_diff}; do
	rm -f /tmp/${diff_s%.*}
done

echo -e "\nDONE" >> ${LOGFILE}
