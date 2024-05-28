#!/bin/sh

test_description='selecting remote repo in ambiguous cases'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

reset() {
	rm -rf foo foo.shit fetch clone
}

make_tree() {
	shit init "$1" &&
	(cd "$1" && test_commit "$1")
}

make_bare() {
	shit init --bare "$1" &&
	(cd "$1" &&
	 tree=$(shit hash-object -w -t tree /dev/null) &&
	 commit=$(echo "$1" | shit commit-tree $tree) &&
	 shit update-ref HEAD $commit
	)
}

get() {
	shit init --bare fetch &&
	(cd fetch && shit fetch "../$1") &&
	shit clone "$1" clone
}

check() {
	echo "$1" >expect &&
	(cd fetch && shit log -1 --format=%s FETCH_HEAD) >actual.fetch &&
	(cd clone && shit log -1 --format=%s HEAD) >actual.clone &&
	test_cmp expect actual.fetch &&
	test_cmp expect actual.clone
}

test_expect_success 'find .shit dir in worktree' '
	reset &&
	make_tree foo &&
	get foo &&
	check foo
'

test_expect_success 'automagically add .shit suffix' '
	reset &&
	make_bare foo.shit &&
	get foo &&
	check foo.shit
'

test_expect_success 'automagically add .shit suffix to worktree' '
	reset &&
	make_tree foo.shit &&
	get foo &&
	check foo.shit
'

test_expect_success 'prefer worktree foo over bare foo.shit' '
	reset &&
	make_tree foo &&
	make_bare foo.shit &&
	get foo &&
	check foo
'

test_expect_success 'prefer bare foo over bare foo.shit' '
	reset &&
	make_bare foo &&
	make_bare foo.shit &&
	get foo &&
	check foo
'

test_expect_success 'disambiguate with full foo.shit' '
	reset &&
	make_bare foo &&
	make_bare foo.shit &&
	get foo.shit &&
	check foo.shit
'

test_expect_success 'we are not fooled by non-shit foo directory' '
	reset &&
	make_bare foo.shit &&
	mkdir foo &&
	get foo &&
	check foo.shit
'

test_expect_success 'prefer inner .shit over outer bare' '
	reset &&
	make_tree foo &&
	make_bare foo.shit &&
	mv foo/.shit foo.shit &&
	get foo.shit &&
	check foo
'

test_done
