#!/bin/sh
#
# Copyright (c) 2008 Charles Bailey
#

test_description='shit mergetool

Testing basic merge tool invocation'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

# All the mergetool test work by checking out a temporary branch based
# off 'branch1' and then merging in main and checking the results of
# running mergetool

test_expect_success 'setup' '
	test_config rerere.enabled true &&
	echo main >file1 &&
	echo main spaced >"spaced name" &&
	echo main file11 >file11 &&
	echo main file12 >file12 &&
	echo main file13 >file13 &&
	echo main file14 >file14 &&
	mkdir subdir &&
	echo main sub >subdir/file3 &&
	test_create_repo submod &&
	(
		cd submod &&
		: >foo &&
		shit add foo &&
		shit commit -m "Add foo"
	) &&
	shit submodule add file:///dev/null submod &&
	shit add file1 "spaced name" file1[1-4] subdir/file3 .shitmodules submod &&
	shit commit -m "add initial versions" &&

	shit checkout -b branch1 main &&
	shit submodule update -N &&
	echo branch1 change >file1 &&
	echo branch1 newfile >file2 &&
	echo branch1 spaced >"spaced name" &&
	echo branch1 both added >both &&
	echo branch1 change file11 >file11 &&
	echo branch1 change file13 >file13 &&
	echo branch1 sub >subdir/file3 &&
	(
		cd submod &&
		echo branch1 submodule >bar &&
		shit add bar &&
		shit commit -m "Add bar on branch1" &&
		shit checkout -b submod-branch1
	) &&
	shit add file1 "spaced name" file11 file13 file2 subdir/file3 submod &&
	shit add both &&
	shit rm file12 &&
	shit commit -m "branch1 changes" &&

	shit checkout -b delete-base branch1 &&
	mkdir -p a/a &&
	test_write_lines one two 3 4 >a/a/file.txt &&
	shit add a/a/file.txt &&
	shit commit -m"base file" &&
	shit checkout -b move-to-b delete-base &&
	mkdir -p b/b &&
	shit mv a/a/file.txt b/b/file.txt &&
	test_write_lines one two 4 >b/b/file.txt &&
	shit commit -a -m"move to b" &&
	shit checkout -b move-to-c delete-base &&
	mkdir -p c/c &&
	shit mv a/a/file.txt c/c/file.txt &&
	test_write_lines one two 3 >c/c/file.txt &&
	shit commit -a -m"move to c" &&

	shit checkout -b stash1 main &&
	echo stash1 change file11 >file11 &&
	shit add file11 &&
	shit commit -m "stash1 changes" &&

	shit checkout -b stash2 main &&
	echo stash2 change file11 >file11 &&
	shit add file11 &&
	shit commit -m "stash2 changes" &&

	shit checkout main &&
	shit submodule update -N &&
	echo main updated >file1 &&
	echo main new >file2 &&
	echo main updated spaced >"spaced name" &&
	echo main both added >both &&
	echo main updated file12 >file12 &&
	echo main updated file14 >file14 &&
	echo main new sub >subdir/file3 &&
	(
		cd submod &&
		echo main submodule >bar &&
		shit add bar &&
		shit commit -m "Add bar on main" &&
		shit checkout -b submod-main
	) &&
	shit add file1 "spaced name" file12 file14 file2 subdir/file3 submod &&
	shit add both &&
	shit rm file11 &&
	shit commit -m "main updates" &&

	shit clean -fdx &&
	shit checkout -b order-file-start main &&
	echo start >a &&
	echo start >b &&
	shit add a b &&
	shit commit -m start &&
	shit checkout -b order-file-side1 order-file-start &&
	echo side1 >a &&
	echo side1 >b &&
	shit add a b &&
	shit commit -m side1 &&
	shit checkout -b order-file-side2 order-file-start &&
	echo side2 >a &&
	echo side2 >b &&
	shit add a b &&
	shit commit -m side2 &&

	shit config merge.tool mytool &&
	shit config mergetool.mytool.cmd "cat \"\$REMOTE\" >\"\$MERGED\"" &&
	shit config mergetool.mytool.trustExitCode true &&
	shit config mergetool.mybase.cmd "cat \"\$BASE\" >\"\$MERGED\"" &&
	shit config mergetool.mybase.trustExitCode true
