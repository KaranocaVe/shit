#!/bin/sh

test_description='shit p4 submit'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./lib-shit-p4.sh

test_expect_success 'start p4d' '
	start_p4d
'

test_expect_success 'init depot' '
	(
		cd "$cli" &&
		echo file1 >file1 &&
		p4 add file1 &&
		p4 submit -d "change 1"
	)
'

test_expect_success 'is_cli_file_writeable function' '
	(
		cd "$cli" &&
		echo a >a &&
		is_cli_file_writeable a &&
		! is_cli_file_writeable file1 &&
		rm a
	)
'

test_expect_success 'submit with no client dir' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		echo file2 >file2 &&
		shit add file2 &&
		shit commit -m "shit commit 2" &&
		rm -rf "$cli" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit
	) &&
	(
		cd "$cli" &&
		test_path_is_file file1 &&
		test_path_is_file file2
	)
'

# make two commits, but tell it to apply only from HEAD^
test_expect_success 'submit --origin' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		test_commit "file3" &&
		test_commit "file4" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit --origin=HEAD^
	) &&
	(
		cd "$cli" &&
		test_path_is_missing "file3.t" &&
		test_path_is_file "file4.t"
	)
'

test_expect_success 'submit --dry-run' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		test_commit "dry-run1" &&
		test_commit "dry-run2" &&
		shit p4 submit --dry-run >out &&
		test_grep "Would apply" out
	) &&
	(
		cd "$cli" &&
		test_path_is_missing "dry-run1.t" &&
		test_path_is_missing "dry-run2.t"
	)
'

test_expect_success 'submit --dry-run --export-labels' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		echo dry-run1 >dry-run1 &&
		shit add dry-run1 &&
		shit commit -m "dry-run1" dry-run1 &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit &&
		echo dry-run2 >dry-run2 &&
		shit add dry-run2 &&
		shit commit -m "dry-run2" dry-run2 &&
		shit tag -m "dry-run-tag1" dry-run-tag1 HEAD^ &&
		shit p4 submit --dry-run --export-labels >out &&
		test_grep "Would create p4 label" out
	) &&
	(
		cd "$cli" &&
		test_path_is_file "dry-run1" &&
		test_path_is_missing "dry-run2"
	)
'

test_expect_success 'submit with allowSubmit' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		test_commit "file5" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit config shit-p4.allowSubmit "nobranch" &&
		test_must_fail shit p4 submit &&
		shit config shit-p4.allowSubmit "nobranch,main" &&
		shit p4 submit
	)
'

test_expect_success 'submit with master branch name from argv' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		test_commit "file6" &&
		shit config shit-p4.skipSubmitEdit true &&
		test_must_fail shit p4 submit nobranch &&
		shit branch otherbranch &&
		shit reset --hard HEAD^ &&
		test_commit "file7" &&
		shit p4 submit otherbranch
	) &&
	(
		cd "$cli" &&
		test_path_is_file "file6.t" &&
		test_path_is_missing "file7.t"
	)
'

test_expect_success 'allow submit from branch with same revision but different name' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		test_commit "file8" &&
		shit checkout -b branch1 &&
		shit checkout -b branch2 &&
		shit config shit-p4.skipSubmitEdit true &&
		shit config shit-p4.allowSubmit "branch1" &&
		test_must_fail shit p4 submit &&
		shit checkout branch1 &&
		shit p4 submit
	)
'

# make two commits, but tell it to apply only one

test_expect_success 'submit --commit one' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		test_commit "file9" &&
		test_commit "file10" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit --commit HEAD
	) &&
	(
		cd "$cli" &&
		test_path_is_missing "file9.t" &&
		test_path_is_file "file10.t"
	)
'

# make three commits, but tell it to apply only range

test_expect_success 'submit --commit range' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		test_commit "file11" &&
		test_commit "file12" &&
		test_commit "file13" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit --commit HEAD~2..HEAD
	) &&
	(
		cd "$cli" &&
		test_path_is_missing "file11.t" &&
		test_path_is_file "file12.t" &&
		test_path_is_file "file13.t"
	)
'

#
# Basic submit tests, the five handled cases
#

test_expect_success 'submit modify' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		shit config shit-p4.skipSubmitEdit true &&
		echo line >>file1 &&
		shit add file1 &&
		shit commit -m file1 &&
		shit p4 submit
	) &&
	(
		cd "$cli" &&
		test_path_is_file file1 &&
		test_line_count = 2 file1
	)
'

test_expect_success 'submit add' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		shit config shit-p4.skipSubmitEdit true &&
		echo file13 >file13 &&
		shit add file13 &&
		shit commit -m file13 &&
		shit p4 submit
	) &&
	(
		cd "$cli" &&
		test_path_is_file file13
	)
'

test_expect_success 'submit delete' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit rm file4.t &&
		shit commit -m "delete file4.t" &&
		shit p4 submit
	) &&
	(
		cd "$cli" &&
		test_path_is_missing file4.t
	)
'

