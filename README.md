
# Gentoo QA Scripts

This repository contains a collection of various qa scripts for gentoo ebuild repositories. Results of the these scripts can be seen on https://gentooqa.levelnine.at/

## patchtest.sh
This scripts tries to find unused patches by creating a list of files from the `files` directory and tries to find them in ebuilds. In order to improve its finding rates it also replaces Variable like `${P}`,`${PV}`,`${PN}` and other variations. Further more it also creates lists of possible Name variation in order to find patches which are written like following:
`epatch foo-bar-{patch1,patch2,patch3}.patch`
However this has limitations and won't find every case. Lastly it also tries to find files and patches which are used in ebuilds by calling them via an asterisk ('*'), like:
`epatch ${FILESDIR}/*.patch`

### Limitations:
Following Structures can't be found yet and will give a false positive:
* Usage of special vars which are not included in the script: `epatch foo-bar-${MY_VERS}.patch`
* Usage of patching via eclasses: In this case not the ebuild uses the file, but the eclass. For example: `apache-module` do that. However we exclude most of the beforehand.
* Usage for loops like:
```
for i in name1 name2 name3; do
	epatch foo-bar-$i.patch
done
```
* False negative can also occur if the filename is the same as the package name.
* Directories under the `files` directory will be ignored (for now)

## repostats.sh
Repostats generates statistics about repos. Following statistics are generated:
* ebuild_eapi_statistics: `EAPI` usage in repo
* ebuild_live_statistics: lists all live `9999` ebuids
* ebuild_eclass_statistics: eclass usage among ebuilds
* ebuild_licenses_statistics: license usage among ebuilds
* ebuild_keywords_statistics: keyword usage among ebuilds
* ebuild_virtual_use_statistics: `virtual/*` usage among ebuilds
* ebuild_obsolete_eapi: lists all ebuilds which have an obsolete `EAPI`
* ebuild_cleanup_candidates: lists ebuilds which are candidates to cleanup
* ebuild_stable_candidates: lists ebuilds which are candidates for stabilization
* ebuild_glep81_group_statistics: `app-group/*` usage among ebuilds
* ebuild_glep81_user_statistics: `app-user/*` usage among ebuilds

## repochecks.sh
This is the main qa script which contains most of the checks. For following checks are being made:
* ebuild_trailing_whitespaces: checks for trailing whitespaces in ebuilds
* ebuild_obsolete_gentoo_mirror_usage: checks for `mirror://gentoo` usage in ebuilds
* ebuild_epatch_in_eapi6: checks for `epatch` usage in `EAPI 6` ebuilds
* ebuild_dohtml_in_eapi6: checks for `dohtml` usage in `EAPI 6`  ebuids
* ebuild_description_over_80: checks if `DESCRIPTION` is longer then 80 chars
* ebuild_variables_in_homepages: checks if `HOMEPAGE` contains variables
* ebuild_insecure_git_uri_usage: checks for `git://` usage
* ebuild_deprecated_eclasses: lists ebuilds which uses deprecated eclasses
* ebuild_leading_trailing_whitespaces_in_variables: checks for leading / trailing whitespaces in certain variables
* ebuild_multiple_deps_per_line: lists ebuilds which have multiple dependencies in on line
* ebuild_nonexist_dependency: checks for dependencies which doesn't exists
* ebuild_obsolete_virtual: lists virtuals which has effective only on consumer left
* ebuild_missing_eclasses: lists ebuilds which are missing eclasses
* ebuild_unused_eclasses: lists ebuilds who `inherit` eclasses which are not needed
* ebuild_missing_eclasses_fatal: lists ebuilds which are missing eclasses and are not inherited indirectly
* ebuild_homepage_upstream_shutdown: lists ebuilds who have a `HOMEPAGE` to a know shutdown service
* ebuild_homepage_unsync: lists packages who have different `HOMEPAGE` among ebuilds
* ebuild_missing_zip_dependency: lists ebuilds which misses `app-arch/unzip` dependency
* ebuild_src_uri_offline: lists ebuilds who's upstream `SRC_URI` is unavailable and are the ebuild has mirror restricted enabled
* ebuild_unused_patches_simple: simple check for unused patches
* ebuild_insecure_pkg_post_config: lists ebuilds who use ch{mod,own} -R in `pkg_config` or `pkg_postinst`
* ebuild_insecure_init_scripts: lists ebuilds who use ch{mod,own} -R in init scripts

For a detailed explanation of each check please refer to the descriptions in the scripts.

## wwwtest.sh
This script tries to get the http statuscode of every homepage of the `HOMEPAGE` variable. This script is more usefull if the `script_mode` is enabled as it will multiple lists of the result.
These a sorted after maintainer, httpcode, package and a special filter. Further more homepages which reply with a `301` statuscode (redirect) will be saved in special lists which checks the redirected page again.

## srctest.sh
This script checks if the `SRC_URI` links are available. It generates 3 return values. Available and not_available are obviously. maybe_available will be return when wget gets 403/Forbidden as return code. In that case the download might be still available but doesn't get recognized from wget when it behaves as a spider.

## repomancheck.sh
A script which runs 'repoman full' on every package. The result is also filtered by repoman's checks.

# Misc

## tmpcheck.sh
This is a template file for new scripts.

## qa.sh
This script is used in order to run multiple repositories. It support to run scripts in `diff`mode in order to only run on packages which were changes since last run.

# Tools

## maintainer.py
This python script doesn't take any arguments and just prints every gentoo project and it members.

## dteclasses.sh
Simply prints the inheration tree of a particular eclass.

## whitecheck.sh
Removes obsolete entries from whitelist files. (used for patchcheck.sh)

## eclassinfo.sh
Prints functions which can be used by ebuilds.

# Usage:

Following usage will work for every script:

* Scan the full portage tree: `./scriptname.sh full`
* Scan a whole category: `./scriptname.sh app-admin`
* Scan a single package: `./scriptname.sh app-admin/diradm`

There are also a few Variables which can be set, but don't have too. Most importantly are:

* `REPOTREE`: Set's the repository path, default is: `/usr/portage`
* `FILERESULTS`: If this is set to `true` the script will save it's output in files. Default is `false`
* `RESULTSDIR`: This is the directory were the files will be copied if `SCRIPT_MODE` is enabled. Default is set to `${HOME}/${scriptname}`

### Debugging
Most script also have some debugging possibilities. Following variables can be configured:
* `DEBUG`: if this is set to `true`, debugging is enabled
* `DEBUGLEVEL`: if unset, the default is set to `1`. Changes in Levels:
	* `1` only print basic information, in this case script runs in parallel
	* `2` includes important messages, script runs not in parallel anymore
	* `3` includes non important messages
	* `<=4` includes messages from `_funcs.sh` as well.
* `DEBUGFILE`: redirects the debug output into a file.

# License:

All scripts are free software. You can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
