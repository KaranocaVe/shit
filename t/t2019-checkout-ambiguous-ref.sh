#!/bin/sh

test_description='checkout handling of ambiguous (branch/tag) refs'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup ambiguous refs' '
	test_commit branch file &&
	shit branch ambiguity &&
	shit branch vagueness &&
	test_commit tag file &&
	shit tag ambiguity &&
	shit tag vagueness HEAD:file &&
	test_commit other file
'

test_expect_success 'checkout ambiguous ref succeeds' '
	shit checkout ambiguity 2>stderr
'

test_expect_success 'checkout produces ambiguity warning' '
	grep "warning.*ambiguous" stderr
'

test_expect_success 'checkout chooses branch over tag' '
	echo refs/heads/ambiguity >expect &&
	shit symbolic-ref HEAD >actual &&
	test_cmp expect actual &&
	echo branch >expect &&
	test_cmp expect file
'

test_expect_success 'checkout reports switch to branch' '
	test_grep "Switched to branch" stderr &&
	test_grep ! "^HEAD is now at" stderr
'

test_expect_success 'checkout vague ref succeeds' '
	shit checkout vagueness 2>stderr &&
	test_set_prereq VAGUENESS_SUCCESS
'

test_expect_success VAGUENESS_SUCCESS 'checkout produces ambiguity warning' '
	grep "warning.*ambiguous" stderr
'

test_expect_success VAGUENESS_SUCCESS 'checkout chooses branch over tag' '
	echo refs/heads/vagueness >expect &&
	shit symbolic-ref HEAD >actual &&
	test_cmp expect actual &&
	echo branch >expect &&
	test_cmp expect file
'

test_expect_success VAGUENESS_SUCCESS 'checkout reports switch to branch' '
	test_grep "Switched to branch" stderr &&
	test_grep ! "^HEAD is now at" stderr
'

test_done
