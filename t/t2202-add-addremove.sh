#!/bin/sh

test_description='shit add --all'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	(
		echo .shitignore &&
		echo will-remove
	) >expect &&
	(
		echo actual &&
		echo expect &&
		echo ignored
	) >.shitignore &&
	shit --literal-pathspecs add --all &&
	>will-remove &&
	shit add --all &&
	test_tick &&
	shit commit -m initial &&
	shit ls-files >actual &&
	test_cmp expect actual
'

test_expect_success 'shit add --all' '
	(
		echo .shitignore &&
		echo not-ignored &&
		echo "M	.shitignore" &&
		echo "A	not-ignored" &&
		echo "D	will-remove"
	) >expect &&
	>ignored &&
	>not-ignored &&
	echo modification >>.shitignore &&
	rm -f will-remove &&
	shit add --all &&
	shit update-index --refresh &&
	shit ls-files >actual &&
	shit diff-index --name-status --cached HEAD >>actual &&
	test_cmp expect actual
'

test_expect_success 'Just "shit add" is a no-op' '
	shit reset --hard &&
	echo >will-remove &&
	>will-not-be-added &&
	shit add &&
	shit diff-index --name-status --cached HEAD >actual &&
	test_must_be_empty actual
'

test_done
