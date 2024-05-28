#!/bin/sh
#
# Copyright (c) 2007 Michael Spang
#

test_description='shit clean basic tests'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

shit config clean.requireForce no

test_expect_success 'setup' '

	mkdir -p src &&
	touch src/part1.c Makefile &&
	echo build >.shitignore &&
	echo \*.o >>.shitignore &&
	shit add . &&
	shit commit -m setup &&
	touch src/part2.c README &&
	shit add .

'

test_expect_success 'shit clean with skip-worktree .shitignore' '
	shit update-index --skip-worktree .shitignore &&
	rm .shitignore &&
	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	shit clean &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test ! -f a.out &&
	test ! -f src/part3.c &&
	test -f docs/manual.txt &&
	test -f obj.o &&
	test -f build/lib.so &&
	shit update-index --no-skip-worktree .shitignore &&
	shit checkout .shitignore
'

test_expect_success 'shit clean' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	shit clean &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test ! -f a.out &&
	test ! -f src/part3.c &&
	test -f docs/manual.txt &&
	test -f obj.o &&
	test -f build/lib.so

'

test_expect_success 'shit clean src/' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	shit clean src/ &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test -f a.out &&
	test ! -f src/part3.c &&
	test -f docs/manual.txt &&
	test -f obj.o &&
	test -f build/lib.so

'

test_expect_success 'shit clean src/ src/' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	shit clean src/ src/ &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test -f a.out &&
	test ! -f src/part3.c &&
	test -f docs/manual.txt &&
	test -f obj.o &&
	test -f build/lib.so

'

test_expect_success 'shit clean with prefix' '

	mkdir -p build docs src/test &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so src/test/1.c &&
	(cd src/ && shit clean) &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test -f a.out &&
	test ! -f src/part3.c &&
	test -f src/test/1.c &&
	test -f docs/manual.txt &&
	test -f obj.o &&
	test -f build/lib.so

'

test_expect_success 'shit clean with relative prefix' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	would_clean=$(
		cd docs &&
		shit clean -n ../src |
		grep part3 |
		sed -n -e "s|^Would remove ||p"
	) &&
	test "$would_clean" = ../src/part3.c
'

test_expect_success 'shit clean with absolute path' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	would_clean=$(
		cd docs &&
		shit clean -n "$(pwd)/../src" |
		grep part3 |
		sed -n -e "s|^Would remove ||p"
	) &&
	test "$would_clean" = ../src/part3.c
'

test_expect_success 'shit clean with out of work tree relative path' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	(
		cd docs &&
		test_must_fail shit clean -n ../..
	)
'

test_expect_success 'shit clean with out of work tree absolute path' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	dd=$(cd .. && pwd) &&
	(
		cd docs &&
		test_must_fail shit clean -n $dd
	)
'

test_expect_success 'shit clean -d with prefix and path' '

	mkdir -p build docs src/feature &&
	touch a.out src/part3.c src/feature/file.c docs/manual.txt obj.o build/lib.so &&
	(cd src/ && shit clean -d feature/) &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test -f a.out &&
	test -f src/part3.c &&
	test ! -f src/feature/file.c &&
	test -f docs/manual.txt &&
	test -f obj.o &&
	test -f build/lib.so

'

test_expect_success SYMLINKS 'shit clean symbolic link' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	ln -s docs/manual.txt src/part4.c &&
	shit clean &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test ! -f a.out &&
	test ! -f src/part3.c &&
	test ! -f src/part4.c &&
	test -f docs/manual.txt &&
	test -f obj.o &&
	test -f build/lib.so

'

test_expect_success 'shit clean with wildcard' '

	touch a.clean b.clean other.c &&
	shit clean "*.clean" &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test ! -f a.clean &&
	test ! -f b.clean &&
	test -f other.c

'

test_expect_success 'shit clean -n' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	shit clean -n &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test -f a.out &&
	test -f src/part3.c &&
	test -f docs/manual.txt &&
	test -f obj.o &&
	test -f build/lib.so

