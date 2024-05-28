#!/bin/sh

test_description='shit status rename detection options'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	echo 1 >original &&
	shit add . &&
	shit commit -m"Adding original file." &&
	mv original renamed &&
	echo 2 >> renamed &&
	shit add . &&
	cat >.shitignore <<-\EOF
	.shitignore
	expect*
	actual*
	EOF
'

test_expect_success 'status no-options' '
	shit status >actual &&
	test_grep "renamed:" actual
'

test_expect_success 'status --no-renames' '
	shit status --no-renames >actual &&
	test_grep "deleted:" actual &&
	test_grep "new file:" actual
'

test_expect_success 'status.renames inherits from diff.renames false' '
	shit -c diff.renames=false status >actual &&
	test_grep "deleted:" actual &&
	test_grep "new file:" actual
'

test_expect_success 'status.renames inherits from diff.renames true' '
	shit -c diff.renames=true status >actual &&
	test_grep "renamed:" actual
'

test_expect_success 'status.renames overrides diff.renames false' '
	shit -c diff.renames=true -c status.renames=false status >actual &&
	test_grep "deleted:" actual &&
	test_grep "new file:" actual
'

test_expect_success 'status.renames overrides from diff.renames true' '
	shit -c diff.renames=false -c status.renames=true status >actual &&
	test_grep "renamed:" actual
'

test_expect_success 'status status.renames=false' '
	shit -c status.renames=false status >actual &&
	test_grep "deleted:" actual &&
	test_grep "new file:" actual
'

test_expect_success 'status status.renames=true' '
	shit -c status.renames=true status >actual &&
	test_grep "renamed:" actual
'

test_expect_success 'commit honors status.renames=false' '
	shit -c status.renames=false commit --dry-run >actual &&
	test_grep "deleted:" actual &&
	test_grep "new file:" actual
'

test_expect_success 'commit honors status.renames=true' '
	shit -c status.renames=true commit --dry-run >actual &&
	test_grep "renamed:" actual
'

test_expect_success 'status config overridden' '
	shit -c status.renames=true status --no-renames >actual &&
	test_grep "deleted:" actual &&
	test_grep "new file:" actual
'

test_expect_success 'status score=100%' '
	shit status -M=100% >actual &&
	test_grep "deleted:" actual &&
	test_grep "new file:" actual &&

	shit status --find-renames=100% >actual &&
	test_grep "deleted:" actual &&
	test_grep "new file:" actual
'

test_expect_success 'status score=01%' '
	shit status -M=01% >actual &&
	test_grep "renamed:" actual &&

	shit status --find-renames=01% >actual &&
	test_grep "renamed:" actual
'

test_expect_success 'copies not overridden by find-renames' '
	cp renamed copy &&
	shit add copy &&

	shit -c status.renames=copies status -M=01% >actual &&
	test_grep "copied:" actual &&
	test_grep "renamed:" actual &&

	shit -c status.renames=copies status --find-renames=01% >actual &&
	test_grep "copied:" actual &&
	test_grep "renamed:" actual
'

test_done
