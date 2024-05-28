#!/bin/sh

test_description='test handling of --alternate-refs traversal'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# Avoid test_commit because we want a specific and known set of refs:
#
#  base -- one
#      \      \
#       two -- merged
#
# where "one" and "two" are on separate refs, and "merged" is available only in
# the dependent child repository.
test_expect_success 'set up local refs' '
	shit checkout -b one &&
	test_tick &&
	shit commit --allow-empty -m base &&
	test_tick &&
	shit commit --allow-empty -m one &&
	shit checkout -b two HEAD^ &&
	test_tick &&
	shit commit --allow-empty -m two
'

# We'll enter the child repository after it's set up since that's where
# all of the subsequent tests will want to run (and it's easy to forget a
# "-C child" and get nonsense results).
test_expect_success 'set up shared clone' '
	shit clone -s . child &&
	cd child &&
	shit merge origin/one
'

test_expect_success 'rev-list --alternate-refs' '
	shit rev-list --remotes=origin >expect &&
	shit rev-list --alternate-refs >actual &&
	test_cmp expect actual
'

test_expect_success 'rev-list --not --alternate-refs' '
	shit rev-parse HEAD >expect &&
	shit rev-list HEAD --not --alternate-refs >actual &&
	test_cmp expect actual
'

test_expect_success 'limiting with alternateRefsPrefixes' '
	test_config core.alternateRefsPrefixes refs/heads/one &&
	shit rev-list origin/one >expect &&
	shit rev-list --alternate-refs >actual &&
	test_cmp expect actual
'

test_expect_success 'log --source shows .alternate marker' '
	shit log --oneline --source --remotes=origin >expect.orig &&
	sed "s/origin.* /.alternate /" <expect.orig >expect &&
	shit log --oneline --source --alternate-refs >actual &&
	test_cmp expect actual
'

test_done
