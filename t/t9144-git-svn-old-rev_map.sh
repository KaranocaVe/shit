#!/bin/sh
#
# Copyright (c) 2009 Eric Wong

test_description='shit svn old rev_map preservd'
. ./lib-shit-svn.sh

test_expect_success 'setup test repository with old layout' '
	mkdir i &&
	(cd i && > a) &&
	svn_cmd import -m- i "$svnrepo" &&
	shit svn init "$svnrepo" &&
	shit svn fetch &&
	test -d .shit/svn/refs/remotes/shit-svn/ &&
	! test -e .shit/svn/shit-svn/ &&
	mv .shit/svn/refs/remotes/shit-svn .shit/svn/ &&
	rm -r .shit/svn/refs
'

test_expect_success 'old layout continues to work' '
	svn_cmd import -m- i "$svnrepo/b" &&
	shit svn rebase &&
	echo a >> b/a &&
	shit add b/a &&
	shit commit -m- -a &&
	shit svn dcommit &&
	! test -d .shit/svn/refs/ &&
	test -e .shit/svn/shit-svn/
'

test_done
