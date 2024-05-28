#!/bin/sh
#
# Copyright (c) 2013 Tobias Schulte
#

test_description='shit svn branch for subproject clones'

. ./lib-shit-svn.sh

test_expect_success 'initialize svnrepo' '
	mkdir import &&
	(
		cd import &&
		mkdir -p trunk/project branches tags &&
		(
			cd trunk/project &&
			echo foo > foo
		) &&
		svn_cmd import -m "import for shit-svn" . "$svnrepo" >/dev/null
	) &&
	rm -rf import &&
	svn_cmd co "$svnrepo"/trunk/project trunk/project &&
	(
		cd trunk/project &&
		echo bar >> foo &&
		svn_cmd ci -m "updated trunk"
	) &&
	rm -rf trunk
'

test_expect_success 'import into shit' '
	shit svn init --trunk=trunk/project --branches=branches/*/project \
		--tags=tags/*/project "$svnrepo" &&
	shit svn fetch &&
	shit checkout remotes/origin/trunk
'

test_expect_success 'shit svn branch tests' '
	test_must_fail shit svn branch a &&
	shit svn branch --parents a &&
	test_must_fail shit svn branch -t tag1 &&
	shit svn branch --parents -t tag1 &&
	test_must_fail shit svn branch --tag tag2 &&
	shit svn branch --parents --tag tag2 &&
	test_must_fail shit svn tag tag3 &&
	shit svn tag --parents tag3
'

test_done
