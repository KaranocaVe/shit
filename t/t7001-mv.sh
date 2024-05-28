#!/bin/sh

test_description='shit mv in subdirs'
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-diff-data.sh

index_at_path () {
	shit ls-files --format='%(objectmode) %(objectname) %(stage)' "$@"
}

test_expect_success 'mv -f refreshes updated index entry' '
	echo test >bar &&
	shit add bar &&
	shit commit -m test &&

	echo foo >foo &&
	shit add foo &&

	# Wait one second to ensure ctime of rename will differ from original
	# file creation ctime.
	sleep 1 &&
	shit mv -f foo bar &&
	shit reset --merge HEAD &&

	# Verify the index has been reset
	shit diff-files >out &&
	test_must_be_empty out
'

test_expect_success 'prepare reference tree' '
	mkdir path0 path1 &&
	COPYING_test_data >path0/COPYING &&
	shit add path0/COPYING &&
	shit commit -m add -a
'

test_expect_success 'moving the file out of subdirectory' '
	shit -C path0 mv COPYING ../path1/COPYING
'

# in path0 currently
test_expect_success 'commiting the change' '
	shit commit -m move-out -a
'

test_expect_success 'checking the commit' '
	shit diff-tree -r -M --name-status  HEAD^ HEAD >actual &&
	grep "^R100..*path0/COPYING..*path1/COPYING" actual
'

test_expect_success 'moving the file back into subdirectory' '
	shit -C path0 mv ../path1/COPYING COPYING
'

# in path0 currently
test_expect_success 'commiting the change' '
	shit commit -m move-in -a
'

test_expect_success 'checking the commit' '
	shit diff-tree -r -M --name-status  HEAD^ HEAD >actual &&
	grep "^R100..*path1/COPYING..*path0/COPYING" actual
'

test_expect_success 'mv --dry-run does not move file' '
	shit mv -n path0/COPYING MOVED &&
	test_path_is_file path0/COPYING &&
	test_path_is_missing MOVED
'

test_expect_success 'checking -k on non-existing file' '
	shit mv -k idontexist path0
'

test_expect_success 'checking -k on untracked file' '
	>untracked1 &&
	shit mv -k untracked1 path0 &&
	test_path_is_file untracked1 &&
	test_path_is_missing path0/untracked1
'

test_expect_success 'checking -k on multiple untracked files' '
	>untracked2 &&
	shit mv -k untracked1 untracked2 path0 &&
	test_path_is_file untracked1 &&
	test_path_is_file untracked2 &&
	test_path_is_missing path0/untracked1 &&
	test_path_is_missing path0/untracked2
'

test_expect_success 'checking -f on untracked file with existing target' '
	>path0/untracked1 &&
	test_must_fail shit mv -f untracked1 path0 &&
	test_path_is_missing .shit/index.lock &&
	test_path_is_file untracked1 &&
	test_path_is_file path0/untracked1
'

# clean up the mess in case bad things happen
rm -f idontexist untracked1 untracked2 \
     path0/idontexist path0/untracked1 path0/untracked2 \
     .shit/index.lock
rmdir path1

test_expect_success 'moving to absent target with trailing slash' '
	test_must_fail shit mv path0/COPYING no-such-dir/ &&
	test_must_fail shit mv path0/COPYING no-such-dir// &&
	shit mv path0/ no-such-dir/ &&
	test_path_is_dir no-such-dir
'

test_expect_success 'clean up' '
	shit reset --hard
'

test_expect_success 'moving to existing untracked target with trailing slash' '
	mkdir path1 &&
	shit mv path0/ path1/ &&
	test_path_is_dir path1/path0/
'

test_expect_success 'moving to existing tracked target with trailing slash' '
	mkdir path2 &&
	>path2/file && shit add path2/file &&
	shit mv path1/path0/ path2/ &&
	test_path_is_dir path2/path0/
'

test_expect_success 'clean up' '
	shit reset --hard
'

test_expect_success 'adding another file' '
	COPYING_test_data | tr A-Za-z N-ZA-Mn-za-m >path0/README &&
	shit add path0/README &&
	shit commit -m add2 -a
'

test_expect_success 'moving whole subdirectory' '
	shit mv path0 path2
'

test_expect_success 'commiting the change' '
	shit commit -m dir-move -a
'

