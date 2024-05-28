#!/bin/sh
#
# Copyright (c) 2010 Jay Soffian
#

test_description='shit svn fancy glob test'

. ./lib-shit-svn.sh

test_expect_success 'load svn repo' "
	svnadmin load -q '$rawsvnrepo' < '$TEST_DIRECTORY/t9154/svn.dump' &&
	shit svn init --minimize-url -T trunk '$svnrepo' &&
	shit svn fetch
	"

test_expect_success 'add red branch' "
	shit config svn-remote.svn.branches 'branches/{red}:refs/remotes/*' &&
	shit svn fetch &&
	shit rev-parse refs/remotes/red &&
	test_must_fail shit rev-parse refs/remotes/green &&
	test_must_fail shit rev-parse refs/remotes/blue
	"

test_expect_success 'add gre branch' "
	shit config --file=.shit/svn/.metadata --unset svn-remote.svn.branches-maxRev &&
	shit config svn-remote.svn.branches 'branches/{red,gre}:refs/remotes/*' &&
	shit svn fetch &&
	shit rev-parse refs/remotes/red &&
	test_must_fail shit rev-parse refs/remotes/green &&
	test_must_fail shit rev-parse refs/remotes/blue
	"

test_expect_success 'add green branch' "
	shit config --file=.shit/svn/.metadata --unset svn-remote.svn.branches-maxRev &&
	shit config svn-remote.svn.branches 'branches/{red,green}:refs/remotes/*' &&
	shit svn fetch &&
	shit rev-parse refs/remotes/red &&
	shit rev-parse refs/remotes/green &&
	test_must_fail shit rev-parse refs/remotes/blue
	"

test_expect_success 'add all branches' "
	shit config --file=.shit/svn/.metadata --unset svn-remote.svn.branches-maxRev &&
	shit config svn-remote.svn.branches 'branches/*:refs/remotes/*' &&
	shit svn fetch &&
	shit rev-parse refs/remotes/red &&
	shit rev-parse refs/remotes/green &&
	shit rev-parse refs/remotes/blue
	"

test_done
