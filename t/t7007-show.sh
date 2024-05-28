#!/bin/sh

test_description='shit show'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	echo hello world >foo &&
	H=$(shit hash-object -w foo) &&
	shit tag -a foo-tag -m "Tags $H" $H &&
	HH=$(expr "$H" : "\(..\)") &&
	H38=$(expr "$H" : "..\(.*\)") &&
	rm -f .shit/objects/$HH/$H38
'

test_expect_success 'showing a tag that point at a missing object' '
	test_must_fail shit --no-pager show foo-tag
'

test_expect_success 'set up a bit of history' '
	test_commit main1 &&
	test_commit main2 &&
	test_commit main3 &&
	shit tag -m "annotated tag" annotated &&
	shit checkout -b side HEAD^^ &&
	test_commit side2 &&
	test_commit side3 &&
	test_merge merge main3
'

test_expect_success 'showing two commits' '
	cat >expect <<-EOF &&
	commit $(shit rev-parse main2)
	commit $(shit rev-parse main3)
	EOF
	shit show main2 main3 >actual &&
	grep ^commit actual >actual.filtered &&
	test_cmp expect actual.filtered
'

test_expect_success 'showing a tree' '
	cat >expected <<-EOF &&
	tree main1:

	main1.t
	EOF
	shit show main1: >actual &&
	test_cmp expected actual
'

test_expect_success 'showing two trees' '
	cat >expected <<-EOF &&
	tree main1^{tree}

	main1.t

	tree main2^{tree}

	main1.t
	main2.t
	EOF
	shit show main1^{tree} main2^{tree} >actual &&
	test_cmp expected actual
'

test_expect_success 'showing a trees is not recursive' '
	shit worktree add not-recursive main1 &&
	mkdir not-recursive/a &&
	test_commit -C not-recursive a/file &&
	cat >expected <<-EOF &&
	tree HEAD^{tree}

	a/
	main1.t
	EOF
	shit -C not-recursive show HEAD^{tree} >actual &&
	test_cmp expected actual
'

test_expect_success 'showing a range walks (linear)' '
	cat >expect <<-EOF &&
	commit $(shit rev-parse main3)
	commit $(shit rev-parse main2)
	EOF
	shit show main1..main3 >actual &&
	grep ^commit actual >actual.filtered &&
	test_cmp expect actual.filtered
'

test_expect_success 'showing a range walks (Y shape, ^ first)' '
	cat >expect <<-EOF &&
	commit $(shit rev-parse main3)
	commit $(shit rev-parse main2)
	EOF
	shit show ^side3 main3 >actual &&
	grep ^commit actual >actual.filtered &&
	test_cmp expect actual.filtered
'

test_expect_success 'showing a range walks (Y shape, ^ last)' '
	cat >expect <<-EOF &&
	commit $(shit rev-parse main3)
	commit $(shit rev-parse main2)
	EOF
	shit show main3 ^side3 >actual &&
	grep ^commit actual >actual.filtered &&
	test_cmp expect actual.filtered
'

test_expect_success 'showing with -N walks' '
	cat >expect <<-EOF &&
	commit $(shit rev-parse main3)
	commit $(shit rev-parse main2)
	EOF
	shit show -2 main3 >actual &&
	grep ^commit actual >actual.filtered &&
	test_cmp expect actual.filtered
'

test_expect_success 'showing annotated tag' '
	cat >expect <<-EOF &&
	tag annotated
	commit $(shit rev-parse annotated^{commit})
	EOF
	shit show annotated >actual &&
	grep -E "^(commit|tag)" actual >actual.filtered &&
	test_cmp expect actual.filtered
'

test_expect_success 'showing annotated tag plus commit' '
	cat >expect <<-EOF &&
	tag annotated
	commit $(shit rev-parse annotated^{commit})
	commit $(shit rev-parse side3)
	EOF
	shit show annotated side3 >actual &&
	grep -E "^(commit|tag)" actual >actual.filtered &&
	test_cmp expect actual.filtered
'

test_expect_success 'showing range' '
	cat >expect <<-EOF &&
	commit $(shit rev-parse main3)
	commit $(shit rev-parse main2)
	EOF
	shit show ^side3 annotated >actual &&
	grep -E "^(commit|tag)" actual >actual.filtered &&
	test_cmp expect actual.filtered
'

test_expect_success '-s suppresses diff' '
	cat >expect <<-\EOF &&
	merge
	main3
	EOF
	shit show -s --format=%s merge main3 >actual &&
	test_cmp expect actual
'

test_expect_success '--quiet suppresses diff' '
	echo main3 >expect &&
	shit show --quiet --format=%s main3 >actual &&
	test_cmp expect actual
'

test_expect_success 'show --graph is forbidden' '
  test_must_fail shit show --graph HEAD
'

test_done
