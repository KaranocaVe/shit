#!/bin/sh

test_description='test shit rev-list --cherry-pick -- file'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

# A---B---D---F
#  \
#   \
#    C---E
#
# B changes a file foo.c, adding a line of text.  C changes foo.c as
# well as bar.c, but the change in foo.c was identical to change B.
# D and C change bar in the same way, E and F differently.

test_expect_success setup '
	echo Hallo > foo &&
	shit add foo &&
	test_tick &&
	shit commit -m "A" &&
	shit tag A &&
	shit checkout -b branch &&
	echo Bello > foo &&
	echo Cello > bar &&
	shit add foo bar &&
	test_tick &&
	shit commit -m "C" &&
	shit tag C &&
	echo Dello > bar &&
	shit add bar &&
	test_tick &&
	shit commit -m "E" &&
	shit tag E &&
	shit checkout main &&
	shit checkout branch foo &&
	test_tick &&
	shit commit -m "B" &&
	shit tag B &&
	echo Cello > bar &&
	shit add bar &&
	test_tick &&
	shit commit -m "D" &&
	shit tag D &&
	echo Nello > bar &&
	shit add bar &&
	test_tick &&
	shit commit -m "F" &&
	shit tag F
'

cat >expect <<EOF
<tags/B
>tags/C
EOF

test_expect_success '--left-right' '
	shit rev-list --left-right B...C > actual &&
	shit name-rev --annotate-stdin --name-only --refs="*tags/*" \
		< actual > actual.named &&
	test_cmp expect actual.named
'

test_expect_success '--count' '
	shit rev-list --count B...C > actual &&
	test "$(cat actual)" = 2
'

test_expect_success '--cherry-pick foo comes up empty' '
	test -z "$(shit rev-list --left-right --cherry-pick B...C -- foo)"
'

cat >expect <<EOF
>tags/C
EOF

test_expect_success '--cherry-pick bar does not come up empty' '
	shit rev-list --left-right --cherry-pick B...C -- bar > actual &&
	shit name-rev --annotate-stdin --name-only --refs="*tags/*" \
		< actual > actual.named &&
	test_cmp expect actual.named
'

test_expect_success 'bar does not come up empty' '
	shit rev-list --left-right B...C -- bar > actual &&
	shit name-rev --annotate-stdin --name-only --refs="*tags/*" \
		< actual > actual.named &&
	test_cmp expect actual.named
'

cat >expect <<EOF
<tags/F
>tags/E
EOF

test_expect_success '--cherry-pick bar does not come up empty (II)' '
	shit rev-list --left-right --cherry-pick F...E -- bar > actual &&
	shit name-rev --annotate-stdin --name-only --refs="*tags/*" \
		< actual > actual.named &&
	test_cmp expect actual.named
'

test_expect_success 'name-rev multiple --refs combine inclusive' '
	shit rev-list --left-right --cherry-pick F...E -- bar >actual &&
	shit name-rev --annotate-stdin --name-only --refs="*tags/F" --refs="*tags/E" \
		<actual >actual.named &&
	test_cmp expect actual.named
'

cat >expect <<EOF
<tags/F
EOF

test_expect_success 'name-rev --refs excludes non-matched patterns' '
	shit rev-list --left-right --right-only --cherry-pick F...E -- bar >>expect &&
	shit rev-list --left-right --cherry-pick F...E -- bar >actual &&
	shit name-rev --annotate-stdin --name-only --refs="*tags/F" \
		<actual >actual.named &&
	test_cmp expect actual.named
'

cat >expect <<EOF
<tags/F
EOF

test_expect_success 'name-rev --exclude excludes matched patterns' '
	shit rev-list --left-right --right-only --cherry-pick F...E -- bar >>expect &&
	shit rev-list --left-right --cherry-pick F...E -- bar >actual &&
	shit name-rev --annotate-stdin --name-only --refs="*tags/*" --exclude="*E" \
		<actual >actual.named &&
	test_cmp expect actual.named
'

test_expect_success 'name-rev --no-refs clears the refs list' '
	shit rev-list --left-right --cherry-pick F...E -- bar >expect &&
	shit name-rev --annotate-stdin --name-only --refs="*tags/F" --refs="*tags/E" --no-refs --refs="*tags/G" \
		<expect >actual &&
	test_cmp expect actual
