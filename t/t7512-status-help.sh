#!/bin/sh
#
# Copyright (c) 2012 Valentin Duperray, Lucien Kong, Franck Jonas,
#		     Thomas Nguy, Khoi Nguyen
#		     Grenoble INP Ensimag
#

test_description='shit status advice'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

. "$TEST_DIRECTORY"/lib-rebase.sh

set_fake_editor

test_expect_success 'prepare for conflicts' '
	shit config --global advice.statusuoption false &&
	test_commit init main.txt init &&
	shit branch conflicts &&
	test_commit on_main main.txt on_main &&
	shit checkout conflicts &&
	test_commit on_conflicts main.txt on_conflicts
'


test_expect_success 'status when conflicts unresolved' '
	test_must_fail shit merge main &&
	cat >expected <<\EOF &&
On branch conflicts
You have unmerged paths.
  (fix conflicts and run "shit commit")
  (use "shit merge --abort" to abort the merge)

Unmerged paths:
  (use "shit add <file>..." to mark resolution)
	both modified:   main.txt

no changes added to commit (use "shit add" and/or "shit commit -a")
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status when conflicts resolved before commit' '
	shit reset --hard conflicts &&
	test_must_fail shit merge main &&
	echo one >main.txt &&
	shit add main.txt &&
	cat >expected <<\EOF &&
On branch conflicts
All conflicts fixed but you are still merging.
  (use "shit commit" to conclude merge)

Changes to be committed:
	modified:   main.txt

