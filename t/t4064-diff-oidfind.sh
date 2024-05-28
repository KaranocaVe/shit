#!/bin/sh

test_description='test finding specific blobs in the revision walking'
. ./test-lib.sh

test_expect_success 'setup ' '
	shit commit --allow-empty -m "empty initial commit" &&

	echo "Hello, world!" >greeting &&
	shit add greeting &&
	shit commit -m "add the greeting blob" && # borrowed from shit from the Bottom Up
	shit tag -m "the blob" greeting $(shit rev-parse HEAD:greeting) &&

	echo asdf >unrelated &&
	shit add unrelated &&
	shit commit -m "unrelated history" &&

	shit revert HEAD^ &&

	shit commit --allow-empty -m "another unrelated commit"
'

test_expect_success 'find the greeting blob' '
	cat >expect <<-EOF &&
	Revert "add the greeting blob"
	add the greeting blob
	EOF

	shit log --format=%s --find-object=greeting^{blob} >actual &&

	test_cmp expect actual
'

test_expect_success 'setup a tree' '
	mkdir a &&
	echo asdf >a/file &&
	shit add a/file &&
	shit commit -m "add a file in a subdirectory"
'

test_expect_success 'find a tree' '
	cat >expect <<-EOF &&
	add a file in a subdirectory
	EOF

	shit log --format=%s -t --find-object=HEAD:a >actual &&

	test_cmp expect actual
'

test_expect_success 'setup a submodule' '
	test_create_repo sub &&
	test_commit -C sub sub &&
	shit submodule add ./sub sub &&
	shit commit -a -m "add sub"
'

test_expect_success 'find a submodule' '
	cat >expect <<-EOF &&
	add sub
	EOF

	shit log --format=%s --find-object=HEAD:sub >actual &&

	test_cmp expect actual
'

test_expect_success 'set up merge tests' '
	test_commit base &&

	shit checkout -b boring base^ &&
	echo boring >file &&
	shit add file &&
	shit commit -m boring &&

	shit checkout -b interesting base^ &&
	echo interesting >file &&
	shit add file &&
	shit commit -m interesting &&

	blob=$(shit rev-parse interesting:file)
'

test_expect_success 'detect merge which introduces blob' '
	shit checkout -B merge base &&
	shit merge --no-commit boring &&
	echo interesting >file &&
	shit commit -am "introduce blob" &&
	shit diff-tree --format=%s --find-object=$blob -c --name-status HEAD >actual &&
	cat >expect <<-\EOF &&
	introduce blob

	AM	file
	EOF
	test_cmp expect actual
'

test_expect_success 'detect merge which removes blob' '
	shit checkout -B merge interesting &&
	shit merge --no-commit base &&
	echo boring >file &&
	shit commit -am "remove blob" &&
	shit diff-tree --format=%s --find-object=$blob -c --name-status HEAD >actual &&
	cat >expect <<-\EOF &&
	remove blob

	MA	file
	EOF
	test_cmp expect actual
'

test_expect_success 'do not detect merge that does not touch blob' '
	shit checkout -B merge interesting &&
	shit merge -m "untouched blob" base &&
	shit diff-tree --format=%s --find-object=$blob -c --name-status HEAD >actual &&
	cat >expect <<-\EOF &&
	untouched blob

	EOF
	test_cmp expect actual
'

test_done
