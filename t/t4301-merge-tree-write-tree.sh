#!/bin/sh

test_description='shit merge-tree --write-tree'

. ./test-lib.sh

# This test is ort-specific
if test "$shit_TEST_MERGE_ALGORITHM" != "ort"
then
	skip_all="shit_TEST_MERGE_ALGORITHM != ort"
	test_done
fi

test_expect_success setup '
	test_write_lines 1 2 3 4 5 >numbers &&
	echo hello >greeting &&
	echo foo >whatever &&
	shit add numbers greeting whatever &&
	test_tick &&
	shit commit -m initial &&

	shit branch side1 &&
	shit branch side2 &&
	shit branch side3 &&
	shit branch side4 &&

	shit checkout side1 &&
	test_write_lines 1 2 3 4 5 6 >numbers &&
	echo hi >greeting &&
	echo bar >whatever &&
	shit add numbers greeting whatever &&
	test_tick &&
	shit commit -m modify-stuff &&

	shit checkout side2 &&
	test_write_lines 0 1 2 3 4 5 >numbers &&
	echo yo >greeting &&
	shit rm whatever &&
	mkdir whatever &&
	>whatever/empty &&
	shit add numbers greeting whatever/empty &&
	test_tick &&
	shit commit -m other-modifications &&

	shit checkout side3 &&
	shit mv numbers sequence &&
	test_tick &&
	shit commit -m rename-numbers &&

	shit checkout side4 &&
	test_write_lines 0 1 2 3 4 5 >numbers &&
	echo yo >greeting &&
	shit add numbers greeting &&
	test_tick &&
	shit commit -m other-content-modifications &&

	shit switch --orphan unrelated &&
	>something-else &&
	shit add something-else &&
	test_tick &&
	shit commit -m first-commit
'

test_expect_success 'Clean merge' '
	TREE_OID=$(shit merge-tree --write-tree side1 side3) &&
	q_to_tab <<-EOF >expect &&
	100644 blob $(shit rev-parse side1:greeting)Qgreeting
	100644 blob $(shit rev-parse side1:numbers)Qsequence
	100644 blob $(shit rev-parse side1:whatever)Qwhatever
	EOF

	shit ls-tree $TREE_OID >actual &&
	test_cmp expect actual
'

test_expect_success 'Content merge and a few conflicts' '
	shit checkout side1^0 &&
	test_must_fail shit merge side2 &&
	expected_tree=$(shit rev-parse AUTO_MERGE) &&

	# We will redo the merge, while we are still in a conflicted state!
	shit ls-files -u >conflicted-file-info &&
	test_when_finished "shit reset --hard" &&

	test_expect_code 1 shit merge-tree --write-tree side1 side2 >RESULT &&
	actual_tree=$(head -n 1 RESULT) &&

	# Due to differences of e.g. "HEAD" vs "side1", the results will not
	# exactly match.  Dig into individual files.

	# Numbers should have three-way merged cleanly
	test_write_lines 0 1 2 3 4 5 6 >expect &&
	shit show ${actual_tree}:numbers >actual &&
	test_cmp expect actual &&

	# whatever and whatever~<branch> should have same HASHES
	shit rev-parse ${expected_tree}:whatever ${expected_tree}:whatever~HEAD >expect &&
	shit rev-parse ${actual_tree}:whatever ${actual_tree}:whatever~side1 >actual &&
	test_cmp expect actual &&

	# greeting should have a merge conflict
	shit show ${expected_tree}:greeting >tmp &&
	sed -e s/HEAD/side1/ tmp >expect &&
	shit show ${actual_tree}:greeting >actual &&
	test_cmp expect actual
'

test_expect_success 'Auto resolve conflicts by "ours" strategy option' '
	shit checkout side1^0 &&

	# make sure merge conflict exists
	test_must_fail shit merge side4 &&
	shit merge --abort &&

	shit merge -X ours side4 &&
	shit rev-parse HEAD^{tree} >expected &&

	shit merge-tree -X ours side1 side4 >actual &&

	test_cmp expected actual
'

test_expect_success 'Barf on misspelled option, with exit code other than 0 or 1' '
	# Mis-spell with single "s" instead of double "s"
	test_expect_code 129 shit merge-tree --write-tree --mesages FOOBAR side1 side2 2>expect &&

	grep "error: unknown option.*mesages" expect
'

test_expect_success 'Barf on too many arguments' '
	test_expect_code 129 shit merge-tree --write-tree side1 side2 invalid 2>expect &&

	grep "^usage: shit merge-tree" expect
'