Untracked files not listed (use -u option to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'prepare for rebase conflicts' '
	shit reset --hard main &&
	shit checkout -b rebase_conflicts &&
	test_commit one_rebase main.txt one &&
	test_commit two_rebase main.txt two &&
	test_commit three_rebase main.txt three
'


test_expect_success 'status when rebase --apply in progress before resolving conflicts' '
	test_when_finished "shit rebase --abort" &&
	ONTO=$(shit rev-parse --short HEAD^^) &&
	test_must_fail shit rebase --apply HEAD^ --onto HEAD^^ &&
	cat >expected <<EOF &&
rebase in progress; onto $ONTO
You are currently rebasing branch '\''rebase_conflicts'\'' on '\''$ONTO'\''.
  (fix conflicts and then run "shit rebase --continue")
  (use "shit rebase --skip" to skip this patch)
  (use "shit rebase --abort" to check out the original branch)

Unmerged paths:
  (use "shit restore --staged <file>..." to unstage)
  (use "shit add <file>..." to mark resolution)
	both modified:   main.txt

no changes added to commit (use "shit add" and/or "shit commit -a")
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status when rebase --apply in progress before rebase --continue' '
	shit reset --hard rebase_conflicts &&
	test_when_finished "shit rebase --abort" &&
	ONTO=$(shit rev-parse --short HEAD^^) &&
	test_must_fail shit rebase --apply HEAD^ --onto HEAD^^ &&
	echo three >main.txt &&
	shit add main.txt &&
	cat >expected <<EOF &&
rebase in progress; onto $ONTO
You are currently rebasing branch '\''rebase_conflicts'\'' on '\''$ONTO'\''.
  (all conflicts fixed: run "shit rebase --continue")

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	modified:   main.txt

Untracked files not listed (use -u option to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'prepare for rebase_i_conflicts' '
	shit reset --hard main &&
	shit checkout -b rebase_i_conflicts &&
	test_commit one_unmerge main.txt one_unmerge &&
	shit branch rebase_i_conflicts_second &&
	test_commit one_main main.txt one_main &&
	shit checkout rebase_i_conflicts_second &&
	test_commit one_second main.txt one_second
'


test_expect_success 'status during rebase -i when conflicts unresolved' '
	test_when_finished "shit rebase --abort" &&
	ONTO=$(shit rev-parse --short rebase_i_conflicts) &&
	LAST_COMMIT=$(shit rev-parse --short rebase_i_conflicts_second) &&
	test_must_fail shit rebase -i rebase_i_conflicts &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last command done (1 command done):
   pick $LAST_COMMIT one_second
No commands remaining.
You are currently rebasing branch '\''rebase_i_conflicts_second'\'' on '\''$ONTO'\''.
  (fix conflicts and then run "shit rebase --continue")
  (use "shit rebase --skip" to skip this patch)
  (use "shit rebase --abort" to check out the original branch)

Unmerged paths:
  (use "shit restore --staged <file>..." to unstage)
  (use "shit add <file>..." to mark resolution)
	both modified:   main.txt

no changes added to commit (use "shit add" and/or "shit commit -a")
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status during rebase -i after resolving conflicts' '
	shit reset --hard rebase_i_conflicts_second &&
	test_when_finished "shit rebase --abort" &&
	ONTO=$(shit rev-parse --short rebase_i_conflicts) &&
	LAST_COMMIT=$(shit rev-parse --short rebase_i_conflicts_second) &&
	test_must_fail shit rebase -i rebase_i_conflicts &&
	shit add main.txt &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last command done (1 command done):
   pick $LAST_COMMIT one_second
No commands remaining.
You are currently rebasing branch '\''rebase_i_conflicts_second'\'' on '\''$ONTO'\''.
  (all conflicts fixed: run "shit rebase --continue")

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	modified:   main.txt

Untracked files not listed (use -u option to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status when rebasing -i in edit mode' '
	shit reset --hard main &&
	shit checkout -b rebase_i_edit &&
	test_commit one_rebase_i main.txt one &&
	test_commit two_rebase_i main.txt two &&
	COMMIT2=$(shit rev-parse --short rebase_i_edit) &&
	test_commit three_rebase_i main.txt three &&
	COMMIT3=$(shit rev-parse --short rebase_i_edit) &&
	FAKE_LINES="1 edit 2" &&
	export FAKE_LINES &&
	test_when_finished "shit rebase --abort" &&
	ONTO=$(shit rev-parse --short HEAD~2) &&
	shit rebase -i HEAD~2 &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last commands done (2 commands done):
   pick $COMMIT2 two_rebase_i
   edit $COMMIT3 three_rebase_i
No commands remaining.
You are currently editing a commit while rebasing branch '\''rebase_i_edit'\'' on '\''$ONTO'\''.
  (use "shit commit --amend" to amend the current commit)
  (use "shit rebase --continue" once you are satisfied with your changes)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status when splitting a commit' '
	shit reset --hard main &&
	shit checkout -b split_commit &&
	test_commit one_split main.txt one &&
	test_commit two_split main.txt two &&
	COMMIT2=$(shit rev-parse --short split_commit) &&
	test_commit three_split main.txt three &&
	COMMIT3=$(shit rev-parse --short split_commit) &&
	test_commit four_split main.txt four &&
	COMMIT4=$(shit rev-parse --short split_commit) &&
	FAKE_LINES="1 edit 2 3" &&
	export FAKE_LINES &&
	test_when_finished "shit rebase --abort" &&
	ONTO=$(shit rev-parse --short HEAD~3) &&
	shit rebase -i HEAD~3 &&
	shit reset HEAD^ &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last commands done (2 commands done):
   pick $COMMIT2 two_split
   edit $COMMIT3 three_split
Next command to do (1 remaining command):
   pick $COMMIT4 four_split
  (use "shit rebase --edit-todo" to view and edit)
You are currently splitting a commit while rebasing branch '\''split_commit'\'' on '\''$ONTO'\''.
  (Once your working directory is clean, run "shit rebase --continue")

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   main.txt

no changes added to commit (use "shit add" and/or "shit commit -a")
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status after editing the last commit with --amend during a rebase -i' '
	shit reset --hard main &&
	shit checkout -b amend_last &&
	test_commit one_amend main.txt one &&
	test_commit two_amend main.txt two &&
	test_commit three_amend main.txt three &&
	COMMIT3=$(shit rev-parse --short amend_last) &&
	test_commit four_amend main.txt four &&
	COMMIT4=$(shit rev-parse --short amend_last) &&
	FAKE_LINES="1 2 edit 3" &&
	export FAKE_LINES &&
	test_when_finished "shit rebase --abort" &&
	ONTO=$(shit rev-parse --short HEAD~3) &&
	shit rebase -i HEAD~3 &&
	shit commit --amend -m "foo" &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last commands done (3 commands done):
   pick $COMMIT3 three_amend
   edit $COMMIT4 four_amend
  (see more in file .shit/rebase-merge/done)
No commands remaining.
You are currently editing a commit while rebasing branch '\''amend_last'\'' on '\''$ONTO'\''.
  (use "shit commit --amend" to amend the current commit)
  (use "shit rebase --continue" once you are satisfied with your changes)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'prepare for several edits' '
	shit reset --hard main &&
	shit checkout -b several_edits &&
	test_commit one_edits main.txt one &&
	test_commit two_edits main.txt two &&
	test_commit three_edits main.txt three &&
	test_commit four_edits main.txt four
'


test_expect_success 'status: (continue first edit) second edit' '
	FAKE_LINES="edit 1 edit 2 3" &&
	export FAKE_LINES &&
	test_when_finished "shit rebase --abort" &&
	COMMIT2=$(shit rev-parse --short several_edits^^) &&
	COMMIT3=$(shit rev-parse --short several_edits^) &&
	COMMIT4=$(shit rev-parse --short several_edits) &&
	ONTO=$(shit rev-parse --short HEAD~3) &&
	shit rebase -i HEAD~3 &&
	shit rebase --continue &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last commands done (2 commands done):
   edit $COMMIT2 two_edits
   edit $COMMIT3 three_edits
Next command to do (1 remaining command):
   pick $COMMIT4 four_edits
  (use "shit rebase --edit-todo" to view and edit)
You are currently editing a commit while rebasing branch '\''several_edits'\'' on '\''$ONTO'\''.
  (use "shit commit --amend" to amend the current commit)
  (use "shit rebase --continue" once you are satisfied with your changes)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status: (continue first edit) second edit and split' '
	shit reset --hard several_edits &&
	FAKE_LINES="edit 1 edit 2 3" &&
	export FAKE_LINES &&
	test_when_finished "shit rebase --abort" &&
	COMMIT2=$(shit rev-parse --short several_edits^^) &&
	COMMIT3=$(shit rev-parse --short several_edits^) &&
	COMMIT4=$(shit rev-parse --short several_edits) &&
	ONTO=$(shit rev-parse --short HEAD~3) &&
	shit rebase -i HEAD~3 &&
	shit rebase --continue &&
	shit reset HEAD^ &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last commands done (2 commands done):
   edit $COMMIT2 two_edits
   edit $COMMIT3 three_edits
Next command to do (1 remaining command):
   pick $COMMIT4 four_edits
  (use "shit rebase --edit-todo" to view and edit)
You are currently splitting a commit while rebasing branch '\''several_edits'\'' on '\''$ONTO'\''.
  (Once your working directory is clean, run "shit rebase --continue")

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   main.txt

no changes added to commit (use "shit add" and/or "shit commit -a")
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status: (continue first edit) second edit and amend' '
	shit reset --hard several_edits &&
	FAKE_LINES="edit 1 edit 2 3" &&
	export FAKE_LINES &&
	test_when_finished "shit rebase --abort" &&
	COMMIT2=$(shit rev-parse --short several_edits^^) &&
	COMMIT3=$(shit rev-parse --short several_edits^) &&
	COMMIT4=$(shit rev-parse --short several_edits) &&
	ONTO=$(shit rev-parse --short HEAD~3) &&
	shit rebase -i HEAD~3 &&
	shit rebase --continue &&
	shit commit --amend -m "foo" &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last commands done (2 commands done):
   edit $COMMIT2 two_edits
   edit $COMMIT3 three_edits
Next command to do (1 remaining command):
   pick $COMMIT4 four_edits
  (use "shit rebase --edit-todo" to view and edit)
You are currently editing a commit while rebasing branch '\''several_edits'\'' on '\''$ONTO'\''.
  (use "shit commit --amend" to amend the current commit)
  (use "shit rebase --continue" once you are satisfied with your changes)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status: (amend first edit) second edit' '
	shit reset --hard several_edits &&
	FAKE_LINES="edit 1 edit 2 3" &&
	export FAKE_LINES &&
	test_when_finished "shit rebase --abort" &&
	COMMIT2=$(shit rev-parse --short several_edits^^) &&
	COMMIT3=$(shit rev-parse --short several_edits^) &&
	COMMIT4=$(shit rev-parse --short several_edits) &&
	ONTO=$(shit rev-parse --short HEAD~3) &&
	shit rebase -i HEAD~3 &&
	shit commit --amend -m "a" &&
	shit rebase --continue &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last commands done (2 commands done):
   edit $COMMIT2 two_edits
   edit $COMMIT3 three_edits
Next command to do (1 remaining command):
   pick $COMMIT4 four_edits
  (use "shit rebase --edit-todo" to view and edit)
You are currently editing a commit while rebasing branch '\''several_edits'\'' on '\''$ONTO'\''.
  (use "shit commit --amend" to amend the current commit)
  (use "shit rebase --continue" once you are satisfied with your changes)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status: (amend first edit) second edit and split' '
	shit reset --hard several_edits &&
	FAKE_LINES="edit 1 edit 2 3" &&
	export FAKE_LINES &&
	test_when_finished "shit rebase --abort" &&
	ONTO=$(shit rev-parse --short HEAD~3) &&
	COMMIT2=$(shit rev-parse --short several_edits^^) &&
	COMMIT3=$(shit rev-parse --short several_edits^) &&
	COMMIT4=$(shit rev-parse --short several_edits) &&
	shit rebase -i HEAD~3 &&
	shit commit --amend -m "b" &&
	shit rebase --continue &&
	shit reset HEAD^ &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last commands done (2 commands done):
   edit $COMMIT2 two_edits
   edit $COMMIT3 three_edits
Next command to do (1 remaining command):
   pick $COMMIT4 four_edits
  (use "shit rebase --edit-todo" to view and edit)
You are currently splitting a commit while rebasing branch '\''several_edits'\'' on '\''$ONTO'\''.
  (Once your working directory is clean, run "shit rebase --continue")

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   main.txt

no changes added to commit (use "shit add" and/or "shit commit -a")
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status: (amend first edit) second edit and amend' '
	shit reset --hard several_edits &&
	FAKE_LINES="edit 1 edit 2 3" &&
	export FAKE_LINES &&
	test_when_finished "shit rebase --abort" &&
	COMMIT2=$(shit rev-parse --short several_edits^^) &&
	COMMIT3=$(shit rev-parse --short several_edits^) &&
	COMMIT4=$(shit rev-parse --short several_edits) &&
	ONTO=$(shit rev-parse --short HEAD~3) &&
	shit rebase -i HEAD~3 &&
	shit commit --amend -m "c" &&
	shit rebase --continue &&
	shit commit --amend -m "d" &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last commands done (2 commands done):
   edit $COMMIT2 two_edits
   edit $COMMIT3 three_edits
Next command to do (1 remaining command):
   pick $COMMIT4 four_edits
  (use "shit rebase --edit-todo" to view and edit)
You are currently editing a commit while rebasing branch '\''several_edits'\'' on '\''$ONTO'\''.
  (use "shit commit --amend" to amend the current commit)
  (use "shit rebase --continue" once you are satisfied with your changes)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status: (split first edit) second edit' '
	shit reset --hard several_edits &&
	FAKE_LINES="edit 1 edit 2 3" &&
	export FAKE_LINES &&
	test_when_finished "shit rebase --abort" &&
	COMMIT2=$(shit rev-parse --short several_edits^^) &&
	COMMIT3=$(shit rev-parse --short several_edits^) &&
	COMMIT4=$(shit rev-parse --short several_edits) &&
	ONTO=$(shit rev-parse --short HEAD~3) &&
	shit rebase -i HEAD~3 &&
	shit reset HEAD^ &&
	shit add main.txt &&
	shit commit -m "e" &&
	shit rebase --continue &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last commands done (2 commands done):
   edit $COMMIT2 two_edits
   edit $COMMIT3 three_edits
Next command to do (1 remaining command):
   pick $COMMIT4 four_edits
  (use "shit rebase --edit-todo" to view and edit)
You are currently editing a commit while rebasing branch '\''several_edits'\'' on '\''$ONTO'\''.
  (use "shit commit --amend" to amend the current commit)
  (use "shit rebase --continue" once you are satisfied with your changes)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status: (split first edit) second edit and split' '
	shit reset --hard several_edits &&
	FAKE_LINES="edit 1 edit 2 3" &&
	export FAKE_LINES &&
	test_when_finished "shit rebase --abort" &&
	COMMIT2=$(shit rev-parse --short several_edits^^) &&
	COMMIT3=$(shit rev-parse --short several_edits^) &&
	COMMIT4=$(shit rev-parse --short several_edits) &&
	ONTO=$(shit rev-parse --short HEAD~3) &&
	shit rebase -i HEAD~3 &&
	shit reset HEAD^ &&
	shit add main.txt &&
	shit commit --amend -m "f" &&
	shit rebase --continue &&
	shit reset HEAD^ &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last commands done (2 commands done):
   edit $COMMIT2 two_edits
   edit $COMMIT3 three_edits
Next command to do (1 remaining command):
   pick $COMMIT4 four_edits
  (use "shit rebase --edit-todo" to view and edit)
You are currently splitting a commit while rebasing branch '\''several_edits'\'' on '\''$ONTO'\''.
  (Once your working directory is clean, run "shit rebase --continue")

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   main.txt

no changes added to commit (use "shit add" and/or "shit commit -a")
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status: (split first edit) second edit and amend' '
	shit reset --hard several_edits &&
	FAKE_LINES="edit 1 edit 2 3" &&
	export FAKE_LINES &&
	test_when_finished "shit rebase --abort" &&
	COMMIT2=$(shit rev-parse --short several_edits^^) &&
	COMMIT3=$(shit rev-parse --short several_edits^) &&
	COMMIT4=$(shit rev-parse --short several_edits) &&
	ONTO=$(shit rev-parse --short HEAD~3) &&
	shit rebase -i HEAD~3 &&
	shit reset HEAD^ &&
	shit add main.txt &&
	shit commit --amend -m "g" &&
	shit rebase --continue &&
	shit commit --amend -m "h" &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last commands done (2 commands done):
   edit $COMMIT2 two_edits
   edit $COMMIT3 three_edits
Next command to do (1 remaining command):
   pick $COMMIT4 four_edits
  (use "shit rebase --edit-todo" to view and edit)
You are currently editing a commit while rebasing branch '\''several_edits'\'' on '\''$ONTO'\''.
  (use "shit commit --amend" to amend the current commit)
  (use "shit rebase --continue" once you are satisfied with your changes)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'prepare am_session' '
	shit reset --hard main &&
	shit checkout -b am_session &&
	test_commit one_am one.txt "one" &&
	test_commit two_am two.txt "two" &&
	test_commit three_am three.txt "three"
'


test_expect_success 'status in an am session: file already exists' '
	shit checkout -b am_already_exists &&
	test_when_finished "rm Maildir/* && shit am --abort" &&
	shit format-patch -1 -oMaildir &&
	test_must_fail shit am Maildir/*.patch &&
	cat >expected <<\EOF &&
On branch am_already_exists
You are in the middle of an am session.
  (fix conflicts and then run "shit am --continue")
  (use "shit am --skip" to skip this patch)
  (use "shit am --abort" to restore the original branch)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status in an am session: file does not exist' '
	shit reset --hard am_session &&
	shit checkout -b am_not_exists &&
	shit rm three.txt &&
	shit commit -m "delete three.txt" &&
	test_when_finished "rm Maildir/* && shit am --abort" &&
	shit format-patch -1 -oMaildir &&
	test_must_fail shit am Maildir/*.patch &&
	cat >expected <<\EOF &&
On branch am_not_exists
You are in the middle of an am session.
  (fix conflicts and then run "shit am --continue")
  (use "shit am --skip" to skip this patch)
  (use "shit am --abort" to restore the original branch)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status in an am session: empty patch' '
	shit reset --hard am_session &&
	shit checkout -b am_empty &&
	test_when_finished "rm Maildir/* && shit am --abort" &&
	shit format-patch -3 -oMaildir &&
	shit rm one.txt two.txt three.txt &&
	shit commit -m "delete all am_empty" &&
	echo error >Maildir/0002-two_am.patch &&
	test_must_fail shit am Maildir/*.patch &&
	cat >expected <<\EOF &&
On branch am_empty
You are in the middle of an am session.
The current patch is empty.
  (use "shit am --skip" to skip this patch)
  (use "shit am --allow-empty" to record this patch as an empty commit)
  (use "shit am --abort" to restore the original branch)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status when bisecting' '
	shit reset --hard main &&
	shit checkout -b bisect &&
	test_commit one_bisect main.txt one &&
	test_commit two_bisect main.txt two &&
	test_commit three_bisect main.txt three &&
	test_when_finished "shit bisect reset" &&
	shit bisect start &&
	shit bisect bad &&
	shit bisect good one_bisect &&
	TGT=$(shit rev-parse --short two_bisect) &&
	cat >expected <<EOF &&
HEAD detached at $TGT
You are currently bisecting, started from branch '\''bisect'\''.
  (use "shit bisect reset" to get back to the original branch)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status when bisecting while rebasing' '
	shit reset --hard main &&
	test_when_finished "shit rebase --abort" &&
	ONTO=$(shit rev-parse --short HEAD^) &&
	FAKE_LINES="break" shit rebase -i HEAD^ &&
	test_when_finished "shit checkout -" &&
	shit checkout -b bisect_while_rebasing &&
	test_when_finished "shit bisect reset" &&
	shit bisect start &&
	cat >expected <<EOF &&
On branch bisect_while_rebasing
Last command done (1 command done):
   break
No commands remaining.
You are currently editing a commit while rebasing branch '\''bisect'\'' on '\''$ONTO'\''.
  (use "shit commit --amend" to amend the current commit)
  (use "shit rebase --continue" once you are satisfied with your changes)

You are currently bisecting, started from branch '\''bisect_while_rebasing'\''.
  (use "shit bisect reset" to get back to the original branch)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status when rebase --apply conflicts with statushints disabled' '
	shit reset --hard main &&
	shit checkout -b statushints_disabled &&
	test_when_finished "shit config --local advice.statushints true" &&
	shit config --local advice.statushints false &&
	test_commit one_statushints main.txt one &&
	test_commit two_statushints main.txt two &&
	test_commit three_statushints main.txt three &&
	test_when_finished "shit rebase --abort" &&
	ONTO=$(shit rev-parse --short HEAD^^) &&
	test_must_fail shit rebase --apply HEAD^ --onto HEAD^^ &&
	cat >expected <<EOF &&
rebase in progress; onto $ONTO
You are currently rebasing branch '\''statushints_disabled'\'' on '\''$ONTO'\''.

Unmerged paths:
	both modified:   main.txt

no changes added to commit
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'prepare for cherry-pick conflicts' '
	shit reset --hard main &&
	shit checkout -b cherry_branch &&
	test_commit one_cherry main.txt one &&
	test_commit two_cherries main.txt two &&
	shit checkout -b cherry_branch_second &&
	test_commit second_cherry main.txt second &&
	shit checkout cherry_branch &&
	test_commit three_cherries main.txt three
'


test_expect_success 'status when cherry-picking before resolving conflicts' '
	test_when_finished "shit cherry-pick --abort" &&
	test_must_fail shit cherry-pick cherry_branch_second &&
	TO_CHERRY_PICK=$(shit rev-parse --short CHERRY_PICK_HEAD) &&
	cat >expected <<EOF &&
On branch cherry_branch
You are currently cherry-picking commit $TO_CHERRY_PICK.
  (fix conflicts and run "shit cherry-pick --continue")
  (use "shit cherry-pick --skip" to skip this patch)
  (use "shit cherry-pick --abort" to cancel the cherry-pick operation)

Unmerged paths:
  (use "shit add <file>..." to mark resolution)
	both modified:   main.txt

no changes added to commit (use "shit add" and/or "shit commit -a")
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status when cherry-picking after resolving conflicts' '
	shit reset --hard cherry_branch &&
	test_when_finished "shit cherry-pick --abort" &&
	test_must_fail shit cherry-pick cherry_branch_second &&
	TO_CHERRY_PICK=$(shit rev-parse --short CHERRY_PICK_HEAD) &&
	echo end >main.txt &&
	shit add main.txt &&
	cat >expected <<EOF &&
On branch cherry_branch
You are currently cherry-picking commit $TO_CHERRY_PICK.
  (all conflicts fixed: run "shit cherry-pick --continue")
  (use "shit cherry-pick --skip" to skip this patch)
  (use "shit cherry-pick --abort" to cancel the cherry-pick operation)

Changes to be committed:
	modified:   main.txt

Untracked files not listed (use -u option to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'

test_expect_success 'status when cherry-picking multiple commits' '
	shit reset --hard cherry_branch &&
	test_when_finished "shit cherry-pick --abort" &&
	test_must_fail shit cherry-pick cherry_branch_second one_cherry &&
	TO_CHERRY_PICK=$(shit rev-parse --short CHERRY_PICK_HEAD) &&
	cat >expected <<EOF &&
On branch cherry_branch
You are currently cherry-picking commit $TO_CHERRY_PICK.
  (fix conflicts and run "shit cherry-pick --continue")
  (use "shit cherry-pick --skip" to skip this patch)
  (use "shit cherry-pick --abort" to cancel the cherry-pick operation)

Unmerged paths:
  (use "shit add <file>..." to mark resolution)
	both modified:   main.txt

no changes added to commit (use "shit add" and/or "shit commit -a")
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'

test_expect_success 'status when cherry-picking after committing conflict resolution' '
	shit reset --hard cherry_branch &&
	test_when_finished "shit cherry-pick --abort" &&
	test_must_fail shit cherry-pick cherry_branch_second one_cherry &&
	echo end >main.txt &&
	shit commit -a &&
	cat >expected <<EOF &&
On branch cherry_branch
Cherry-pick currently in progress.
  (run "shit cherry-pick --continue" to continue)
  (use "shit cherry-pick --skip" to skip this patch)
  (use "shit cherry-pick --abort" to cancel the cherry-pick operation)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'

test_expect_success 'status shows cherry-pick with invalid oid' '
	mkdir .shit/sequencer &&
	test_write_lines "pick invalid-oid" >.shit/sequencer/todo &&
	shit status --untracked-files=no >actual 2>err &&
	shit cherry-pick --quit &&
	test_must_be_empty err &&
	test_cmp expected actual
'

test_expect_success 'status does not show error if .shit/sequencer is a file' '
	test_when_finished "rm .shit/sequencer" &&
	test_write_lines hello >.shit/sequencer &&
	shit status --untracked-files=no 2>err &&
	test_must_be_empty err
'

test_expect_success 'status showing detached at and from a tag' '
	test_commit atag tagging &&
	shit checkout atag &&
	cat >expected <<\EOF &&
HEAD detached at atag
nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual &&

	shit reset --hard HEAD^ &&
	cat >expected <<\EOF &&
HEAD detached from atag
nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'

test_expect_success 'status while reverting commit (conflicts)' '
	shit checkout main &&
	echo before >to-revert.txt &&
	test_commit before to-revert.txt &&
	echo old >to-revert.txt &&
	test_commit old to-revert.txt &&
	echo new >to-revert.txt &&
	test_commit new to-revert.txt &&
	TO_REVERT=$(shit rev-parse --short HEAD^) &&
	test_must_fail shit revert $TO_REVERT &&
	cat >expected <<EOF &&
On branch main
You are currently reverting commit $TO_REVERT.
  (fix conflicts and run "shit revert --continue")
  (use "shit revert --skip" to skip this patch)
  (use "shit revert --abort" to cancel the revert operation)

Unmerged paths:
  (use "shit restore --staged <file>..." to unstage)
  (use "shit add <file>..." to mark resolution)
	both modified:   to-revert.txt

no changes added to commit (use "shit add" and/or "shit commit -a")
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'

test_expect_success 'status while reverting commit (conflicts resolved)' '
	echo reverted >to-revert.txt &&
	shit add to-revert.txt &&
	cat >expected <<EOF &&
On branch main
You are currently reverting commit $TO_REVERT.
  (all conflicts fixed: run "shit revert --continue")
  (use "shit revert --skip" to skip this patch)
  (use "shit revert --abort" to cancel the revert operation)

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	modified:   to-revert.txt

Untracked files not listed (use -u option to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'

test_expect_success 'status after reverting commit' '
	shit revert --continue &&
	cat >expected <<\EOF &&
On branch main
nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'

test_expect_success 'status while reverting after committing conflict resolution' '
	test_when_finished "shit revert --abort" &&
	shit reset --hard new &&
	test_must_fail shit revert old new &&
	echo reverted >to-revert.txt &&
	shit commit -a &&
	cat >expected <<EOF &&
On branch main
Revert currently in progress.
  (run "shit revert --continue" to continue)
  (use "shit revert --skip" to skip this patch)
  (use "shit revert --abort" to cancel the revert operation)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'

test_expect_success 'prepare for different number of commits rebased' '
	shit reset --hard main &&
	shit checkout -b several_commits &&
	test_commit one_commit main.txt one &&
	test_commit two_commit main.txt two &&
	test_commit three_commit main.txt three &&
	test_commit four_commit main.txt four
'

test_expect_success 'status: one command done nothing remaining' '
	FAKE_LINES="exec_exit_15" &&
	export FAKE_LINES &&
	test_when_finished "shit rebase --abort" &&
	ONTO=$(shit rev-parse --short HEAD~3) &&
	test_must_fail shit rebase -i HEAD~3 &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last command done (1 command done):
   exec exit 15
No commands remaining.
You are currently editing a commit while rebasing branch '\''several_commits'\'' on '\''$ONTO'\''.
  (use "shit commit --amend" to amend the current commit)
  (use "shit rebase --continue" once you are satisfied with your changes)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'

test_expect_success 'status: two commands done with some white lines in done file' '
	FAKE_LINES="1 > exec_exit_15  2 3" &&
	export FAKE_LINES &&
	test_when_finished "shit rebase --abort" &&
	ONTO=$(shit rev-parse --short HEAD~3) &&
	COMMIT4=$(shit rev-parse --short HEAD) &&
	COMMIT3=$(shit rev-parse --short HEAD^) &&
	COMMIT2=$(shit rev-parse --short HEAD^^) &&
	test_must_fail shit rebase -i HEAD~3 &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last commands done (2 commands done):
   pick $COMMIT2 two_commit
   exec exit 15
Next commands to do (2 remaining commands):
   pick $COMMIT3 three_commit
   pick $COMMIT4 four_commit
  (use "shit rebase --edit-todo" to view and edit)
You are currently editing a commit while rebasing branch '\''several_commits'\'' on '\''$ONTO'\''.
  (use "shit commit --amend" to amend the current commit)
  (use "shit rebase --continue" once you are satisfied with your changes)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'

test_expect_success 'status: two remaining commands with some white lines in todo file' '
	FAKE_LINES="1 2 exec_exit_15 3 > 4" &&
	export FAKE_LINES &&
	test_when_finished "shit rebase --abort" &&
	ONTO=$(shit rev-parse --short HEAD~4) &&
	COMMIT4=$(shit rev-parse --short HEAD) &&
	COMMIT3=$(shit rev-parse --short HEAD^) &&
	COMMIT2=$(shit rev-parse --short HEAD^^) &&
	test_must_fail shit rebase -i HEAD~4 &&
	cat >expected <<EOF &&
interactive rebase in progress; onto $ONTO
Last commands done (3 commands done):
   pick $COMMIT2 two_commit
   exec exit 15
  (see more in file .shit/rebase-merge/done)
Next commands to do (2 remaining commands):
   pick $COMMIT3 three_commit
   pick $COMMIT4 four_commit
  (use "shit rebase --edit-todo" to view and edit)
You are currently editing a commit while rebasing branch '\''several_commits'\'' on '\''$ONTO'\''.
  (use "shit commit --amend" to amend the current commit)
  (use "shit rebase --continue" once you are satisfied with your changes)

nothing to commit (use -u to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'

test_expect_success 'status: handle not-yet-started rebase -i gracefully' '
	ONTO=$(shit rev-parse --short HEAD^) &&
	COMMIT=$(shit rev-parse --short HEAD) &&
	EDITOR="shit status --untracked-files=no >actual" shit rebase -i HEAD^ &&
	cat >expected <<EOF &&
On branch several_commits
No commands done.
Next command to do (1 remaining command):
   pick $COMMIT four_commit
  (use "shit rebase --edit-todo" to view and edit)
You are currently editing a commit while rebasing branch '\''several_commits'\'' on '\''$ONTO'\''.
  (use "shit commit --amend" to amend the current commit)
  (use "shit rebase --continue" once you are satisfied with your changes)

nothing to commit (use -u to show untracked files)
EOF
	test_cmp expected actual
'

test_done
