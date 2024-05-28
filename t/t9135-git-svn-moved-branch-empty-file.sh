#!/bin/sh

test_description='test moved svn branch with missing empty files'

. ./lib-shit-svn.sh
test_expect_success 'load svn dumpfile'  '
	svnadmin load "$rawsvnrepo" < "${TEST_DIRECTORY}/t9135/svn.dump"
	'

test_expect_success 'clone using shit svn' 'shit svn clone -s "$svnrepo" x'

test_expect_success 'test that b1 exists and is empty' '
	(
		cd x &&
		shit reset --hard origin/branch-c &&
		test_must_be_empty b1
	)
	'

test_done
