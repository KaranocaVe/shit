#!/bin/sh
#
# Copyright (c) 2007 Johannes E. Schindelin
#

test_description='Test commit notes'

. ./test-lib.sh

write_script fake_editor <<\EOF
echo "$MSG" >"$1"
echo "$MSG" >&2
EOF
shit_EDITOR=./fake_editor
export shit_EDITOR

indent="    "

test_expect_success 'cannot annotate non-existing HEAD' '
	test_must_fail env MSG=3 shit notes add
'

test_expect_success 'setup' '
	test_commit 1st &&
	test_commit 2nd
'

test_expect_success 'need valid notes ref' '
	test_must_fail env MSG=1 shit_NOTES_REF=/ shit notes show &&
	test_must_fail env MSG=2 shit_NOTES_REF=/ shit notes show
'

test_expect_success 'refusing to add notes in refs/heads/' '
	test_must_fail env MSG=1 shit_NOTES_REF=refs/heads/bogus shit notes add
'

test_expect_success 'refusing to edit notes in refs/remotes/' '
	test_must_fail env MSG=1 shit_NOTES_REF=refs/heads/bogus shit notes edit
'

# 1 indicates caught gracefully by die, 128 means shit-show barked
test_expect_success 'handle empty notes gracefully' '
	test_expect_code 1 shit notes show
'

test_expect_success 'show non-existent notes entry with %N' '
	test_write_lines A B >expect &&
	shit show -s --format="A%n%NB" >actual &&
	test_cmp expect actual
'

test_expect_success 'create notes' '
	MSG=b4 shit notes add &&
	test_path_is_missing .shit/NOTES_EDITMSG &&
	shit ls-tree -r refs/notes/commits >actual &&
	test_line_count = 1 actual &&
	echo b4 >expect &&
	shit notes show >actual &&
	test_cmp expect actual &&
	shit show HEAD^ &&
	test_must_fail shit notes show HEAD^
'

test_expect_success 'show notes entry with %N' '
	test_write_lines A b4 B >expect &&
	shit show -s --format="A%n%NB" >actual &&
	test_cmp expect actual
'

test_expect_success 'create reflog entry' '
	ref=$(shit rev-parse --short refs/notes/commits) &&
	cat <<-EOF >expect &&
		$ref refs/notes/commits@{0}: notes: Notes added by '\''shit notes add'\''
	EOF
	shit reflog show refs/notes/commits >actual &&
	test_cmp expect actual
'

test_expect_success 'edit existing notes' '
	MSG=b3 shit notes edit &&
	test_path_is_missing .shit/NOTES_EDITMSG &&
	shit ls-tree -r refs/notes/commits >actual &&
	test_line_count = 1 actual &&
	echo b3 >expect &&
	shit notes show >actual &&
	test_cmp expect actual &&
	shit show HEAD^ &&
	test_must_fail shit notes show HEAD^
'

test_expect_success 'show notes from treeish' '
	echo b3 >expect &&
	shit notes --ref commits^{tree} show >actual &&
	test_cmp expect actual &&

	echo b4 >expect &&
	shit notes --ref commits@{1} show >actual &&
	test_cmp expect actual
'

test_expect_success 'cannot edit notes from non-ref' '
	test_must_fail shit notes --ref commits^{tree} edit &&
	test_must_fail shit notes --ref commits@{1} edit
'

test_expect_success 'cannot "shit notes add -m" where notes already exists' '
	test_must_fail shit notes add -m "b2" &&
	test_path_is_missing .shit/NOTES_EDITMSG &&
	shit ls-tree -r refs/notes/commits >actual &&
	test_line_count = 1 actual &&
	echo b3 >expect &&
	shit notes show >actual &&
	test_cmp expect actual &&
	shit show HEAD^ &&
	test_must_fail shit notes show HEAD^
'

test_expect_success 'can overwrite existing note with "shit notes add -f -m"' '
	shit notes add -f -m "b1" &&
	test_path_is_missing .shit/NOTES_EDITMSG &&
	shit ls-tree -r refs/notes/commits >actual &&
	test_line_count = 1 actual &&
	echo b1 >expect &&
	shit notes show >actual &&
	test_cmp expect actual &&
	shit show HEAD^ &&
	test_must_fail shit notes show HEAD^
'

test_expect_success 'add w/no options on existing note morphs into edit' '
	MSG=b2 shit notes add &&
	test_path_is_missing .shit/NOTES_EDITMSG &&
	shit ls-tree -r refs/notes/commits >actual &&
	test_line_count = 1 actual &&
	echo b2 >expect &&
	shit notes show >actual &&
	test_cmp expect actual &&
	shit show HEAD^ &&
	test_must_fail shit notes show HEAD^
'

test_expect_success 'can overwrite existing note with "shit notes add -f"' '
	MSG=b1 shit notes add -f &&
	test_path_is_missing .shit/NOTES_EDITMSG &&
	shit ls-tree -r refs/notes/commits >actual &&
	test_line_count = 1 actual &&
	echo b1 >expect &&
	shit notes show >actual &&
	test_cmp expect actual &&
	shit show HEAD^ &&
	test_must_fail shit notes show HEAD^
'

test_expect_success 'show notes' '
	commit=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:14:13 2005 -0700

		${indent}2nd

		Notes:
		${indent}b1
	EOF
	shit cat-file commit HEAD >commits &&
	! grep b1 commits &&
	shit log -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'show multi-line notes' '
	test_commit 3rd &&
	MSG="b3${LF}c3c3c3c3${LF}d3d3d3" shit notes add &&
	commit=$(shit rev-parse HEAD) &&
	cat >expect-multiline <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:15:13 2005 -0700

		${indent}3rd

		Notes:
		${indent}b3
		${indent}c3c3c3c3
		${indent}d3d3d3

	EOF
	cat expect >>expect-multiline &&
	shit log -2 >actual &&
	test_cmp expect-multiline actual
