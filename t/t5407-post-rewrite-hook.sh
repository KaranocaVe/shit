#!/bin/sh
#
# Copyright (c) 2010 Thomas Rast
#

test_description='Test the post-rewrite hook.'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '
	test_commit A foo A &&
	test_commit B foo B &&
	test_commit C foo C &&
	test_commit D foo D &&
	shit checkout A^0 &&
	test_commit E bar E &&
	test_commit F foo F &&
	shit checkout B &&
	shit merge E &&
	shit tag merge-E &&
	test_commit G G &&
	test_commit H H &&
	test_commit I I &&
	shit checkout main &&

	test_hook --setup post-rewrite <<-EOF
	echo \$@ > "$TRASH_DIRECTORY"/post-rewrite.args
	cat > "$TRASH_DIRECTORY"/post-rewrite.data
	EOF
'

clear_hook_input () {
	rm -f post-rewrite.args post-rewrite.data
}

verify_hook_input () {
	test_cmp expected.args "$TRASH_DIRECTORY"/post-rewrite.args &&
	test_cmp expected.data "$TRASH_DIRECTORY"/post-rewrite.data
}

test_expect_success 'shit commit --amend' '
	clear_hook_input &&
	echo "D new message" > newmsg &&
	oldsha=$(shit rev-parse HEAD^0) &&
	shit commit -Fnewmsg --amend &&
	echo amend > expected.args &&
	echo $oldsha $(shit rev-parse HEAD^0) > expected.data &&
	verify_hook_input
'

test_expect_success 'shit commit --amend --no-post-rewrite' '
	clear_hook_input &&
	echo "D new message again" > newmsg &&
	shit commit --no-post-rewrite -Fnewmsg --amend &&
	test ! -f post-rewrite.args &&
	test ! -f post-rewrite.data
'

test_expect_success 'shit rebase --apply' '
	shit reset --hard D &&
	clear_hook_input &&
	test_must_fail shit rebase --apply --onto A B &&
	echo C > foo &&
	shit add foo &&
	shit rebase --continue &&
	echo rebase >expected.args &&
	cat >expected.data <<-EOF &&
	$(shit rev-parse C) $(shit rev-parse HEAD^)
	$(shit rev-parse D) $(shit rev-parse HEAD)
	EOF
	verify_hook_input
'

test_expect_success 'shit rebase --apply --skip' '
	shit reset --hard D &&
	clear_hook_input &&
	test_must_fail shit rebase --apply --onto A B &&
	test_must_fail shit rebase --skip &&
	echo D > foo &&
	shit add foo &&
	shit rebase --continue &&
	echo rebase >expected.args &&
	cat >expected.data <<-EOF &&
	$(shit rev-parse C) $(shit rev-parse HEAD^)
	$(shit rev-parse D) $(shit rev-parse HEAD)
	EOF
	verify_hook_input
'

test_expect_success 'shit rebase --apply --skip the last one' '
	shit reset --hard F &&
	clear_hook_input &&
	test_must_fail shit rebase --apply --onto D A &&
	shit rebase --skip &&
	echo rebase >expected.args &&
	cat >expected.data <<-EOF &&
	$(shit rev-parse E) $(shit rev-parse HEAD)
	$(shit rev-parse F) $(shit rev-parse HEAD)
	EOF
	verify_hook_input
'

test_expect_success 'shit rebase -m' '
	shit reset --hard D &&
	clear_hook_input &&
	test_must_fail shit rebase -m --onto A B &&
	echo C > foo &&
	shit add foo &&
	shit rebase --continue &&
	echo rebase >expected.args &&
	cat >expected.data <<-EOF &&
	$(shit rev-parse C) $(shit rev-parse HEAD^)
	$(shit rev-parse D) $(shit rev-parse HEAD)
	EOF
	verify_hook_input
'

test_expect_success 'shit rebase -m --skip' '
	shit reset --hard D &&
	clear_hook_input &&
	test_must_fail shit rebase -m --onto A B &&
	test_must_fail shit rebase --skip &&
	echo D > foo &&
	shit add foo &&
	shit rebase --continue &&
	echo rebase >expected.args &&
	cat >expected.data <<-EOF &&
	$(shit rev-parse C) $(shit rev-parse HEAD^)
	$(shit rev-parse D) $(shit rev-parse HEAD)
	EOF
	verify_hook_input
'

test_expect_success 'shit rebase with implicit use of merge backend' '
	shit reset --hard D &&
	clear_hook_input &&
	test_must_fail shit rebase --keep-empty --onto A B &&
	echo C > foo &&
	shit add foo &&
	shit rebase --continue &&
	echo rebase >expected.args &&
	cat >expected.data <<-EOF &&
	$(shit rev-parse C) $(shit rev-parse HEAD^)
	$(shit rev-parse D) $(shit rev-parse HEAD)
	EOF
	verify_hook_input
'

