#!/bin/sh
#
# Copyright (c) 2018 Johannes E. Schindelin
#

test_description='shit rebase -i --rebase-merges

This test runs shit rebase "interactively", retaining the branch structure by
recreating merge commits.

Initial setup:

    -- B --                   (first)
   /       \
 A - C - D - E - H            (main)
   \    \       /
    \    F - G                (second)
     \
      Conflicting-G
'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-rebase.sh
. "$TEST_DIRECTORY"/lib-log-graph.sh

test_cmp_graph () {
	cat >expect &&
	lib_test_cmp_graph --boundary --format=%s "$@"
}

test_expect_success 'setup' '
	write_script replace-editor.sh <<-\EOF &&
	mv "$1" "$(shit rev-parse --shit-path ORIGINAL-TODO)"
	cp script-from-scratch "$1"
	EOF

	test_commit A &&
	shit checkout -b first &&
	test_commit B &&
	b=$(shit rev-parse --short HEAD) &&
	shit checkout main &&
	test_commit C &&
	c=$(shit rev-parse --short HEAD) &&
	test_commit D &&
	d=$(shit rev-parse --short HEAD) &&
	shit merge --no-commit B &&
	test_tick &&
	shit commit -m E &&
	shit tag -m E E &&
	e=$(shit rev-parse --short HEAD) &&
	shit checkout -b second C &&
	test_commit F &&
	f=$(shit rev-parse --short HEAD) &&
	test_commit G &&
	g=$(shit rev-parse --short HEAD) &&
	shit checkout main &&
	shit merge --no-commit G &&
	test_tick &&
	shit commit -m H &&
	h=$(shit rev-parse --short HEAD) &&
	shit tag -m H H &&
	shit checkout A &&
	test_commit conflicting-G G.t
'

test_expect_success 'create completely different structure' '
	cat >script-from-scratch <<-\EOF &&
	label onto

	# onebranch
	pick G
	pick D
	label onebranch

	# second
	reset onto
	pick B
	label second

	reset onto
	merge -C H second
	merge onebranch # Merge the topic branch '\''onebranch'\''
	EOF
	test_config sequence.editor \""$PWD"/replace-editor.sh\" &&
	test_tick &&
	shit rebase -i -r A main &&
	test_cmp_graph <<-\EOF
	*   Merge the topic branch '\''onebranch'\''
	|\
	| * D
	| * G
	* |   H
	|\ \
	| |/
	|/|
	| * B
	|/
	* A
	EOF
'

test_expect_success 'generate correct todo list' '
	cat >expect <<-EOF &&
	label onto

	reset onto
	pick $b B
	label E

	reset onto
	pick $c C
	label branch-point
	pick $f F
	pick $g G
	label H

	reset branch-point # C
	pick $d D
	merge -C $e E # E
	merge -C $h H # H

	EOF

	grep -v "^#" <.shit/ORIGINAL-TODO >output &&
	test_cmp expect output
'

test_expect_success '`reset` refuses to overwrite untracked files' '
	shit checkout B &&
	test_commit dont-overwrite-untracked &&
	cat >script-from-scratch <<-EOF &&
	exec >dont-overwrite-untracked.t
	pick $(shit rev-parse B) B
	reset refs/tags/dont-overwrite-untracked
	pick $(shit rev-parse C) C
	exec cat .shit/rebase-merge/done >actual
	EOF
	test_config sequence.editor \""$PWD"/replace-editor.sh\" &&
	test_must_fail shit rebase -ir A &&
	test_cmp_rev HEAD B &&
	head -n3 script-from-scratch >expect &&
	test_cmp expect .shit/rebase-merge/done &&
	rm dont-overwrite-untracked.t &&
	shit rebase --continue &&
	tail -n3 script-from-scratch >>expect &&
	test_cmp expect actual
'

test_expect_success '`reset` rejects trees' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	test_must_fail env shit_SEQUENCE_EDITOR="echo reset A^{tree} >" \
		shit rebase -i B C >out 2>err &&
	grep "object .* is a tree" err &&
	test_must_be_empty out
'

