#! /usr/bin/env bash


main() {
	local ec=${1}
	local efuncs=( )
	local f=( )

	for i in ${ec}; do
		if ! $(grep -q "EXPORT_FUNCTIONS" /${GENTOOTREE}/eclass/${i}.eclass); then
			efuncs="$(sed -n 's/# @FUNCTION: //p' "/${GENTOOTREE}/eclass/${i}.eclass" | sed ':a;N;$!ba;s/\n/ /g')"
			if [ -n "${efuncs}" ]; then
				for x in ${efuncs}; do
					if ! $(grep "@FUNCTION: ${x}" -A3 -m1 /${GENTOOTREE}/eclass/${i}.eclass |grep -q "@INTERNAL"); then
						f+=( "${x}" )
					fi
				done
			fi
		else
			echo "ERR: ${i} exports functions"
			exit 1
		fi
	done
	echo "--<${ec}>--"
	echo "ALL: $(echo ${efuncs[@]}|tr ' ' ':')"
	echo "FIL: $(echo ${f[@]}|tr ' ' ':')"
	echo
}

full() {
	for i in $(find /${GENTOOTREE}/eclass/ -maxdepth 1 -mindepth 1 -type f -name *.eclass); do
		if ! $(grep -q "EXPORT_FUNCTIONS" ${i}); then
				main "$(echo ${i##*/}|rev|cut -d '.' -f2-|rev)"
		fi
	done
}

def(){
	ecl=( optfeature wrapper edos2unix ltprune l10n eutils estack preserve-libs \
		vcs-clean epatch desktop versionator user user-info flag-o-matic xdg-utils \
		libtool udev eapi7-ver pam ssl-cert )

	for i in ${ecl[@]}; do
		main ${i}
	done
}

GENTOOTREE=/usr/portage/
if [ -n "${1}" ]; then
	if [ -e /${GENTOOTREE}/eclass/${1}.eclass ]; then
		main ${1}
	elif [ "${1}" == "all" ]; then
		full
	elif [ "${1}" == "def" ]; then
		def
	fi
fi