'

test_expect_success 'custom mergetool' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	shit submodule update -N &&
	test_must_fail shit merge main &&
	yes "" | shit mergetool both &&
	yes "" | shit mergetool file1 file1 &&
	yes "" | shit mergetool file2 "spaced name" &&
	yes "" | shit mergetool subdir/file3 &&
	yes "d" | shit mergetool file11 &&
	yes "d" | shit mergetool file12 &&
	yes "l" | shit mergetool submod &&
	echo "main updated" >expect &&
	test_cmp expect file1 &&
	echo "main new" >expect &&
	test_cmp expect file2 &&
	echo "main new sub" >expect &&
	test_cmp expect subdir/file3 &&
	echo "branch1 submodule" >expect &&
	test_cmp expect submod/bar &&
	shit commit -m "branch1 resolved with mergetool"
'

test_expect_success 'gui mergetool' '
	test_config merge.guitool myguitool &&
	test_config mergetool.myguitool.cmd "(printf \"gui \" && cat \"\$REMOTE\") >\"\$MERGED\"" &&
	test_config mergetool.myguitool.trustExitCode true &&
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	shit submodule update -N &&
	test_must_fail shit merge main &&
	yes "" | shit mergetool --gui both &&
	yes "" | shit mergetool -g file1 file1 &&
	yes "" | shit mergetool --gui file2 "spaced name" &&
	yes "" | shit mergetool --gui subdir/file3 &&
	yes "d" | shit mergetool --gui file11 &&
	yes "d" | shit mergetool --gui file12 &&
	yes "l" | shit mergetool --gui submod &&
	echo "gui main updated" >expect &&
	test_cmp expect file1 &&
	echo "gui main new" >expect &&
	test_cmp expect file2 &&
	echo "gui main new sub" >expect &&
	test_cmp expect subdir/file3 &&
	echo "branch1 submodule" >expect &&
	test_cmp expect submod/bar &&
	shit commit -m "branch1 resolved with mergetool"
'

test_expect_success 'gui mergetool without merge.guitool set falls back to merge.tool' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	shit submodule update -N &&
	test_must_fail shit merge main &&
	yes "" | shit mergetool --gui both &&
	yes "" | shit mergetool -g file1 file1 &&
	yes "" | shit mergetool --gui file2 "spaced name" &&
	yes "" | shit mergetool --gui subdir/file3 &&
	yes "d" | shit mergetool --gui file11 &&
	yes "d" | shit mergetool --gui file12 &&
	yes "l" | shit mergetool --gui submod &&
	echo "main updated" >expect &&
	test_cmp expect file1 &&
	echo "main new" >expect &&
	test_cmp expect file2 &&
	echo "main new sub" >expect &&
	test_cmp expect subdir/file3 &&
	echo "branch1 submodule" >expect &&
	test_cmp expect submod/bar &&
	shit commit -m "branch1 resolved with mergetool"
'

test_expect_success 'mergetool crlf' '
	test_when_finished "shit reset --hard" &&
	# This test_config line must go after the above reset line so that
	# core.autocrlf is unconfigured before reset runs.  (The
	# test_config command uses test_when_finished internally and
	# test_when_finished is LIFO.)
	test_config core.autocrlf true &&
	shit checkout -b test$test_count branch1 &&
	test_must_fail shit merge main &&
	yes "" | shit mergetool file1 &&
	yes "" | shit mergetool file2 &&
	yes "" | shit mergetool "spaced name" &&
	yes "" | shit mergetool both &&
	yes "" | shit mergetool subdir/file3 &&
	yes "d" | shit mergetool file11 &&
	yes "d" | shit mergetool file12 &&
	yes "r" | shit mergetool submod &&
	test "$(printf x | cat file1 -)" = "$(printf "main updated\r\nx")" &&
	test "$(printf x | cat file2 -)" = "$(printf "main new\r\nx")" &&
	test "$(printf x | cat subdir/file3 -)" = "$(printf "main new sub\r\nx")" &&
	shit submodule update -N &&
	echo "main submodule" >expect &&
	test_cmp expect submod/bar &&
	shit commit -m "branch1 resolved with mergetool - autocrlf"