test_expect_success '`reset` only looks for labels under refs/rewritten/' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	shit branch refs/rewritten/my-label A &&
	test_must_fail env shit_SEQUENCE_EDITOR="echo reset my-label >" \
		shit rebase -i B C >out 2>err &&
	grep "could not resolve ${SQ}my-label${SQ}" err &&
	test_must_be_empty out
'

test_expect_success 'failed `merge -C` writes patch (may be rescheduled, too)' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	shit checkout -b conflicting-merge A &&

	: fail because of conflicting untracked file &&
	>G.t &&
	echo "merge -C H G" >script-from-scratch &&
	test_config sequence.editor \""$PWD"/replace-editor.sh\" &&
	test_tick &&
	test_must_fail shit rebase -ir HEAD &&
	test_cmp_rev REBASE_HEAD H^0 &&
	grep "^merge -C .* G$" .shit/rebase-merge/done &&
	grep "^merge -C .* G$" .shit/rebase-merge/shit-rebase-todo &&
	test_path_is_missing .shit/rebase-merge/patch &&
	echo changed >file1 &&
	shit add file1 &&
	test_must_fail shit rebase --continue 2>err &&
	grep "error: you have staged changes in your working tree" err &&

	: fail because of merge conflict &&
	shit reset --hard conflicting-G &&
	test_must_fail shit rebase --continue &&
	! grep "^merge -C .* G$" .shit/rebase-merge/shit-rebase-todo &&
	test_path_is_file .shit/rebase-merge/patch
'

test_expect_success 'failed `merge <branch>` does not crash' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	shit checkout conflicting-G &&

	echo "merge G" >script-from-scratch &&
	test_config sequence.editor \""$PWD"/replace-editor.sh\" &&
	test_tick &&
	test_must_fail shit rebase -ir HEAD &&
	! grep "^merge G$" .shit/rebase-merge/shit-rebase-todo &&
	grep "^Merge branch ${SQ}G${SQ}$" .shit/rebase-merge/message
'

test_expect_success 'merge -c commits before rewording and reloads todo-list' '
	cat >script-from-scratch <<-\EOF &&
	merge -c E B
	merge -c H G
	EOF

	shit checkout -b merge-c H &&
	(
		set_reword_editor &&
		shit_SEQUENCE_EDITOR="\"$PWD/replace-editor.sh\"" \
			shit rebase -i -r D
	) &&
	check_reworded_commits E H
'

test_expect_success 'merge -c rewords when a strategy is given' '
	shit checkout -b merge-c-with-strategy H &&
	write_script shit-merge-override <<-\EOF &&
	echo overridden$1 >G.t
	shit add G.t
	EOF

	PATH="$PWD:$PATH" \
	shit_SEQUENCE_EDITOR="echo merge -c H G >" \
	shit_EDITOR="echo edited >>" \
		shit rebase --no-ff -ir -s override -Xxopt E &&
	test_write_lines overridden--xopt >expect &&
	test_cmp expect G.t &&
	test_write_lines H "" edited "" >expect &&
	shit log --format=%B -1 >actual &&
	test_cmp expect actual

'
test_expect_success 'with a branch tip that was cherry-picked already' '
	shit checkout -b already-upstream main &&
	base="$(shit rev-parse --verify HEAD)" &&

	test_commit A1 &&
	test_commit A2 &&
	shit reset --hard $base &&
	test_commit B1 &&
	test_tick &&
	shit merge -m "Merge branch A" A2 &&

	shit checkout -b upstream-with-a2 $base &&
	test_tick &&
	shit cherry-pick A2 &&

	shit checkout already-upstream &&
	test_tick &&
	shit rebase -i -r upstream-with-a2 &&
	test_cmp_graph upstream-with-a2.. <<-\EOF
	*   Merge branch A
	|\
	| * A1
	* | B1
	|/
	o A2
	EOF
'

test_expect_success '--no-rebase-merges countermands --rebase-merges' '
	shit checkout -b no-rebase-merges E &&
	shit rebase --rebase-merges --no-rebase-merges C &&
	test_cmp_graph C.. <<-\EOF
	* B
	* D
	o C
	EOF
