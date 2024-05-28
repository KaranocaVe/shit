#!/bin/sh
#
# Copyright (c) 2009 Eric Wong
#

test_description='shit svn property tests'
. ./lib-shit-svn.sh

test_expect_success 'setup repo with a shit repo inside it' '
	svn_cmd co "$svnrepo" s &&
	(
		cd s &&
		shit init &&
		shit symbolic-ref HEAD &&
		> .shit/a &&
		echo a > a &&
		svn_cmd add .shit a &&
		svn_cmd commit -m "create a nested shit repo" &&
		svn_cmd up &&
		echo hi >> .shit/a &&
		svn_cmd commit -m "modify .shit/a" &&
		svn_cmd up
	)
'

test_expect_success 'clone an SVN repo containing a shit repo' '
	shit svn clone "$svnrepo" g &&
	echo a > expect &&
	test_cmp expect g/a
'

test_expect_success 'SVN-side change outside of .shit' '
	(
		cd s &&
		echo b >> a &&
		svn_cmd commit -m "SVN-side change outside of .shit" &&
		svn_cmd up &&
		svn_cmd log -v | grep -F "SVN-side change outside of .shit"
	)
'

test_expect_success 'update shit svn-cloned repo' '
	(
		cd g &&
		shit svn rebase &&
		echo a > expect &&
		echo b >> expect &&
		test_cmp expect a &&
		rm expect
	)
'

test_expect_success 'SVN-side change inside of .shit' '
	(
		cd s &&
		shit add a &&
		shit commit -m "add a inside an SVN repo" &&
		shit log &&
		svn_cmd add --force .shit &&
		svn_cmd commit -m "SVN-side change inside of .shit" &&
		svn_cmd up &&
		svn_cmd log -v | grep -F "SVN-side change inside of .shit"
	)
'

test_expect_success 'update shit svn-cloned repo' '
	(
		cd g &&
		shit svn rebase &&
		echo a > expect &&
		echo b >> expect &&
		test_cmp expect a &&
		rm expect
	)
'

test_expect_success 'SVN-side change in and out of .shit' '
	(
		cd s &&
		echo c >> a &&
		shit add a &&
		shit commit -m "add a inside an SVN repo" &&
		svn_cmd commit -m "SVN-side change in and out of .shit" &&
		svn_cmd up &&
		svn_cmd log -v | grep -F "SVN-side change in and out of .shit"
	)
'

test_expect_success 'update shit svn-cloned repo again' '
	(
		cd g &&
		shit svn rebase &&
		echo a > expect &&
		echo b >> expect &&
		echo c >> expect &&
		test_cmp expect a &&
		rm expect
	)
'

test_done
