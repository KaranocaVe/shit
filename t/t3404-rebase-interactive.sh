#!/bin/sh
#
# Copyright (c) 2007 Johannes E. Schindelin
#

test_description='shit rebase interactive

This test runs shit rebase "interactively", by faking an edit, and verifies
that the result still makes sense.

Initial setup:

     one - two - three - four (conflict-branch)
   /
 A - B - C - D - E            (primary)
 | \
 |   F - G - H                (branch1)
 |     \
 |\      I                    (branch2)
 | \
 |   J - K - L - M            (no-conflict-branch)
  \
    N - O - P                 (no-ff-branch)

 where A, B, D and G all touch file1, and one, two, three, four all
 touch file "conflict".
'

. ./test-lib.sh

. "$TEST_DIRECTORY"/lib-rebase.sh

test_expect_success 'setup' '
	shit switch -C primary &&
	test_commit A file1 &&
	test_commit B file1 &&
	test_commit C file2 &&
	test_commit D file1 &&
	test_commit E file3 &&
	shit checkout -b branch1 A &&
	test_commit F file4 &&
	test_commit G file1 &&
	test_commit H file5 &&
	shit checkout -b branch2 F &&
	test_commit I file6 &&
	shit checkout -b conflict-branch A &&
	test_commit one conflict &&
	test_commit two conflict &&
	test_commit three conflict &&
	test_commit four conflict &&
	shit checkout -b no-conflict-branch A &&
	test_commit J fileJ &&
	test_commit K fileK &&
	test_commit L fileL &&
	test_commit M fileM &&
	shit checkout -b no-ff-branch A &&
	test_commit N fileN &&
	test_commit O fileO &&
	test_commit P fileP
'

# "exec" commands are run with the user shell by default, but this may
# be non-POSIX. For example, if SHELL=zsh then ">file" doesn't work
# to create a file. Unsetting SHELL avoids such non-portable behavior
# in tests. It must be exported for it to take effect where needed.
SHELL=
export SHELL

test_expect_success 'rebase --keep-empty' '
	shit checkout -b emptybranch primary &&
	shit commit --allow-empty -m "empty" &&
	shit rebase --keep-empty -i HEAD~2 &&
	shit log --oneline >actual &&
	test_line_count = 6 actual
'

test_expect_success 'rebase -i with empty todo list' '
	cat >expect <<-\EOF &&
	error: nothing to do
	EOF
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="#" \
			shit rebase -i HEAD^ >output 2>&1
	) &&
	tail -n 1 output >actual &&  # Ignore output about changing todo list
	test_cmp expect actual
'

test_expect_success 'rebase -i with the exec command' '
	shit checkout primary &&
	(
	set_fake_editor &&
	FAKE_LINES="1 exec_>touch-one
		2 exec_>touch-two exec_false exec_>touch-three
		3 4 exec_>\"touch-file__name_with_spaces\";_>touch-after-semicolon 5" &&
	export FAKE_LINES &&
	test_must_fail shit rebase -i A
	) &&
	test_path_is_file touch-one &&
	test_path_is_file touch-two &&
	# Missing because we should have stopped by now.
	test_path_is_missing touch-three &&
	test_cmp_rev C HEAD &&
	shit rebase --continue &&
	test_path_is_file touch-three &&
	test_path_is_file "touch-file  name with spaces" &&
	test_path_is_file touch-after-semicolon &&
	test_cmp_rev primary HEAD &&
	rm -f touch-*
'

test_expect_success 'rebase -i with the exec command runs from tree root' '
	shit checkout primary &&
	mkdir subdir && (cd subdir &&
	set_fake_editor &&
	FAKE_LINES="1 exec_>touch-subdir" \
		shit rebase -i HEAD^
	) &&
	test_path_is_file touch-subdir &&
	rm -fr subdir
'

test_expect_success 'rebase -i with exec allows shit commands in subdirs' '
	test_when_finished "rm -rf subdir" &&
	test_when_finished "shit rebase --abort ||:" &&
	shit checkout primary &&
	mkdir subdir && (cd subdir &&
	set_fake_editor &&
	FAKE_LINES="1 x_cd_subdir_&&_shit_rev-parse_--is-inside-work-tree" \
		shit rebase -i HEAD^
	)
'

test_expect_success 'rebase -i sets work tree properly' '
	test_when_finished "rm -rf subdir" &&
	test_when_finished "test_might_fail shit rebase --abort" &&
	mkdir subdir &&
	shit rebase -x "(cd subdir && shit rev-parse --show-toplevel)" HEAD^ \
		>actual &&
	! grep "/subdir$" actual
'

test_expect_success 'rebase -i with the exec command checks tree cleanness' '
	shit checkout primary &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="exec_echo_foo_>file1 1" \
			shit rebase -i HEAD^
	) &&
	test_cmp_rev primary^ HEAD &&
	shit reset --hard &&
	shit rebase --continue
'

test_expect_success 'cherry-pick works with rebase --exec' '
	test_when_finished "shit cherry-pick --abort; \
			    shit rebase --abort; \
			    shit checkout primary" &&
	echo "exec shit cherry-pick G" >todo &&
	(
		set_replace_editor todo &&
		test_must_fail shit rebase -i D D
	) &&
	test_cmp_rev G CHERRY_PICK_HEAD
'

test_expect_success 'rebase -x with empty command fails' '
	test_when_finished "shit rebase --abort ||:" &&
	test_must_fail env shit rebase -x "" @ 2>actual &&
	test_write_lines "error: empty exec command" >expected &&
	test_cmp expected actual &&
	test_must_fail env shit rebase -x " " @ 2>actual &&
	test_cmp expected actual
'

test_expect_success 'rebase -x with newline in command fails' '
	test_when_finished "shit rebase --abort ||:" &&
	test_must_fail env shit rebase -x "a${LF}b" @ 2>actual &&
	test_write_lines "error: exec commands cannot contain newlines" \
			 >expected &&
	test_cmp expected actual
'

test_expect_success 'rebase -i with exec of inexistent command' '
	shit checkout primary &&
	test_when_finished "shit rebase --abort" &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="exec_this-command-does-not-exist 1" \
			shit rebase -i HEAD^ >actual 2>&1
	) &&
	! grep "Maybe shit-rebase is broken" actual
'

test_expect_success 'implicit interactive rebase does not invoke sequence editor' '
	test_when_finished "shit rebase --abort ||:" &&
	shit_SEQUENCE_EDITOR="echo bad >" shit rebase -x"echo one" @^
'

test_expect_success 'no changes are a nop' '
	shit checkout branch2 &&
	shit rebase -i F &&
	test "$(shit symbolic-ref -q HEAD)" = "refs/heads/branch2" &&
	test_cmp_rev I HEAD
'

test_expect_success 'test the [branch] option' '
	shit checkout -b dead-end &&
	shit rm file6 &&
	shit commit -m "stop here" &&
	shit rebase -i F branch2 &&
	test "$(shit symbolic-ref -q HEAD)" = "refs/heads/branch2" &&
	test_cmp_rev I branch2 &&
	test_cmp_rev I HEAD
'

test_expect_success 'test --onto <branch>' '
	shit checkout -b test-onto branch2 &&
	shit rebase -i --onto branch1 F &&
	test "$(shit symbolic-ref -q HEAD)" = "refs/heads/test-onto" &&
	test_cmp_rev HEAD^ branch1 &&
	test_cmp_rev I branch2
'

test_expect_success 'rebase on top of a non-conflicting commit' '
	shit checkout branch1 &&
	shit tag original-branch1 &&
	shit rebase -i branch2 &&
	test file6 = $(shit diff --name-only original-branch1) &&
	test "$(shit symbolic-ref -q HEAD)" = "refs/heads/branch1" &&
	test_cmp_rev I branch2 &&
	test_cmp_rev I HEAD~2
'

test_expect_success 'reflog for the branch shows state before rebase' '
	test_cmp_rev branch1@{1} original-branch1
'

test_expect_success 'reflog for the branch shows correct finish message' '
	printf "rebase (finish): refs/heads/branch1 onto %s\n" \
		"$(shit rev-parse branch2)" >expected &&
	shit log -g --pretty=%gs -1 refs/heads/branch1 >actual &&
	test_cmp expected actual
'

test_expect_success 'exchange two commits' '
	(
		set_fake_editor &&
		FAKE_LINES="2 1" shit rebase -i HEAD~2
	) &&
	test H = $(shit cat-file commit HEAD^ | sed -ne \$p) &&
	test G = $(shit cat-file commit HEAD | sed -ne \$p) &&
	blob1=$(shit rev-parse --short HEAD^:file1) &&
	blob2=$(shit rev-parse --short HEAD:file1) &&
	commit=$(shit rev-parse --short HEAD)
'

test_expect_success 'stop on conflicting pick' '
	cat >expect <<-EOF &&
	diff --shit a/file1 b/file1
	index $blob1..$blob2 100644
	--- a/file1
	+++ b/file1
	@@ -1 +1 @@
	-A
	+G
	EOF
	cat >expect2 <<-EOF &&
	<<<<<<< HEAD
	D
	=======
	G
	>>>>>>> $commit (G)
	EOF
	shit tag new-branch1 &&
	test_must_fail shit rebase -i primary &&
	test "$(shit rev-parse HEAD~3)" = "$(shit rev-parse primary)" &&
	test_cmp expect .shit/rebase-merge/patch &&
	test_cmp expect2 file1 &&
	test "$(shit diff --name-status |
		sed -n -e "/^U/s/^U[^a-z]*//p")" = file1 &&
	test 4 = $(grep -v "^#" < .shit/rebase-merge/done | wc -l) &&
	test 0 = $(grep -c "^[^#]" < .shit/rebase-merge/shit-rebase-todo)
'

test_expect_success 'show conflicted patch' '
	shit_TRACE=1 shit rebase --show-current-patch >/dev/null 2>stderr &&
	grep "show.*REBASE_HEAD" stderr &&
	# the original stopped-sha1 is abbreviated
	stopped_sha1="$(shit rev-parse $(cat ".shit/rebase-merge/stopped-sha"))" &&
	test "$(shit rev-parse REBASE_HEAD)" = "$stopped_sha1"
