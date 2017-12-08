# Gentoo Scripts

This repository contains a collection of various gentoo related scripts to find and improve the gentoo portage tree. The results of the script can be seen on http://gentoo.levelnine.at/

## Duration:

All scripts are actually running once a day on a gentoo VM with following specs:
* Gentoo VM
* Intel(R) Core(TM) i7-6700 CPU @ 3.40GHz
* 8 GB-RAM


Every script uses now ```parallel``` to improve duration time of every script. While most of the scripts improved quite a lot, only simplechecks didn't really improve. The reason might be because this script already makes its basic check via the find command before parallel even get exectued. Below are some numbers from before and after the usage of ```parallel``` :

Below are the estimated duration time of every script:

Script | without parallel | since parallel
------|------|--------------
eapistats | 30 m | 11 m
patchcheck | ~50 sec |  ~35 sec
patchtest | 15 m | 8 m
simplechecks | 8 m | 8 m
srctest | 11 h | 2.5 h
wwwtest | 7.5 h | 1.5 h

## patchtest.sh
This scripts tries to find unused patches from the gentoo portage tree by creating a list of files in the `files` directory and grep's every ebuild if it's used there.
In order to improve its finding rates it also replaces Variable like `${P}`,`${PV}`,`${PN}` and other variations.
Further more it also creates lists of possible Name variation in order to find patches which are written like following:

`epatch foo-bar-{patch1,patch2,patch3}.patch`

This however doesn't work 100% yet.

### Limitations:
Following Structures can't be found yet and will give a false positive:

* Usage of asterisk: `epatch foo-bar-*.patch`
* Usage of special Vars: `epatch foo-bar-${MY_VERS}.patch`
* Usage of patching via eclasses: In this case not the ebuild uses the file, but the eclass. For example: `apache-module` do that.
* Usage of braces: `epatch foo-bar-{patch1,patch2}.patch`

Note: The script already can find *some* of such versions.
* Usage for loops:
```
for i in name1 name2 name3; do
	epatch foo-bar-$i.patch
done
```
* False negative will also happen if the filename just contains the packagename and thus would be found anyway in the ebuild.
* Directories under the `files` directory will be ignored (for now)

## patchcheck.sh
This scripts is more like an spin-off of `patchtest`. It also tries to find unused patches, but doesn't look to deep.
patchcheck basically just looks into every package if it has a `files` directory and then check if the ebuilds matches (via grep) for one of the following words:

`.patch|.diff|FILESDIR|...` + a list of eclasses who uses the FILESDIR as well.

## wwwtest.sh
This script tries to get the http statuscode of every homepage of the `HOMEPAGE` variable. This script is more usefull if the `script_mode` is enabled as it will multiple lists of the result.
These a sorted after maintainer, httpcode, package and a special filter. Further more homepages which reply with a `301` statuscode (redirect) will be saved in special lists which checks the redirected page again.

## srctest.sh
This script checks if the `SRC_URI` links are available. It generates 3 return values. Available and not_available are obviously. maybe_available will be return when wget gets 403/Forbidden as return code. In that case the download might be still available but doesn't get recognized from wget when it behaves as a spider.

## simplechecks.sh
This is a simple scripts which check files for various mistakes (not just ebuilds). For now it can detect following spelling errors.
* trailing whitespaces in ebuilds
* mixed indentiations in metadata.xml files

## eapistats.sh
This script only generates statistics about EAPI usage. Also it sorts every EAPI by maintainer.

## maintainer.py
This python script doesn't take any arguments and just prints every gentoo project and it members.

# Usage:

Following usage will work for every script:

* Scan the full portage tree: `./scriptname.sh full`
* Scan a whole category: `./scriptname.sh app-admin`
* Scan a single package: `./scriptname.sh app-admin/diradm`

There are also a few Variables which can be set, but don't have too. Most importantly are:

* `PORTTREE`: Set's the portage directory path, usually `/usr/portage`
* `SCRIPT_MODE`: If this is set to `true` the script will save it's output in files. Default is `false`
* `WWWDIR`: This is the directory were the files will be written if `SCRIPT_MODE` is enabled.

# License:

All scripts are free software. You can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
