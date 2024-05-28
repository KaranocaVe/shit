#!/bin/sh

test_description='remote tracking stats'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

advance () {
	echo "$1" >"$1" &&
	shit add "$1" &&
	test_tick &&
	shit commit -m "$1"
}

test_expect_success setup '
	advance a &&
	advance b &&
	advance c &&
	shit clone . test &&
	(
		cd test &&
		shit checkout -b b1 origin &&
		shit reset --hard HEAD^ &&
		advance d &&
		shit checkout -b b2 origin &&
		shit reset --hard b1 &&
		shit checkout -b b3 origin &&
		shit reset --hard HEAD^ &&
		shit checkout -b b4 origin &&
		advance e &&
		advance f &&
		shit checkout -b brokenbase origin &&
		shit checkout -b b5 --track brokenbase &&
		advance g &&
		shit branch -d brokenbase &&
		shit checkout -b b6 origin
	) &&
	shit checkout -b follower --track main &&
	advance h
'

t6040_script='s/^..\(b.\) *[0-9a-f]* \(.*\)$/\1 \2/p'
cat >expect <<\EOF
b1 [ahead 1, behind 1] d
b2 [ahead 1, behind 1] d
b3 [behind 1] b
b4 [ahead 2] f
b5 [gone] g
b6 c
EOF

test_expect_success 'branch -v' '
	(
		cd test &&
		shit branch -v
	) |
	sed -n -e "$t6040_script" >actual &&
	test_cmp expect actual
'

cat >expect <<\EOF
b1 [origin/main: ahead 1, behind 1] d
b2 [origin/main: ahead 1, behind 1] d
b3 [origin/main: behind 1] b
b4 [origin/main: ahead 2] f
b5 [brokenbase: gone] g
b6 [origin/main] c
EOF

test_expect_success 'branch -vv' '
	(
		cd test &&
		shit branch -vv
	) |
	sed -n -e "$t6040_script" >actual &&
	test_cmp expect actual
'

test_expect_success 'checkout (diverged from upstream)' '
	(
		cd test && shit checkout b1
	) >actual &&
	test_grep "have 1 and 1 different" actual
'

test_expect_success 'checkout with local tracked branch' '
	shit checkout main &&
	shit checkout follower >actual &&
	test_grep "is ahead of" actual
'

test_expect_success 'checkout (upstream is gone)' '
	(
		cd test &&
		shit checkout b5
	) >actual &&
	test_grep "is based on .*, but the upstream is gone." actual
'

test_expect_success 'checkout (up-to-date with upstream)' '
	(
		cd test && shit checkout b6
	) >actual &&
	test_grep "Your branch is up to date with .origin/main" actual
'

test_expect_success 'status (diverged from upstream)' '
	(
		cd test &&
		shit checkout b1 >/dev/null &&
		# reports nothing to commit
		test_must_fail shit commit --dry-run
	) >actual &&
	test_grep "have 1 and 1 different" actual
'

test_expect_success 'status (upstream is gone)' '
	(
		cd test &&
		shit checkout b5 >/dev/null &&
		# reports nothing to commit
		test_must_fail shit commit --dry-run
	) >actual &&
	test_grep "is based on .*, but the upstream is gone." actual
'

test_expect_success 'status (up-to-date with upstream)' '
	(
		cd test &&
		shit checkout b6 >/dev/null &&
		# reports nothing to commit
		test_must_fail shit commit --dry-run
	) >actual &&
	test_grep "Your branch is up to date with .origin/main" actual
'

cat >expect <<\EOF
## b1...origin/main [ahead 1, behind 1]
EOF

test_expect_success 'status -s -b (diverged from upstream)' '
	(
		cd test &&
		shit checkout b1 >/dev/null &&
		shit status -s -b | head -1
	) >actual &&
	test_cmp expect actual
'

cat >expect <<\EOF
## b1...origin/main [different]
EOF