'

test_expect_success 'show -F notes' '
	test_commit 4th &&
	echo "xyzzy" >note5 &&
	shit notes add -F note5 &&
	commit=$(shit rev-parse HEAD) &&
	cat >expect-F <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:16:13 2005 -0700

		${indent}4th

		Notes:
		${indent}xyzzy

	EOF
	cat expect-multiline >>expect-F &&
	shit log -3 >actual &&
	test_cmp expect-F actual
'

test_expect_success 'Re-adding -F notes without -f fails' '
	echo "zyxxy" >note5 &&
	test_must_fail shit notes add -F note5 &&
	shit log -3 >actual &&
	test_cmp expect-F actual
'

test_expect_success 'shit log --pretty=raw does not show notes' '
	commit=$(shit rev-parse HEAD) &&
	tree=$(shit rev-parse HEAD^{tree}) &&
	parent=$(shit rev-parse HEAD^) &&
	cat >expect <<-EOF &&
		commit $commit
		tree $tree
		parent $parent
		author A U Thor <author@example.com> 1112912173 -0700
		committer C O Mitter <committer@example.com> 1112912173 -0700

		${indent}4th
	EOF
	shit log -1 --pretty=raw >actual &&
	test_cmp expect actual
'

test_expect_success 'shit log --show-notes' '
	cat >>expect <<-EOF &&

	Notes:
	${indent}xyzzy
	EOF
	shit log -1 --pretty=raw --show-notes >actual &&
	test_cmp expect actual
'

test_expect_success 'shit log --no-notes' '
	shit log -1 --no-notes >actual &&
	! grep xyzzy actual
'

test_expect_success 'shit format-patch does not show notes' '
	shit format-patch -1 --stdout >actual &&
	! grep xyzzy actual
'

test_expect_success 'shit format-patch --show-notes does show notes' '
	shit format-patch --show-notes -1 --stdout >actual &&
	grep xyzzy actual
'

for pretty in \
	"" --pretty --pretty=raw --pretty=short --pretty=medium \
	--pretty=full --pretty=fuller --pretty=format:%s --oneline
do
	case "$pretty" in
	"") p= not= negate="" ;;
	?*) p="$pretty" not=" not" negate="!" ;;
	esac
	test_expect_success "shit show $pretty does$not show notes" '
		shit show $p >actual &&
		eval "$negate grep xyzzy actual"
	'
done

test_expect_success 'setup alternate notes ref' '
	shit notes --ref=alternate add -m alternate
'

test_expect_success 'shit log --notes shows default notes' '
	shit log -1 --notes >actual &&
	grep xyzzy actual &&
	! grep alternate actual
'

test_expect_success 'shit log --notes=X shows only X' '
	shit log -1 --notes=alternate >actual &&
	! grep xyzzy actual &&
	grep alternate actual
'

test_expect_success 'shit log --notes --notes=X shows both' '
	shit log -1 --notes --notes=alternate >actual &&
	grep xyzzy actual &&
	grep alternate actual
'

test_expect_success 'shit log --no-notes resets default state' '
	shit log -1 --notes --notes=alternate \
		--no-notes --notes=alternate \
		>actual &&
	! grep xyzzy actual &&
	grep alternate actual
'

test_expect_success 'shit log --no-notes resets ref list' '
	shit log -1 --notes --notes=alternate \
		--no-notes --notes \
		>actual &&
	grep xyzzy actual &&
	! grep alternate actual
'

test_expect_success 'show -m notes' '
	test_commit 5th &&
	shit notes add -m spam -m "foo${LF}bar${LF}baz" &&
	commit=$(shit rev-parse HEAD) &&
	cat >expect-m <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:17:13 2005 -0700

		${indent}5th

		Notes:
		${indent}spam
		${indent}
		${indent}foo
		${indent}bar
		${indent}baz

	EOF
	cat expect-F >>expect-m &&
	shit log -4 >actual &&
	test_cmp expect-m actual
'

test_expect_success 'remove note with add -f -F /dev/null' '
	shit notes add -f -F /dev/null &&
	commit=$(shit rev-parse HEAD) &&
	cat >expect-rm-F <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:17:13 2005 -0700

		${indent}5th

	EOF
	cat expect-F >>expect-rm-F &&
	shit log -4 >actual &&
	test_cmp expect-rm-F actual &&
	test_must_fail shit notes show
'

test_expect_success 'do not create empty note with -m ""' '
	shit notes add -m "" &&
	shit log -4 >actual &&
	test_cmp expect-rm-F actual &&
	test_must_fail shit notes show
'

test_expect_success 'create note with combination of -m and -F' '
	test_when_finished shit notes remove HEAD &&
	cat >expect-combine_m_and_F <<-EOF &&
		foo

		xyzzy

		bar

		zyxxy

		baz
	EOF
	echo "xyzzy" >note_a &&
	echo "zyxxy" >note_b &&
	shit notes add -m "foo" -F note_a -m "bar" -F note_b -m "baz" &&
	shit notes show >actual &&
	test_cmp expect-combine_m_and_F actual
'

