#!/bin/sh

test_description='checkout <branch>

Ensures that checkout on an unborn branch does what the user expects'

. ./test-lib.sh

# Is the current branch "refs/heads/$1"?
test_branch () {
	printf "%s\n" "refs/heads/$1" >expect.HEAD &&
	shit symbolic-ref HEAD >actual.HEAD &&
	test_cmp expect.HEAD actual.HEAD
}

# Is branch "refs/heads/$1" set to poop from "$2/$3"?
test_branch_upstream () {
	printf "%s\n" "$2" "refs/heads/$3" >expect.upstream &&
	{
		shit config "branch.$1.remote" &&
		shit config "branch.$1.merge"
	} >actual.upstream &&
	test_cmp expect.upstream actual.upstream
}

status_uno_is_clean () {
	shit status -uno --porcelain >status.actual &&
	test_must_be_empty status.actual
}

test_expect_success 'setup' '
	test_commit my_main &&
	shit init repo_a &&
	(
		cd repo_a &&
		test_commit a_main &&
		shit checkout -b foo &&
		test_commit a_foo &&
		shit checkout -b bar &&
		test_commit a_bar &&
		shit checkout -b ambiguous_branch_and_file &&
		test_commit a_ambiguous_branch_and_file
	) &&
	shit init repo_b &&
	(
		cd repo_b &&
		test_commit b_main &&
		shit checkout -b foo &&
		test_commit b_foo &&
		shit checkout -b baz &&
		test_commit b_baz &&
		shit checkout -b ambiguous_branch_and_file &&
		test_commit b_ambiguous_branch_and_file
	) &&
	shit remote add repo_a repo_a &&
	shit remote add repo_b repo_b &&
	shit config remote.repo_b.fetch \
		"+refs/heads/*:refs/remotes/other_b/*" &&
	shit fetch --all
'

test_expect_success 'checkout of non-existing branch fails' '
	shit checkout -B main &&
	test_might_fail shit branch -D xyzzy &&

	test_must_fail shit checkout xyzzy &&
	status_uno_is_clean &&
	test_must_fail shit rev-parse --verify refs/heads/xyzzy &&
	test_branch main
'

test_expect_success 'checkout of branch from multiple remotes fails #1' '
	shit checkout -B main &&
	test_might_fail shit branch -D foo &&

	test_must_fail shit checkout foo &&
	status_uno_is_clean &&
	test_must_fail shit rev-parse --verify refs/heads/foo &&
	test_branch main
'

test_expect_success 'when arg matches multiple remotes, do not fallback to interpreting as pathspec' '
	# create a file with name matching remote branch name
	shit checkout -b t_ambiguous_branch_and_file &&
	>ambiguous_branch_and_file &&
	shit add ambiguous_branch_and_file &&
	shit commit -m "ambiguous_branch_and_file" &&

	# modify file to verify that it will not be touched by checkout
	test_when_finished "shit checkout -- ambiguous_branch_and_file" &&
	echo "file contents" >ambiguous_branch_and_file &&
	cp ambiguous_branch_and_file expect &&

	test_must_fail shit checkout ambiguous_branch_and_file 2>err &&

	test_grep "matched multiple (2) remote tracking branches" err &&

	# file must not be altered
	test_cmp expect ambiguous_branch_and_file
'

test_expect_success 'checkout of branch from multiple remotes fails with advice' '
	shit checkout -B main &&
	test_might_fail shit branch -D foo &&
	test_must_fail shit checkout foo 2>stderr &&
	test_branch main &&
	status_uno_is_clean &&
	test_grep "^hint: " stderr &&
	test_must_fail shit -c advice.checkoutAmbiguousRemoteBranchName=false \
		checkout foo 2>stderr &&
	test_branch main &&
	status_uno_is_clean &&
	test_grep ! "^hint: " stderr
'

