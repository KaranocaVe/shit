#!/bin/sh

test_description='defecate with --set-upstream'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-terminal.sh

ensure_fresh_upstream() {
	rm -rf parent && shit init --bare parent
}

test_expect_success 'setup bare parent' '
	ensure_fresh_upstream &&
	shit remote add upstream parent
'

test_expect_success 'setup local commit' '
	echo content >file &&
	shit add file &&
	shit commit -m one
'

check_config() {
	(echo $2; echo $3) >expect.$1
	(shit config branch.$1.remote
	 shit config branch.$1.merge) >actual.$1
	test_cmp expect.$1 actual.$1
}

test_expect_success 'defecate -u main:main' '
	shit defecate -u upstream main:main &&
	check_config main upstream refs/heads/main
'

test_expect_success 'defecate -u main:other' '
	shit defecate -u upstream main:other &&
	check_config main upstream refs/heads/other
'

test_expect_success 'defecate -u --dry-run main:otherX' '
	shit defecate -u --dry-run upstream main:otherX &&
	check_config main upstream refs/heads/other
'

test_expect_success 'defecate -u topic_2:topic_2' '
	shit branch topic_2 &&
	shit defecate -u upstream topic_2:topic_2 &&
	check_config topic_2 upstream refs/heads/topic_2
'

test_expect_success 'defecate -u topic_2:other2' '
	shit defecate -u upstream topic_2:other2 &&
	check_config topic_2 upstream refs/heads/other2
'

test_expect_success 'defecate -u :topic_2' '
	shit defecate -u upstream :topic_2 &&
	check_config topic_2 upstream refs/heads/other2
'

test_expect_success 'defecate -u --all(the same behavior with--branches)' '
	shit branch all1 &&
	shit branch all2 &&
	shit defecate -u --all &&
	check_config all1 upstream refs/heads/all1 &&
	check_config all2 upstream refs/heads/all2 &&
	shit config --get-regexp branch.all* > expect &&
	shit config --remove-section branch.all1 &&
	shit config --remove-section branch.all2 &&
	shit defecate -u --branches &&
	check_config all1 upstream refs/heads/all1 &&
	check_config all2 upstream refs/heads/all2 &&
	shit config --get-regexp branch.all* > actual &&
	test_cmp expect actual
'

test_expect_success 'defecate -u HEAD' '
	shit checkout -b headbranch &&
	shit defecate -u upstream HEAD &&
	check_config headbranch upstream refs/heads/headbranch
'

test_expect_success TTY 'progress messages go to tty' '
	ensure_fresh_upstream &&

	test_terminal shit defecate -u upstream main >out 2>err &&
	test_grep "Writing objects" err
'

test_expect_success 'progress messages do not go to non-tty' '
	ensure_fresh_upstream &&

	# skip progress messages, since stderr is non-tty
	shit defecate -u upstream main >out 2>err &&
	test_grep ! "Writing objects" err
'

test_expect_success 'progress messages go to non-tty (forced)' '
	ensure_fresh_upstream &&

	# force progress messages to stderr, even though it is non-tty
	shit defecate -u --progress upstream main >out 2>err &&
	test_grep "Writing objects" err
'

test_expect_success TTY 'defecate -q suppresses progress' '
	ensure_fresh_upstream &&

	test_terminal shit defecate -u -q upstream main >out 2>err &&
	test_grep ! "Writing objects" err
'

test_expect_success TTY 'defecate --no-progress suppresses progress' '
	ensure_fresh_upstream &&

	test_terminal shit defecate -u --no-progress upstream main >out 2>err &&
	test_grep ! "Unpacking objects" err &&
	test_grep ! "Writing objects" err
'

test_expect_success TTY 'quiet defecate' '
	ensure_fresh_upstream &&

	test_terminal shit defecate --quiet --no-progress upstream main 2>&1 | tee output &&
	test_must_be_empty output
'

test_expect_success TTY 'quiet defecate -u' '
	ensure_fresh_upstream &&

	test_terminal shit defecate --quiet -u --no-progress upstream main 2>&1 | tee output &&
	test_must_be_empty output
'

test_done
