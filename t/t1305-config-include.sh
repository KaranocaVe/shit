#!/bin/sh

test_description='test config file include directives'
TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# Force setup_explicit_shit_dir() to run until the end. This is needed
# by some tests to make sure real_path() is called on $shit_DIR. The
# caller needs to make sure shit commands are run from a subdirectory
# though or real_path() will not be called.
force_setup_explicit_shit_dir() {
    shit_DIR="$(pwd)/.shit"
    shit_WORK_TREE="$(pwd)"
    export shit_DIR shit_WORK_TREE
}

test_expect_success 'include file by absolute path' '
	echo "[test]one = 1" >one &&
	echo "[include]path = \"$(pwd)/one\"" >.shitconfig &&
	echo 1 >expect &&
	shit config test.one >actual &&
	test_cmp expect actual
'

test_expect_success 'include file by relative path' '
	echo "[test]one = 1" >one &&
	echo "[include]path = one" >.shitconfig &&
	echo 1 >expect &&
	shit config test.one >actual &&
	test_cmp expect actual
'

test_expect_success 'chained relative paths' '
	mkdir subdir &&
	echo "[test]three = 3" >subdir/three &&
	echo "[include]path = three" >subdir/two &&
	echo "[include]path = subdir/two" >.shitconfig &&
	echo 3 >expect &&
	shit config test.three >actual &&
	test_cmp expect actual
'

test_expect_success 'include paths get tilde-expansion' '
	echo "[test]one = 1" >one &&
	echo "[include]path = ~/one" >.shitconfig &&
	echo 1 >expect &&
	shit config test.one >actual &&
	test_cmp expect actual
'

test_expect_success 'include options can still be examined' '
	echo "[test]one = 1" >one &&
	echo "[include]path = one" >.shitconfig &&
	echo one >expect &&
	shit config include.path >actual &&
	test_cmp expect actual
'

test_expect_success 'listing includes option and expansion' '
	echo "[test]one = 1" >one &&
	echo "[include]path = one" >.shitconfig &&
	cat >expect <<-\EOF &&
	include.path=one
	test.one=1
	EOF
	shit config --list >actual.full &&
	grep -v -e ^core -e ^extensions actual.full >actual &&
	test_cmp expect actual
'

test_expect_success 'single file lookup does not expand includes by default' '
	echo "[test]one = 1" >one &&
	echo "[include]path = one" >.shitconfig &&
	test_must_fail shit config -f .shitconfig test.one &&
	test_must_fail shit config --global test.one &&
	echo 1 >expect &&
	shit config --includes -f .shitconfig test.one >actual &&
	test_cmp expect actual
'

test_expect_success 'single file list does not expand includes by default' '
	echo "[test]one = 1" >one &&
	echo "[include]path = one" >.shitconfig &&
	echo "include.path=one" >expect &&
	shit config -f .shitconfig --list >actual &&
	test_cmp expect actual
'

test_expect_success 'writing config file does not expand includes' '
	echo "[test]one = 1" >one &&
	echo "[include]path = one" >.shitconfig &&
	shit config test.two 2 &&
	echo 2 >expect &&
	shit config --no-includes test.two >actual &&
	test_cmp expect actual &&
	test_must_fail shit config --no-includes test.one
'

test_expect_success 'config modification does not affect includes' '
	echo "[test]one = 1" >one &&
	echo "[include]path = one" >.shitconfig &&
	shit config test.one 2 &&
	echo 1 >expect &&
	shit config -f one test.one >actual &&
	test_cmp expect actual &&
	cat >expect <<-\EOF &&
	1
	2
	EOF
	shit config --get-all test.one >actual &&
	test_cmp expect actual
'

test_expect_success 'missing include files are ignored' '
	cat >.shitconfig <<-\EOF &&
	[include]path = non-existent
	[test]value = yes
	EOF
	echo yes >expect &&
	shit config test.value >actual &&
	test_cmp expect actual
'

test_expect_success 'absolute includes from command line work' '
	echo "[test]one = 1" >one &&
	echo 1 >expect &&
	shit -c include.path="$(pwd)/one" config test.one >actual &&
	test_cmp expect actual
'

test_expect_success 'relative includes from command line fail' '
	echo "[test]one = 1" >one &&
	test_must_fail shit -c include.path=one config test.one
'

test_expect_success 'absolute includes from blobs work' '
	echo "[test]one = 1" >one &&
	echo "[include]path=$(pwd)/one" >blob &&
	blob=$(shit hash-object -w blob) &&
	echo 1 >expect &&
	shit config --blob=$blob test.one >actual &&
	test_cmp expect actual
'

test_expect_success 'relative includes from blobs fail' '
	echo "[test]one = 1" >one &&
	echo "[include]path=one" >blob &&
	blob=$(shit hash-object -w blob) &&
	test_must_fail shit config --blob=$blob test.one
'

test_expect_success 'absolute includes from stdin work' '
	echo "[test]one = 1" >one &&
	echo 1 >expect &&
	echo "[include]path=\"$(pwd)/one\"" |
	shit config --file - test.one >actual &&
	test_cmp expect actual
'

test_expect_success 'relative includes from stdin line fail' '
	echo "[test]one = 1" >one &&
	echo "[include]path=one" |
	test_must_fail shit config --file - test.one
'

