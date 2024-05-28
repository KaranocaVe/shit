#!/bin/sh

test_description='merging with submodules'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

shit_TEST_FATAL_REGISTER_SUBMODULE_ODB=1
export shit_TEST_FATAL_REGISTER_SUBMODULE_ODB

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-merge.sh

#
# history
#
#        a --- c
#      /   \ /
# root      X
#      \   / \
#        b --- d
#

test_expect_success setup '

	mkdir sub &&
	(cd sub &&
	 shit init &&
	 echo original > file &&
	 shit add file &&
	 test_tick &&
	 shit commit -m sub-root) &&
	shit add sub &&
	test_tick &&
	shit commit -m root &&

	shit checkout -b a main &&
	(cd sub &&
	 echo A > file &&
	 shit add file &&
	 test_tick &&
	 shit commit -m sub-a) &&
	shit add sub &&
	test_tick &&
	shit commit -m a &&

	shit checkout -b b main &&
	(cd sub &&
	 echo B > file &&
	 shit add file &&
	 test_tick &&
	 shit commit -m sub-b) &&
	shit add sub &&
	test_tick &&
	shit commit -m b &&

	shit checkout -b c a &&
	shit merge -s ours b &&

	shit checkout -b d b &&
	shit merge -s ours a
'

# History setup
#
#             b
#           /   \
#  init -- a     d
#    \      \   /
#     g       c
#
# a in the main repository records to sub-a in the submodule and
# analogous b and c. d should be automatically found by merging c into
# b in the main repository.
test_expect_success 'setup for merge search' '
	mkdir merge-search &&
	(cd merge-search &&
	shit init &&
	mkdir sub &&
	(cd sub &&
	 shit init &&
	 echo "file-a" > file-a &&
	 shit add file-a &&
	 shit commit -m "sub-a" &&
	 shit branch sub-a) &&
	shit commit --allow-empty -m init &&
	shit branch init &&
	shit add sub &&
	shit commit -m "a" &&
	shit branch a &&

	shit checkout -b b &&
	(cd sub &&
	 shit checkout -b sub-b &&
	 echo "file-b" > file-b &&
	 shit add file-b &&
	 shit commit -m "sub-b") &&
	shit commit -a -m "b" &&

	shit checkout -b c a &&
	(cd sub &&
	 shit checkout -b sub-c sub-a &&
	 echo "file-c" > file-c &&
	 shit add file-c &&
	 shit commit -m "sub-c") &&
	shit commit -a -m "c")
'

test_expect_success 'merging should conflict for non fast-forward' '
	test_when_finished "shit -C merge-search reset --hard" &&
	(cd merge-search &&
	 shit checkout -b test-nonforward-a b &&
	  if test "$shit_TEST_MERGE_ALGORITHM" = ort
	  then
		test_must_fail shit merge c 2>actual &&
		sub_expect="go to submodule (sub), and either merge commit $(shit -C sub rev-parse --short sub-c)" &&
		grep "$sub_expect" actual
	  else
		test_must_fail shit merge c 2> actual
	  fi)
'

test_expect_success 'finish setup for merge-search' '
	(cd merge-search &&
	shit checkout -b d a &&
	(cd sub &&
	 shit checkout -b sub-d sub-b &&
	 shit merge sub-c) &&
	shit commit -a -m "d" &&
	shit branch test b &&

	shit checkout -b g init &&
	(cd sub &&
	 shit checkout -b sub-g sub-c) &&
	shit add sub &&
	shit commit -a -m "g")
'

test_expect_success 'merge with one side as a fast-forward of the other' '
	(cd merge-search &&
	 shit checkout -b test-forward b &&
	 shit merge d &&
	 shit ls-tree test-forward sub | cut -f1 | cut -f3 -d" " > actual &&
	 (cd sub &&
	  shit rev-parse sub-d > ../expect) &&
	 test_cmp expect actual)
'