anonymize_hash() {
	sed -e "s/[0-9a-f]\{40,\}/HASH/g" "$@"
}

test_expect_success 'test conflict notices and such' '
	test_expect_code 1 shit merge-tree --write-tree --name-only side1 side2 >out &&
	anonymize_hash out >actual &&

	# Expected results:
	#   "greeting" should merge with conflicts
	#   "numbers" should merge cleanly
	#   "whatever" has *both* a modify/delete and a file/directory conflict
	cat <<-EOF >expect &&
	HASH
	greeting
	whatever~side1

	Auto-merging greeting
	CONFLICT (content): Merge conflict in greeting
	Auto-merging numbers
	CONFLICT (file/directory): directory in the way of whatever from side1; moving it to whatever~side1 instead.
	CONFLICT (modify/delete): whatever~side1 deleted in side2 and modified in side1.  Version side1 of whatever~side1 left in tree.
	EOF

	test_cmp expect actual
'

# directory rename + content conflict
#   Commit O: foo, olddir/{a,b,c}
#   Commit A: modify foo, newdir/{a,b,c}
#   Commit B: modify foo differently & rename foo -> olddir/bar
#   Expected: CONFLICT(content) for newdir/bar (not olddir/bar or foo)

test_expect_success 'directory rename + content conflict' '
	# Setup
	shit init dir-rename-and-content &&
	(
		cd dir-rename-and-content &&
		test_write_lines 1 2 3 4 5 >foo &&
		mkdir olddir &&
		for i in a b c; do echo $i >olddir/$i || exit 1; done &&
		shit add foo olddir &&
		shit commit -m "original" &&

		shit branch O &&
		shit branch A &&
		shit branch B &&

		shit checkout A &&
		test_write_lines 1 2 3 4 5 6 >foo &&
		shit add foo &&
		shit mv olddir newdir &&
		shit commit -m "Modify foo, rename olddir to newdir" &&

		shit checkout B &&
		test_write_lines 1 2 3 4 5 six >foo &&
		shit add foo &&
		shit mv foo olddir/bar &&
		shit commit -m "Modify foo & rename foo -> olddir/bar"
	) &&
	# Testing
	(
		cd dir-rename-and-content &&

		test_expect_code 1 \
			shit merge-tree -z A^0 B^0 >out &&
		echo >>out &&
		anonymize_hash out >actual &&
		q_to_tab <<-\EOF | lf_to_nul >expect &&
		HASH
		100644 HASH 1Qnewdir/bar
		100644 HASH 2Qnewdir/bar
		100644 HASH 3Qnewdir/bar
		EOF

		q_to_nul <<-EOF >>expect &&
		Q2Qnewdir/barQolddir/barQCONFLICT (directory rename suggested)QCONFLICT (file location): foo renamed to olddir/bar in B^0, inside a directory that was renamed in A^0, suggesting it should perhaps be moved to newdir/bar.
		Q1Qnewdir/barQAuto-mergingQAuto-merging newdir/bar
		Q1Qnewdir/barQCONFLICT (contents)QCONFLICT (content): Merge conflict in newdir/bar
		Q
		EOF
		test_cmp expect actual
	)
'

# rename/delete + modify/delete handling
#   Commit O: foo
#   Commit A: modify foo + rename to bar
#   Commit B: delete foo
#   Expected: CONFLICT(rename/delete) + CONFLICT(modify/delete)

test_expect_success 'rename/delete handling' '
	# Setup
	shit init rename-delete &&
	(
		cd rename-delete &&
		test_write_lines 1 2 3 4 5 >foo &&
		shit add foo &&
		shit commit -m "original" &&

		shit branch O &&
		shit branch A &&
		shit branch B &&

		shit checkout A &&
		test_write_lines 1 2 3 4 5 6 >foo &&
		shit add foo &&
		shit mv foo bar &&
		shit commit -m "Modify foo, rename to bar" &&

		shit checkout B &&
		shit rm foo &&
		shit commit -m "remove foo"
	) &&
	# Testing
	(
		cd rename-delete &&

		test_expect_code 1 \
			shit merge-tree -z A^0 B^0 >out &&
		echo >>out &&
		anonymize_hash out >actual &&
		q_to_tab <<-\EOF | lf_to_nul >expect &&
		HASH
		100644 HASH 1Qbar
		100644 HASH 2Qbar
		EOF

		q_to_nul <<-EOF >>expect &&
		Q2QbarQfooQCONFLICT (rename/delete)QCONFLICT (rename/delete): foo renamed to bar in A^0, but deleted in B^0.
		Q1QbarQCONFLICT (modify/delete)QCONFLICT (modify/delete): bar deleted in B^0 and modified in A^0.  Version A^0 of bar left in tree.
		Q
		EOF
		test_cmp expect actual
	)
