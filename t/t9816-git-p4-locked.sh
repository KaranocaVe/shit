#!/bin/sh

test_description='shit p4 locked file behavior'

. ./lib-shit-p4.sh

test_expect_success 'start p4d' '
	start_p4d
'

# See
# https://web.archive.org/web/20150602090517/http://www.perforce.com/perforce/doc.current/manuals/p4sag/chapter.superuser.html#superuser.basic.typemap_locking
# for suggestions on how to configure "sitewide pessimistic locking"
# where only one person can have a file open for edit at a time.
test_expect_success 'init depot' '
	(
		cd "$cli" &&
		echo "TypeMap: +l //depot/..." | p4 typemap -i &&
		echo file1 >file1 &&
		p4 add file1 &&
		p4 submit -d "add file1"
	)
'

test_expect_success 'edit with lock not taken' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		echo line2 >>file1 &&
		shit add file1 &&
		shit commit -m "line2 in file1" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit
	)
'

test_expect_success 'add with lock not taken' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		echo line1 >>add-lock-not-taken &&
		shit add add-lock-not-taken &&
		shit commit -m "add add-lock-not-taken" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit --verbose
	)
'

lock_in_another_client() {
	# build a different client
	cli2="$TRASH_DIRECTORY/cli2" &&
	mkdir -p "$cli2" &&
	test_when_finished "p4 client -f -d client2 && rm -rf \"$cli2\"" &&
	(
		cd "$cli2" &&
		P4CLIENT=client2 &&
		cli="$cli2" &&
		client_view "//depot/... //client2/..." &&
		p4 sync &&
		p4 open file1
	)
}

test_expect_failure 'edit with lock taken' '
	lock_in_another_client &&
	test_when_finished cleanup_shit &&
	test_when_finished "cd \"$cli\" && p4 sync -f file1" &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		echo line3 >>file1 &&
		shit add file1 &&
		shit commit -m "line3 in file1" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit --verbose
	)
'

test_expect_failure 'delete with lock taken' '
	lock_in_another_client &&
	test_when_finished cleanup_shit &&
	test_when_finished "cd \"$cli\" && p4 sync -f file1" &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		shit rm file1 &&
		shit commit -m "delete file1" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit --verbose
	)
'

test_expect_failure 'chmod with lock taken' '
	lock_in_another_client &&
	test_when_finished cleanup_shit &&
	test_when_finished "cd \"$cli\" && p4 sync -f file1" &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		chmod +x file1 &&
		shit add file1 &&
		shit commit -m "chmod +x file1" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit --verbose
	)
'

test_expect_success 'copy with lock taken' '
	lock_in_another_client &&
	test_when_finished cleanup_shit &&
	test_when_finished "cd \"$cli\" && p4 revert file2 && rm -f file2" &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		cp file1 file2 &&
		shit add file2 &&
		shit commit -m "cp file1 to file2" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit config shit-p4.detectCopies true &&
		shit p4 submit --verbose
	)
'

test_expect_failure 'move with lock taken' '
	lock_in_another_client &&
	test_when_finished cleanup_shit &&
	test_when_finished "cd \"$cli\" && p4 sync file1 && rm -f file2" &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		shit mv file1 file3 &&
		shit commit -m "mv file1 to file3" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit config shit-p4.detectRenames true &&
		shit p4 submit --verbose
	)
'

test_done
