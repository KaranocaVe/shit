#!/bin/sh

test_description='remerge-diff handling'

. ./test-lib.sh

# This test is ort-specific
if test "${shit_TEST_MERGE_ALGORITHM}" != ort
then
	skip_all="shit_TEST_MERGE_ALGORITHM != ort"
	test_done
fi

test_expect_success 'setup basic merges' '
	test_write_lines 1 2 3 4 5 6 7 8 9 >numbers &&
	shit add numbers &&
	shit commit -m base &&

	shit branch feature_a &&
	shit branch feature_b &&
	shit branch feature_c &&

	shit branch ab_resolution &&
	shit branch bc_resolution &&

	shit checkout feature_a &&
	test_write_lines 1 2 three 4 5 6 7 eight 9 >numbers &&
	shit commit -a -m change_a &&

	shit checkout feature_b &&
	test_write_lines 1 2 tres 4 5 6 7 8 9 >numbers &&
	shit commit -a -m change_b &&

	shit checkout feature_c &&
	test_write_lines 1 2 3 4 5 6 7 8 9 10 >numbers &&
	shit commit -a -m change_c &&

	shit checkout bc_resolution &&
	shit merge --ff-only feature_b &&
	# no conflict
	shit merge feature_c &&

	shit checkout ab_resolution &&
	shit merge --ff-only feature_a &&
	# conflicts!
	test_must_fail shit merge feature_b &&
	# Resolve conflict...and make another change elsewhere
	test_write_lines 1 2 drei 4 5 6 7 acht 9 >numbers &&
	shit add numbers &&
	shit merge --continue
'

test_expect_success 'remerge-diff on a clean merge' '
	shit log -1 --oneline bc_resolution >expect &&
	shit show --oneline --remerge-diff bc_resolution >actual &&
	test_cmp expect actual
'

test_expect_success 'remerge-diff on a clean merge with a filter' '
	shit show --oneline --remerge-diff --diff-filter=U bc_resolution >actual &&
	test_must_be_empty actual
'

test_expect_success 'remerge-diff with both a resolved conflict and an unrelated change' '
	shit log -1 --oneline ab_resolution >tmp &&
	cat <<-EOF >>tmp &&
	diff --shit a/numbers b/numbers
	remerge CONFLICT (content): Merge conflict in numbers
	index a1fb731..6875544 100644
	--- a/numbers
	+++ b/numbers
	@@ -1,13 +1,9 @@
	 1
	 2
	-<<<<<<< b0ed5cb (change_a)
	-three
	-=======
	-tres
	->>>>>>> 6cd3f82 (change_b)
	+drei
	 4
	 5
	 6
	 7
	-eight
	+acht
	 9
	EOF
	# Hashes above are sha1; rip them out so test works with sha256
	sed -e "s/[0-9a-f]\{7,\}/HASH/g" tmp >expect &&

	shit show --oneline --remerge-diff ab_resolution >tmp &&
	sed -e "s/[0-9a-f]\{7,\}/HASH/g" tmp >actual &&
	test_cmp expect actual
'

test_expect_success 'pickaxe still includes additional headers for relevant changes' '
	# reuses "expect" from the previous testcase

	shit log --oneline --remerge-diff -Sacht ab_resolution >tmp &&
	sed -e "s/[0-9a-f]\{7,\}/HASH/g" tmp >actual &&
	test_cmp expect actual
'

test_expect_success 'can filter out additional headers with pickaxe' '
	shit show --remerge-diff --submodule=log --find-object=HEAD ab_resolution >actual &&
	test_must_be_empty actual &&

	shit show --remerge-diff -S"not present" --all >actual &&
	test_must_be_empty actual
'