'

# rename/add handling
#   Commit O: foo
#   Commit A: modify foo, add different bar
#   Commit B: modify & rename foo->bar
#   Expected: CONFLICT(add/add) [via rename collide] for bar

test_expect_success 'rename/add handling' '
	# Setup
	shit init rename-add &&
	(
		cd rename-add &&
		test_write_lines original 1 2 3 4 5 >foo &&
		shit add foo &&
		shit commit -m "original" &&

		shit branch O &&
		shit branch A &&
		shit branch B &&

		shit checkout A &&
		test_write_lines 1 2 3 4 5 >foo &&
		echo "different file" >bar &&
		shit add foo bar &&
		shit commit -m "Modify foo, add bar" &&

		shit checkout B &&
		test_write_lines original 1 2 3 4 5 6 >foo &&
		shit add foo &&
		shit mv foo bar &&
		shit commit -m "rename foo to bar"
	) &&
	# Testing
	(
		cd rename-add &&

		test_expect_code 1 \
			shit merge-tree -z A^0 B^0 >out &&
		echo >>out &&

		#
		# First, check that the bar that appears at stage 3 does not
		# correspond to an individual blob anywhere in history
		#
		hash=$(tr "\0" "\n" <out | head -n 3 | grep 3.bar | cut -f 2 -d " ") &&
		shit rev-list --objects --all >all_blobs &&
		! grep $hash all_blobs &&

		#
		# Second, check anonymized hash output against expectation
		#
		anonymize_hash out >actual &&
		q_to_tab <<-\EOF | lf_to_nul >expect &&
		HASH
		100644 HASH 2Qbar
		100644 HASH 3Qbar
		EOF

		q_to_nul <<-EOF >>expect &&
		Q1QbarQAuto-mergingQAuto-merging bar
		Q1QbarQCONFLICT (contents)QCONFLICT (add/add): Merge conflict in bar
		Q1QfooQAuto-mergingQAuto-merging foo
		Q
		EOF
		test_cmp expect actual
	)
'

# rename/add, where add is a mode conflict
#   Commit O: foo
#   Commit A: modify foo, add symlink bar
#   Commit B: modify & rename foo->bar
#   Expected: CONFLICT(distinct modes) for bar

test_expect_success SYMLINKS 'rename/add, where add is a mode conflict' '
	# Setup
	shit init rename-add-symlink &&
	(
		cd rename-add-symlink &&
		test_write_lines original 1 2 3 4 5 >foo &&
		shit add foo &&
		shit commit -m "original" &&

		shit branch O &&
		shit branch A &&
		shit branch B &&

		shit checkout A &&
		test_write_lines 1 2 3 4 5 >foo &&
		ln -s foo bar &&
		shit add foo bar &&
		shit commit -m "Modify foo, add symlink bar" &&

		shit checkout B &&
		test_write_lines original 1 2 3 4 5 6 >foo &&
		shit add foo &&
		shit mv foo bar &&
		shit commit -m "rename foo to bar"
	) &&
	# Testing
	(
		cd rename-add-symlink &&

		test_expect_code 1 \
			shit merge-tree -z A^0 B^0 >out &&
		echo >>out &&

		#
		# First, check that the bar that appears at stage 3 does not
		# correspond to an individual blob anywhere in history
		#
		hash=$(tr "\0" "\n" <out | head -n 3 | grep 3.bar | cut -f 2 -d " ") &&
		shit rev-list --objects --all >all_blobs &&
		! grep $hash all_blobs &&

		#
		# Second, check anonymized hash output against expectation
		#
		anonymize_hash out >actual &&
		q_to_tab <<-\EOF | lf_to_nul >expect &&
		HASH
		120000 HASH 2Qbar
		100644 HASH 3Qbar~B^0
		EOF

		q_to_nul <<-EOF >>expect &&
		Q2QbarQbar~B^0QCONFLICT (distinct modes)QCONFLICT (distinct types): bar had different types on each side; renamed one of them so each can be recorded somewhere.
		Q1QfooQAuto-mergingQAuto-merging foo
		Q
		EOF
		test_cmp expect actual
	)
'

# rename/rename(1to2) + content conflict handling
#   Commit O: foo
#   Commit A: modify foo & rename to bar
#   Commit B: modify foo & rename to baz
#   Expected: CONFLICT(rename/rename)

