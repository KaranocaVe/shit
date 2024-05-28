#!/bin/sh

test_description='difference in submodules'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-diff.sh

test_expect_success setup '
	test_tick &&
	test_create_repo sub &&
	(
		cd sub &&
		echo hello >world &&
		shit add world &&
		shit commit -m submodule
	) &&

	test_tick &&
	echo frotz >nitfol &&
	shit add nitfol sub &&
	shit commit -m superproject &&

	(
		cd sub &&
		echo goodbye >world &&
		shit add world &&
		shit commit -m "submodule #2"
	) &&

	shit -C sub rev-list HEAD >revs &&
	set x $(cat revs) &&
	echo ":160000 160000 $3 $ZERO_OID M	sub" >expect &&
	subtip=$3 subprev=$2
'

test_expect_success 'shit diff --raw HEAD' '
	hexsz=$(test_oid hexsz) &&
	shit diff --raw --abbrev=$hexsz HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'shit diff-index --raw HEAD' '
	shit diff-index --raw HEAD >actual.index &&
	test_cmp expect actual.index
'

test_expect_success 'shit diff-files --raw' '
	shit diff-files --raw >actual.files &&
	test_cmp expect actual.files
'

expect_from_to () {
	printf "%sSubproject commit %s\n+Subproject commit %s\n" \
		"-" "$1" "$2"
}

test_expect_success 'shit diff HEAD' '
	shit diff HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subtip $subprev &&
	test_cmp expect.body actual.body
'

test_expect_success 'shit diff HEAD with dirty submodule (work tree)' '
	echo >>sub/world &&
	shit diff HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subtip $subprev-dirty &&
	test_cmp expect.body actual.body
'

test_expect_success 'shit diff HEAD with dirty submodule (index)' '
	(
		cd sub &&
		shit reset --hard &&
		echo >>world &&
		shit add world
	) &&
	shit diff HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subtip $subprev-dirty &&
	test_cmp expect.body actual.body
'

test_expect_success 'shit diff HEAD with dirty submodule (untracked)' '
	(
		cd sub &&
		shit reset --hard &&
		shit clean -qfdx &&
		>cruft
	) &&
	shit diff HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subtip $subprev &&
	test_cmp expect.body actual.body
'

test_expect_success 'shit diff HEAD with dirty submodule (untracked) (none ignored)' '
	test_config diff.ignoreSubmodules none &&
	shit diff HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subtip $subprev-dirty &&
	test_cmp expect.body actual.body
'

test_expect_success 'shit diff HEAD with dirty submodule (work tree, refs match)' '
	shit commit -m "x" sub &&
	echo >>sub/world &&
	shit diff HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subprev $subprev-dirty &&
	test_cmp expect.body actual.body &&
	shit diff --ignore-submodules HEAD >actual2 &&
	test_must_be_empty actual2 &&
	shit diff --ignore-submodules=untracked HEAD >actual3 &&
	sed -e "1,/^@@/d" actual3 >actual3.body &&
	expect_from_to >expect.body $subprev $subprev-dirty &&
	test_cmp expect.body actual3.body &&
	shit diff --ignore-submodules=dirty HEAD >actual4 &&
	test_must_be_empty actual4
'

test_expect_success 'shit diff HEAD with dirty submodule (work tree, refs match) [.shitmodules]' '
	shit config diff.ignoreSubmodules dirty &&
	shit diff HEAD >actual &&
	test_must_be_empty actual &&
	shit config --add -f .shitmodules submodule.subname.ignore none &&
	shit config --add -f .shitmodules submodule.subname.path sub &&
	shit diff HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subprev $subprev-dirty &&
	test_cmp expect.body actual.body &&
	shit config -f .shitmodules submodule.subname.ignore all &&
	shit config -f .shitmodules submodule.subname.path sub &&
	shit diff HEAD >actual2 &&
	test_must_be_empty actual2 &&
	shit config -f .shitmodules submodule.subname.ignore untracked &&
	shit diff HEAD >actual3 &&
	sed -e "1,/^@@/d" actual3 >actual3.body &&
	expect_from_to >expect.body $subprev $subprev-dirty &&
	test_cmp expect.body actual3.body &&
	shit config -f .shitmodules submodule.subname.ignore dirty &&
	shit diff HEAD >actual4 &&
	test_must_be_empty actual4 &&
	shit config submodule.subname.ignore none &&
	shit config submodule.subname.path sub &&
	shit diff HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subprev $subprev-dirty &&
	test_cmp expect.body actual.body &&
	shit config --remove-section submodule.subname &&
	shit config --remove-section -f .shitmodules submodule.subname &&
	shit config --unset diff.ignoreSubmodules &&
	rm .shitmodules
