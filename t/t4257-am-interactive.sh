#!/bin/sh

test_description='am --interactive tests'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'set up patches to apply' '
	test_commit unrelated &&
	test_commit no-conflict &&
	test_commit conflict-patch file patch &&
	shit format-patch --stdout -2 >mbox &&

	shit reset --hard unrelated &&
	test_commit conflict-main file main base
'

# Sanity check our setup.
test_expect_success 'applying all patches generates conflict' '
	test_must_fail shit am mbox &&
	echo resolved >file &&
	shit add -u &&
	shit am --resolved
'

test_expect_success 'interactive am can apply a single patch' '
	shit reset --hard base &&
	# apply the first, but not the second
	test_write_lines y n | shit am -i mbox &&

	echo no-conflict >expect &&
	shit log -1 --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'interactive am can resolve conflict' '
	shit reset --hard base &&
	# apply both; the second one will conflict
	test_write_lines y y | test_must_fail shit am -i mbox &&
	echo resolved >file &&
	shit add -u &&
	# interactive "--resolved" will ask us if we want to apply the result
	echo y | shit am -i --resolved &&

	echo conflict-patch >expect &&
	shit log -1 --format=%s >actual &&
	test_cmp expect actual &&

	echo resolved >expect &&
	shit cat-file blob HEAD:file >actual &&
	test_cmp expect actual
'

test_done