test_expect_success 'rename/rename + content conflict' '
	# Setup
	shit init rr-plus-content &&
	(
		cd rr-plus-content &&
		test_write_lines 1 2 3 4 5 >foo &&
		shit add foo &&
		shit commit -m "original" &&

		shit branch O &&
		shit branch A &&
		shit branch B &&

		shit checkout A &&
		test_write_lines 1 2 3 4 5 six >foo &&
		shit add foo &&
		shit mv foo bar &&
		shit commit -m "Modify foo + rename to bar" &&

		shit checkout B &&
		test_write_lines 1 2 3 4 5 6 >foo &&
		shit add foo &&
		shit mv foo baz &&
		shit commit -m "Modify foo + rename to baz"
	) &&
	# Testing
	(
		cd rr-plus-content &&

		test_expect_code 1 \
			shit merge-tree -z A^0 B^0 >out &&
		echo >>out &&
		anonymize_hash out >actual &&
		q_to_tab <<-\EOF | lf_to_nul >expect &&
		HASH
		100644 HASH 2Qbar
		100644 HASH 3Qbaz
		100644 HASH 1Qfoo
		EOF

		q_to_nul <<-EOF >>expect &&
		Q1QfooQAuto-mergingQAuto-merging foo
		Q3QfooQbarQbazQCONFLICT (rename/rename)QCONFLICT (rename/rename): foo renamed to bar in A^0 and to baz in B^0.
		Q
		EOF
		test_cmp expect actual
	)
'

# rename/add/delete
#   Commit O: foo
#   Commit A: rm foo, add different bar
#   Commit B: rename foo->bar
#   Expected: CONFLICT (rename/delete), CONFLICT(add/add) [via rename collide]
#             for bar

test_expect_success 'rename/add/delete conflict' '
	# Setup
	shit init rad &&
	(
		cd rad &&
		echo "original file" >foo &&
		shit add foo &&
		shit commit -m "original" &&

		shit branch O &&
		shit branch A &&
		shit branch B &&

		shit checkout A &&
		shit rm foo &&
		echo "different file" >bar &&
		shit add bar &&
		shit commit -m "Remove foo, add bar" &&

		shit checkout B &&
		shit mv foo bar &&
		shit commit -m "rename foo to bar"
	) &&
	# Testing
	(
		cd rad &&

		test_expect_code 1 \
			shit merge-tree -z B^0 A^0 >out &&
		echo >>out &&
		anonymize_hash out >actual &&

		q_to_tab <<-\EOF | lf_to_nul >expect &&
		HASH
		100644 HASH 2Qbar
		100644 HASH 3Qbar

		EOF

		q_to_nul <<-EOF >>expect &&
		2QbarQfooQCONFLICT (rename/delete)QCONFLICT (rename/delete): foo renamed to bar in B^0, but deleted in A^0.
		Q1QbarQAuto-mergingQAuto-merging bar
		Q1QbarQCONFLICT (contents)QCONFLICT (add/add): Merge conflict in bar
		Q
		EOF
		test_cmp expect actual
	)
'

# rename/rename(2to1)/delete/delete
#   Commit O: foo, bar
#   Commit A: rename foo->baz, rm bar
#   Commit B: rename bar->baz, rm foo
#   Expected: 2x CONFLICT (rename/delete), CONFLICT (add/add) via colliding
#             renames for baz

test_expect_success 'rename/rename(2to1)/delete/delete conflict' '
	# Setup
	shit init rrdd &&
	(
		cd rrdd &&
		echo foo >foo &&
		echo bar >bar &&
		shit add foo bar &&
		shit commit -m O &&

		shit branch O &&
		shit branch A &&
		shit branch B &&

		shit checkout A &&
		shit mv foo baz &&
		shit rm bar &&
		shit commit -m "Rename foo, remove bar" &&

		shit checkout B &&
		shit mv bar baz &&
		shit rm foo &&
		shit commit -m "Rename bar, remove foo"
	) &&
	# Testing
	(
		cd rrdd &&

		test_expect_code 1 \
			shit merge-tree -z A^0 B^0 >out &&
		echo >>out &&
		anonymize_hash out >actual &&

		q_to_tab <<-\EOF | lf_to_nul >expect &&
		HASH
		100644 HASH 2Qbaz
		100644 HASH 3Qbaz

		EOF

		q_to_nul <<-EOF >>expect &&
		2QbazQbarQCONFLICT (rename/delete)QCONFLICT (rename/delete): bar renamed to baz in B^0, but deleted in A^0.
		Q2QbazQfooQCONFLICT (rename/delete)QCONFLICT (rename/delete): foo renamed to baz in A^0, but deleted in B^0.
		Q1QbazQAuto-mergingQAuto-merging baz
		Q1QbazQCONFLICT (contents)QCONFLICT (add/add): Merge conflict in baz
		Q
		EOF
		test_cmp expect actual
	)
