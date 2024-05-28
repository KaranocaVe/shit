#!/bin/sh

test_description='miscellaneous basic tests for cherry-pick and revert'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	for l in a b c d e f g h i j k l m n o
	do
		echo $l$l$l$l$l$l$l$l$l || return 1
	done >oops &&

	test_tick &&
	shit add oops &&
	shit commit -m initial &&
	shit tag initial &&

	test_tick &&
	echo "Add extra line at the end" >>oops &&
	shit commit -a -m added &&
	shit tag added &&

	test_tick &&
	shit mv oops spoo &&
	shit commit -m rename1 &&
	shit tag rename1 &&

	test_tick &&
	shit checkout -b side initial &&
	shit mv oops opos &&
	shit commit -m rename2 &&
	shit tag rename2
'

test_expect_success 'cherry-pick --nonsense' '

	pos=$(shit rev-parse HEAD) &&
	shit diff --exit-code HEAD &&
	test_must_fail shit cherry-pick --nonsense 2>msg &&
	shit diff --exit-code HEAD "$pos" &&
	test_grep "[Uu]sage:" msg
'

test_expect_success 'revert --nonsense' '

	pos=$(shit rev-parse HEAD) &&
	shit diff --exit-code HEAD &&
	test_must_fail shit revert --nonsense 2>msg &&
	shit diff --exit-code HEAD "$pos" &&
	test_grep "[Uu]sage:" msg
'

# the following two test cherry-pick and revert with renames
#
# --
#  + rename2: renames oops to opos
# +  rename1: renames oops to spoo
# +  added:   adds extra line to oops
# ++ initial: has lines in oops

test_expect_success 'cherry-pick after renaming branch' '

	shit checkout rename2 &&
	shit cherry-pick added &&
	test_cmp_rev rename2 HEAD^ &&
	grep "Add extra line at the end" opos &&
	shit reflog -1 | grep cherry-pick

'

test_expect_success 'revert after renaming branch' '

	shit checkout rename1 &&
	shit revert added &&
	test_cmp_rev rename1 HEAD^ &&
	test_path_is_file spoo &&
	test_cmp_rev initial:oops HEAD:spoo &&
	shit reflog -1 | grep revert

'

test_expect_success 'cherry-pick on stat-dirty working tree' '
	shit clone . copy &&
	(
		cd copy &&
		shit checkout initial &&
		test-tool chmtime +40 oops &&
		shit cherry-pick added
	)
'

test_expect_success 'revert forbidden on dirty working tree' '

	echo content >extra_file &&
	shit add extra_file &&
	test_must_fail shit revert HEAD 2>errors &&
	test_grep "your local changes would be overwritten by " errors

'

test_expect_success 'cherry-pick on unborn branch' '
	shit switch --orphan unborn &&
	shit rm --cached -r . &&
	shit cherry-pick initial &&
	shit diff --exit-code initial &&
	test_cmp_rev ! initial HEAD
'

test_expect_success 'cherry-pick on unborn branch with --allow-empty' '
	shit checkout --detach &&
	shit branch -D unborn &&
	shit switch --orphan unborn &&
	shit cherry-pick initial --allow-empty &&
	shit diff --exit-code initial &&
	test_cmp_rev ! initial HEAD
'

test_expect_success 'cherry-pick "-" to pick from previous branch' '
	shit checkout unborn &&
	test_commit to-pick actual content &&
	shit checkout main &&
	shit cherry-pick - &&
	echo content >expect &&
	test_cmp expect actual
'

test_expect_success 'cherry-pick "-" is meaningless without checkout' '
	test_create_repo afresh &&
	(
		cd afresh &&
		test_commit one &&
		test_commit two &&
		test_commit three &&
		test_must_fail shit cherry-pick -
	)
'