test_expect_success 'shit rebase --skip with implicit use of merge backend' '
	shit reset --hard D &&
	clear_hook_input &&
	test_must_fail shit rebase --keep-empty --onto A B &&
	test_must_fail shit rebase --skip &&
	echo D > foo &&
	shit add foo &&
	shit rebase --continue &&
	echo rebase >expected.args &&
	cat >expected.data <<-EOF &&
	$(shit rev-parse C) $(shit rev-parse HEAD^)
	$(shit rev-parse D) $(shit rev-parse HEAD)
	EOF
	verify_hook_input
'

. "$TEST_DIRECTORY"/lib-rebase.sh

set_fake_editor

# Helper to work around the lack of one-shot exporting for
# test_must_fail (as it is a shell function)
test_fail_interactive_rebase () {
	(
		FAKE_LINES="$1" &&
		shift &&
		export FAKE_LINES &&
		test_must_fail shit rebase -i "$@"
	)
}

test_expect_success 'shit rebase with failed pick' '
	clear_hook_input &&
	cat >todo <<-\EOF &&
	exec >bar
	merge -C merge-E E
	exec >G
	pick G
	exec >H 2>I
	pick H
	fixup I
	EOF

	(
		set_replace_editor todo &&
		test_must_fail shit rebase -i D D 2>err
	) &&
	grep "would be overwritten" err &&
	rm bar &&

	test_must_fail shit rebase --continue 2>err &&
	grep "would be overwritten" err &&
	rm G &&

	test_must_fail shit rebase --continue 2>err &&
	grep "would be overwritten" err &&
	rm H &&

	test_must_fail shit rebase --continue 2>err &&
	grep "would be overwritten" err &&
	rm I &&

	shit rebase --continue &&
	echo rebase >expected.args &&
	cat >expected.data <<-EOF &&
	$(shit rev-parse merge-E) $(shit rev-parse HEAD~2)
	$(shit rev-parse G) $(shit rev-parse HEAD~1)
	$(shit rev-parse H) $(shit rev-parse HEAD)
	$(shit rev-parse I) $(shit rev-parse HEAD)
	EOF
	verify_hook_input
'

test_expect_success 'shit rebase -i (unchanged)' '
	shit reset --hard D &&
	clear_hook_input &&
	test_fail_interactive_rebase "1 2" --onto A B &&
	echo C > foo &&
	shit add foo &&
	shit rebase --continue &&
	echo rebase >expected.args &&
	cat >expected.data <<-EOF &&
	$(shit rev-parse C) $(shit rev-parse HEAD^)
	$(shit rev-parse D) $(shit rev-parse HEAD)
	EOF
	verify_hook_input
'

test_expect_success 'shit rebase -i (skip)' '
	shit reset --hard D &&
	clear_hook_input &&
	test_fail_interactive_rebase "2" --onto A B &&
	echo D > foo &&
	shit add foo &&
	shit rebase --continue &&
	echo rebase >expected.args &&
	cat >expected.data <<-EOF &&
	$(shit rev-parse D) $(shit rev-parse HEAD)
	EOF
	verify_hook_input
'

test_expect_success 'shit rebase -i (squash)' '
	shit reset --hard D &&
	clear_hook_input &&
	test_fail_interactive_rebase "1 squash 2" --onto A B &&
	echo C > foo &&
	shit add foo &&
	shit rebase --continue &&
	echo rebase >expected.args &&
	cat >expected.data <<-EOF &&
	$(shit rev-parse C) $(shit rev-parse HEAD)
	$(shit rev-parse D) $(shit rev-parse HEAD)
	EOF
	verify_hook_input
'

test_expect_success 'shit rebase -i (fixup without conflict)' '
	shit reset --hard D &&
	clear_hook_input &&
	FAKE_LINES="1 fixup 2" shit rebase -i B &&
	echo rebase >expected.args &&
	cat >expected.data <<-EOF &&
	$(shit rev-parse C) $(shit rev-parse HEAD)
	$(shit rev-parse D) $(shit rev-parse HEAD)
	EOF
	verify_hook_input
'

test_expect_success 'shit rebase -i (double edit)' '
	shit reset --hard D &&
	clear_hook_input &&
	FAKE_LINES="edit 1 edit 2" shit rebase -i B &&
	shit rebase --continue &&
	echo something > foo &&
	shit add foo &&
	shit rebase --continue &&
	echo rebase >expected.args &&
	cat >expected.data <<-EOF &&
	$(shit rev-parse C) $(shit rev-parse HEAD^)
	$(shit rev-parse D) $(shit rev-parse HEAD)
	EOF
	verify_hook_input
'

test_expect_success 'shit rebase -i (exec)' '
	shit reset --hard D &&
	clear_hook_input &&
	FAKE_LINES="edit 1 exec_false 2" shit rebase -i B &&
	echo something >bar &&
	shit add bar &&
	# Fails because of exec false
	test_must_fail shit rebase --continue &&
	shit rebase --continue &&
	echo rebase >expected.args &&
	cat >expected.data <<-EOF &&
	$(shit rev-parse C) $(shit rev-parse HEAD^)
	$(shit rev-parse D) $(shit rev-parse HEAD)
	EOF
	verify_hook_input
'

test_done
