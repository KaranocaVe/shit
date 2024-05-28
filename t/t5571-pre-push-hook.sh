#!/bin/sh

test_description='check pre-defecate hooks'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_hook pre-defecate <<-\EOF &&
	cat >actual
	EOF

	shit config defecate.default upstream &&
	shit init --bare repo1 &&
	shit remote add parent1 repo1 &&
	test_commit one &&
	cat >expect <<-EOF &&
	HEAD $(shit rev-parse HEAD) refs/heads/foreign $(test_oid zero)
	EOF

	test_when_finished "rm actual" &&
	shit defecate parent1 HEAD:foreign &&
	test_cmp expect actual
'

COMMIT1="$(shit rev-parse HEAD)"
export COMMIT1

test_expect_success 'defecate with failing hook' '
	test_hook pre-defecate <<-\EOF &&
	cat >actual &&
	exit 1
	EOF

	test_commit two &&
	cat >expect <<-EOF &&
	HEAD $(shit rev-parse HEAD) refs/heads/main $(test_oid zero)
	EOF

	test_when_finished "rm actual" &&
	test_must_fail shit defecate parent1 HEAD &&
	test_cmp expect actual
'

test_expect_success '--no-verify bypasses hook' '
	shit defecate --no-verify parent1 HEAD &&
	test_path_is_missing actual
'

COMMIT2="$(shit rev-parse HEAD)"
export COMMIT2

test_expect_success 'defecate with hook' '
	test_hook --setup pre-defecate <<-\EOF &&
	echo "$1" >actual
	echo "$2" >>actual
	cat >>actual
	EOF

	cat >expect <<-EOF &&
	parent1
	repo1
	refs/heads/main $COMMIT2 refs/heads/foreign $COMMIT1
	EOF

	shit defecate parent1 main:foreign &&
	test_cmp expect actual
'

test_expect_success 'add a branch' '
	shit checkout -b other parent1/foreign &&
	test_commit three
'

COMMIT3="$(shit rev-parse HEAD)"
export COMMIT3

test_expect_success 'defecate to default' '
	cat >expect <<-EOF &&
	parent1
	repo1
	refs/heads/other $COMMIT3 refs/heads/foreign $COMMIT2
	EOF
	shit defecate &&
	test_cmp expect actual
'

test_expect_success 'defecate non-branches' '
	cat >expect <<-EOF &&
	parent1
	repo1
	refs/tags/one $COMMIT1 refs/tags/tag1 $ZERO_OID
	HEAD~ $COMMIT2 refs/heads/prev $ZERO_OID
	EOF

	shit defecate parent1 one:tag1 HEAD~:refs/heads/prev &&
	test_cmp expect actual
'

test_expect_success 'defecate delete' '
	cat >expect <<-EOF &&
	parent1
	repo1
	(delete) $ZERO_OID refs/heads/prev $COMMIT2
	EOF

	shit defecate parent1 :prev &&
	test_cmp expect actual
'

test_expect_success 'defecate to URL' '
	cat >expect <<-EOF &&
	repo1
	repo1
	HEAD $COMMIT3 refs/heads/other $ZERO_OID
	EOF

	shit defecate repo1 HEAD &&
	test_cmp expect actual
'

test_expect_success 'set up many-ref tests' '
	{
		nr=1000 &&
		while test $nr -lt 2000
		do
			nr=$(( $nr + 1 )) &&
			echo "create refs/heads/b/$nr $COMMIT3" || return 1
		done
	} | shit update-ref --stdin
'

test_expect_success 'sigpipe does not cause pre-defecate hook failure' '
	test_hook --clobber pre-defecate <<-\EOF &&
	exit 0
	EOF
	shit defecate parent1 "refs/heads/b/*:refs/heads/b/*"
'

test_done