'

test_expect_success 'do not rebase cousins unless asked for' '
	shit checkout -b cousins main &&
	before="$(shit rev-parse --verify HEAD)" &&
	test_tick &&
	shit rebase -r HEAD^ &&
	test_cmp_rev HEAD $before &&
	test_tick &&
	shit rebase --rebase-merges=rebase-cousins HEAD^ &&
	test_cmp_graph HEAD^.. <<-\EOF
	*   Merge the topic branch '\''onebranch'\''
	|\
	| * D
	| * G
	|/
	o H
	EOF
'

test_expect_success 'rebase.rebaseMerges=rebase-cousins is equivalent to --rebase-merges=rebase-cousins' '
	test_config rebase.rebaseMerges rebase-cousins &&
	shit checkout -b config-rebase-cousins main &&
	shit rebase HEAD^ &&
	test_cmp_graph HEAD^.. <<-\EOF
	*   Merge the topic branch '\''onebranch'\''
	|\
	| * D
	| * G
	|/
	o H
	EOF
'

test_expect_success '--no-rebase-merges overrides rebase.rebaseMerges=no-rebase-cousins' '
	test_config rebase.rebaseMerges no-rebase-cousins &&
	shit checkout -b override-config-no-rebase-cousins E &&
	shit rebase --no-rebase-merges C &&
	test_cmp_graph C.. <<-\EOF
	* B
	* D
	o C
	EOF
'

test_expect_success '--rebase-merges overrides rebase.rebaseMerges=rebase-cousins' '
	test_config rebase.rebaseMerges rebase-cousins &&
	shit checkout -b override-config-rebase-cousins E &&
	before="$(shit rev-parse --verify HEAD)" &&
	test_tick &&
	shit rebase --rebase-merges C &&
	test_cmp_rev HEAD $before
'

test_expect_success 'refs/rewritten/* is worktree-local' '
	shit worktree add wt &&
	cat >wt/script-from-scratch <<-\EOF &&
	label xyz
	exec shit_DIR=../.shit shit rev-parse --verify refs/rewritten/xyz >a || :
	exec shit rev-parse --verify refs/rewritten/xyz >b
	EOF

	test_config -C wt sequence.editor \""$PWD"/replace-editor.sh\" &&
	shit -C wt rebase -i HEAD &&
	test_must_be_empty wt/a &&
	test_cmp_rev HEAD "$(cat wt/b)"
'

test_expect_success '--abort cleans up refs/rewritten' '
	shit checkout -b abort-cleans-refs-rewritten H &&
	shit_SEQUENCE_EDITOR="echo break >>" shit rebase -ir @^ &&
	shit rev-parse --verify refs/rewritten/onto &&
	shit rebase --abort &&
	test_must_fail shit rev-parse --verify refs/rewritten/onto
'

test_expect_success '--quit cleans up refs/rewritten' '
	shit checkout -b quit-cleans-refs-rewritten H &&
	shit_SEQUENCE_EDITOR="echo break >>" shit rebase -ir @^ &&
	shit rev-parse --verify refs/rewritten/onto &&
	shit rebase --quit &&
	test_must_fail shit rev-parse --verify refs/rewritten/onto
'

test_expect_success 'post-rewrite hook and fixups work for merges' '
	shit checkout -b post-rewrite H &&
	test_commit same1 &&
	shit reset --hard HEAD^ &&
	test_commit same2 &&
	shit merge -m "to fix up" same1 &&
	echo same old same old >same2.t &&
	test_tick &&
	shit commit --fixup HEAD same2.t &&
	fixup="$(shit rev-parse HEAD)" &&

	test_hook post-rewrite <<-\EOF &&
	cat >actual
	EOF

	test_tick &&
	shit rebase -i --autosquash -r HEAD^^^ &&
	printf "%s %s\n%s %s\n%s %s\n%s %s\n" >expect $(shit rev-parse \
		$fixup^^2 HEAD^2 \
		$fixup^^ HEAD^ \
		$fixup^ HEAD \
		$fixup HEAD) &&
	test_cmp expect actual
'

