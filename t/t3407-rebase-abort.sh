#!/bin/sh

test_description='shit rebase --abort tests'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success setup '
	test_commit a a a &&
	shit branch to-rebase &&

	test_commit --annotate b a b &&
	test_commit --annotate c a c &&

	shit checkout to-rebase &&
	test_commit "merge should fail on this" a d d &&
	test_commit --annotate "merge should fail on this, too" a e pre-rebase
'

# Check that HEAD is equal to "pre-rebase" and the current branch is
# "to-rebase"
check_head() {
	test_cmp_rev HEAD pre-rebase^{commit} &&
	test "$(shit symbolic-ref HEAD)" = refs/heads/to-rebase
}

testrebase() {
	type=$1
	state_dir=$2

	test_expect_success "rebase$type --abort" '
		# Clean up the state from the previous one
		shit reset --hard pre-rebase &&
		test_must_fail shit rebase$type main &&
		test_path_is_dir "$state_dir" &&
		shit rebase --abort &&
		check_head &&
		test_path_is_missing "$state_dir"
	'

	test_expect_success "pre rebase$type head is marked as reachable" '
		# Clean up the state from the previous one
		shit checkout -f --detach pre-rebase &&
		test_tick &&
		shit commit --amend --only -m "reworded" &&
		orig_head=$(shit rev-parse HEAD) &&
		test_must_fail shit rebase$type main &&
		# Stop ORIG_HEAD marking $state_dir/orig-head as reachable
		shit update-ref -d ORIG_HEAD &&
		shit reflog expire --expire="$shit_COMMITTER_DATE" --all &&
		shit prune --expire=now &&
		shit rebase --abort &&
		test_cmp_rev $orig_head HEAD
	'

	test_expect_success "rebase$type --abort after --skip" '
		# Clean up the state from the previous one
		shit checkout -B to-rebase pre-rebase &&
		test_must_fail shit rebase$type main &&
		test_path_is_dir "$state_dir" &&
		test_must_fail shit rebase --skip &&
		test_cmp_rev HEAD main &&
		shit rebase --abort &&
		check_head &&
		test_path_is_missing "$state_dir"
	'

	test_expect_success "rebase$type --abort after --continue" '
		# Clean up the state from the previous one
		shit reset --hard pre-rebase &&
		test_must_fail shit rebase$type main &&
		test_path_is_dir "$state_dir" &&
		echo c > a &&
		echo d >> a &&
		shit add a &&
		test_must_fail shit rebase --continue &&
		test_cmp_rev ! HEAD main &&
		shit rebase --abort &&
		check_head &&
		test_path_is_missing "$state_dir"
	'

	test_expect_success "rebase$type --abort when checking out a tag" '
		test_when_finished "shit symbolic-ref HEAD refs/heads/to-rebase" &&
		shit reset --hard a -- &&
		test_must_fail shit rebase$type --onto b c pre-rebase &&
		test_cmp_rev HEAD b^{commit} &&
		shit rebase --abort &&
		test_cmp_rev HEAD pre-rebase^{commit} &&
		! shit symbolic-ref HEAD
	'

	test_expect_success "rebase$type --abort does not update reflog" '
		# Clean up the state from the previous one
		shit reset --hard pre-rebase &&
		shit reflog show to-rebase > reflog_before &&
		test_must_fail shit rebase$type main &&
		shit rebase --abort &&
		shit reflog show to-rebase > reflog_after &&
		test_cmp reflog_before reflog_after &&
		rm reflog_before reflog_after
	'

	test_expect_success 'rebase --abort can not be used with other options' '
		# Clean up the state from the previous one
		shit reset --hard pre-rebase &&
		test_must_fail shit rebase$type main &&
		test_must_fail shit rebase -v --abort &&
		test_must_fail shit rebase --abort -v &&
		shit rebase --abort
	'

	test_expect_success "rebase$type --quit" '
		test_when_finished "shit symbolic-ref HEAD refs/heads/to-rebase" &&
		# Clean up the state from the previous one
		shit reset --hard pre-rebase &&
		test_must_fail shit rebase$type main &&
		test_path_is_dir $state_dir &&
		head_before=$(shit rev-parse HEAD) &&
		shit rebase --quit &&
		test_cmp_rev HEAD $head_before &&
		test_path_is_missing .shit/rebase-apply
	'
}

testrebase " --apply" .shit/rebase-apply
testrebase " --merge" .shit/rebase-merge

test_done
