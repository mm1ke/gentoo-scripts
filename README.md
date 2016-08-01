A collection of various gentoo related scripts !

patchtest.sh:

This scripts tries to find unused patches from the gentoo portage tree.
In order to use this scripts you must set the PORTTREE variable to the
correct portage directory (which is usually /usr/portage)

Usage:

./patchtest.sh
	searches in every catergory (takes some time)
./patchtest.sh $catergory
	only searches in the given catergory

Limitations:

While it's quite usefull to quickly find unused patches, it still produces
false-positives. Common reasons are:

* custom variables in patchnames
	epatch foo-bar-${MY_P}.patch
* executing patches in loops
	for i in name1 name2 name3; do
		epatch foo-bar-$i.patch
	done
* executing patches where names are in brace's
	epatch foo-bar-{var1,var2,var3}.patch
