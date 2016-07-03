#!/bin/bash

cd /mnt/data/gentoo
z=0

ls -d */* |grep -E -v "distfiles|metadata|eclass" | while read -r line; do
	category=${line%%/*}
	package_name=${line##*/}

	var_package_name='${PN}'
	var_package_name_version='${P}'
	var_package_name_re_version='${PF}'
	var_package_version='${PV}'

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

				custom_name_1=${i/${package_name}/${var_package_name}}

				package_version=$(echo ${custom_name_1}|cut -d'-' -f2)
				package_reversion=$(echo ${custom_name_1}|cut -d'-' -f3)
				package_fullname="${package_name}-${package_version}"
				package_fullname_reversion="${package_name}-${package_version}-${package_reversion}"

				custom_name_2=${i/${package_fullname}/${var_package_name_version}}

				if [[ "${package_reversion}" =~ ^r[0-9] ]];then
					custom_name_3=${i/${package_fullname_reversion}/${var_package_name_re_version}}
				else
					package_reversion=""
				fi
				if [[ "${package_version}" =~ ^[0-9] ]]; then
					custom_name_4=${i/${package_version}/${var_package_version}}
				else
					package_version=""
				fi


				if $(sed 's|"||g' ${fullpath}/*.ebuild | grep $i >/dev/null); then
					found=true
					#continue
				elif $(sed 's|"||g' ${fullpath}/*.ebuild | grep ${custom_name_1} >/dev/null); then
					found=true
				elif $(sed 's|"||g' ${fullpath}/*.ebuild | grep ${custom_name_2} >/dev/null); then
					found=true
				elif [ -n "${package_reversion}" ] && $(sed 's|"||g' ${fullpath}/*.ebuild | grep ${custom_name_3} >/dev/null); then
					found=true
				elif [ -n "${package_version}" ] && $(sed 's|"||g' ${fullpath}/*.ebuild | grep ${custom_name_4} >/dev/null); then
					found=true
				else
					echo "$line: patch $i not used"
					z=$[$z+1]
				fi
			fi
		done
	fi
#	if [ $z -eq 10 ]; then
#		break
#	fi
done