'

test_expect_success 'shit clean -d' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	shit clean -d &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test ! -f a.out &&
	test ! -f src/part3.c &&
	test ! -d docs &&
	test -f obj.o &&
	test -f build/lib.so

'

test_expect_success 'shit clean -d src/ examples/' '

	mkdir -p build docs examples &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so examples/1.c &&
	shit clean -d src/ examples/ &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test -f a.out &&
	test ! -f src/part3.c &&
	test ! -f examples/1.c &&
	test -f docs/manual.txt &&
	test -f obj.o &&
	test -f build/lib.so

'

test_expect_success 'shit clean -x' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	shit clean -x &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test ! -f a.out &&
	test ! -f src/part3.c &&
	test -f docs/manual.txt &&
	test ! -f obj.o &&
	test -f build/lib.so

'

test_expect_success 'shit clean -d -x' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	shit clean -d -x &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test ! -f a.out &&
	test ! -f src/part3.c &&
	test ! -d docs &&
	test ! -f obj.o &&
	test ! -d build

'

test_expect_success 'shit clean -d -x with ignored tracked directory' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	shit clean -d -x -e src &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test ! -f a.out &&
	test -f src/part3.c &&
	test ! -d docs &&
	test ! -f obj.o &&
	test ! -d build

'

test_expect_success 'shit clean -X' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	shit clean -X &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test -f a.out &&
	test -f src/part3.c &&
	test -f docs/manual.txt &&
	test ! -f obj.o &&
	test -f build/lib.so

'

test_expect_success 'shit clean -d -X' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	shit clean -d -X &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test -f a.out &&
	test -f src/part3.c &&
	test -f docs/manual.txt &&
	test ! -f obj.o &&
	test ! -d build

'

test_expect_success 'shit clean -d -X with ignored tracked directory' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	shit clean -d -X -e src &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test -f a.out &&
	test ! -f src/part3.c &&
	test -f docs/manual.txt &&
	test ! -f obj.o &&
	test ! -d build

'

test_expect_success 'clean.requireForce defaults to true' '

	shit config --unset clean.requireForce &&
	test_must_fail shit clean

'

test_expect_success 'clean.requireForce' '

	shit config clean.requireForce true &&
	test_must_fail shit clean

'

test_expect_success 'clean.requireForce and -n' '

	mkdir -p build docs &&
	touch a.out src/part3.c docs/manual.txt obj.o build/lib.so &&
	shit clean -n &&
	test -f Makefile &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test -f a.out &&
	test -f src/part3.c &&
	test -f docs/manual.txt &&
	test -f obj.o &&
	test -f build/lib.so

'

test_expect_success 'clean.requireForce and -f' '

	shit clean -f &&
	test -f README &&
	test -f src/part1.c &&
	test -f src/part2.c &&
	test ! -f a.out &&
	test ! -f src/part3.c &&
	test -f docs/manual.txt &&
	test -f obj.o &&
	test -f build/lib.so

'

test_expect_success 'clean.requireForce and --interactive' '
	shit clean --interactive </dev/null >output 2>error &&
	test_grep ! "requireForce is true and" error &&
	test_grep "\*\*\* Commands \*\*\*" output
'

test_expect_success 'core.excludesfile' '

	echo excludes >excludes &&
	echo included >included &&
	shit config core.excludesfile excludes &&
	output=$(shit clean -n excludes included 2>&1) &&
	expr "$output" : ".*included" >/dev/null &&
	! expr "$output" : ".*excludes" >/dev/null

'

test_expect_success SANITY 'removal failure' '

	mkdir foo &&
	touch foo/bar &&
	test_when_finished "chmod 755 foo" &&
	(exec <foo/bar &&
	 chmod 0 foo &&
	 test_must_fail shit clean -f -d)
'

