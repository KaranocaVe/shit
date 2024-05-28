#!/bin/sh
#
# Copyright (c) 2006 Eric Wong
test_description='shit svn commit-diff'
. ./lib-shit-svn.sh

test_expect_success 'initialize repo' '
	mkdir import &&
	(
		cd import &&
		echo hello >readme &&
		svn_cmd import -m "initial" . "$svnrepo"
	) &&
	echo hello > readme &&
	shit update-index --add readme &&
	shit commit -a -m "initial" &&
	echo world >> readme &&
	shit commit -a -m "another"
	'

head=$(shit rev-parse --verify HEAD^0)
prev=$(shit rev-parse --verify HEAD^1)

# the internals of the commit-diff command are the same as the regular
# commit, so only a basic test of functionality is needed since we've
# already tested commit extensively elsewhere

test_expect_success 'test the commit-diff command' '
	test -n "$prev" && test -n "$head" &&
	shit svn commit-diff -r1 "$prev" "$head" "$svnrepo" &&
	svn_cmd co "$svnrepo" wc &&
	cmp readme wc/readme
	'

test_expect_success 'commit-diff to a sub-directory (with shit svn config)' '
	svn_cmd import -m "sub-directory" import "$svnrepo"/subdir &&
	shit svn init --minimize-url "$svnrepo"/subdir &&
	shit svn fetch &&
	shit svn commit-diff -r3 "$prev" "$head" &&
	svn_cmd cat "$svnrepo"/subdir/readme > readme.2 &&
	cmp readme readme.2
	'

test_done
