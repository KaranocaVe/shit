#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='shit ls-files -k and -m flags test.

This test prepares the following in the cache:

    path0       - a file
    path1       - a symlink
    path2/file2 - a file in a directory
    path3/file3 - a file in a directory
    pathx/ju    - a file in a directory
    submod1/	- a submodule
    submod2/	- another submodule

and the following on the filesystem:

    path0/file0 - a file in a directory
    path1/file1 - a file in a directory
    path2       - a file
    path3       - a symlink
    path4	- a file
    path5	- a symlink
    path6/file6 - a file in a directory
    pathx/ju/nk - a file in a directory to be killed
    submod1/	- a submodule (modified from the cache)
    submod2/	- a submodule (matches the cache)

shit ls-files -k should report that existing filesystem objects
path0/*, path1/*, path2 and path3 to be killed.

Also for modification test, the cache and working tree have:

    path7       - an empty file, modified to a non-empty file.
    path8       - a non-empty file, modified to an empty file.
    path9	- an empty file, cache dirtied.
    path10	- a non-empty file, cache dirtied.

We should report path0, path1, path2/file2, path3/file3, path7 and path8
modified without reporting path9 and path10.  submod1 is also modified.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'shit update-index --add to add various paths.' '
	date >path0 &&
	test_ln_s_add xyzzy path1 &&
	mkdir path2 path3 pathx &&
	date >path2/file2 &&
	date >path3/file3 &&
	>pathx/ju &&
	: >path7 &&
	date >path8 &&
	: >path9 &&
	date >path10 &&
	shit update-index --add -- path0 path?/file? pathx/ju path7 path8 path9 path10 &&
	shit init submod1 &&
	shit -C submod1 commit --allow-empty -m "empty 1" &&
	shit init submod2 &&
	shit -C submod2 commit --allow-empty -m "empty 2" &&
	shit update-index --add submod[12] &&
	(
		cd submod1 &&
		shit commit --allow-empty -m "empty 1 (updated)"
	) &&
	rm -fr path?	# leave path10 alone
'

test_expect_success 'shit ls-files -k to show killed files.' '
	date >path2 &&
	if test_have_prereq SYMLINKS
	then
		ln -s frotz path3 &&
		ln -s nitfol path5
	else
		date >path3 &&
		date >path5
	fi &&
	mkdir -p path0 path1 path6 pathx/ju &&
	date >path0/file0 &&
	date >path1/file1 &&
	date >path6/file6 &&
	date >path7 &&
	: >path8 &&
	: >path9 &&
	touch path10 &&
	>pathx/ju/nk &&
	cat >.expected <<-\EOF
	path0/file0
	path1/file1
	path2
	path3
	pathx/ju/nk
	EOF
'

test_expect_success 'shit ls-files -k output (w/o icase)' '
	shit ls-files -k >.output &&
	test_cmp .expected .output
'

test_expect_success 'shit ls-files -k output (w/ icase)' '
	shit -c core.ignorecase=true ls-files -k >.output &&
	test_cmp .expected .output
'

test_expect_success 'shit ls-files -m to show modified files.' '
	shit ls-files -m >.output
'

test_expect_success 'validate shit ls-files -m output.' '
	cat >.expected <<-\EOF &&
	path0
	path1
	path2/file2
	path3/file3
	path7
	path8
	pathx/ju
	submod1
	EOF
	test_cmp .expected .output
'

test_done
