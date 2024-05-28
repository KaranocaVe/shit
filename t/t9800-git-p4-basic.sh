#!/bin/sh

test_description='shit p4 tests'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./lib-shit-p4.sh

test_expect_success 'start p4d' '
	start_p4d
'

test_expect_success 'add p4 files' '
	(
		cd "$cli" &&
		echo file1 >file1 &&
		p4 add file1 &&
		p4 submit -d "file1" &&
		echo file2 >file2 &&
		p4 add file2 &&
		p4 submit -d "file2"
	)
'

test_expect_success 'basic shit p4 clone' '
	shit p4 clone --dest="$shit" //depot &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit log --oneline >lines &&
		test_line_count = 1 lines
	)
'

test_expect_success 'depot typo error' '
	test_must_fail shit p4 clone --dest="$shit" /depot 2>errs &&
	grep "Depot paths must start with" errs
'

test_expect_success 'shit p4 clone @all' '
	shit p4 clone --dest="$shit" //depot@all &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit log --oneline >lines &&
		test_line_count = 2 lines
	)
'

test_expect_success 'shit p4 sync uninitialized repo' '
	test_create_repo "$shit" &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		test_must_fail shit p4 sync 2>errs &&
		test_grep "Perhaps you never did" errs
	)
'

#
# Create a shit repo by hand.  Add a commit so that HEAD is valid.
# Test imports a new p4 repository into a new shit branch.
#
test_expect_success 'shit p4 sync new branch' '
	test_create_repo "$shit" &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		test_commit head &&
		shit p4 sync --branch=refs/remotes/p4/depot //depot@all &&
		shit log --oneline p4/depot >lines &&
		test_line_count = 2 lines
	)
'

#
# Setup as before, and then explicitly sync imported branch, using a
# different ref format.
#
test_expect_success 'shit p4 sync existing branch without changes' '
	test_create_repo "$shit" &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		test_commit head &&
		shit p4 sync --branch=depot //depot@all &&
		shit p4 sync --branch=refs/remotes/p4/depot >out &&
		test_grep "No changes to import!" out
	)
'

#
# Same as before, relative branch name.
#
test_expect_success 'shit p4 sync existing branch with relative name' '
	test_create_repo "$shit" &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		test_commit head &&
		shit p4 sync --branch=branch1 //depot@all &&
		shit p4 sync --branch=p4/branch1 >out &&
		test_grep "No changes to import!" out
	)
'

#
# Same as before, with a nested branch path, referenced different ways.
#
test_expect_success 'shit p4 sync existing branch with nested path' '
	test_create_repo "$shit" &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		test_commit head &&
		shit p4 sync --branch=p4/some/path //depot@all &&
		shit p4 sync --branch=some/path >out &&
		test_grep "No changes to import!" out
	)
'

#
# Same as before, with a full ref path outside the p4/* namespace.
#
test_expect_success 'shit p4 sync branch explicit ref without p4 in path' '
	test_create_repo "$shit" &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		test_commit head &&
		shit p4 sync --branch=refs/remotes/someremote/depot //depot@all &&
		shit p4 sync --branch=refs/remotes/someremote/depot >out &&
		test_grep "No changes to import!" out
	)
'

test_expect_success 'shit p4 sync nonexistent ref' '
	test_create_repo "$shit" &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		test_commit head &&
		shit p4 sync --branch=depot //depot@all &&
		test_must_fail shit p4 sync --branch=depot2 2>errs &&
		test_grep "Perhaps you never did" errs
	)
'

test_expect_success 'shit p4 sync existing non-p4-imported ref' '
	test_create_repo "$shit" &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		test_commit head &&
		shit p4 sync --branch=depot //depot@all &&
		test_must_fail shit p4 sync --branch=refs/heads/master 2>errs &&
		test_grep "Perhaps you never did" errs
	)
'

test_expect_success 'clone two dirs' '
	(
		cd "$cli" &&
		mkdir sub1 sub2 &&
		echo sub1/f1 >sub1/f1 &&
		echo sub2/f2 >sub2/f2 &&
		p4 add sub1/f1 &&
		p4 submit -d "sub1/f1" &&
		p4 add sub2/f2 &&
		p4 submit -d "sub2/f2"
	) &&
	shit p4 clone --dest="$shit" //depot/sub1 //depot/sub2 &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit ls-files >lines &&
		test_line_count = 2 lines &&
		shit log --oneline p4/master >lines &&
		test_line_count = 1 lines
	)
'

test_expect_success 'clone two dirs, @all' '
	(
		cd "$cli" &&
		echo sub1/f3 >sub1/f3 &&
		p4 add sub1/f3 &&
		p4 submit -d "sub1/f3"
	) &&
	shit p4 clone --dest="$shit" //depot/sub1@all //depot/sub2@all &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit ls-files >lines &&
		test_line_count = 3 lines &&
		shit log --oneline p4/master >lines &&
		test_line_count = 3 lines
	)
'

test_expect_success 'clone two dirs, @all, conflicting files' '
	(
		cd "$cli" &&
		echo sub2/f3 >sub2/f3 &&
		p4 add sub2/f3 &&
		p4 submit -d "sub2/f3"
	) &&
	shit p4 clone --dest="$shit" //depot/sub1@all //depot/sub2@all &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit ls-files >lines &&
		test_line_count = 3 lines &&
		shit log --oneline p4/master >lines &&
		test_line_count = 4 lines &&
		echo sub2/f3 >expected &&
		test_cmp expected f3
	)
'