test_expect_success 'checking the commit' '
	shit diff-tree -r -M --name-status  HEAD^ HEAD >actual &&
	grep "^R100..*path0/COPYING..*path2/COPYING" actual &&
	grep "^R100..*path0/README..*path2/README" actual
'

test_expect_success 'succeed when source is a prefix of destination' '
	shit mv path2/COPYING path2/COPYING-renamed
'

test_expect_success 'moving whole subdirectory into subdirectory' '
	shit mv path2 path1
'

test_expect_success 'commiting the change' '
	shit commit -m dir-move -a
'

test_expect_success 'checking the commit' '
	shit diff-tree -r -M --name-status  HEAD^ HEAD >actual &&
	grep "^R100..*path2/COPYING..*path1/path2/COPYING" actual &&
	grep "^R100..*path2/README..*path1/path2/README" actual
'

test_expect_success 'do not move directory over existing directory' '
	mkdir path0 &&
	mkdir path0/path2 &&
	test_must_fail shit mv path2 path0
'

test_expect_success 'rename directory to non-existing directory' '
	mkdir dir-a &&
	>dir-a/f &&
	shit add dir-a &&
	shit mv dir-a non-existing-dir
'

test_expect_success 'move into "."' '
	shit mv path1/path2/ .
'

test_expect_success "Michael Cassar's test case" '
	rm -fr .shit papers partA &&
	shit init &&
	mkdir -p papers/unsorted papers/all-papers partA &&
	echo a >papers/unsorted/Thesis.pdf &&
	echo b >partA/outline.txt &&
	echo c >papers/unsorted/_another &&
	shit add papers partA &&
	T1=$(shit write-tree) &&

	shit mv papers/unsorted/Thesis.pdf papers/all-papers/moo-blah.pdf &&

	T=$(shit write-tree) &&
	shit ls-tree -r $T >out &&
	grep partA/outline.txt out
'

rm -fr papers partA path?

test_expect_success "Sergey Vlasov's test case" '
	rm -fr .shit &&
	shit init &&
	mkdir ab &&
	date >ab.c &&
	date >ab/d &&
	shit add ab.c ab &&
	shit commit -m "initial" &&
	shit mv ab a
'

test_expect_success 'absolute pathname' '
	(
		rm -fr mine &&
		mkdir mine &&
		cd mine &&
		test_create_repo one &&
		cd one &&
		mkdir sub &&
		>sub/file &&
		shit add sub/file &&

		shit mv sub "$(pwd)/in" &&
		test_path_is_missing sub &&
		test_path_is_dir in &&
		shit ls-files --error-unmatch in/file
	)
'

test_expect_success 'absolute pathname outside should fail' '
	(
		rm -fr mine &&
		mkdir mine &&
		cd mine &&
		out=$(pwd) &&
		test_create_repo one &&
		cd one &&
		mkdir sub &&
		>sub/file &&
		shit add sub/file &&

		test_must_fail shit mv sub "$out/out" &&
		test_path_is_dir sub &&
		test_path_is_missing ../in &&
		shit ls-files --error-unmatch sub/file
	)
'

test_expect_success 'shit mv to move multiple sources into a directory' '
	rm -fr .shit && shit init &&
	mkdir dir other &&
	>dir/a.txt &&
	>dir/b.txt &&
	shit add dir/?.txt &&
	shit mv dir/a.txt dir/b.txt other &&
	shit ls-files >actual &&
	cat >expect <<-\EOF &&
	other/a.txt
	other/b.txt
	EOF
	test_cmp expect actual
'

test_expect_success 'shit mv should not change sha1 of moved cache entry' '
	rm -fr .shit &&
	shit init &&
	echo 1 >dirty &&
	shit add dirty &&
	entry="$(index_at_path dirty)" &&
	shit mv dirty dirty2 &&
	test "$entry" = "$(index_at_path dirty2)" &&
	echo 2 >dirty2 &&
	shit mv dirty2 dirty &&
	test "$entry" = "$(index_at_path dirty)"
'

rm -f dirty dirty2

# NB: This test is about the error message
# as well as the failure.
test_expect_success 'shit mv error on conflicted file' '
	rm -fr .shit &&
	shit init &&
	>conflict &&
	test_when_finished "rm -f conflict" &&
	cfhash=$(shit hash-object -w conflict) &&
	q_to_tab <<-EOF | shit update-index --index-info &&
	0 $cfhash 0Qconflict
	100644 $cfhash 1Qconflict
	EOF

	test_must_fail shit mv conflict newname 2>actual &&
	test_grep "conflicted" actual