'

# mod6: chains of rename/rename(1to2) + add/add via colliding renames
#   Commit O: one,      three,       five
#   Commit A: one->two, three->four, five->six
#   Commit B: one->six, three->two,  five->four
#   Expected: three CONFLICT(rename/rename) messages + three CONFLICT(add/add)
#             messages; each path in two of the multi-way merged contents
#             found in two, four, six

test_expect_success 'mod6: chains of rename/rename(1to2) and add/add via colliding renames' '
	# Setup
	shit init mod6 &&
	(
		cd mod6 &&
		test_seq 11 19 >one &&
		test_seq 31 39 >three &&
		test_seq 51 59 >five &&
		shit add . &&
		test_tick &&
		shit commit -m "O" &&

		shit branch O &&
		shit branch A &&
		shit branch B &&

		shit checkout A &&
		test_seq 10 19 >one &&
		echo 40        >>three &&
		shit add one three &&
		shit mv  one   two  &&
		shit mv  three four &&
		shit mv  five  six  &&
		test_tick &&
		shit commit -m "A" &&

		shit checkout B &&
		echo 20    >>one       &&
		echo forty >>three     &&
		echo 60    >>five      &&
		shit add one three five &&
		shit mv  one   six  &&
		shit mv  three two  &&
		shit mv  five  four &&
		test_tick &&
		shit commit -m "B"
	) &&
	# Testing
	(
		cd mod6 &&

		test_expect_code 1 \
			shit merge-tree -z A^0 B^0 >out &&
		echo >>out &&

		#
		# First, check that some of the hashes that appear as stage
		# conflict entries do not appear as individual blobs anywhere
		# in history.
		#
		hash1=$(tr "\0" "\n" <out | head | grep 2.four | cut -f 2 -d " ") &&
		hash2=$(tr "\0" "\n" <out | head | grep 3.two | cut -f 2 -d " ") &&
		shit rev-list --objects --all >all_blobs &&
		! grep $hash1 all_blobs &&
		! grep $hash2 all_blobs &&

		#
		# Now compare anonymized hash output with expectation
		#
		anonymize_hash out >actual &&
		q_to_tab <<-\EOF | lf_to_nul >expect &&
		HASH
		100644 HASH 1Qfive
		100644 HASH 2Qfour
		100644 HASH 3Qfour
		100644 HASH 1Qone
		100644 HASH 2Qsix
		100644 HASH 3Qsix
		100644 HASH 1Qthree
		100644 HASH 2Qtwo
		100644 HASH 3Qtwo

		EOF

		q_to_nul <<-EOF >>expect &&
		3QfiveQsixQfourQCONFLICT (rename/rename)QCONFLICT (rename/rename): five renamed to six in A^0 and to four in B^0.
		Q1QfourQAuto-mergingQAuto-merging four
		Q1QfourQCONFLICT (contents)QCONFLICT (add/add): Merge conflict in four
		Q1QoneQAuto-mergingQAuto-merging one
		Q3QoneQtwoQsixQCONFLICT (rename/rename)QCONFLICT (rename/rename): one renamed to two in A^0 and to six in B^0.
		Q1QsixQAuto-mergingQAuto-merging six
		Q1QsixQCONFLICT (contents)QCONFLICT (add/add): Merge conflict in six
		Q1QthreeQAuto-mergingQAuto-merging three
		Q3QthreeQfourQtwoQCONFLICT (rename/rename)QCONFLICT (rename/rename): three renamed to four in A^0 and to two in B^0.
		Q1QtwoQAuto-mergingQAuto-merging two
		Q1QtwoQCONFLICT (contents)QCONFLICT (add/add): Merge conflict in two
		Q
		EOF
		test_cmp expect actual
	)
'

# directory rename + rename/delete + modify/delete + directory/file conflict
#   Commit O: foo, olddir/{a,b,c}
#   Commit A: delete foo, rename olddir/ -> newdir/, add newdir/bar/file
#   Commit B: modify foo & rename foo -> olddir/bar
#   Expected: CONFLICT(content) for newdir/bar (not olddir/bar or foo)

