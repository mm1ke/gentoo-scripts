#!/bin/bash

cd /mnt/data/gentoo
z=0
toscan="*"

if [ -n "$1" ]; then
	if [ -d $1 ]; then
		toscan=$1
	else
		echo "$1 doesn't exist. scanning all"
	fi
fi

ls -d ${toscan}/* |grep -E -v "distfiles|metadata|eclass" | while read -r line; do
	category=${line%%/*}
	package_name=${line##*/}

	var_package_name='${PN}'
	var_package_name_version='${P}'
	var_package_name_re_version='${PF}'
	var_package_version='${PV}'
	var_package_version_reversion='${PVR}'

	fullpath="/usr/portage/${line}"
	if [ -e ${fullpath}/files ]; then
		for i in ${fullpath}/files/*; do
			if ! [ -d $i ]; then
				# original patch name
				i=${i##*/}
				# skip readme files
				if [ "$i" == "README.gentoo" ]; then
					continue
				fi

				for ebuild in ${fullpath}/*.ebuild; do
					ebuild_full=${ebuild%.*}
					ebuild_full=${ebuild_full##*/}
					ebuild_version=$(echo ${ebuild_full/${package_name}}|cut -d'-' -f2)
					ebuild_reversion=$(echo ${ebuild_full/${package_name}}|cut -d'-' -f3)
					#echo "$package_name $ebuild_version $ebuild_reversion"


					custom_name_1=${i/${package_name}/${var_package_name}}
					custom_name_2=${i/${package_name}-${ebuild_version}/${var_package_name_version}}
					custom_name_4=${i/${ebuild_version}/${var_package_version}}
					if [ -n "${ebuild_reversion}" ]; then
						custom_name_3=${i/${package_name}-${ebuild_version}-${ebuild_reversion}/${var_package_name_re_version}}
						custom_name_5=${i/${ebuild_version}-${ebuild_reversion}/${var_package_version_reversion}}
					else
						custom_name_5=${i/${ebuild_version}/${var_package_version_reversion}}
					fi

					
					if $(sed 's|"||g' ${ebuild} | grep $i >/dev/null); then
						found=true
					elif $(sed 's|"||g' ${ebuild} | grep ${custom_name_1} >/dev/null); then
						found=true
					elif $(sed 's|"||g' ${ebuild} | grep ${custom_name_2} >/dev/null); then
						found=true
					elif [ -n "${ebuild_reversion}" ] && $(sed 's|"||g' ${ebuild} | grep ${custom_name_3} >/dev/null); then
						found=true
					elif $(sed 's|"||g' ${ebuild} | grep ${custom_name_5} >/dev/null); then
						found=true
					elif $(sed 's|"||g' ${ebuild} | grep ${custom_name_4} >/dev/null); then
						found=true
					else
						found=false
					fi

					$found && break

				done

				if ! $found; then
					echo "$line: patch $i not used"
					z=$[$z+1]
				fi

				found=false
			fi
		done
	fi
done