test_expect_success 'merging should conflict for non fast-forward (resolution exists)' '
	(cd merge-search &&
	 shit checkout -b test-nonforward-b b &&
	 (cd sub &&
	  shit rev-parse --short sub-d > ../expect) &&
	  if test "$shit_TEST_MERGE_ALGORITHM" = ort
	  then
		test_must_fail shit merge c >actual 2>sub-actual &&
		sub_expect="go to submodule (sub), and either merge commit $(shit -C sub rev-parse --short sub-c)" &&
		grep "$sub_expect" sub-actual
	  else
		test_must_fail shit merge c 2> actual
	  fi &&
	 grep $(cat expect) actual > /dev/null &&
	 shit reset --hard)
'

test_expect_success 'merging should fail for ambiguous common parent' '
	(cd merge-search &&
	shit checkout -b test-ambiguous b &&
	(cd sub &&
	 shit checkout -b ambiguous sub-b &&
	 shit merge sub-c &&
	 if test "$shit_TEST_MERGE_ALGORITHM" = ort
	 then
		shit rev-parse --short sub-d >../expect1 &&
		shit rev-parse --short ambiguous >../expect2
	 else
		shit rev-parse sub-d > ../expect1 &&
		shit rev-parse ambiguous > ../expect2
	 fi
	 ) &&
	 if test "$shit_TEST_MERGE_ALGORITHM" = ort
	 then
		test_must_fail shit merge c >actual 2>sub-actual &&
		sub_expect="go to submodule (sub), and either merge commit $(shit -C sub rev-parse --short sub-c)" &&
		grep "$sub_expect" sub-actual
	 else
		test_must_fail shit merge c 2> actual
	 fi &&
	grep $(cat expect1) actual > /dev/null &&
	grep $(cat expect2) actual > /dev/null &&
	shit reset --hard)
'

# in a situation like this
#
# submodule tree:
#
#    sub-a --- sub-b --- sub-d
#
# main tree:
#
#    e (sub-a)
#   /
#  bb (sub-b)
#   \
#    f (sub-d)
#
# A merge between e and f should fail because one of the submodule
# commits (sub-a) does not descend from the submodule merge-base (sub-b).
#
test_expect_success 'merging should fail for changes that are backwards' '
	(cd merge-search &&
	shit checkout -b bb a &&
	(cd sub &&
	 shit checkout sub-b) &&
	shit commit -a -m "bb" &&

	shit checkout -b e bb &&
	(cd sub &&
	 shit checkout sub-a) &&
	shit commit -a -m "e" &&

	shit checkout -b f bb &&
	(cd sub &&
	 shit checkout sub-d) &&
	shit commit -a -m "f" &&

	shit checkout -b test-backward e &&
	test_must_fail shit merge f 2>actual &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
    then
		sub_expect="go to submodule (sub), and either merge commit $(shit -C sub rev-parse --short sub-d)" &&
		grep "$sub_expect" actual
	fi)
'


# Check that the conflicting submodule is detected when it is
# in the common ancestor. status should be 'U00...00"
test_expect_success 'shit submodule status should display the merge conflict properly with merge base' '
       (cd merge-search &&
       cat >.shitmodules <<EOF &&
[submodule "sub"]
       path = sub
       url = $TRASH_DIRECTORY/sub
EOF
       cat >expect <<EOF &&
U$ZERO_OID sub
EOF
       shit submodule status > actual &&
       test_cmp expect actual &&
	shit reset --hard)
'

# Check that the conflicting submodule is detected when it is
# not in the common ancestor. status should be 'U00...00"
test_expect_success 'shit submodule status should display the merge conflict properly without merge-base' '
       (cd merge-search &&
	shit checkout -b test-no-merge-base g &&
	test_must_fail shit merge b &&
       cat >.shitmodules <<EOF &&
[submodule "sub"]
       path = sub
       url = $TRASH_DIRECTORY/sub
EOF
       cat >expect <<EOF &&
U$ZERO_OID sub
EOF
       shit submodule status > actual &&
       test_cmp expect actual &&
       shit reset --hard)
'


test_expect_success 'merging with a modify/modify conflict between merge bases' '
	shit reset --hard HEAD &&
	shit checkout -b test2 c &&
	shit merge d
'