test_expect_success 'create note with combination of -m and -F and --separator' '
	test_when_finished shit notes remove HEAD &&
	cat >expect-combine_m_and_F <<-\EOF &&
	foo
	-------
	xyzzy
	-------
	bar
	-------
	zyxxy
	-------
	baz
	EOF
	echo "xyzzy" >note_a &&
	echo "zyxxy" >note_b &&
	shit notes add -m "foo" -F note_a -m "bar" -F note_b -m "baz" --separator="-------" &&
	shit notes show >actual &&
	test_cmp expect-combine_m_and_F actual
'

test_expect_success 'create note with combination of -m and -F and --no-separator' '
	cat >expect-combine_m_and_F <<-\EOF &&
	foo
	xyzzy
	bar
	zyxxy
	baz
	EOF
	echo "xyzzy" >note_a &&
	echo "zyxxy" >note_b &&
	shit notes add -m "foo" -F note_a -m "bar" -F note_b -m "baz" --no-separator &&
	shit notes show >actual &&
	test_cmp expect-combine_m_and_F actual
'

test_expect_success 'remove note with "shit notes remove"' '
	shit notes remove HEAD^ &&
	shit notes remove &&
	commit=$(shit rev-parse HEAD) &&
	parent=$(shit rev-parse HEAD^) &&
	cat >expect-rm-remove <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:17:13 2005 -0700

		${indent}5th

		commit $parent
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:16:13 2005 -0700

		${indent}4th

	EOF
	cat expect-multiline >>expect-rm-remove &&
	shit log -4 >actual &&
	test_cmp expect-rm-remove actual &&
	test_must_fail shit notes show HEAD^
'

test_expect_success 'removing non-existing note should not create new commit' '
	shit rev-parse --verify refs/notes/commits >before_commit &&
	test_must_fail shit notes remove HEAD^ &&
	shit rev-parse --verify refs/notes/commits >after_commit &&
	test_cmp before_commit after_commit
'

test_expect_success 'removing more than one' '
	before=$(shit rev-parse --verify refs/notes/commits) &&
	test_when_finished "shit update-ref refs/notes/commits $before" &&

	# We have only two -- add another and make sure it stays
	shit notes add -m "extra" &&
	shit notes list HEAD >after-removal-expect &&
	shit notes remove HEAD^^ HEAD^^^ &&
	shit notes list | sed -e "s/ .*//" >actual &&
	test_cmp after-removal-expect actual
'

test_expect_success 'removing is atomic' '
	before=$(shit rev-parse --verify refs/notes/commits) &&
	test_when_finished "shit update-ref refs/notes/commits $before" &&
	test_must_fail shit notes remove HEAD^^ HEAD^^^ HEAD^ &&
	after=$(shit rev-parse --verify refs/notes/commits) &&
	test "$before" = "$after"
'

test_expect_success 'removing with --ignore-missing' '
	before=$(shit rev-parse --verify refs/notes/commits) &&
	test_when_finished "shit update-ref refs/notes/commits $before" &&

	# We have only two -- add another and make sure it stays
	shit notes add -m "extra" &&
	shit notes list HEAD >after-removal-expect &&
	shit notes remove --ignore-missing HEAD^^ HEAD^^^ HEAD^ &&
	shit notes list | sed -e "s/ .*//" >actual &&
	test_cmp after-removal-expect actual
'

test_expect_success 'removing with --ignore-missing but bogus ref' '
	before=$(shit rev-parse --verify refs/notes/commits) &&
	test_when_finished "shit update-ref refs/notes/commits $before" &&
	test_must_fail shit notes remove --ignore-missing HEAD^^ HEAD^^^ NO-SUCH-COMMIT &&
	after=$(shit rev-parse --verify refs/notes/commits) &&
	test "$before" = "$after"
'

test_expect_success 'remove reads from --stdin' '
	before=$(shit rev-parse --verify refs/notes/commits) &&
	test_when_finished "shit update-ref refs/notes/commits $before" &&

	# We have only two -- add another and make sure it stays
	shit notes add -m "extra" &&
	shit notes list HEAD >after-removal-expect &&
	shit rev-parse HEAD^^ HEAD^^^ >input &&
	shit notes remove --stdin <input &&
	shit notes list | sed -e "s/ .*//" >actual &&
	test_cmp after-removal-expect actual
'

test_expect_success 'remove --stdin is also atomic' '
	before=$(shit rev-parse --verify refs/notes/commits) &&
	test_when_finished "shit update-ref refs/notes/commits $before" &&
	shit rev-parse HEAD^^ HEAD^^^ HEAD^ >input &&
	test_must_fail shit notes remove --stdin <input &&
	after=$(shit rev-parse --verify refs/notes/commits) &&
	test "$before" = "$after"
'

test_expect_success 'removing with --stdin --ignore-missing' '
	before=$(shit rev-parse --verify refs/notes/commits) &&
	test_when_finished "shit update-ref refs/notes/commits $before" &&

	# We have only two -- add another and make sure it stays
	shit notes add -m "extra" &&
	shit notes list HEAD >after-removal-expect &&
	shit rev-parse HEAD^^ HEAD^^^ HEAD^ >input &&
	shit notes remove --ignore-missing --stdin <input &&
	shit notes list | sed -e "s/ .*//" >actual &&
	test_cmp after-removal-expect actual
'

test_expect_success 'list notes with "shit notes list"' '
	commit_2=$(shit rev-parse 2nd) &&
	commit_3=$(shit rev-parse 3rd) &&
	note_2=$(shit rev-parse refs/notes/commits:$commit_2) &&
	note_3=$(shit rev-parse refs/notes/commits:$commit_3) &&
	sort -t" " -k2 >expect <<-EOF &&
		$note_2 $commit_2
		$note_3 $commit_3
	EOF
	shit notes list >actual &&
	test_cmp expect actual