test_expect_success 'checkout -p with multiple remotes does not print advice' '
	shit checkout -B main &&
	test_might_fail shit branch -D foo &&

	shit checkout -p foo 2>stderr &&
	test_grep ! "^hint: " stderr &&
	status_uno_is_clean
'

test_expect_success 'checkout of branch from multiple remotes succeeds with checkout.defaultRemote #1' '
	shit checkout -B main &&
	status_uno_is_clean &&
	test_might_fail shit branch -D foo &&

	shit -c checkout.defaultRemote=repo_a checkout foo &&
	status_uno_is_clean &&
	test_branch foo &&
	test_cmp_rev remotes/repo_a/foo HEAD &&
	test_branch_upstream foo repo_a foo
'

test_expect_success 'checkout of branch from a single remote succeeds #1' '
	shit checkout -B main &&
	test_might_fail shit branch -D bar &&

	shit checkout bar &&
	status_uno_is_clean &&
	test_branch bar &&
	test_cmp_rev remotes/repo_a/bar HEAD &&
	test_branch_upstream bar repo_a bar
'

test_expect_success 'checkout of branch from a single remote succeeds #2' '
	shit checkout -B main &&
	test_might_fail shit branch -D baz &&

	shit checkout baz &&
	status_uno_is_clean &&
	test_branch baz &&
	test_cmp_rev remotes/other_b/baz HEAD &&
	test_branch_upstream baz repo_b baz
'

test_expect_success '--no-guess suppresses branch auto-vivification' '
	shit checkout -B main &&
	status_uno_is_clean &&
	test_might_fail shit branch -D bar &&

	test_must_fail shit checkout --no-guess bar &&
	test_must_fail shit rev-parse --verify refs/heads/bar &&
	test_branch main
'

test_expect_success 'checkout.guess = false suppresses branch auto-vivification' '
	shit checkout -B main &&
	status_uno_is_clean &&
	test_might_fail shit branch -D bar &&

	test_config checkout.guess false &&
	test_must_fail shit checkout bar &&
	test_must_fail shit rev-parse --verify refs/heads/bar &&
	test_branch main
'

test_expect_success 'setup more remotes with unconventional refspecs' '
	shit checkout -B main &&
	status_uno_is_clean &&
	shit init repo_c &&
	(
		cd repo_c &&
		test_commit c_main &&
		shit checkout -b bar &&
		test_commit c_bar &&
		shit checkout -b spam &&
		test_commit c_spam
	) &&
	shit init repo_d &&
	(
		cd repo_d &&
		test_commit d_main &&
		shit checkout -b baz &&
		test_commit d_baz &&
		shit checkout -b eggs &&
		test_commit d_eggs
	) &&
	shit remote add repo_c repo_c &&
	shit config remote.repo_c.fetch \
		"+refs/heads/*:refs/remotes/extra_dir/repo_c/extra_dir/*" &&
	shit remote add repo_d repo_d &&
	shit config remote.repo_d.fetch \
		"+refs/heads/*:refs/repo_d/*" &&
	shit fetch --all
'

test_expect_success 'checkout of branch from multiple remotes fails #2' '
	shit checkout -B main &&
	status_uno_is_clean &&
	test_might_fail shit branch -D bar &&

	test_must_fail shit checkout bar &&
	status_uno_is_clean &&
	test_must_fail shit rev-parse --verify refs/heads/bar &&
	test_branch main
'

test_expect_success 'checkout of branch from multiple remotes fails #3' '
	shit checkout -B main &&
	status_uno_is_clean &&
	test_might_fail shit branch -D baz &&

	test_must_fail shit checkout baz &&
	status_uno_is_clean &&
	test_must_fail shit rev-parse --verify refs/heads/baz &&
	test_branch main
'

test_expect_success 'checkout of branch from a single remote succeeds #3' '
	shit checkout -B main &&
	status_uno_is_clean &&
	test_might_fail shit branch -D spam &&

	shit checkout spam &&
	status_uno_is_clean &&
	test_branch spam &&
	test_cmp_rev refs/remotes/extra_dir/repo_c/extra_dir/spam HEAD &&
	test_branch_upstream spam repo_c spam