'

test_expect_success 'abort' '
	shit rebase --abort &&
	test_cmp_rev new-branch1 HEAD &&
	test "$(shit symbolic-ref -q HEAD)" = "refs/heads/branch1" &&
	test_path_is_missing .shit/rebase-merge
'

test_expect_success 'abort with error when new base cannot be checked out' '
	shit rm --cached file1 &&
	shit commit -m "remove file in base" &&
	test_must_fail shit rebase -i primary > output 2>&1 &&
	test_grep "The following untracked working tree files would be overwritten by checkout:" \
		output &&
	test_grep "file1" output &&
	test_path_is_missing .shit/rebase-merge &&
	rm file1 &&
	shit reset --hard HEAD^
'

test_expect_success 'retain authorship' '
	echo A > file7 &&
	shit add file7 &&
	test_tick &&
	shit_AUTHOR_NAME="Twerp Snog" shit commit -m "different author" &&
	shit tag twerp &&
	shit rebase -i --onto primary HEAD^ &&
	shit show HEAD | grep "^Author: Twerp Snog"
'

test_expect_success 'retain authorship w/ conflicts' '
	oshit_AUTHOR_NAME=$shit_AUTHOR_NAME &&
	test_when_finished "shit_AUTHOR_NAME=\$oshit_AUTHOR_NAME" &&

	shit reset --hard twerp &&
	test_commit a conflict a conflict-a &&
	shit reset --hard twerp &&

	shit_AUTHOR_NAME=AttributeMe &&
	export shit_AUTHOR_NAME &&
	test_commit b conflict b conflict-b &&
	shit_AUTHOR_NAME=$oshit_AUTHOR_NAME &&

	test_must_fail shit rebase -i conflict-a &&
	echo resolved >conflict &&
	shit add conflict &&
	shit rebase --continue &&
	test_cmp_rev conflict-a^0 HEAD^ &&
	shit show >out &&
	grep AttributeMe out
'

test_expect_success 'squash' '
	shit reset --hard twerp &&
	echo B > file7 &&
	test_tick &&
	shit_AUTHOR_NAME="Nitfol" shit commit -m "nitfol" file7 &&
	echo "******************************" &&
	(
		set_fake_editor &&
		FAKE_LINES="1 squash 2" EXPECT_HEADER_COUNT=2 \
			shit rebase -i --onto primary HEAD~2
	) &&
	test B = $(cat file7) &&
	test_cmp_rev HEAD^ primary
'

test_expect_success 'retain authorship when squashing' '
	shit show HEAD | grep "^Author: Twerp Snog"
'

test_expect_success '--continue tries to commit' '
	shit reset --hard D &&
	test_tick &&
	(
		set_fake_editor &&
		test_must_fail shit rebase -i --onto new-branch1 HEAD^ &&
		echo resolved > file1 &&
		shit add file1 &&
		FAKE_COMMIT_MESSAGE="chouette!" shit rebase --continue
	) &&
	test_cmp_rev HEAD^ new-branch1 &&
	shit show HEAD | grep chouette
'

test_expect_success 'verbose flag is heeded, even after --continue' '
	shit reset --hard primary@{1} &&
	test_tick &&
	test_must_fail shit rebase -v -i --onto new-branch1 HEAD^ &&
	echo resolved > file1 &&
	shit add file1 &&
	shit rebase --continue > output &&
	grep "^ file1 | 2 +-$" output
'

test_expect_success 'multi-squash only fires up editor once' '
	base=$(shit rev-parse HEAD~4) &&
	(
		set_fake_editor &&
		FAKE_COMMIT_AMEND="ONCE" \
			FAKE_LINES="1 squash 2 squash 3 squash 4" \
			EXPECT_HEADER_COUNT=4 \
			shit rebase -i $base
	) &&
	test $base = $(shit rev-parse HEAD^) &&
	test 1 = $(shit show | grep ONCE | wc -l)
'

test_expect_success 'multi-fixup does not fire up editor' '
	shit checkout -b multi-fixup E &&
	base=$(shit rev-parse HEAD~4) &&
	(
		set_fake_editor &&
		FAKE_COMMIT_AMEND="NEVER" \
			FAKE_LINES="1 fixup 2 fixup 3 fixup 4" \
			shit rebase -i $base
	) &&
	test $base = $(shit rev-parse HEAD^) &&
	test 0 = $(shit show | grep NEVER | wc -l) &&
	shit checkout @{-1} &&
	shit branch -D multi-fixup
'

test_expect_success 'commit message used after conflict' '
	shit checkout -b conflict-fixup conflict-branch &&
	base=$(shit rev-parse HEAD~4) &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="1 fixup 3 fixup 4" \
			shit rebase -i $base &&
		echo three > conflict &&
		shit add conflict &&
		FAKE_COMMIT_AMEND="ONCE" EXPECT_HEADER_COUNT=2 \
			shit rebase --continue
	) &&
	test $base = $(shit rev-parse HEAD^) &&
	test 1 = $(shit show | grep ONCE | wc -l) &&
	shit checkout @{-1} &&
	shit branch -D conflict-fixup
'

test_expect_success 'commit message retained after conflict' '
	shit checkout -b conflict-squash conflict-branch &&
	base=$(shit rev-parse HEAD~4) &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="1 fixup 3 squash 4" \
			shit rebase -i $base &&
		echo three > conflict &&
		shit add conflict &&
		FAKE_COMMIT_AMEND="TWICE" EXPECT_HEADER_COUNT=2 \
			shit rebase --continue
	) &&
	test $base = $(shit rev-parse HEAD^) &&
	test 2 = $(shit show | grep TWICE | wc -l) &&
	shit checkout @{-1} &&
	shit branch -D conflict-squash
'

test_expect_success 'squash and fixup generate correct log messages' '
	cat >expect-squash-fixup <<-\EOF &&
	B

	D

	ONCE
	EOF
	shit checkout -b squash-fixup E &&
	base=$(shit rev-parse HEAD~4) &&
	(
		set_fake_editor &&
		FAKE_COMMIT_AMEND="ONCE" \
			FAKE_LINES="1 fixup 2 squash 3 fixup 4" \
			EXPECT_HEADER_COUNT=4 \
			shit rebase -i $base
	) &&
	shit cat-file commit HEAD | sed -e 1,/^\$/d > actual-squash-fixup &&
	test_cmp expect-squash-fixup actual-squash-fixup &&
	shit cat-file commit HEAD@{2} |
		grep "^# This is a combination of 3 commits\."  &&
	shit cat-file commit HEAD@{3} |
		grep "^# This is a combination of 2 commits\."  &&
	shit checkout @{-1} &&
	shit branch -D squash-fixup
'

test_expect_success 'squash ignores comments' '
	shit checkout -b skip-comments E &&
	base=$(shit rev-parse HEAD~4) &&
	(
		set_fake_editor &&
		FAKE_COMMIT_AMEND="ONCE" \
			FAKE_LINES="# 1 # squash 2 # squash 3 # squash 4 #" \
			EXPECT_HEADER_COUNT=4 \
			shit rebase -i $base
	) &&
	test $base = $(shit rev-parse HEAD^) &&
	test 1 = $(shit show | grep ONCE | wc -l) &&
	shit checkout @{-1} &&
	shit branch -D skip-comments
'

test_expect_success 'squash ignores blank lines' '
	shit checkout -b skip-blank-lines E &&
	base=$(shit rev-parse HEAD~4) &&
	(
		set_fake_editor &&
		FAKE_COMMIT_AMEND="ONCE" \
			FAKE_LINES="> 1 > squash 2 > squash 3 > squash 4 >" \
			EXPECT_HEADER_COUNT=4 \
			shit rebase -i $base
	) &&
	test $base = $(shit rev-parse HEAD^) &&
	test 1 = $(shit show | grep ONCE | wc -l) &&
	shit checkout @{-1} &&
	shit branch -D skip-blank-lines
'

test_expect_success 'squash works as expected' '
	shit checkout -b squash-works no-conflict-branch &&
	one=$(shit rev-parse HEAD~3) &&
	(
		set_fake_editor &&
		FAKE_LINES="1 s 3 2" EXPECT_HEADER_COUNT=2 shit rebase -i HEAD~3
	) &&
	test $one = $(shit rev-parse HEAD~2)
'

test_expect_success 'interrupted squash works as expected' '
	shit checkout -b interrupted-squash conflict-branch &&
	one=$(shit rev-parse HEAD~3) &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="1 squash 3 2" \
			shit rebase -i HEAD~3
	) &&
	test_write_lines one two four > conflict &&
	shit add conflict &&
	test_must_fail shit rebase --continue &&
	echo resolved > conflict &&
	shit add conflict &&
	shit rebase --continue &&
	test $one = $(shit rev-parse HEAD~2)
'

test_expect_success 'interrupted squash works as expected (case 2)' '
	shit checkout -b interrupted-squash2 conflict-branch &&
	one=$(shit rev-parse HEAD~3) &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="3 squash 1 2" \
			shit rebase -i HEAD~3
	) &&
	test_write_lines one four > conflict &&
	shit add conflict &&
	test_must_fail shit rebase --continue &&
	test_write_lines one two four > conflict &&
	shit add conflict &&
	test_must_fail shit rebase --continue &&
	echo resolved > conflict &&
	shit add conflict &&
	shit rebase --continue &&
	test $one = $(shit rev-parse HEAD~2)
'

test_expect_success '--continue tries to commit, even for "edit"' '
	echo unrelated > file7 &&
	shit add file7 &&
	test_tick &&
	shit commit -m "unrelated change" &&
	parent=$(shit rev-parse HEAD^) &&
	test_tick &&
	(
		set_fake_editor &&
		FAKE_LINES="edit 1" shit rebase -i HEAD^ &&
		echo edited > file7 &&
		shit add file7 &&
		FAKE_COMMIT_MESSAGE="chouette!" shit rebase --continue
	) &&
	test edited = $(shit show HEAD:file7) &&
	shit show HEAD | grep chouette &&
	test $parent = $(shit rev-parse HEAD^)