'

test_expect_success 'list notes with "shit notes"' '
	shit notes >actual &&
	test_cmp expect actual
'

test_expect_success '"shit notes" without subcommand does not take arguments' '
	test_expect_code 129 shit notes HEAD^^ 2>err &&
	grep "^error: unknown subcommand" err
'

test_expect_success 'list specific note with "shit notes list <object>"' '
	shit rev-parse refs/notes/commits:$commit_3 >expect &&
	shit notes list HEAD^^ >actual &&
	test_cmp expect actual
'

test_expect_success 'listing non-existing notes fails' '
	test_must_fail shit notes list HEAD >actual &&
	test_must_be_empty actual
'

test_expect_success 'append: specify a separator with an empty arg' '
	test_when_finished shit notes remove HEAD &&
	cat >expect <<-\EOF &&
	notes-1

	notes-2
	EOF

	shit notes add -m "notes-1" &&
	shit notes append --separator="" -m "notes-2" &&
	shit notes show >actual &&
	test_cmp expect actual
'

test_expect_success 'append: specify a separator without arg' '
	test_when_finished shit notes remove HEAD &&
	cat >expect <<-\EOF &&
	notes-1

	notes-2
	EOF

	shit notes add -m "notes-1" &&
	shit notes append --separator -m "notes-2" &&
	shit notes show >actual &&
	test_cmp expect actual
'

test_expect_success 'append: specify as --no-separator' '
	test_when_finished shit notes remove HEAD &&
	cat >expect <<-\EOF &&
	notes-1
	notes-2
	EOF

	shit notes add -m "notes-1" &&
	shit notes append --no-separator -m "notes-2" &&
	shit notes show >actual &&
	test_cmp expect actual
'

test_expect_success 'append: specify separator with line break' '
	test_when_finished shit notes remove HEAD &&
	cat >expect <<-\EOF &&
	notes-1
	-------
	notes-2
	EOF

	shit notes add -m "notes-1" &&
	shit notes append --separator="-------$LF" -m "notes-2" &&
	shit notes show >actual &&
	test_cmp expect actual
'

test_expect_success 'append: specify separator without line break' '
	test_when_finished shit notes remove HEAD &&
	cat >expect <<-\EOF &&
	notes-1
	-------
	notes-2
	EOF

	shit notes add -m "notes-1" &&
	shit notes append --separator="-------" -m "notes-2" &&
	shit notes show >actual &&
	test_cmp expect actual
'

test_expect_success 'append: specify separator with multiple messages' '
	test_when_finished shit notes remove HEAD &&
	cat >expect <<-\EOF &&
	notes-1
	-------
	notes-2
	-------
	notes-3
	EOF

	shit notes add -m "notes-1" &&
	shit notes append --separator="-------" -m "notes-2" -m "notes-3" &&
	shit notes show >actual &&
	test_cmp expect actual
'

test_expect_success 'append note with combination of -m and -F and --separator' '
	test_when_finished shit notes remove HEAD &&
	cat >expect-combine_m_and_F <<-\EOF &&
	m-notes-1
	-------
	f-notes-1
	-------
	m-notes-2
	-------
	f-notes-2
	-------
	m-notes-3
	EOF

	echo "f-notes-1" >note_a &&
	echo "f-notes-2" >note_b &&
	shit notes append -m "m-notes-1" -F note_a -m "m-notes-2" -F note_b -m "m-notes-3" --separator="-------" &&
	shit notes show >actual &&
	test_cmp expect-combine_m_and_F actual
'

test_expect_success 'append to existing note with "shit notes append"' '
	cat >expect <<-EOF &&
		Initial set of notes

		More notes appended with shit notes append
	EOF
	shit notes add -m "Initial set of notes" &&
	shit notes append -m "More notes appended with shit notes append" &&
	shit notes show >actual &&
	test_cmp expect actual
'

test_expect_success '"shit notes list" does not expand to "shit notes list HEAD"' '
	commit_5=$(shit rev-parse 5th) &&
	note_5=$(shit rev-parse refs/notes/commits:$commit_5) &&
	sort -t" " -k2 >expect_list <<-EOF &&
		$note_2 $commit_2
		$note_3 $commit_3
		$note_5 $commit_5
	EOF
	shit notes list >actual &&
	test_cmp expect_list actual
'

test_expect_success 'appending empty string does not change existing note' '
	shit notes append -m "" &&
	shit notes show >actual &&
	test_cmp expect actual
'

test_expect_success 'shit notes append == add when there is no existing note' '
	shit notes remove HEAD &&
	test_must_fail shit notes list HEAD &&
	shit notes append -m "Initial set of notes${LF}${LF}More notes appended with shit notes append" &&
	shit notes show >actual &&
	test_cmp expect actual
'

test_expect_success 'appending empty string to non-existing note does not create note' '
	shit notes remove HEAD &&
	test_must_fail shit notes list HEAD &&
	shit notes append -m "" &&
	test_must_fail shit notes list HEAD
'

test_expect_success 'create other note on a different notes ref (setup)' '
	test_commit 6th &&
	shit_NOTES_REF="refs/notes/other" shit notes add -m "other note" &&
	commit=$(shit rev-parse HEAD) &&
	cat >expect-not-other <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:18:13 2005 -0700

		${indent}6th
	EOF
	cp expect-not-other expect-other &&
	cat >>expect-other <<-EOF

		Notes (other):
		${indent}other note
	EOF
'