test_expect_success 'status -s -b --no-ahead-behind (diverged from upstream)' '
	(
		cd test &&
		shit checkout b1 >/dev/null &&
		shit status -s -b --no-ahead-behind | head -1
	) >actual &&
	test_cmp expect actual
'

cat >expect <<\EOF
## b1...origin/main [different]
EOF

test_expect_success 'status.aheadbehind=false status -s -b (diverged from upstream)' '
	(
		cd test &&
		shit checkout b1 >/dev/null &&
		shit -c status.aheadbehind=false status -s -b | head -1
	) >actual &&
	test_cmp expect actual
'

cat >expect <<\EOF
On branch b1
Your branch and 'origin/main' have diverged,
and have 1 and 1 different commits each, respectively.
EOF

test_expect_success 'status --long --branch' '
	(
		cd test &&
		shit checkout b1 >/dev/null &&
		shit status --long -b | head -3
	) >actual &&
	test_cmp expect actual
'

test_expect_success 'status --long --branch' '
	(
		cd test &&
		shit checkout b1 >/dev/null &&
		shit -c status.aheadbehind=true status --long -b | head -3
	) >actual &&
	test_cmp expect actual
'

cat >expect <<\EOF
On branch b1
Your branch and 'origin/main' refer to different commits.
EOF

test_expect_success 'status --long --branch --no-ahead-behind' '
	(
		cd test &&
		shit checkout b1 >/dev/null &&
		shit status --long -b --no-ahead-behind | head -2
	) >actual &&
	test_cmp expect actual
'

test_expect_success 'status.aheadbehind=false status --long --branch' '
	(
		cd test &&
		shit checkout b1 >/dev/null &&
		shit -c status.aheadbehind=false status --long -b | head -2
	) >actual &&
	test_cmp expect actual
'

cat >expect <<\EOF
## b5...brokenbase [gone]
EOF

test_expect_success 'status -s -b (upstream is gone)' '
	(
		cd test &&
		shit checkout b5 >/dev/null &&
		shit status -s -b | head -1
	) >actual &&
	test_cmp expect actual
'

cat >expect <<\EOF
## b6...origin/main
EOF

test_expect_success 'status -s -b (up-to-date with upstream)' '
	(
		cd test &&
		shit checkout b6 >/dev/null &&
		shit status -s -b | head -1
	) >actual &&
	test_cmp expect actual
'

test_expect_success 'fail to track lightweight tags' '
	shit checkout main &&
	shit tag light &&
	test_must_fail shit branch --track lighttrack light >actual &&
	test_grep ! "set up to track" actual &&
	test_must_fail shit checkout lighttrack
'

test_expect_success 'fail to track annotated tags' '
	shit checkout main &&
	shit tag -m heavy heavy &&
	test_must_fail shit branch --track heavytrack heavy >actual &&
	test_grep ! "set up to track" actual &&
	test_must_fail shit checkout heavytrack
'

test_expect_success '--set-upstream-to does not change branch' '
	shit branch from-main main &&
	shit branch --set-upstream-to main from-main &&
	shit branch from-topic_2 main &&
	test_must_fail shit config branch.from-topic_2.merge > actual &&
	shit rev-list from-topic_2 &&
	shit update-ref refs/heads/from-topic_2 from-topic_2^ &&
	shit rev-parse from-topic_2 >expect2 &&
	shit branch --set-upstream-to main from-topic_2 &&
	shit config branch.from-main.merge > actual &&
	shit rev-parse from-topic_2 >actual2 &&
	grep -q "^refs/heads/main$" actual &&
	cmp expect2 actual2
'

test_expect_success '--set-upstream-to @{-1}' '
	shit checkout follower &&
	shit checkout from-topic_2 &&
	shit config branch.from-topic_2.merge > expect2 &&
	shit branch --set-upstream-to @{-1} from-main &&
	shit config branch.from-main.merge > actual &&
	shit config branch.from-topic_2.merge > actual2 &&
	shit branch --set-upstream-to follower from-main &&
	shit config branch.from-main.merge > expect &&
	test_cmp expect2 actual2 &&
	test_cmp expect actual
'

test_done
