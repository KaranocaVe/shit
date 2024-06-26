#!/bin/sh

test_description='shit p4 tests for p4 branches'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./lib-shit-p4.sh

test_expect_success 'start p4d' '
	start_p4d
'

#
# 1: //depot/main/f1
# 2: //depot/main/f2
# 3: integrate //depot/main/... -> //depot/branch1/...
# 4: //depot/main/f4
# 5: //depot/branch1/f5
# .: named branch branch2
# 6: integrate -b branch2
# 7: //depot/branch2/f7
# 8: //depot/main/f8
#
test_expect_success 'basic p4 branches' '
	(
		cd "$cli" &&
		mkdir -p main &&

		echo f1 >main/f1 &&
		p4 add main/f1 &&
		p4 submit -d "main/f1" &&

		echo f2 >main/f2 &&
		p4 add main/f2 &&
		p4 submit -d "main/f2" &&

		p4 integrate //depot/main/... //depot/branch1/... &&
		p4 submit -d "integrate main to branch1" &&

		echo f4 >main/f4 &&
		p4 add main/f4 &&
		p4 submit -d "main/f4" &&

		echo f5 >branch1/f5 &&
		p4 add branch1/f5 &&
		p4 submit -d "branch1/f5" &&

		p4 branch -i <<-EOF &&
		Branch: branch2
		View: //depot/main/... //depot/branch2/...
		EOF

		p4 integrate -b branch2 &&
		p4 submit -d "integrate main to branch2" &&

		echo f7 >branch2/f7 &&
		p4 add branch2/f7 &&
		p4 submit -d "branch2/f7" &&

		echo f8 >main/f8 &&
		p4 add main/f8 &&
		p4 submit -d "main/f8"
	)
'

test_expect_success 'import main, no branch detection' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot/main@all &&
	(
		cd "$shit" &&
		shit log --oneline --graph --decorate --all &&
		shit rev-list main -- >wc &&
		test_line_count = 4 wc
	)
'

test_expect_success 'import branch1, no branch detection' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot/branch1@all &&
	(
		cd "$shit" &&
		shit log --oneline --graph --decorate --all &&
		shit rev-list main -- >wc &&
		test_line_count = 2 wc
	)
'

test_expect_success 'import branch2, no branch detection' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot/branch2@all &&
	(
		cd "$shit" &&
		shit log --oneline --graph --decorate --all &&
		shit rev-list main -- >wc &&
		test_line_count = 2 wc
	)
'

test_expect_success 'import depot, no branch detection' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot@all &&
	(
		cd "$shit" &&
		shit log --oneline --graph --decorate --all &&
		shit rev-list main -- >wc &&
		test_line_count = 8 wc
	)
'

test_expect_success 'import depot, branch detection' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" --detect-branches //depot@all &&
	(
		cd "$shit" &&

		shit log --oneline --graph --decorate --all &&

		# 4 main commits
		shit rev-list main -- >wc &&
		test_line_count = 4 wc &&

		# 3 main, 1 integrate, 1 on branch2
		shit rev-list p4/depot/branch2 >wc &&
		test_line_count = 5 wc &&

		# no branch1, since no p4 branch created for it
		test_must_fail shit show-ref p4/depot/branch1
	)
'

test_expect_success 'sync specific detected branch' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" --detect-branches //depot@all &&
	(
		cd "$shit" &&
		shit p4 sync --branch=depot/branch2 >out &&
		test_grep "No changes to import!" out
	)
'

test_expect_success 'import depot, branch detection, branchList branch definition' '
	test_when_finished cleanup_shit &&
	test_create_repo "$shit" &&
	(
		cd "$shit" &&
		shit config shit-p4.branchList main:branch1 &&
		shit p4 clone --dest=. --detect-branches //depot@all &&

		shit log --oneline --graph --decorate --all &&

		# 4 main commits
		shit rev-list main -- >wc &&
		test_line_count = 4 wc &&

		# 3 main, 1 integrate, 1 on branch2
		shit rev-list p4/depot/branch2 >wc &&
		test_line_count = 5 wc &&

		# 2 main, 1 integrate, 1 on branch1
		shit rev-list p4/depot/branch1 >wc &&
		test_line_count = 4 wc
	)