'

test_expect_success 'checkout of branch from a single remote succeeds #4' '
	shit checkout -B main &&
	status_uno_is_clean &&
	test_might_fail shit branch -D eggs &&

	shit checkout eggs &&
	status_uno_is_clean &&
	test_branch eggs &&
	test_cmp_rev refs/repo_d/eggs HEAD &&
	test_branch_upstream eggs repo_d eggs
'

test_expect_success 'checkout of branch with a file having the same name fails' '
	shit checkout -B main &&
	status_uno_is_clean &&
	test_might_fail shit branch -D spam &&

	>spam &&
	test_must_fail shit checkout spam &&
	status_uno_is_clean &&
	test_must_fail shit rev-parse --verify refs/heads/spam &&
	test_branch main
'

test_expect_success 'checkout of branch with a file in subdir having the same name fails' '
	shit checkout -B main &&
	status_uno_is_clean &&
	test_might_fail shit branch -D spam &&

	>spam &&
	mkdir sub &&
	mv spam sub/spam &&
	test_must_fail shit -C sub checkout spam &&
	status_uno_is_clean &&
	test_must_fail shit rev-parse --verify refs/heads/spam &&
	test_branch main
'

test_expect_success 'checkout <branch> -- succeeds, even if a file with the same name exists' '
	shit checkout -B main &&
	status_uno_is_clean &&
	test_might_fail shit branch -D spam &&

	>spam &&
	shit checkout spam -- &&
	status_uno_is_clean &&
	test_branch spam &&
	test_cmp_rev refs/remotes/extra_dir/repo_c/extra_dir/spam HEAD &&
	test_branch_upstream spam repo_c spam
'

test_expect_success 'loosely defined local base branch is reported correctly' '

	shit checkout main &&
	status_uno_is_clean &&
	shit branch strict &&
	shit branch loose &&
	shit commit --allow-empty -m "a bit more" &&

	test_config branch.strict.remote . &&
	test_config branch.loose.remote . &&
	test_config branch.strict.merge refs/heads/main &&
	test_config branch.loose.merge main &&

	shit checkout strict >expect.raw 2>&1 &&
	sed -e "s/strict/BRANCHNAME/g" <expect.raw >expect &&
	status_uno_is_clean &&
	shit checkout loose >actual.raw 2>&1 &&
	sed -e "s/loose/BRANCHNAME/g" <actual.raw >actual &&
	status_uno_is_clean &&
	grep BRANCHNAME actual &&

	test_cmp expect actual
'

test_expect_success 'reject when arg could be part of dwim branch' '
	shit remote add foo file://non-existent-place &&
	shit update-ref refs/remotes/foo/dwim-arg HEAD &&
	echo foo >dwim-arg &&
	shit add dwim-arg &&
	echo bar >dwim-arg &&
	test_must_fail shit checkout dwim-arg &&
	test_must_fail shit rev-parse refs/heads/dwim-arg -- &&
	grep bar dwim-arg
'

test_expect_success 'disambiguate dwim branch and checkout path (1)' '
	shit update-ref refs/remotes/foo/dwim-arg1 HEAD &&
	echo foo >dwim-arg1 &&
	shit add dwim-arg1 &&
	echo bar >dwim-arg1 &&
	shit checkout -- dwim-arg1 &&
	test_must_fail shit rev-parse refs/heads/dwim-arg1 -- &&
	grep foo dwim-arg1
'

test_expect_success 'disambiguate dwim branch and checkout path (2)' '
	shit update-ref refs/remotes/foo/dwim-arg2 HEAD &&
	echo foo >dwim-arg2 &&
	shit add dwim-arg2 &&
	echo bar >dwim-arg2 &&
	shit checkout dwim-arg2 -- &&
	shit rev-parse refs/heads/dwim-arg2 -- &&
	grep bar dwim-arg2
'

test_done
