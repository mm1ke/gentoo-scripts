#!/bin/bash

cd /mnt/data/gentoo
z=0
ls -d */* |grep -E -v "distfiles|metadata|eclass" | while read -r line; do
	cat=${line%%/*}
	pak=${line##*/}
	genpak='${PN}'
	genpak2='"${PN}"'
	genpakv='${P}'
	genpakv2='"${P}"'
	fullpath="/usr/portage/$line"
	if [ -e ${fullpath}/files ]; then
		for i in ${fullpath}/files/*; do
			if ! [ -d $i ]; then

				i=${i##*/}
				if [ "$i" == "README.gentoo" ]; then
					continue
				fi
				i_genpak=${i/$pak/$genpak}
				i_genpak2=${i/$pak/$genpak2}

				version=$(echo $i_genpak|cut -d'-' -f2)
				fullname="${pak}-${version}"
				i_genpakv=${i/${fullname}/$genpakv}
				i_genpakv2=${i/${fullname}/$genpakv2}

				if $(grep ${i} ${fullpath}/*.ebuild >/dev/null); then
					found=true
					#continue
				elif $(grep ${i_genpak} ${fullpath}/*.ebuild >/dev/null); then
					found=true
				elif $(grep ${i_genpakv} ${fullpath}/*.ebuild >/dev/null); then
					found=true
				elif $(grep ${i_genpak2} ${fullpath}/*.ebuild >/dev/null); then
					found=true
				elif $(grep ${i_genpakv2} ${fullpath}/*.ebuild >/dev/null); then
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
