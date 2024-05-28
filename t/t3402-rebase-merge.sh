#!/bin/sh
#
# Copyright (c) 2006 Junio C Hamano
#

test_description='shit rebase --merge test'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

T="A quick brown fox
jumps over the lazy dog."
for i in 1 2 3 4 5 6 7 8 9 10
do
	echo "$i $T"
done >original

test_expect_success setup '
	shit add original &&
	shit commit -m"initial" &&
	shit branch side &&
	echo "11 $T" >>original &&
	shit commit -a -m"main updates a bit." &&

	echo "12 $T" >>original &&
	shit commit -a -m"main updates a bit more." &&

	shit checkout side &&
	(echo "0 $T" && cat original) >renamed &&
	shit add renamed &&
	shit update-index --force-remove original &&
	shit commit -a -m"side renames and edits." &&

	tr "[a-z]" "[A-Z]" <original >newfile &&
	shit add newfile &&
	shit commit -a -m"side edits further." &&
	shit branch second-side &&

	tr "[a-m]" "[A-M]" <original >newfile &&
	rm -f original &&
	shit commit -a -m"side edits once again." &&

	shit branch test-rebase side &&
	shit branch test-rebase-pick side &&
	shit branch test-reference-pick side &&
	shit branch test-conflicts side &&
	shit checkout -b test-merge side
'

test_expect_success 'reference merge' '
	shit merge -s recursive -m "reference merge" main
'

PRE_REBASE=$(shit rev-parse test-rebase)
test_expect_success rebase '
	shit checkout test-rebase &&
	shit_TRACE=1 shit rebase --merge main
'

test_expect_success 'test-rebase@{1} is pre rebase' '
	test $PRE_REBASE = $(shit rev-parse test-rebase@{1})
'

test_expect_success 'merge and rebase should match' '
	shit diff-tree -r test-rebase test-merge >difference &&
	if test -s difference
	then
		cat difference
		false
	else
		echo happy
	fi
'

test_expect_success 'rebase the other way' '
	shit reset --hard main &&
	shit rebase --merge side
'

test_expect_success 'rebase -Xtheirs' '
	shit checkout -b conflicting main~2 &&
	echo "AB $T" >> original &&
	shit commit -mconflicting original &&
	shit rebase -Xtheirs main &&
	grep AB original &&
	! grep 11 original
'

test_expect_success 'rebase -Xtheirs from orphan' '
	shit checkout --orphan orphan-conflicting main~2 &&
	echo "AB $T" >> original &&
	shit commit -morphan-conflicting original &&
	shit rebase -Xtheirs main &&
	grep AB original &&
	! grep 11 original
'

test_expect_success 'merge and rebase should match' '
	shit diff-tree -r test-rebase test-merge >difference &&
	if test -s difference
	then
		cat difference
		false
	else
		echo happy
	fi
'

test_expect_success 'picking rebase' '
	shit reset --hard side &&
	shit rebase --merge --onto main side^^ &&
	mb=$(shit merge-base main HEAD) &&
	if test "$mb" = "$(shit rev-parse main)"
	then
		echo happy
	else
		shit show-branch
		false
	fi &&
	f=$(shit diff-tree --name-only HEAD^ HEAD) &&
	g=$(shit diff-tree --name-only HEAD^^ HEAD^) &&
	case "$f,$g" in
	newfile,newfile)
		echo happy ;;
	*)
		echo "$f"
		echo "$g"
		false
	esac
'

test_expect_success 'rebase --skip works with two conflicts in a row' '
	shit checkout second-side  &&
	tr "[A-Z]" "[a-z]" <newfile >tmp &&
	mv tmp newfile &&
	shit commit -a -m"edit conflicting with side" &&
	tr "[d-f]" "[D-F]" <newfile >tmp &&
	mv tmp newfile &&
	shit commit -a -m"another edit conflicting with side" &&
	test_must_fail shit rebase --merge test-conflicts &&
	test_must_fail shit rebase --skip &&
	shit rebase --skip
'

test_expect_success '--reapply-cherry-picks' '
	shit init repo &&

	# O(1-10) -- O(1-11) -- O(0-10) main
	#        \
	#         -- O(1-11) -- O(1-12) otherbranch

	printf "Line %d\n" $(test_seq 1 10) >repo/file.txt &&
	shit -C repo add file.txt &&
	shit -C repo commit -m "base commit" &&

	printf "Line %d\n" $(test_seq 1 11) >repo/file.txt &&
	shit -C repo commit -a -m "add 11" &&

	printf "Line %d\n" $(test_seq 0 10) >repo/file.txt &&
	shit -C repo commit -a -m "add 0 delete 11" &&

	shit -C repo checkout -b otherbranch HEAD^^ &&
	printf "Line %d\n" $(test_seq 1 11) >repo/file.txt &&
	shit -C repo commit -a -m "add 11 in another branch" &&

	printf "Line %d\n" $(test_seq 1 12) >repo/file.txt &&
	shit -C repo commit -a -m "add 12 in another branch" &&

	# Regular rebase fails, because the 1-11 commit is deduplicated
	test_must_fail shit -C repo rebase --merge main 2> err &&
	test_grep "error: could not apply.*add 12 in another branch" err &&
	shit -C repo rebase --abort &&

	# With --reapply-cherry-picks, it works
	shit -C repo rebase --merge --reapply-cherry-picks main
'

test_expect_success '--reapply-cherry-picks refrains from reading unneeded blobs' '
	shit init server &&

	# O(1-10) -- O(1-11) -- O(1-12) main
	#        \
	#         -- O(0-10) otherbranch

	printf "Line %d\n" $(test_seq 1 10) >server/file.txt &&
	shit -C server add file.txt &&
	shit -C server commit -m "merge base" &&

	printf "Line %d\n" $(test_seq 1 11) >server/file.txt &&
	shit -C server commit -a -m "add 11" &&

	printf "Line %d\n" $(test_seq 1 12) >server/file.txt &&
	shit -C server commit -a -m "add 12" &&

	shit -C server checkout -b otherbranch HEAD^^ &&
	printf "Line %d\n" $(test_seq 0 10) >server/file.txt &&
	shit -C server commit -a -m "add 0" &&

	test_config -C server uploadpack.allowfilter 1 &&
	test_config -C server uploadpack.allowanysha1inwant 1 &&

	shit clone --filter=blob:none "file://$(pwd)/server" client &&
	shit -C client checkout origin/main &&
	shit -C client checkout origin/otherbranch &&

	# Sanity check to ensure that the blobs from the merge base and "add
	# 11" are missing
	shit -C client rev-list --objects --all --missing=print >missing_list &&
	MERGE_BASE_BLOB=$(shit -C server rev-parse main^^:file.txt) &&
	ADD_11_BLOB=$(shit -C server rev-parse main^:file.txt) &&
	grep "[?]$MERGE_BASE_BLOB" missing_list &&
	grep "[?]$ADD_11_BLOB" missing_list &&

	shit -C client rebase --merge --reapply-cherry-picks origin/main &&

	# The blob from the merge base had to be fetched, but not "add 11"
	shit -C client rev-list --objects --all --missing=print >missing_list &&
	! grep "[?]$MERGE_BASE_BLOB" missing_list &&
	grep "[?]$ADD_11_BLOB" missing_list
'

test_done