'

test_expect_success 'aborted --continue does not squash commits after "edit"' '
	old=$(shit rev-parse HEAD) &&
	test_tick &&
	(
		set_fake_editor &&
		FAKE_LINES="edit 1" shit rebase -i HEAD^ &&
		echo "edited again" > file7 &&
		shit add file7 &&
		test_must_fail env FAKE_COMMIT_MESSAGE=" " shit rebase --continue
	) &&
	test $old = $(shit rev-parse HEAD) &&
	shit rebase --abort
'

test_expect_success 'auto-amend only edited commits after "edit"' '
	test_tick &&
	(
		set_fake_editor &&
		FAKE_LINES="edit 1" shit rebase -i HEAD^ &&
		echo "edited again" > file7 &&
		shit add file7 &&
		FAKE_COMMIT_MESSAGE="edited file7 again" shit commit &&
		echo "and again" > file7 &&
		shit add file7 &&
		test_tick &&
		test_must_fail env FAKE_COMMIT_MESSAGE="and again" \
			shit rebase --continue
	) &&
	shit rebase --abort
'

test_expect_success 'clean error after failed "exec"' '
	test_tick &&
	test_when_finished "shit rebase --abort || :" &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="1 exec_false" shit rebase -i HEAD^
	) &&
	echo "edited again" > file7 &&
	shit add file7 &&
	test_must_fail shit rebase --continue 2>error &&
	test_grep "you have staged changes in your working tree" error &&
	test_grep ! "could not open.*for reading" error
'

test_expect_success 'rebase a detached HEAD' '
	grandparent=$(shit rev-parse HEAD~2) &&
	shit checkout $(shit rev-parse HEAD) &&
	test_tick &&
	(
		set_fake_editor &&
		FAKE_LINES="2 1" shit rebase -i HEAD~2
	) &&
	test $grandparent = $(shit rev-parse HEAD~2)
'

test_expect_success 'rebase a commit violating pre-commit' '
	test_hook pre-commit <<-\EOF &&
	test -z "$(shit diff --cached --check)"
	EOF
	echo "monde! " >> file1 &&
	test_tick &&
	test_must_fail shit commit -m doesnt-verify file1 &&
	shit commit -m doesnt-verify --no-verify file1 &&
	test_tick &&
	(
		set_fake_editor &&
		FAKE_LINES=2 shit rebase -i HEAD~2
	)
'

test_expect_success 'rebase with a file named HEAD in worktree' '
	shit reset --hard &&
	shit checkout -b branch3 A &&

	(
		shit_AUTHOR_NAME="Squashed Away" &&
		export shit_AUTHOR_NAME &&
		>HEAD &&
		shit add HEAD &&
		shit commit -m "Add head" &&
		>BODY &&
		shit add BODY &&
		shit commit -m "Add body"
	) &&

	(
		set_fake_editor &&
		FAKE_LINES="1 squash 2" shit rebase -i @{-1}
	) &&
	test "$(shit show -s --pretty=format:%an)" = "Squashed Away"

'

test_expect_success 'do "noop" when there is nothing to cherry-pick' '

	shit checkout -b branch4 HEAD &&
	shit_EDITOR=: shit commit --amend \
		--author="Somebody else <somebody@else.com>" &&
	test $(shit rev-parse branch3) != $(shit rev-parse branch4) &&
	shit rebase -i branch3 &&
	test_cmp_rev branch3 branch4

'

test_expect_success 'submodule rebase setup' '
	shit checkout A &&
	mkdir sub &&
	(
		cd sub && shit init && >elif &&
		shit add elif && shit commit -m "submodule initial"
	) &&
	echo 1 >file1 &&
	shit add file1 sub &&
	test_tick &&
	shit commit -m "One" &&
	echo 2 >file1 &&
	test_tick &&
	shit commit -a -m "Two" &&
	(
		cd sub && echo 3 >elif &&
		shit commit -a -m "submodule second"
	) &&
	test_tick &&
	shit commit -a -m "Three changes submodule"
'

test_expect_success 'submodule rebase -i' '
	(
		set_fake_editor &&
		FAKE_LINES="1 squash 2 3" shit rebase -i A
	)
'

test_expect_success 'submodule conflict setup' '
	shit tag submodule-base &&
	shit checkout HEAD^ &&
	(
		cd sub && shit checkout HEAD^ && echo 4 >elif &&
		shit add elif && shit commit -m "submodule conflict"
	) &&
	shit add sub &&
	test_tick &&
	shit commit -m "Conflict in submodule" &&
	shit tag submodule-topic
'

test_expect_success 'rebase -i continue with only submodule staged' '
	test_must_fail shit rebase -i submodule-base &&
	shit add sub &&
	shit rebase --continue &&
	test $(shit rev-parse submodule-base) != $(shit rev-parse HEAD)
'

test_expect_success 'rebase -i continue with unstaged submodule' '
	shit checkout submodule-topic &&
	shit reset --hard &&
	test_must_fail shit rebase -i submodule-base &&
	shit reset &&
	shit rebase --continue &&
	test_cmp_rev submodule-base HEAD
'

test_expect_success 'avoid unnecessary reset' '
	shit checkout primary &&
	shit reset --hard &&
	test-tool chmtime =123456789 file3 &&
	shit update-index --refresh &&
	HEAD=$(shit rev-parse HEAD) &&
	shit rebase -i HEAD~4 &&
	test $HEAD = $(shit rev-parse HEAD) &&
	MTIME=$(test-tool chmtime --get file3) &&
	test 123456789 = $MTIME
'

test_expect_success 'reword' '
	shit checkout -b reword-branch primary &&
	(
		set_fake_editor &&
		FAKE_LINES="1 2 3 reword 4" FAKE_COMMIT_MESSAGE="E changed" \
			shit rebase -i A &&
		shit show HEAD | grep "E changed" &&
		test $(shit rev-parse primary) != $(shit rev-parse HEAD) &&
		test_cmp_rev primary^ HEAD^ &&
		FAKE_LINES="1 2 reword 3 4" FAKE_COMMIT_MESSAGE="D changed" \
			shit rebase -i A &&
		shit show HEAD^ | grep "D changed" &&
		FAKE_LINES="reword 1 2 3 4" FAKE_COMMIT_MESSAGE="B changed" \
			shit rebase -i A &&
		shit show HEAD~3 | grep "B changed" &&
		FAKE_LINES="1 r 2 pick 3 p 4" FAKE_COMMIT_MESSAGE="C changed" \
			shit rebase -i A
	) &&
	shit show HEAD~2 | grep "C changed"
'

test_expect_success 'no uncommitted changes when rewording and the todo list is reloaded' '
	shit checkout E &&
	test_when_finished "shit checkout @{-1}" &&
	(
		set_fake_editor &&
		shit_SEQUENCE_EDITOR="\"$PWD/fake-editor.sh\"" &&
		export shit_SEQUENCE_EDITOR &&
		set_reword_editor &&
		FAKE_LINES="reword 1 reword 2" shit rebase -i C
	) &&
	check_reworded_commits D E
'

test_expect_success 'rebase -i can copy notes' '
	shit config notes.rewrite.rebase true &&
	shit config notes.rewriteRef "refs/notes/*" &&
	test_commit n1 &&
	test_commit n2 &&
	test_commit n3 &&
	shit notes add -m"a note" n3 &&
	shit rebase -i --onto n1 n2 &&
	test "a note" = "$(shit notes show HEAD)"
'

test_expect_success 'rebase -i can copy notes over a fixup' '
	cat >expect <<-\EOF &&
	an earlier note

	a note
	EOF
	shit reset --hard n3 &&
	shit notes add -m"an earlier note" n2 &&
	(
		set_fake_editor &&
		shit_NOTES_REWRITE_MODE=concatenate FAKE_LINES="1 f 2" \
			shit rebase -i n1
	) &&
	shit notes show > output &&
	test_cmp expect output
'

test_expect_success 'rebase while detaching HEAD' '
	shit symbolic-ref HEAD &&
	grandparent=$(shit rev-parse HEAD~2) &&
	test_tick &&
	(
		set_fake_editor &&
		FAKE_LINES="2 1" shit rebase -i HEAD~2 HEAD^0
	) &&
	test $grandparent = $(shit rev-parse HEAD~2) &&
	test_must_fail shit symbolic-ref HEAD
'

test_tick # Ensure that the rebased commits get a different timestamp.
test_expect_success 'always cherry-pick with --no-ff' '
	shit checkout no-ff-branch &&
	shit tag original-no-ff-branch &&
	shit rebase -i --no-ff A &&
	for p in 0 1 2
	do
		test ! $(shit rev-parse HEAD~$p) = $(shit rev-parse original-no-ff-branch~$p) &&
		shit diff HEAD~$p original-no-ff-branch~$p > out &&
		test_must_be_empty out || return 1
	done &&
	test_cmp_rev HEAD~3 original-no-ff-branch~3 &&
	shit diff HEAD~3 original-no-ff-branch~3 > out &&
	test_must_be_empty out
'

test_expect_success 'set up commits with funny messages' '
	shit checkout -b funny A &&
	echo >>file1 &&
	test_tick &&
	shit commit -a -m "end with slash\\" &&
	echo >>file1 &&
	test_tick &&
	shit commit -a -m "something (\000) that looks like octal" &&
	echo >>file1 &&
	test_tick &&
	shit commit -a -m "something (\n) that looks like a newline" &&
	echo >>file1 &&
	test_tick &&
	shit commit -a -m "another commit"
'

test_expect_success 'rebase-i history with funny messages' '
	shit rev-list A..funny >expect &&
	test_tick &&
	(
		set_fake_editor &&
		FAKE_LINES="1 2 3 4" shit rebase -i A
	) &&
	shit rev-list A.. >actual &&
	test_cmp expect actual
'

test_expect_success 'prepare for rebase -i --exec' '
	shit checkout primary &&
	shit checkout -b execute &&
	test_commit one_exec main.txt one_exec &&
	test_commit two_exec main.txt two_exec &&
	test_commit three_exec main.txt three_exec