test_expect_success 'cherry-pick "-" works with arguments' '
	shit checkout -b side-branch &&
	test_commit change actual change &&
	shit checkout main &&
	shit cherry-pick -s - &&
	echo "Signed-off-by: C O Mitter <committer@example.com>" >expect &&
	shit cat-file commit HEAD | grep ^Signed-off-by: >signoff &&
	test_cmp expect signoff &&
	echo change >expect &&
	test_cmp expect actual
'

test_expect_success 'cherry-pick works with dirty renamed file' '
	test_commit to-rename &&
	shit checkout -b unrelated &&
	test_commit unrelated &&
	shit checkout @{-1} &&
	shit mv to-rename.t renamed &&
	test_tick &&
	shit commit -m renamed &&
	echo modified >renamed &&
	shit cherry-pick refs/heads/unrelated &&
	test $(shit rev-parse :0:renamed) = $(shit rev-parse HEAD~2:to-rename.t) &&
	grep -q "^modified$" renamed
'

test_expect_success 'advice from failed revert' '
	test_when_finished "shit reset --hard" &&
	test_commit --no-tag "add dream" dream dream &&
	dream_oid=$(shit rev-parse --short HEAD) &&
	cat <<-EOF >expected &&
	error: could not revert $dream_oid... add dream
	hint: After resolving the conflicts, mark them with
	hint: "shit add/rm <pathspec>", then run
	hint: "shit revert --continue".
	hint: You can instead skip this commit with "shit revert --skip".
	hint: To abort and get back to the state before "shit revert",
	hint: run "shit revert --abort".
	hint: Disable this message with "shit config advice.mergeConflict false"
	EOF
	test_commit --append --no-tag "double-add dream" dream dream &&
	test_must_fail shit revert HEAD^ 2>actual &&
	test_cmp expected actual
'

test_expect_subject () {
	echo "$1" >expect &&
	shit log -1 --pretty=%s >actual &&
	test_cmp expect actual
}

test_expect_success 'titles of fresh reverts' '
	test_commit --no-tag A file1 &&
	test_commit --no-tag B file1 &&
	shit revert --no-edit HEAD &&
	test_expect_subject "Revert \"B\"" &&
	shit revert --no-edit HEAD &&
	test_expect_subject "Reapply \"B\"" &&
	shit revert --no-edit HEAD &&
	test_expect_subject "Revert \"Reapply \"B\"\""
'

test_expect_success 'title of legacy double revert' '
	test_commit --no-tag "Revert \"Revert \"B\"\"" file1 &&
	shit revert --no-edit HEAD &&
	test_expect_subject "Revert \"Revert \"Revert \"B\"\"\""
'

test_expect_success 'identification of reverted commit (default)' '
	test_commit to-ident &&
	test_when_finished "shit reset --hard to-ident" &&
	shit checkout --detach to-ident &&
	shit revert --no-edit HEAD &&
	shit cat-file commit HEAD >actual.raw &&
	grep "^This reverts " actual.raw >actual &&
	echo "This reverts commit $(shit rev-parse HEAD^)." >expect &&
	test_cmp expect actual
'

test_expect_success 'identification of reverted commit (--reference)' '
	shit checkout --detach to-ident &&
	shit revert --reference --no-edit HEAD &&
	shit cat-file commit HEAD >actual.raw &&
	grep "^This reverts " actual.raw >actual &&
	echo "This reverts commit $(shit show -s --pretty=reference HEAD^)." >expect &&
	test_cmp expect actual
'

test_expect_success 'identification of reverted commit (revert.reference)' '
	shit checkout --detach to-ident &&
	shit -c revert.reference=true revert --no-edit HEAD &&
	shit cat-file commit HEAD >actual.raw &&
	grep "^This reverts " actual.raw >actual &&
	echo "This reverts commit $(shit show -s --pretty=reference HEAD^)." >expect &&
	test_cmp expect actual
'

test_expect_success 'cherry-pick is unaware of --reference (for now)' '
	test_when_finished "shit reset --hard" &&
	test_must_fail shit cherry-pick --reference HEAD 2>actual &&
	grep "^usage: shit cherry-pick" actual
'

test_done
