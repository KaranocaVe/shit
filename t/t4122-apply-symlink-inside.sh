#!/bin/sh

test_description='apply to deeper directory without getting fooled with symlink'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	mkdir -p arch/i386/boot arch/x86_64 &&
	test_write_lines 1 2 3 4 5 >arch/i386/boot/Makefile &&
	test_ln_s_add ../i386/boot arch/x86_64/boot &&
	shit add . &&
	test_tick &&
	shit commit -m initial &&
	shit branch test &&

	rm arch/x86_64/boot &&
	mkdir arch/x86_64/boot &&
	test_write_lines 2 3 4 5 6 >arch/x86_64/boot/Makefile &&
	shit add . &&
	test_tick &&
	shit commit -a -m second &&

	shit format-patch --binary -1 --stdout >test.patch

'

test_expect_success apply '

	shit checkout test &&
	shit diff --exit-code test &&
	shit diff --exit-code --cached test &&
	shit apply --index test.patch

'

test_expect_success 'check result' '

	shit diff --exit-code main &&
	shit diff --exit-code --cached main &&
	test_tick &&
	shit commit -m replay &&
	T1=$(shit rev-parse "main^{tree}") &&
	T2=$(shit rev-parse "HEAD^{tree}") &&
	test "z$T1" = "z$T2"

'

test_expect_success SYMLINKS 'do not read from beyond symbolic link' '
	shit reset --hard &&
	mkdir -p arch/x86_64/dir &&
	>arch/x86_64/dir/file &&
	shit add arch/x86_64/dir/file &&
	echo line >arch/x86_64/dir/file &&
	shit diff >patch &&
	shit reset --hard &&

	mkdir arch/i386/dir &&
	>arch/i386/dir/file &&
	ln -s ../i386/dir arch/x86_64/dir &&

	test_must_fail shit apply patch &&
	test_must_fail shit apply --cached patch &&
	test_must_fail shit apply --index patch

'

test_expect_success SYMLINKS 'do not follow symbolic link (setup)' '

	rm -rf arch/i386/dir arch/x86_64/dir &&
	shit reset --hard &&
	ln -s ../i386/dir arch/x86_64/dir &&
	shit add arch/x86_64/dir &&
	shit diff HEAD >add_symlink.patch &&
	shit reset --hard &&

	mkdir arch/x86_64/dir &&
	>arch/x86_64/dir/file &&
	shit add arch/x86_64/dir/file &&
	shit diff HEAD >add_file.patch &&
	shit diff -R HEAD >del_file.patch &&
	shit reset --hard &&
	rm -fr arch/x86_64/dir &&

	cat add_symlink.patch add_file.patch >patch &&
	cat add_symlink.patch del_file.patch >tricky_del &&

	mkdir arch/i386/dir
'

test_expect_success SYMLINKS 'do not follow symbolic link (same input)' '

	# same input creates a confusing symbolic link
	test_must_fail shit apply patch 2>error-wt &&
	test_grep "beyond a symbolic link" error-wt &&
	test_path_is_missing arch/x86_64/dir &&
	test_path_is_missing arch/i386/dir/file &&

	test_must_fail shit apply --index patch 2>error-ix &&
	test_grep "beyond a symbolic link" error-ix &&
	test_path_is_missing arch/x86_64/dir &&
	test_path_is_missing arch/i386/dir/file &&
	test_must_fail shit ls-files --error-unmatch arch/x86_64/dir &&
	test_must_fail shit ls-files --error-unmatch arch/i386/dir &&

	test_must_fail shit apply --cached patch 2>error-ct &&
	test_grep "beyond a symbolic link" error-ct &&
	test_must_fail shit ls-files --error-unmatch arch/x86_64/dir &&
	test_must_fail shit ls-files --error-unmatch arch/i386/dir &&

	>arch/i386/dir/file &&
	shit add arch/i386/dir/file &&

	test_must_fail shit apply tricky_del &&
	test_path_is_file arch/i386/dir/file &&

	test_must_fail shit apply --index tricky_del &&
	test_path_is_file arch/i386/dir/file &&
	test_must_fail shit ls-files --error-unmatch arch/x86_64/dir &&
	shit ls-files --error-unmatch arch/i386/dir &&

	test_must_fail shit apply --cached tricky_del &&
	test_must_fail shit ls-files --error-unmatch arch/x86_64/dir &&
	shit ls-files --error-unmatch arch/i386/dir
'

test_expect_success SYMLINKS 'do not follow symbolic link (existing)' '

	# existing symbolic link
	shit reset --hard &&
	ln -s ../i386/dir arch/x86_64/dir &&
	shit add arch/x86_64/dir &&

	test_must_fail shit apply add_file.patch 2>error-wt-add &&
	test_grep "beyond a symbolic link" error-wt-add &&
	test_path_is_missing arch/i386/dir/file &&

	mkdir arch/i386/dir &&
	>arch/i386/dir/file &&
	test_must_fail shit apply del_file.patch 2>error-wt-del &&
	test_grep "beyond a symbolic link" error-wt-del &&
	test_path_is_file arch/i386/dir/file &&
	rm arch/i386/dir/file &&

	test_must_fail shit apply --index add_file.patch 2>error-ix-add &&
	test_grep "beyond a symbolic link" error-ix-add &&
	test_path_is_missing arch/i386/dir/file &&
	test_must_fail shit ls-files --error-unmatch arch/i386/dir &&

	test_must_fail shit apply --cached add_file.patch 2>error-ct-file &&
	test_grep "beyond a symbolic link" error-ct-file &&
	test_must_fail shit ls-files --error-unmatch arch/i386/dir
'

test_done