'

test_expect_success 'running "shit rebase -i --exec shit show HEAD"' '
	(
		set_fake_editor &&
		shit rebase -i --exec "shit show HEAD" HEAD~2 >actual &&
		FAKE_LINES="1 exec_shit_show_HEAD 2 exec_shit_show_HEAD" &&
		export FAKE_LINES &&
		shit rebase -i HEAD~2 >expect
	) &&
	sed -e "1,9d" expect >expected &&
	test_cmp expected actual
'

test_expect_success 'running "shit rebase --exec shit show HEAD -i"' '
	shit reset --hard execute &&
	(
		set_fake_editor &&
		shit rebase --exec "shit show HEAD" -i HEAD~2 >actual &&
		FAKE_LINES="1 exec_shit_show_HEAD 2 exec_shit_show_HEAD" &&
		export FAKE_LINES &&
		shit rebase -i HEAD~2 >expect
	) &&
	sed -e "1,9d" expect >expected &&
	test_cmp expected actual
'

test_expect_success 'running "shit rebase -ix shit show HEAD"' '
	shit reset --hard execute &&
	(
		set_fake_editor &&
		shit rebase -ix "shit show HEAD" HEAD~2 >actual &&
		FAKE_LINES="1 exec_shit_show_HEAD 2 exec_shit_show_HEAD" &&
		export FAKE_LINES &&
		shit rebase -i HEAD~2 >expect
	) &&
	sed -e "1,9d" expect >expected &&
	test_cmp expected actual
'


test_expect_success 'rebase -ix with several <CMD>' '
	shit reset --hard execute &&
	(
		set_fake_editor &&
		shit rebase -ix "shit show HEAD; pwd" HEAD~2 >actual &&
		FAKE_LINES="1 exec_shit_show_HEAD;_pwd 2 exec_shit_show_HEAD;_pwd" &&
		export FAKE_LINES &&
		shit rebase -i HEAD~2 >expect
	) &&
	sed -e "1,9d" expect >expected &&
	test_cmp expected actual
'

test_expect_success 'rebase -ix with several instances of --exec' '
	shit reset --hard execute &&
	(
		set_fake_editor &&
		shit rebase -i --exec "shit show HEAD" --exec "pwd" HEAD~2 >actual &&
		FAKE_LINES="1 exec_shit_show_HEAD exec_pwd 2
				exec_shit_show_HEAD exec_pwd" &&
		export FAKE_LINES &&
		shit rebase -i HEAD~2 >expect
	) &&
	sed -e "1,11d" expect >expected &&
	test_cmp expected actual
'

test_expect_success 'rebase -ix with --autosquash' '
	shit reset --hard execute &&
	shit checkout -b autosquash &&
	echo second >second.txt &&
	shit add second.txt &&
	shit commit -m "fixup! two_exec" &&
	echo bis >bis.txt &&
	shit add bis.txt &&
	shit commit -m "fixup! two_exec" &&
	shit checkout -b autosquash_actual &&
	shit rebase -i --exec "shit show HEAD" --autosquash HEAD~4 >actual &&
	shit checkout autosquash &&
	(
		set_fake_editor &&
		shit checkout -b autosquash_expected &&
		FAKE_LINES="1 fixup 3 fixup 4 exec_shit_show_HEAD 2 exec_shit_show_HEAD" &&
		export FAKE_LINES &&
		shit rebase -i HEAD~4 >expect
	) &&
	sed -e "1,13d" expect >expected &&
	test_cmp expected actual
'

test_expect_success 'rebase --exec works without -i ' '
	shit reset --hard execute &&
	rm -rf exec_output &&
	EDITOR="echo >invoked_editor" shit rebase --exec "echo a line >>exec_output"  HEAD~2 2>actual &&
	test_grep  "Successfully rebased and updated" actual &&
	test_line_count = 2 exec_output &&
	test_path_is_missing invoked_editor
'

test_expect_success 'rebase -i --exec without <CMD>' '
	shit reset --hard execute &&
	test_must_fail shit rebase -i --exec 2>actual &&
	test_grep "requires a value" actual &&
	shit checkout primary
'

test_expect_success 'rebase -i --root re-order and drop commits' '
	shit checkout E &&
	(
		set_fake_editor &&
		FAKE_LINES="3 1 2 5" shit rebase -i --root
	) &&
	test E = $(shit cat-file commit HEAD | sed -ne \$p) &&
	test B = $(shit cat-file commit HEAD^ | sed -ne \$p) &&
	test A = $(shit cat-file commit HEAD^^ | sed -ne \$p) &&
	test C = $(shit cat-file commit HEAD^^^ | sed -ne \$p) &&
	test 0 = $(shit cat-file commit HEAD^^^ | grep -c ^parent\ )
'

test_expect_success 'rebase -i --root retain root commit author and message' '
	shit checkout A &&
	echo B >file7 &&
	shit add file7 &&
	shit_AUTHOR_NAME="Twerp Snog" shit commit -m "different author" &&
	(
		set_fake_editor &&
		FAKE_LINES="2" shit rebase -i --root
	) &&
	shit cat-file commit HEAD | grep -q "^author Twerp Snog" &&
	shit cat-file commit HEAD | grep -q "^different author$"
'

test_expect_success 'rebase -i --root temporary sentinel commit' '
	shit checkout B &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="2" shit rebase -i --root
	) &&
	shit cat-file commit HEAD | grep "^tree $EMPTY_TREE" &&
	shit rebase --abort
'

test_expect_success 'rebase -i --root fixup root commit' '
	shit checkout B &&
	(
		set_fake_editor &&
		FAKE_LINES="1 fixup 2" shit rebase -i --root
	) &&
	test A = $(shit cat-file commit HEAD | sed -ne \$p) &&
	test B = $(shit show HEAD:file1) &&
	test 0 = $(shit cat-file commit HEAD | grep -c ^parent\ )
'

test_expect_success 'rebase -i --root reword original root commit' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	shit checkout -b reword-original-root-branch primary &&
	(
		set_fake_editor &&
		FAKE_LINES="reword 1 2" FAKE_COMMIT_MESSAGE="A changed" \
			shit rebase -i --root
	) &&
	shit show HEAD^ | grep "A changed" &&
	test -z "$(shit show -s --format=%p HEAD^)"
'

test_expect_success 'rebase -i --root reword new root commit' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	shit checkout -b reword-now-root-branch primary &&
	(
		set_fake_editor &&
		FAKE_LINES="reword 3 1" FAKE_COMMIT_MESSAGE="C changed" \
		shit rebase -i --root
	) &&
	shit show HEAD^ | grep "C changed" &&
	test -z "$(shit show -s --format=%p HEAD^)"
'

test_expect_success 'rebase -i --root when root has untracked file conflict' '
	test_when_finished "reset_rebase" &&
	shit checkout -b failing-root-pick A &&
	echo x >file2 &&
	shit rm file1 &&
	shit commit -m "remove file 1 add file 2" &&
	echo z >file1 &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="1 2" shit rebase -i --root
	) &&
	rm file1 &&
	shit rebase --continue &&
	test "$(shit log -1 --format=%B)" = "remove file 1 add file 2" &&
	test "$(shit rev-list --count HEAD)" = 2
'

test_expect_success 'rebase -i --root reword root when root has untracked file conflict' '
	test_when_finished "reset_rebase" &&
	echo z>file1 &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="reword 1 2" \
			FAKE_COMMIT_MESSAGE="Modified A" shit rebase -i --root &&
		rm file1 &&
		FAKE_COMMIT_MESSAGE="Reworded A" shit rebase --continue
	) &&
	test "$(shit log -1 --format=%B HEAD^)" = "Reworded A" &&
	test "$(shit rev-list --count HEAD)" = 2
'

test_expect_success 'rebase --edit-todo does not work on non-interactive rebase' '
	shit checkout reword-original-root-branch &&
	shit reset --hard &&
	shit checkout conflict-branch &&
	(
		set_fake_editor &&
		test_must_fail shit rebase -f --apply --onto HEAD~2 HEAD~ &&
		test_must_fail shit rebase --edit-todo
	) &&
	shit rebase --abort
'

test_expect_success 'rebase --edit-todo can be used to modify todo' '
	shit reset --hard &&
	shit checkout no-conflict-branch^0 &&
	(
		set_fake_editor &&
		FAKE_LINES="edit 1 2 3" shit rebase -i HEAD~3 &&
		FAKE_LINES="2 1" shit rebase --edit-todo &&
		shit rebase --continue
	) &&
	test M = $(shit cat-file commit HEAD^ | sed -ne \$p) &&
	test L = $(shit cat-file commit HEAD | sed -ne \$p)
'

test_expect_success 'rebase -i produces readable reflog' '
	shit reset --hard &&
	shit branch -f branch-reflog-test H &&
	shit rebase -i --onto I F branch-reflog-test &&
	cat >expect <<-\EOF &&
	rebase (finish): returning to refs/heads/branch-reflog-test
	rebase (pick): H
	rebase (pick): G
	rebase (start): checkout I
	EOF
	shit reflog -n4 HEAD |
	sed "s/[^:]*: //" >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase -i respects core.commentchar' '
	shit reset --hard &&
	shit checkout E^0 &&
	test_config core.commentchar "\\" &&
	write_script remove-all-but-first.sh <<-\EOF &&
	sed -e "2,\$s/^/\\\\/" "$1" >"$1.tmp" &&
	mv "$1.tmp" "$1"
	EOF
	(
		test_set_editor "$(pwd)/remove-all-but-first.sh" &&
		shit rebase -i B
	) &&
	test B = $(shit cat-file commit HEAD^ | sed -ne \$p)
'

test_expect_success 'rebase -i respects core.commentchar=auto' '
	test_config core.commentchar auto &&
	write_script copy-edit-script.sh <<-\EOF &&
	cp "$1" edit-script
	EOF
	test_when_finished "shit rebase --abort || :" &&
	(
		test_set_editor "$(pwd)/copy-edit-script.sh" &&
		shit rebase -i HEAD^
	) &&
	test -z "$(grep -ve "^#" -e "^\$" -e "^pick" edit-script)"
