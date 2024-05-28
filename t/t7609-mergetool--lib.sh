#!/bin/sh

test_description='shit mergetool

Testing basic merge tools options'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'mergetool --tool=vimdiff creates the expected layout' '
	. "$shit_BUILD_DIR"/mergetools/vimdiff &&
	run_unit_tests
'

test_done
