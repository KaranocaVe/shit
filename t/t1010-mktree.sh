#!/bin/sh

test_description='shit mktree'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	for d in a a- a0
	do
		mkdir "$d" && echo "$d/one" >"$d/one" &&
		shit add "$d" || return 1
	done &&
	echo zero >one &&
	shit update-index --add --info-only one &&
	shit write-tree --missing-ok >tree.missing &&
	shit ls-tree $(cat tree.missing) >top.missing &&
	shit ls-tree -r $(cat tree.missing) >all.missing &&
	echo one >one &&
	shit add one &&
	shit write-tree >tree &&
	shit ls-tree $(cat tree) >top &&
	shit ls-tree -r $(cat tree) >all &&
	test_tick &&
	shit commit -q -m one &&
	H=$(shit rev-parse HEAD) &&
	shit update-index --add --cacheinfo 160000 $H sub &&
	test_tick &&
	shit commit -q -m two &&
	shit rev-parse HEAD^{tree} >tree.withsub &&
	shit ls-tree HEAD >top.withsub &&
	shit ls-tree -r HEAD >all.withsub
'

test_expect_success 'ls-tree piped to mktree (1)' '
	shit mktree <top >actual &&
	test_cmp tree actual
'

test_expect_success 'ls-tree piped to mktree (2)' '
	shit mktree <top.withsub >actual &&
	test_cmp tree.withsub actual
'

test_expect_success 'ls-tree output in wrong order given to mktree (1)' '
	perl -e "print reverse <>" <top |
	shit mktree >actual &&
	test_cmp tree actual
'

test_expect_success 'ls-tree output in wrong order given to mktree (2)' '
	perl -e "print reverse <>" <top.withsub |
	shit mktree >actual &&
	test_cmp tree.withsub actual
'

test_expect_success 'allow missing object with --missing' '
	shit mktree --missing <top.missing >actual &&
	test_cmp tree.missing actual
'

test_expect_success 'mktree refuses to read ls-tree -r output (1)' '
	test_must_fail shit mktree <all
'

test_expect_success 'mktree refuses to read ls-tree -r output (2)' '
	test_must_fail shit mktree <all.withsub
'

test_done
