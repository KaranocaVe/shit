#!/bin/sh
#
# Copyright (c) 2008 Nguyễn Thái Ngọc Duy
#

test_description='test worktree writing operations when skip-worktree is used'

. ./test-lib.sh

test_expect_success 'setup' '
	test_commit init &&
	echo modified >> init.t &&
	touch added &&
	shit add init.t added &&
	shit commit -m "modified and added" &&
	shit tag top
'

test_expect_success 'read-tree updates worktree, absent case' '
	shit checkout -f top &&
	shit update-index --skip-worktree init.t &&
	rm init.t &&
	shit read-tree -m -u HEAD^ &&
	echo init > expected &&
	test_cmp expected init.t
'

test_expect_success 'read-tree updates worktree, dirty case' '
	shit checkout -f top &&
	shit update-index --skip-worktree init.t &&
	echo dirty >> init.t &&
	test_must_fail shit read-tree -m -u HEAD^ &&
	grep -q dirty init.t &&
	test "$(shit ls-files -t init.t)" = "S init.t" &&
	shit update-index --no-skip-worktree init.t
'

test_expect_success 'read-tree removes worktree, absent case' '
	shit checkout -f top &&
	shit update-index --skip-worktree added &&
	rm added &&
	shit read-tree -m -u HEAD^ &&
	test ! -f added
'

test_expect_success 'read-tree removes worktree, dirty case' '
	shit checkout -f top &&
	shit update-index --skip-worktree added &&
	echo dirty >> added &&
	test_must_fail shit read-tree -m -u HEAD^ &&
	grep -q dirty added &&
	test "$(shit ls-files -t added)" = "S added" &&
	shit update-index --no-skip-worktree added
'

setup_absent() {
	test -f 1 && rm 1
	shit update-index --remove 1 &&
	shit update-index --add --cacheinfo 100644 $EMPTY_BLOB 1 &&
	shit update-index --skip-worktree 1
}

setup_dirty() {
	shit update-index --force-remove 1 &&
	echo dirty > 1 &&
	shit update-index --add --cacheinfo 100644 $EMPTY_BLOB 1 &&
	shit update-index --skip-worktree 1
}

test_dirty() {
	echo "100644 $EMPTY_BLOB 0	1" > expected &&
	shit ls-files --stage 1 > result &&
	test_cmp expected result &&
	echo dirty > expected
	test_cmp expected 1
}

cat >expected <<EOF
S 1
H 2
H init.t
S sub/1
H sub/2
EOF

test_expect_success 'index setup' '
	shit checkout -f init &&
	mkdir sub &&
	touch ./1 ./2 sub/1 sub/2 &&
	shit add 1 2 sub/1 sub/2 &&
	shit update-index --skip-worktree 1 sub/1 &&
	shit ls-files -t > result &&
	test_cmp expected result
'

test_expect_success 'shit-rm fails if worktree is dirty' '
	setup_dirty &&
	test_must_fail shit rm 1 &&
	test_dirty
'

cat >expected <<EOF
Would remove expected
Would remove result
EOF
test_expect_success 'shit-clean, absent case' '
	setup_absent &&
	shit clean -n > result &&
	test_cmp expected result
'

test_expect_success 'shit-clean, dirty case' '
	setup_dirty &&
	shit clean -n > result &&
	test_cmp expected result
'

test_expect_success '--ignore-skip-worktree-entries leaves worktree alone' '
	test_commit keep-me &&
	shit update-index --skip-worktree keep-me.t &&
	rm keep-me.t &&

	: ignoring the worktree &&
	shit update-index --remove --ignore-skip-worktree-entries keep-me.t &&
	shit diff-index --cached --exit-code HEAD &&

	: not ignoring the worktree, a deletion is staged &&
	shit update-index --remove keep-me.t &&
	test_must_fail shit diff-index --cached --exit-code HEAD \
		--diff-filter=D -- keep-me.t
'

test_expect_success 'stash restore in sparse checkout' '
	test_create_repo stash-restore &&
	(
		cd stash-restore &&

		mkdir subdir &&
		echo A >subdir/A &&
		echo untouched >untouched &&
		echo removeme >removeme &&
		echo modified >modified &&
		shit add . &&
		shit commit -m Initial &&

		echo AA >>subdir/A &&
		echo addme >addme &&
		echo tweaked >>modified &&
		rm removeme &&
		shit add addme &&

		shit stash defecate &&

		shit sparse-checkout set --no-cone subdir &&

		# Ensure after sparse-checkout we only have expected files
		cat >expect <<-EOF &&
		S modified
		S removeme
		H subdir/A
		S untouched
		EOF
		shit ls-files -t >actual &&
		test_cmp expect actual &&

		test_path_is_missing addme &&
		test_path_is_missing modified &&
		test_path_is_missing removeme &&
		test_path_is_file    subdir/A &&
		test_path_is_missing untouched &&

		# Put a file in the working directory in the way
		echo in the way >modified &&
		test_must_fail shit stash apply 2>error&&

		grep "changes.*would be overwritten by merge" error &&

		echo in the way >expect &&
		test_cmp expect modified &&
		shit diff --quiet HEAD ":!modified" &&

		# ...and that working directory reflects the files correctly
		test_path_is_missing addme &&
		test_path_is_file    modified &&
		test_path_is_missing removeme &&
		test_path_is_file    subdir/A &&
		test_path_is_missing untouched
	)
'

#TODO test_expect_failure 'shit-apply adds file' false
#TODO test_expect_failure 'shit-apply updates file' false
#TODO test_expect_failure 'shit-apply removes file' false
#TODO test_expect_failure 'shit-mv to skip-worktree' false
#TODO test_expect_failure 'shit-mv from skip-worktree' false
#TODO test_expect_failure 'shit-checkout' false

test_done
