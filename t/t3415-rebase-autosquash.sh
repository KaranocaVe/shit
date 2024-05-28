#!/bin/sh

test_description='auto squash'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

. "$TEST_DIRECTORY"/lib-rebase.sh

test_expect_success setup '
	echo 0 >file0 &&
	shit add . &&
	test_tick &&
	shit commit -m "initial commit" &&
	echo 0 >file1 &&
	echo 2 >file2 &&
	shit add . &&
	test_tick &&
	shit commit -m "first commit" &&
	shit tag first-commit &&
	echo 3 >file3 &&
	shit add . &&
	test_tick &&
	shit commit -m "second commit" &&
	shit tag base
'

test_auto_fixup () {
	no_squash= &&
	if test "x$1" = 'x!'
	then
		no_squash=true
		shift
	fi &&

	shit reset --hard base &&
	echo 1 >file1 &&
	shit add -u &&
	test_tick &&
	shit commit -m "fixup! first" &&

	shit tag $1 &&
	test_tick &&
	shit rebase $2 HEAD^^^ &&
	shit log --oneline >actual &&
	if test -n "$no_squash"
	then
		test_line_count = 4 actual
	else
		test_line_count = 3 actual &&
		shit diff --exit-code $1 &&
		echo 1 >expect &&
		shit cat-file blob HEAD^:file1 >actual &&
		test_cmp expect actual &&
		shit cat-file commit HEAD^ >commit &&
		grep first commit >actual &&
		test_line_count = 1 actual
	fi
}

test_expect_success 'auto fixup (option)' '
	test_auto_fixup fixup-option --autosquash &&
	test_auto_fixup fixup-option-i "--autosquash -i"
'

test_expect_success 'auto fixup (config true)' '
	shit config rebase.autosquash true &&
	test_auto_fixup ! fixup-config-true &&
	test_auto_fixup fixup-config-true-i -i &&
	test_auto_fixup ! fixup-config-true-no --no-autosquash &&
	test_auto_fixup ! fixup-config-true-i-no "-i --no-autosquash"
'

test_expect_success 'auto fixup (config false)' '
	shit config rebase.autosquash false &&
	test_auto_fixup ! fixup-config-false &&
	test_auto_fixup ! fixup-config-false-i -i &&
	test_auto_fixup fixup-config-false-yes --autosquash &&
	test_auto_fixup fixup-config-false-i-yes "-i --autosquash"
'

test_auto_squash () {
	no_squash= &&
	if test "x$1" = 'x!'
	then
		no_squash=true
		shift
	fi &&

	shit reset --hard base &&
	echo 1 >file1 &&
	shit add -u &&
	test_tick &&
	shit commit -m "squash! first" -m "extra para for first" &&
	shit tag $1 &&
	test_tick &&
	shit rebase $2 HEAD^^^ &&
	shit log --oneline >actual &&
	if test -n "$no_squash"
	then
		test_line_count = 4 actual
	else
		test_line_count = 3 actual &&
		shit diff --exit-code $1 &&
		echo 1 >expect &&
		shit cat-file blob HEAD^:file1 >actual &&
		test_cmp expect actual &&
		shit cat-file commit HEAD^ >commit &&
		grep first commit >actual &&
		test_line_count = 2 actual
	fi
}

test_expect_success 'auto squash (option)' '
	test_auto_squash squash-option --autosquash &&
	test_auto_squash squash-option-i "--autosquash -i"
'

test_expect_success 'auto squash (config true)' '
	shit config rebase.autosquash true &&
	test_auto_squash ! squash-config-true &&
	test_auto_squash squash-config-true-i -i &&
	test_auto_squash ! squash-config-true-no --no-autosquash &&
	test_auto_squash ! squash-config-true-i-no "-i --no-autosquash"
'

test_expect_success 'auto squash (config false)' '
	shit config rebase.autosquash false &&
	test_auto_squash ! squash-config-false &&
	test_auto_squash ! squash-config-false-i -i &&
	test_auto_squash squash-config-false-yes --autosquash &&
	test_auto_squash squash-config-false-i-yes "-i --autosquash"
'

