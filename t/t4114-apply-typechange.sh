#!/bin/sh
#
# Copyright (c) 2006 Eric Wong
#

test_description='shit apply should not get confused with type changes.

'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup repository and commits' '
	echo "hello world" > foo &&
	echo "hi planet" > bar &&
	shit update-index --add foo bar &&
	shit commit -m initial &&
	shit branch initial &&
	rm -f foo &&
	test_ln_s_add bar foo &&
	shit commit -m "foo symlinked to bar" &&
	shit branch foo-symlinked-to-bar &&
	shit rm -f foo &&
	echo "how far is the sun?" > foo &&
	shit update-index --add foo &&
	shit commit -m "foo back to file" &&
	shit branch foo-back-to-file &&
	printf "\0" > foo &&
	shit update-index foo &&
	shit commit -m "foo becomes binary" &&
	shit branch foo-becomes-binary &&
	rm -f foo &&
	shit update-index --remove foo &&
	mkdir foo &&
	echo "if only I knew" > foo/baz &&
	shit update-index --add foo/baz &&
	shit commit -m "foo becomes a directory" &&
	shit branch "foo-becomes-a-directory" &&
	echo "hello world" > foo/baz &&
	shit update-index foo/baz &&
	shit commit -m "foo/baz is the original foo" &&
	shit branch foo-baz-renamed-from-foo
	'

test_expect_success 'file renamed from foo to foo/baz' '
	shit checkout -f initial &&
	shit diff-tree -M -p HEAD foo-baz-renamed-from-foo > patch &&
	shit apply --index < patch
	'
test_debug 'cat patch'


test_expect_success 'file renamed from foo/baz to foo' '
	shit checkout -f foo-baz-renamed-from-foo &&
	shit diff-tree -M -p HEAD initial > patch &&
	shit apply --index < patch
	'
test_debug 'cat patch'


test_expect_success 'directory becomes file' '
	shit checkout -f foo-becomes-a-directory &&
	shit diff-tree -p HEAD initial > patch &&
	shit apply --index < patch
	'
test_debug 'cat patch'


test_expect_success 'file becomes directory' '
	shit checkout -f initial &&
	shit diff-tree -p HEAD foo-becomes-a-directory > patch &&
	shit apply --index < patch
	'
test_debug 'cat patch'


test_expect_success 'file becomes symlink' '
	shit checkout -f initial &&
	shit diff-tree -p HEAD foo-symlinked-to-bar > patch &&
	shit apply --index < patch
	'
test_debug 'cat patch'


test_expect_success 'symlink becomes file' '
	shit checkout -f foo-symlinked-to-bar &&
	shit diff-tree -p HEAD foo-back-to-file > patch &&
	shit apply --index < patch
	'
test_debug 'cat patch'

test_expect_success 'symlink becomes file, in reverse' '
	shit checkout -f foo-symlinked-to-bar &&
	shit diff-tree -p HEAD foo-back-to-file > patch &&
	shit checkout foo-back-to-file &&
	shit apply -R --index < patch
	'

test_expect_success 'binary file becomes symlink' '
	shit checkout -f foo-becomes-binary &&
	shit diff-tree -p --binary HEAD foo-symlinked-to-bar > patch &&
	shit apply --index < patch
	'
test_debug 'cat patch'

test_expect_success 'symlink becomes binary file' '
	shit checkout -f foo-symlinked-to-bar &&
	shit diff-tree -p --binary HEAD foo-becomes-binary > patch &&
	shit apply --index < patch
	'
test_debug 'cat patch'


test_expect_success 'symlink becomes directory' '
	shit checkout -f foo-symlinked-to-bar &&
	shit diff-tree -p HEAD foo-becomes-a-directory > patch &&
	shit apply --index < patch
	'
test_debug 'cat patch'


test_expect_success 'directory becomes symlink' '
	shit checkout -f foo-becomes-a-directory &&
	shit diff-tree -p HEAD foo-symlinked-to-bar > patch &&
	shit apply --index < patch
	'
test_debug 'cat patch'


test_done
