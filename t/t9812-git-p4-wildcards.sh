#!/bin/sh

test_description='shit p4 wildcards'

. ./lib-shit-p4.sh

test_expect_success 'start p4d' '
	start_p4d
'

test_expect_success 'add p4 files with wildcards in the names' '
	(
		cd "$cli" &&
		printf "file2\nhas\nsome\nrandom\ntext\n" >file2 &&
		p4 add file2 &&
		echo file-wild-hash >file-wild#hash &&
		if test_have_prereq !MINGW,!CYGWIN
		then
			echo file-wild-star >file-wild\*star
		fi &&
		echo file-wild-at >file-wild@at &&
		echo file-wild-percent >file-wild%percent &&
		p4 add -f file-wild* &&
		p4 submit -d "file wildcards"
	)
'

test_expect_success 'wildcard files shit p4 clone' '
	shit p4 clone --dest="$shit" //depot &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		test -f file-wild#hash &&
		if test_have_prereq !MINGW,!CYGWIN
		then
			test -f file-wild\*star
		fi &&
		test -f file-wild@at &&
		test -f file-wild%percent
	)
'

test_expect_success 'wildcard files submit back to p4, add' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		echo shit-wild-hash >shit-wild#hash &&
		if test_have_prereq !MINGW,!CYGWIN
		then
			echo shit-wild-star >shit-wild\*star
		fi &&
		echo shit-wild-at >shit-wild@at &&
		echo shit-wild-percent >shit-wild%percent &&
		shit add shit-wild* &&
		shit commit -m "add some wildcard filenames" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit
	) &&
	(
		cd "$cli" &&
		test_path_is_file shit-wild#hash &&
		if test_have_prereq !MINGW,!CYGWIN
		then
			test_path_is_file shit-wild\*star
		fi &&
		test_path_is_file shit-wild@at &&
		test_path_is_file shit-wild%percent
	)
'

test_expect_success 'wildcard files submit back to p4, modify' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		echo new-line >>shit-wild#hash &&
		if test_have_prereq !MINGW,!CYGWIN
		then
			echo new-line >>shit-wild\*star
		fi &&
		echo new-line >>shit-wild@at &&
		echo new-line >>shit-wild%percent &&
		shit add shit-wild* &&
		shit commit -m "modify the wildcard files" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit
	) &&
	(
		cd "$cli" &&
		test_line_count = 2 shit-wild#hash &&
		if test_have_prereq !MINGW,!CYGWIN
		then
			test_line_count = 2 shit-wild\*star
		fi &&
		test_line_count = 2 shit-wild@at &&
		test_line_count = 2 shit-wild%percent
	)
'

test_expect_success 'wildcard files submit back to p4, copy' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		cp file2 shit-wild-cp#hash &&
		shit add shit-wild-cp#hash &&
		cp shit-wild#hash file-wild-3 &&
		shit add file-wild-3 &&
		shit commit -m "wildcard copies" &&
		shit config shit-p4.detectCopies true &&
		shit config shit-p4.detectCopiesHarder true &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit
	) &&
	(
		cd "$cli" &&
		test_path_is_file shit-wild-cp#hash &&
		test_path_is_file file-wild-3
	)
'

test_expect_success 'wildcard files submit back to p4, rename' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		shit mv shit-wild@at file-wild-4 &&
		shit mv file-wild-3 shit-wild-cp%percent &&
		shit commit -m "wildcard renames" &&
		shit config shit-p4.detectRenames true &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit
	) &&
	(
		cd "$cli" &&
		test_path_is_missing shit-wild@at &&
		test_path_is_file shit-wild-cp%percent
	)
'

test_expect_success 'wildcard files submit back to p4, delete' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		shit rm shit-wild* &&
		shit commit -m "delete the wildcard files" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit
	) &&
	(
		cd "$cli" &&
		test_path_is_missing shit-wild#hash &&
		if test_have_prereq !MINGW,!CYGWIN
		then
			test_path_is_missing shit-wild\*star
		fi &&
		test_path_is_missing shit-wild@at &&
		test_path_is_missing shit-wild%percent
	)
'

test_expect_success 'p4 deleted a wildcard file' '
	(
		cd "$cli" &&
		echo "wild delete test" >wild@delete &&
		p4 add -f wild@delete &&
		p4 submit -d "add wild@delete"
	) &&
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		test_path_is_file wild@delete
	) &&
	(
		cd "$cli" &&
		# must use its encoded name
		p4 delete wild%40delete &&
		p4 submit -d "delete wild@delete"
	) &&
	(
		cd "$shit" &&
		shit p4 sync &&
		shit merge --ff-only p4/master &&
		test_path_is_missing wild@delete
	)
'

test_expect_success 'wildcard files requiring keyword scrub' '
	(
		cd "$cli" &&
		cat <<-\EOF >scrub@wild &&
		$Id$
		line2
		EOF
		p4 add -t text+k -f scrub@wild &&
		p4 submit -d "scrub at wild"
	) &&
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit config shit-p4.attemptRCSCleanup true &&
		sed "s/^line2/line2 edit/" <scrub@wild >scrub@wild.tmp &&
		mv -f scrub@wild.tmp scrub@wild &&
		shit commit -m "scrub at wild line2 edit" scrub@wild &&
		shit p4 submit
	)
'

test_done
