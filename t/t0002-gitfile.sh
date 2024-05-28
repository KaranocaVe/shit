#!/bin/sh

test_description='.shit file

Verify that plumbing commands work when .shit is a file
'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

objpath() {
	echo "$1" | sed -e 's|\(..\)|\1/|'
}

test_expect_success 'initial setup' '
	REAL="$(pwd)/.real" &&
	mv .shit "$REAL"
'

test_expect_success 'bad setup: invalid .shit file format' '
	echo "shitdir $REAL" >.shit &&
	test_must_fail shit rev-parse 2>.err &&
	test_grep "invalid shitfile format" .err
'

test_expect_success 'bad setup: invalid .shit file path' '
	echo "shitdir: $REAL.not" >.shit &&
	test_must_fail shit rev-parse 2>.err &&
	test_grep "not a shit repository" .err
'

test_expect_success 'final setup + check rev-parse --shit-dir' '
	echo "shitdir: $REAL" >.shit &&
	echo "$REAL" >expect &&
	shit rev-parse --shit-dir >actual &&
	test_cmp expect actual
'

test_expect_success 'check hash-object' '
	echo "foo" >bar &&
	SHA=$(shit hash-object -w --stdin <bar) &&
	test_path_is_file "$REAL/objects/$(objpath $SHA)"
'

test_expect_success 'check cat-file' '
	shit cat-file blob $SHA >actual &&
	test_cmp bar actual
'

test_expect_success 'check update-index' '
	test_path_is_missing "$REAL/index" &&
	rm -f "$REAL/objects/$(objpath $SHA)" &&
	shit update-index --add bar &&
	test_path_is_file "$REAL/index" &&
	test_path_is_file "$REAL/objects/$(objpath $SHA)"
'

test_expect_success 'check write-tree' '
	SHA=$(shit write-tree) &&
	test_path_is_file "$REAL/objects/$(objpath $SHA)"
'

test_expect_success 'check commit-tree' '
	SHA=$(echo "commit bar" | shit commit-tree $SHA) &&
	test_path_is_file "$REAL/objects/$(objpath $SHA)"
'

test_expect_success 'check rev-list' '
	shit update-ref "HEAD" "$SHA" &&
	shit rev-list HEAD >actual &&
	echo $SHA >expected &&
	test_cmp expected actual
'

test_expect_success 'setup_shit_dir twice in subdir' '
	shit init sgd &&
	(
		cd sgd &&
		shit config alias.lsfi ls-files &&
		mv .shit .realshit &&
		echo "shitdir: .realshit" >.shit &&
		mkdir subdir &&
		cd subdir &&
		>foo &&
		shit add foo &&
		shit lsfi >actual &&
		echo foo >expected &&
		test_cmp expected actual
	)
'

test_expect_success 'enter_repo non-strict mode' '
	test_create_repo enter_repo &&
	(
		cd enter_repo &&
		test_tick &&
		test_commit foo &&
		mv .shit .realshit &&
		echo "shitdir: .realshit" >.shit
	) &&
	head=$(shit -C enter_repo rev-parse HEAD) &&
	shit ls-remote enter_repo >actual &&
	cat >expected <<-EOF &&
	$head	HEAD
	$head	refs/heads/main
	$head	refs/tags/foo
	EOF
	test_cmp expected actual
'

test_expect_success 'enter_repo linked checkout' '
	(
		cd enter_repo &&
		shit worktree add  ../foo refs/tags/foo
	) &&
	head=$(shit -C enter_repo rev-parse HEAD) &&
	shit ls-remote foo >actual &&
	cat >expected <<-EOF &&
	$head	HEAD
	$head	refs/heads/main
	$head	refs/tags/foo
	EOF
	test_cmp expected actual
'

test_expect_success 'enter_repo strict mode' '
	head=$(shit -C enter_repo rev-parse HEAD) &&
	shit ls-remote --upload-pack="shit upload-pack --strict" foo/.shit >actual &&
	cat >expected <<-EOF &&
	$head	HEAD
	$head	refs/heads/main
	$head	refs/tags/foo
	EOF
	test_cmp expected actual
'

test_done
