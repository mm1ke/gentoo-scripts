
# Gentoo QA Scripts

This repository contains a collection of various qa scripts for gentoo ebuild repositories. Results of the these scripts can be seen on https://gentooqa.levelnine.at/

## repostats.sh
Repostats generates statistics about repos. Following statistics are generated:
* ebuild_eapi_statistics: `EAPI` usage in repo
* ebuild_live_statistics: lists all live (`9999`) ebuilds
* ebuild_eclass_statistics: eclass usage among ebuilds
* ebuild_licenses_statistics: `LICENSE` usage among ebuilds
* ebuild_keywords_statistics: keyword usage among ebuilds
* ebuild_virtual_use_statistics: `virtual/*` usage among ebuilds
* ebuild_obsolete_eapi: lists all ebuilds which have an obsolete `EAPI`
* ebuild_cleanup_candidates: lists ebuilds which are candidates to cleanup
* ebuild_stable_candidates: lists ebuilds which are candidates for stabilization
* ebuild_glep81_group_statistics: `app-group/*` usage among ebuilds
* ebuild_glep81_user_statistics: `app-user/*` usage among ebuilds

## repochecks.sh
`repochecks` scan ebuilds, categories or a whole repository for various errors and mistakes. Nowadays many checks are already done by the the amazing tool `dev-util/pkgcheck`, which is why i've included the checks from `pkgcheck` into `repochecks`.  
Since `pkgcheck` already has mostly the same checks as `repochecks`, checks which are basically the same are going to be removed in further updates.
Following a list of all the checks done with `repochecks` and (if available) the correspondig check in `pkgcheck`.
* ebuild_install_worthless_file_install: checks for ebuilds which install `INSTALL` files
* ebuild_trailing_whitespaces: checks for trailing whitespaces in ebuilds
  * **pkgcheck**: WhitespaceFound
* ebuild_obsolete_dependency_tracking: checks if ebuilds have `--disable-dependency-tracking` enabled. Not needed since `EAPI4`
* ebuild_obsolete_silent_rules: checks if ebuilds have `--disable-silent-rules` enabled. Not needed since `EAPI5`
* ebuild_obsolete_disable_static: checks if ebuilds have `--disable-static` enabled. Not needed since `EAPI8`
* ebuild_variable_missing_braces: Simple check to find variables in ebuilds which not use curly braces.
* ebuild_epatch_in_eapi6: checks for `epatch` usage in `EAPI 6` ebuilds
  * going to be removed with the last EAPI6 ebuild
* ebuild_dohtml_in_eapi6: checks for `dohtml` usage in `EAPI 6`  ebuids
  * going to be removed with the last EAPI6 ebuild
* ebuild_description_over_80: checks if `DESCRIPTION` is longer then 80 chars
  * **pkgcheck**: DescriptionCheck
* ebuild_variables_in_homepages: checks if `HOMEPAGE` contains variables
  * **pkgcheck**: ReferenceInMetadataVar
* ebuild_insecure_git_uri_usage: checks for `git://` usage
* ebuild_deprecated_eclasses: lists ebuilds which uses deprecated eclasses
  * **pkgcheck**: DeprecatedEclass
* ebuild_leading_trailing_whitespaces_in_variables: checks for leading / trailing whitespaces in certain variables
* ebuild_multiple_deps_per_line: lists ebuilds which have multiple dependencies in on line
* ebuild_nonexist_dependency: checks for dependencies which doesn't exists
* ebuild_obsolete_virtual: lists virtuals which has effective only on consumer left
* ebuild_missing_eclasses: lists ebuilds which are missing eclasses
  * **pkgcheck**: InheritsCheck
* ebuild_unused_eclasses: lists ebuilds who `inherit` eclasses which are not needed
  * **pkgcheck**: InheritsCheck
* ebuild_missing_eclasses_fatal: lists ebuilds which are missing eclasses and are not inherited indirectly
  * **pkgcheck**: InheritsCheck
* ebuild_homepage_upstream_shutdown: lists ebuilds who have a `HOMEPAGE` to a know shutdown service
* ebuild_homepage_unsync: lists packages who have different `HOMEPAGE` among ebuilds
* ebuild_missing_zip_dependency: lists ebuilds which misses `app-arch/unzip` dependency
* ebuild_src_uri_offline: lists ebuilds who's upstream `SRC_URI` is unavailable and are the ebuild has mirror restricted enabled
* ebuild_src_uri_bad: This check uses wget's spider functionality to check if a ebuild's `SRC_URI` link still works
* ebuild_unused_patches: Extensive check to find unused pachtes. Uses a `whitelist` for false-positives
* ebuild_unused_patches_simple: simple check for unused patches
* ebuild_insecure_pkg_post_config: lists ebuilds who use ch{mod,own} -R in `pkg_config` or `pkg_postinst`
* ebuild_insecure_init_scripts: lists ebuilds who use ch{mod,own} -R in init scripts
* ebuild_homepage_redirections: lists ebuilds with a Homepage which actually redirects to another sites
  * **pkgcheck**: RedirectedUrl
* packages_pkgcheck_scan: runs `pkgcheck scan --net --keywords=-info -q` on packages
  * **pkgcheck**: simply use `pkgcheck`
* metadata_mixed_indentation: Checks metadata files (`metadata.xml`) if it uses mixed tabs and whitespaces
  * **pkgcheck**: PkgMetadataXmlIndentation
* metadata_missing_proxy_maintainer: Checks the `metadata.xml` of proxy maintained packages if it includes actually a non gentoo email address (address of proxy maintainer)
  * **pkgcheck**: MaintainerWithoutProxy
* metadata_duplicate_useflag_description: Lists packages which define use flags locally in `metadata.xml` which already exists as a global use flag.
* metadata_missing_remote_id: Lists packages which has a certain homepage (github, sourceforge) but doesn't set remote-id in `metadata.xml`
  * **pkgcheck**: MissingRemoteId

### Limitations for ebuild_unused_patches:
Following Structures can't be found (yet) and will give a false positive:
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


For a detailed explanation of each check please refer to the descriptions in `repochecks`

# Misc

## qa.sh
This script is used in order to run multiple repositories. It support to run scripts in `diff` mode (git diffs) in order to only run on packages which were changes since last run.

# Tools

## maintainer.py
This python script doesn't take any arguments and just prints every gentoo project and it members.

## dteclasses.sh
Simply prints the inheration tree of a particular eclass.

## whitecheck.sh
Removes obsolete entries from whitelist files (for unused patches)

## eclassinfo.sh
Prints functions which can be used by ebuilds.

# Usage:

Following usage will work for `repochecks` and `repostats`:

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
