#!/bin/sh

test_description='shit status and symlinks'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	echo .shitignore >.shitignore &&
	echo actual >>.shitignore &&
	echo expect >>.shitignore &&
	mkdir dir &&
	echo x >dir/file1 &&
	echo y >dir/file2 &&
	shit add dir &&
	shit commit -m initial &&
	shit tag initial
'

test_expect_success SYMLINKS 'symlink to a directory' '
	test_when_finished "rm symlink" &&
	ln -s dir symlink &&
	echo "?? symlink" >expect &&
	shit status --porcelain >actual &&
	test_cmp expect actual
'

test_expect_success SYMLINKS 'symlink replacing a directory' '
	test_when_finished "rm -rf copy && shit reset --hard initial" &&
	mkdir copy &&
	cp dir/file1 copy/file1 &&
	echo "changed in copy" >copy/file2 &&
	shit add copy &&
	shit commit -m second &&
	rm -rf copy &&
	ln -s dir copy &&
	echo " D copy/file1" >expect &&
	echo " D copy/file2" >>expect &&
	echo "?? copy" >>expect &&
	shit status --porcelain >actual &&
	test_cmp expect actual
'

test_done
