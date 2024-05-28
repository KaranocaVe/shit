#!/bin/sh

test_description='ancestor culling and limiting by parent number'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

check_revlist () {
	rev_list_args="$1" &&
	shift &&
	shit rev-parse "$@" >expect &&
	shit rev-list $rev_list_args --all >actual &&
	test_cmp expect actual
}

test_expect_success setup '

	touch file &&
	shit add file &&

	test_commit one &&

	test_tick=$(($test_tick - 2400)) &&

	test_commit two &&
	test_commit three &&
	test_commit four &&

	shit log --pretty=oneline --abbrev-commit
'

test_expect_success 'one is ancestor of others and should not be shown' '

	shit rev-list one --not four >result &&
	test_must_be_empty result

'

test_expect_success 'setup roots, merges and octopuses' '

	shit checkout --orphan newroot &&
	test_commit five &&
	shit checkout -b sidebranch two &&
	test_commit six &&
	shit checkout -b anotherbranch three &&
	test_commit seven &&
	shit checkout -b yetanotherbranch four &&
	test_commit eight &&
	shit checkout main &&
	test_tick &&
	shit merge --allow-unrelated-histories -m normalmerge newroot &&
	shit tag normalmerge &&
	test_tick &&
	shit merge -m tripus sidebranch anotherbranch &&
	shit tag tripus &&
	shit checkout -b tetrabranch normalmerge &&
	test_tick &&
	shit merge -m tetrapus sidebranch anotherbranch yetanotherbranch &&
	shit tag tetrapus &&
	shit checkout main
'

test_expect_success 'parse --max-parents & --min-parents' '
	test_must_fail shit rev-list --max-parents=1q HEAD 2>error &&
	grep "not an integer" error &&

	test_must_fail shit rev-list --min-parents=1q HEAD 2>error &&
	grep "not an integer" error &&

	shit rev-list --max-parents=1 --min-parents=1 HEAD &&
	shit rev-list --max-parents=-1 --min-parents=-1 HEAD
'

test_expect_success 'rev-list roots' '

	check_revlist "--max-parents=0" one five
'

test_expect_success 'rev-list no merges' '

	check_revlist "--max-parents=1" one eight seven six five four three two &&
	check_revlist "--no-merges" one eight seven six five four three two
'

test_expect_success 'rev-list no octopuses' '

	check_revlist "--max-parents=2" one normalmerge eight seven six five four three two
'

test_expect_success 'rev-list no roots' '

	check_revlist "--min-parents=1" tetrapus tripus normalmerge eight seven six four three two
'

test_expect_success 'rev-list merges' '

	check_revlist "--min-parents=2" tetrapus tripus normalmerge &&
	check_revlist "--merges" tetrapus tripus normalmerge
'

test_expect_success 'rev-list octopus' '

	check_revlist "--min-parents=3" tetrapus tripus
'

test_expect_success 'rev-list ordinary commits' '

	check_revlist "--min-parents=1 --max-parents=1" eight seven six four three two
'

test_expect_success 'rev-list --merges --no-merges yields empty set' '

	check_revlist "--min-parents=2 --no-merges" &&
	check_revlist "--merges --no-merges" &&
	check_revlist "--no-merges --merges"
'

test_expect_success 'rev-list override and infinities' '

	check_revlist "--min-parents=2 --max-parents=1 --max-parents=3" tripus normalmerge &&
	check_revlist "--min-parents=1 --min-parents=2 --max-parents=7" tetrapus tripus normalmerge &&
	check_revlist "--min-parents=2 --max-parents=8" tetrapus tripus normalmerge &&
	check_revlist "--min-parents=2 --max-parents=-1" tetrapus tripus normalmerge &&
	check_revlist "--min-parents=2 --no-max-parents" tetrapus tripus normalmerge &&
	check_revlist "--max-parents=0 --min-parents=1 --no-min-parents" one five
'

test_expect_success 'dodecapus' '

	roots= &&
	for i in 1 2 3 4 5 6 7 8 9 10 11
	do
		shit checkout -b root$i five &&
		test_commit $i &&
		roots="$roots root$i" ||
		return 1
	done &&
	shit checkout main &&
	test_tick &&
	shit merge -m dodecapus $roots &&
	shit tag dodecapus &&

	check_revlist "--min-parents=4" dodecapus tetrapus &&
	check_revlist "--min-parents=8" dodecapus &&
	check_revlist "--min-parents=12" dodecapus &&
	check_revlist "--min-parents=13" &&
	check_revlist "--min-parents=4 --max-parents=11" tetrapus
'

test_expect_success 'ancestors with the same commit time' '

	test_tick_keep=$test_tick &&
	for i in 1 2 3 4 5 6 7 8; do
		test_tick=$test_tick_keep &&
		test_commit t$i || return 1
	done &&
	shit rev-list t1^! --not t$i >result &&
	test_must_be_empty result
'

test_done
