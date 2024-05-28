#!/bin/sh
#
# Copyright (c) 2006 Carl D. Worth
#

test_description='shit ls-files test for --error-unmatch option

This test runs shit ls-files --error-unmatch to ensure it correctly
returns an error when a non-existent path is provided on the command
line.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	touch foo bar &&
	shit update-index --add foo bar &&
	shit commit -m "add foo bar"
'

test_expect_success 'shit ls-files --error-unmatch should fail with unmatched path.' '
	test_must_fail shit ls-files --error-unmatch foo bar-does-not-match
'

test_expect_success 'shit ls-files --error-unmatch should succeed with matched paths.' '
	shit ls-files --error-unmatch foo bar
'

test_done