'

test_expect_success 'mergetool in subdir' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	shit submodule update -N &&
	(
		cd subdir &&
		test_must_fail shit merge main &&
		yes "" | shit mergetool file3 &&
		echo "main new sub" >expect &&
		test_cmp expect file3
	)
'

test_expect_success 'mergetool on file in parent dir' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	shit submodule update -N &&
	(
		cd subdir &&
		test_must_fail shit merge main &&
		yes "" | shit mergetool file3 &&
		yes "" | shit mergetool ../file1 &&
		yes "" | shit mergetool ../file2 ../spaced\ name &&
		yes "" | shit mergetool ../both &&
		yes "d" | shit mergetool ../file11 &&
		yes "d" | shit mergetool ../file12 &&
		yes "l" | shit mergetool ../submod &&
		echo "main updated" >expect &&
		test_cmp expect ../file1 &&
		echo "main new" >expect &&
		test_cmp expect ../file2 &&
		echo "branch1 submodule" >expect &&
		test_cmp expect ../submod/bar &&
		shit commit -m "branch1 resolved with mergetool - subdir"
	)
'

test_expect_success 'mergetool skips autoresolved' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	shit submodule update -N &&
	test_must_fail shit merge main &&
	test -n "$(shit ls-files -u)" &&
	yes "d" | shit mergetool file11 &&
	yes "d" | shit mergetool file12 &&
	yes "l" | shit mergetool submod &&
	output="$(shit mergetool --no-prompt)" &&
	test "$output" = "No files need merging"
'

test_expect_success 'mergetool merges all from subdir (rerere disabled)' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	test_config rerere.enabled false &&
	(
		cd subdir &&
		test_must_fail shit merge main &&
		yes "r" | shit mergetool ../submod &&
		yes "d" "d" | shit mergetool --no-prompt &&
		echo "main updated" >expect &&
		test_cmp expect ../file1 &&
		echo "main new" >expect &&
		test_cmp expect ../file2 &&
		echo "main new sub" >expect &&
		test_cmp expect file3 &&
		( cd .. && shit submodule update -N ) &&
		echo "main submodule" >expect &&
		test_cmp expect ../submod/bar &&
		shit commit -m "branch2 resolved by mergetool from subdir"
	)
'

test_expect_success 'mergetool merges all from subdir (rerere enabled)' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	test_config rerere.enabled true &&
	rm -rf .shit/rr-cache &&
	(
		cd subdir &&
		test_must_fail shit merge main &&
		yes "r" | shit mergetool ../submod &&
		yes "d" "d" | shit mergetool --no-prompt &&
		echo "main updated" >expect &&
		test_cmp expect ../file1 &&
		echo "main new" >expect &&
		test_cmp expect ../file2 &&
		echo "main new sub" >expect &&
		test_cmp expect file3 &&
		( cd .. && shit submodule update -N ) &&
		echo "main submodule" >expect &&
		test_cmp expect ../submod/bar &&
		shit commit -m "branch2 resolved by mergetool from subdir"
	)
'

test_expect_success 'mergetool skips resolved paths when rerere is active' '
	test_when_finished "shit reset --hard" &&
	test_config rerere.enabled true &&
	rm -rf .shit/rr-cache &&
	shit checkout -b test$test_count branch1 &&
	shit submodule update -N &&
	test_must_fail shit merge main &&
	yes "l" | shit mergetool --no-prompt submod &&
	yes "d" "d" | shit mergetool --no-prompt &&
	shit submodule update -N &&
	output="$(yes "n" | shit mergetool --no-prompt)" &&
	test "$output" = "No files need merging"
'

