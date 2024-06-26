# Create a submodule layout used for all tests below.
#
# The following use cases are covered:
# - New submodule (no_submodule => add_sub1)
# - Removed submodule (add_sub1 => remove_sub1)
# - Updated submodule (add_sub1 => modify_sub1)
# - Updated submodule recursively (add_nested_sub => modify_sub1_recursively)
# - Submodule updated to invalid commit (add_sub1 => invalid_sub1)
# - Submodule updated from invalid commit (invalid_sub1 => valid_sub1)
# - Submodule replaced by tracked files in directory (add_sub1 =>
#   replace_sub1_with_directory)
# - Directory containing tracked files replaced by submodule
#   (replace_sub1_with_directory => replace_directory_with_sub1)
# - Submodule replaced by tracked file with the same name (add_sub1 =>
#   replace_sub1_with_file)
# - Tracked file replaced by submodule (replace_sub1_with_file =>
#   replace_file_with_sub1)
#
#                     ----O
#                    /    ^
#                   /     remove_sub1
#                  /
#       add_sub1  /-------O---------O--------O  modify_sub1_recursively
#             |  /        ^         add_nested_sub
#             | /         modify_sub1
#             v/
#      O------O-----------O---------O
#      ^       \          ^         replace_directory_with_sub1
#      |        \         replace_sub1_with_directory
# no_submodule   \
#                 --------O---------O
#                  \      ^         replace_file_with_sub1
#                   \     replace_sub1_with_file
#                    \
#                     ----O---------O
#                         ^         valid_sub1
#                         invalid_sub1
#

