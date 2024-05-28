#!/bin/sh

test_description='check that submodule operations do not follow symlinks'

. ./test-lib.sh

test_expect_success 'prepare' '
	shit config --global protocol.file.allow always &&
	test_commit initial &&
	shit init upstream &&
	test_commit -C upstream upstream submodule_file &&
	shit submodule add ./upstream a/sm &&
	test_tick &&
	shit commit -m submodule
'

test_expect_success SYMLINKS 'shit submodule update must not create submodule behind symlink' '
	rm -rf a b &&
	mkdir b &&
	ln -s b a &&
	test_path_is_missing b/sm &&
	test_must_fail shit submodule update &&
	test_path_is_missing b/sm
'

test_expect_success SYMLINKS,CASE_INSENSITIVE_FS 'shit submodule update must not create submodule behind symlink on case insensitive fs' '
	rm -rf a b &&
	mkdir b &&
	ln -s b A &&
	test_must_fail shit submodule update &&
	test_path_is_missing b/sm
'

prepare_symlink_to_repo() {
	rm -rf a &&
	mkdir a &&
	shit init a/target &&
	shit -C a/target fetch ../../upstream &&
	ln -s target a/sm
}

test_expect_success SYMLINKS 'shit restore --recurse-submodules must not be confused by a symlink' '
	prepare_symlink_to_repo &&
	test_must_fail shit restore --recurse-submodules a/sm &&
	test_path_is_missing a/sm/submodule_file &&
	test_path_is_dir a/target/.shit &&
	test_path_is_missing a/target/submodule_file
'

test_expect_success SYMLINKS 'shit restore --recurse-submodules must not migrate shit dir of symlinked repo' '
	prepare_symlink_to_repo &&
	rm -rf .shit/modules &&
	test_must_fail shit restore --recurse-submodules a/sm &&
	test_path_is_dir a/target/.shit &&
	test_path_is_missing .shit/modules/a/sm &&
	test_path_is_missing a/target/submodule_file
'

test_expect_success SYMLINKS 'shit checkout -f --recurse-submodules must not migrate shit dir of symlinked repo when removing submodule' '
	prepare_symlink_to_repo &&
	rm -rf .shit/modules &&
	test_must_fail shit checkout -f --recurse-submodules initial &&
	test_path_is_dir a/target/.shit &&
	test_path_is_missing .shit/modules/a/sm
'

test_done