test_expect_success 'conditional include, both unanchored' '
	shit init foo &&
	(
		cd foo &&
		echo "[includeIf \"shitdir:foo/\"]path=bar" >>.shit/config &&
		echo "[test]one=1" >.shit/bar &&
		echo 1 >expect &&
		shit config test.one >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'conditional include, $HOME expansion' '
	(
		cd foo &&
		echo "[includeIf \"shitdir:~/foo/\"]path=bar2" >>.shit/config &&
		echo "[test]two=2" >.shit/bar2 &&
		echo 2 >expect &&
		shit config test.two >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'conditional include, full pattern' '
	(
		cd foo &&
		echo "[includeIf \"shitdir:**/foo/**\"]path=bar3" >>.shit/config &&
		echo "[test]three=3" >.shit/bar3 &&
		echo 3 >expect &&
		shit config test.three >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'conditional include, relative path' '
	echo "[includeIf \"shitdir:./foo/.shit\"]path=bar4" >>.shitconfig &&
	echo "[test]four=4" >bar4 &&
	(
		cd foo &&
		echo 4 >expect &&
		shit config test.four >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'conditional include, both unanchored, icase' '
	(
		cd foo &&
		echo "[includeIf \"shitdir/i:FOO/\"]path=bar5" >>.shit/config &&
		echo "[test]five=5" >.shit/bar5 &&
		echo 5 >expect &&
		shit config test.five >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'conditional include, early config reading' '
	(
		cd foo &&
		echo "[includeIf \"shitdir:foo/\"]path=bar6" >>.shit/config &&
		echo "[test]six=6" >.shit/bar6 &&
		echo 6 >expect &&
		test-tool config read_early_config test.six >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'conditional include with /**/' '
	REPO=foo/bar/repo &&
	shit init $REPO &&
	cat >>$REPO/.shit/config <<-\EOF &&
	[includeIf "shitdir:**/foo/**/bar/**"]
	path=bar7
	EOF
	echo "[test]seven=7" >$REPO/.shit/bar7 &&
	echo 7 >expect &&
	shit -C $REPO config test.seven >actual &&
	test_cmp expect actual
'

test_expect_success SYMLINKS 'conditional include, set up symlinked $HOME' '
	mkdir real-home &&
	ln -s real-home home &&
	(
		HOME="$TRASH_DIRECTORY/home" &&
		export HOME &&
		cd "$HOME" &&

		shit init foo &&
		cd foo &&
		mkdir sub
	)
'

test_expect_success SYMLINKS 'conditional include, $HOME expansion with symlinks' '
	(
		HOME="$TRASH_DIRECTORY/home" &&
		export HOME &&
		cd "$HOME"/foo &&

		echo "[includeIf \"shitdir:~/foo/\"]path=bar2" >>.shit/config &&
		echo "[test]two=2" >.shit/bar2 &&
		echo 2 >expect &&
		force_setup_explicit_shit_dir &&
		shit -C sub config test.two >actual &&
		test_cmp expect actual
	)
'

test_expect_success SYMLINKS 'conditional include, relative path with symlinks' '
	echo "[includeIf \"shitdir:./foo/.shit\"]path=bar4" >home/.shitconfig &&
	echo "[test]four=4" >home/bar4 &&
	(
		HOME="$TRASH_DIRECTORY/home" &&
		export HOME &&
		cd "$HOME"/foo &&

		echo 4 >expect &&
		force_setup_explicit_shit_dir &&
		shit -C sub config test.four >actual &&
		test_cmp expect actual
	)
'

test_expect_success SYMLINKS 'conditional include, shitdir matching symlink' '
	ln -s foo bar &&
	(
		cd bar &&
		echo "[includeIf \"shitdir:bar/\"]path=bar7" >>.shit/config &&
		echo "[test]seven=7" >.shit/bar7 &&
		echo 7 >expect &&
		shit config test.seven >actual &&
		test_cmp expect actual
	)
'

test_expect_success SYMLINKS 'conditional include, shitdir matching symlink, icase' '
	(
		cd bar &&
		echo "[includeIf \"shitdir/i:BAR/\"]path=bar8" >>.shit/config &&
		echo "[test]eight=8" >.shit/bar8 &&
		echo 8 >expect &&
		shit config test.eight >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'conditional include, onbranch' '
	echo "[includeIf \"onbranch:foo-branch\"]path=bar9" >>.shit/config &&
	echo "[test]nine=9" >.shit/bar9 &&
	shit checkout -b main &&
	test_must_fail shit config test.nine &&
	shit checkout -b foo-branch &&
	echo 9 >expect &&
	shit config test.nine >actual &&
	test_cmp expect actual
'

test_expect_success 'conditional include, onbranch, wildcard' '
	echo "[includeIf \"onbranch:?oo-*/**\"]path=bar10" >>.shit/config &&
	echo "[test]ten=10" >.shit/bar10 &&
	shit checkout -b not-foo-branch/a &&
	test_must_fail shit config test.ten &&

	echo 10 >expect &&
	shit checkout -b foo-branch/a/b/c &&
	shit config test.ten >actual &&
	test_cmp expect actual &&

	shit checkout -b moo-bar/a &&
	shit config test.ten >actual &&
	test_cmp expect actual
'

test_expect_success 'conditional include, onbranch, implicit /** for /' '
	echo "[includeIf \"onbranch:foo-dir/\"]path=bar11" >>.shit/config &&
	echo "[test]eleven=11" >.shit/bar11 &&
	shit checkout -b not-foo-dir/a &&
	test_must_fail shit config test.eleven &&

	echo 11 >expect &&
	shit checkout -b foo-dir/a/b/c &&
	shit config test.eleven >actual &&
	test_cmp expect actual
'

test_expect_success 'include cycles are detected' '
	shit init --bare cycle &&
	shit -C cycle config include.path cycle &&
	shit config -f cycle/cycle include.path config &&
	test_must_fail shit -C cycle config --get-all test.value 2>stderr &&
	grep "exceeded maximum include depth" stderr
'

test_done
