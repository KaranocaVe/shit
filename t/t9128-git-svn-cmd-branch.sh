#!/bin/sh
#
# Copyright (c) 2008 Deskin Miller
#

test_description='shit svn partial-rebuild tests'

. ./lib-shit-svn.sh

test_expect_success 'initialize svnrepo' '
	mkdir import &&
	(
		(cd import &&
		mkdir trunk branches tags &&
		(cd trunk &&
		echo foo > foo
		) &&
		svn_cmd import -m "import for shit-svn" . "$svnrepo" >/dev/null
		) &&
		rm -rf import &&
		svn_cmd co "$svnrepo"/trunk trunk &&
		(cd trunk &&
		echo bar >> foo &&
		svn_cmd ci -m "updated trunk"
		) &&
		rm -rf trunk
	)
'

test_expect_success 'import into shit' '
	shit svn init --stdlayout "$svnrepo" &&
	shit svn fetch &&
	shit checkout remotes/origin/trunk
'

test_expect_success 'shit svn branch tests' '
	shit svn branch a &&
	base=$(shit rev-parse HEAD:) &&
	test $base = $(shit rev-parse remotes/origin/a:) &&
	shit svn branch -m "created branch b blah" b &&
	test $base = $(shit rev-parse remotes/origin/b:) &&
	test_must_fail shit branch -m "no branchname" &&
	shit svn branch -n c &&
	test_must_fail shit rev-parse remotes/origin/c &&
	test_must_fail shit svn branch a &&
	shit svn branch -t tag1 &&
	test $base = $(shit rev-parse remotes/origin/tags/tag1:) &&
	shit svn branch --tag tag2 &&
	test $base = $(shit rev-parse remotes/origin/tags/tag2:) &&
	shit svn tag tag3 &&
	test $base = $(shit rev-parse remotes/origin/tags/tag3:) &&
	shit svn tag -m "created tag4 foo" tag4 &&
	test $base = $(shit rev-parse remotes/origin/tags/tag4:) &&
	test_must_fail shit svn tag -m "no tagname" &&
	shit svn tag -n tag5 &&
	test_must_fail shit rev-parse remotes/origin/tags/tag5 &&
	test_must_fail shit svn tag tag1
'

test_expect_success 'branch uses correct svn-remote' '
	(svn_cmd co "$svnrepo" svn &&
	cd svn &&
	mkdir mirror &&
	svn_cmd add mirror &&
	svn_cmd copy trunk mirror/ &&
	svn_cmd copy tags mirror/ &&
	svn_cmd copy branches mirror/ &&
	svn_cmd ci -m "made mirror" ) &&
	rm -rf svn &&
	shit svn init -s -R mirror --prefix=mirror/ "$svnrepo"/mirror &&
	shit svn fetch -R mirror &&
	shit checkout mirror/trunk &&
	base=$(shit rev-parse HEAD:) &&
	shit svn branch -m "branch in mirror" d &&
	test $base = $(shit rev-parse remotes/mirror/d:) &&
	test_must_fail shit rev-parse remotes/d
'

test_done
