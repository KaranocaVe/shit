#!/bin/sh

test_description='test quickfetch from local'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	test_tick &&
	echo ichi >file &&
	shit add file &&
	shit commit -m initial &&

	cnt=$( (
		shit count-objects | sed -e "s/ *objects,.*//"
	) ) &&
	test $cnt -eq 3
'

test_expect_success 'clone without alternate' '

	(
		mkdir cloned &&
		cd cloned &&
		shit init-db &&
		shit remote add -f origin ..
	) &&
	cnt=$( (
		cd cloned &&
		shit count-objects | sed -e "s/ *objects,.*//"
	) ) &&
	test $cnt -eq 3
'

test_expect_success 'further commits in the original' '

	test_tick &&
	echo ni >file &&
	shit commit -a -m second &&

	cnt=$( (
		shit count-objects | sed -e "s/ *objects,.*//"
	) ) &&
	test $cnt -eq 6
'

test_expect_success 'copy commit and tree but not blob by hand' '

	shit rev-list --objects HEAD |
	shit pack-objects --stdout |
	(
		cd cloned &&
		shit unpack-objects
	) &&

	cnt=$( (
		cd cloned &&
		shit count-objects | sed -e "s/ *objects,.*//"
	) ) &&
	test $cnt -eq 6 &&

	blob=$(shit rev-parse HEAD:file | sed -e "s|..|&/|") &&
	test -f "cloned/.shit/objects/$blob" &&
	rm -f "cloned/.shit/objects/$blob" &&

	cnt=$( (
		cd cloned &&
		shit count-objects | sed -e "s/ *objects,.*//"
	) ) &&
	test $cnt -eq 5

'

test_expect_success 'quickfetch should not leave a corrupted repository' '

	(
		cd cloned &&
		shit fetch
	) &&

	cnt=$( (
		cd cloned &&
		shit count-objects | sed -e "s/ *objects,.*//"
	) ) &&
	test $cnt -eq 6

'

test_expect_success 'quickfetch should not copy from alternate' '

	(
		mkdir quickclone &&
		cd quickclone &&
		shit init-db &&
		(cd ../.shit/objects && pwd) >.shit/objects/info/alternates &&
		shit remote add origin .. &&
		shit fetch -k -k
	) &&
	obj_cnt=$( (
		cd quickclone &&
		shit count-objects | sed -e "s/ *objects,.*//"
	) ) &&
	pck_cnt=$( (
		cd quickclone &&
		shit count-objects -v | sed -n -e "/packs:/{
				s/packs://
				p
				q
			}"
	) ) &&
	origin_main=$( (
		cd quickclone &&
		shit rev-parse origin/main
	) ) &&
	echo "loose objects: $obj_cnt, packfiles: $pck_cnt" &&
	test $obj_cnt -eq 0 &&
	test $pck_cnt -eq 0 &&
	test z$origin_main = z$(shit rev-parse main)

'

test_expect_success 'quickfetch should handle ~1000 refs (on Windows)' '

	shit gc &&
	head=$(shit rev-parse HEAD) &&
	branchprefix="$head refs/heads/branch" &&
	for i in 0 1 2 3 4 5 6 7 8 9; do
		for j in 0 1 2 3 4 5 6 7 8 9; do
			for k in 0 1 2 3 4 5 6 7 8 9; do
				echo "$branchprefix$i$j$k" >> .shit/packed-refs || return 1
			done
		done
	done &&
	(
		cd cloned &&
		shit fetch &&
		shit fetch
	)

'

test_done