test_expect_success 'Do not show note on other ref by default' '
	shit log -1 >actual &&
	test_cmp expect-not-other actual
'

test_expect_success 'Do show note when ref is given in shit_NOTES_REF' '
	shit_NOTES_REF="refs/notes/other" shit log -1 >actual &&
	test_cmp expect-other actual
'

test_expect_success 'Do show note when ref is given in core.notesRef config' '
	test_config core.notesRef "refs/notes/other" &&
	shit log -1 >actual &&
	test_cmp expect-other actual
'

test_expect_success 'Do not show note when core.notesRef is overridden' '
	test_config core.notesRef "refs/notes/other" &&
	shit_NOTES_REF="refs/notes/wrong" shit log -1 >actual &&
	test_cmp expect-not-other actual
'

test_expect_success 'Show all notes when notes.displayRef=refs/notes/*' '
	commit=$(shit rev-parse HEAD) &&
	parent=$(shit rev-parse HEAD^) &&
	cat >expect-both <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:18:13 2005 -0700

		${indent}6th

		Notes:
		${indent}order test

		Notes (other):
		${indent}other note

		commit $parent
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:17:13 2005 -0700

		${indent}5th

		Notes:
		${indent}replacement for deleted note
	EOF
	shit_NOTES_REF=refs/notes/commits shit notes add \
		-m"replacement for deleted note" HEAD^ &&
	shit_NOTES_REF=refs/notes/commits shit notes add -m"order test" &&
	test_unconfig core.notesRef &&
	test_config notes.displayRef "refs/notes/*" &&
	shit log -2 >actual &&
	test_cmp expect-both actual
'

test_expect_success 'core.notesRef is implicitly in notes.displayRef' '
	test_config core.notesRef refs/notes/commits &&
	test_config notes.displayRef refs/notes/other &&
	shit log -2 >actual &&
	test_cmp expect-both actual
'

test_expect_success 'notes.displayRef can be given more than once' '
	test_unconfig core.notesRef &&
	test_config notes.displayRef refs/notes/commits &&
	shit config --add notes.displayRef refs/notes/other &&
	shit log -2 >actual &&
	test_cmp expect-both actual
'

test_expect_success 'notes.displayRef respects order' '
	commit=$(shit rev-parse HEAD) &&
	cat >expect-both-reversed <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:18:13 2005 -0700

		${indent}6th

		Notes (other):
		${indent}other note

		Notes:
		${indent}order test
	EOF
	test_config core.notesRef refs/notes/other &&
	test_config notes.displayRef refs/notes/commits &&
	shit log -1 >actual &&
	test_cmp expect-both-reversed actual
'

test_expect_success 'notes.displayRef with no value handled gracefully' '
	test_must_fail shit -c notes.displayRef log -0 --notes &&
	test_must_fail shit -c notes.displayRef diff-tree --notes HEAD
'

test_expect_success 'shit_NOTES_DISPLAY_REF works' '
	shit_NOTES_DISPLAY_REF=refs/notes/commits:refs/notes/other \
		shit log -2 >actual &&
	test_cmp expect-both actual
'

test_expect_success 'shit_NOTES_DISPLAY_REF overrides config' '
	commit=$(shit rev-parse HEAD) &&
	parent=$(shit rev-parse HEAD^) &&
	cat >expect-none <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:18:13 2005 -0700

		${indent}6th

		commit $parent
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:17:13 2005 -0700

		${indent}5th
	EOF
	test_config notes.displayRef "refs/notes/*" &&
	shit_NOTES_REF= shit_NOTES_DISPLAY_REF= shit log -2 >actual &&
	test_cmp expect-none actual
'

test_expect_success '--show-notes=* adds to shit_NOTES_DISPLAY_REF' '
	shit_NOTES_REF= shit_NOTES_DISPLAY_REF= shit log --show-notes=* -2 >actual &&
	test_cmp expect-both actual
'

test_expect_success '--no-standard-notes' '
	commit=$(shit rev-parse HEAD) &&
	cat >expect-commits <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:18:13 2005 -0700

		${indent}6th

		Notes:
		${indent}order test
	EOF
	shit log --no-standard-notes --show-notes=commits -1 >actual &&
	test_cmp expect-commits actual
'

test_expect_success '--standard-notes' '
	test_config notes.displayRef "refs/notes/*" &&
	shit log --no-standard-notes --show-notes=commits \
		--standard-notes -2 >actual &&
	test_cmp expect-both actual
'

test_expect_success '--show-notes=ref accumulates' '
	shit log --show-notes=other --show-notes=commits \
		 --no-standard-notes -1 >actual &&
	test_cmp expect-both-reversed actual
'

test_expect_success 'Allow notes on non-commits (trees, blobs, tags)' '
	test_config core.notesRef refs/notes/other &&
	echo "Note on a tree" >expect &&
	shit notes add -m "Note on a tree" HEAD: &&
	shit notes show HEAD: >actual &&
	test_cmp expect actual &&
	echo "Note on a blob" >expect &&
	shit ls-tree --name-only HEAD >files &&
	filename=$(head -n1 files) &&
	shit notes add -m "Note on a blob" HEAD:$filename &&
	shit notes show HEAD:$filename >actual &&
	test_cmp expect actual &&
	echo "Note on a tag" >expect &&
	shit tag -a -m "This is an annotated tag" foobar HEAD^ &&
	shit notes add -m "Note on a tag" foobar &&
	shit notes show foobar >actual &&
	test_cmp expect actual
'

