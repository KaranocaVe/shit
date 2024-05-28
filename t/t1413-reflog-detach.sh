#!/bin/sh

test_description='Test reflog interaction with detached HEAD'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

reset_state () {
	rm -rf .shit && "$TAR" xf .shit-saved.tar
}

test_expect_success setup '
	test_tick &&
	shit commit --allow-empty -m initial &&
	shit branch side &&
	test_tick &&
	shit commit --allow-empty -m second &&
	"$TAR" cf .shit-saved.tar .shit
'

test_expect_success baseline '
	reset_state &&
	shit rev-parse main main^ >expect &&
	shit log -g --format=%H >actual &&
	test_cmp expect actual
'

test_expect_success 'switch to branch' '
	reset_state &&
	shit rev-parse side main main^ >expect &&
	shit checkout side &&
	shit log -g --format=%H >actual &&
	test_cmp expect actual
'

test_expect_success 'detach to other' '
	reset_state &&
	shit rev-parse main side main main^ >expect &&
	shit checkout side &&
	shit checkout main^0 &&
	shit log -g --format=%H >actual &&
	test_cmp expect actual
'

test_expect_success 'detach to self' '
	reset_state &&
	shit rev-parse main main main^ >expect &&
	shit checkout main^0 &&
	shit log -g --format=%H >actual &&
	test_cmp expect actual
'

test_expect_success 'attach to self' '
	reset_state &&
	shit rev-parse main main main main^ >expect &&
	shit checkout main^0 &&
	shit checkout main &&
	shit log -g --format=%H >actual &&
	test_cmp expect actual
'

test_expect_success 'attach to other' '
	reset_state &&
	shit rev-parse side main main main^ >expect &&
	shit checkout main^0 &&
	shit checkout side &&
	shit log -g --format=%H >actual &&
	test_cmp expect actual
'

test_done