'

test_expect_success 'shit mv should overwrite symlink to a file' '
	rm -fr .shit &&
	shit init &&
	echo 1 >moved &&
	test_ln_s_add moved symlink &&
	shit add moved &&
	test_must_fail shit mv moved symlink &&
	shit mv -f moved symlink &&
	test_path_is_missing moved &&
	test_path_is_file symlink &&
	test "$(cat symlink)" = 1 &&
	shit update-index --refresh &&
	shit diff-files --quiet
'

rm -f moved symlink

test_expect_success 'shit mv should overwrite file with a symlink' '
	rm -fr .shit &&
	shit init &&
	echo 1 >moved &&
	test_ln_s_add moved symlink &&
	shit add moved &&
	test_must_fail shit mv symlink moved &&
	shit mv -f symlink moved &&
	test_path_is_missing symlink &&
	shit update-index --refresh &&
	shit diff-files --quiet
'

test_expect_success SYMLINKS 'check moved symlink' '
	test_path_is_symlink moved
'

rm -f moved symlink

test_expect_success 'setup submodule' '
	test_config_global protocol.file.allow always &&
	shit commit -m initial &&
	shit reset --hard &&
	shit submodule add ./. sub &&
	echo content >file &&
	shit add file &&
	shit commit -m "added sub and file" &&
	mkdir -p deep/directory/hierarchy &&
	shit submodule add ./. deep/directory/hierarchy/sub &&
	shit commit -m "added another submodule" &&
	shit branch submodule
'

test_expect_success 'shit mv cannot move a submodule in a file' '
	test_must_fail shit mv sub file
'

test_expect_success 'shit mv moves a submodule with a .shit directory and no .shitmodules' '
	entry="$(index_at_path sub)" &&
	shit rm .shitmodules &&
	(
		cd sub &&
		rm -f .shit &&
		cp -R -P -p ../.shit/modules/sub .shit &&
		shit_WORK_TREE=. shit config --unset core.worktree
	) &&
	mkdir mod &&
	shit mv sub mod/sub &&
	test_path_is_missing sub &&
	test "$entry" = "$(index_at_path mod/sub)" &&
	shit -C mod/sub status &&
	shit update-index --refresh &&
	shit diff-files --quiet
'

test_expect_success 'shit mv moves a submodule with a .shit directory and .shitmodules' '
	rm -rf mod &&
	shit reset --hard &&
	shit submodule update &&
	entry="$(index_at_path sub)" &&
	(
		cd sub &&
		rm -f .shit &&
		cp -R -P -p ../.shit/modules/sub .shit &&
		shit_WORK_TREE=. shit config --unset core.worktree
	) &&
	mkdir mod &&
	shit mv sub mod/sub &&
	test_path_is_missing sub &&
	test "$entry" = "$(index_at_path mod/sub)" &&
	shit -C mod/sub status &&
	echo mod/sub >expected &&
	shit config -f .shitmodules submodule.sub.path >actual &&
	test_cmp expected actual &&
	shit update-index --refresh &&
	shit diff-files --quiet
'

test_expect_success 'shit mv moves a submodule with shitfile' '
	rm -rf mod &&
	shit reset --hard &&
	shit submodule update &&
	entry="$(index_at_path sub)" &&
	mkdir mod &&
	shit -C mod mv ../sub/ . &&
	test_path_is_missing sub &&
	test "$entry" = "$(index_at_path mod/sub)" &&
	shit -C mod/sub status &&
	echo mod/sub >expected &&
	shit config -f .shitmodules submodule.sub.path >actual &&
	test_cmp expected actual &&
	shit update-index --refresh &&
	shit diff-files --quiet
'

test_expect_success 'mv does not complain when no .shitmodules file is found' '
	rm -rf mod &&
	shit reset --hard &&
	shit submodule update &&
	shit rm .shitmodules &&
	entry="$(index_at_path sub)" &&
	mkdir mod &&
	shit mv sub mod/sub 2>actual.err &&
	test_must_be_empty actual.err &&
	test_path_is_missing sub &&
	test "$entry" = "$(index_at_path mod/sub)" &&
	shit -C mod/sub status &&
	shit update-index --refresh &&
	shit diff-files --quiet