'

test_expect_success 'rebase -i, with <onto> and <upstream> specified as :/quuxery' '
	test_when_finished "shit branch -D torebase" &&
	shit checkout -b torebase branch1 &&
	upstream=$(shit rev-parse ":/J") &&
	onto=$(shit rev-parse ":/A") &&
	shit rebase --onto $onto $upstream &&
	shit reset --hard branch1 &&
	shit rebase --onto ":/A" ":/J" &&
	shit checkout branch1
'

test_expect_success 'rebase -i with --strategy and -X' '
	shit checkout -b conflict-merge-use-theirs conflict-branch &&
	shit reset --hard HEAD^ &&
	echo five >conflict &&
	echo Z >file1 &&
	shit commit -a -m "one file conflict" &&
	EDITOR=true shit rebase -i --strategy=recursive -Xours conflict-branch &&
	test $(shit show conflict-branch:conflict) = $(cat conflict) &&
	test $(cat file1) = Z
'

test_expect_success 'interrupted rebase -i with --strategy and -X' '
	shit checkout -b conflict-merge-use-theirs-interrupted conflict-branch &&
	shit reset --hard HEAD^ &&
	>breakpoint &&
	shit add breakpoint &&
	shit commit -m "breakpoint for interactive mode" &&
	echo five >conflict &&
	echo Z >file1 &&
	shit commit -a -m "one file conflict" &&
	(
		set_fake_editor &&
		FAKE_LINES="edit 1 2" shit rebase -i --strategy=recursive \
			-Xours conflict-branch
	) &&
	shit rebase --continue &&
	test $(shit show conflict-branch:conflict) = $(cat conflict) &&
	test $(cat file1) = Z
'

test_expect_success 'rebase -i error on commits with \ in message' '
	current_head=$(shit rev-parse HEAD) &&
	test_when_finished "shit rebase --abort; shit reset --hard $current_head; rm -f error" &&
	test_commit TO-REMOVE will-conflict old-content &&
	test_commit "\temp" will-conflict new-content dummy &&
	test_must_fail env EDITOR=true shit rebase -i HEAD^ --onto HEAD^^ 2>error &&
	test_expect_code 1 grep  "	emp" error
'

test_expect_success 'short commit ID setup' '
	test_when_finished "shit checkout primary" &&
	shit checkout --orphan collide &&
	shit rm -rf . &&
	(
	unset test_tick &&
	test_commit collide1 collide &&
	test_commit --notick collide2 collide &&
	test_commit --notick collide3 collide
	)
'

if test -n "$shit_TEST_FIND_COLLIDER"
then
	author="$(unset test_tick; test_tick; shit var shit_AUTHOR_IDENT)"
	committer="$(unset test_tick; test_tick; shit var shit_COMMITTER_IDENT)"
	blob="$(shit rev-parse collide2:collide)"
	from="$(shit rev-parse collide1^0)"
	repl="commit refs/heads/collider-&\\n"
	repl="${repl}author $author\\ncommitter $committer\\n"
	repl="${repl}data <<EOF\\ncollide2 &\\nEOF\\n"
	repl="${repl}from $from\\nM 100644 $blob collide\\n"
	test_seq 1 32768 | sed "s|.*|$repl|" >script &&
	shit fast-import <script &&
	shit pack-refs &&
	shit for-each-ref >refs &&
	grep "^$(test_oid t3404_collision)" <refs >matches &&
	cat matches &&
	test_line_count -gt 2 matches || {
		echo "Could not find a collider" >&2
		exit 1
	}
fi

test_expect_success 'short commit ID collide' '
	test_oid_cache <<-EOF &&
	# collision-related constants
	t3404_collision	sha1:6bcd
	t3404_collision	sha256:0161
	t3404_collider	sha1:ac4f2ee
	t3404_collider	sha256:16697
	EOF
	test_when_finished "reset_rebase && shit checkout primary" &&
	shit checkout collide &&
	colliding_id=$(test_oid t3404_collision) &&
	hexsz=$(test_oid hexsz) &&
	test $colliding_id = "$(shit rev-parse HEAD | cut -c 1-4)" &&
	test_config core.abbrev 4 &&
	(
		unset test_tick &&
		test_tick &&
		set_fake_editor &&
		FAKE_COMMIT_MESSAGE="collide2 $(test_oid t3404_collider)" \
		FAKE_LINES="reword 1 break 2" shit rebase -i HEAD~2 &&
		test $colliding_id = "$(shit rev-parse HEAD | cut -c 1-4)" &&
		grep "^pick $colliding_id " \
			.shit/rebase-merge/shit-rebase-todo.tmp &&
		grep -E "^pick [0-9a-f]{$hexsz}" \
			.shit/rebase-merge/shit-rebase-todo &&
		grep -E "^pick [0-9a-f]{$hexsz}" \
			.shit/rebase-merge/shit-rebase-todo.backup &&
		shit rebase --continue
	) &&
	collide2="$(shit rev-parse HEAD~1 | cut -c 1-4)" &&
	collide3="$(shit rev-parse collide3 | cut -c 1-4)" &&
	test "$collide2" = "$collide3"
'

test_expect_success 'respect core.abbrev' '
	shit config core.abbrev 12 &&
	(
		set_cat_todo_editor &&
		test_must_fail shit rebase -i HEAD~4 >todo-list
	) &&
	test 4 = $(grep -c -E "pick [0-9a-f]{12,}" todo-list)
'

test_expect_success 'todo count' '
	write_script dump-raw.sh <<-\EOF &&
		cat "$1"
	EOF
	(
		test_set_editor "$(pwd)/dump-raw.sh" &&
		shit rebase -i HEAD~4 >actual
	) &&
	test_grep "^# Rebase ..* onto ..* ([0-9]" actual
'

test_expect_success 'rebase -i commits that overwrite untracked files (pick)' '
	shit checkout --force A &&
	shit clean -f &&
	cat >todo <<-EOF &&
	exec >file2
	pick $(shit rev-parse B) B
	pick $(shit rev-parse C) C
	pick $(shit rev-parse D) D
	exec cat .shit/rebase-merge/done >actual
	EOF
	(
		set_replace_editor todo &&
		test_must_fail shit rebase -i A
	) &&
	test_cmp_rev HEAD B &&
	test_cmp_rev REBASE_HEAD C &&
	head -n3 todo >expect &&
	test_cmp expect .shit/rebase-merge/done &&
	rm file2 &&
	test_path_is_missing .shit/rebase-merge/patch &&
	echo changed >file1 &&
	shit add file1 &&
	test_must_fail shit rebase --continue 2>err &&
	grep "error: you have staged changes in your working tree" err &&
	shit reset --hard HEAD &&
	shit rebase --continue &&
	test_cmp_rev HEAD D &&
	tail -n3 todo >>expect &&
	test_cmp expect actual
'

test_expect_success 'rebase -i commits that overwrite untracked files (squash)' '
	shit checkout --force branch2 &&
	shit clean -f &&
	shit tag original-branch2 &&
	(
		set_fake_editor &&
		FAKE_LINES="edit 1 squash 2" shit rebase -i A
	) &&
	test_cmp_rev HEAD F &&
	test_path_is_missing file6 &&
	>file6 &&
	test_must_fail shit rebase --continue &&
	test_cmp_rev HEAD F &&
	test_cmp_rev REBASE_HEAD I &&
	rm file6 &&
	test_path_is_missing .shit/rebase-merge/patch &&
	echo changed >file1 &&
	shit add file1 &&
	test_must_fail shit rebase --continue 2>err &&
	grep "error: you have staged changes in your working tree" err &&
	shit reset --hard HEAD &&
	shit rebase --continue &&
	test $(shit cat-file commit HEAD | sed -ne \$p) = I &&
	shit reset --hard original-branch2
'

test_expect_success 'rebase -i commits that overwrite untracked files (no ff)' '
	shit checkout --force branch2 &&
	shit clean -f &&
	(
		set_fake_editor &&
		FAKE_LINES="edit 1 2" shit rebase -i --no-ff A
	) &&
	test $(shit cat-file commit HEAD | sed -ne \$p) = F &&
	test_path_is_missing file6 &&
	>file6 &&
	test_must_fail shit rebase --continue &&
	test $(shit cat-file commit HEAD | sed -ne \$p) = F &&
	test_cmp_rev REBASE_HEAD I &&
	rm file6 &&
	test_path_is_missing .shit/rebase-merge/patch &&
	echo changed >file1 &&
	shit add file1 &&
	test_must_fail shit rebase --continue 2>err &&
	grep "error: you have staged changes in your working tree" err &&
	shit reset --hard HEAD &&
	shit rebase --continue &&
	test $(shit cat-file commit HEAD | sed -ne \$p) = I
'

test_expect_success 'rebase --continue removes CHERRY_PICK_HEAD' '
	shit checkout -b commit-to-skip &&
	for double in X 3 1
	do
		test_seq 5 | sed "s/$double/&&/" >seq &&
		shit add seq &&
		test_tick &&
		shit commit -m seq-$double || return 1
	done &&
	shit tag seq-onto &&
	shit reset --hard HEAD~2 &&
	shit cherry-pick seq-onto &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES= shit rebase -i seq-onto
	) &&
	test -d .shit/rebase-merge &&
	shit rebase --continue &&
	shit diff --exit-code seq-onto &&
	test ! -d .shit/rebase-merge &&
	test ! -f .shit/CHERRY_PICK_HEAD
'

rebase_setup_and_clean () {
	test_when_finished "
		shit checkout primary &&
		test_might_fail shit branch -D $1 &&
		test_might_fail shit rebase --abort
	" &&
	shit checkout -b $1 ${2:-primary}
}