test_expect_success 'submit copy' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit config shit-p4.detectCopies true &&
		shit config shit-p4.detectCopiesHarder true &&
		cp file5.t file5.ta &&
		shit add file5.ta &&
		shit commit -m "copy to file5.ta" &&
		shit p4 submit
	) &&
	(
		cd "$cli" &&
		test_path_is_file file5.ta &&
		! is_cli_file_writeable file5.ta
	)
'

test_expect_success 'submit rename' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit config shit-p4.detectRenames true &&
		shit mv file6.t file6.ta &&
		shit commit -m "rename file6.t to file6.ta" &&
		shit p4 submit
	) &&
	(
		cd "$cli" &&
		test_path_is_missing file6.t &&
		test_path_is_file file6.ta &&
		! is_cli_file_writeable file6.ta
	)
'

#
# Converting shit commit message to p4 change description, including
# parsing out the optional Jobs: line.
#
test_expect_success 'simple one-line description' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		echo desc2 >desc2 &&
		shit add desc2 &&
		cat >msg <<-EOF &&
		One-line description line for desc2.
		EOF
		shit commit -F - <msg &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit &&
		change=$(p4 -G changes -m 1 //depot/... | \
			 marshal_dump change) &&
		# marshal_dump always adds a newline
		p4 -G describe $change | marshal_dump desc | sed \$d >pmsg &&
		test_cmp msg pmsg
	)
'

test_expect_success 'description with odd formatting' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		echo desc3 >desc3 &&
		shit add desc3 &&
		(
			printf "subject line\n\n\tExtra tab\nline.\n\n" &&
			printf "Description:\n\tBogus description marker\n\n" &&
			# shit commit eats trailing newlines; only use one
			printf "Files:\n\tBogus descs marker\n"
		) >msg &&
		shit commit -F - <msg &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit &&
		change=$(p4 -G changes -m 1 //depot/... | \
			 marshal_dump change) &&
		# marshal_dump always adds a newline
		p4 -G describe $change | marshal_dump desc | sed \$d >pmsg &&
		test_cmp msg pmsg
	)
'

make_job() {
	name="$1" &&
	tab="$(printf \\t)" &&
	p4 job -o | \
	sed -e "/^Job:/s/.*/Job: $name/" \
	    -e "/^Description/{ n; s/.*/$tab job text/; }" | \
	p4 job -i
}

test_expect_success 'description with Jobs section at end' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		echo desc4 >desc4 &&
		shit add desc4 &&
		echo 6060842 >jobname &&
		(
			printf "subject line\n\n\tExtra tab\nline.\n\n" &&
			printf "Files:\n\tBogus files marker\n" &&
			printf "Junk: 3164175\n" &&
			printf "Jobs: $(cat jobname)\n"
		) >msg &&
		shit commit -F - <msg &&
		shit config shit-p4.skipSubmitEdit true &&
		# build a job
		make_job $(cat jobname) &&
		shit p4 submit &&
		change=$(p4 -G changes -m 1 //depot/... | \
			 marshal_dump change) &&
		# marshal_dump always adds a newline
		p4 -G describe $change | marshal_dump desc | sed \$d >pmsg &&
		# make sure Jobs line and all following is gone
		sed "/^Jobs:/,\$d" msg >jmsg &&
		test_cmp jmsg pmsg &&
		# make sure p4 knows about job
		p4 -G describe $change | marshal_dump job0 >job0 &&
		test_cmp jobname job0
	)
'

test_expect_success 'description with Jobs and values on separate lines' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		echo desc5 >desc5 &&
		shit add desc5 &&
		echo PROJ-6060842 >jobname1 &&
		echo PROJ-6060847 >jobname2 &&
		(
			printf "subject line\n\n\tExtra tab\nline.\n\n" &&
			printf "Files:\n\tBogus files marker\n" &&
			printf "Junk: 3164175\n" &&
			printf "Jobs:\n" &&
			printf "\t$(cat jobname1)\n" &&
			printf "\t$(cat jobname2)\n"
		) >msg &&
		shit commit -F - <msg &&
		shit config shit-p4.skipSubmitEdit true &&
		# build two jobs
		make_job $(cat jobname1) &&
		make_job $(cat jobname2) &&
		shit p4 submit &&
		change=$(p4 -G changes -m 1 //depot/... | \
			 marshal_dump change) &&
		# marshal_dump always adds a newline
		p4 -G describe $change | marshal_dump desc | sed \$d >pmsg &&
		# make sure Jobs line and all following is gone
		sed "/^Jobs:/,\$d" msg >jmsg &&
		test_cmp jmsg pmsg &&
		# make sure p4 knows about the two jobs
		p4 -G describe $change >change &&
		(
			marshal_dump job0 <change &&
			marshal_dump job1 <change
		) | sort >jobs &&
		sort jobname1 jobname2 >expected &&
		test_cmp expected jobs
	)
'