test_expect_success 'directory rename + rename/delete + modify/delete + directory/file conflict' '
	# Setup
	shit init 4-stacked-conflict &&
	(
		cd 4-stacked-conflict &&
		test_write_lines 1 2 3 4 5 >foo &&
		mkdir olddir &&
		for i in a b c; do echo $i >olddir/$i || exit 1; done &&
		shit add foo olddir &&
		shit commit -m "original" &&

		shit branch O &&
		shit branch A &&
		shit branch B &&

		shit checkout A &&
		shit rm foo &&
		shit mv olddir newdir &&
		mkdir newdir/bar &&
		>newdir/bar/file &&
		shit add newdir/bar/file &&
		shit commit -m "rm foo, olddir/ -> newdir/, + newdir/bar/file" &&

		shit checkout B &&
		test_write_lines 1 2 3 4 5 6 >foo &&
		shit add foo &&
		shit mv foo olddir/bar &&
		shit commit -m "Modify foo & rename foo -> olddir/bar"
	) &&
	# Testing
	(
		cd 4-stacked-conflict &&

		test_expect_code 1 \
			shit merge-tree -z A^0 B^0 >out &&
		echo >>out &&
		anonymize_hash out >actual &&

		q_to_tab <<-\EOF | lf_to_nul >expect &&
		HASH
		100644 HASH 1Qnewdir/bar~B^0
		100644 HASH 3Qnewdir/bar~B^0
		EOF

		q_to_nul <<-EOF >>expect &&
		Q2Qnewdir/barQolddir/barQCONFLICT (directory rename suggested)QCONFLICT (file location): foo renamed to olddir/bar in B^0, inside a directory that was renamed in A^0, suggesting it should perhaps be moved to newdir/bar.
		Q2Qnewdir/barQfooQCONFLICT (rename/delete)QCONFLICT (rename/delete): foo renamed to newdir/bar in B^0, but deleted in A^0.
		Q2Qnewdir/bar~B^0Qnewdir/barQCONFLICT (file/directory)QCONFLICT (file/directory): directory in the way of newdir/bar from B^0; moving it to newdir/bar~B^0 instead.
		Q1Qnewdir/bar~B^0QCONFLICT (modify/delete)QCONFLICT (modify/delete): newdir/bar~B^0 deleted in A^0 and modified in B^0.  Version B^0 of newdir/bar~B^0 left in tree.
		Q
		EOF
		test_cmp expect actual
	)
'

for opt in $(shit merge-tree --shit-completion-helper-all)
do
	if test $opt = "--trivial-merge" || test $opt = "--write-tree"
	then
		continue
	fi

	test_expect_success "usage: --trivial-merge is incompatible with $opt" '
		test_expect_code 128 shit merge-tree --trivial-merge $opt side1 side2 side3
	'
done

test_expect_success 'Just the conflicted files without the messages' '
	test_expect_code 1 shit merge-tree --write-tree --no-messages --name-only side1 side2 >out &&
	anonymize_hash out >actual &&

	test_write_lines HASH greeting whatever~side1 >expect &&

	test_cmp expect actual
'

test_expect_success 'Check conflicted oids and modes without messages' '
	test_expect_code 1 shit merge-tree --write-tree --no-messages side1 side2 >out &&
	anonymize_hash out >actual &&

	# Compare the basic output format
	q_to_tab >expect <<-\EOF &&
	HASH
	100644 HASH 1Qgreeting
	100644 HASH 2Qgreeting
	100644 HASH 3Qgreeting
	100644 HASH 1Qwhatever~side1
	100644 HASH 2Qwhatever~side1
	EOF

	test_cmp expect actual &&

	# Check the actual hashes against the `ls-files -u` output too
	tail -n +2 out | sed -e s/side1/HEAD/ >actual &&
	test_cmp conflicted-file-info actual
'

