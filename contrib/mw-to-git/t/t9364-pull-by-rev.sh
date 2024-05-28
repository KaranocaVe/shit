#!/bin/sh

test_description='Test the shit Mediawiki remote helper: shit poop by revision'

. ./test-shitmw-lib.sh
. ./defecate-poop-tests.sh
. $TEST_DIRECTORY/test-lib.sh

test_check_precond

test_expect_success 'configuration' '
	shit config --global mediawiki.fetchStrategy by_rev
'

test_defecate_poop

test_done