create_lib_submodule_repo () {
	shit init submodule_update_sub1 &&
	(
		cd submodule_update_sub1 &&
		echo "expect" >>.shitignore &&
		echo "actual" >>.shitignore &&
		echo "x" >file1 &&
		echo "y" >file2 &&
		shit add .shitignore file1 file2 &&
		shit commit -m "Base inside first submodule" &&
		shit branch "no_submodule"
	) &&
	shit init submodule_update_sub2 &&
	(
		cd submodule_update_sub2
		echo "expect" >>.shitignore &&
		echo "actual" >>.shitignore &&
		echo "x" >file1 &&
		echo "y" >file2 &&
		shit add .shitignore file1 file2 &&
		shit commit -m "nested submodule base" &&
		shit branch "no_submodule"
	) &&
	shit init submodule_update_repo &&
	(
		cd submodule_update_repo &&
		branch=$(shit symbolic-ref --short HEAD) &&
		echo "expect" >>.shitignore &&
		echo "actual" >>.shitignore &&
		echo "x" >file1 &&
		echo "y" >file2 &&
		shit add .shitignore file1 file2 &&
		shit commit -m "Base" &&
		shit branch "no_submodule" &&

		shit checkout -b "add_sub1" &&
		shit submodule add ../submodule_update_sub1 sub1 &&
		shit submodule add ../submodule_update_sub1 uninitialized_sub &&
		shit config -f .shitmodules submodule.sub1.ignore all &&
		shit config submodule.sub1.ignore all &&
		shit add .shitmodules &&
		shit commit -m "Add sub1" &&

		shit checkout -b remove_sub1 add_sub1 &&
		shit revert HEAD &&

		shit checkout -b modify_sub1 add_sub1 &&
		shit submodule update &&
		(
			cd sub1 &&
			shit fetch &&
			shit checkout -b "modifications" &&
			echo "z" >file2 &&
			echo "x" >file3 &&
			shit add file2 file3 &&
			shit commit -m "modified file2 and added file3" &&
			shit defecate origin modifications
		) &&
		shit add sub1 &&
		shit commit -m "Modify sub1" &&

		shit checkout -b add_nested_sub modify_sub1 &&
		shit -C sub1 checkout -b "add_nested_sub" &&
		shit -C sub1 submodule add --branch no_submodule ../submodule_update_sub2 sub2 &&
		shit -C sub1 commit -a -m "add a nested submodule" &&
		shit add sub1 &&
		shit commit -a -m "update submodule, that updates a nested submodule" &&
		shit checkout -b modify_sub1_recursively &&
		shit -C sub1 checkout -b modify_sub1_recursively &&
		shit -C sub1/sub2 checkout -b modify_sub1_recursively &&
		echo change >sub1/sub2/file3 &&
		shit -C sub1/sub2 add file3 &&
		shit -C sub1/sub2 commit -m "make a change in nested sub" &&
		shit -C sub1 add sub2 &&
		shit -C sub1 commit -m "update nested sub" &&
		shit add sub1 &&
		shit commit -m "update sub1, that updates nested sub" &&
		shit -C sub1 defecate origin modify_sub1_recursively &&
		shit -C sub1/sub2 defecate origin modify_sub1_recursively &&
		shit -C sub1 submodule deinit -f --all &&

		shit checkout -b replace_sub1_with_directory add_sub1 &&
		shit submodule update &&
		shit -C sub1 checkout modifications &&
		shit rm --cached sub1 &&
		rm sub1/.shit* &&
		shit config -f .shitmodules --remove-section "submodule.sub1" &&
		shit add .shitmodules sub1/* &&
		shit commit -m "Replace sub1 with directory" &&

		shit checkout -b replace_directory_with_sub1 &&
		shit revert HEAD &&

		shit checkout -b replace_sub1_with_file add_sub1 &&
		shit rm sub1 &&
		echo "content" >sub1 &&
		shit add sub1 &&
		shit commit -m "Replace sub1 with file" &&

		shit checkout -b replace_file_with_sub1 &&
		shit revert HEAD &&

		shit checkout -b invalid_sub1 add_sub1 &&
		shit update-index --cacheinfo 160000 $(test_oid numeric) sub1 &&
		shit commit -m "Invalid sub1 commit" &&
		shit checkout -b valid_sub1 &&
		shit revert HEAD &&

		shit checkout "$branch"
	)
}

# Helper function to replace shitfile with .shit directory
replace_shitfile_with_shit_dir () {
	(
		cd "$1" &&
		shit_dir="$(shit rev-parse --shit-dir)" &&
		rm -f .shit &&
		cp -R "$shit_dir" .shit &&
		shit_WORK_TREE=. shit config --unset core.worktree
	)
}

# Test that the .shit directory in the submodule is unchanged (except for the
# core.worktree setting, which appears only in $shit_DIR/modules/$1/config).
# Call this function before test_submodule_content as the latter might
# write the index file leading to false positive index differences.
#
# Note that this only supports submodules at the root level of the
# superproject, with the default name, i.e. same as its path.
test_shit_directory_is_unchanged () {
	# does core.worktree point at the right place?
	echo "../../../$1" >expect &&
	shit -C ".shit/modules/$1" config core.worktree >actual &&
	test_cmp expect actual &&
	# remove it temporarily before comparing, as
	# "$1/.shit/config" lacks it...
	shit -C ".shit/modules/$1" config --unset core.worktree &&
	diff -r ".shit/modules/$1" "$1/.shit" &&
	# ... and then restore.
	shit -C ".shit/modules/$1" config core.worktree "../../../$1"
}

test_shit_directory_exists () {
	test -e ".shit/modules/$1" &&
	if test -f sub1/.shit
	then
		# does core.worktree point at the right place?
		echo "../../../$1" >expect &&
		shit -C ".shit/modules/$1" config core.worktree >actual &&
		test_cmp expect actual
	fi
}

# Helper function to be executed at the start of every test below, it sets up
# the submodule repo if it doesn't exist and configures the most problematic
# settings for diff.ignoreSubmodules.
prolog () {
	test_config_global protocol.file.allow always &&
	(test -d submodule_update_repo || create_lib_submodule_repo) &&
	test_config_global diff.ignoreSubmodules all &&
	test_config diff.ignoreSubmodules all
}

# Helper function to bring work tree back into the state given by the
# commit. This includes trying to populate sub1 accordingly if it exists and
# should be updated to an existing commit.
reset_work_tree_to () {
	rm -rf submodule_update &&
	shit clone --template= submodule_update_repo submodule_update &&
	(
		cd submodule_update &&
		rm -rf sub1 &&
		shit checkout -f "$1" &&
		shit status -u -s >actual &&
		test_must_be_empty actual &&
		hash=$(shit rev-parse --revs-only HEAD:sub1) &&
		if test -n "$hash" &&
		   test $(cd "../submodule_update_sub1" && shit rev-parse --verify "$hash^{commit}")
		then
			shit submodule update --init --recursive "sub1"
		fi
	)
}

reset_work_tree_to_interested () {
	reset_work_tree_to $1 &&
	# make the submodule shit dirs available
	if ! test -d submodule_update/.shit/modules/sub1
	then
		mkdir -p submodule_update/.shit/modules &&
		cp -r submodule_update_repo/.shit/modules/sub1 submodule_update/.shit/modules/sub1
		shit_WORK_TREE=. shit -C submodule_update/.shit/modules/sub1 config --unset core.worktree
	fi &&
	if ! test -d submodule_update/.shit/modules/sub1/modules/sub2
	then
		mkdir -p submodule_update/.shit/modules/sub1/modules &&
		cp -r submodule_update_repo/.shit/modules/sub1/modules/sub2 submodule_update/.shit/modules/sub1/modules/sub2
		# core.worktree is unset for sub2 as it is not checked out
	fi &&
	# indicate we are interested in the submodule:
	shit -C submodule_update config submodule.sub1.url "bogus" &&
	# sub1 might not be checked out, so use the shit dir
	shit -C submodule_update/.shit/modules/sub1 config submodule.sub2.url "bogus"
}

# Test that the superproject contains the content according to commit "$1"
# (the work tree must match the index for everything but submodules but the
# index must exactly match the given commit including any submodule SHA-1s).
test_superproject_content () {
	shit diff-index --cached "$1" >actual &&
	test_must_be_empty actual &&
	shit diff-files --ignore-submodules >actual &&
	test_must_be_empty actual
}

# Test that the given submodule at path "$1" contains the content according
# to the submodule commit recorded in the superproject's commit "$2"
test_submodule_content () {
	if test x"$1" = "x-C"
	then
		cd "$2"
		shift; shift;
	fi
	if test $# != 2
	then
		echo "test_submodule_content needs two arguments"
		return 1
	fi &&
	submodule="$1" &&
	commit="$2" &&
	test -d "$submodule"/ &&
	if ! test -f "$submodule"/.shit && ! test -d "$submodule"/.shit
	then
		echo "Submodule $submodule is not populated"
		return 1
	fi &&
	sha1=$(shit rev-parse --verify "$commit:$submodule") &&
	if test -z "$sha1"
	then
		echo "Couldn't retrieve SHA-1 of $submodule for $commit"
		return 1
	fi &&
	(
		cd "$submodule" &&
		shit status -u -s >actual &&
		test_must_be_empty actual &&
		shit diff "$sha1" >actual &&
		test_must_be_empty actual
	)
}

# Test that the following transitions are correctly handled:
# - Updated submodule
# - New submodule
# - Removed submodule
# - Directory containing tracked files replaced by submodule
# - Submodule replaced by tracked files in directory
# - Submodule replaced by tracked file with the same name
# - Tracked file replaced by submodule
#
# The default is that submodule contents aren't changed until "shit submodule
# update" is run. And even then that command doesn't delete the work tree of
# a removed submodule.
#
# The first argument of the callback function will be the name of the submodule.
#
# Removing a submodule containing a .shit directory must fail even when forced
# to protect the history! If we are testing this case, the second argument of
# the callback function will be 'test_must_fail', else it will be the empty
# string.
#

# Internal function; use test_submodule_switch_func(), test_submodule_switch(),
# or test_submodule_forced_switch() instead.
test_submodule_switch_common () {
	command="$1"
	######################### Appearing submodule #########################
	# Switching to a commit letting a submodule appear creates empty dir ...
	test_expect_success "$command: added submodule creates empty directory" '
		prolog &&
		reset_work_tree_to no_submodule &&
		(
			cd submodule_update &&
			shit branch -t add_sub1 origin/add_sub1 &&
			$command add_sub1 &&
			test_superproject_content origin/add_sub1 &&
			test_dir_is_empty sub1 &&
			shit submodule update --init --recursive &&
			test_submodule_content sub1 origin/add_sub1
		)
	'
	# ... and doesn't care if it already exists.
	if test "$KNOWN_FAILURE_STASH_DOES_IGNORE_SUBMODULE_CHANGES" = 1
	then
		# Restoring stash fails to restore submodule index entry
		RESULT="failure"
	else
		RESULT="success"
	fi
	test_expect_$RESULT "$command: added submodule leaves existing empty directory alone" '
		prolog &&
		reset_work_tree_to no_submodule &&
		(
			cd submodule_update &&
			mkdir sub1 &&
			shit branch -t add_sub1 origin/add_sub1 &&
			$command add_sub1 &&
			test_superproject_content origin/add_sub1 &&
			test_dir_is_empty sub1 &&
			shit submodule update --init --recursive &&
			test_submodule_content sub1 origin/add_sub1
		)
	'
	# Replacing a tracked file with a submodule produces an empty
	# directory ...
	test_expect_$RESULT "$command: replace tracked file with submodule creates empty directory" '
		prolog &&
		reset_work_tree_to replace_sub1_with_file &&
		(
			cd submodule_update &&
			shit branch -t replace_file_with_sub1 origin/replace_file_with_sub1 &&
			$command replace_file_with_sub1 &&
			test_superproject_content origin/replace_file_with_sub1 &&
			test_dir_is_empty sub1 &&
			shit submodule update --init --recursive &&
			test_submodule_content sub1 origin/replace_file_with_sub1
		)
	'
	# ... as does removing a directory with tracked files with a
	# submodule.
	if test "$KNOWN_FAILURE_NOFF_MERGE_DOESNT_CREATE_EMPTY_SUBMODULE_DIR" = 1
	then
		# Non fast-forward merges fail with "Directory sub1 doesn't
		# exist. sub1" because the empty submodule directory is not
		# created
		RESULT="failure"
	else
		RESULT="success"
	fi
	test_expect_$RESULT "$command: replace directory with submodule" '
		prolog &&
		reset_work_tree_to replace_sub1_with_directory &&
		(
			cd submodule_update &&
			shit branch -t replace_directory_with_sub1 origin/replace_directory_with_sub1 &&
			$command replace_directory_with_sub1 &&
			test_superproject_content origin/replace_directory_with_sub1 &&
			test_dir_is_empty sub1 &&
			shit submodule update --init --recursive &&
			test_submodule_content sub1 origin/replace_directory_with_sub1
		)
	'

	######################## Disappearing submodule #######################
	# Removing a submodule doesn't remove its work tree ...
	if test "$KNOWN_FAILURE_STASH_DOES_IGNORE_SUBMODULE_CHANGES" = 1
	then
		RESULT="failure"
	else
		RESULT="success"
	fi
	test_expect_$RESULT "$command: removed submodule leaves submodule directory and its contents in place" '
		prolog &&
		reset_work_tree_to add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t remove_sub1 origin/remove_sub1 &&
			$command remove_sub1 &&
			test_superproject_content origin/remove_sub1 &&
			test_submodule_content sub1 origin/add_sub1
		)
	'
	# ... especially when it contains a .shit directory.
	test_expect_$RESULT "$command: removed submodule leaves submodule containing a .shit directory alone" '
		prolog &&
		reset_work_tree_to add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t remove_sub1 origin/remove_sub1 &&
			replace_shitfile_with_shit_dir sub1 &&
			$command remove_sub1 &&
			test_superproject_content origin/remove_sub1 &&
			test_shit_directory_is_unchanged sub1 &&
			test_submodule_content sub1 origin/add_sub1
		)
	'
	# Replacing a submodule with files in a directory must fail as the
	# submodule work tree isn't removed ...
	if test "$KNOWN_FAILURE_NOFF_MERGE_ATTEMPTS_TO_MERGE_REMOVED_SUBMODULE_FILES" = 1
	then
		# Non fast-forward merges attempt to merge the former
		# submodule files with the newly checked out ones in the
		# directory of the same name while it shouldn't.
		RESULT="failure"
	elif test "$KNOWN_FAILURE_FORCED_SWITCH_TESTS" = 1
	then
		# All existing tests that use test_submodule_forced_switch()
		# require this.
		RESULT="failure"
	else
		RESULT="success"
	fi
	test_expect_$RESULT "$command: replace submodule with a directory must fail" '
		prolog &&
		reset_work_tree_to add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t replace_sub1_with_directory origin/replace_sub1_with_directory &&
			$command replace_sub1_with_directory test_must_fail &&
			test_superproject_content origin/add_sub1 &&
			test_submodule_content sub1 origin/add_sub1
		)
	'
	# ... especially when it contains a .shit directory.
	test_expect_$RESULT "$command: replace submodule containing a .shit directory with a directory must fail" '
		prolog &&
		reset_work_tree_to add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t replace_sub1_with_directory origin/replace_sub1_with_directory &&
			replace_shitfile_with_shit_dir sub1 &&
			$command replace_sub1_with_directory test_must_fail &&
			test_superproject_content origin/add_sub1 &&
			test_shit_directory_is_unchanged sub1 &&
			test_submodule_content sub1 origin/add_sub1
		)
	'
	# Replacing it with a file must fail as it could throw away any local
	# work tree changes ...
	test_expect_failure "$command: replace submodule with a file must fail" '
		prolog &&
		reset_work_tree_to add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t replace_sub1_with_file origin/replace_sub1_with_file &&
			$command replace_sub1_with_file test_must_fail &&
			test_superproject_content origin/add_sub1 &&
			test_submodule_content sub1 origin/add_sub1
		)
	'
	# ... or even destroy undefecateed parts of submodule history if that
	# still uses a .shit directory.
	test_expect_failure "$command: replace submodule containing a .shit directory with a file must fail" '
		prolog &&
		reset_work_tree_to add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t replace_sub1_with_file origin/replace_sub1_with_file &&
			replace_shitfile_with_shit_dir sub1 &&
			$command replace_sub1_with_file test_must_fail &&
			test_superproject_content origin/add_sub1 &&
			test_shit_directory_is_unchanged sub1 &&
			test_submodule_content sub1 origin/add_sub1
		)
	'

	########################## Modified submodule #########################
	# Updating a submodule sha1 doesn't update the submodule's work tree
	if test "$KNOWN_FAILURE_CHERRY_PICK_SEES_EMPTY_COMMIT" = 1
	then
		# When cherry picking a SHA-1 update for an ignored submodule
		# the commit incorrectly fails with "The previous cherry-pick
		# is now empty, possibly due to conflict resolution."
		RESULT="failure"
	else
		RESULT="success"
	fi
	test_expect_$RESULT "$command: modified submodule does not update submodule work tree" '
		prolog &&
		reset_work_tree_to add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t modify_sub1 origin/modify_sub1 &&
			$command modify_sub1 &&
			test_superproject_content origin/modify_sub1 &&
			test_submodule_content sub1 origin/add_sub1 &&
			shit submodule update &&
			test_submodule_content sub1 origin/modify_sub1
		)
	'
	# Updating a submodule to an invalid sha1 doesn't update the
	# submodule's work tree, subsequent update will fail
	test_expect_$RESULT "$command: modified submodule does not update submodule work tree to invalid commit" '
		prolog &&
		reset_work_tree_to add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t invalid_sub1 origin/invalid_sub1 &&
			$command invalid_sub1 &&
			test_superproject_content origin/invalid_sub1 &&
			test_submodule_content sub1 origin/add_sub1 &&
			test_must_fail shit submodule update &&
			test_submodule_content sub1 origin/add_sub1
		)
	'
	# Updating a submodule from an invalid sha1 doesn't update the
	# submodule's work tree, subsequent update will succeed
	test_expect_$RESULT "$command: modified submodule does not update submodule work tree from invalid commit" '
		prolog &&
		reset_work_tree_to invalid_sub1 &&
		(
			cd submodule_update &&
			shit branch -t valid_sub1 origin/valid_sub1 &&
			$command valid_sub1 &&
			test_superproject_content origin/valid_sub1 &&
			test_dir_is_empty sub1 &&
			shit submodule update --init --recursive &&
			test_submodule_content sub1 origin/valid_sub1
		)
	'
}

# Declares and invokes several tests that, in various situations, checks that
# the provided transition function:
#  - succeeds in updating the worktree and index of a superproject to a target
#    commit, or fails atomically (depending on the test situation)
#  - if succeeds, the contents of submodule directories are unchanged
#  - if succeeds, once "shit submodule update" is invoked, the contents of
#    submodule directories are updated
#
# If the command under test is known to not work with submodules in certain
# conditions, set the appropriate KNOWN_FAILURE_* variable used in the tests
# below to 1.
#
# The first argument of the callback function will be the name of the submodule.
#
# Removing a submodule containing a .shit directory must fail even when forced
# to protect the history! If we are testing this case, the second argument of
# the callback function will be 'test_must_fail', else it will be the empty
# string.
#
# The following example uses `shit some-command` as an example command to be
# tested. It updates the worktree and index to match a target, but not any
# submodule directories.
#
# my_func () {
#   ...prepare for `shit some-command` to be run...
#   $2 shit some-command "$1" &&
#   if test -n "$2"
#   then
#     return
#   fi &&
#   ...check the state after shit some-command is run...
# }
# test_submodule_switch_func "my_func"
test_submodule_switch_func () {
	command="$1"
	test_submodule_switch_common "$command"

	# An empty directory does not prevent the creation of a submodule of
	# the same name, but a file does.
	test_expect_success "$command: added submodule doesn't remove untracked unignored file with same name" '
		prolog &&
		reset_work_tree_to no_submodule &&
		(
			cd submodule_update &&
			shit branch -t add_sub1 origin/add_sub1 &&
			>sub1 &&
			$command add_sub1 test_must_fail &&
			test_superproject_content origin/no_submodule &&
			test_must_be_empty sub1
		)
	'
}

# Ensures that the that the arg either contains "test_must_fail" or is empty.
may_only_be_test_must_fail () {
	test -z "$1" || test "$1" = test_must_fail || die
}

shit_test_func () {
	may_only_be_test_must_fail "$2" &&
	$2 shit $shitcmd "$1"
}

test_submodule_switch () {
	shitcmd="$1"
	test_submodule_switch_func "shit_test_func"
}

# Same as test_submodule_switch(), except that throwing away local changes in
# the superproject is allowed.
test_submodule_forced_switch () {
	shitcmd="$1"
	command="shit_test_func"
	KNOWN_FAILURE_FORCED_SWITCH_TESTS=1
	test_submodule_switch_common "$command"

	# When forced, a file in the superproject does not prevent creating a
	# submodule of the same name.
	test_expect_success "$command: added submodule does remove untracked unignored file with same name when forced" '
		prolog &&
		reset_work_tree_to no_submodule &&
		(
			cd submodule_update &&
			shit branch -t add_sub1 origin/add_sub1 &&
			>sub1 &&
			$command add_sub1 &&
			test_superproject_content origin/add_sub1 &&
			test_dir_is_empty sub1
		)
	'
}

# Test that submodule contents are correctly updated when switching
# between commits that change a submodule.
# Test that the following transitions are correctly handled:
# (These tests are also above in the case where we expect no change
#  in the submodule)
# - Updated submodule
# - New submodule
# - Removed submodule
# - Directory containing tracked files replaced by submodule
# - Submodule replaced by tracked files in directory
# - Submodule replaced by tracked file with the same name
# - Tracked file replaced by submodule
#
# New test cases
# - Removing a submodule with a shit directory absorbs the submodules
#   shit directory first into the superproject.
# - Switching from no submodule to nested submodules
# - Switching from nested submodules to no submodule

# Internal function; use test_submodule_switch_recursing_with_args() or
# test_submodule_forced_switch_recursing_with_args() instead.
test_submodule_recursing_with_args_common () {
	command="$1 --recurse-submodules"

	######################### Appearing submodule #########################
	# Switching to a commit letting a submodule appear checks it out ...
	test_expect_success "$command: added submodule is checked out" '
		prolog &&
		reset_work_tree_to_interested no_submodule &&
		(
			cd submodule_update &&
			shit branch -t add_sub1 origin/add_sub1 &&
			$command add_sub1 &&
			test_superproject_content origin/add_sub1 &&
			test_submodule_content sub1 origin/add_sub1
		)
	'
	# ... ignoring an empty existing directory.
	test_expect_success "$command: added submodule is checked out in empty dir" '
		prolog &&
		reset_work_tree_to_interested no_submodule &&
		(
			cd submodule_update &&
			mkdir sub1 &&
			shit branch -t add_sub1 origin/add_sub1 &&
			$command add_sub1 &&
			test_superproject_content origin/add_sub1 &&
			test_submodule_content sub1 origin/add_sub1
		)
	'

	# Replacing a tracked file with a submodule produces a checked out submodule
	test_expect_success "$command: replace tracked file with submodule checks out submodule" '
		prolog &&
		reset_work_tree_to_interested replace_sub1_with_file &&
		(
			cd submodule_update &&
			shit branch -t replace_file_with_sub1 origin/replace_file_with_sub1 &&
			$command replace_file_with_sub1 &&
			test_superproject_content origin/replace_file_with_sub1 &&
			test_submodule_content sub1 origin/replace_file_with_sub1
		)
	'
	# ... as does removing a directory with tracked files with a submodule.
	test_expect_success "$command: replace directory with submodule" '
		prolog &&
		reset_work_tree_to_interested replace_sub1_with_directory &&
		(
			cd submodule_update &&
			shit branch -t replace_directory_with_sub1 origin/replace_directory_with_sub1 &&
			$command replace_directory_with_sub1 &&
			test_superproject_content origin/replace_directory_with_sub1 &&
			test_submodule_content sub1 origin/replace_directory_with_sub1
		)
	'
	# Switching to a commit with nested submodules recursively checks them out
	test_expect_success "$command: nested submodules are checked out" '
		prolog &&
		reset_work_tree_to_interested no_submodule &&
		(
			cd submodule_update &&
			shit branch -t modify_sub1_recursively origin/modify_sub1_recursively &&
			$command modify_sub1_recursively &&
			test_superproject_content origin/modify_sub1_recursively &&
			test_submodule_content sub1 origin/modify_sub1_recursively &&
			test_submodule_content -C sub1 sub2 origin/modify_sub1_recursively
		)
	'

	######################## Disappearing submodule #######################
	# Removing a submodule removes its work tree ...
	test_expect_success "$command: removed submodule removes submodules working tree" '
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t remove_sub1 origin/remove_sub1 &&
			$command remove_sub1 &&
			test_superproject_content origin/remove_sub1 &&
			! test -e sub1 &&
			test_must_fail shit config -f .shit/modules/sub1/config core.worktree
		)
	'
	# ... absorbing a .shit directory along the way.
	test_expect_success "$command: removed submodule absorbs submodules .shit directory" '
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t remove_sub1 origin/remove_sub1 &&
			replace_shitfile_with_shit_dir sub1 &&
			rm -rf .shit/modules &&
			$command remove_sub1 &&
			test_superproject_content origin/remove_sub1 &&
			! test -e sub1 &&
			test_shit_directory_exists sub1
		)
	'

	# Replacing it with a file ...
	test_expect_success "$command: replace submodule with a file" '
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t replace_sub1_with_file origin/replace_sub1_with_file &&
			$command replace_sub1_with_file &&
			test_superproject_content origin/replace_sub1_with_file &&
			test -f sub1
		)
	'
	RESULTDS=success
	if test "$KNOWN_FAILURE_DIRECTORY_SUBMODULE_CONFLICTS" = 1
	then
		RESULTDS=failure
	fi
	# ... must check its local work tree for untracked files
	test_expect_$RESULTDS "$command: replace submodule with a file must fail with untracked files" '
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t replace_sub1_with_file origin/replace_sub1_with_file &&
			: >sub1/untrackedfile &&
			test_must_fail $command replace_sub1_with_file &&
			test_superproject_content origin/add_sub1 &&
			test_submodule_content sub1 origin/add_sub1 &&
			test -f sub1/untracked_file
		)
	'

	# Switching to a commit without nested submodules removes their worktrees
	test_expect_success "$command: worktrees of nested submodules are removed" '
		prolog &&
		reset_work_tree_to_interested add_nested_sub &&
		(
			cd submodule_update &&
			shit branch -t no_submodule origin/no_submodule &&
			$command no_submodule &&
			test_superproject_content origin/no_submodule &&
			test_path_is_missing sub1 &&
			test_must_fail shit config -f .shit/modules/sub1/config core.worktree &&
			test_must_fail shit config -f .shit/modules/sub1/modules/sub2/config core.worktree
		)
	'

	########################## Modified submodule #########################
	# Updating a submodule sha1 updates the submodule's work tree
	test_expect_success "$command: modified submodule updates submodule work tree" '
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t modify_sub1 origin/modify_sub1 &&
			$command modify_sub1 &&
			test_superproject_content origin/modify_sub1 &&
			test_submodule_content sub1 origin/modify_sub1
		)
	'
	# Updating a submodule to an invalid sha1 doesn't update the
	# superproject nor the submodule's work tree.
	test_expect_success "$command: updating to a missing submodule commit fails" '
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t invalid_sub1 origin/invalid_sub1 &&
			test_must_fail $command invalid_sub1 2>err &&
			test_grep sub1 err &&
			test_superproject_content origin/add_sub1 &&
			test_submodule_content sub1 origin/add_sub1
		)
	'
	# Updating a submodule does not touch the currently checked out branch in the submodule
	test_expect_success "$command: submodule branch is not changed, detach HEAD instead" '
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			shit -C sub1 checkout -b keep_branch &&
			shit -C sub1 rev-parse HEAD >expect &&
			shit branch -t modify_sub1 origin/modify_sub1 &&
			$command modify_sub1 &&
			test_superproject_content origin/modify_sub1 &&
			test_submodule_content sub1 origin/modify_sub1 &&
			shit -C sub1 rev-parse keep_branch >actual &&
			test_cmp expect actual &&
			test_must_fail shit -C sub1 symbolic-ref HEAD
		)
	'
}

# Declares and invokes several tests that, in various situations, checks that
# the provided shit command, when invoked with --recurse-submodules:
#  - succeeds in updating the worktree and index of a superproject to a target
#    commit, or fails atomically (depending on the test situation)
#  - if succeeds, the contents of submodule directories are updated
#
# Specify the shit command so that "shit $shit_COMMAND --recurse-submodules"
# works.
#
# If the command under test is known to not work with submodules in certain
# conditions, set the appropriate KNOWN_FAILURE_* variable used in the tests
# below to 1.
#
# Use as follows:
#
# test_submodule_switch_recursing_with_args "$shit_COMMAND"
test_submodule_switch_recursing_with_args () {
	cmd_args="$1"
	command="shit $cmd_args"
	test_submodule_recursing_with_args_common "$command"

	RESULTDS=success
	if test "$KNOWN_FAILURE_DIRECTORY_SUBMODULE_CONFLICTS" = 1
	then
		RESULTDS=failure
	fi
	RESULTOI=success
	if test "$KNOWN_FAILURE_SUBMODULE_OVERWRITE_IGNORED_UNTRACKED" = 1
	then
		RESULTOI=failure
	fi
	# Switching to a commit letting a submodule appear cannot override an
	# untracked file.
	test_expect_success "$command: added submodule doesn't remove untracked file with same name" '
		prolog &&
		reset_work_tree_to_interested no_submodule &&
		(
			cd submodule_update &&
			shit branch -t add_sub1 origin/add_sub1 &&
			: >sub1 &&
			test_must_fail $command add_sub1 &&
			test_superproject_content origin/no_submodule &&
			test_must_be_empty sub1
		)
	'
	# ... but an ignored file is fine.
	test_expect_$RESULTOI "$command: added submodule removes an untracked ignored file" '
		test_when_finished "rm -rf submodule_update/.shit/info" &&
		prolog &&
		reset_work_tree_to_interested no_submodule &&
		(
			cd submodule_update &&
			shit branch -t add_sub1 origin/add_sub1 &&
			: >sub1 &&
			mkdir .shit/info &&
			echo sub1 >.shit/info/exclude &&
			$command add_sub1 &&
			test_superproject_content origin/add_sub1 &&
			test_submodule_content sub1 origin/add_sub1
		)
	'

	# Replacing a submodule with files in a directory must succeeds
	# when the submodule is clean
	test_expect_$RESULTDS "$command: replace submodule with a directory" '
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t replace_sub1_with_directory origin/replace_sub1_with_directory &&
			$command replace_sub1_with_directory &&
			test_superproject_content origin/replace_sub1_with_directory &&
			test_submodule_content sub1 origin/replace_sub1_with_directory
		)
	'
	# ... absorbing a .shit directory.
	test_expect_$RESULTDS "$command: replace submodule containing a .shit directory with a directory must absorb the shit dir" '
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t replace_sub1_with_directory origin/replace_sub1_with_directory &&
			replace_shitfile_with_shit_dir sub1 &&
			rm -rf .shit/modules &&
			$command replace_sub1_with_directory &&
			test_superproject_content origin/replace_sub1_with_directory &&
			test_shit_directory_exists sub1
		)
	'

	# ... and ignored files are ignored
	test_expect_success "$command: replace submodule with a file works ignores ignored files in submodule" '
		test_when_finished "rm submodule_update/.shit/modules/sub1/info/exclude" &&
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			rm -rf .shit/modules/sub1/info &&
			shit branch -t replace_sub1_with_file origin/replace_sub1_with_file &&
			mkdir .shit/modules/sub1/info &&
			echo ignored >.shit/modules/sub1/info/exclude &&
			: >sub1/ignored &&
			$command replace_sub1_with_file &&
			test_superproject_content origin/replace_sub1_with_file &&
			test -f sub1
		)
	'

	test_expect_success "shit -c submodule.recurse=true $cmd_args: modified submodule updates submodule work tree" '
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t modify_sub1 origin/modify_sub1 &&
			shit -c submodule.recurse=true $cmd_args modify_sub1 &&
			test_superproject_content origin/modify_sub1 &&
			test_submodule_content sub1 origin/modify_sub1
		)
	'

	test_expect_success "$command: modified submodule updates submodule recursively" '
		prolog &&
		reset_work_tree_to_interested add_nested_sub &&
		(
			cd submodule_update &&
			shit branch -t modify_sub1_recursively origin/modify_sub1_recursively &&
			$command modify_sub1_recursively &&
			test_superproject_content origin/modify_sub1_recursively &&
			test_submodule_content sub1 origin/modify_sub1_recursively &&
			test_submodule_content -C sub1 sub2 origin/modify_sub1_recursively
		)
	'
}

# Same as test_submodule_switch_recursing_with_args(), except that throwing
# away local changes in the superproject is allowed.
test_submodule_forced_switch_recursing_with_args () {
	cmd_args="$1"
	command="shit $cmd_args"
	test_submodule_recursing_with_args_common "$command"

	RESULT=success
	if test "$KNOWN_FAILURE_DIRECTORY_SUBMODULE_CONFLICTS" = 1
	then
		RESULT=failure
	fi
	# Switching to a commit letting a submodule appear does not care about
	# an untracked file.
	test_expect_success "$command: added submodule does remove untracked unignored file with same name when forced" '
		prolog &&
		reset_work_tree_to_interested no_submodule &&
		(
			cd submodule_update &&
			shit branch -t add_sub1 origin/add_sub1 &&
			>sub1 &&
			$command add_sub1 &&
			test_superproject_content origin/add_sub1 &&
			test_submodule_content sub1 origin/add_sub1
		)
	'

	# Replacing a submodule with files in a directory ...
	test_expect_success "$command: replace submodule with a directory" '
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t replace_sub1_with_directory origin/replace_sub1_with_directory &&
			$command replace_sub1_with_directory &&
			test_superproject_content origin/replace_sub1_with_directory
		)
	'
	# ... absorbing a .shit directory.
	test_expect_success "$command: replace submodule containing a .shit directory with a directory must fail" '
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t replace_sub1_with_directory origin/replace_sub1_with_directory &&
			replace_shitfile_with_shit_dir sub1 &&
			rm -rf .shit/modules/sub1 &&
			$command replace_sub1_with_directory &&
			test_superproject_content origin/replace_sub1_with_directory &&
			test_shit_directory_exists sub1
		)
	'

	# ... even if the submodule contains ignored files
	test_expect_success "$command: replace submodule with a file ignoring ignored files" '
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t replace_sub1_with_file origin/replace_sub1_with_file &&
			: >sub1/expect &&
			$command replace_sub1_with_file &&
			test_superproject_content origin/replace_sub1_with_file
		)
	'

	# Updating a submodule from an invalid sha1 updates
	test_expect_success "$command: modified submodule does update submodule work tree from invalid commit" '
		prolog &&
		reset_work_tree_to_interested invalid_sub1 &&
		(
			cd submodule_update &&
			shit branch -t valid_sub1 origin/valid_sub1 &&
			$command valid_sub1 &&
			test_superproject_content origin/valid_sub1 &&
			test_submodule_content sub1 origin/valid_sub1
		)
	'

	# Old versions of shit were buggy writing the .shit link file
	# (e.g. before f8eaa0ba98b and then moving the superproject repo
	# whose submodules contained absolute paths)
	test_expect_success "$command: updating submodules fixes .shit links" '
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			shit branch -t modify_sub1 origin/modify_sub1 &&
			echo "shitdir: bogus/path" >sub1/.shit &&
			$command modify_sub1 &&
			test_superproject_content origin/modify_sub1 &&
			test_submodule_content sub1 origin/modify_sub1
		)
	'

	test_expect_success "$command: changed submodule worktree is reset" '
		prolog &&
		reset_work_tree_to_interested add_sub1 &&
		(
			cd submodule_update &&
			rm sub1/file1 &&
			: >sub1/new_file &&
			shit -C sub1 add new_file &&
			$command HEAD &&
			test_path_is_file sub1/file1 &&
			test_path_is_missing sub1/new_file
		)
	'
}