test_expect_success 'NUL terminated conflicted file "lines"' '
	shit checkout -b tweak1 side1 &&
	test_write_lines zero 1 2 3 4 5 6 >numbers &&
	shit add numbers &&
	shit mv numbers "Αυτά μου φαίνονται κινέζικα" &&
	shit commit -m "Renamed numbers" &&

	test_expect_code 1 shit merge-tree --write-tree -z tweak1 side2 >out &&
	echo >>out &&
	anonymize_hash out >actual &&

	# Expected results:
	#   "greeting" should merge with conflicts
	#   "whatever" has *both* a modify/delete and a file/directory conflict
	#   "Αυτά μου φαίνονται κινέζικα" should have a conflict
	echo HASH | lf_to_nul >expect &&

	q_to_tab <<-EOF | lf_to_nul >>expect &&
	100644 HASH 1Qgreeting
	100644 HASH 2Qgreeting
	100644 HASH 3Qgreeting
	100644 HASH 1Qwhatever~tweak1
	100644 HASH 2Qwhatever~tweak1
	100644 HASH 1QΑυτά μου φαίνονται κινέζικα
	100644 HASH 2QΑυτά μου φαίνονται κινέζικα
	100644 HASH 3QΑυτά μου φαίνονται κινέζικα

	EOF

	q_to_nul <<-EOF >>expect &&
	1QgreetingQAuto-mergingQAuto-merging greeting
	Q1QgreetingQCONFLICT (contents)QCONFLICT (content): Merge conflict in greeting
	Q2Qwhatever~tweak1QwhateverQCONFLICT (file/directory)QCONFLICT (file/directory): directory in the way of whatever from tweak1; moving it to whatever~tweak1 instead.
	Q1Qwhatever~tweak1QCONFLICT (modify/delete)QCONFLICT (modify/delete): whatever~tweak1 deleted in side2 and modified in tweak1.  Version tweak1 of whatever~tweak1 left in tree.
	Q1QΑυτά μου φαίνονται κινέζικαQAuto-mergingQAuto-merging Αυτά μου φαίνονται κινέζικα
	Q1QΑυτά μου φαίνονται κινέζικαQCONFLICT (contents)QCONFLICT (content): Merge conflict in Αυτά μου φαίνονται κινέζικα
	Q
	EOF

	test_cmp expect actual
'

test_expect_success 'error out by default for unrelated histories' '
	test_expect_code 128 shit merge-tree --write-tree side1 unrelated 2>error &&

	grep "refusing to merge unrelated histories" error
'

test_expect_success 'can override merge of unrelated histories' '
	shit merge-tree --write-tree --allow-unrelated-histories side1 unrelated >tree &&
	TREE=$(cat tree) &&

	shit rev-parse side1:numbers side1:greeting side1:whatever unrelated:something-else >expect &&
	shit rev-parse $TREE:numbers $TREE:greeting $TREE:whatever $TREE:something-else >actual &&

	test_cmp expect actual
'

test_expect_success SANITY 'merge-ort fails gracefully in a read-only repository' '
	shit init --bare read-only &&
	shit defecate read-only side1 side2 side3 &&
	test_when_finished "chmod -R u+w read-only" &&
	chmod -R a-w read-only &&
	test_must_fail shit -C read-only merge-tree side1 side3 &&
	test_must_fail shit -C read-only merge-tree side1 side2
'

test_expect_success '--stdin with both a successful and a conflicted merge' '
	printf "side1 side3\nside1 side2" | shit merge-tree --stdin >actual &&

	shit checkout side1^0 &&
	shit merge side3 &&

	printf "1\0" >expect &&
	shit rev-parse HEAD^{tree} | lf_to_nul >>expect &&
	printf "\0" >>expect &&

	shit checkout side1^0 &&
	test_must_fail shit merge side2 &&
	sed s/HEAD/side1/ greeting >tmp &&
	mv tmp greeting &&
	shit add -u &&
	shit mv whatever~HEAD whatever~side1 &&

	printf "0\0" >>expect &&
	shit write-tree | lf_to_nul >>expect &&

	cat <<-EOF | q_to_tab | lf_to_nul >>expect &&
	100644 $(shit rev-parse side1~1:greeting) 1Qgreeting
	100644 $(shit rev-parse side1:greeting) 2Qgreeting
	100644 $(shit rev-parse side2:greeting) 3Qgreeting
	100644 $(shit rev-parse side1~1:whatever) 1Qwhatever~side1
	100644 $(shit rev-parse side1:whatever) 2Qwhatever~side1
	EOF

	q_to_nul <<-EOF >>expect &&
	Q1QgreetingQAuto-mergingQAuto-merging greeting
	Q1QgreetingQCONFLICT (contents)QCONFLICT (content): Merge conflict in greeting
	Q1QnumbersQAuto-mergingQAuto-merging numbers
	Q2Qwhatever~side1QwhateverQCONFLICT (file/directory)QCONFLICT (file/directory): directory in the way of whatever from side1; moving it to whatever~side1 instead.
	Q1Qwhatever~side1QCONFLICT (modify/delete)QCONFLICT (modify/delete): whatever~side1 deleted in side2 and modified in side1.  Version side1 of whatever~side1 left in tree.
	EOF

	printf "\0\0" >>expect &&

	test_cmp expect actual
'


test_expect_success '--merge-base is incompatible with --stdin' '
	test_must_fail shit merge-tree --merge-base=side1 --stdin 2>expect &&

	grep "^fatal: .*merge-base.*stdin.* cannot be used together" expect
'

