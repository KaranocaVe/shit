#!/bin/sh
#
# Copyright (c) 2013 Ramkumar Ramachandra
#

test_description='shit rebase --autostash tests'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success setup '
	echo hello-world >file0 &&
	shit add . &&
	test_tick &&
	shit commit -m "initial commit" &&
	shit checkout -b feature-branch &&
	echo another-hello >file1 &&
	echo goodbye >file2 &&
	shit add . &&
	test_tick &&
	shit commit -m "second commit" &&
	echo final-goodbye >file3 &&
	shit add . &&
	test_tick &&
	shit commit -m "third commit" &&
	shit checkout -b unrelated-onto-branch main &&
	echo unrelated >file4 &&
	shit add . &&
	test_tick &&
	shit commit -m "unrelated commit" &&
	shit checkout -b related-onto-branch main &&
	echo conflicting-change >file2 &&
	shit add . &&
	test_tick &&
	shit commit -m "related commit" &&
	remove_progress_re="$(printf "s/.*\\r//")"
'

create_expected_success_apply () {
	cat >expected <<-EOF
	$(grep "^Created autostash: [0-9a-f][0-9a-f]*\$" actual)
	First, rewinding head to replay your work on top of it...
	Applying: second commit
	Applying: third commit
	Applied autostash.
	EOF
}

create_expected_success_merge () {
	q_to_cr >expected <<-EOF
	$(grep "^Created autostash: [0-9a-f][0-9a-f]*\$" actual)
	Applied autostash.
	Successfully rebased and updated refs/heads/rebased-feature-branch.
	EOF
}

create_expected_failure_apply () {
	cat >expected <<-EOF
	$(grep "^Created autostash: [0-9a-f][0-9a-f]*\$" actual)
	First, rewinding head to replay your work on top of it...
	Applying: second commit
	Applying: third commit
	Applying autostash resulted in conflicts.
	Your changes are safe in the stash.
	You can run "shit stash pop" or "shit stash drop" at any time.
	EOF
}

create_expected_failure_merge () {
	cat >expected <<-EOF
	$(grep "^Created autostash: [0-9a-f][0-9a-f]*\$" actual)
	Applying autostash resulted in conflicts.
	Your changes are safe in the stash.
	You can run "shit stash pop" or "shit stash drop" at any time.
	Successfully rebased and updated refs/heads/rebased-feature-branch.
	EOF
}