test_expect_success 'refuse to merge ancestors of HEAD' '
	echo "merge HEAD^" >script-from-scratch &&
	test_config -C wt sequence.editor \""$PWD"/replace-editor.sh\" &&
	before="$(shit rev-parse HEAD)" &&
	shit rebase -i HEAD &&
	test_cmp_rev HEAD $before
'

test_expect_success 'root commits' '
	shit checkout --orphan unrelated &&
	(shit_AUTHOR_NAME="Parsnip" shit_AUTHOR_EMAIL="root@example.com" \
	 test_commit second-root) &&
	test_commit third-root &&
	cat >script-from-scratch <<-\EOF &&
	pick third-root
	label first-branch
	reset [new root]
	pick second-root
	merge first-branch # Merge the 3rd root
	EOF
	test_config sequence.editor \""$PWD"/replace-editor.sh\" &&
	test_tick &&
	shit rebase -i --force-rebase --root -r &&
	test "Parsnip" = "$(shit show -s --format=%an HEAD^)" &&
	test $(shit rev-parse second-root^0) != $(shit rev-parse HEAD^) &&
	test $(shit rev-parse second-root:second-root.t) = \
		$(shit rev-parse HEAD^:second-root.t) &&
	test_cmp_graph HEAD <<-\EOF &&
	*   Merge the 3rd root
	|\
	| * third-root
	* second-root
	EOF

	: fast forward if possible &&
	before="$(shit rev-parse --verify HEAD)" &&
	test_might_fail shit config --unset sequence.editor &&
	test_tick &&
	shit rebase -i --root -r &&
	test_cmp_rev HEAD $before
'

test_expect_success 'a "merge" into a root commit is a fast-forward' '
	head=$(shit rev-parse HEAD) &&
	cat >script-from-scratch <<-EOF &&
	reset [new root]
	merge $head
	EOF
	test_config sequence.editor \""$PWD"/replace-editor.sh\" &&
	test_tick &&
	shit rebase -i -r HEAD^ &&
	test_cmp_rev HEAD $head
'

test_expect_success 'A root commit can be a cousin, treat it that way' '
	shit checkout --orphan khnum &&
	test_commit yama &&
	shit checkout -b asherah main &&
	test_commit shamkat &&
	shit merge --allow-unrelated-histories khnum &&
	test_tick &&
	shit rebase -f -r HEAD^ &&
	test_cmp_rev ! HEAD^2 khnum &&
	test_cmp_graph HEAD^.. <<-\EOF &&
	*   Merge branch '\''khnum'\'' into asherah
	|\
	| * yama
	o shamkat
	EOF
	test_tick &&
	shit rebase --rebase-merges=rebase-cousins HEAD^ &&
	test_cmp_graph HEAD^.. <<-\EOF
	*   Merge branch '\''khnum'\'' into asherah
	|\
	| * yama
	|/
	o shamkat
	EOF
'

test_expect_success 'labels that are object IDs are rewritten' '
	shit checkout -b third B &&
	test_commit I &&
	third=$(shit rev-parse HEAD) &&
	shit checkout -b labels main &&
	shit merge --no-commit third &&
	test_tick &&
	shit commit -m "Merge commit '\''$third'\'' into labels" &&
	echo noop >script-from-scratch &&
	test_config sequence.editor \""$PWD"/replace-editor.sh\" &&
	test_tick &&
	shit rebase -i -r A &&
	grep "^label $third-" .shit/ORIGINAL-TODO &&
	! grep "^label $third$" .shit/ORIGINAL-TODO
'

test_expect_success 'octopus merges' '
	shit checkout -b three &&
	test_commit before-octopus &&
	test_commit three &&
	shit checkout -b two HEAD^ &&
	test_commit two &&
	shit checkout -b one HEAD^ &&
	test_commit one &&
	test_tick &&
	(shit_AUTHOR_NAME="Hank" shit_AUTHOR_EMAIL="hank@sea.world" \
	 shit merge -m "Tüntenfüsch" two three) &&

	: fast forward if possible &&
	before="$(shit rev-parse --verify HEAD)" &&
	test_tick &&
	shit rebase -i -r HEAD^^ &&
	test_cmp_rev HEAD $before &&

	test_tick &&
	shit rebase -i --force-rebase -r HEAD^^ &&
	test "Hank" = "$(shit show -s --format=%an HEAD)" &&
	test "$before" != $(shit rev-parse HEAD) &&
	test_cmp_graph HEAD^^.. <<-\EOF
	*-.   Tüntenfüsch
	|\ \
	| | * three
	| * | two
	| |/
	* / one
	|/
	o before-octopus
	EOF
