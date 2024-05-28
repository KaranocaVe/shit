#!/bin/sh

test_description='checkout $tree -- $paths'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	mkdir dir &&
	>dir/main &&
	echo common >dir/common &&
	shit add dir/main dir/common &&
	test_tick && shit commit -m "main has dir/main" &&
	shit checkout -b next &&
	shit mv dir/main dir/next0 &&
	echo next >dir/next1 &&
	shit add dir &&
	test_tick && shit commit -m "next has dir/next but not dir/main"
'

test_expect_success 'checking out paths out of a tree does not clobber unrelated paths' '
	shit checkout next &&
	shit reset --hard &&
	rm dir/next0 &&
	cat dir/common >expect.common &&
	echo modified >expect.next1 &&
	cat expect.next1 >dir/next1 &&
	echo untracked >expect.next2 &&
	cat expect.next2 >dir/next2 &&

	shit checkout main dir &&

	test_cmp expect.common dir/common &&
	test_path_is_file dir/main &&
	shit diff --exit-code main dir/main &&

	test_path_is_missing dir/next0 &&
	test_cmp expect.next1 dir/next1 &&
	test_path_is_file dir/next2 &&
	test_must_fail shit ls-files --error-unmatch dir/next2 &&
	test_cmp expect.next2 dir/next2
'

test_expect_success 'do not touch unmerged entries matching $path but not in $tree' '
	shit checkout next &&
	shit reset --hard &&

	cat dir/common >expect.common &&
	EMPTY_SHA1=$(shit hash-object -w --stdin </dev/null) &&
	shit rm dir/next0 &&
	cat >expect.next0 <<-EOF &&
	100644 $EMPTY_SHA1 1	dir/next0
	100644 $EMPTY_SHA1 2	dir/next0
	EOF
	shit update-index --index-info <expect.next0 &&

	shit checkout main dir &&

	test_cmp expect.common dir/common &&
	test_path_is_file dir/main &&
	shit diff --exit-code main dir/main &&
	shit ls-files -s dir/next0 >actual.next0 &&
	test_cmp expect.next0 actual.next0
'

test_expect_success 'do not touch files that are already up-to-date' '
	shit reset --hard &&
	echo one >file1 &&
	echo two >file2 &&
	shit add file1 file2 &&
	shit commit -m base &&
	echo modified >file1 &&
	test-tool chmtime =1000000000 file2 &&
	shit update-index -q --refresh &&
	shit checkout HEAD -- file1 file2 &&
	echo one >expect &&
	test_cmp expect file1 &&
	echo "1000000000" >expect &&
	test-tool chmtime --get file2 >actual &&
	test_cmp expect actual
'

test_expect_success 'checkout HEAD adds deleted intent-to-add file back to index' '
	echo "nonempty" >nonempty &&
	>empty &&
	shit add nonempty empty &&
	shit commit -m "create files to be deleted" &&
	shit rm --cached nonempty empty &&
	shit add -N nonempty empty &&
	shit checkout HEAD nonempty empty &&
	shit diff --cached --exit-code
'

test_done