'

test_expect_success 'restart p4d' '
	stop_and_cleanup_p4d &&
	start_p4d
'

#
# 1: //depot/branch1/file1
#    //depot/branch1/file2
# 2: integrate //depot/branch1/... -> //depot/branch2/...
# 3: //depot/branch1/file3
# 4: //depot/branch1/file2 (edit)
# 5: integrate //depot/branch1/... -> //depot/branch3/...
#
## Create a simple branch structure in P4 depot.
test_expect_success 'add simple p4 branches' '
	(
		cd "$cli" &&
		mkdir branch1 &&
		cd branch1 &&
		echo file1 >file1 &&
		echo file2 >file2 &&
		p4 add file1 file2 &&
		p4 submit -d "Create branch1" &&
		p4 integrate //depot/branch1/... //depot/branch2/... &&
		p4 submit -d "Integrate branch2 from branch1" &&
		echo file3 >file3 &&
		p4 add file3 &&
		p4 submit -d "add file3 in branch1" &&
		p4 open file2 &&
		echo update >>file2 &&
		p4 submit -d "update file2 in branch1" &&
		p4 integrate //depot/branch1/... //depot/branch3/... &&
		p4 submit -d "Integrate branch3 from branch1"
	)
'

# Configure branches through shit-config and clone them.
# All files are tested to make sure branches were cloned correctly.
# Finally, make an update to branch1 on P4 side to check if it is imported
# correctly by shit p4.
test_expect_success 'shit p4 clone simple branches' '
	test_when_finished cleanup_shit &&
	test_create_repo "$shit" &&
	(
		cd "$shit" &&
		shit config shit-p4.branchList branch1:branch2 &&
		shit config --add shit-p4.branchList branch1:branch3 &&
		shit p4 clone --dest=. --detect-branches //depot@all &&
		shit log --all --graph --decorate --stat &&
		shit reset --hard p4/depot/branch1 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_file file3 &&
		grep update file2 &&
		shit reset --hard p4/depot/branch2 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test ! -f file3 &&
		! grep update file2 &&
		shit reset --hard p4/depot/branch3 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_file file3 &&
		grep update file2 &&
		cd "$cli" &&
		cd branch1 &&
		p4 edit file2 &&
		echo file2_ >>file2 &&
		p4 submit -d "update file2 in branch1" &&
		cd "$shit" &&
		shit reset --hard p4/depot/branch1 &&
		shit p4 rebase &&
		grep file2_ file2
	)
'

