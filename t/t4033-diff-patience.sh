#!/bin/sh

test_description='patience diff algorithm'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-diff-alternative.sh

test_expect_success '--ignore-space-at-eol with a single appended character' '
	printf "a\nb\nc\n" >pre &&
	printf "a\nbX\nc\n" >post &&
	test_must_fail shit diff --no-index \
		--patience --ignore-space-at-eol pre post >diff &&
	grep "^+.*X" diff
'

test_diff_frobnitz "patience"

test_diff_unique "patience"

test_done