test_expect_success 'conflicted stash sets up rerere'  '
	test_when_finished "shit reset --hard" &&
	test_config rerere.enabled true &&
	shit checkout stash1 &&
	echo "Conflicting stash content" >file11 &&
	shit stash &&

	shit checkout --detach stash2 &&
	test_must_fail shit stash apply &&

	test -n "$(shit ls-files -u)" &&
	conflicts="$(shit rerere remaining)" &&
	test "$conflicts" = "file11" &&
	output="$(shit mergetool --no-prompt)" &&
	test "$output" != "No files need merging" &&

	shit commit -am "save the stash resolution" &&

	shit reset --hard stash2 &&
	test_must_fail shit stash apply &&

	test -n "$(shit ls-files -u)" &&
	conflicts="$(shit rerere remaining)" &&
	test -z "$conflicts" &&
	output="$(shit mergetool --no-prompt)" &&
	test "$output" = "No files need merging"
'

test_expect_success 'mergetool takes partial path' '
	test_when_finished "shit reset --hard" &&
	test_config rerere.enabled false &&
	shit checkout -b test$test_count branch1 &&
	shit submodule update -N &&
	test_must_fail shit merge main &&

	yes "" | shit mergetool subdir &&

	echo "main new sub" >expect &&
	test_cmp expect subdir/file3
'

test_expect_success 'mergetool delete/delete conflict' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count move-to-c &&
	test_must_fail shit merge move-to-b &&
	echo d | shit mergetool a/a/file.txt &&
	! test -f a/a/file.txt &&
	shit reset --hard &&
	test_must_fail shit merge move-to-b &&
	echo m | shit mergetool a/a/file.txt &&
	test -f b/b/file.txt &&
	shit reset --hard &&
	test_must_fail shit merge move-to-b &&
	! echo a | shit mergetool a/a/file.txt &&
	! test -f a/a/file.txt
'

test_expect_success 'mergetool produces no errors when keepBackup is used' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count move-to-c &&
	test_config mergetool.keepBackup true &&
	test_must_fail shit merge move-to-b &&
	echo d | shit mergetool a/a/file.txt 2>actual &&
	test_must_be_empty actual &&
	! test -d a
'

test_expect_success 'mergetool honors tempfile config for deleted files' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count move-to-c &&
	test_config mergetool.keepTemporaries false &&
	test_must_fail shit merge move-to-b &&
	echo d | shit mergetool a/a/file.txt &&
	! test -d a
'

test_expect_success 'mergetool keeps tempfiles when aborting delete/delete' '
	test_when_finished "shit reset --hard" &&
	test_when_finished "shit clean -fdx" &&
	shit checkout -b test$test_count move-to-c &&
	test_config mergetool.keepTemporaries true &&
	test_must_fail shit merge move-to-b &&
	! test_write_lines a n | shit mergetool a/a/file.txt &&
	test -d a/a &&
	cat >expect <<-\EOF &&
	file_BASE_.txt
	file_LOCAL_.txt
	file_REMOTE_.txt
	EOF
	ls -1 a/a | sed -e "s/[0-9]*//g" >actual &&
	test_cmp expect actual
'

