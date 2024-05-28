#!/bin/sh
#
# Copyright (c) 2011 Ray Chen
#

test_description='shit svn test (option --preserve-empty-dirs)

This test uses shit to clone a Subversion repository that contains empty
directories, and checks that corresponding directories are created in the
local shit repository with placeholder files.'

. ./lib-shit-svn.sh

shit_REPO=shit-svn-repo

test_expect_success 'initialize source svn repo containing empty dirs' '
	svn_cmd mkdir -m x "$svnrepo"/trunk &&
	svn_cmd co "$svnrepo"/trunk "$SVN_TREE" &&
	(
		cd "$SVN_TREE" &&
		mkdir -p 1 2 3/a 3/b 4 5 6 &&
		echo "First non-empty file"  > 2/file1.txt &&
		echo "Second non-empty file" > 2/file2.txt &&
		echo "Third non-empty file"  > 3/a/file1.txt &&
		echo "Fourth non-empty file" > 3/b/file1.txt &&
		svn_cmd add 1 2 3 4 5 6 &&
		svn_cmd commit -m "initial commit" &&

		mkdir 4/a &&
		svn_cmd add 4/a &&
		svn_cmd commit -m "nested empty directory" &&
		mkdir 4/a/b &&
		svn_cmd add 4/a/b &&
		svn_cmd commit -m "deeply nested empty directory" &&
		mkdir 4/a/b/c &&
		svn_cmd add 4/a/b/c &&
		svn_cmd commit -m "really deeply nested empty directory" &&
		echo "Kill the placeholder file" > 4/a/b/c/foo &&
		svn_cmd add 4/a/b/c/foo &&
		svn_cmd commit -m "Regular file to remove placeholder" &&

		svn_cmd del 2/file2.txt &&
		svn_cmd del 3/b &&
		svn_cmd commit -m "delete non-last entry in directory" &&

		svn_cmd del 2/file1.txt &&
		svn_cmd del 3/a &&
		svn_cmd commit -m "delete last entry in directory" &&

		echo "Conflict file" > 5/.placeholder &&
		mkdir 6/.placeholder &&
		svn_cmd add 5/.placeholder 6/.placeholder &&
		svn_cmd commit -m "Placeholder Namespace conflict"
	) &&
	rm -rf "$SVN_TREE"
'

test_expect_success 'clone svn repo with --preserve-empty-dirs' '
	shit svn clone "$svnrepo"/trunk --preserve-empty-dirs "$shit_REPO"
'

# "$shit_REPO"/1 should only contain the placeholder file.
test_expect_success 'directory empty from inception' '
	test -f "$shit_REPO"/1/.shitignore &&
	test $(find "$shit_REPO"/1 -type f | wc -l) = "1"
'

# "$shit_REPO"/2 and "$shit_REPO"/3 should only contain the placeholder file.
test_expect_success 'directory empty from subsequent svn commit' '
	test -f "$shit_REPO"/2/.shitignore &&
	test $(find "$shit_REPO"/2 -type f | wc -l) = "1" &&
	test -f "$shit_REPO"/3/.shitignore &&
	test $(find "$shit_REPO"/3 -type f | wc -l) = "1"
'

# No placeholder files should exist in "$shit_REPO"/4, even though one was
# generated for every sub-directory at some point in the repo's history.
test_expect_success 'add entry to previously empty directory' '
	test $(find "$shit_REPO"/4 -type f | wc -l) = "1" &&
	test -f "$shit_REPO"/4/a/b/c/foo
'

# The HEAD~2 commit should not have introduced .shitignore placeholder files.
test_expect_success 'remove non-last entry from directory' '
	(
		cd "$shit_REPO" &&
		shit checkout HEAD~2
	) &&
	test_path_is_missing "$shit_REPO"/2/.shitignore &&
	test_path_is_missing "$shit_REPO"/3/.shitignore
'

# After re-cloning the repository with --placeholder-file specified, there
# should be 5 files named ".placeholder" in the local shit repo.
test_expect_success 'clone svn repo with --placeholder-file specified' '
	rm -rf "$shit_REPO" &&
	shit svn clone "$svnrepo"/trunk --preserve-empty-dirs \
		--placeholder-file=.placeholder "$shit_REPO" &&
	find "$shit_REPO" -type f -name ".placeholder" &&
	test $(find "$shit_REPO" -type f -name ".placeholder" | wc -l) = "5"
'

# "$shit_REPO"/5/.placeholder should be a file, and non-empty.
test_expect_success 'placeholder namespace conflict with file' '
	test -s "$shit_REPO"/5/.placeholder
'

# "$shit_REPO"/6/.placeholder should be a directory, and the "$shit_REPO"/6 tree
# should only contain one file: the placeholder.
test_expect_success 'placeholder namespace conflict with directory' '
	test -d "$shit_REPO"/6/.placeholder &&
	test -f "$shit_REPO"/6/.placeholder/.placeholder &&
	test $(find "$shit_REPO"/6 -type f | wc -l) = "1"
'

# Prepare a second set of svn commits to test persistence during rebase.
test_expect_success 'second set of svn commits and rebase' '
	svn_cmd co "$svnrepo"/trunk "$SVN_TREE" &&
	(
		cd "$SVN_TREE" &&
		mkdir -p 7 &&
		echo "This should remove placeholder" > 1/file1.txt &&
		echo "This should not remove placeholder" > 5/file1.txt &&
		svn_cmd add 7 1/file1.txt 5/file1.txt &&
		svn_cmd commit -m "subsequent svn commit for persistence tests"
	) &&
	rm -rf "$SVN_TREE" &&
	(
		cd "$shit_REPO" &&
		shit svn rebase
	)
'

# Check that --preserve-empty-dirs and --placeholder-file flag state
# stays persistent over multiple invocations.
test_expect_success 'flag persistence during subsqeuent rebase' '
	test -f "$shit_REPO"/7/.placeholder &&
	test $(find "$shit_REPO"/7 -type f | wc -l) = "1"
'

# Check that placeholder files are properly removed when unnecessary,
# even across multiple invocations.
test_expect_success 'placeholder list persistence during subsqeuent rebase' '
	test -f "$shit_REPO"/1/file1.txt &&
	test $(find "$shit_REPO"/1 -type f | wc -l) = "1" &&

	test -f "$shit_REPO"/5/file1.txt &&
	test -f "$shit_REPO"/5/.placeholder &&
	test $(find "$shit_REPO"/5 -type f | wc -l) = "2"
'

test_done
