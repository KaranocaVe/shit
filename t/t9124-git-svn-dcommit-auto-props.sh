#!/bin/sh
#
# Copyright (c) 2008 Brad King

test_description='shit svn dcommit honors auto-props'

. ./lib-shit-svn.sh

generate_auto_props() {
cat << EOF
[miscellany]
enable-auto-props=$1
[auto-props]
*.sh  = svn:mime-type=application/x-shellscript; svn:eol-style=LF
*.txt = svn:mime-type=text/plain; svn:eol-style = native
EOF
}

test_expect_success 'initialize shit svn' '
	mkdir import &&
	(
		cd import &&
		echo foo >foo &&
		svn_cmd import -m "import for shit svn" . "$svnrepo"
	) &&
	rm -rf import &&
	shit svn init "$svnrepo" &&
	shit svn fetch
'

test_expect_success 'enable auto-props config' '
	mkdir user &&
	generate_auto_props yes >user/config
'

test_expect_success 'add files matching auto-props' '
	write_script exec1.sh </dev/null &&
	echo "hello" >hello.txt &&
	echo bar >bar &&
	shit add exec1.sh hello.txt bar &&
	shit commit -m "files for enabled auto-props" &&
	shit svn dcommit --config-dir=user
'

test_expect_success 'disable auto-props config' '
	generate_auto_props no >user/config
'

test_expect_success 'add files matching disabled auto-props' '
	write_script exec2.sh </dev/null &&
	echo "world" >world.txt &&
	echo zot >zot &&
	shit add exec2.sh world.txt zot &&
	shit commit -m "files for disabled auto-props" &&
	shit svn dcommit --config-dir=user
'

test_expect_success 'check resulting svn repository' '
(
	mkdir work &&
	cd work &&
	svn_cmd co "$svnrepo" &&
	cd svnrepo &&

	# Check properties from first commit.
	if test_have_prereq POSIXPERM
	then
		test "x$(svn_cmd propget svn:executable exec1.sh)" = "x*"
	fi &&
	test "x$(svn_cmd propget svn:mime-type exec1.sh)" = \
	     "xapplication/x-shellscript" &&
	test "x$(svn_cmd propget svn:mime-type hello.txt)" = "xtext/plain" &&
	test "x$(svn_cmd propget svn:eol-style hello.txt)" = "xnative" &&
	test "x$(svn_cmd propget svn:mime-type bar)" = "x" &&

	# Check properties from second commit.
	if test_have_prereq POSIXPERM
	then
		test "x$(svn_cmd propget svn:executable exec2.sh)" = "x*"
	fi &&
	test "x$(svn_cmd propget svn:mime-type exec2.sh)" = "x" &&
	test "x$(svn_cmd propget svn:mime-type world.txt)" = "x" &&
	test "x$(svn_cmd propget svn:eol-style world.txt)" = "x" &&
	test "x$(svn_cmd propget svn:mime-type zot)" = "x"
)
'

test_expect_success 'check renamed file' '
	test -d user &&
	generate_auto_props yes > user/config &&
	shit mv foo foo.sh &&
	shit commit -m "foo => foo.sh" &&
	shit svn dcommit --config-dir=user &&
	(
		cd work/svnrepo &&
		svn_cmd up &&
		test ! -e foo &&
		test -e foo.sh &&
		test "x$(svn_cmd propget svn:mime-type foo.sh)" = \
		     "xapplication/x-shellscript" &&
		test "x$(svn_cmd propget svn:eol-style foo.sh)" = "xLF"
	)
'

test_done