'

cat >expect <<EOF
+tags/F
=tags/D
+tags/E
=tags/C
EOF

test_expect_success '--cherry-mark' '
	shit rev-list --cherry-mark F...E -- bar > actual &&
	shit name-rev --annotate-stdin --name-only --refs="*tags/*" \
		< actual > actual.named &&
	test_cmp expect actual.named
'

cat >expect <<EOF
<tags/F
=tags/D
>tags/E
=tags/C
EOF

test_expect_success '--cherry-mark --left-right' '
	shit rev-list --cherry-mark --left-right F...E -- bar > actual &&
	shit name-rev --annotate-stdin --name-only --refs="*tags/*" \
		< actual > actual.named &&
	test_cmp expect actual.named
'

cat >expect <<EOF
tags/E
EOF

test_expect_success '--cherry-pick --right-only' '
	shit rev-list --cherry-pick --right-only F...E -- bar > actual &&
	shit name-rev --annotate-stdin --name-only --refs="*tags/*" \
		< actual > actual.named &&
	test_cmp expect actual.named
'

test_expect_success '--cherry-pick --left-only' '
	shit rev-list --cherry-pick --left-only E...F -- bar > actual &&
	shit name-rev --annotate-stdin --name-only --refs="*tags/*" \
		< actual > actual.named &&
	test_cmp expect actual.named
'

cat >expect <<EOF
+tags/E
=tags/C
EOF

test_expect_success '--cherry' '
	shit rev-list --cherry F...E -- bar > actual &&
	shit name-rev --annotate-stdin --name-only --refs="*tags/*" \
		< actual > actual.named &&
	test_cmp expect actual.named
'

cat >expect <<EOF
1	1
EOF

test_expect_success '--cherry --count' '
	shit rev-list --cherry --count F...E -- bar > actual &&
	test_cmp expect actual
'

cat >expect <<EOF
2	2
EOF

test_expect_success '--cherry-mark --count' '
	shit rev-list --cherry-mark --count F...E -- bar > actual &&
	test_cmp expect actual
'

cat >expect <<EOF
1	1	2
EOF

test_expect_success '--cherry-mark --left-right --count' '
	shit rev-list --cherry-mark --left-right --count F...E -- bar > actual &&
	test_cmp expect actual
'

test_expect_success '--cherry-pick with independent, but identical branches' '
	shit symbolic-ref HEAD refs/heads/independent &&
	rm .shit/index &&
	echo Hallo > foo &&
	shit add foo &&
	test_tick &&
	shit commit -m "independent" &&
	echo Bello > foo &&
	test_tick &&
	shit commit -m "independent, too" foo &&
	test -z "$(shit rev-list --left-right --cherry-pick \
		HEAD...main -- foo)"
'

cat >expect <<EOF
1	2
EOF

test_expect_success '--count --left-right' '
	shit rev-list --count --left-right C...D > actual &&
	test_cmp expect actual
'

test_expect_success '--cherry-pick with duplicates on each side' '
	shit checkout -b dup-orig &&
	test_commit dup-base &&
	shit revert dup-base &&
	shit cherry-pick dup-base &&
	shit checkout -b dup-side HEAD~3 &&
	test_tick &&
	shit cherry-pick -3 dup-orig &&
	shit rev-list --cherry-pick dup-orig...dup-side >actual &&
	test_must_be_empty actual
'

# Corrupt the object store deliberately to make sure
# the object is not even checked for its existence.
remove_loose_object () {
	sha1="$(shit rev-parse "$1")" &&
	remainder=${sha1#??} &&
	firsttwo=${sha1%$remainder} &&
	rm .shit/objects/$firsttwo/$remainder
}

test_expect_success '--cherry-pick avoids looking at full diffs' '
	shit checkout -b shy-diff &&
	test_commit dont-look-at-me &&
	echo Hello >dont-look-at-me.t &&
	test_tick &&
	shit commit -m tip dont-look-at-me.t &&
	shit checkout -b mainline HEAD^ &&
	test_commit to-cherry-pick &&
	remove_loose_object shy-diff^:dont-look-at-me.t &&
	shit rev-list --cherry-pick ...shy-diff
'

test_done
