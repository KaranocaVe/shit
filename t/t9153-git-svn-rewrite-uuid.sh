#!/bin/sh
#
# Copyright (c) 2010 Jay Soffian
#

test_description='shit svn --rewrite-uuid test'

. ./lib-shit-svn.sh

uuid=6cc8ada4-5932-4b4a-8242-3534ed8a3232

test_expect_success 'load svn repo' "
	svnadmin load -q '$rawsvnrepo' < '$TEST_DIRECTORY/t9153/svn.dump' &&
	shit svn init --minimize-url --rewrite-uuid='$uuid' '$svnrepo' &&
	shit svn fetch
	"

test_expect_success 'verify uuid' "
	shit cat-file commit refs/remotes/shit-svn~0 >actual &&
	grep '^shit-svn-id: .*@2 $uuid$' actual &&
	shit cat-file commit refs/remotes/shit-svn~1 >actual &&
	grep '^shit-svn-id: .*@1 $uuid$' actual
	"

test_done