test_expect_success 'clone two dirs, each edited by submit, single shit commit' '
	(
		cd "$cli" &&
		echo sub1/f4 >sub1/f4 &&
		p4 add sub1/f4 &&
		echo sub2/f4 >sub2/f4 &&
		p4 add sub2/f4 &&
		p4 submit -d "sub1/f4 and sub2/f4"
	) &&
	shit p4 clone --dest="$shit" //depot/sub1@all //depot/sub2@all &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit ls-files >lines &&
		test_line_count = 4 lines &&
		shit log --oneline p4/master >lines &&
		test_line_count = 5 lines
	)
'

revision_ranges="2000/01/01,#head \
		 1,2080/01/01 \
		 2000/01/01,2080/01/01 \
		 2000/01/01,1000 \
		 1,1000"

test_expect_success 'clone using non-numeric revision ranges' '
	test_when_finished cleanup_shit &&
	for r in $revision_ranges
	do
		rm -fr "$shit" &&
		test ! -d "$shit" &&
		shit p4 clone --dest="$shit" //depot@$r &&
		(
			cd "$shit" &&
			shit ls-files >lines &&
			test_line_count = 8 lines
		) || return 1
	done
'

test_expect_success 'clone with date range, excluding some changes' '
	test_when_finished cleanup_shit &&
	before=$(date +%Y/%m/%d:%H:%M:%S) &&
	sleep 2 &&
	(
		cd "$cli" &&
		:>date_range_test &&
		p4 add date_range_test &&
		p4 submit -d "Adding file"
	) &&
	shit p4 clone --dest="$shit" //depot@1,$before &&
	(
		cd "$shit" &&
		test_path_is_missing date_range_test
	)
'

test_expect_success 'exit when p4 fails to produce marshaled output' '
	mkdir badp4dir &&
	test_when_finished "rm badp4dir/p4 && rmdir badp4dir" &&
	cat >badp4dir/p4 <<-EOF &&
	#!$SHELL_PATH
	exit 1
	EOF
	chmod 755 badp4dir/p4 &&
	(
		PATH="$TRASH_DIRECTORY/badp4dir:$PATH" &&
		export PATH &&
		test_expect_code 1 shit p4 clone --dest="$shit" //depot >errs 2>&1
	) &&
	test_grep ! Traceback errs
'

# Hide a file from p4d, make sure we catch its complaint.  This won't fail in
# p4 changes, files, or describe; just in p4 print.  If P4CLIENT is unset, the
# message will include "Librarian checkout".
test_expect_success 'exit gracefully for p4 server errors' '
	test_when_finished "mv \"$db\"/depot/file1,v,hidden \"$db\"/depot/file1,v" &&
	mv "$db"/depot/file1,v "$db"/depot/file1,v,hidden &&
	test_when_finished cleanup_shit &&
	test_expect_code 1 shit p4 clone --dest="$shit" //depot@1 >out 2>err &&
	test_grep "Error from p4 print" err
'

test_expect_success 'clone --bare should make a bare repository' '
	rm -rf "$shit" &&
	shit p4 clone --dest="$shit" --bare //depot &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		test_path_is_missing .shit &&
		shit config --get --bool core.bare true &&
		shit rev-parse --verify refs/remotes/p4/master &&
		shit rev-parse --verify refs/remotes/p4/HEAD &&
		shit rev-parse --verify refs/heads/main &&
		shit rev-parse --verify HEAD
	)
'

# Sleep a bit so that the top-most p4 change did not happen "now".  Then
# import the repo and make sure that the initial import has the same time
# as the top-most change.
test_expect_success 'initial import time from top change time' '
	p4change=$(p4 -G changes -m 1 //depot/... | marshal_dump change) &&
	p4time=$(p4 -G changes -m 1 //depot/... | marshal_dump time) &&
	sleep 3 &&
	shit p4 clone --dest="$shit" //depot &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shittime=$(shit show -s --pretty=format:%at HEAD) &&
		echo $p4time $shittime &&
		test $p4time = $shittime
	)
'

test_expect_success 'unresolvable host in P4PORT should display error' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		P4PORT=nosuchhost:65537 &&
		export P4PORT &&
		test_expect_code 1 shit p4 sync >out 2>err &&
		grep "connect to nosuchhost" err
	)
'

# Test following scenarios:
#   - Without ".shit/hooks/p4-pre-submit" , submit should continue
#   - With the hook returning 0, submit should continue
#   - With the hook returning 1, submit should abort
test_expect_success 'run hook p4-pre-submit before submit' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		echo "hello world" >hello.txt &&
		shit add hello.txt &&
		shit commit -m "add hello.txt" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit --dry-run >out &&
		grep "Would apply" out
	) &&
	test_hook -C "$shit" p4-pre-submit <<-\EOF &&
	exit 0
	EOF
	(
		cd "$shit" &&
		shit p4 submit --dry-run >out &&
		grep "Would apply" out
	) &&
	test_hook -C "$shit" --clobber p4-pre-submit <<-\EOF &&
	exit 1
	EOF
	(
		cd "$shit" &&
		test_must_fail shit p4 submit --dry-run >errs 2>&1 &&
		! grep "Would apply" errs
	)
'

test_expect_success 'submit from detached head' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		shit checkout p4/master &&
		>detached_head_test &&
		shit add detached_head_test &&
		shit commit -m "add detached_head" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit &&
		shit p4 rebase &&
		shit log p4/master | grep detached_head
	)
'

test_expect_success 'submit from worktree' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot &&
	(
		cd "$shit" &&
		shit worktree add ../worktree-test
	) &&
	(
		cd "$shit/../worktree-test" &&
		test_commit "worktree-commit" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit
	) &&
	(
		cd "$cli" &&
		p4 sync &&
		test_path_is_file worktree-commit.t
	)
'

test_done