# Create a complex branch structure in P4 depot to check if they are correctly
# cloned. The branches are created from older changelists to check if shit p4 is
# able to correctly detect them.
# The final expected structure is:
# `branch1
# | `- file1
# | `- file2 (updated)
# | `- file3
# `branch2
# | `- file1
# | `- file2
# `branch3
# | `- file1
# | `- file2 (updated)
# | `- file3
# `branch4
# | `- file1
# | `- file2
# `branch5
#   `- file1
#   `- file2
#   `- file3
test_expect_success 'shit p4 add complex branches' '
	(
		cd "$cli" &&
		changelist=$(p4 changes -m1 //depot/... | cut -d" " -f2) &&
		changelist=$(($changelist - 5)) &&
		p4 integrate //depot/branch1/...@$changelist //depot/branch4/... &&
		p4 submit -d "Integrate branch4 from branch1@${changelist}" &&
		changelist=$(($changelist + 2)) &&
		p4 integrate //depot/branch1/...@$changelist //depot/branch5/... &&
		p4 submit -d "Integrate branch5 from branch1@${changelist}"
	)
'

# Configure branches through shit-config and clone them. shit p4 will only be able
# to clone the original structure if it is able to detect the origin changelist
# of each branch.
test_expect_success 'shit p4 clone complex branches' '
	test_when_finished cleanup_shit &&
	test_create_repo "$shit" &&
	(
		cd "$shit" &&
		shit config shit-p4.branchList branch1:branch2 &&
		shit config --add shit-p4.branchList branch1:branch3 &&
		shit config --add shit-p4.branchList branch1:branch4 &&
		shit config --add shit-p4.branchList branch1:branch5 &&
		shit p4 clone --dest=. --detect-branches //depot@all &&
		shit log --all --graph --decorate --stat &&
		shit reset --hard p4/depot/branch1 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_file file3 &&
		grep update file2 &&
		shit reset --hard p4/depot/branch2 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_missing file3 &&
		! grep update file2 &&
		shit reset --hard p4/depot/branch3 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_file file3 &&
		grep update file2 &&
		shit reset --hard p4/depot/branch4 &&
		shit diff-tree --quiet HEAD &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_missing file3 &&
		! grep update file2 &&
		shit reset --hard p4/depot/branch5 &&
		shit diff-tree --quiet HEAD &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_file file3 &&
		! grep update file2 &&
		test_must_fail shit show-ref --verify refs/shit-p4-tmp
	)
'

# Move branch3/file3 to branch4/file3 in a single changelist
test_expect_success 'shit p4 submit to two branches in a single changelist' '
	(
		cd "$cli" &&
		p4 integrate //depot/branch3/file3 //depot/branch4/file3 &&
		p4 delete //depot/branch3/file3 &&
		p4 submit -d "Move branch3/file3 to branch4/file3"
	)
'

# Confirm that changes to two branches done in a single changelist
# are correctly imported by shit p4
test_expect_success 'shit p4 sync changes to two branches in the same changelist' '
	test_when_finished cleanup_shit &&
	test_create_repo "$shit" &&
	(
		cd "$shit" &&
		shit config shit-p4.branchList branch1:branch2 &&
		shit config --add shit-p4.branchList branch1:branch3 &&
		shit config --add shit-p4.branchList branch1:branch4 &&
		shit config --add shit-p4.branchList branch1:branch5 &&
		shit p4 clone --dest=. --detect-branches //depot@all &&
		shit log --all --graph --decorate --stat &&
		shit reset --hard p4/depot/branch1 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_file file3 &&
		grep update file2 &&
		shit reset --hard p4/depot/branch2 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_missing file3 &&
		! grep update file2 &&
		shit reset --hard p4/depot/branch3 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_missing file3 &&
		grep update file2 &&
		shit reset --hard p4/depot/branch4 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_file file3 &&
		! grep update file2 &&
		shit reset --hard p4/depot/branch5 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_file file3 &&
		! grep update file2 &&
		test_must_fail shit show-ref --verify refs/shit-p4-tmp
	)
'

# Create a branch by integrating a single file
test_expect_success 'shit p4 file subset branch' '
	(
		cd "$cli" &&
		p4 integrate //depot/branch1/file1 //depot/branch6/file1 &&
		p4 submit -d "Integrate file1 alone from branch1 to branch6"
	)
'

# Check if shit p4 creates a new branch containing a single file,
# instead of keeping the old files from the original branch
test_expect_failure 'shit p4 clone file subset branch' '
	test_when_finished cleanup_shit &&
	test_create_repo "$shit" &&
	(
		cd "$shit" &&
		shit config shit-p4.branchList branch1:branch2 &&
		shit config --add shit-p4.branchList branch1:branch3 &&
		shit config --add shit-p4.branchList branch1:branch4 &&
		shit config --add shit-p4.branchList branch1:branch5 &&
		shit config --add shit-p4.branchList branch1:branch6 &&
		shit p4 clone --dest=. --detect-branches //depot@all &&
		shit log --all --graph --decorate --stat &&
		shit reset --hard p4/depot/branch1 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_file file3 &&
		grep update file2 &&
		shit reset --hard p4/depot/branch2 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_missing file3 &&
		! grep update file2 &&
		shit reset --hard p4/depot/branch3 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_missing file3 &&
		grep update file2 &&
		shit reset --hard p4/depot/branch4 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_file file3 &&
		! grep update file2 &&
		shit reset --hard p4/depot/branch5 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_file file3 &&
		! grep update file2 &&
		shit reset --hard p4/depot/branch6 &&
		test_path_is_file file1 &&
		test_path_is_missing file2 &&
		test_path_is_missing file3
	)
'

# Check that excluded files are omitted during import
test_expect_success 'shit p4 clone complex branches with excluded files' '
	test_when_finished cleanup_shit &&
	test_create_repo "$shit" &&
	(
		cd "$shit" &&
		shit config shit-p4.branchList branch1:branch2 &&
		shit config --add shit-p4.branchList branch1:branch3 &&
		shit config --add shit-p4.branchList branch1:branch4 &&
		shit config --add shit-p4.branchList branch1:branch5 &&
		shit config --add shit-p4.branchList branch1:branch6 &&
		shit p4 clone --dest=. --detect-branches -//depot/branch1/file2 -//depot/branch2/file2 -//depot/branch3/file2 -//depot/branch4/file2 -//depot/branch5/file2 -//depot/branch6/file2 //depot@all &&
		shit log --all --graph --decorate --stat &&
		shit reset --hard p4/depot/branch1 &&
		test_path_is_file file1 &&
		test_path_is_missing file2 &&
		test_path_is_file file3 &&
		shit reset --hard p4/depot/branch2 &&
		test_path_is_file file1 &&
		test_path_is_missing file2 &&
		test_path_is_missing file3 &&
		shit reset --hard p4/depot/branch3 &&
		test_path_is_file file1 &&
		test_path_is_missing file2 &&
		test_path_is_missing file3 &&
		shit reset --hard p4/depot/branch4 &&
		test_path_is_file file1 &&
		test_path_is_missing file2 &&
		test_path_is_file file3 &&
		shit reset --hard p4/depot/branch5 &&
		test_path_is_file file1 &&
		test_path_is_missing file2 &&
		test_path_is_file file3 &&
		shit reset --hard p4/depot/branch6 &&
		test_path_is_file file1 &&
		test_path_is_missing file2 &&
		test_path_is_missing file3
	)
'

# From a report in https://stackoverflow.com/questions/11893688
# where --use-client-spec caused branch prefixes not to be removed;
# every file in shit appeared into a subdirectory of the branch name.
test_expect_success 'use-client-spec detect-branches setup' '
	rm -rf "$cli" &&
	mkdir "$cli" &&
	(
		cd "$cli" &&
		client_view "//depot/usecs/... //client/..." &&
		mkdir b1 &&
		echo b1/b1-file1 >b1/b1-file1 &&
		p4 add b1/b1-file1 &&
		p4 submit -d "b1/b1-file1" &&

		p4 integrate //depot/usecs/b1/... //depot/usecs/b2/... &&
		p4 submit -d "b1 -> b2" &&
		p4 branch -i <<-EOF &&
		Branch: b2
		View: //depot/usecs/b1/... //depot/usecs/b2/...
		EOF

		echo b2/b2-file2 >b2/b2-file2 &&
		p4 add b2/b2-file2 &&
		p4 submit -d "b2/b2-file2"
	)
'

test_expect_success 'use-client-spec detect-branches files in top-level' '
	test_when_finished cleanup_shit &&
	test_create_repo "$shit" &&
	(
		cd "$shit" &&
		shit p4 sync --detect-branches --use-client-spec //depot/usecs@all &&
		shit checkout -b main p4/usecs/b1 &&
		test_path_is_file b1-file1 &&
		test_path_is_missing b2-file2 &&
		test_path_is_missing b1 &&
		test_path_is_missing b2 &&

		shit checkout -b b2 p4/usecs/b2 &&
		test_path_is_file b1-file1 &&
		test_path_is_file b2-file2 &&
		test_path_is_missing b1 &&
		test_path_is_missing b2
	)
'

test_expect_success 'use-client-spec detect-branches skips branches setup' '
	(
		cd "$cli" &&

		p4 integrate //depot/usecs/b1/... //depot/usecs/b3/... &&
		p4 submit -d "b1 -> b3" &&
		p4 branch -i <<-EOF &&
		Branch: b3
		View: //depot/usecs/b1/... //depot/usecs/b3/...
		EOF

		echo b3/b3-file3_1 >b3/b3-file3_1 &&
		echo b3/b3-file3_2 >b3/b3-file3_2 &&
		p4 add b3/b3-file3_1 &&
		p4 add b3/b3-file3_2 &&
		p4 submit -d "b3/b3-file3_1 b3/b3-file3_2"
	)
'

test_expect_success 'use-client-spec detect-branches skips branches' '
	client_view "//depot/usecs/... //client/..." \
		    "-//depot/usecs/b3/... //client/b3/..." &&
	test_when_finished cleanup_shit &&
	test_create_repo "$shit" &&
	(
		cd "$shit" &&
		shit p4 sync --detect-branches --use-client-spec //depot/usecs@all &&
		test_must_fail shit rev-parse refs/remotes/p4/usecs/b3
	)
'

test_expect_success 'use-client-spec detect-branches skips files in branches' '
	client_view "//depot/usecs/... //client/..." \
		    "-//depot/usecs/b3/b3-file3_1 //client/b3/b3-file3_1" &&
	test_when_finished cleanup_shit &&
	test_create_repo "$shit" &&
	(
		cd "$shit" &&
		shit p4 sync --detect-branches --use-client-spec //depot/usecs@all &&
		shit checkout -b main p4/usecs/b3 &&
		test_path_is_file b1-file1 &&
		test_path_is_file b3-file3_2 &&
		test_path_is_missing b3-file3_1
	)
'

test_expect_success 'restart p4d' '
	stop_and_cleanup_p4d &&
	start_p4d
'

#
# 1: //depot/branch1/base/file1
#    //depot/branch1/base/file2
#    //depot/branch1/base/dir/sub_file1
# 2: integrate //depot/branch1/base/... -> //depot/branch2/base/...
# 3: //depot/branch1/base/file3
# 4: //depot/branch1/base/file2 (edit)
# 5: integrate //depot/branch1/base/... -> //depot/branch3/base/...
#
# Note: the client view removes the "base" folder from the workspace
#       and moves sub_file1 one level up.
test_expect_success 'add simple p4 branches with common base folder on each branch' '
	(
		cd "$cli" &&
		client_view "//depot/branch1/base/... //client/branch1/..." \
			    "//depot/branch1/base/dir/sub_file1 //client/branch1/sub_file1" \
			    "//depot/branch2/base/... //client/branch2/..." \
			    "//depot/branch3/base/... //client/branch3/..." &&
		mkdir -p branch1 &&
		cd branch1 &&
		echo file1 >file1 &&
		echo file2 >file2 &&
		mkdir dir &&
		echo sub_file1 >sub_file1 &&
		p4 add file1 file2 sub_file1 &&
		p4 submit -d "Create branch1" &&
		p4 integrate //depot/branch1/base/... //depot/branch2/base/... &&
		p4 submit -d "Integrate branch2 from branch1" &&
		echo file3 >file3 &&
		p4 add file3 &&
		p4 submit -d "add file3 in branch1" &&
		p4 open file2 &&
		echo update >>file2 &&
		p4 submit -d "update file2 in branch1" &&
		p4 integrate //depot/branch1/base/... //depot/branch3/base/... &&
		p4 submit -d "Integrate branch3 from branch1"
	)
'

# Configure branches through shit-config and clone them.
# All files are tested to make sure branches were cloned correctly.
# Finally, make an update to branch1 on P4 side to check if it is imported
# correctly by shit p4.
# shit p4 is expected to use the client view to also not include the common
# "base" folder in the imported directory structure.
test_expect_success 'shit p4 clone simple branches with base folder on server side' '
	test_create_repo "$shit" &&
	(
		cd "$shit" &&
		shit config shit-p4.branchList branch1:branch2 &&
		shit config --add shit-p4.branchList branch1:branch3 &&
		shit p4 clone --dest=. --use-client-spec  --detect-branches //depot@all &&
		shit log --all --graph --decorate --stat &&
		shit reset --hard p4/depot/branch1 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_file file3 &&
		test_path_is_file sub_file1 &&
		grep update file2 &&
		shit reset --hard p4/depot/branch2 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test ! -f file3 &&
		test_path_is_file sub_file1 &&
		! grep update file2 &&
		shit reset --hard p4/depot/branch3 &&
		test_path_is_file file1 &&
		test_path_is_file file2 &&
		test_path_is_file file3 &&
		test_path_is_file sub_file1 &&
		grep update file2 &&
		cd "$cli" &&
		cd branch1 &&
		p4 edit file2 &&
		echo file2_ >>file2 &&
		p4 submit -d "update file2 in branch1" &&
		cd "$shit" &&
		shit reset --hard p4/depot/branch1 &&
		shit p4 rebase &&
		grep file2_ file2
	)
'

# Now update a file in one of the branches in shit and submit to P4
test_expect_success 'Update a file in shit side and submit to P4 using client view' '
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit reset --hard p4/depot/branch1 &&
		echo "client spec" >> file1 &&
		shit add -u . &&
		shit commit -m "update file1 in branch1" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit --verbose &&
		cd "$cli" &&
		p4 sync ... &&
		cd branch1 &&
		grep "client spec" file1
	)
