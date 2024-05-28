#!/bin/sh

test_description='shit rev-list trivial path optimization test

   d/z1
   b0                             b1
   o------------------------*----o main
  /                        /
 o---------o----o----o----o side
 a0        c0   c1   a1   c2
 d/f0      d/f1
 d/z0

'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success setup '
	echo Hello >a &&
	mkdir d &&
	echo World >d/f &&
	echo World >d/z &&
	shit add a d &&
	test_tick &&
	shit commit -m "Initial commit" &&
	shit rev-parse --verify HEAD &&
	shit tag initial
'

test_expect_success path-optimization '
	test_tick &&
	commit=$(echo "Unchanged tree" | shit commit-tree "HEAD^{tree}" -p HEAD) &&
	test $(shit rev-list $commit | wc -l) = 2 &&
	test $(shit rev-list $commit -- . | wc -l) = 1
'

test_expect_success 'further setup' '
	shit checkout -b side &&
	echo Irrelevant >c &&
	echo Irrelevant >d/f &&
	shit add c d/f &&
	test_tick &&
	shit commit -m "Side makes an irrelevant commit" &&
	shit tag side_c0 &&
	echo "More Irrelevancy" >c &&
	shit add c &&
	test_tick &&
	shit commit -m "Side makes another irrelevant commit" &&
	echo Bye >a &&
	shit add a &&
	test_tick &&
	shit commit -m "Side touches a" &&
	shit tag side_a1 &&
	echo "Yet more Irrelevancy" >c &&
	shit add c &&
	test_tick &&
	shit commit -m "Side makes yet another irrelevant commit" &&
	shit checkout main &&
	echo Another >b &&
	echo Munged >d/z &&
	shit add b d/z &&
	test_tick &&
	shit commit -m "Main touches b" &&
	shit tag main_b0 &&
	shit merge side &&
	echo Touched >b &&
	shit add b &&
	test_tick &&
	shit commit -m "Main touches b again"
'

test_expect_success 'path optimization 2' '
	shit rev-parse side_a1 initial >expected &&
	shit rev-list HEAD -- a >actual &&
	test_cmp expected actual
'

test_expect_success 'pathspec with leading path' '
	shit rev-parse main^ main_b0 side_c0 initial >expected &&
	shit rev-list HEAD -- d >actual &&
	test_cmp expected actual
'

test_expect_success 'pathspec with glob (1)' '
	shit rev-parse main^ main_b0 side_c0 initial >expected &&
	shit rev-list HEAD -- "d/*" >actual &&
	test_cmp expected actual
'

test_expect_success 'pathspec with glob (2)' '
	shit rev-parse side_c0 initial >expected &&
	shit rev-list HEAD -- "d/[a-m]*" >actual &&
	test_cmp expected actual
'

test_done