# canonical criss-cross history in top and submodule
test_expect_success 'setup for recursive merge with submodule' '
	mkdir merge-recursive &&
	(cd merge-recursive &&
	 shit init &&
	 mkdir sub &&
	 (cd sub &&
	  shit init &&
	  test_commit a &&
	  shit checkout -b sub-b main &&
	  test_commit b &&
	  shit checkout -b sub-c main &&
	  test_commit c &&
	  shit checkout -b sub-bc sub-b &&
	  shit merge sub-c &&
	  shit checkout -b sub-cb sub-c &&
	  shit merge sub-b &&
	  shit checkout main) &&
	 shit add sub &&
	 shit commit -m a &&
	 shit checkout -b top-b main &&
	 (cd sub && shit checkout sub-b) &&
	 shit add sub &&
	 shit commit -m b &&
	 shit checkout -b top-c main &&
	 (cd sub && shit checkout sub-c) &&
	 shit add sub &&
	 shit commit -m c &&
	 shit checkout -b top-bc top-b &&
	 shit merge -s ours --no-commit top-c &&
	 (cd sub && shit checkout sub-bc) &&
	 shit add sub &&
	 shit commit -m bc &&
	 shit checkout -b top-cb top-c &&
	 shit merge -s ours --no-commit top-b &&
	 (cd sub && shit checkout sub-cb) &&
	 shit add sub &&
	 shit commit -m cb)
'

# merge should leave submodule unmerged in index
test_expect_success 'recursive merge with submodule' '
	(cd merge-recursive &&
	 test_must_fail shit merge top-bc &&
	 echo "160000 $(shit rev-parse top-cb:sub) 2	sub" > expect2 &&
	 echo "160000 $(shit rev-parse top-bc:sub) 3	sub" > expect3 &&
	 shit ls-files -u > actual &&
	 grep "$(cat expect2)" actual > /dev/null &&
	 grep "$(cat expect3)" actual > /dev/null)
'

# File/submodule conflict
#   Commit O: <empty>
#   Commit A: path (submodule)
#   Commit B: path
#   Expected: path/ is submodule and file contents for B's path are somewhere

test_expect_success 'setup file/submodule conflict' '
	shit init file-submodule &&
	(
		cd file-submodule &&

		shit commit --allow-empty -m O &&

		shit branch A &&
		shit branch B &&

		shit checkout B &&
		echo content >path &&
		shit add path &&
		shit commit -m B &&

		shit checkout A &&
		shit init path &&
		test_commit -C path world &&
		shit submodule add ./path &&
		shit commit -m A
	)
'

test_expect_merge_algorithm failure success 'file/submodule conflict' '
	test_when_finished "shit -C file-submodule reset --hard" &&
	(
		cd file-submodule &&

		shit checkout A^0 &&
		test_must_fail shit merge B^0 &&

		shit ls-files -s >out &&
		test_line_count = 3 out &&
		shit ls-files -u >out &&
		test_line_count = 2 out &&

		# path/ is still a submodule
		test_path_is_dir path/.shit &&

		# There is a submodule at "path", so B:path cannot be written
		# there.  We expect it to be written somewhere in the same
		# directory, though, so just grep for its content in all
		# files, and ignore "grep: path: Is a directory" message
		echo Checking if contents from B:path showed up anywhere &&
		grep -q content * 2>/dev/null
	)
'

test_expect_success 'file/submodule conflict; merge --abort works afterward' '
	test_when_finished "shit -C file-submodule reset --hard" &&
	(
		cd file-submodule &&

		shit checkout A^0 &&
		test_must_fail shit merge B^0 >out 2>err &&

		test_path_is_file .shit/MERGE_HEAD &&
		shit merge --abort
	)
'

# Directory/submodule conflict
#   Commit O: <empty>
#   Commit A: path (submodule), with sole tracked file named 'world'
#   Commit B1: path/file
#   Commit B2: path/world
#
#   Expected from merge of A & B1:
#     Contents under path/ from commit B1 are renamed elsewhere; we do not
#     want to write files from one of our tracked directories into a submodule
#
#   Expected from merge of A & B2:
#     Similar to last merge, but with a slight twist: we don't want paths
#     under the submodule to be treated as untracked or in the way.

