#!/bin/sh
# Copyright (c) 2008 Marcus Griep

test_description='shit svn multi-glob branch names'
. ./lib-shit-svn.sh

test_expect_success 'setup svnrepo' '
	mkdir project project/trunk project/branches \
			project/branches/v14.1 project/tags &&
	echo foo > project/trunk/foo &&
	svn_cmd import -m "$test_description" project "$svnrepo/project" &&
	rm -rf project &&
	svn_cmd cp -m "fun" "$svnrepo/project/trunk" \
	                "$svnrepo/project/branches/v14.1/beta" &&
	svn_cmd cp -m "more fun!" "$svnrepo/project/branches/v14.1/beta" \
	                      "$svnrepo/project/branches/v14.1/gold"
	'

test_expect_success 'test clone with multi-glob in branch names' '
	shit svn clone -T trunk -b branches/*/* -t tags \
	              "$svnrepo/project" project &&
	(cd project &&
		shit rev-parse "refs/remotes/origin/v14.1/beta" &&
		shit rev-parse "refs/remotes/origin/v14.1/gold"
	)
	'

test_expect_success 'test dcommit to multi-globbed branch' "
	(cd project &&
	shit reset --hard 'refs/remotes/origin/v14.1/gold' &&
	echo hello >> foo &&
	shit commit -m 'hello' -- foo &&
	shit svn dcommit
	)
	"

test_done