testrebase () {
	type=$1
	dotest=$2

	test_expect_success "rebase$type: dirty worktree, --no-autostash" '
		test_config rebase.autostash true &&
		shit reset --hard &&
		shit checkout -b rebased-feature-branch feature-branch &&
		test_when_finished shit branch -D rebased-feature-branch &&
		test_when_finished shit checkout feature-branch &&
		echo dirty >>file3 &&
		test_must_fail shit rebase$type --no-autostash unrelated-onto-branch
	'

	test_expect_success "rebase$type: dirty worktree, non-conflicting rebase" '
		test_config rebase.autostash true &&
		shit reset --hard &&
		shit checkout -b rebased-feature-branch feature-branch &&
		echo dirty >>file3 &&
		shit rebase$type unrelated-onto-branch >actual 2>&1 &&
		grep unrelated file4 &&
		grep dirty file3 &&
		shit checkout feature-branch
	'

	test_expect_success "rebase$type --autostash: check output" '
		test_when_finished shit branch -D rebased-feature-branch &&
		suffix=${type#\ --} && suffix=${suffix:-apply} &&
		if test ${suffix} = "interactive"; then
			suffix=merge
		fi &&
		create_expected_success_$suffix &&
		sed "$remove_progress_re" <actual >actual2 &&
		test_cmp expected actual2
	'

	test_expect_success "rebase$type: dirty index, non-conflicting rebase" '
		test_config rebase.autostash true &&
		shit reset --hard &&
		shit checkout -b rebased-feature-branch feature-branch &&
		test_when_finished shit branch -D rebased-feature-branch &&
		echo dirty >>file3 &&
		shit add file3 &&
		shit rebase$type unrelated-onto-branch &&
		grep unrelated file4 &&
		grep dirty file3 &&
		shit checkout feature-branch
	'

	test_expect_success "rebase$type: conflicting rebase" '
		test_config rebase.autostash true &&
		shit reset --hard &&
		shit checkout -b rebased-feature-branch feature-branch &&
		test_when_finished shit branch -D rebased-feature-branch &&
		echo dirty >>file3 &&
		test_must_fail shit rebase$type related-onto-branch &&
		test_path_is_file $dotest/autostash &&
		test_path_is_missing file3 &&
		rm -rf $dotest &&
		shit reset --hard &&
		shit checkout feature-branch
	'

	test_expect_success "rebase$type: --continue" '
		test_config rebase.autostash true &&
		shit reset --hard &&
		shit checkout -b rebased-feature-branch feature-branch &&
		test_when_finished shit branch -D rebased-feature-branch &&
		echo dirty >>file3 &&
		test_must_fail shit rebase$type related-onto-branch &&
		test_path_is_file $dotest/autostash &&
		test_path_is_missing file3 &&
		echo "conflicting-plus-goodbye" >file2 &&
		shit add file2 &&
		shit rebase --continue &&
		test_path_is_missing $dotest/autostash &&
		grep dirty file3 &&
		shit checkout feature-branch
	'

	test_expect_success "rebase$type: --skip" '
		test_config rebase.autostash true &&
		shit reset --hard &&
		shit checkout -b rebased-feature-branch feature-branch &&
		test_when_finished shit branch -D rebased-feature-branch &&
		echo dirty >>file3 &&
		test_must_fail shit rebase$type related-onto-branch &&
		test_path_is_file $dotest/autostash &&
		test_path_is_missing file3 &&
		shit rebase --skip &&
		test_path_is_missing $dotest/autostash &&
		grep dirty file3 &&
		shit checkout feature-branch
	'

	test_expect_success "rebase$type: --abort" '
		test_config rebase.autostash true &&
		shit reset --hard &&
		shit checkout -b rebased-feature-branch feature-branch &&
		test_when_finished shit branch -D rebased-feature-branch &&
		echo dirty >>file3 &&
		test_must_fail shit rebase$type related-onto-branch &&
		test_path_is_file $dotest/autostash &&
		test_path_is_missing file3 &&
		shit rebase --abort &&
		test_path_is_missing $dotest/autostash &&
		grep dirty file3 &&
		shit checkout feature-branch
	'

	test_expect_success "rebase$type: --quit" '
		test_config rebase.autostash true &&
		shit reset --hard &&
		shit checkout -b rebased-feature-branch feature-branch &&
		test_when_finished shit branch -D rebased-feature-branch &&
		echo dirty >>file3 &&
		shit diff >expect &&
		test_must_fail shit rebase$type related-onto-branch &&
		test_path_is_file $dotest/autostash &&
		test_path_is_missing file3 &&
		shit rebase --quit &&
		test_when_finished shit stash drop &&
		test_path_is_missing $dotest/autostash &&
		! grep dirty file3 &&
		shit stash show -p >actual &&
		test_cmp expect actual &&
		shit reset --hard &&
		shit checkout feature-branch
	'

	test_expect_success "rebase$type: non-conflicting rebase, conflicting stash" '
		test_config rebase.autostash true &&
		shit reset --hard &&
		shit checkout -b rebased-feature-branch feature-branch &&
		echo dirty >file4 &&
		shit add file4 &&
		shit rebase$type unrelated-onto-branch >actual 2>&1 &&
		test_path_is_missing $dotest &&
		shit reset --hard &&
		grep unrelated file4 &&
		! grep dirty file4 &&
		shit checkout feature-branch &&
		shit stash pop &&
		grep dirty file4
	'

	test_expect_success "rebase$type: check output with conflicting stash" '
		test_when_finished shit branch -D rebased-feature-branch &&
		suffix=${type#\ --} && suffix=${suffix:-apply} &&
		if test ${suffix} = "interactive"; then
			suffix=merge
		fi &&
		create_expected_failure_$suffix &&
		sed "$remove_progress_re" <actual >actual2 &&
		test_cmp expected actual2
	'
}

test_expect_success "rebase: fast-forward rebase" '
	test_config rebase.autostash true &&
	shit reset --hard &&
	shit checkout -b behind-feature-branch feature-branch~1 &&
	test_when_finished shit branch -D behind-feature-branch &&
	echo dirty >>file1 &&
	shit rebase feature-branch &&
	grep dirty file1 &&
	shit checkout feature-branch
'

test_expect_success "rebase: noop rebase" '
	test_config rebase.autostash true &&
	shit reset --hard &&
	shit checkout -b same-feature-branch feature-branch &&
	test_when_finished shit branch -D same-feature-branch &&
	echo dirty >>file1 &&
	shit rebase feature-branch &&
	grep dirty file1 &&
	shit checkout feature-branch
'

testrebase " --apply" .shit/rebase-apply
testrebase " --merge" .shit/rebase-merge
testrebase " --interactive" .shit/rebase-merge

test_expect_success 'abort rebase -i with --autostash' '
	test_when_finished "shit reset --hard" &&
	echo uncommitted-content >file0 &&
	(
		write_script abort-editor.sh <<-\EOF &&
			echo >"$1"
		EOF
		test_set_editor "$(pwd)/abort-editor.sh" &&
		test_must_fail shit rebase -i --autostash HEAD^ &&
		rm -f abort-editor.sh
	) &&
	echo uncommitted-content >expected &&
	test_cmp expected file0
'

test_expect_success 'restore autostash on editor failure' '
	test_when_finished "shit reset --hard" &&
	echo uncommitted-content >file0 &&
	(
		test_set_editor "false" &&
		test_must_fail shit rebase -i --autostash HEAD^
	) &&
	echo uncommitted-content >expected &&
	test_cmp expected file0
'

test_expect_success 'autostash is saved on editor failure with conflict' '
	test_when_finished "shit reset --hard" &&
	echo uncommitted-content >file0 &&
	(
		write_script abort-editor.sh <<-\EOF &&
			echo conflicting-content >file0
			exit 1
		EOF
		test_set_editor "$(pwd)/abort-editor.sh" &&
		test_must_fail shit rebase -i --autostash HEAD^ &&
		rm -f abort-editor.sh
	) &&
	echo conflicting-content >expected &&
	test_cmp expected file0 &&
	shit checkout file0 &&
	shit stash pop &&
	echo uncommitted-content >expected &&
	test_cmp expected file0
'

test_expect_success 'autostash with dirty submodules' '
	test_when_finished "shit reset --hard && shit checkout main" &&
	shit checkout -b with-submodule &&
	shit -c protocol.file.allow=always submodule add ./ sub &&
	test_tick &&
	shit commit -m add-submodule &&
	echo changed >sub/file0 &&
	shit rebase -i --autostash HEAD
'

test_expect_success 'branch is left alone when possible' '
	shit checkout -b unchanged-branch &&
	echo changed >file0 &&
	shit rebase --autostash unchanged-branch &&
	test changed = "$(cat file0)" &&
	test unchanged-branch = "$(shit rev-parse --abbrev-ref HEAD)"
'

test_expect_success 'never change active branch' '
	shit checkout -b not-the-feature-branch unrelated-onto-branch &&
	test_when_finished "shit reset --hard && shit checkout main" &&
	echo changed >file0 &&
	shit rebase --autostash not-the-feature-branch feature-branch &&
	test_cmp_rev not-the-feature-branch unrelated-onto-branch
'

test_expect_success 'autostash commit is marked as reachable' '
	echo changed >file0 &&
	shit rebase --autostash --exec "shit prune --expire=now" \
		feature-branch^ feature-branch &&
	# shit rebase succeeds if the stash cannot be applied so we need to check
	# the contents of file0
	echo changed >expect &&
	test_cmp expect file0
'

test_done