test_expect_success 'description with Jobs section and bogus following text' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		echo desc6 >desc6 &&
		shit add desc6 &&
		echo 6060843 >jobname &&
		(
			printf "subject line\n\n\tExtra tab\nline.\n\n" &&
			printf "Files:\n\tBogus files marker\n" &&
			printf "Junk: 3164175\n" &&
			printf "Jobs: $(cat jobname)\n" &&
			printf "MoreJunk: 3711\n"
		) >msg &&
		shit commit -F - <msg &&
		shit config shit-p4.skipSubmitEdit true &&
		# build a job
		make_job $(cat jobname) &&
		test_must_fail shit p4 submit 2>err &&
		test_grep "Unknown field name" err
	) &&
	(
		cd "$cli" &&
		p4 revert desc6 &&
		rm -f desc6
	)
'

test_expect_success 'submit --prepare-p4-only' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		echo prep-only-add >prep-only-add &&
		shit add prep-only-add &&
		shit commit -m "prep only add" &&
		shit p4 submit --prepare-p4-only >out &&
		test_grep "prepared for submission" out &&
		test_grep "must be deleted" out &&
		test_grep ! "everything below this line is just the diff" out
	) &&
	(
		cd "$cli" &&
		test_path_is_file prep-only-add &&
		p4 fstat -T action prep-only-add | grep -w add
	)
'

test_expect_success 'submit --shelve' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$cli" &&
		p4 revert ... &&
		cd "$shit" &&
		shit config shit-p4.skipSubmitEdit true &&
		test_commit "shelveme1" &&
		shit p4 submit --origin=HEAD^ &&

		echo 654321 >shelveme2.t &&
		echo 123456 >>shelveme1.t &&
		shit add shelveme* &&
		shit commit -m"shelvetest" &&
		shit p4 submit --shelve --origin=HEAD^ &&

		test_path_is_file shelveme1.t &&
		test_path_is_file shelveme2.t
	) &&
	(
		cd "$cli" &&
		change=$(p4 -G changes -s shelved -m 1 //depot/... | \
			 marshal_dump change) &&
		p4 describe -S $change | grep shelveme2 &&
		p4 describe -S $change | grep 123456 &&
		test_path_is_file shelveme1.t &&
		test_path_is_missing shelveme2.t
	)
'

last_shelve () {
	p4 -G changes -s shelved -m 1 //depot/... | marshal_dump change
}

make_shelved_cl() {
	test_commit "$1" >/dev/null &&
	shit p4 submit --origin HEAD^ --shelve >/dev/null &&
	p4 -G changes -s shelved -m 1 | marshal_dump change
}

# Update existing shelved changelists

test_expect_success 'submit --update-shelve' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$cli" &&
		p4 revert ... &&
		cd "$shit" &&
		shit config shit-p4.skipSubmitEdit true &&
		shelved_cl0=$(make_shelved_cl "shelved-change-0") &&
		echo shelved_cl0=$shelved_cl0 &&
		shelved_cl1=$(make_shelved_cl "shelved-change-1") &&

		echo "updating shelved change lists $shelved_cl0 and $shelved_cl1" &&

		echo "updated-line" >>shelf.t &&
		echo added-file.t >added-file.t &&
		shit add shelf.t added-file.t &&
		shit rm -f shelved-change-1.t &&
		shit commit --amend -C HEAD &&
		shit show --stat HEAD &&
		shit p4 submit -v --origin HEAD~2 --update-shelve $shelved_cl0 --update-shelve $shelved_cl1 &&
		echo "done shit p4 submit"
	) &&
	(
		cd "$cli" &&
		change=$(last_shelve) &&
		p4 unshelve -c $change -s $change &&
		grep -q updated-line shelf.t &&
		p4 describe -S $change | grep added-file.t &&
		test_path_is_missing shelved-change-1.t &&
		p4 revert ...
	)
'

test_expect_success 'update a shelve involving moved and copied files' '
	test_when_finished cleanup_shit &&
	(
		cd "$cli" &&
		: >file_to_move &&
		p4 add file_to_move &&
		p4 submit -d "change1" &&
		p4 edit file_to_move &&
		echo change >>file_to_move &&
		p4 submit -d "change2" &&
		p4 opened
	) &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		shit config shit-p4.detectCopies true &&
		shit config shit-p4.detectRenames true &&
		shit config shit-p4.skipSubmitEdit true &&
		mkdir moved &&
		cp file_to_move copy_of_file &&
		shit add copy_of_file &&
		shit mv file_to_move moved/ &&
		shit commit -m "rename a file" &&
		shit p4 submit -M --shelve --origin HEAD^ &&
		: >new_file &&
		shit add new_file &&
		shit commit --amend &&
		shit show --stat HEAD &&
		change=$(last_shelve) &&
		shit p4 submit -M --update-shelve $change --commit HEAD
	) &&
	(
		cd "$cli" &&
		change=$(last_shelve) &&
		echo change=$change &&
		p4 unshelve -s $change &&
		p4 submit -d "Testing update-shelve" &&
		test_path_is_file copy_of_file &&
		test_path_is_file moved/file_to_move &&
		test_path_is_missing file_to_move &&
		test_path_is_file new_file &&
		echo "unshelved and submitted change $change" &&
		p4 changes moved/file_to_move | grep "Testing update-shelve" &&
		p4 changes copy_of_file | grep "Testing update-shelve"
	)
'

test_done