'

test_expect_success 'restart p4d (case folding enabled)' '
	stop_and_cleanup_p4d &&
	start_p4d -C1
'

#
# 1: //depot/main/mf1
# 2: integrate //depot/main/... -> //depot/branch1/...
# 3: //depot/main/mf2
# 4: //depot/BRANCH1/B1f3
# 5: //depot/branch1/b1f4
#
test_expect_success !CASE_INSENSITIVE_FS 'basic p4 branches for case folding' '
	(
		cd "$cli" &&
		mkdir -p main &&

		echo mf1 >main/mf1 &&
		p4 add main/mf1 &&
		p4 submit -d "main/mf1" &&

		p4 integrate //depot/main/... //depot/branch1/... &&
		p4 submit -d "integrate main to branch1" &&

		echo mf2 >main/mf2 &&
		p4 add main/mf2 &&
		p4 submit -d "main/mf2" &&

		mkdir BRANCH1 &&
		echo B1f3 >BRANCH1/B1f3 &&
		p4 add BRANCH1/B1f3 &&
		p4 submit -d "BRANCH1/B1f3" &&

		echo b1f4 >branch1/b1f4 &&
		p4 add branch1/b1f4 &&
		p4 submit -d "branch1/b1f4"
	)
'

# Check that files are properly split across branches when ignorecase is set
test_expect_success !CASE_INSENSITIVE_FS 'shit p4 clone, branchList branch definition, ignorecase' '
	test_when_finished cleanup_shit &&
	test_create_repo "$shit" &&
	(
		cd "$shit" &&
		shit config shit-p4.branchList main:branch1 &&
		shit config --type=bool core.ignoreCase true &&
		shit p4 clone --dest=. --detect-branches //depot@all &&

		shit log --all --graph --decorate --stat &&

		shit reset --hard p4/master &&
		test_path_is_file mf1 &&
		test_path_is_file mf2 &&
		test_path_is_missing B1f3 &&
		test_path_is_missing b1f4 &&

		shit reset --hard p4/depot/branch1 &&
		test_path_is_file mf1 &&
		test_path_is_missing mf2 &&
		test_path_is_file B1f3 &&
		test_path_is_file b1f4
	)
'

# Check that files are properly split across branches when ignorecase is set, use-client-spec case
test_expect_success !CASE_INSENSITIVE_FS 'shit p4 clone with client-spec, branchList branch definition, ignorecase' '
	client_view "//depot/... //client/..." &&
	test_when_finished cleanup_shit &&
	test_create_repo "$shit" &&
	(
		cd "$shit" &&
		shit config shit-p4.branchList main:branch1 &&
		shit config --type=bool core.ignoreCase true &&
		shit p4 clone --dest=. --use-client-spec --detect-branches //depot@all &&

		shit log --all --graph --decorate --stat &&

		shit reset --hard p4/master &&
		test_path_is_file mf1 &&
		test_path_is_file mf2 &&
		test_path_is_missing B1f3 &&
		test_path_is_missing b1f4 &&

		shit reset --hard p4/depot/branch1 &&
		test_path_is_file mf1 &&
		test_path_is_missing mf2 &&
		test_path_is_file B1f3 &&
		test_path_is_file b1f4
	)
'

test_done