test_expect_success 'drop' '
	rebase_setup_and_clean drop-test &&
	(
		set_fake_editor &&
		FAKE_LINES="1 drop 2 3 d 4 5" shit rebase -i --root
	) &&
	test E = $(shit cat-file commit HEAD | sed -ne \$p) &&
	test C = $(shit cat-file commit HEAD^ | sed -ne \$p) &&
	test A = $(shit cat-file commit HEAD^^ | sed -ne \$p)
'

test_expect_success 'rebase -i respects rebase.missingCommitsCheck = ignore' '
	test_config rebase.missingCommitsCheck ignore &&
	rebase_setup_and_clean missing-commit &&
	(
		set_fake_editor &&
		FAKE_LINES="1 2 3 4" shit rebase -i --root 2>actual
	) &&
	test D = $(shit cat-file commit HEAD | sed -ne \$p) &&
	test_grep \
		"Successfully rebased and updated refs/heads/missing-commit" \
		actual
'

test_expect_success 'rebase -i respects rebase.missingCommitsCheck = warn' '
	cat >expect <<-EOF &&
	Warning: some commits may have been dropped accidentally.
	Dropped commits (newer to older):
	 - $(shit rev-list --pretty=oneline --abbrev-commit -1 primary)
	To avoid this message, use "drop" to explicitly remove a commit.
	EOF
	test_config rebase.missingCommitsCheck warn &&
	rebase_setup_and_clean missing-commit &&
	(
		set_fake_editor &&
		FAKE_LINES="1 2 3 4" shit rebase -i --root 2>actual.2
	) &&
	head -n4 actual.2 >actual &&
	test_cmp expect actual &&
	test D = $(shit cat-file commit HEAD | sed -ne \$p)
'

test_expect_success 'rebase -i respects rebase.missingCommitsCheck = error' '
	cat >expect <<-EOF &&
	Warning: some commits may have been dropped accidentally.
	Dropped commits (newer to older):
	 - $(shit rev-list --pretty=oneline --abbrev-commit -1 primary)
	 - $(shit rev-list --pretty=oneline --abbrev-commit -1 primary~2)
	To avoid this message, use "drop" to explicitly remove a commit.

	Use '\''shit config rebase.missingCommitsCheck'\'' to change the level of warnings.
	The possible behaviours are: ignore, warn, error.

	You can fix this with '\''shit rebase --edit-todo'\'' and then run '\''shit rebase --continue'\''.
	Or you can abort the rebase with '\''shit rebase --abort'\''.
	EOF
	test_config rebase.missingCommitsCheck error &&
	rebase_setup_and_clean missing-commit &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="1 2 4" \
			shit rebase -i --root 2>actual &&
		test_cmp expect actual &&
		cp .shit/rebase-merge/shit-rebase-todo.backup \
			.shit/rebase-merge/shit-rebase-todo &&
		FAKE_LINES="1 2 drop 3 4 drop 5" shit rebase --edit-todo
	) &&
	shit rebase --continue &&
	test D = $(shit cat-file commit HEAD | sed -ne \$p) &&
	test B = $(shit cat-file commit HEAD^ | sed -ne \$p)
'

test_expect_success 'rebase --edit-todo respects rebase.missingCommitsCheck = ignore' '
	test_config rebase.missingCommitsCheck ignore &&
	rebase_setup_and_clean missing-commit &&
	(
		set_fake_editor &&
		FAKE_LINES="break 1 2 3 4 5" shit rebase -i --root &&
		FAKE_LINES="1 2 3 4" shit rebase --edit-todo &&
		shit rebase --continue 2>actual
	) &&
	test D = $(shit cat-file commit HEAD | sed -ne \$p) &&
	test_grep \
		"Successfully rebased and updated refs/heads/missing-commit" \
		actual
'

test_expect_success 'rebase --edit-todo respects rebase.missingCommitsCheck = warn' '
	cat >expect <<-EOF &&
	error: invalid command '\''pickled'\''
	error: invalid line 1: pickled $(shit rev-list --pretty=oneline --abbrev-commit -1 primary~4)
	Warning: some commits may have been dropped accidentally.
	Dropped commits (newer to older):
	 - $(shit rev-list --pretty=oneline --abbrev-commit -1 primary)
	 - $(shit rev-list --pretty=oneline --abbrev-commit -1 primary~4)
	To avoid this message, use "drop" to explicitly remove a commit.
	EOF
	head -n5 expect >expect.2 &&
	tail -n1 expect >>expect.2 &&
	tail -n4 expect.2 >expect.3 &&
	test_config rebase.missingCommitsCheck warn &&
	rebase_setup_and_clean missing-commit &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="bad 1 2 3 4 5" \
			shit rebase -i --root &&
		cp .shit/rebase-merge/shit-rebase-todo.backup orig &&
		FAKE_LINES="2 3 4" shit rebase --edit-todo 2>actual.2 &&
		head -n7 actual.2 >actual &&
		test_cmp expect actual &&
		cp orig .shit/rebase-merge/shit-rebase-todo &&
		FAKE_LINES="1 2 3 4" shit rebase --edit-todo 2>actual.2 &&
		head -n4 actual.2 >actual &&
		test_cmp expect.3 actual &&
		shit rebase --continue 2>actual
	) &&
	test D = $(shit cat-file commit HEAD | sed -ne \$p) &&
	test_grep \
		"Successfully rebased and updated refs/heads/missing-commit" \
		actual
'

test_expect_success 'rebase --edit-todo respects rebase.missingCommitsCheck = error' '
	cat >expect <<-EOF &&
	error: invalid command '\''pickled'\''
	error: invalid line 1: pickled $(shit rev-list --pretty=oneline --abbrev-commit -1 primary~4)
	Warning: some commits may have been dropped accidentally.
	Dropped commits (newer to older):
	 - $(shit rev-list --pretty=oneline --abbrev-commit -1 primary)
	 - $(shit rev-list --pretty=oneline --abbrev-commit -1 primary~4)
	To avoid this message, use "drop" to explicitly remove a commit.

	Use '\''shit config rebase.missingCommitsCheck'\'' to change the level of warnings.
	The possible behaviours are: ignore, warn, error.

	You can fix this with '\''shit rebase --edit-todo'\'' and then run '\''shit rebase --continue'\''.
	Or you can abort the rebase with '\''shit rebase --abort'\''.
	EOF
	tail -n11 expect >expect.2 &&
	head -n3 expect.2 >expect.3 &&
	tail -n7 expect.2 >>expect.3 &&
	test_config rebase.missingCommitsCheck error &&
	rebase_setup_and_clean missing-commit &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="bad 1 2 3 4 5" \
			shit rebase -i --root &&
		cp .shit/rebase-merge/shit-rebase-todo.backup orig &&
		test_must_fail env FAKE_LINES="2 3 4" \
			shit rebase --edit-todo 2>actual &&
		test_cmp expect actual &&
		test_must_fail shit rebase --continue 2>actual &&
		test_cmp expect.2 actual &&
		test_must_fail shit rebase --edit-todo &&
		cp orig .shit/rebase-merge/shit-rebase-todo &&
		test_must_fail env FAKE_LINES="1 2 3 4" \
			shit rebase --edit-todo 2>actual &&
		test_cmp expect.3 actual &&
		test_must_fail shit rebase --continue 2>actual &&
		test_cmp expect.3 actual &&
		cp orig .shit/rebase-merge/shit-rebase-todo &&
		FAKE_LINES="1 2 3 4 drop 5" shit rebase --edit-todo &&
		shit rebase --continue 2>actual
	) &&
	test D = $(shit cat-file commit HEAD | sed -ne \$p) &&
	test_grep \
		"Successfully rebased and updated refs/heads/missing-commit" \
		actual
'

test_expect_success 'rebase.missingCommitsCheck = error after resolving conflicts' '
	test_config rebase.missingCommitsCheck error &&
	(
		set_fake_editor &&
		FAKE_LINES="drop 1 break 2 3 4" shit rebase -i A E
	) &&
	shit rebase --edit-todo &&
	test_must_fail shit rebase --continue &&
	echo x >file1 &&
	shit add file1 &&
	shit rebase --continue
'

test_expect_success 'rebase.missingCommitsCheck = error when editing for a second time' '
	test_config rebase.missingCommitsCheck error &&
	(
		set_fake_editor &&
		FAKE_LINES="1 break 2 3" shit rebase -i A D &&
		cp .shit/rebase-merge/shit-rebase-todo todo &&
		test_must_fail env FAKE_LINES=2 shit rebase --edit-todo &&
		shit_SEQUENCE_EDITOR="cp todo" shit rebase --edit-todo &&
		shit rebase --continue
	)
'

test_expect_success 'respects rebase.abbreviateCommands with fixup, squash and exec' '
	rebase_setup_and_clean abbrevcmd &&
	test_commit "first" file1.txt "first line" first &&
	test_commit "second" file1.txt "another line" second &&
	test_commit "fixup! first" file2.txt "first line again" first_fixup &&
	test_commit "squash! second" file1.txt "another line here" second_squash &&
	cat >expected <<-EOF &&
	p $(shit rev-list --abbrev-commit -1 first) first
	f $(shit rev-list --abbrev-commit -1 first_fixup) fixup! first
	x shit show HEAD
	p $(shit rev-list --abbrev-commit -1 second) second
	s $(shit rev-list --abbrev-commit -1 second_squash) squash! second
	x shit show HEAD
	EOF
	shit checkout abbrevcmd &&
	test_config rebase.abbreviateCommands true &&
	(
		set_cat_todo_editor &&
		test_must_fail shit rebase -i --exec "shit show HEAD" \
			--autosquash primary >actual
	) &&
	test_cmp expected actual
'

test_expect_success 'static check of bad command' '
	rebase_setup_and_clean bad-cmd &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="1 2 3 bad 4 5" \
		shit rebase -i --root 2>actual &&
		test_grep "pickled $(shit rev-list --oneline -1 primary~1)" \
				actual &&
		test_grep "You can fix this with .shit rebase --edit-todo.." \
				actual &&
		FAKE_LINES="1 2 3 drop 4 5" shit rebase --edit-todo
	) &&
	shit rebase --continue &&
	test E = $(shit cat-file commit HEAD | sed -ne \$p) &&
	test C = $(shit cat-file commit HEAD^ | sed -ne \$p)