'

test_expect_success 'with --autosquash and --exec' '
	shit checkout -b with-exec H &&
	echo Booh >B.t &&
	test_tick &&
	shit commit --fixup B B.t &&
	write_script show.sh <<-\EOF &&
	subject="$(shit show -s --format=%s HEAD)"
	content="$(shit diff HEAD^ HEAD | tail -n 1)"
	echo "$subject: $content"
	EOF
	test_tick &&
	shit rebase -ir --autosquash --exec ./show.sh A >actual &&
	grep "B: +Booh" actual &&
	grep "E: +Booh" actual &&
	grep "G: +G" actual
'

test_expect_success '--continue after resolving conflicts after a merge' '
	shit checkout -b already-has-g E &&
	shit cherry-pick E..G &&
	test_commit H2 &&

	shit checkout -b conflicts-in-merge H &&
	test_commit H2 H2.t conflicts H2-conflict &&
	test_must_fail shit rebase -r already-has-g &&
	grep conflicts H2.t &&
	echo resolved >H2.t &&
	shit add -u &&
	shit rebase --continue &&
	test_must_fail shit rev-parse --verify HEAD^2 &&
	test_path_is_missing .shit/MERGE_HEAD
'

test_expect_success '--rebase-merges with strategies' '
	shit checkout -b with-a-strategy F &&
	test_tick &&
	shit merge -m "Merge conflicting-G" conflicting-G &&

	: first, test with a merge strategy option &&
	shit rebase -ir -Xtheirs G &&
	echo conflicting-G >expect &&
	test_cmp expect G.t &&

	: now, try with a merge strategy other than recursive &&
	shit reset --hard @{1} &&
	write_script shit-merge-override <<-\EOF &&
	echo overridden$1 >>G.t
	shit add G.t
	EOF
	PATH="$PWD:$PATH" shit rebase -ir -s override -Xxopt G &&
	test_write_lines G overridden--xopt >expect &&
	test_cmp expect G.t
'

test_expect_success '--rebase-merges with commit that can generate bad characters for filename' '
	shit checkout -b colon-in-label E &&
	shit merge -m "colon: this should work" G &&
	shit rebase --rebase-merges --force-rebase E
'

test_expect_success '--rebase-merges with message matched with onto label' '
	shit checkout -b onto-label E &&
	shit merge -m onto G &&
	shit rebase --rebase-merges --force-rebase E &&
	test_cmp_graph <<-\EOF
	*   onto
	|\
	| * G
	| * F
	* |   E
	|\ \
	| * | B
	* | | D
	| |/
	|/|
	* | C
	|/
	* A
	EOF
'

test_expect_success 'progress shows the correct total' '
	shit checkout -b progress H &&
	shit rebase --rebase-merges --force-rebase --verbose A 2> err &&
	# Expecting "Rebasing (N/14)" here, no bogus total number
	grep "^Rebasing.*/14.$" err >progress &&
	test_line_count = 14 progress
'

test_expect_success 'truncate label names' '
	commit=$(shit commit-tree -p HEAD^ -p HEAD -m "0123456789 我 123" HEAD^{tree}) &&
	shit merge --ff-only $commit &&

	done="$(shit rev-parse --shit-path rebase-merge/done)" &&
	shit -c rebase.maxLabelLength=14 rebase --rebase-merges -x "cp \"$done\" out" --root &&
	grep "label 0123456789-我$" out &&
	shit -c rebase.maxLabelLength=13 rebase --rebase-merges -x "cp \"$done\" out" --root &&
	grep "label 0123456789-$" out
'

test_done
