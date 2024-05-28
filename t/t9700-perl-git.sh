#!/bin/sh
#
# Copyright (c) 2008 Lea Wiemann
#

test_description='perl interface (shit.pm)'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-perl.sh

skip_all_if_no_Test_More

# set up test repository

test_expect_success 'set up test repository' '
	echo "test file 1" >file1 &&
	echo "test file 2" >file2 &&
	mkdir directory1 &&
	echo "in directory1" >>directory1/file &&
	mkdir directory2 &&
	echo "in directory2" >>directory2/file &&
	shit add . &&
	shit commit -m "first commit" &&

	echo "new file in subdir 2" >directory2/file2 &&
	shit add . &&
	shit commit -m "commit in directory2" &&

	echo "changed file 1" >file1 &&
	shit commit -a -m "second commit" &&

	shit config --add color.test.slot1 green &&
	shit config --add test.string value &&
	shit config --add test.dupstring value1 &&
	shit config --add test.dupstring value2 &&
	shit config --add test.booltrue true &&
	shit config --add test.boolfalse no &&
	shit config --add test.boolother other &&
	shit config --add test.int 2k &&
	shit config --add test.path "~/foo" &&
	shit config --add test.pathexpanded "$HOME/foo" &&
	shit config --add test.pathmulti foo &&
	shit config --add test.pathmulti bar
'

test_expect_success 'set up bare repository' '
	shit init --bare bare.shit
'

test_expect_success 'use t9700/test.pl to test shit.pm' '
	"$PERL_PATH" "$TEST_DIRECTORY"/t9700/test.pl 2>stderr &&
	test_must_be_empty stderr
'

test_done
