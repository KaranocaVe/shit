#!/bin/sh

test_description='tests for ref^{stuff}'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '
	echo blob >a-blob &&
	shit tag -a -m blob blob-tag $(shit hash-object -w a-blob) &&
	mkdir a-tree &&
	echo moreblobs >a-tree/another-blob &&
	shit add . &&
	TREE_SHA1=$(shit write-tree) &&
	shit tag -a -m tree tree-tag "$TREE_SHA1" &&
	shit commit -m Initial &&
	shit tag -a -m commit commit-tag &&
	shit branch ref &&
	shit checkout main &&
	echo modified >>a-blob &&
	shit add -u &&
	shit commit -m Modified &&
	shit branch modref &&
	echo changed! >>a-blob &&
	shit add -u &&
	shit commit -m !Exp &&
	shit branch expref &&
	echo changed >>a-blob &&
	shit add -u &&
	shit commit -m Changed &&
	echo changed-again >>a-blob &&
	shit add -u &&
	shit commit -m Changed-again
'

test_expect_success 'ref^{non-existent}' '
	test_must_fail shit rev-parse ref^{non-existent}
'

test_expect_success 'ref^{}' '
	shit rev-parse ref >expected &&
	shit rev-parse ref^{} >actual &&
	test_cmp expected actual &&
	shit rev-parse commit-tag^{} >actual &&
	test_cmp expected actual
'

test_expect_success 'ref^{commit}' '
	shit rev-parse ref >expected &&
	shit rev-parse ref^{commit} >actual &&
	test_cmp expected actual &&
	shit rev-parse commit-tag^{commit} >actual &&
	test_cmp expected actual &&
	test_must_fail shit rev-parse tree-tag^{commit} &&
	test_must_fail shit rev-parse blob-tag^{commit}
'

test_expect_success 'ref^{tree}' '
	echo $TREE_SHA1 >expected &&
	shit rev-parse ref^{tree} >actual &&
	test_cmp expected actual &&
	shit rev-parse commit-tag^{tree} >actual &&
	test_cmp expected actual &&
	shit rev-parse tree-tag^{tree} >actual &&
	test_cmp expected actual &&
	test_must_fail shit rev-parse blob-tag^{tree}
'

test_expect_success 'ref^{tag}' '
	test_must_fail shit rev-parse HEAD^{tag} &&
	shit rev-parse commit-tag >expected &&
	shit rev-parse commit-tag^{tag} >actual &&
	test_cmp expected actual
'

test_expect_success 'ref^{/.}' '
	shit rev-parse main >expected &&
	shit rev-parse main^{/.} >actual &&
	test_cmp expected actual
'

test_expect_success 'ref^{/non-existent}' '
	test_must_fail shit rev-parse main^{/non-existent}
'

test_expect_success 'ref^{/Initial}' '
	shit rev-parse ref >expected &&
	shit rev-parse main^{/Initial} >actual &&
	test_cmp expected actual
'

test_expect_success 'ref^{/!Exp}' '
	test_must_fail shit rev-parse main^{/!Exp}
'

test_expect_success 'ref^{/!}' '
	test_must_fail shit rev-parse main^{/!}
'

test_expect_success 'ref^{/!!Exp}' '
	shit rev-parse expref >expected &&
	shit rev-parse main^{/!!Exp} >actual &&
	test_cmp expected actual
'

test_expect_success 'ref^{/!-}' '
	test_must_fail shit rev-parse main^{/!-}
'

test_expect_success 'ref^{/!-.}' '
	test_must_fail shit rev-parse main^{/!-.}
'

test_expect_success 'ref^{/!-non-existent}' '
	shit rev-parse main >expected &&
	shit rev-parse main^{/!-non-existent} >actual &&
	test_cmp expected actual
'

test_expect_success 'ref^{/!-Changed}' '
	shit rev-parse expref >expected &&
	shit rev-parse main^{/!-Changed} >actual &&
	test_cmp expected actual
'

test_expect_success 'ref^{/!-!Exp}' '
	shit rev-parse modref >expected &&
	shit rev-parse expref^{/!-!Exp} >actual &&
	test_cmp expected actual
'

test_done
