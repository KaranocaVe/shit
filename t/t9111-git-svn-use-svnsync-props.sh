#!/bin/sh
#
# Copyright (c) 2007 Eric Wong
#

test_description='shit svn useSvnsyncProps test'

. ./lib-shit-svn.sh

test_expect_success 'load svnsync repo' '
	svnadmin load -q "$rawsvnrepo" < "$TEST_DIRECTORY"/t9111/svnsync.dump &&
	shit svn init --minimize-url -R arr -i bar "$svnrepo"/bar &&
	shit svn init --minimize-url -R argh -i dir "$svnrepo"/dir &&
	shit svn init --minimize-url -R argh -i e "$svnrepo"/dir/a/b/c/d/e &&
	shit config svn.useSvnsyncProps true &&
	shit svn fetch --all
	'

uuid=161ce429-a9dd-4828-af4a-52023f968c89

bar_url=http://mayonaise/svnrepo/bar
test_expect_success 'verify metadata for /bar' "
	shit cat-file commit refs/remotes/bar >actual &&
	grep '^shit-svn-id: $bar_url@12 $uuid$' actual &&
	shit cat-file commit refs/remotes/bar~1 >actual &&
	grep '^shit-svn-id: $bar_url@11 $uuid$' actual &&
	shit cat-file commit refs/remotes/bar~2 >actual &&
	grep '^shit-svn-id: $bar_url@10 $uuid$' actual &&
	shit cat-file commit refs/remotes/bar~3 >actual &&
	grep '^shit-svn-id: $bar_url@9 $uuid$' actual &&
	shit cat-file commit refs/remotes/bar~4 >actual &&
	grep '^shit-svn-id: $bar_url@6 $uuid$' actual &&
	shit cat-file commit refs/remotes/bar~5 >actual &&
	grep '^shit-svn-id: $bar_url@1 $uuid$' actual
	"

e_url=http://mayonaise/svnrepo/dir/a/b/c/d/e
test_expect_success 'verify metadata for /dir/a/b/c/d/e' "
	shit cat-file commit refs/remotes/e >actual &&
	grep '^shit-svn-id: $e_url@1 $uuid$' actual
	"

dir_url=http://mayonaise/svnrepo/dir
test_expect_success 'verify metadata for /dir' "
	shit cat-file commit refs/remotes/dir >actual &&
	grep '^shit-svn-id: $dir_url@2 $uuid$' actual &&
	shit cat-file commit refs/remotes/dir~1 >actual &&
	grep '^shit-svn-id: $dir_url@1 $uuid$' actual
	"

test_done