'

test_expect_success 'shit diff HEAD with dirty submodule (index, refs match)' '
	(
		cd sub &&
		shit reset --hard &&
		echo >>world &&
		shit add world
	) &&
	shit diff HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subprev $subprev-dirty &&
	test_cmp expect.body actual.body
'

test_expect_success 'shit diff HEAD with dirty submodule (untracked, refs match)' '
	(
		cd sub &&
		shit reset --hard &&
		shit clean -qfdx &&
		>cruft
	) &&
	shit diff --ignore-submodules=none HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subprev $subprev-dirty &&
	test_cmp expect.body actual.body &&
	shit diff --ignore-submodules=all HEAD >actual2 &&
	test_must_be_empty actual2 &&
	shit diff HEAD >actual3 &&
	test_must_be_empty actual3 &&
	shit diff --ignore-submodules=dirty HEAD >actual4 &&
	test_must_be_empty actual4
'

test_expect_success 'shit diff HEAD with dirty submodule (untracked, refs match) [.shitmodules]' '
	shit config --add -f .shitmodules submodule.subname.ignore all &&
	shit config --add -f .shitmodules submodule.subname.path sub &&
	shit diff HEAD >actual2 &&
	test_must_be_empty actual2 &&
	shit config -f .shitmodules submodule.subname.ignore untracked &&
	shit diff HEAD >actual3 &&
	test_must_be_empty actual3 &&
	shit config -f .shitmodules submodule.subname.ignore dirty &&
	shit diff HEAD >actual4 &&
	test_must_be_empty actual4 &&
	shit config submodule.subname.ignore none &&
	shit config submodule.subname.path sub &&
	shit diff HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subprev $subprev-dirty &&
	test_cmp expect.body actual.body &&
	shit config --remove-section submodule.subname &&
	shit config --remove-section -f .shitmodules submodule.subname &&
	rm .shitmodules
'

test_expect_success 'shit diff between submodule commits' '
	shit diff HEAD^..HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subtip $subprev &&
	test_cmp expect.body actual.body &&
	shit diff --ignore-submodules=dirty HEAD^..HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subtip $subprev &&
	test_cmp expect.body actual.body &&
	shit diff --ignore-submodules HEAD^..HEAD >actual &&
	test_must_be_empty actual
'

test_expect_success 'shit diff between submodule commits [.shitmodules]' '
	shit diff HEAD^..HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subtip $subprev &&
	test_cmp expect.body actual.body &&
	shit config --add -f .shitmodules submodule.subname.ignore dirty &&
	shit config --add -f .shitmodules submodule.subname.path sub &&
	shit diff HEAD^..HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subtip $subprev &&
	test_cmp expect.body actual.body &&
	shit config -f .shitmodules submodule.subname.ignore all &&
	shit diff HEAD^..HEAD >actual &&
	test_must_be_empty actual &&
	shit config submodule.subname.ignore dirty &&
	shit config submodule.subname.path sub &&
	shit diff  HEAD^..HEAD >actual &&
	sed -e "1,/^@@/d" actual >actual.body &&
	expect_from_to >expect.body $subtip $subprev &&
	shit config --remove-section submodule.subname &&
	shit config --remove-section -f .shitmodules submodule.subname &&
	rm .shitmodules
'

test_expect_success 'shit diff (empty submodule dir)' '
	rm -rf sub/* sub/.shit &&
	shit diff > actual.empty &&
	test_must_be_empty actual.empty
'

test_expect_success 'conflicted submodule setup' '
	c=$(test_oid ff_1) &&
	(
		echo "000000 $ZERO_OID 0	sub" &&
		echo "160000 1$c 1	sub" &&
		echo "160000 2$c 2	sub" &&
		echo "160000 3$c 3	sub"
	) | shit update-index --index-info &&
	echo >expect.nosub "diff --cc sub
index 2ffffff,3ffffff..0000000
--- a/sub
+++ b/sub
@@@ -1,1 -1,1 +1,1 @@@
- Subproject commit 2$c
 -Subproject commit 3$c
++Subproject commit $ZERO_OID" &&

	hh=$(shit rev-parse HEAD) &&
	sed -e "s/$ZERO_OID/$hh/" expect.nosub >expect.withsub

'

test_expect_success 'combined (empty submodule)' '
	rm -fr sub && mkdir sub &&
	shit diff >actual &&
	test_cmp expect.nosub actual
'

test_expect_success 'combined (with submodule)' '
	rm -fr sub &&
	shit clone --no-checkout . sub &&
	shit diff >actual &&
	test_cmp expect.withsub actual
'



test_done
