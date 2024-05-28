#!/bin/sh

test_description='Test merge without common ancestors'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# This scenario is based on a real-world repository of Shawn Pearce.

# 1 - A - D - F
#   \   X   /
#     B   X
#       X   \
# 2 - C - E - G

shit_COMMITTER_DATE="2006-12-12 23:28:00 +0100"
export shit_COMMITTER_DATE

test_expect_success 'setup tests' '
	shit_TEST_COMMIT_GRAPH=0 &&
	export shit_TEST_COMMIT_GRAPH &&
	echo 1 >a1 &&
	shit add a1 &&
	shit_AUTHOR_DATE="2006-12-12 23:00:00" shit commit -m 1 a1 &&

	shit checkout -b A main &&
	echo A >a1 &&
	shit_AUTHOR_DATE="2006-12-12 23:00:01" shit commit -m A a1 &&

	shit checkout -b B main &&
	echo B >a1 &&
	shit_AUTHOR_DATE="2006-12-12 23:00:02" shit commit -m B a1 &&

	shit checkout -b D A &&
	shit rev-parse B >.shit/MERGE_HEAD &&
	echo D >a1 &&
	shit update-index a1 &&
	shit_AUTHOR_DATE="2006-12-12 23:00:03" shit commit -m D &&

	shit symbolic-ref HEAD refs/heads/other &&
	echo 2 >a1 &&
	shit_AUTHOR_DATE="2006-12-12 23:00:04" shit commit -m 2 a1 &&

	shit checkout -b C &&
	echo C >a1 &&
	shit_AUTHOR_DATE="2006-12-12 23:00:05" shit commit -m C a1 &&

	shit checkout -b E C &&
	shit rev-parse B >.shit/MERGE_HEAD &&
	echo E >a1 &&
	shit update-index a1 &&
	shit_AUTHOR_DATE="2006-12-12 23:00:06" shit commit -m E &&

	shit checkout -b G E &&
	shit rev-parse A >.shit/MERGE_HEAD &&
	echo G >a1 &&
	shit update-index a1 &&
	shit_AUTHOR_DATE="2006-12-12 23:00:07" shit commit -m G &&

	shit checkout -b F D &&
	shit rev-parse C >.shit/MERGE_HEAD &&
	echo F >a1 &&
	shit update-index a1 &&
	shit_AUTHOR_DATE="2006-12-12 23:00:08" shit commit -m F &&

	test_oid_cache <<-EOF
	idxstage1 sha1:ec3fe2a791706733f2d8fa7ad45d9a9672031f5e
	idxstage1 sha256:b3c8488929903aaebdeb22270cb6d36e5b8724b01ae0d4da24632f158c99676f
	EOF
'

test_expect_success 'combined merge conflicts' '
	test_must_fail shit merge -m final G
'

test_expect_success 'result contains a conflict' '
	cat >expect <<-\EOF &&
	<<<<<<< HEAD
	F
	=======
	G
	>>>>>>> G
	EOF

	test_cmp expect a1
'

test_expect_success 'virtual trees were processed' '
	# TODO: fragile test, relies on ambigious merge-base resolution
	shit ls-files --stage >out &&

	cat >expect <<-EOF &&
	100644 $(test_oid idxstage1) 1	a1
	100644 $(shit rev-parse F:a1) 2	a1
	100644 $(shit rev-parse G:a1) 3	a1
	EOF

	test_cmp expect out
'

test_expect_success 'refuse to merge binary files' '
	shit reset --hard &&
	printf "\0" >binary-file &&
	shit add binary-file &&
	shit commit -m binary &&
	shit checkout G &&
	printf "\0\0" >binary-file &&
	shit add binary-file &&
	shit commit -m binary2 &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		test_must_fail shit merge F >merge_output
	else
		test_must_fail shit merge F 2>merge_output
	fi &&
	grep "Cannot merge binary files: binary-file (HEAD vs. F)" merge_output
'

test_expect_success 'mark rename/delete as unmerged' '

	shit reset --hard &&
	shit checkout -b delete &&
	shit rm a1 &&
	test_tick &&
	shit commit -m delete &&
	shit checkout -b rename HEAD^ &&
	shit mv a1 a2 &&
	test_tick &&
	shit commit -m rename &&
	test_must_fail shit merge delete &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		test 2 = $(shit ls-files --unmerged | wc -l)
	else
		test 1 = $(shit ls-files --unmerged | wc -l)
	fi &&
	shit rev-parse --verify :2:a2 &&
	test_must_fail shit rev-parse --verify :3:a2 &&
	shit checkout -f delete &&
	test_must_fail shit merge rename &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		test 2 = $(shit ls-files --unmerged | wc -l)
	else
		test 1 = $(shit ls-files --unmerged | wc -l)
	fi &&
	test_must_fail shit rev-parse --verify :2:a2 &&
	shit rev-parse --verify :3:a2
'

test_done
