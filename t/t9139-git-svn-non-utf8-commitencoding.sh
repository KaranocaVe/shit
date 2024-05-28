#!/bin/sh
#
# Copyright (c) 2009 Eric Wong

test_description='shit svn refuses to dcommit non-UTF8 messages'

TEST_FAILS_SANITIZE_LEAK=true
. ./lib-shit-svn.sh

# ISO-2022-JP can pass for valid UTF-8, so skipping that in this test

for H in ISO8859-1 eucJP
do
	test_expect_success "$H setup" '
		mkdir $H &&
		svn_cmd import -m "$H test" $H "$svnrepo"/$H &&
		shit svn clone "$svnrepo"/$H $H
	'
done

for H in ISO8859-1 eucJP
do
	test_expect_success "$H commit on shit side" '
	(
		cd $H &&
		shit config i18n.commitencoding $H &&
		shit checkout -b t refs/remotes/shit-svn &&
		echo $H >F &&
		shit add F &&
		shit commit -a -F "$TEST_DIRECTORY"/t3900/$H.txt &&
		E=$(shit cat-file commit HEAD | sed -ne "s/^encoding //p") &&
		test "z$E" = "z$H"
	)
	'
done

for H in ISO8859-1 eucJP
do
	test_expect_success "$H dcommit to svn" '
	(
		cd $H &&
		shit config --unset i18n.commitencoding &&
		test_must_fail shit svn dcommit
	)
	'
done

test_done