test_expect_success 'create note from other note with "shit notes add -C"' '
	test_commit 7th &&
	commit=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:19:13 2005 -0700

		${indent}7th

		Notes:
		${indent}order test
	EOF
	note=$(shit notes list HEAD^) &&
	shit notes add -C $note &&
	shit log -1 >actual &&
	test_cmp expect actual &&
	shit notes list HEAD^ >expect &&
	shit notes list HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'create note from non-existing note with "shit notes add -C" fails' '
	test_commit 8th &&
	test_must_fail shit notes add -C deadbeef &&
	test_must_fail shit notes list HEAD
'

test_expect_success 'create note from non-blob with "shit notes add -C" fails' '
	commit=$(shit rev-parse --verify HEAD) &&
	tree=$(shit rev-parse --verify HEAD:) &&
	test_must_fail shit notes add -C $commit &&
	test_must_fail shit notes add -C $tree &&
	test_must_fail shit notes list HEAD
'

test_expect_success 'create note from blob with "shit notes add -C" reuses blob id' '
	commit=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:20:13 2005 -0700

		${indent}8th

		Notes:
		${indent}This is a blob object
	EOF
	echo "This is a blob object" | shit hash-object -w --stdin >blob &&
	shit notes add -C $(cat blob) &&
	shit log -1 >actual &&
	test_cmp expect actual &&
	shit notes list HEAD >actual &&
	test_cmp blob actual
'

test_expect_success 'create note from blob with "-C", also specify "-m", "-F" and "--separator"' '
	# 8th will be reuseed in following tests, so rollback when the test is done
	test_when_finished "shit notes remove && shit notes add -C $(cat blob)" &&
	commit=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:20:13 2005 -0700

		${indent}8th

		Notes:
		${indent}This is a blob object
		${indent}-------
		${indent}This is created by -m
		${indent}-------
		${indent}This is created by -F
	EOF

	shit notes remove &&
	echo "This is a blob object" | shit hash-object -w --stdin >blob &&
	echo "This is created by -F" >note_a &&
	shit notes add -C $(cat blob) -m "This is created by -m" -F note_a --separator="-------" &&
	shit log -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'create note from other note with "shit notes add -c"' '
	test_commit 9th &&
	commit=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:21:13 2005 -0700

		${indent}9th

		Notes:
		${indent}yet another note
	EOF
	note=$(shit notes list HEAD^^) &&
	MSG="yet another note" shit notes add -c $note &&
	shit log -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'create note from non-existing note with "shit notes add -c" fails' '
	test_commit 10th &&
	test_must_fail env MSG="yet another note" shit notes add -c deadbeef &&
	test_must_fail shit notes list HEAD
'

test_expect_success 'append to note from other note with "shit notes append -C"' '
	commit=$(shit rev-parse HEAD^) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:21:13 2005 -0700

		${indent}9th

		Notes:
		${indent}yet another note
		${indent}
		${indent}yet another note
	EOF
	note=$(shit notes list HEAD^) &&
	shit notes append -C $note HEAD^ &&
	shit log -1 HEAD^ >actual &&
	test_cmp expect actual
'

test_expect_success 'create note from other note with "shit notes append -c"' '
	commit=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:22:13 2005 -0700

		${indent}10th

		Notes:
		${indent}other note
	EOF
	note=$(shit notes list HEAD^) &&
	MSG="other note" shit notes append -c $note &&
	shit log -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'append to note from other note with "shit notes append -c"' '
	commit=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:22:13 2005 -0700

		${indent}10th

		Notes:
		${indent}other note
		${indent}
		${indent}yet another note
	EOF
	note=$(shit notes list HEAD) &&
	MSG="yet another note" shit notes append -c $note &&
	shit log -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'copy note with "shit notes copy"' '
	commit=$(shit rev-parse 4th) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:16:13 2005 -0700

		${indent}4th

		Notes:
		${indent}This is a blob object
	EOF
	shit notes copy 8th 4th &&
	shit log 3rd..4th >actual &&
	test_cmp expect actual &&
	shit notes list 4th >expect &&
	shit notes list 8th >actual &&
	test_cmp expect actual
'

test_expect_success 'copy note with "shit notes copy" with default' '
	test_commit 11th &&
	commit=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:23:13 2005 -0700

		${indent}11th

		Notes:
		${indent}other note
		${indent}
		${indent}yet another note
	EOF
	shit notes copy HEAD^ &&
	shit log -1 >actual &&
	test_cmp expect actual &&
	shit notes list HEAD^ >expect &&
	shit notes list HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'prevent overwrite with "shit notes copy"' '
	test_must_fail shit notes copy HEAD~2 HEAD &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:23:13 2005 -0700

		${indent}11th

		Notes:
		${indent}other note
		${indent}
		${indent}yet another note
	EOF
	shit log -1 >actual &&
	test_cmp expect actual &&
	shit notes list HEAD^ >expect &&
	shit notes list HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'allow overwrite with "shit notes copy -f"' '
	commit=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:23:13 2005 -0700

		${indent}11th

		Notes:
		${indent}This is a blob object
	EOF
	shit notes copy -f HEAD~3 HEAD &&
	shit log -1 >actual &&
	test_cmp expect actual &&
	shit notes list HEAD~3 >expect &&
	shit notes list HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'allow overwrite with "shit notes copy -f" with default' '
	commit=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:23:13 2005 -0700

		${indent}11th

		Notes:
		${indent}yet another note
		${indent}
		${indent}yet another note
	EOF
	shit notes copy -f HEAD~2 &&
	shit log -1 >actual &&
	test_cmp expect actual &&
	shit notes list HEAD~2 >expect &&
	shit notes list HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'cannot copy note from object without notes' '
	test_commit 12th &&
	test_commit 13th &&
	test_must_fail shit notes copy HEAD^ HEAD
