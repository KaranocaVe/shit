#!/bin/sh
#
# Copyright (c) 2008 Jan Krüger
#

test_description='shit svn respects rewriteRoot during rebuild'

. ./lib-shit-svn.sh

mkdir import
(cd import
	touch foo
	svn_cmd import -m 'import for shit svn' . "$svnrepo" >/dev/null
)
rm -rf import

test_expect_success 'init, fetch and checkout repository' '
	shit svn init --rewrite-root=http://invalid.invalid/ "$svnrepo" &&
	shit svn fetch &&
	shit checkout -b mybranch remotes/shit-svn
	'

test_expect_success 'remove rev_map' '
	rm "$shit_SVN_DIR"/.rev_map.*
	'

test_expect_success 'rebuild rev_map' '
	shit svn rebase >/dev/null
	'

test_done

