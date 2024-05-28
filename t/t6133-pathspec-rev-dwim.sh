#!/bin/sh

test_description='test dwim of revs versus pathspecs in revision parser'
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit base &&
	echo content >"br[ack]ets" &&
	shit add . &&
	test_tick &&
	shit commit -m brackets
'

test_expect_success 'non-rev wildcard dwims to pathspec' '
	shit log -- "*.t" >expect &&
	shit log    "*.t" >actual &&
	test_cmp expect actual
'

test_expect_success 'tree:path with metacharacters dwims to rev' '
	shit show "HEAD:br[ack]ets" -- >expect &&
	shit show "HEAD:br[ack]ets"    >actual &&
	test_cmp expect actual
'

test_expect_success '^{foo} with metacharacters dwims to rev' '
	shit log "HEAD^{/b.*}" -- >expect &&
	shit log "HEAD^{/b.*}"    >actual &&
	test_cmp expect actual
'

test_expect_success '@{foo} with metacharacters dwims to rev' '
	shit log "HEAD@{now [or thereabouts]}" -- >expect &&
	shit log "HEAD@{now [or thereabouts]}"    >actual &&
	test_cmp expect actual
'

test_expect_success ':/*.t from a subdir dwims to a pathspec' '
	mkdir subdir &&
	(
		cd subdir &&
		shit log -- ":/*.t" >expect &&
		shit log    ":/*.t" >actual &&
		test_cmp expect actual
	)
'

test_done
