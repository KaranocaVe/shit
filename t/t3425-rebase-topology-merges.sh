#!/bin/sh

test_description='rebase topology tests with merges'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-rebase.sh

test_revision_subjects () {
	expected="$1"
	shift
	set -- $(shit log --format=%s --no-walk=unsorted "$@")
	test "$expected" = "$*"
}

# a---b-----------c
#      \           \
#       d-------e   \
#        \       \   \
#         n---o---w---v
#              \
#               z
test_expect_success 'setup of non-linear-history' '
	test_commit a &&
	test_commit b &&
	test_commit c &&
	shit checkout b &&
	test_commit d &&
	test_commit e &&

	shit checkout c &&
	test_commit g &&
	revert h g &&
	shit checkout d &&
	cherry_pick gp g &&
	test_commit i &&
	shit checkout b &&
	test_commit f &&

	shit checkout d &&
	test_commit n &&
	test_commit o &&
	test_merge w e &&
	test_merge v c &&
	shit checkout o &&
	test_commit z
'

test_run_rebase () {
	result=$1
	shift
	test_expect_$result "rebase $* after merge from upstream" "
		reset_rebase &&
		shit rebase $* e w &&
		test_cmp_rev e HEAD~2 &&
		test_linear_range 'n o' e..
	"
}
test_run_rebase success --apply
test_run_rebase success -m
test_run_rebase success -i

test_run_rebase () {
	result=$1
	shift
	expected=$1
	shift
	test_expect_$result "rebase $* of non-linear history is linearized in place" "
		reset_rebase &&
		shit rebase $* d w &&
		test_cmp_rev d HEAD~3 &&
		test_linear_range "\'"$expected"\'" d..
	"
}
test_run_rebase success 'n o e' --apply
test_run_rebase success 'n o e' -m
test_run_rebase success 'n o e' -i

test_run_rebase () {
	result=$1
	shift
	expected=$1
	shift
	test_expect_$result "rebase $* of non-linear history is linearized upstream" "
		reset_rebase &&
		shit rebase $* c w &&
		test_cmp_rev c HEAD~4 &&
		test_linear_range "\'"$expected"\'" c..
	"
}
test_run_rebase success 'd n o e' --apply
test_run_rebase success 'd n o e' -m
test_run_rebase success 'd n o e' -i

test_run_rebase () {
	result=$1
	shift
	expected=$1
	shift
	test_expect_$result "rebase $* of non-linear history with merges after upstream merge is linearized" "
		reset_rebase &&
		shit rebase $* c v &&
		test_cmp_rev c HEAD~4 &&
		test_linear_range "\'"$expected"\'" c..
	"
}
test_run_rebase success 'd n o e' --apply
test_run_rebase success 'd n o e' -m
test_run_rebase success 'd n o e' -i

test_done