test_expect_success 'misspelled auto squash' '
	shit reset --hard base &&
	echo 1 >file1 &&
	shit add -u &&
	test_tick &&
	shit commit -m "squash! forst" &&
	shit tag final-missquash &&
	test_tick &&
	shit rebase --autosquash -i HEAD^^^ &&
	shit log --oneline >actual &&
	test_line_count = 4 actual &&
	shit diff --exit-code final-missquash &&
	shit rev-list final-missquash...HEAD >list &&
	test_must_be_empty list
'

test_expect_success 'auto squash that matches 2 commits' '
	shit reset --hard base &&
	echo 4 >file4 &&
	shit add file4 &&
	test_tick &&
	shit commit -m "first new commit" &&
	echo 1 >file1 &&
	shit add -u &&
	test_tick &&
	shit commit -m "squash! first" -m "extra para for first" &&
	shit tag final-multisquash &&
	test_tick &&
	shit rebase --autosquash -i HEAD~4 &&
	shit log --oneline >actual &&
	test_line_count = 4 actual &&
	shit diff --exit-code final-multisquash &&
	echo 1 >expect &&
	shit cat-file blob HEAD^^:file1 >actual &&
	test_cmp expect actual &&
	shit cat-file commit HEAD^^ >commit &&
	grep first commit >actual &&
	test_line_count = 2 actual &&
	shit cat-file commit HEAD >commit &&
	grep first commit >actual &&
	test_line_count = 1 actual
'

test_expect_success 'auto squash that matches a commit after the squash' '
	shit reset --hard base &&
	echo 1 >file1 &&
	shit add -u &&
	test_tick &&
	shit commit -m "squash! third" &&
	echo 4 >file4 &&
	shit add file4 &&
	test_tick &&
	shit commit -m "third commit" &&
	shit tag final-presquash &&
	test_tick &&
	shit rebase --autosquash -i HEAD~4 &&
	shit log --oneline >actual &&
	test_line_count = 5 actual &&
	shit diff --exit-code final-presquash &&
	echo 0 >expect &&
	shit cat-file blob HEAD^^:file1 >actual &&
	test_cmp expect actual &&
	echo 1 >expect &&
	shit cat-file blob HEAD^:file1 >actual &&
	test_cmp expect actual &&
	shit cat-file commit HEAD >commit &&
	grep third commit >actual &&
	test_line_count = 1 actual &&
	shit cat-file commit HEAD^ >commit &&
	grep third commit >actual &&
	test_line_count = 1 actual
'
test_expect_success 'auto squash that matches a sha1' '
	shit reset --hard base &&
	echo 1 >file1 &&
	shit add -u &&
	test_tick &&
	oid=$(shit rev-parse --short HEAD^) &&
	shit commit -m "squash! $oid" -m "extra para" &&
	shit tag final-shasquash &&
	test_tick &&
	shit rebase --autosquash -i HEAD^^^ &&
	shit log --oneline >actual &&
	test_line_count = 3 actual &&
	shit diff --exit-code final-shasquash &&
	echo 1 >expect &&
	shit cat-file blob HEAD^:file1 >actual &&
	test_cmp expect actual &&
	shit cat-file commit HEAD^ >commit &&
	! grep "squash" commit &&
	grep "^extra para" commit >actual &&
	test_line_count = 1 actual
'

test_expect_success 'auto squash that matches longer sha1' '
	shit reset --hard base &&
	echo 1 >file1 &&
	shit add -u &&
	test_tick &&
	oid=$(shit rev-parse --short=11 HEAD^) &&
	shit commit -m "squash! $oid" -m "extra para" &&
	shit tag final-longshasquash &&
	test_tick &&
	shit rebase --autosquash -i HEAD^^^ &&
	shit log --oneline >actual &&
	test_line_count = 3 actual &&
	shit diff --exit-code final-longshasquash &&
	echo 1 >expect &&
	shit cat-file blob HEAD^:file1 >actual &&
	test_cmp expect actual &&
	shit cat-file commit HEAD^ >commit &&
	! grep "squash" commit &&
	grep "^extra para" commit >actual &&
	test_line_count = 1 actual
'

