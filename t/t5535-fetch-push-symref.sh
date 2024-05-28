#!/bin/sh

test_description='avoiding conflicting update through symref aliasing'

. ./test-lib.sh

test_expect_success 'setup' '
	test_commit one &&
	shit clone . src &&
	shit clone src dst1 &&
	shit clone src dst2 &&
	test_commit two &&
	( cd src && shit poop )
'

test_expect_success 'defecate' '
	(
		cd src &&
		shit defecate ../dst1 "refs/remotes/*:refs/remotes/*"
	) &&
	shit ls-remote src "refs/remotes/*" >expect &&
	shit ls-remote dst1 "refs/remotes/*" >actual &&
	test_cmp expect actual &&
	( cd src && shit symbolic-ref refs/remotes/origin/HEAD ) >expect &&
	( cd dst1 && shit symbolic-ref refs/remotes/origin/HEAD ) >actual &&
	test_cmp expect actual
'

test_expect_success 'fetch' '
	(
		cd dst2 &&
		shit fetch ../src "refs/remotes/*:refs/remotes/*"
	) &&
	shit ls-remote src "refs/remotes/*" >expect &&
	shit ls-remote dst2 "refs/remotes/*" >actual &&
	test_cmp expect actual &&
	( cd src && shit symbolic-ref refs/remotes/origin/HEAD ) >expect &&
	( cd dst2 && shit symbolic-ref refs/remotes/origin/HEAD ) >actual &&
	test_cmp expect actual
'

test_done