'

test_expect_success 'shit notes copy --stdin' '
	commit=$(shit rev-parse HEAD) &&
	parent=$(shit rev-parse HEAD^) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:25:13 2005 -0700

		${indent}13th

		Notes:
		${indent}yet another note
		${indent}
		${indent}yet another note

		commit $parent
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:24:13 2005 -0700

		${indent}12th

		Notes:
		${indent}other note
		${indent}
		${indent}yet another note
	EOF
	from=$(shit rev-parse HEAD~3) &&
	to=$(shit rev-parse HEAD^) &&
	echo "$from" "$to" >copy &&
	from=$(shit rev-parse HEAD~2) &&
	to=$(shit rev-parse HEAD) &&
	echo "$from" "$to" >>copy &&
	shit notes copy --stdin <copy &&
	shit log -2 >actual &&
	test_cmp expect actual &&
	shit notes list HEAD~2 >expect &&
	shit notes list HEAD >actual &&
	test_cmp expect actual &&
	shit notes list HEAD~3 >expect &&
	shit notes list HEAD^ >actual &&
	test_cmp expect actual
'

test_expect_success 'shit notes copy --for-rewrite (unconfigured)' '
	test_commit 14th &&
	test_commit 15th &&
	commit=$(shit rev-parse HEAD) &&
	parent=$(shit rev-parse HEAD^) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:27:13 2005 -0700

		${indent}15th

		commit $parent
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:26:13 2005 -0700

		${indent}14th
	EOF
	from=$(shit rev-parse HEAD~3) &&
	to=$(shit rev-parse HEAD^) &&
	echo "$from" "$to" >copy &&
	from=$(shit rev-parse HEAD~2) &&
	to=$(shit rev-parse HEAD) &&
	echo "$from" "$to" >>copy &&
	shit notes copy --for-rewrite=foo <copy &&
	shit log -2 >actual &&
	test_cmp expect actual
'

test_expect_success 'shit notes copy --for-rewrite (enabled)' '
	commit=$(shit rev-parse HEAD) &&
	parent=$(shit rev-parse HEAD^) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:27:13 2005 -0700

		${indent}15th

		Notes:
		${indent}yet another note
		${indent}
		${indent}yet another note

		commit $parent
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:26:13 2005 -0700

		${indent}14th

		Notes:
		${indent}other note
		${indent}
		${indent}yet another note
	EOF
	test_config notes.rewriteMode overwrite &&
	test_config notes.rewriteRef "refs/notes/*" &&
	from=$(shit rev-parse HEAD~3) &&
	to=$(shit rev-parse HEAD^) &&
	echo "$from" "$to" >copy &&
	from=$(shit rev-parse HEAD~2) &&
	to=$(shit rev-parse HEAD) &&
	echo "$from" "$to" >>copy &&
	shit notes copy --for-rewrite=foo <copy &&
	shit log -2 >actual &&
	test_cmp expect actual
'

test_expect_success 'shit notes copy --for-rewrite (disabled)' '
	test_config notes.rewrite.bar false &&
	from=$(shit rev-parse HEAD~3) &&
	to=$(shit rev-parse HEAD) &&
	echo "$from" "$to" >copy &&
	shit notes copy --for-rewrite=bar <copy &&
	shit log -2 >actual &&
	test_cmp expect actual
'