test_expect_success 'auto squash of fixup commit that matches branch name which points back to fixup commit' '
	shit reset --hard base &&
	shit commit --allow-empty -m "fixup! self-cycle" &&
	shit branch self-cycle &&
	shit_SEQUENCE_EDITOR="cat >tmp" shit rebase --autosquash -i HEAD^^ &&
	sed -ne "/^[^#]/{s/[0-9a-f]\{7,\}/HASH/g;p;}" tmp >actual &&
	cat <<-EOF >expect &&
	pick HASH second commit
	pick HASH fixup! self-cycle # empty
	EOF
	test_cmp expect actual
'

test_auto_commit_flags () {
	shit reset --hard base &&
	echo 1 >file1 &&
	shit add -u &&
	test_tick &&
	shit commit --$1 first-commit -m "extra para for first" &&
	shit tag final-commit-$1 &&
	test_tick &&
	shit rebase --autosquash -i HEAD^^^ &&
	shit log --oneline >actual &&
	test_line_count = 3 actual &&
	shit diff --exit-code final-commit-$1 &&
	echo 1 >expect &&
	shit cat-file blob HEAD^:file1 >actual &&
	test_cmp expect actual &&
	shit cat-file commit HEAD^ >commit &&
	grep first commit >actual &&
	test_line_count = $2 actual
}

test_expect_success 'use commit --fixup' '
	test_auto_commit_flags fixup 1
'

test_expect_success 'use commit --squash' '
	test_auto_commit_flags squash 2
'

test_auto_fixup_fixup () {
	shit reset --hard base &&
	echo 1 >file1 &&
	shit add -u &&
	test_tick &&
	shit commit -m "$1! first" -m "extra para for first" &&
	echo 2 >file1 &&
	shit add -u &&
	test_tick &&
	shit commit -m "$1! $2! first" -m "second extra para for first" &&
	shit tag "final-$1-$2" &&
	test_tick &&
	(
		set_cat_todo_editor &&
		test_must_fail shit rebase --autosquash -i HEAD^^^^ >actual &&
		head=$(shit rev-parse --short HEAD) &&
		parent1=$(shit rev-parse --short HEAD^) &&
		parent2=$(shit rev-parse --short HEAD^^) &&
		parent3=$(shit rev-parse --short HEAD^^^) &&
		cat >expected <<-EOF &&
		pick $parent3 first commit
		$1 $parent1 $1! first
		$1 $head $1! $2! first
		pick $parent2 second commit
		EOF
		test_cmp expected actual
	) &&
	shit rebase --autosquash -i HEAD^^^^ &&
	shit log --oneline >actual &&
	test_line_count = 3 actual
	shit diff --exit-code "final-$1-$2" &&
	echo 2 >expect &&
	shit cat-file blob HEAD^:file1 >actual &&
	test_cmp expect actual &&
	shit cat-file commit HEAD^ >commit &&
	grep first commit >actual &&
	if test "$1" = "fixup"
	then
		test_line_count = 1 actual
	elif test "$1" = "squash"
	then
		test_line_count = 3 actual
	else
		false
	fi
}

test_expect_success 'fixup! fixup!' '
	test_auto_fixup_fixup fixup fixup
'

test_expect_success 'fixup! squash!' '
	test_auto_fixup_fixup fixup squash
'

test_expect_success 'squash! squash!' '
	test_auto_fixup_fixup squash squash
'

test_expect_success 'squash! fixup!' '
	test_auto_fixup_fixup squash fixup
'

test_expect_success 'autosquash with custom inst format' '
	shit reset --hard base &&
	shit config --add rebase.instructionFormat "[%an @ %ar] %s"  &&
	echo 2 >file1 &&
	shit add -u &&
	test_tick &&
	oid=$(shit rev-parse --short HEAD^) &&
	shit commit -m "squash! $oid" -m "extra para for first" &&
	echo 1 >file1 &&
	shit add -u &&
	test_tick &&
	subject=$(shit log -n 1 --format=%s HEAD~2) &&
	shit commit -m "squash! $subject" -m "second extra para for first" &&
	shit tag final-squash-instFmt &&
	test_tick &&
	shit rebase --autosquash -i HEAD~4 &&
	shit log --oneline >actual &&
	test_line_count = 3 actual &&
	shit diff --exit-code final-squash-instFmt &&
	echo 1 >expect &&
	shit cat-file blob HEAD^:file1 >actual &&
	test_cmp expect actual &&
	shit cat-file commit HEAD^ >commit &&
	! grep "squash" commit &&
	grep first commit >actual &&
	test_line_count = 3 actual
