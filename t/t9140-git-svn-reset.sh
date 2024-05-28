#!/bin/sh
#
# Copyright (c) 2009 Ben Jackson
#

test_description='shit svn reset'
. ./lib-shit-svn.sh

test_expect_success 'setup test repository' '
	svn_cmd co "$svnrepo" s &&
	(
		cd s &&
		mkdir vis &&
		echo always visible > vis/vis.txt &&
		svn_cmd add vis &&
		svn_cmd commit -m "create visible files" &&
		mkdir hid &&
		echo initially hidden > hid/hid.txt &&
		svn_cmd add hid &&
		svn_cmd commit -m "create initially hidden files" &&
		svn_cmd up &&
		echo mod >> vis/vis.txt &&
		svn_cmd commit -m "modify vis" &&
		svn_cmd up
	)
'

test_expect_success 'clone SVN repository with hidden directory' '
	shit svn init "$svnrepo" g &&
	( cd g && shit svn fetch --ignore-paths="^hid" )
'

test_expect_success 'modify hidden file in SVN repo' '
	( cd s &&
	  echo mod hidden >> hid/hid.txt &&
	  svn_cmd commit -m "modify hid" &&
	  svn_cmd up
	)
'

test_expect_success 'fetch fails on modified hidden file' '
	( cd g &&
	  shit svn find-rev refs/remotes/shit-svn > ../expect &&
	  test_must_fail shit svn fetch 2> ../errors &&
	  shit svn find-rev refs/remotes/shit-svn > ../expect2 ) &&
	grep "not found in commit" errors &&
	test_cmp expect expect2
'

test_expect_success 'reset unwinds back to r1' '
	( cd g &&
	  shit svn reset -r1 &&
	  shit svn find-rev refs/remotes/shit-svn > ../expect2 ) &&
	echo 1 >expect &&
	test_cmp expect expect2
'

test_expect_success 'refetch succeeds not ignoring any files' '
	( cd g &&
	  shit svn fetch &&
	  shit svn rebase &&
	  grep "mod hidden" hid/hid.txt
	)
'

test_done
