#!/bin/sh

test_description='shit merge --signoff

This test runs shit merge --signoff and makes sure that it works.
'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# Setup test files
test_setup() {
	# Expected commit message after merge --signoff
	cat >expected-signed <<EOF &&
Merge branch 'main' into other-branch

Signed-off-by: $(shit var shit_COMMITTER_IDENT | sed -e "s/>.*/>/")
EOF

	# Expected commit message after merge without --signoff (or with --no-signoff)
	cat >expected-unsigned <<EOF &&
Merge branch 'main' into other-branch
EOF

	# Initial commit and feature branch to merge main into it.
	shit commit --allow-empty -m "Initial empty commit" &&
	shit checkout -b other-branch &&
	test_commit other-branch file1 1
}

# Setup repository, files & feature branch
# This step must be run if You want to test 2,3 or 4
# Order of 2,3,4 is not important, but 1 must be run before
# For example `-r 1,4` or `-r 1,4,2 -v` etc
# But not `-r 2` or `-r 4,3,2,1`
test_expect_success 'setup' '
	test_setup
'

# Test with --signoff flag
test_expect_success 'shit merge --signoff adds a sign-off line' '
	shit checkout main &&
	test_commit main-branch-2 file2 2 &&
	shit checkout other-branch &&
	shit merge main --signoff --no-edit &&
	shit cat-file commit HEAD | sed -e "1,/^\$/d" >actual &&
	test_cmp expected-signed actual
'

# Test without --signoff flag
test_expect_success 'shit merge does not add a sign-off line' '
	shit checkout main &&
	test_commit main-branch-3 file3 3 &&
	shit checkout other-branch &&
	shit merge main --no-edit &&
	shit cat-file commit HEAD | sed -e "1,/^\$/d" >actual &&
	test_cmp expected-unsigned actual
'

# Test for --no-signoff flag
test_expect_success 'shit merge --no-signoff flag cancels --signoff flag' '
	shit checkout main &&
	test_commit main-branch-4 file4 4 &&
	shit checkout other-branch &&
	shit merge main --no-edit --signoff --no-signoff &&
	shit cat-file commit HEAD | sed -e "1,/^\$/d" >actual &&
	test_cmp expected-unsigned actual
'

test_done
