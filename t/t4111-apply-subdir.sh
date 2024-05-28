#!/bin/sh

test_description='patching from inconvenient places'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	cat >patch <<-\EOF &&
	diff file.orig file
	--- a/file.orig
	+++ b/file
	@@ -1 +1,2 @@
	 1
	+2
	EOF
	patch="$(pwd)/patch" &&

	echo 1 >preimage &&
	printf "%s\n" 1 2 >postimage &&
	echo 3 >other &&

	test_tick &&
	shit commit --allow-empty -m basis
'

test_expect_success 'setup: subdir' '
	reset_subdir() {
		shit reset &&
		mkdir -p sub/dir/b &&
		mkdir -p objects &&
		cp "$1" file &&
		cp "$1" objects/file &&
		cp "$1" sub/dir/file &&
		cp "$1" sub/dir/b/file &&
		shit add file sub/dir/file sub/dir/b/file objects/file &&
		cp "$2" file &&
		cp "$2" sub/dir/file &&
		cp "$2" sub/dir/b/file &&
		cp "$2" objects/file &&
		test_might_fail shit update-index --refresh -q
	}
'

test_expect_success 'apply from subdir of toplevel' '
	cp postimage expected &&
	reset_subdir other preimage &&
	(
		cd sub/dir &&
		shit apply "$patch"
	) &&
	test_cmp expected sub/dir/file
'

test_expect_success 'apply --cached from subdir of toplevel' '
	cp postimage expected &&
	cp other expected.working &&
	reset_subdir preimage other &&
	(
		cd sub/dir &&
		shit apply --cached "$patch"
	) &&
	shit show :sub/dir/file >actual &&
	test_cmp expected actual &&
	test_cmp expected.working sub/dir/file
'

test_expect_success 'apply --index from subdir of toplevel' '
	cp postimage expected &&
	reset_subdir preimage other &&
	(
		cd sub/dir &&
		test_must_fail shit apply --index "$patch"
	) &&
	reset_subdir other preimage &&
	(
		cd sub/dir &&
		test_must_fail shit apply --index "$patch"
	) &&
	reset_subdir preimage preimage &&
	(
		cd sub/dir &&
		shit apply --index "$patch"
	) &&
	shit show :sub/dir/file >actual &&
	test_cmp expected actual &&
	test_cmp expected sub/dir/file
'

test_expect_success 'apply half-broken patch from subdir of toplevel' '
	(
		cd sub/dir &&
		test_must_fail shit apply <<-EOF
		--- sub/dir/file
		+++ sub/dir/file
		@@ -1,0 +1,0 @@
		--- file_in_root
		+++ file_in_root
		@@ -1,0 +1,0 @@
		EOF
	)
'

test_expect_success 'apply from .shit dir' '
	cp postimage expected &&
	cp preimage .shit/file &&
	cp preimage .shit/objects/file &&
	(
		cd .shit &&
		shit apply "$patch"
	) &&
	test_cmp expected .shit/file
'

test_expect_success 'apply from subdir of .shit dir' '
	cp postimage expected &&
	cp preimage .shit/file &&
	cp preimage .shit/objects/file &&
	(
		cd .shit/objects &&
		shit apply "$patch"
	) &&
	test_cmp expected .shit/objects/file
'

test_expect_success 'apply --cached from .shit dir' '
	cp postimage expected &&
	cp other expected.working &&
	cp other .shit/file &&
	reset_subdir preimage other &&
	(
		cd .shit &&
		shit apply --cached "$patch"
	) &&
	shit show :file >actual &&
	test_cmp expected actual &&
	test_cmp expected.working file &&
	test_cmp expected.working .shit/file
'

test_expect_success 'apply --cached from subdir of .shit dir' '
	cp postimage expected &&
	cp preimage expected.subdir &&
	cp other .shit/file &&
	cp other .shit/objects/file &&
	reset_subdir preimage other &&
	(
		cd .shit/objects &&
		shit apply --cached "$patch"
	) &&
	shit show :file >actual &&
	shit show :objects/file >actual.subdir &&
	test_cmp expected actual &&
	test_cmp expected.subdir actual.subdir
'

test_done