test_expect_success 'deleted vs modified submodule' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	shit submodule update -N &&
	mv submod submod-movedaside &&
	shit rm --cached submod &&
	shit commit -m "Submodule deleted from branch" &&
	shit checkout -b test$test_count.a test$test_count &&
	test_must_fail shit merge main &&
	test -n "$(shit ls-files -u)" &&
	yes "" | shit mergetool file1 file2 spaced\ name subdir/file3 &&
	yes "" | shit mergetool both &&
	yes "d" | shit mergetool file11 file12 &&
	yes "r" | shit mergetool submod &&
	rmdir submod && mv submod-movedaside submod &&
	echo "branch1 submodule" >expect &&
	test_cmp expect submod/bar &&
	shit submodule update -N &&
	echo "main submodule" >expect &&
	test_cmp expect submod/bar &&
	output="$(shit mergetool --no-prompt)" &&
	test "$output" = "No files need merging" &&
	shit commit -m "Merge resolved by keeping module" &&

	mv submod submod-movedaside &&
	shit checkout -b test$test_count.b test$test_count &&
	shit submodule update -N &&
	test_must_fail shit merge main &&
	test -n "$(shit ls-files -u)" &&
	yes "" | shit mergetool file1 file2 spaced\ name subdir/file3 &&
	yes "" | shit mergetool both &&
	yes "d" | shit mergetool file11 file12 &&
	yes "l" | shit mergetool submod &&
	test ! -e submod &&
	output="$(shit mergetool --no-prompt)" &&
	test "$output" = "No files need merging" &&
	shit commit -m "Merge resolved by deleting module" &&

	mv submod-movedaside submod &&
	shit checkout -b test$test_count.c main &&
	shit submodule update -N &&
	test_must_fail shit merge test$test_count &&
	test -n "$(shit ls-files -u)" &&
	yes "" | shit mergetool file1 file2 spaced\ name subdir/file3 &&
	yes "" | shit mergetool both &&
	yes "d" | shit mergetool file11 file12 &&
	yes "r" | shit mergetool submod &&
	test ! -e submod &&
	test -d submod.orig &&
	shit submodule update -N &&
	output="$(shit mergetool --no-prompt)" &&
	test "$output" = "No files need merging" &&
	shit commit -m "Merge resolved by deleting module" &&
	mv submod.orig submod &&

	shit checkout -b test$test_count.d main &&
	shit submodule update -N &&
	test_must_fail shit merge test$test_count &&
	test -n "$(shit ls-files -u)" &&
	yes "" | shit mergetool file1 file2 spaced\ name subdir/file3 &&
	yes "" | shit mergetool both &&
	yes "d" | shit mergetool file11 file12 &&
	yes "l" | shit mergetool submod &&
	echo "main submodule" >expect &&
	test_cmp expect submod/bar &&
	shit submodule update -N &&
	echo "main submodule" >expect &&
	test_cmp expect submod/bar &&
	output="$(shit mergetool --no-prompt)" &&
	test "$output" = "No files need merging" &&
	shit commit -m "Merge resolved by keeping module"
'

test_expect_success 'file vs modified submodule' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	shit submodule update -N &&
	mv submod submod-movedaside &&
	shit rm --cached submod &&
	echo not a submodule >submod &&
	shit add submod &&
	shit commit -m "Submodule path becomes file" &&
	shit checkout -b test$test_count.a branch1 &&
	test_must_fail shit merge main &&
	test -n "$(shit ls-files -u)" &&
	yes "" | shit mergetool file1 file2 spaced\ name subdir/file3 &&
	yes "" | shit mergetool both &&
	yes "d" | shit mergetool file11 file12 &&
	yes "r" | shit mergetool submod &&
	rmdir submod && mv submod-movedaside submod &&
	echo "branch1 submodule" >expect &&
	test_cmp expect submod/bar &&
	shit submodule update -N &&
	echo "main submodule" >expect &&
	test_cmp expect submod/bar &&
	output="$(shit mergetool --no-prompt)" &&
	test "$output" = "No files need merging" &&
	shit commit -m "Merge resolved by keeping module" &&

	mv submod submod-movedaside &&
	shit checkout -b test$test_count.b test$test_count &&
	test_must_fail shit merge main &&
	test -n "$(shit ls-files -u)" &&
	yes "" | shit mergetool file1 file2 spaced\ name subdir/file3 &&
	yes "" | shit mergetool both &&
	yes "d" | shit mergetool file11 file12 &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		yes "c" | shit mergetool submod~HEAD &&
		shit rm submod &&
		shit mv submod~HEAD submod
	else
		yes "l" | shit mergetool submod
	fi &&
	shit submodule update -N &&
	echo "not a submodule" >expect &&
	test_cmp expect submod &&
	output="$(shit mergetool --no-prompt)" &&
	test "$output" = "No files need merging" &&
	shit commit -m "Merge resolved by keeping file" &&

	shit checkout -b test$test_count.c main &&
	rmdir submod && mv submod-movedaside submod &&
	test ! -e submod.orig &&
	shit submodule update -N &&
	test_must_fail shit merge test$test_count &&
	test -n "$(shit ls-files -u)" &&
	yes "" | shit mergetool file1 file2 spaced\ name subdir/file3 &&
	yes "" | shit mergetool both &&
	yes "d" | shit mergetool file11 file12 &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		mv submod submod.orig &&
		shit rm --cached submod &&
		yes "c" | shit mergetool submod~test19 &&
		shit mv submod~test19 submod
	else
		yes "r" | shit mergetool submod
	fi &&
	test -d submod.orig &&
	shit submodule update -N &&
	echo "not a submodule" >expect &&
	test_cmp expect submod &&
	output="$(shit mergetool --no-prompt)" &&
	test "$output" = "No files need merging" &&
	shit commit -m "Merge resolved by keeping file" &&

	shit checkout -b test$test_count.d main &&
	rmdir submod && mv submod.orig submod &&
	shit submodule update -N &&
	test_must_fail shit merge test$test_count &&
	test -n "$(shit ls-files -u)" &&
	yes "" | shit mergetool file1 file2 spaced\ name subdir/file3 &&
	yes "" | shit mergetool both &&
	yes "d" | shit mergetool file11 file12 &&
	yes "l" | shit mergetool submod &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		yes "d" | shit mergetool submod~test19
	fi &&
	echo "main submodule" >expect &&
	test_cmp expect submod/bar &&
	shit submodule update -N &&
	echo "main submodule" >expect &&
	test_cmp expect submod/bar &&
	output="$(shit mergetool --no-prompt)" &&
	test "$output" = "No files need merging" &&
	shit commit -m "Merge resolved by keeping module"