test_expect_success 'nested shit work tree' '
	rm -fr foo bar baz &&
	mkdir -p foo bar baz/boo &&
	(
		cd foo &&
		shit init &&
		test_commit nested hello.world
	) &&
	(
		cd bar &&
		>goodbye.people
	) &&
	(
		cd baz/boo &&
		shit init &&
		test_commit deeply.nested deeper.world
	) &&
	shit clean -f -d &&
	test -f foo/.shit/index &&
	test -f foo/hello.world &&
	test -f baz/boo/.shit/index &&
	test -f baz/boo/deeper.world &&
	! test -d bar
'

test_expect_success 'should clean things that almost look like shit but are not' '
	rm -fr almost_shit almost_bare_shit almost_submodule &&
	mkdir -p almost_shit/.shit/objects &&
	mkdir -p almost_shit/.shit/refs &&
	cat >almost_shit/.shit/HEAD <<-\EOF &&
	garbage
	EOF
	cp -r almost_shit/.shit/ almost_bare_shit &&
	mkdir almost_submodule/ &&
	cat >almost_submodule/.shit <<-\EOF &&
	garbage
	EOF
	test_when_finished "rm -rf almost_*" &&
	shit clean -f -d &&
	test_path_is_missing almost_shit &&
	test_path_is_missing almost_bare_shit &&
	test_path_is_missing almost_submodule
'

test_expect_success 'should not clean submodules' '
	rm -fr repo to_clean sub1 sub2 &&
	mkdir repo to_clean &&
	(
		cd repo &&
		shit init &&
		test_commit msg hello.world
	) &&
	test_config_global protocol.file.allow always &&
	shit submodule add ./repo/.shit sub1 &&
	shit commit -m "sub1" &&
	shit branch before_sub2 &&
	shit submodule add ./repo/.shit sub2 &&
	shit commit -m "sub2" &&
	shit checkout before_sub2 &&
	>to_clean/should_clean.this &&
	shit clean -f -d &&
	test_path_is_file repo/.shit/index &&
	test_path_is_file repo/hello.world &&
	test_path_is_file sub1/.shit &&
	test_path_is_file sub1/hello.world &&
	test_path_is_file sub2/.shit &&
	test_path_is_file sub2/hello.world &&
	test_path_is_missing to_clean
'

test_expect_success POSIXPERM,SANITY 'should avoid cleaning possible submodules' '
	rm -fr to_clean possible_sub1 &&
	mkdir to_clean possible_sub1 &&
	test_when_finished "rm -rf possible_sub*" &&
	echo "shitdir: foo" >possible_sub1/.shit &&
	>possible_sub1/hello.world &&
	chmod 0 possible_sub1/.shit &&
	>to_clean/should_clean.this &&
	shit clean -f -d &&
	test_path_is_file possible_sub1/.shit &&
	test_path_is_file possible_sub1/hello.world &&
	test_path_is_missing to_clean
'

test_expect_success 'nested (empty) shit should be kept' '
	rm -fr empty_repo to_clean &&
	shit init empty_repo &&
	mkdir to_clean &&
	>to_clean/should_clean.this &&
	# Note that we put the expect file in the .shit directory so that it
	# does not get cleaned.
	find empty_repo | sort >.shit/expect &&
	shit clean -f -d &&
	find empty_repo | sort >actual &&
	test_cmp .shit/expect actual &&
	test_path_is_missing to_clean
'

test_expect_success 'nested bare repositories should be cleaned' '
	rm -fr bare1 bare2 subdir &&
	shit init --bare bare1 &&
	shit clone --local --bare . bare2 &&
	mkdir subdir &&
	cp -r bare2 subdir/bare3 &&
	shit clean -f -d &&
	test_path_is_missing bare1 &&
	test_path_is_missing bare2 &&
	test_path_is_missing subdir
'

test_expect_failure 'nested (empty) bare repositories should be cleaned even when in .shit' '
	rm -fr strange_bare &&
	mkdir strange_bare &&
	shit init --bare strange_bare/.shit &&
	shit clean -f -d &&
	test_path_is_missing strange_bare
'

