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
		svn_cmd import -m "import for shit-svn" . "$svnrepo" >/dev/null &&
		svn_cmd copy "$svnrepo"/trunk "$svnrepo"/branches/a \
			-m "created branch a"
		) &&
		rm -rf import &&
		svn_cmd co "$svnrepo"/trunk trunk &&
		(cd trunk &&
		echo bar >> foo &&
		svn_cmd ci -m "updated trunk"
		) &&
		svn_cmd co "$svnrepo"/branches/a a &&
		(cd a &&
		echo baz >> a &&
		svn_cmd add a &&
		svn_cmd ci -m "updated a"
		) &&
		shit svn init --stdlayout "$svnrepo"
	)
'

test_expect_success 'import an early SVN revision into shit' '
	shit svn fetch -r1:2
'

test_expect_success 'make full shit mirror of SVN' '
	mkdir mirror &&
	(
		(cd mirror &&
		shit init &&
		shit svn init --stdlayout "$svnrepo" &&
		shit svn fetch
		)
	)
'

test_expect_success 'fetch from shit mirror and partial-rebuild' '
	shit config --add remote.origin.url "file://$PWD/mirror/.shit" &&
	shit config --add remote.origin.fetch refs/remotes/*:refs/remotes/* &&
	shit fetch origin &&
	shit svn fetch
'

test_done