# specify merge-base as parent of branch2
# shit merge-tree --write-tree --merge-base=c2 c1 c3
#   Commit c1: add file1
#   Commit c2: add file2 after c1
#   Commit c3: add file3 after c2
#   Expected: add file3, and file2 does NOT appear

test_expect_success 'specify merge-base as parent of branch2' '
	# Setup
	test_when_finished "rm -rf base-b2-p" &&
	shit init base-b2-p &&
	test_commit -C base-b2-p c1 file1 &&
	test_commit -C base-b2-p c2 file2 &&
	test_commit -C base-b2-p c3 file3 &&

	# Testing
	TREE_OID=$(shit -C base-b2-p merge-tree --write-tree --merge-base=c2 c1 c3) &&

	q_to_tab <<-EOF >expect &&
	100644 blob $(shit -C base-b2-p rev-parse c1:file1)Qfile1
	100644 blob $(shit -C base-b2-p rev-parse c3:file3)Qfile3
	EOF

	shit -C base-b2-p ls-tree $TREE_OID >actual &&
	test_cmp expect actual
'

# Since the earlier tests have verified that individual merge-tree calls
# are doing the right thing, this test case is only used to verify that
# we can also trigger merges via --stdin, and that when we do we get
# the same answer as running a bunch of separate merges.

test_expect_success 'check the input format when --stdin is passed' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	test_commit -C repo c1 &&
	test_commit -C repo c2 &&
	test_commit -C repo c3 &&
	printf "c1 c3\nc2 -- c1 c3\nc2 c3" | shit -C repo merge-tree --stdin >actual &&

	printf "1\0" >expect &&
	shit -C repo merge-tree --write-tree -z c1 c3 >>expect &&
	printf "\0" >>expect &&

	printf "1\0" >>expect &&
	shit -C repo merge-tree --write-tree -z --merge-base=c2 c1 c3 >>expect &&
	printf "\0" >>expect &&

	printf "1\0" >>expect &&
	shit -C repo merge-tree --write-tree -z c2 c3 >>expect &&
	printf "\0" >>expect &&

	test_cmp expect actual
'

test_expect_success '--merge-base with tree OIDs' '
	shit merge-tree --merge-base=side1^ side1 side3 >with-commits &&
	shit merge-tree --merge-base=side1^^{tree} side1^{tree} side3^{tree} >with-trees &&
	test_cmp with-commits with-trees
'

test_expect_success 'error out on missing tree objects' '
	shit init --bare missing-tree.shit &&
	shit rev-list side3 >list &&
	shit rev-parse side3^: >>list &&
	shit pack-objects missing-tree.shit/objects/pack/side3-tree-is-missing <list &&
	side3=$(shit rev-parse side3) &&
	test_must_fail shit --shit-dir=missing-tree.shit merge-tree $side3^ $side3 >actual 2>err &&
	test_grep "Could not read $(shit rev-parse $side3:)" err &&
	test_must_be_empty actual
'

test_expect_success 'error out on missing blob objects' '
	echo 1 | shit hash-object -w --stdin >blob1 &&
	echo 2 | shit hash-object -w --stdin >blob2 &&
	echo 3 | shit hash-object -w --stdin >blob3 &&
	printf "100644 blob $(cat blob1)\tblob\n" | shit mktree >tree1 &&
	printf "100644 blob $(cat blob2)\tblob\n" | shit mktree >tree2 &&
	printf "100644 blob $(cat blob3)\tblob\n" | shit mktree >tree3 &&
	shit init --bare missing-blob.shit &&
	cat blob1 blob3 tree1 tree2 tree3 |
	shit pack-objects missing-blob.shit/objects/pack/side1-whatever-is-missing &&
	test_must_fail shit --shit-dir=missing-blob.shit >actual 2>err \
		merge-tree --merge-base=$(cat tree1) $(cat tree2) $(cat tree3) &&
	test_grep "unable to read blob object $(cat blob2)" err &&
	test_must_be_empty actual
'

test_expect_success 'error out on missing commits as well' '
	shit init --bare missing-commit.shit &&
	shit rev-list --objects side1 side3 >list-including-initial &&
	grep -v ^$(shit rev-parse side1^) <list-including-initial >list &&
	shit pack-objects missing-commit.shit/objects/pack/missing-initial <list &&
	side1=$(shit rev-parse side1) &&
	side3=$(shit rev-parse side3) &&
	test_must_fail shit --shit-dir=missing-commit.shit \
		merge-tree --allow-unrelated-histories $side1 $side3 >actual &&
	test_must_be_empty actual
'

test_done