test_expect_failure 'nested (non-empty) bare repositories should be cleaned even when in .shit' '
	rm -fr strange_bare &&
	mkdir strange_bare &&
	shit clone --local --bare . strange_bare/.shit &&
	shit clean -f -d &&
	test_path_is_missing strange_bare
'

test_expect_success 'giving path in nested shit work tree will NOT remove it' '
	rm -fr repo &&
	mkdir repo &&
	(
		cd repo &&
		shit init &&
		mkdir -p bar/baz &&
		test_commit msg bar/baz/hello.world
	) &&
	find repo | sort >expect &&
	shit clean -f -d repo/bar/baz &&
	find repo | sort >actual &&
	test_cmp expect actual
'

test_expect_success 'giving path to nested .shit will not remove it' '
	rm -fr repo &&
	mkdir repo untracked &&
	(
		cd repo &&
		shit init &&
		test_commit msg hello.world
	) &&
	find repo | sort >expect &&
	shit clean -f -d repo/.shit &&
	find repo | sort >actual &&
	test_cmp expect actual &&
	test_path_is_dir untracked/
'

test_expect_success 'giving path to nested .shit/ will NOT remove contents' '
	rm -fr repo untracked &&
	mkdir repo untracked &&
	(
		cd repo &&
		shit init &&
		test_commit msg hello.world
	) &&
	find repo | sort >expect &&
	shit clean -f -d repo/.shit/ &&
	find repo | sort >actual &&
	test_cmp expect actual &&
	test_path_is_dir untracked/
'

test_expect_success 'force removal of nested shit work tree' '
	rm -fr foo bar baz &&
	mkdir -p foo bar baz/boo &&
	(
		cd foo &&
		shit init &&
		test_commit nested hello.world
	) &&
	(
		cd bar &&
		>goodbye.people
	) &&
	(
		cd baz/boo &&
		shit init &&
		test_commit deeply.nested deeper.world
	) &&
	shit clean -f -f -d &&
	! test -d foo &&
	! test -d bar &&
	! test -d baz
'

test_expect_success 'shit clean -e' '
	rm -fr repo &&
	mkdir repo &&
	(
		cd repo &&
		shit init &&
		touch known 1 2 3 &&
		shit add known &&
		shit clean -f -e 1 -e 2 &&
		test -e 1 &&
		test -e 2 &&
		! (test -e 3) &&
		test -e known
	)
'

test_expect_success SANITY 'shit clean -d with an unreadable empty directory' '
	mkdir foo &&
	chmod a= foo &&
	shit clean -dfx foo &&
	! test -d foo
'

test_expect_success 'shit clean -d respects pathspecs (dir is prefix of pathspec)' '
	mkdir -p foo &&
	mkdir -p foobar &&
	shit clean -df foobar &&
	test_path_is_dir foo &&
	test_path_is_missing foobar
'

test_expect_success 'shit clean -d respects pathspecs (pathspec is prefix of dir)' '
	mkdir -p foo &&
	mkdir -p foobar &&
	shit clean -df foo &&
	test_path_is_missing foo &&
	test_path_is_dir foobar
'

test_expect_success 'shit clean -d skips untracked dirs containing ignored files' '
	echo /foo/bar >.shitignore &&
	echo ignoreme >>.shitignore &&
	rm -rf foo &&
	mkdir -p foo/a/aa/aaa foo/b/bb/bbb &&
	touch foo/bar foo/baz foo/a/aa/ignoreme foo/b/ignoreme foo/b/bb/1 foo/b/bb/2 &&
	shit clean -df &&
	test_path_is_dir foo &&
	test_path_is_file foo/bar &&
	test_path_is_missing foo/baz &&
	test_path_is_file foo/a/aa/ignoreme &&
	test_path_is_missing foo/a/aa/aaa &&
	test_path_is_file foo/b/ignoreme &&
	test_path_is_missing foo/b/bb
'

