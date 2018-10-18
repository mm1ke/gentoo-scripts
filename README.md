# Gentoo QA Scripts

This repository contains a collection of various gentoo related scripts to find and improve the gentoo portage tree. The results of the scripts can be seen on https://gentoo.levelnine.at/ and with Statistics on https://gentooqa.levelnine.at

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
This is a simple script which check files for various mistakes in ebuilds and
metadata.xml files.
* trailing whitespaces in ebuilds
* mixed indentiations in metadata.xml files
* obosolete gentoo mirror usage
* epatch in EAPI6
* dohtml in EAPI6
* DESCRIPTION over 80 charaters
* missing proxy maintainer in metadata.xml file
* variables in the HOMEPAGE variable
* insecure git uri usage

## eapistats.sh
This script only generates statistics about EAPI usage. Also it sorts every EAPI by maintainer.

## trailwhite.sh
Simple check to find leading or trailing whitespaces in a set of variables.
For example: SRC_URI=" www.foo.com/bar.tar.gz "

## repomancheck.sh
A script which runs 'repoman full' on every package. The result is also filtered
by repomans checks.

## eclassusage.sh
This script has two checks:
* Lists ebuilds which use functions of eclasses which are not directly inherited. (usually inherited implicit)
* Lists ebuilds which inherit eclasses but doesn't use their features.
Following eclasses are checked:
 * ltprune, eutils, estack, preserve-libs, vcs-clean, epatch, desktop, versionator, user, eapi7-ver, flag-o-matic, libtool, pam, udev, xdg-utils

## eclassstats.sh
Lists the eclasses used by every ebuild.
Not including packages which don't inherit anything. Also not included are eclasses inherited by other eclasses.

## eapichecks.sh
This script generates following results:

###ebuild_obsolete_eapi
This scirpt lists every ebuild with a EAPI 0-4. The first column prints the ebuilds EAPI, the second column
prints the EAPI Versions of the packages other version (if available). This should make easier to find packages which
can be removed and also package which need some attention.

###ebuild_cleanup_candidates
This script searches for ebuilds with EAPI 0-5 and checks if there is a newer EAPI6 reversion (-r1).
If found it also checks if the KEYWORDS are the same. In this case the older versions is a good canditate to be removed.

###ebuild_stable_candidates
Also checks for ebuilds with EAPI 0-5 and a newer EAPI6 reversion (-r1).
In this the newer version has different KEYWORDS which most likely means it haven't been stabilized, why these ebuilds are good
stable request canditates

## dupuse.sh
Lists packages which define use flags locally in metadata.xml, which already exists as a global use flag.

## deadeclasses.sh
Lists ebuilds who use deprecated or obsolete eclasses.
Currently looks for following eclasses:
* fdo-mime, games, git-2, ltprune, readme.gentoo, autotools-multilib, autotools-utils and versionator

## badstyle.sh
Ebuilds which have multiple dependencies written in one line like:
```
	|| ( app-arch/foo app-arch/bar )
```
Should look like:
```
	|| (
		app-arch/foo
		app-arch/bar
	)
```

# Misc

## treehashgen.sh
This script is needed for the diff mode. It generates lists of changed packages
in a regular basis.

## tmpcheck.sh
This is a template file for new scripts.

# Tools

## maintainer.py
This python script doesn't take any arguments and just prints every gentoo project and it members.

## dteclasses.sh
Simply prints the inheration tree of a particular eclass.

## whitecheck.sh
Removes obsolete entries from whitelist files. (used for patchcheck.sh)

# Usage:

Following usage will work for every script:

* Scan the full portage tree: `./scriptname.sh full`
* Scan a whole category: `./scriptname.sh app-admin`
* Scan a single package: `./scriptname.sh app-admin/diradm`

A few scripts also support a `diff` mode in order to only check changes since
last run. This however needs `treehashgen.sh` configured to generate lists on a
recuring basis.

There are also a few Variables which can be set, but don't have too. Most importantly are:

* `PORTTREE`: Set's the portage directory path, usually `/usr/portage`
* `SCRIPT_MODE`: If this is set to `true` the script will save it's output in files. Default is `false`
* `SITEDIR`: This is the directory were the files will be written if `SCRIPT_MODE` is enabled. Default is set to `${HOME}/checks-${RANDOM}`

# License:

All scripts are free software. You can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

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