'

test_expect_success 'submodule in subdirectory' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	shit submodule update -N &&
	(
		cd subdir &&
		test_create_repo subdir_module &&
		(
		cd subdir_module &&
		: >file15 &&
		shit add file15 &&
		shit commit -m "add initial versions"
		)
	) &&
	test_when_finished "rm -rf subdir/subdir_module" &&
	shit submodule add file:///dev/null subdir/subdir_module &&
	shit add subdir/subdir_module &&
	shit commit -m "add submodule in subdirectory" &&

	shit checkout -b test$test_count.a test$test_count &&
	shit submodule update -N &&
	(
	cd subdir/subdir_module &&
		shit checkout -b super10.a &&
		echo test$test_count.a >file15 &&
		shit add file15 &&
		shit commit -m "on branch 10.a"
	) &&
	shit add subdir/subdir_module &&
	shit commit -m "change submodule in subdirectory on test$test_count.a" &&

	shit checkout -b test$test_count.b test$test_count &&
	shit submodule update -N &&
	(
		cd subdir/subdir_module &&
		shit checkout -b super10.b &&
		echo test$test_count.b >file15 &&
		shit add file15 &&
		shit commit -m "on branch 10.b"
	) &&
	shit add subdir/subdir_module &&
	shit commit -m "change submodule in subdirectory on test$test_count.b" &&

	test_must_fail shit merge test$test_count.a &&
	(
		cd subdir &&
		yes "l" | shit mergetool subdir_module
	) &&
	echo "test$test_count.b" >expect &&
	test_cmp expect subdir/subdir_module/file15 &&
	shit submodule update -N &&
	echo "test$test_count.b" >expect &&
	test_cmp expect subdir/subdir_module/file15 &&
	shit reset --hard &&
	shit submodule update -N &&

	test_must_fail shit merge test$test_count.a &&
	yes "r" | shit mergetool subdir/subdir_module &&
	echo "test$test_count.b" >expect &&
	test_cmp expect subdir/subdir_module/file15 &&
	shit submodule update -N &&
	echo "test$test_count.a" >expect &&
	test_cmp expect subdir/subdir_module/file15 &&
	shit commit -m "branch1 resolved with mergetool"
'