'

test_expect_success 'autosquash with empty custom instructionFormat' '
	shit reset --hard base &&
	test_commit empty-instructionFormat-test &&
	(
		set_cat_todo_editor &&
		test_must_fail shit -c rebase.instructionFormat= \
			rebase --autosquash  --force-rebase -i HEAD^ >actual &&
		shit log -1 --format="pick %h %s" >expect &&
		test_cmp expect actual
	)
'

set_backup_editor () {
	write_script backup-editor.sh <<-\EOF
	cp "$1" .shit/backup-"$(basename "$1")"
	EOF
	test_set_editor "$PWD/backup-editor.sh"
}

test_expect_success 'autosquash with multiple empty patches' '
	test_tick &&
	shit commit --allow-empty -m "empty" &&
	test_tick &&
	shit commit --allow-empty -m "empty2" &&
	test_tick &&
	>fixup &&
	shit add fixup &&
	shit commit --fixup HEAD^^ &&
	(
		set_backup_editor &&
		shit_USE_REBASE_HELPER=false \
		shit rebase -i --force-rebase --autosquash HEAD~4 &&
		grep empty2 .shit/backup-shit-rebase-todo
	)
'

test_expect_success 'extra spaces after fixup!' '
	base=$(shit rev-parse HEAD) &&
	test_commit to-fixup &&
	shit commit --allow-empty -m "fixup!  to-fixup" &&
	shit rebase -i --autosquash --keep-empty HEAD~2 &&
	parent=$(shit rev-parse HEAD^) &&
	test $base = $parent
'

test_expect_success 'wrapped original subject' '
	if test -d .shit/rebase-merge; then shit rebase --abort; fi &&
	base=$(shit rev-parse HEAD) &&
	echo "wrapped subject" >wrapped &&
	shit add wrapped &&
	test_tick &&
	shit commit --allow-empty -m "$(printf "To\nfixup")" &&
	test_tick &&
	shit commit --allow-empty -m "fixup! To fixup" &&
	shit rebase -i --autosquash --keep-empty HEAD~2 &&
	parent=$(shit rev-parse HEAD^) &&
	test $base = $parent
'

test_expect_success 'abort last squash' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	test_when_finished "shit checkout main" &&

	shit checkout -b some-squashes &&
	shit commit --allow-empty -m first &&
	shit commit --allow-empty --squash HEAD &&
	shit commit --allow-empty -m second &&
	shit commit --allow-empty --squash HEAD &&

	test_must_fail shit -c core.editor="grep -q ^pick" \
		rebase -ki --autosquash HEAD~4 &&
	: do not finish the squash, but resolve it manually &&
	shit commit --allow-empty --amend -m edited-first &&
	shit rebase --skip &&
	shit show >actual &&
	! grep first actual
'

test_expect_success 'fixup a fixup' '
	echo 0to-fixup >file0 &&
	test_tick &&
	shit commit -m "to-fixup" file0 &&
	test_tick &&
	shit commit --squash HEAD -m X --allow-empty &&
	test_tick &&
	shit commit --squash HEAD^ -m Y --allow-empty &&
	test_tick &&
	shit commit -m "squash! $(shit rev-parse HEAD^)" -m Z --allow-empty &&
	test_tick &&
	shit commit -m "squash! $(shit rev-parse HEAD^^)" -m W --allow-empty &&
	shit rebase -ki --autosquash HEAD~5 &&
	test XZWY = $(shit show | tr -cd W-Z)
'

test_expect_success 'fixup does not clean up commit message' '
	oneline="#818" &&
	shit commit --allow-empty -m "$oneline" &&
	shit commit --fixup HEAD --allow-empty &&
	shit -c commit.cleanup=strip rebase -ki --autosquash HEAD~2 &&
	test "$oneline" = "$(shit show -s --format=%s)"
'

test_done
