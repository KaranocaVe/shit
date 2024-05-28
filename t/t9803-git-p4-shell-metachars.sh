#!/bin/sh

test_description='shit p4 transparency to shell metachars in filenames'

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

test_expect_success 'shell metachars in filenames' '
	shit p4 clone --dest="$shit" //depot &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit config shit-p4.skipSubmitEditCheck true &&
		echo f1 >foo\$bar &&
		shit add foo\$bar &&
		echo f2 >"file with spaces" &&
		shit add "file with spaces" &&
		shit commit -m "add files" &&
		P4EDITOR="test-tool chmtime +5" shit p4 submit
	) &&
	(
		cd "$cli" &&
		p4 sync ... &&
		test -e "file with spaces" &&
		test -e "foo\$bar"
	)
'

test_expect_success 'deleting with shell metachars' '
	shit p4 clone --dest="$shit" //depot &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit config shit-p4.skipSubmitEditCheck true &&
		shit rm foo\$bar &&
		shit rm file\ with\ spaces &&
		shit commit -m "remove files" &&
		P4EDITOR="test-tool chmtime +5" shit p4 submit
	) &&
	(
		cd "$cli" &&
		p4 sync ... &&
		test ! -e "file with spaces" &&
		test ! -e foo\$bar
	)
'

# Create a branch with a shell metachar in its name
#
# 1. //depot/main
# 2. //depot/branch$3

test_expect_success 'branch with shell char' '
	test_when_finished cleanup_shit &&
	test_create_repo "$shit" &&
	(
		cd "$cli" &&

		mkdir -p main &&

		echo f1 >main/f1 &&
		p4 add main/f1 &&
		p4 submit -d "main/f1" &&

		p4 integrate //depot/main/... //depot/branch\$3/... &&
		p4 submit -d "integrate main to branch\$3" &&

		echo f1 >branch\$3/shell_char_branch_file &&
		p4 add branch\$3/shell_char_branch_file &&
		p4 submit -d "branch\$3/shell_char_branch_file" &&

		p4 branch -i <<-EOF &&
		Branch: branch\$3
		View: //depot/main/... //depot/branch\$3/...
		EOF

		p4 edit main/f1 &&
		echo "a change" >> main/f1 &&
		p4 submit -d "a change" main/f1 &&

		p4 integrate -b branch\$3 &&
		p4 resolve -am branch\$3/... &&
		p4 submit -d "integrate main to branch\$3" &&

		cd "$shit" &&

		shit config shit-p4.branchList main:branch\$3 &&
		shit p4 clone --dest=. --detect-branches //depot@all &&
		shit log --all --graph --decorate --stat &&
		shit reset --hard p4/depot/branch\$3 &&
		test -f shell_char_branch_file &&
		test -f f1
	)
'

test_done