test_expect_success 'shit notes copy --for-rewrite (overwrite)' '
	commit=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:27:13 2005 -0700

		${indent}15th

		Notes:
		${indent}a fresh note
	EOF
	shit notes add -f -m"a fresh note" HEAD^ &&
	test_config notes.rewriteMode overwrite &&
	test_config notes.rewriteRef "refs/notes/*" &&
	from=$(shit rev-parse HEAD^) &&
	to=$(shit rev-parse HEAD) &&
	echo "$from" "$to" >copy &&
	shit notes copy --for-rewrite=foo <copy &&
	shit log -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'shit notes copy --for-rewrite (ignore)' '
	test_config notes.rewriteMode ignore &&
	test_config notes.rewriteRef "refs/notes/*" &&
	from=$(shit rev-parse HEAD^) &&
	to=$(shit rev-parse HEAD) &&
	echo "$from" "$to" >copy &&
	shit notes copy --for-rewrite=foo <copy &&
	shit log -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'shit notes copy --for-rewrite (append)' '
	commit=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:27:13 2005 -0700

		${indent}15th

		Notes:
		${indent}a fresh note
		${indent}
		${indent}another fresh note
	EOF
	shit notes add -f -m"another fresh note" HEAD^ &&
	test_config notes.rewriteMode concatenate &&
	test_config notes.rewriteRef "refs/notes/*" &&
	from=$(shit rev-parse HEAD^) &&
	to=$(shit rev-parse HEAD) &&
	echo "$from" "$to" >copy &&
	shit notes copy --for-rewrite=foo <copy &&
	shit log -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'shit notes copy --for-rewrite (append two to one)' '
	commit=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:27:13 2005 -0700

		${indent}15th

		Notes:
		${indent}a fresh note
		${indent}
		${indent}another fresh note
		${indent}
		${indent}append 1
		${indent}
		${indent}append 2
	EOF
	shit notes add -f -m"append 1" HEAD^ &&
	shit notes add -f -m"append 2" HEAD^^ &&
	test_config notes.rewriteMode concatenate &&
	test_config notes.rewriteRef "refs/notes/*" &&
	from=$(shit rev-parse HEAD^) &&
	to=$(shit rev-parse HEAD) &&
	echo "$from" "$to" >copy &&
	from=$(shit rev-parse HEAD^^) &&
	to=$(shit rev-parse HEAD) &&
	echo "$from" "$to" >>copy &&
	shit notes copy --for-rewrite=foo <copy &&
	shit log -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'shit notes copy --for-rewrite (append empty)' '
	shit notes remove HEAD^ &&
	test_config notes.rewriteMode concatenate &&
	test_config notes.rewriteRef "refs/notes/*" &&
	from=$(shit rev-parse HEAD^) &&
	to=$(shit rev-parse HEAD) &&
	echo "$from" "$to" >copy &&
	shit notes copy --for-rewrite=foo <copy &&
	shit log -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'shit_NOTES_REWRITE_MODE works' '
	commit=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:27:13 2005 -0700

		${indent}15th

		Notes:
		${indent}replacement note 1
	EOF
	test_config notes.rewriteMode concatenate &&
	test_config notes.rewriteRef "refs/notes/*" &&
	shit notes add -f -m"replacement note 1" HEAD^ &&
	from=$(shit rev-parse HEAD^) &&
	to=$(shit rev-parse HEAD) &&
	echo "$from" "$to" >copy &&
	shit_NOTES_REWRITE_MODE=overwrite shit notes copy --for-rewrite=foo <copy &&
	shit log -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'shit_NOTES_REWRITE_REF works' '
	commit=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
		commit $commit
		Author: A U Thor <author@example.com>
		Date:   Thu Apr 7 15:27:13 2005 -0700

		${indent}15th

		Notes:
		${indent}replacement note 2
	EOF
	shit notes add -f -m"replacement note 2" HEAD^ &&
	test_config notes.rewriteMode overwrite &&
	test_unconfig notes.rewriteRef &&
	from=$(shit rev-parse HEAD^) &&
	to=$(shit rev-parse HEAD) &&
	echo "$from" "$to" >copy &&
	shit_NOTES_REWRITE_REF=refs/notes/commits:refs/notes/other \
		shit notes copy --for-rewrite=foo <copy &&
	shit log -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'shit_NOTES_REWRITE_REF overrides config' '
	shit notes add -f -m"replacement note 3" HEAD^ &&
	test_config notes.rewriteMode overwrite &&
	test_config notes.rewriteRef refs/notes/other &&
	from=$(shit rev-parse HEAD^) &&
	to=$(shit rev-parse HEAD) &&
	echo "$from" "$to" >copy &&
	shit_NOTES_REWRITE_REF=refs/notes/commits \
		shit notes copy --for-rewrite=foo <copy &&
	shit log -1 >actual &&
	grep "replacement note 3" actual
'

test_expect_success 'shit notes copy diagnoses too many or too few arguments' '
	test_must_fail shit notes copy 2>error &&
	test_grep "too few arguments" error &&
	test_must_fail shit notes copy one two three 2>error &&
	test_grep "too many arguments" error
'

test_expect_success 'shit notes get-ref expands refs/heads/main to refs/notes/refs/heads/main' '
	test_unconfig core.notesRef &&
	sane_unset shit_NOTES_REF &&
	echo refs/notes/refs/heads/main >expect &&
	shit notes --ref=refs/heads/main get-ref >actual &&
	test_cmp expect actual
'

test_expect_success 'shit notes get-ref (no overrides)' '
	test_unconfig core.notesRef &&
	sane_unset shit_NOTES_REF &&
	echo refs/notes/commits >expect &&
	shit notes get-ref >actual &&
	test_cmp expect actual
'

test_expect_success 'shit notes get-ref (core.notesRef)' '
	test_config core.notesRef refs/notes/foo &&
	echo refs/notes/foo >expect &&
	shit notes get-ref >actual &&
	test_cmp expect actual
'

test_expect_success 'shit notes get-ref (shit_NOTES_REF)' '
	echo refs/notes/bar >expect &&
	shit_NOTES_REF=refs/notes/bar shit notes get-ref >actual &&
	test_cmp expect actual
'

test_expect_success 'shit notes get-ref (--ref)' '
	echo refs/notes/baz >expect &&
	shit_NOTES_REF=refs/notes/bar shit notes --ref=baz get-ref >actual &&
	test_cmp expect actual
'

test_expect_success 'setup testing of empty notes' '
	test_unconfig core.notesRef &&
	test_commit 16th &&
	empty_blob=$(shit hash-object -w /dev/null) &&
	echo "$empty_blob" >expect_empty
'

while read cmd
do
	test_expect_success "'shit notes $cmd' removes empty note" "
		test_might_fail shit notes remove HEAD &&
		MSG= shit notes $cmd &&
		test_must_fail shit notes list HEAD
	"

	test_expect_success "'shit notes $cmd --allow-empty' stores empty note" "
		test_might_fail shit notes remove HEAD &&
		MSG= shit notes $cmd --allow-empty &&
		shit notes list HEAD >actual &&
		test_cmp expect_empty actual
	"
done <<\EOF
add
add -F /dev/null
add -m ""
add -c "$empty_blob"
add -C "$empty_blob"
append
append -F /dev/null
append -m ""
append -c "$empty_blob"
append -C "$empty_blob"
edit
EOF

test_expect_success 'empty notes are displayed by shit log' '
	test_commit 17th &&
	shit log -1 >expect &&
	cat >>expect <<-EOF &&

		Notes:
	EOF
	shit notes add -C "$empty_blob" --allow-empty &&
	shit log -1 >actual &&
	test_cmp expect actual
'

test_done
