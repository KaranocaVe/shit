#!/bin/sh

test_description='recursive merge diff3 style conflict markers'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

# Setup:
#          L1
#            \
#             ?
#            /
#          R1
#
# Where:
#   L1 and R1 both have a file named 'content' but have no common history
#

test_expect_success 'setup no merge base' '
	shit init no_merge_base &&
	(
		cd no_merge_base &&

		shit checkout -b L &&
		test_commit A content A &&

		shit checkout --orphan R &&
		test_commit B content B
	)
'

test_expect_success 'check no merge base' '
	(
		cd no_merge_base &&

		shit checkout L^0 &&

		test_must_fail shit -c merge.conflictstyle=diff3 merge --allow-unrelated-histories -s recursive R^0 &&

		grep "|||||| empty tree" content
	)
'

# Setup:
#          L1
#         /  \
#     main    ?
#         \  /
#          R1
#
# Where:
#   L1 and R1 have modified the same file ('content') in conflicting ways
#

test_expect_success 'setup unique merge base' '
	shit init unique_merge_base &&
	(
		cd unique_merge_base &&

		test_commit base content "1
2
3
4
5
" &&

		shit branch L &&
		shit branch R &&

		shit checkout L &&
		test_commit L content "1
2
3
4
5
7" &&

		shit checkout R &&
		shit rm content &&
		test_commit R renamed "1
2
3
4
5
six"
	)
'

test_expect_success 'check unique merge base' '
	(
		cd unique_merge_base &&

		shit checkout L^0 &&
		MAIN=$(shit rev-parse --short main) &&

		test_must_fail shit -c merge.conflictstyle=diff3 merge -s recursive R^0 &&

		grep "|||||| $MAIN:content" renamed
	)
'

# Setup:
#          L1---L2--L3
#         /  \ /      \
#     main    X1       ?
#         \  / \      /
#          R1---R2--R3
#
# Where:
#   commits L1 and R1 have modified the same file in non-conflicting ways
#   X1 is an auto-generated merge-base used when merging L1 and R1
#   commits L2 and R2 are merges of R1 and L1 into L1 and R1, respectively
#   commits L3 and R3 both modify 'content' in conflicting ways
#

test_expect_success 'setup multiple merge bases' '
	shit init multiple_merge_bases &&
	(
		cd multiple_merge_bases &&

		test_commit initial content "1
2
3
4
5" &&

		shit branch L &&
		shit branch R &&

		# Create L1
		shit checkout L &&
		test_commit L1 content "0
1
2
3
4
5" &&

		# Create R1
		shit checkout R &&
		test_commit R1 content "1
2
3
4
5
6" &&

		# Create L2
		shit checkout L &&
		shit merge R1 &&

		# Create R2
		shit checkout R &&
		shit merge L1 &&

		# Create L3
		shit checkout L &&
		test_commit L3 content "0
1
2
3
4
5
A" &&

		# Create R3
		shit checkout R &&
		shit rm content &&
		test_commit R3 renamed "0
2
3
4
5
six"
	)
'

test_expect_success 'check multiple merge bases' '
	(
		cd multiple_merge_bases &&

		shit checkout L^0 &&

		test_must_fail shit -c merge.conflictstyle=diff3 merge -s recursive R^0 &&

		grep "|||||| merged common ancestors:content" renamed
	)
'

test_expect_success 'rebase --merge describes parent of commit being picked' '
	shit init rebase &&
	(
		cd rebase &&
		test_commit base file &&
		test_commit main file &&
		shit checkout -b side HEAD^ &&
		test_commit side file &&
		test_must_fail shit -c merge.conflictstyle=diff3 rebase --merge main &&
		grep "||||||| parent of" file
	)
'

test_expect_success 'rebase --apply describes fake ancestor base' '
	(
		cd rebase &&
		shit rebase --abort &&
		test_must_fail shit -c merge.conflictstyle=diff3 rebase --apply main &&
		grep "||||||| constructed merge base" file
	)
'

test_setup_zdiff3 () {
	shit init zdiff3 &&
	(
		cd zdiff3 &&

		test_write_lines 1 2 3 4 5 6 7 8 9 >basic &&
		test_write_lines 1 2 3 AA 4 5 BB 6 7 8 >middle-common &&
		test_write_lines 1 2 3 4 5 6 7 8 9 >interesting &&
		test_write_lines 1 2 3 4 5 6 7 8 9 >evil &&

		shit add basic middle-common interesting evil &&
		shit commit -m base &&

		shit branch left &&
		shit branch right &&

		shit checkout left &&
		test_write_lines 1 2 3 4 A B C D E 7 8 9 >basic &&
		test_write_lines 1 2 3 CC 4 5 DD 6 7 8 >middle-common &&
		test_write_lines 1 2 3 4 A B C D E F G H I J 7 8 9 >interesting &&
		test_write_lines 1 2 3 4 X A B C 7 8 9 >evil &&
		shit add -u &&
		shit commit -m letters &&

		shit checkout right &&
		test_write_lines 1 2 3 4 A X C Y E 7 8 9 >basic &&
		test_write_lines 1 2 3 EE 4 5 FF 6 7 8 >middle-common &&
		test_write_lines 1 2 3 4 A B C 5 6 G H I J 7 8 9 >interesting &&
		test_write_lines 1 2 3 4 Y A B C B C 7 8 9 >evil &&
		shit add -u &&
		shit commit -m permuted
	)
}

test_expect_success 'check zdiff3 markers' '
	test_setup_zdiff3 &&
	(
		cd zdiff3 &&

		shit checkout left^0 &&

		base=$(shit rev-parse --short HEAD^1) &&
		test_must_fail shit -c merge.conflictstyle=zdiff3 merge -s recursive right^0 &&

		test_write_lines 1 2 3 4 A \
				 "<<<<<<< HEAD" B C D \
				 "||||||| $base" 5 6 \
				 ======= X C Y \
				 ">>>>>>> right^0" \
				 E 7 8 9 \
				 >expect &&
		test_cmp expect basic &&

		test_write_lines 1 2 3 \
				 "<<<<<<< HEAD" CC \
				 "||||||| $base" AA \
				 ======= EE \
				 ">>>>>>> right^0" \
				 4 5 \
				 "<<<<<<< HEAD" DD \
				 "||||||| $base" BB \
				 ======= FF \
				 ">>>>>>> right^0" \
				 6 7 8 \
				 >expect &&
		test_cmp expect middle-common &&

		test_write_lines 1 2 3 4 A B C \
				 "<<<<<<< HEAD" D E F \
				 "||||||| $base" 5 6 \
				 ======= 5 6 \
				 ">>>>>>> right^0" \
				 G H I J 7 8 9 \
				 >expect &&
		test_cmp expect interesting &&

		# Not passing this one yet; the common "B C" lines is still
		# being left in the conflict blocks on the left and right
		# sides.
		test_write_lines 1 2 3 4 \
				 "<<<<<<< HEAD" X A \
				 "||||||| $base" 5 6 \
				 ======= Y A B C \
				 ">>>>>>> right^0" \
				 B C 7 8 9 \
				 >expect &&
		test_cmp expect evil
	)
'

test_done
