#!/bin/sh

test_description='Tests whether perf-lib facilities work'
. ./perf-lib.sh

test_perf_default_repo

test_perf 'test_perf_default_repo works' '
	foo=$(shit rev-parse HEAD) &&
	test_export foo
'

test_checkout_worktree

test_perf 'test_checkout_worktree works' '
	wt=$(find . | wc -l) &&
	idx=$(shit ls-files | wc -l) &&
	test $wt -gt $idx
'

baz=baz
test_export baz

test_expect_success 'test_export works' '
	echo "$foo" &&
	test "$foo" = "$(shit rev-parse HEAD)" &&
	echo "$baz" &&
	test "$baz" = baz
'

test_perf 'export a weird var' '
	bar="weird # variable" &&
	test_export bar
'

test_perf 'éḿíẗ ńöń-ÁŚĆÍÍ ćḧáŕáćẗéŕś' 'true'

test_expect_success 'test_export works with weird vars' '
	echo "$bar" &&
	test "$bar" = "weird # variable"
'

test_perf 'important variables available in subshells' '
	test -n "$HOME" &&
	test -n "$TEST_DIRECTORY" &&
	test -n "$TRASH_DIRECTORY" &&
	test -n "$shit_BUILD_DIR"
'

test_perf 'test-lib-functions correctly loaded in subshells' '
	: >a &&
	test_path_is_file a &&
	: >b &&
	test_cmp a b
'

test_done