test_expect_success 'directory vs modified submodule' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	mv submod submod-movedaside &&
	shit rm --cached submod &&
	mkdir submod &&
	echo not a submodule >submod/file16 &&
	shit add submod/file16 &&
	shit commit -m "Submodule path becomes directory" &&

	test_must_fail shit merge main &&
	test -n "$(shit ls-files -u)" &&
	yes "l" | shit mergetool submod &&
	echo "not a submodule" >expect &&
	test_cmp expect submod/file16 &&
	rm -rf submod.orig &&

	shit reset --hard &&
	test_must_fail shit merge main &&
	test -n "$(shit ls-files -u)" &&
	test ! -e submod.orig &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		yes "r" | shit mergetool submod~main &&
		shit mv submod submod.orig &&
		shit mv submod~main submod
	else
		yes "r" | shit mergetool submod
	fi &&
	test -d submod.orig &&
	echo "not a submodule" >expect &&
	test_cmp expect submod.orig/file16 &&
	rm -r submod.orig &&
	mv submod-movedaside/.shit submod &&
	( cd submod && shit clean -f && shit reset --hard ) &&
	shit submodule update -N &&
	echo "main submodule" >expect &&
	test_cmp expect submod/bar &&
	shit reset --hard &&
	rm -rf submod-movedaside &&

	shit checkout -b test$test_count.c main &&
	shit submodule update -N &&
	test_must_fail shit merge test$test_count &&
	test -n "$(shit ls-files -u)" &&
	yes "l" | shit mergetool submod &&
	shit submodule update -N &&
	echo "main submodule" >expect &&
	test_cmp expect submod/bar &&

	shit reset --hard &&
	shit submodule update -N &&
	test_must_fail shit merge test$test_count &&
	test -n "$(shit ls-files -u)" &&
	test ! -e submod.orig &&
	yes "r" | shit mergetool submod &&
	echo "not a submodule" >expect &&
	test_cmp expect submod/file16 &&

	shit reset --hard main &&
	( cd submod && shit clean -f && shit reset --hard ) &&
	shit submodule update -N
'

test_expect_success 'file with no base' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	test_must_fail shit merge main &&
	shit mergetool --no-prompt --tool mybase -- both &&
	test_must_be_empty both
'

test_expect_success 'custom commands override built-ins' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	test_config mergetool.defaults.cmd "cat \"\$REMOTE\" >\"\$MERGED\"" &&
	test_config mergetool.defaults.trustExitCode true &&
	test_must_fail shit merge main &&
	shit mergetool --no-prompt --tool defaults -- both &&
	echo main both added >expected &&
	test_cmp expected both
'

test_expect_success 'filenames seen by tools start with ./' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	test_config mergetool.writeToTemp false &&
	test_config mergetool.myecho.cmd "echo \"\$LOCAL\"" &&
	test_config mergetool.myecho.trustExitCode true &&
	test_must_fail shit merge main &&
	shit mergetool --no-prompt --tool myecho -- both >actual &&
	grep ^\./both_LOCAL_ actual
'

test_lazy_prereq MKTEMP '
	tempdir=$(mktemp -d -t foo.XXXXXX) &&
	test -d "$tempdir" &&
	rmdir "$tempdir"
'

test_expect_success MKTEMP 'temporary filenames are used with mergetool.writeToTemp' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	test_config mergetool.writeToTemp true &&
	test_config mergetool.myecho.cmd "echo \"\$LOCAL\"" &&
	test_config mergetool.myecho.trustExitCode true &&
	test_must_fail shit merge main &&
	shit mergetool --no-prompt --tool myecho -- both >actual &&
	! grep ^\./both_LOCAL_ actual &&
	grep /both_LOCAL_ actual
'

