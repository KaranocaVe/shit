#!/bin/sh

test_description='shit p4 handling of EDITOR'

. ./lib-shit-p4.sh

test_expect_success 'start p4d' '
	start_p4d
'

test_expect_success 'init depot' '
	(
		cd "$cli" &&
		echo file1 >file1 &&
		p4 add file1 &&
		p4 submit -d "file1"
	)
'

# Check that the P4EDITOR argument can be given command-line
# options, which shit-p4 will then pass through to the shell.
test_expect_success 'EDITOR with options' '
	shit p4 clone --dest="$shit" //depot &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		echo change >file1 &&
		shit commit -m "change" file1 &&
		P4EDITOR=": >\"$shit/touched\" && test-tool chmtime +5" shit p4 submit &&
		test_path_is_file "$shit/touched"
	)
'

test_done