'

test_expect_success 'mv will error out on a modified .shitmodules file unless staged' '
	rm -rf mod &&
	shit reset --hard &&
	shit submodule update &&
	shit config -f .shitmodules foo.bar true &&
	entry="$(index_at_path sub)" &&
	mkdir mod &&
	test_must_fail shit mv sub mod/sub 2>actual.err &&
	test_file_not_empty actual.err &&
	test_path_exists sub &&
	shit diff-files --quiet -- sub &&
	shit add .shitmodules &&
	shit mv sub mod/sub 2>actual.err &&
	test_must_be_empty actual.err &&
	test_path_is_missing sub &&
	test "$entry" = "$(index_at_path mod/sub)" &&
	shit -C mod/sub status &&
	shit update-index --refresh &&
	shit diff-files --quiet
'

test_expect_success 'mv issues a warning when section is not found in .shitmodules' '
	rm -rf mod &&
	shit reset --hard &&
	shit submodule update &&
	shit config -f .shitmodules --remove-section submodule.sub &&
	shit add .shitmodules &&
	entry="$(index_at_path sub)" &&
	echo "warning: Could not find section in .shitmodules where path=sub" >expect.err &&
	mkdir mod &&
	shit mv sub mod/sub 2>actual.err &&
	test_cmp expect.err actual.err &&
	test_path_is_missing sub &&
	test "$entry" = "$(index_at_path mod/sub)" &&
	shit -C mod/sub status &&
	shit update-index --refresh &&
	shit diff-files --quiet
'

test_expect_success 'mv --dry-run does not touch the submodule or .shitmodules' '
	rm -rf mod &&
	shit reset --hard &&
	shit submodule update &&
	mkdir mod &&
	shit mv -n sub mod/sub 2>actual.err &&
	test_path_is_file sub/.shit &&
	shit diff-index --exit-code HEAD &&
	shit update-index --refresh &&
	shit diff-files --quiet -- sub .shitmodules
'

test_expect_success 'checking out a commit before submodule moved needs manual updates' '
	shit mv sub sub2 &&
	shit commit -m "moved sub to sub2" &&
	shit checkout -q HEAD^ 2>actual &&
	test_grep "^warning: unable to rmdir '\''sub2'\'':" actual &&
	shit status -s sub2 >actual &&
	echo "?? sub2/" >expected &&
	test_cmp expected actual &&
	test_path_is_missing sub/.shit &&
	test_path_is_file sub2/.shit &&
	shit submodule update &&
	test_path_is_file sub/.shit &&
	rm -rf sub2 &&
	shit diff-index --exit-code HEAD &&
	shit update-index --refresh &&
	shit diff-files --quiet -- sub .shitmodules &&
	shit status -s sub2 >actual &&
	test_must_be_empty actual
'

test_expect_success 'mv -k does not accidentally destroy submodules' '
	shit checkout submodule &&
	mkdir dummy dest &&
	shit mv -k dummy sub dest &&
	shit status --porcelain >actual &&
	grep "^R  sub -> dest/sub" actual &&
	shit reset --hard &&
	shit checkout .
'

test_expect_success 'moving a submodule in nested directories' '
	(
		cd deep &&
		shit mv directory ../ &&
		# shit status would fail if the update of linking shit dir to
		# work dir of the submodule failed.
		shit status &&
		shit config -f ../.shitmodules submodule.deep/directory/hierarchy/sub.path >../actual &&
		echo "directory/hierarchy/sub" >../expect
	) &&
	test_cmp expect actual
'

test_expect_success 'moving nested submodules' '
	test_config_global protocol.file.allow always &&
	shit commit -am "cleanup commit" &&
	mkdir sub_nested_nested &&
	(
		cd sub_nested_nested &&
		>nested_level2 &&
		shit init &&
		shit add . &&
		shit commit -m "nested level 2"
	) &&
	mkdir sub_nested &&
	(
		cd sub_nested &&
		>nested_level1 &&
		shit init &&
		shit add . &&
		shit commit -m "nested level 1" &&
		shit submodule add ../sub_nested_nested &&
		shit commit -m "add nested level 2"
	) &&
	shit submodule add ./sub_nested nested_move &&
	shit commit -m "add nested_move" &&
	shit submodule update --init --recursive &&
	shit mv nested_move sub_nested_moved &&
	shit status
'

test_done