'

test_expect_success 'the first command cannot be a fixup' '
	rebase_setup_and_clean fixup-first &&

	cat >orig <<-EOF &&
	fixup $(shit log -1 --format="%h %s" B)
	pick $(shit log -1 --format="%h %s" C)
	EOF

	(
		set_replace_editor orig &&
		test_must_fail shit rebase -i A 2>actual
	) &&
	grep "cannot .fixup. without a previous commit" actual &&
	grep "You can fix this with .shit rebase --edit-todo.." actual &&
	# verify that the todo list has not been truncated
	grep -v "^#" .shit/rebase-merge/shit-rebase-todo >actual &&
	test_cmp orig actual &&

	test_must_fail shit rebase --edit-todo 2>actual &&
	grep "cannot .fixup. without a previous commit" actual &&
	grep "You can fix this with .shit rebase --edit-todo.." actual &&
	# verify that the todo list has not been truncated
	grep -v "^#" .shit/rebase-merge/shit-rebase-todo >actual &&
	test_cmp orig actual
'

test_expect_success 'tabs and spaces are accepted in the todolist' '
	rebase_setup_and_clean indented-comment &&
	write_script add-indent.sh <<-\EOF &&
	(
		# Turn single spaces into space/tab mix
		sed "1s/ /	/g; 2s/ /  /g; 3s/ / 	/g" "$1"
		printf "\n\t# comment\n #more\n\t # comment\n"
	) >"$1.new"
	mv "$1.new" "$1"
	EOF
	(
		test_set_editor "$(pwd)/add-indent.sh" &&
		shit rebase -i HEAD^^^
	) &&
	test E = $(shit cat-file commit HEAD | sed -ne \$p)
'

test_expect_success 'static check of bad SHA-1' '
	rebase_setup_and_clean bad-sha &&
	(
		set_fake_editor &&
		test_must_fail env FAKE_LINES="1 2 edit fakesha 3 4 5 #" \
			shit rebase -i --root 2>actual &&
			test_grep "edit XXXXXXX False commit" actual &&
			test_grep "You can fix this with .shit rebase --edit-todo.." \
					actual &&
		FAKE_LINES="1 2 4 5 6" shit rebase --edit-todo
	) &&
	shit rebase --continue &&
	test E = $(shit cat-file commit HEAD | sed -ne \$p)
'

test_expect_success 'editor saves as CR/LF' '
	shit checkout -b with-crlf &&
	write_script add-crs.sh <<-\EOF &&
	sed -e "s/\$/Q/" <"$1" | tr Q "\\015" >"$1".new &&
	mv -f "$1".new "$1"
	EOF
	(
		test_set_editor "$(pwd)/add-crs.sh" &&
		shit rebase -i HEAD^
	)
'

test_expect_success 'rebase -i --gpg-sign=<key-id>' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	(
		set_fake_editor &&
		FAKE_LINES="edit 1" shit rebase -i --gpg-sign="\"S I Gner\"" \
			HEAD^ >out 2>err
	) &&
	test_grep "$SQ-S\"S I Gner\"$SQ" err
'

test_expect_success 'rebase -i --gpg-sign=<key-id> overrides commit.gpgSign' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	test_config commit.gpgsign true &&
	(
		set_fake_editor &&
		FAKE_LINES="edit 1" shit rebase -i --gpg-sign="\"S I Gner\"" \
			HEAD^ >out 2>err
	) &&
	test_grep "$SQ-S\"S I Gner\"$SQ" err
'

test_expect_success 'valid author header after --root swap' '
	rebase_setup_and_clean author-header no-conflict-branch &&
	shit commit --amend --author="Au ${SQ}thor <author@example.com>" --no-edit &&
	shit cat-file commit HEAD | grep ^author >expected &&
	(
		set_fake_editor &&
		FAKE_LINES="5 1" shit rebase -i --root
	) &&
	shit cat-file commit HEAD^ | grep ^author >actual &&
	test_cmp expected actual
'

test_expect_success 'valid author header when author contains single quote' '
	rebase_setup_and_clean author-header no-conflict-branch &&
	shit commit --amend --author="Au ${SQ}thor <author@example.com>" --no-edit &&
	shit cat-file commit HEAD | grep ^author >expected &&
	(
		set_fake_editor &&
		FAKE_LINES="2" shit rebase -i HEAD~2
	) &&
	shit cat-file commit HEAD | grep ^author >actual &&
	test_cmp expected actual
'

test_expect_success 'post-commit hook is called' '
	>actual &&
	test_hook post-commit <<-\EOS &&
	shit rev-parse HEAD >>actual
	EOS
	(
		set_fake_editor &&
		FAKE_LINES="edit 4 1 reword 2 fixup 3" shit rebase -i A E &&
		echo x>file3 &&
		shit add file3 &&
		FAKE_COMMIT_MESSAGE=edited shit rebase --continue
	) &&
	shit rev-parse HEAD@{5} HEAD@{4} HEAD@{3} HEAD@{2} HEAD@{1} HEAD \
		>expect &&
	test_cmp expect actual
'

test_expect_success 'correct error message for partial commit after empty pick' '
	test_when_finished "shit rebase --abort" &&
	(
		set_fake_editor &&
		FAKE_LINES="2 1 1" &&
		export FAKE_LINES &&
		test_must_fail shit rebase -i A D
	) &&
	echo x >file1 &&
	test_must_fail shit commit file1 2>err &&
	test_grep "cannot do a partial commit during a rebase." err
'

test_expect_success 'correct error message for commit --amend after empty pick' '
	test_when_finished "shit rebase --abort" &&
	(
		set_fake_editor &&
		FAKE_LINES="1 1" &&
		export FAKE_LINES &&
		test_must_fail shit rebase -i A D
	) &&
	echo x>file1 &&
	test_must_fail shit commit -a --amend 2>err &&
	test_grep "middle of a rebase -- cannot amend." err
'

test_expect_success 'todo has correct onto hash' '
	shit_SEQUENCE_EDITOR=cat shit rebase -i no-conflict-branch~4 no-conflict-branch >actual &&
	onto=$(shit rev-parse --short HEAD~4) &&
	test_grep "^# Rebase ..* onto $onto" actual
'

test_expect_success 'ORIG_HEAD is updated correctly' '
	test_when_finished "shit checkout primary && shit branch -D test-orig-head" &&
	shit checkout -b test-orig-head A &&
	shit commit --allow-empty -m A1 &&
	shit commit --allow-empty -m A2 &&
	shit commit --allow-empty -m A3 &&
	shit commit --allow-empty -m A4 &&
	shit rebase primary &&
	test_cmp_rev ORIG_HEAD test-orig-head@{1}
'

test_expect_success '--update-refs adds label and update-ref commands' '
	shit checkout -b update-refs no-conflict-branch &&
	shit branch -f base HEAD~4 &&
	shit branch -f first HEAD~3 &&
	shit branch -f second HEAD~3 &&
	shit branch -f third HEAD~1 &&
	shit commit --allow-empty --fixup=third &&
	shit branch -f is-not-reordered &&
	shit commit --allow-empty --fixup=HEAD~4 &&
	shit branch -f shared-tip &&
	(
		set_cat_todo_editor &&

		cat >expect <<-EOF &&
		pick $(shit log -1 --format=%h J) J
		fixup $(shit log -1 --format=%h update-refs) fixup! J # empty
		update-ref refs/heads/second
		update-ref refs/heads/first
		pick $(shit log -1 --format=%h K) K
		pick $(shit log -1 --format=%h L) L
		fixup $(shit log -1 --format=%h is-not-reordered) fixup! L # empty
		update-ref refs/heads/third
		pick $(shit log -1 --format=%h M) M
		update-ref refs/heads/no-conflict-branch
		update-ref refs/heads/is-not-reordered
		update-ref refs/heads/shared-tip
		EOF

		test_must_fail shit rebase -i --autosquash --update-refs primary >todo &&
		test_cmp expect todo &&

		test_must_fail shit -c rebase.autosquash=true \
				   -c rebase.updaterefs=true \
				   rebase -i primary >todo &&

		test_cmp expect todo
	)
'

test_expect_success '--update-refs adds commands with --rebase-merges' '
	shit checkout -b update-refs-with-merge no-conflict-branch &&
	shit branch -f base HEAD~4 &&
	shit branch -f first HEAD~3 &&
	shit branch -f second HEAD~3 &&
	shit branch -f third HEAD~1 &&
	shit merge -m merge branch2 &&
	shit branch -f merge-branch &&
	shit commit --fixup=third --allow-empty &&
	(
		set_cat_todo_editor &&

		cat >expect <<-EOF &&
		label onto
		reset onto
		pick $(shit log -1 --format=%h branch2~1) F
		pick $(shit log -1 --format=%h branch2) I
		update-ref refs/heads/branch2
		label merge
		reset onto
		pick $(shit log -1 --format=%h refs/heads/second) J
		update-ref refs/heads/second
		update-ref refs/heads/first
		pick $(shit log -1 --format=%h refs/heads/third~1) K
		pick $(shit log -1 --format=%h refs/heads/third) L
		fixup $(shit log -1 --format=%h update-refs-with-merge) fixup! L # empty
		update-ref refs/heads/third
		pick $(shit log -1 --format=%h HEAD~2) M
		update-ref refs/heads/no-conflict-branch
		merge -C $(shit log -1 --format=%h HEAD~1) merge # merge
		update-ref refs/heads/merge-branch
		EOF

		test_must_fail shit rebase -i --autosquash \
				   --rebase-merges=rebase-cousins \
				   --update-refs primary >todo &&

		test_cmp expect todo &&

		test_must_fail shit -c rebase.autosquash=true \
				   -c rebase.updaterefs=true \
				   rebase -i \
				   --rebase-merges=rebase-cousins \
				   primary >todo &&

		test_cmp expect todo
	)
'

