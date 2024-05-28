#!/bin/sh
#
# Copyright (c) 2010 Steven Walter
#

test_description='shit svn mergeinfo propagation'

. ./lib-shit-svn.sh

test_expect_success 'initialize source svn repo' '
	svn_cmd mkdir -m x "$svnrepo"/trunk &&
	svn_cmd co "$svnrepo"/trunk "$SVN_TREE" &&
	(
		cd "$SVN_TREE" &&
		touch foo &&
		svn_cmd add foo &&
		svn_cmd commit -m "initial commit"
	) &&
	rm -rf "$SVN_TREE"
'

test_expect_success 'clone svn repo' '
	shit svn init "$svnrepo"/trunk &&
	shit svn fetch
'

test_expect_success 'change svn:mergeinfo' '
	touch bar &&
	shit add bar &&
	shit commit -m "bar" &&
	shit svn dcommit --mergeinfo="/branches/foo:1-10"
'

test_expect_success 'verify svn:mergeinfo' '
	mergeinfo=$(svn_cmd propget svn:mergeinfo "$svnrepo"/trunk) &&
	test "$mergeinfo" = "/branches/foo:1-10"
'

test_expect_success 'change svn:mergeinfo multiline' '
	touch baz &&
	shit add baz &&
	shit commit -m "baz" &&
	shit svn dcommit --mergeinfo="/branches/bar:1-10 /branches/other:3-5,8,10-11"
'

test_expect_success 'verify svn:mergeinfo multiline' '
	mergeinfo=$(svn_cmd propget svn:mergeinfo "$svnrepo"/trunk) &&
	test "$mergeinfo" = "/branches/bar:1-10
/branches/other:3-5,8,10-11"
'

test_done