test_expect_success 'setup non-content conflicts' '
	shit switch --orphan base &&

	test_write_lines 1 2 3 4 5 6 7 8 9 >numbers &&
	test_write_lines a b c d e f g h i >letters &&
	test_write_lines in the way >content &&
	shit add numbers letters content &&
	shit commit -m base &&

	shit branch side1 &&
	shit branch side2 &&

	shit checkout side1 &&
	test_write_lines 1 2 three 4 5 6 7 8 9 >numbers &&
	shit mv letters letters_side1 &&
	shit mv content file_or_directory &&
	shit add numbers &&
	shit commit -m side1 &&

	shit checkout side2 &&
	shit rm numbers &&
	shit mv letters letters_side2 &&
	mkdir file_or_directory &&
	echo hello >file_or_directory/world &&
	shit add file_or_directory/world &&
	shit commit -m side2 &&

	shit checkout -b resolution side1 &&
	test_must_fail shit merge side2 &&
	test_write_lines 1 2 three 4 5 6 7 8 9 >numbers &&
	shit add numbers &&
	shit add letters_side1 &&
	shit rm letters &&
	shit rm letters_side2 &&
	shit add file_or_directory~HEAD &&
	shit mv file_or_directory~HEAD wanted_content &&
	shit commit -m resolved
'

test_expect_success 'remerge-diff with non-content conflicts' '
	shit log -1 --oneline resolution >tmp &&
	cat <<-EOF >>tmp &&
	diff --shit a/file_or_directory~HASH (side1) b/wanted_content
	similarity index 100%
	rename from file_or_directory~HASH (side1)
	rename to wanted_content
	remerge CONFLICT (file/directory): directory in the way of file_or_directory from HASH (side1); moving it to file_or_directory~HASH (side1) instead.
	diff --shit a/letters b/letters
	remerge CONFLICT (rename/rename): letters renamed to letters_side1 in HASH (side1) and to letters_side2 in HASH (side2).
	diff --shit a/letters_side2 b/letters_side2
	deleted file mode 100644
	index b236ae5..0000000
	--- a/letters_side2
	+++ /dev/null
	@@ -1,9 +0,0 @@
	-a
	-b
	-c
	-d
	-e
	-f
	-g
	-h
	-i
	diff --shit a/numbers b/numbers
	remerge CONFLICT (modify/delete): numbers deleted in HASH (side2) and modified in HASH (side1).  Version HASH (side1) of numbers left in tree.
	EOF
	# We still have some sha1 hashes above; rip them out so test works
	# with sha256
	sed -e "s/[0-9a-f]\{7,\}/HASH/g" tmp >expect &&

	shit show --oneline --remerge-diff resolution >tmp &&
	sed -e "s/[0-9a-f]\{7,\}/HASH/g" tmp >actual &&
	test_cmp expect actual
'

test_expect_success 'remerge-diff w/ diff-filter=U: all conflict headers, no diff content' '
	shit log -1 --oneline resolution >tmp &&
	cat <<-EOF >>tmp &&
	diff --shit a/file_or_directory~HASH (side1) b/file_or_directory~HASH (side1)
	remerge CONFLICT (file/directory): directory in the way of file_or_directory from HASH (side1); moving it to file_or_directory~HASH (side1) instead.
	diff --shit a/letters b/letters
	remerge CONFLICT (rename/rename): letters renamed to letters_side1 in HASH (side1) and to letters_side2 in HASH (side2).
	diff --shit a/numbers b/numbers
	remerge CONFLICT (modify/delete): numbers deleted in HASH (side2) and modified in HASH (side1).  Version HASH (side1) of numbers left in tree.
	EOF
	# We still have some sha1 hashes above; rip them out so test works
	# with sha256
	sed -e "s/[0-9a-f]\{7,\}/HASH/g" tmp >expect &&

	shit show --oneline --remerge-diff --diff-filter=U resolution >tmp &&
	sed -e "s/[0-9a-f]\{7,\}/HASH/g" tmp >actual &&
	test_cmp expect actual
'

test_expect_success 'submodule formatting ignores additional headers' '
	# Reuses "expect" from last testcase

	shit show --oneline --remerge-diff --diff-filter=U --submodule=log >tmp &&
	sed -e "s/[0-9a-f]\{7,\}/HASH/g" tmp >actual &&
	test_cmp expect actual