test_expect_success '--update-refs updates refs correctly' '
	shit checkout -B update-refs no-conflict-branch &&
	shit branch -f base HEAD~4 &&
	shit branch -f first HEAD~3 &&
	shit branch -f second HEAD~3 &&
	shit branch -f third HEAD~1 &&
	test_commit extra2 fileX &&
	shit commit --amend --fixup=L &&

	shit rebase -i --autosquash --update-refs primary 2>err &&

	test_cmp_rev HEAD~3 refs/heads/first &&
	test_cmp_rev HEAD~3 refs/heads/second &&
	test_cmp_rev HEAD~1 refs/heads/third &&
	test_cmp_rev HEAD refs/heads/no-conflict-branch &&

	cat >expect <<-\EOF &&
	Successfully rebased and updated refs/heads/update-refs.
	Updated the following refs with --update-refs:
		refs/heads/first
		refs/heads/no-conflict-branch
		refs/heads/second
		refs/heads/third
	EOF

	# Clear "Rebasing (X/Y)" progress lines and drop leading tabs.
	sed -e "s/Rebasing.*Successfully/Successfully/g" -e "s/^\t//g" \
		<err >err.trimmed &&
	test_cmp expect err.trimmed
'

test_expect_success 'respect user edits to update-ref steps' '
	shit checkout -B update-refs-break no-conflict-branch &&
	shit branch -f base HEAD~4 &&
	shit branch -f first HEAD~3 &&
	shit branch -f second HEAD~3 &&
	shit branch -f third HEAD~1 &&
	shit branch -f unseen base &&

	# First, we will add breaks to the expected todo file
	cat >fake-todo-1 <<-EOF &&
	pick $(shit rev-parse HEAD~3)
	break
	update-ref refs/heads/second
	update-ref refs/heads/first

	pick $(shit rev-parse HEAD~2)
	pick $(shit rev-parse HEAD~1)
	update-ref refs/heads/third

	pick $(shit rev-parse HEAD)
	update-ref refs/heads/no-conflict-branch
	EOF

	# Second, we will drop some update-refs commands (and move one)
	cat >fake-todo-2 <<-EOF &&
	update-ref refs/heads/second

	pick $(shit rev-parse HEAD~2)
	update-ref refs/heads/third
	pick $(shit rev-parse HEAD~1)
	break

	pick $(shit rev-parse HEAD)
	EOF

	# Third, we will:
	# * insert a new one (new-branch),
	# * re-add an old one (first), and
	# * add a second instance of a previously-stored one (second)
	cat >fake-todo-3 <<-EOF &&
	update-ref refs/heads/unseen
	update-ref refs/heads/new-branch
	pick $(shit rev-parse HEAD)
	update-ref refs/heads/first
	update-ref refs/heads/second
	EOF

	(
		set_replace_editor fake-todo-1 &&
		shit rebase -i --update-refs primary &&

		# These branches are currently locked.
		for b in first second third no-conflict-branch
		do
			test_must_fail shit branch -f $b base || return 1
		done &&

		set_replace_editor fake-todo-2 &&
		shit rebase --edit-todo &&

		# These branches are currently locked.
		for b in second third
		do
			test_must_fail shit branch -f $b base || return 1
		done &&

		# These branches are currently unlocked for checkout.
		for b in first no-conflict-branch
		do
			shit worktree add wt-$b $b &&
			shit worktree remove wt-$b || return 1
		done &&

		shit rebase --continue &&

		set_replace_editor fake-todo-3 &&
		shit rebase --edit-todo &&

		# These branches are currently locked.
		for b in second third first unseen
		do
			test_must_fail shit branch -f $b base || return 1
		done &&

		# These branches are currently unlocked for checkout.
		for b in no-conflict-branch
		do
			shit worktree add wt-$b $b &&
			shit worktree remove wt-$b || return 1
		done &&

		shit rebase --continue
	) &&

	test_cmp_rev HEAD~2 refs/heads/third &&
	test_cmp_rev HEAD~1 refs/heads/unseen &&
	test_cmp_rev HEAD~1 refs/heads/new-branch &&
	test_cmp_rev HEAD refs/heads/first &&
	test_cmp_rev HEAD refs/heads/second &&
	test_cmp_rev HEAD refs/heads/no-conflict-branch
'

test_expect_success '--update-refs: all update-ref lines removed' '
	shit checkout -b test-refs-not-removed no-conflict-branch &&
	shit branch -f base HEAD~4 &&
	shit branch -f first HEAD~3 &&
	shit branch -f second HEAD~3 &&
	shit branch -f third HEAD~1 &&
	shit branch -f tip &&

	test_commit test-refs-not-removed &&
	shit commit --amend --fixup first &&

	shit rev-parse first second third tip no-conflict-branch >expect-oids &&

	(
		set_cat_todo_editor &&
		test_must_fail shit rebase -i --update-refs base >todo.raw &&
		sed -e "/^update-ref/d" <todo.raw >todo
	) &&
	(
		set_replace_editor todo &&
		shit rebase -i --update-refs base
	) &&

	# Ensure refs are not deleted and their OIDs have not changed
	shit rev-parse first second third tip no-conflict-branch >actual-oids &&
	test_cmp expect-oids actual-oids
'

test_expect_success '--update-refs: all update-ref lines removed, then some re-added' '
	shit checkout -b test-refs-not-removed2 no-conflict-branch &&
	shit branch -f base HEAD~4 &&
	shit branch -f first HEAD~3 &&
	shit branch -f second HEAD~3 &&
	shit branch -f third HEAD~1 &&
	shit branch -f tip &&

	test_commit test-refs-not-removed2 &&
	shit commit --amend --fixup first &&

	shit rev-parse first second third >expect-oids &&

	(
		set_cat_todo_editor &&
		test_must_fail shit rebase -i \
			--autosquash --update-refs \
			base >todo.raw &&
		sed -e "/^update-ref/d" <todo.raw >todo
	) &&

	# Add a break to the end of the todo so we can edit later
	echo "break" >>todo &&

	(
		set_replace_editor todo &&
		shit rebase -i --autosquash --update-refs base &&
		echo "update-ref refs/heads/tip" >todo &&
		shit rebase --edit-todo &&
		shit rebase --continue
	) &&

	# Ensure first/second/third are unchanged, but tip is updated
	shit rev-parse first second third >actual-oids &&
	test_cmp expect-oids actual-oids &&
	test_cmp_rev HEAD tip
'

test_expect_success '--update-refs: --edit-todo with no update-ref lines' '
	shit checkout -b test-refs-not-removed3 no-conflict-branch &&
	shit branch -f base HEAD~4 &&
	shit branch -f first HEAD~3 &&
	shit branch -f second HEAD~3 &&
	shit branch -f third HEAD~1 &&
	shit branch -f tip &&

	test_commit test-refs-not-removed3 &&
	shit commit --amend --fixup first &&

	shit rev-parse first second third tip no-conflict-branch >expect-oids &&

	(
		set_cat_todo_editor &&
		test_must_fail shit rebase -i \
			--autosquash --update-refs \
			base >todo.raw &&
		sed -e "/^update-ref/d" <todo.raw >todo
	) &&

	# Add a break to the beginning of the todo so we can resume with no
	# update-ref lines
	echo "break" >todo.new &&
	cat todo >>todo.new &&

	(
		set_replace_editor todo.new &&
		shit rebase -i --autosquash --update-refs base &&

		# Make no changes when editing so update-refs is still empty
		cat todo >todo.new &&
		shit rebase --edit-todo &&
		shit rebase --continue
	) &&

	# Ensure refs are not deleted and their OIDs have not changed
	shit rev-parse first second third tip no-conflict-branch >actual-oids &&
	test_cmp expect-oids actual-oids
'

test_expect_success '--update-refs: check failed ref update' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	shit checkout -B update-refs-error no-conflict-branch &&
	shit branch -f base HEAD~4 &&
	shit branch -f first HEAD~3 &&
	shit branch -f second HEAD~2 &&
	shit branch -f third HEAD~1 &&

	cat >fake-todo <<-EOF &&
	pick $(shit rev-parse HEAD~3)
	break
	update-ref refs/heads/first

	pick $(shit rev-parse HEAD~2)
	update-ref refs/heads/second

	pick $(shit rev-parse HEAD~1)
	update-ref refs/heads/third

	pick $(shit rev-parse HEAD)
	update-ref refs/heads/no-conflict-branch
	EOF

	(
		set_replace_editor fake-todo &&
		shit rebase -i --update-refs base
	) &&

	# At this point, the values of first, second, and third are
	# recorded in the update-refs file. We will force-update the
	# "second" ref, but "shit branch -f" will not work because of
	# the lock in the update-refs file.
	shit update-ref refs/heads/second third &&

	test_must_fail shit rebase --continue 2>err &&
	grep "update_ref failed for ref '\''refs/heads/second'\''" err &&

	cat >expect <<-\EOF &&
	Updated the following refs with --update-refs:
		refs/heads/first
		refs/heads/no-conflict-branch
		refs/heads/third
	Failed to update the following refs with --update-refs:
		refs/heads/second
	EOF

	# Clear "Rebasing (X/Y)" progress lines and drop leading tabs.
	tail -n 6 err >err.last &&
	sed -e "s/Rebasing.*Successfully/Successfully/g" -e "s/^\t//g" \
		<err.last >err.trimmed &&
	test_cmp expect err.trimmed
'

test_expect_success 'bad labels and refs rejected when parsing todo list' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	cat >todo <<-\EOF &&
	exec >execed
	label #
	label :invalid
	update-ref :bad
	update-ref topic
	EOF
	rm -f execed &&
	(
		set_replace_editor todo &&
		test_must_fail shit rebase -i HEAD 2>err
	) &&
	grep "'\''#'\'' is not a valid label" err &&
	grep "'\'':invalid'\'' is not a valid label" err &&
	grep "'\'':bad'\'' is not a valid refname" err &&
	grep "update-ref requires a fully qualified refname e.g. refs/heads/topic" \
		err &&
	test_path_is_missing execed
'

# This must be the last test in this file
test_expect_success '$EDITOR and friends are unchanged' '
	test_editor_unchanged
'

test_done
