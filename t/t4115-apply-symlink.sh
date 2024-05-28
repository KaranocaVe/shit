#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='shit apply symlinks and partial files

'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	test_ln_s_add path1/path2/path3/path4/path5 link1 &&
	shit commit -m initial &&

	shit branch side &&

	rm -f link? &&

	test_ln_s_add htap6 link1 &&
	shit commit -m second &&

	shit diff-tree -p HEAD^ HEAD >patch  &&
	shit apply --stat --summary patch

'

test_expect_success SYMLINKS 'apply symlink patch' '

	shit checkout side &&
	shit apply patch &&
	shit diff-files -p >patched &&
	test_cmp patch patched

'

test_expect_success 'apply --index symlink patch' '

	shit checkout -f side &&
	shit apply --index patch &&
	shit diff-index --cached -p HEAD >patched &&
	test_cmp patch patched

'

test_expect_success 'symlink setup' '
	ln -s .shit symlink &&
	shit add symlink &&
	shit commit -m "add symlink"
'

test_expect_success SYMLINKS 'symlink escape when creating new files' '
	test_when_finished "shit reset --hard && shit clean -dfx" &&

	cat >patch <<-EOF &&
	diff --shit a/symlink b/renamed-symlink
	similarity index 100%
	rename from symlink
	rename to renamed-symlink
	--
	diff --shit /dev/null b/renamed-symlink/create-me
	new file mode 100644
	index 0000000..039727e
	--- /dev/null
	+++ b/renamed-symlink/create-me
	@@ -0,0 +1,1 @@
	+busted
	EOF

	test_must_fail shit apply patch 2>stderr &&
	cat >expected_stderr <<-EOF &&
	error: affected file ${SQ}renamed-symlink/create-me${SQ} is beyond a symbolic link
	EOF
	test_cmp expected_stderr stderr &&
	test_path_is_missing .shit/create-me
'

test_expect_success SYMLINKS 'symlink escape when modifying file' '
	test_when_finished "shit reset --hard && shit clean -dfx" &&
	touch .shit/modify-me &&

	cat >patch <<-EOF &&
	diff --shit a/symlink b/renamed-symlink
	similarity index 100%
	rename from symlink
	rename to renamed-symlink
	--
	diff --shit a/renamed-symlink/modify-me b/renamed-symlink/modify-me
	index 1111111..2222222 100644
	--- a/renamed-symlink/modify-me
	+++ b/renamed-symlink/modify-me
	@@ -0,0 +1,1 @@
	+busted
	EOF

	test_must_fail shit apply patch 2>stderr &&
	cat >expected_stderr <<-EOF &&
	error: renamed-symlink/modify-me: No such file or directory
	EOF
	test_cmp expected_stderr stderr &&
	test_must_be_empty .shit/modify-me
'

test_expect_success SYMLINKS 'symlink escape when deleting file' '
	test_when_finished "shit reset --hard && shit clean -dfx && rm .shit/delete-me" &&
	touch .shit/delete-me &&

	cat >patch <<-EOF &&
	diff --shit a/symlink b/renamed-symlink
	similarity index 100%
	rename from symlink
	rename to renamed-symlink
	--
	diff --shit a/renamed-symlink/delete-me b/renamed-symlink/delete-me
	deleted file mode 100644
	index 1111111..0000000 100644
	EOF

	test_must_fail shit apply patch 2>stderr &&
	cat >expected_stderr <<-EOF &&
	error: renamed-symlink/delete-me: No such file or directory
	EOF
	test_cmp expected_stderr stderr &&
	test_path_is_file .shit/delete-me
'

test_expect_success SYMLINKS '--reject removes .rej symlink if it exists' '
	test_when_finished "shit reset --hard && shit clean -dfx" &&

	test_commit file &&
	echo modified >file.t &&
	shit diff -- file.t >patch &&
	echo modified-again >file.t &&

	ln -s foo file.t.rej &&
	test_must_fail shit apply patch --reject 2>err &&
	test_grep "Rejected hunk" err &&
	test_path_is_missing foo &&
	test_path_is_file file.t.rej
'

test_done
