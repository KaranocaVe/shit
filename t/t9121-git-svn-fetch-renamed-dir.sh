#!/bin/sh
#
# Copyright (c) 2008 Santhosh Kumar Mani


test_description='shit svn can fetch renamed directories'

. ./lib-shit-svn.sh

test_expect_success 'load repository with renamed directory' '
	svnadmin load -q "$rawsvnrepo" < "$TEST_DIRECTORY"/t9121/renamed-dir.dump
	'

test_expect_success 'init and fetch repository' '
	shit svn init "$svnrepo/newname" &&
	shit svn fetch
	'

test_done

