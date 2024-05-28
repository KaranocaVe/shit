#!/bin/sh

test_description='checkout and pathspecs/refspecs ambiguities'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	echo hello >world &&
	echo hello >all &&
	shit add all world &&
	shit commit -m initial &&
	shit branch world
'

test_expect_success 'reference must be a tree' '
	test_must_fail shit checkout $(shit hash-object ./all) --
'

test_expect_success 'branch switching' '
	test "refs/heads/main" = "$(shit symbolic-ref HEAD)" &&
	shit checkout world -- &&
	test "refs/heads/world" = "$(shit symbolic-ref HEAD)"
'

test_expect_success 'checkout world from the index' '
	echo bye > world &&
	shit checkout -- world &&
	shit diff --exit-code --quiet
'

test_expect_success 'non ambiguous call' '
	shit checkout all
'

test_expect_success 'allow the most common case' '
	shit checkout world &&
	test "refs/heads/world" = "$(shit symbolic-ref HEAD)"
'

test_expect_success 'check ambiguity' '
	test_must_fail shit checkout world all
'

test_expect_success 'check ambiguity in subdir' '
	mkdir sub &&
	# not ambiguous because sub/world does not exist
	shit -C sub checkout world ../all &&
	echo hello >sub/world &&
	# ambiguous because sub/world does exist
	test_must_fail shit -C sub checkout world ../all
'

test_expect_success 'disambiguate checking out from a tree-ish' '
	echo bye > world &&
	shit checkout world -- world &&
	shit diff --exit-code --quiet
'

test_expect_success 'accurate error message with more than one ref' '
	test_must_fail shit checkout HEAD main -- 2>actual &&
	test_grep 2 actual &&
	test_grep "one reference expected, 2 given" actual
'

test_done