test_expect_success 'diff.orderFile configuration is honored' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count order-file-side2 &&
	test_config diff.orderFile order-file &&
	test_config mergetool.myecho.cmd "echo \"\$LOCAL\"" &&
	test_config mergetool.myecho.trustExitCode true &&
	echo b >order-file &&
	echo a >>order-file &&
	test_must_fail shit merge order-file-side1 &&
	cat >expect <<-\EOF &&
		Merging:
		b
		a
	EOF

	# make sure "order-file" that is ambiguous between
	# rev and path is understood correctly.
	shit branch order-file HEAD &&

	shit mergetool --no-prompt --tool myecho >output &&
	shit grep --no-index -h -A2 Merging: output >actual &&
	test_cmp expect actual
'
test_expect_success 'mergetool -Oorder-file is honored' '
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count order-file-side2 &&
	test_config diff.orderFile order-file &&
	test_config mergetool.myecho.cmd "echo \"\$LOCAL\"" &&
	test_config mergetool.myecho.trustExitCode true &&
	echo b >order-file &&
	echo a >>order-file &&
	test_must_fail shit merge order-file-side1 &&
	cat >expect <<-\EOF &&
		Merging:
		a
		b
	EOF
	shit mergetool -O/dev/null --no-prompt --tool myecho >output &&
	shit grep --no-index -h -A2 Merging: output >actual &&
	test_cmp expect actual &&
	shit reset --hard &&

	shit config --unset diff.orderFile &&
	test_must_fail shit merge order-file-side1 &&
	cat >expect <<-\EOF &&
		Merging:
		b
		a
	EOF
	shit mergetool -Oorder-file --no-prompt --tool myecho >output &&
	shit grep --no-index -h -A2 Merging: output >actual &&
	test_cmp expect actual
'

test_expect_success 'mergetool --tool-help shows recognized tools' '
	# Check a few known tools are correctly shown
	shit mergetool --tool-help >mergetools &&
	grep vimdiff mergetools &&
	grep vimdiff3 mergetools &&
	grep gvimdiff2 mergetools &&
	grep araxis mergetools &&
	grep xxdiff mergetools &&
	grep meld mergetools
'

test_expect_success 'mergetool hideResolved' '
	test_config mergetool.hideResolved true &&
	test_when_finished "shit reset --hard" &&
	shit checkout -b test${test_count}_b main &&
	test_write_lines >file1 base "" a &&
	shit commit -a -m "base" &&
	test_write_lines >file1 base "" c &&
	shit commit -a -m "remote update" &&
	shit checkout -b test${test_count}_a HEAD~ &&
	test_write_lines >file1 local "" b &&
	shit commit -a -m "local update" &&
	test_must_fail shit merge test${test_count}_b &&
	yes "" | shit mergetool file1 &&
	test_write_lines >expect local "" c &&
	test_cmp expect file1 &&
	shit commit -m "test resolved with mergetool"
'

test_expect_success 'mergetool with guiDefault' '
	test_config merge.guitool myguitool &&
	test_config mergetool.myguitool.cmd "(printf \"gui \" && cat \"\$REMOTE\") >\"\$MERGED\"" &&
	test_config mergetool.myguitool.trustExitCode true &&
	test_when_finished "shit reset --hard" &&
	shit checkout -b test$test_count branch1 &&
	shit submodule update -N &&
	test_must_fail shit merge main &&

	test_config mergetool.guiDefault auto &&
	DISPLAY=SOMETHING && export DISPLAY &&
	yes "" | shit mergetool both &&
	yes "" | shit mergetool file1 file1 &&

	DISPLAY= && export DISPLAY &&
	yes "" | shit mergetool file2 "spaced name" &&

	test_config mergetool.guiDefault true &&
	yes "" | shit mergetool subdir/file3 &&

	yes "d" | shit mergetool file11 &&
	yes "d" | shit mergetool file12 &&
	yes "l" | shit mergetool submod &&

	echo "gui main updated" >expect &&
	test_cmp expect file1 &&

	echo "main new" >expect &&
	test_cmp expect file2 &&

	echo "gui main new sub" >expect &&
	test_cmp expect subdir/file3 &&

	echo "branch1 submodule" >expect &&
	test_cmp expect submod/bar &&
	shit commit -m "branch1 resolved with mergetool"
'

test_done
