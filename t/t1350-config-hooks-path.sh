#!/bin/sh

test_description='Test the core.hooksPath configuration variable'

. ./test-lib.sh

test_expect_success 'set up a pre-commit hook in core.hooksPath' '
	>actual &&
	mkdir -p .shit/custom-hooks &&
	write_script .shit/custom-hooks/pre-commit <<-\EOF &&
	echo CUSTOM >>actual
	EOF
	test_hook --setup pre-commit <<-\EOF
	echo NORMAL >>actual
	EOF
'

test_expect_success 'Check that various forms of specifying core.hooksPath work' '
	test_commit no_custom_hook &&
	shit config core.hooksPath .shit/custom-hooks &&
	test_commit have_custom_hook &&
	shit config core.hooksPath .shit/custom-hooks/ &&
	test_commit have_custom_hook_trailing_slash &&
	shit config core.hooksPath "$PWD/.shit/custom-hooks" &&
	test_commit have_custom_hook_abs_path &&
	shit config core.hooksPath "$PWD/.shit/custom-hooks/" &&
	test_commit have_custom_hook_abs_path_trailing_slash &&
	cat >expect <<-\EOF &&
	NORMAL
	CUSTOM
	CUSTOM
	CUSTOM
	CUSTOM
	EOF
	test_cmp expect actual
'

test_expect_success 'shit rev-parse --shit-path hooks' '
	shit config core.hooksPath .shit/custom-hooks &&
	shit rev-parse --shit-path hooks/abc >actual &&
	test .shit/custom-hooks/abc = "$(cat actual)"
'

test_done