'

test_expect_success 'remerge-diff w/ diff-filter=R: relevant file + conflict header' '
	shit log -1 --oneline resolution >tmp &&
	cat <<-EOF >>tmp &&
	diff --shit a/file_or_directory~HASH (side1) b/wanted_content
	similarity index 100%
	rename from file_or_directory~HASH (side1)
	rename to wanted_content
	remerge CONFLICT (file/directory): directory in the way of file_or_directory from HASH (side1); moving it to file_or_directory~HASH (side1) instead.
	EOF
	# We still have some sha1 hashes above; rip them out so test works
	# with sha256
	sed -e "s/[0-9a-f]\{7,\}/HASH/g" tmp >expect &&

	shit show --oneline --remerge-diff --diff-filter=R resolution >tmp &&
	sed -e "s/[0-9a-f]\{7,\}/HASH/g" tmp >actual &&
	test_cmp expect actual
'

test_expect_success 'remerge-diff w/ pathspec: limits to relevant file including conflict header' '
	shit log -1 --oneline resolution >tmp &&
	cat <<-EOF >>tmp &&
	diff --shit a/letters b/letters
	remerge CONFLICT (rename/rename): letters renamed to letters_side1 in HASH (side1) and to letters_side2 in HASH (side2).
	diff --shit a/letters_side2 b/letters_side2
	deleted file mode 100644
	index b236ae5..0000000
	--- a/letters_side2
	+++ /dev/null
	@@ -1,9 +0,0 @@
	-a
	-b
	-c
	-d
	-e
	-f
	-g
	-h
	-i
	EOF
	# We still have some sha1 hashes above; rip them out so test works
	# with sha256
	sed -e "s/[0-9a-f]\{7,\}/HASH/g" tmp >expect &&

	shit show --oneline --remerge-diff resolution -- "letters*" >tmp &&
	sed -e "s/[0-9a-f]\{7,\}/HASH/g" tmp >actual &&
	test_cmp expect actual
'

test_expect_success 'setup non-content conflicts' '
	shit switch --orphan newbase &&

	test_write_lines 1 2 3 4 5 6 7 8 9 >numbers &&
	shit add numbers &&
	shit commit -m base &&

	shit branch newside1 &&
	shit branch newside2 &&

	shit checkout newside1 &&
	test_write_lines 1 2 three 4 5 6 7 8 9 >numbers &&
	shit add numbers &&
	shit commit -m side1 &&

	shit checkout newside2 &&
	test_write_lines 1 2 drei 4 5 6 7 8 9 >numbers &&
	shit add numbers &&
	shit commit -m side2 &&

	shit checkout -b newresolution newside1 &&
	test_must_fail shit merge newside2 &&
	shit checkout --theirs numbers &&
	shit add -u numbers &&
	shit commit -m resolved
'

test_expect_success 'remerge-diff turns off history simplification' '
	shit log -1 --oneline newresolution >tmp &&
	cat <<-EOF >>tmp &&
	diff --shit a/numbers b/numbers
	remerge CONFLICT (content): Merge conflict in numbers
	index 070e9e7..5335e78 100644
	--- a/numbers
	+++ b/numbers
	@@ -1,10 +1,6 @@
	 1
	 2
	-<<<<<<< 96f1e45 (side1)
	-three
	-=======
	 drei
	->>>>>>> 4fd522f (side2)
	 4
	 5
	 6
	EOF
	# We still have some sha1 hashes above; rip them out so test works
	# with sha256
	sed -e "s/[0-9a-f]\{7,\}/HASH/g" tmp >expect &&

	shit show --oneline --remerge-diff newresolution -- numbers >tmp &&
	sed -e "s/[0-9a-f]\{7,\}/HASH/g" tmp >actual &&
	test_cmp expect actual
'

test_done
