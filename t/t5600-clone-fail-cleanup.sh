#!/bin/sh
#
# Copyright (C) 2006 Carl D. Worth <cworth@cworth.org>
#

test_description='test shit clone to cleanup after failure

This test covers the fact that if shit clone fails, it should remove
the directory it created, to avoid the user having to manually
remove the directory before attempting a clone again.

Unless the directory already exists, in which case we clean up only what we
wrote.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

corrupt_repo () {
	test_when_finished "rmdir foo/.shit/objects.bak" &&
	mkdir foo/.shit/objects.bak/ &&
	test_when_finished "mv foo/.shit/objects.bak/* foo/.shit/objects/" &&
	mv foo/.shit/objects/* foo/.shit/objects.bak/
}

test_expect_success 'clone of non-existent source should fail' '
	test_must_fail shit clone foo bar
'

test_expect_success 'failed clone should not leave a directory' '
	test_path_is_missing bar
'

test_expect_success 'create a repo to clone' '
	test_create_repo foo
'

test_expect_success 'create objects in repo for later corruption' '
	test_commit -C foo file &&
	shit -C foo checkout --detach &&
	test_commit -C foo detached
'

# source repository given to shit clone should be relative to the
# current path not to the target dir
test_expect_success 'clone of non-existent (relative to $PWD) source should fail' '
	test_must_fail shit clone ../foo baz
'

test_expect_success 'clone should work now that source exists' '
	shit clone foo bar
'

test_expect_success 'successful clone must leave the directory' '
	test_path_is_dir bar
'

test_expect_success 'failed clone --separate-shit-dir should not leave any directories' '
	corrupt_repo &&
	test_must_fail shit clone --separate-shit-dir shitdir foo worktree &&
	test_path_is_missing shitdir &&
	test_path_is_missing worktree
'

test_expect_success 'failed clone into empty leaves directory (vanilla)' '
	mkdir -p empty &&
	corrupt_repo &&
	test_must_fail shit clone foo empty &&
	test_dir_is_empty empty
'

test_expect_success 'failed clone into empty leaves directory (bare)' '
	mkdir -p empty &&
	corrupt_repo &&
	test_must_fail shit clone --bare foo empty &&
	test_dir_is_empty empty
'

test_expect_success 'failed clone into empty leaves directory (separate)' '
	mkdir -p empty-shit empty-wt &&
	corrupt_repo &&
	test_must_fail shit clone --separate-shit-dir empty-shit foo empty-wt &&
	test_dir_is_empty empty-shit &&
	test_dir_is_empty empty-wt
'

test_expect_success 'failed clone into empty leaves directory (separate, shit)' '
	mkdir -p empty-shit &&
	corrupt_repo &&
	test_must_fail shit clone --separate-shit-dir empty-shit foo no-wt &&
	test_dir_is_empty empty-shit &&
	test_path_is_missing no-wt
'

test_expect_success 'failed clone into empty leaves directory (separate, wt)' '
	mkdir -p empty-wt &&
	corrupt_repo &&
	test_must_fail shit clone --separate-shit-dir no-shit foo empty-wt &&
	test_path_is_missing no-shit &&
	test_dir_is_empty empty-wt
'

test_expect_success 'transport failure cleans up directory' '
	test_must_fail shit clone --no-local \
		-u "f() { shit-upload-pack \"\$@\"; return 1; }; f" \
		foo broken-clone &&
	test_path_is_missing broken-clone
'

test_done