test_expect_success 'setup directory/submodule conflict' '
	shit init directory-submodule &&
	(
		cd directory-submodule &&

		shit commit --allow-empty -m O &&

		shit branch A &&
		shit branch B1 &&
		shit branch B2 &&

		shit checkout B1 &&
		mkdir path &&
		echo contents >path/file &&
		shit add path/file &&
		shit commit -m B1 &&

		shit checkout B2 &&
		mkdir path &&
		echo contents >path/world &&
		shit add path/world &&
		shit commit -m B2 &&

		shit checkout A &&
		shit init path &&
		test_commit -C path hello world &&
		shit submodule add ./path &&
		shit commit -m A
	)
'

test_expect_failure 'directory/submodule conflict; keep submodule clean' '
	test_when_finished "shit -C directory-submodule reset --hard" &&
	(
		cd directory-submodule &&

		shit checkout A^0 &&
		test_must_fail shit merge B1^0 &&

		shit ls-files -s >out &&
		test_line_count = 3 out &&
		shit ls-files -u >out &&
		test_line_count = 1 out &&

		# path/ is still a submodule
		test_path_is_dir path/.shit &&

		echo Checking if contents from B1:path/file showed up &&
		# Would rather use grep -r, but that is GNU extension...
		shit ls-files -co | xargs grep -q contents 2>/dev/null &&

		# However, B1:path/file should NOT have shown up at path/file,
		# because we should not write into the submodule
		test_path_is_missing path/file
	)
'

test_expect_merge_algorithm failure success !FAIL_PREREQS 'directory/submodule conflict; should not treat submodule files as untracked or in the way' '
	test_when_finished "shit -C directory-submodule/path reset --hard" &&
	test_when_finished "shit -C directory-submodule reset --hard" &&
	(
		cd directory-submodule &&

		shit checkout A^0 &&
		test_must_fail shit merge B2^0 >out 2>err &&

		# We do not want files within the submodule to prevent the
		# merge from starting; we should not be writing to such paths
		# anyway.
		test_grep ! "refusing to lose untracked file at" err
	)
'

test_expect_failure 'directory/submodule conflict; merge --abort works afterward' '
	test_when_finished "shit -C directory-submodule/path reset --hard" &&
	test_when_finished "shit -C directory-submodule reset --hard" &&
	(
		cd directory-submodule &&

		shit checkout A^0 &&
		test_must_fail shit merge B2^0 &&
		test_path_is_file .shit/MERGE_HEAD &&

		# merge --abort should succeed, should clear .shit/MERGE_HEAD,
		# and should not leave behind any conflicted files
		shit merge --abort &&
		test_path_is_missing .shit/MERGE_HEAD &&
		shit ls-files -u >conflicts &&
		test_must_be_empty conflicts
	)
'

# Setup:
#   - Submodule has 2 commits: a and b
#   - Superproject branch 'a' adds and commits submodule pointing to 'commit a'
#   - Superproject branch 'b' adds and commits submodule pointing to 'commit b'
# If these two branches are now merged, there is no merge base
test_expect_success 'setup for null merge base' '
	mkdir no-merge-base &&
	(cd no-merge-base &&
	shit init &&
	mkdir sub &&
	(cd sub &&
	 shit init &&
	 echo "file-a" > file-a &&
	 shit add file-a &&
	 shit commit -m "commit a") &&
	shit commit --allow-empty -m init &&
	shit branch init &&
	shit checkout -b a init &&
	shit add sub &&
	shit commit -m "a" &&
	shit switch main &&
	(cd sub &&
	 echo "file-b" > file-b &&
	 shit add file-b &&
	 shit commit -m "commit b"))
'

test_expect_success 'merging should fail with no merge base' '
	(cd no-merge-base &&
	shit checkout -b b init &&
	shit add sub &&
	shit commit -m "b" &&
	test_must_fail shit merge a 2>actual &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
    then
		sub_expect="go to submodule (sub), and either merge commit $(shit -C sub rev-parse --short HEAD^1)" &&
		grep "$sub_expect" actual
	fi)
'

test_done