test_expect_success 'shit clean -d skips nested repo containing ignored files' '
	test_when_finished "rm -rf nested-repo-with-ignored-file" &&

	shit init nested-repo-with-ignored-file &&
	(
		cd nested-repo-with-ignored-file &&
		>file &&
		shit add file &&
		shit commit -m Initial &&

		# This file is ignored by a .shitignore rule in the outer repo
		# added in the previous test.
		>ignoreme
	) &&

	shit clean -fd &&

	test_path_is_file nested-repo-with-ignored-file/.shit/index &&
	test_path_is_file nested-repo-with-ignored-file/ignoreme &&
	test_path_is_file nested-repo-with-ignored-file/file
'

test_expect_success 'shit clean handles being told what to clean' '
	mkdir -p d1 d2 &&
	touch d1/ut d2/ut &&
	shit clean -f */ut &&
	test_path_is_missing d1/ut &&
	test_path_is_missing d2/ut
'

test_expect_success 'shit clean handles being told what to clean, with -d' '
	mkdir -p d1 d2 &&
	touch d1/ut d2/ut &&
	shit clean -ffd */ut &&
	test_path_is_missing d1/ut &&
	test_path_is_missing d2/ut
'

test_expect_success 'shit clean works if a glob is passed without -d' '
	mkdir -p d1 d2 &&
	touch d1/ut d2/ut &&
	shit clean -f "*ut" &&
	test_path_is_missing d1/ut &&
	test_path_is_missing d2/ut
'

test_expect_success 'shit clean works if a glob is passed with -d' '
	mkdir -p d1 d2 &&
	touch d1/ut d2/ut &&
	shit clean -ffd "*ut" &&
	test_path_is_missing d1/ut &&
	test_path_is_missing d2/ut
'

test_expect_success MINGW 'handle clean & core.longpaths = false nicely' '
	test_config core.longpaths false &&
	a50=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa &&
	mkdir -p $a50$a50/$a50$a50/$a50$a50 &&
	: >"$a50$a50/test.txt" 2>"$a50$a50/$a50$a50/$a50$a50/test.txt" &&
	# create a temporary outside the working tree to hide from "shit clean"
	test_must_fail shit clean -xdf 2>.shit/err &&
	# grepping for a strerror string is unportable but it is OK here with
	# MINGW prereq
	test_grep "too long" .shit/err
'

test_expect_success 'clean untracked paths by pathspec' '
	shit init untracked &&
	mkdir untracked/dir &&
	echo >untracked/dir/file.txt &&
	shit -C untracked clean -f dir/file.txt &&
	ls untracked/dir >actual &&
	test_must_be_empty actual
'

test_expect_success 'avoid traversing into ignored directories' '
	test_when_finished rm -f output error trace.* &&
	test_create_repo avoid-traversing-deep-hierarchy &&
	(
		cd avoid-traversing-deep-hierarchy &&

		mkdir -p untracked/subdir/with/a &&
		>untracked/subdir/with/a/random-file.txt &&

		shit_TRACE2_PERF="$TRASH_DIRECTORY/trace.output" \
		shit clean -ffdxn -e untracked
	) &&

	# Make sure we only visited into the top-level directory, and did
	# not traverse into the "untracked" subdirectory since it was excluded
	grep data.*read_directo.*directories-visited trace.output |
		cut -d "|" -f 9 >trace.relevant &&
	cat >trace.expect <<-EOF &&
	 ..directories-visited:1
	EOF
	test_cmp trace.expect trace.relevant
'

test_expect_success 'traverse into directories that may have ignored entries' '
	test_when_finished rm -f output &&
	test_create_repo need-to-traverse-into-hierarchy &&
	(
		cd need-to-traverse-into-hierarchy &&
		mkdir -p modules/foobar/src/generated &&
		> modules/foobar/src/generated/code.c &&
		> modules/foobar/Makefile &&
		echo "/modules/**/src/generated/" >.shitignore &&

		shit clean -fX modules/foobar >../output &&

		grep Removing ../output &&

		test_path_is_missing modules/foobar/src/generated/code.c &&
		test_path_is_file modules/foobar/Makefile
	)
'

test_done
