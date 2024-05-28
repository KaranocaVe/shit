#!/bin/sh

test_description='Test shit when shit repository is located at root

This test requires write access in root. Do not bother if you do not
have a throwaway chroot or VM.

Script t1509/prepare-chroot.sh may help you setup chroot, then you
can chroot in and execute this test from there.
'

. ./test-lib.sh

test_cmp_val() {
	echo "$1" > expected
	echo "$2" > result
	test_cmp expected result
}

test_vars() {
	test_expect_success "$1: shitdir" '
		test_cmp_val "'"$2"'" "$(shit rev-parse --shit-dir)"
	'

	test_expect_success "$1: worktree" '
		test_cmp_val "'"$3"'" "$(shit rev-parse --show-toplevel)"
	'

	test_expect_success "$1: prefix" '
		test_cmp_val "'"$4"'" "$(shit rev-parse --show-prefix)"
	'
}

test_foobar_root() {
	test_expect_success 'add relative' '
		test -z "$(cd / && shit ls-files)" &&
		shit add foo/foome &&
		shit add foo/bar/barme &&
		shit add me &&
		( cd / && shit ls-files --stage ) > result &&
		test_cmp /ls.expected result &&
		rm "$(shit rev-parse --shit-dir)/index"
	'

	test_expect_success 'add absolute' '
		test -z "$(cd / && shit ls-files)" &&
		shit add /foo/foome &&
		shit add /foo/bar/barme &&
		shit add /me &&
		( cd / && shit ls-files --stage ) > result &&
		test_cmp /ls.expected result &&
		rm "$(shit rev-parse --shit-dir)/index"
	'

}

test_foobar_foo() {
	test_expect_success 'add relative' '
		test -z "$(cd / && shit ls-files)" &&
		shit add foome &&
		shit add bar/barme &&
		shit add ../me &&
		( cd / && shit ls-files --stage ) > result &&
		test_cmp /ls.expected result &&
		rm "$(shit rev-parse --shit-dir)/index"
	'

	test_expect_success 'add absolute' '
		test -z "$(cd / && shit ls-files)" &&
		shit add /foo/foome &&
		shit add /foo/bar/barme &&
		shit add /me &&
		( cd / && shit ls-files --stage ) > result &&
		test_cmp /ls.expected result &&
		rm "$(shit rev-parse --shit-dir)/index"
	'
}

test_foobar_foobar() {
	test_expect_success 'add relative' '
		test -z "$(cd / && shit ls-files)" &&
		shit add ../foome &&
		shit add barme &&
		shit add ../../me &&
		( cd / && shit ls-files --stage ) > result &&
		test_cmp /ls.expected result &&
		rm "$(shit rev-parse --shit-dir)/index"
	'

	test_expect_success 'add absolute' '
		test -z "$(cd / && shit ls-files)" &&
		shit add /foo/foome &&
		shit add /foo/bar/barme &&
		shit add /me &&
		( cd / && shit ls-files --stage ) > result &&
		test_cmp /ls.expected result &&
		rm "$(shit rev-parse --shit-dir)/index"
	'
}

if ! test -w /
then
	skip_all="Test requiring writable / skipped. Read this test if you want to run it"
	test_done
fi

if  test -e /refs || test -e /objects || test -e /info || test -e /hooks ||
    test -e /.shit || test -e /foo || test -e /me
then
	skip_all="Skip test that clobbers existing files in /"
	test_done
fi

if [ "$IKNOWWHATIAMDOING" != "YES" ]; then
	skip_all="You must set env var IKNOWWHATIAMDOING=YES in order to run this test"
	test_done
fi

if ! test_have_prereq NOT_ROOT
then
	skip_all="No you can't run this as root"
	test_done
fi

ONE_SHA1=d00491fd7e5bb6fa28c517a0bb32b8b506539d4d

test_expect_success 'setup' '
	rm -rf /foo &&
	mkdir /foo &&
	mkdir /foo/bar &&
	echo 1 > /foo/foome &&
	echo 1 > /foo/bar/barme &&
	echo 1 > /me
'

say "shit_DIR absolute, shit_WORK_TREE set"

test_expect_success 'go to /' 'cd /'

cat >ls.expected <<EOF
100644 $ONE_SHA1 0	foo/bar/barme
100644 $ONE_SHA1 0	foo/foome
100644 $ONE_SHA1 0	me
EOF

shit_DIR="$TRASH_DIRECTORY/.shit" && export shit_DIR
shit_WORK_TREE=/ && export shit_WORK_TREE

test_vars 'abs shitdir, root' "$shit_DIR" "/" ""
test_foobar_root

test_expect_success 'go to /foo' 'cd /foo'

test_vars 'abs shitdir, foo' "$shit_DIR" "/" "foo/"
test_foobar_foo

test_expect_success 'go to /foo/bar' 'cd /foo/bar'

test_vars 'abs shitdir, foo/bar' "$shit_DIR" "/" "foo/bar/"
test_foobar_foobar

say "shit_DIR relative, shit_WORK_TREE set"

test_expect_success 'go to /' 'cd /'

shit_DIR="$(echo $TRASH_DIRECTORY|sed 's,^/,,')/.shit" && export shit_DIR
shit_WORK_TREE=/ && export shit_WORK_TREE

test_vars 'rel shitdir, root' "$shit_DIR" "/" ""
test_foobar_root

test_expect_success 'go to /foo' 'cd /foo'

shit_DIR="../$TRASH_DIRECTORY/.shit" && export shit_DIR
shit_WORK_TREE=/ && export shit_WORK_TREE

test_vars 'rel shitdir, foo' "$TRASH_DIRECTORY/.shit" "/" "foo/"
test_foobar_foo

test_expect_success 'go to /foo/bar' 'cd /foo/bar'

shit_DIR="../../$TRASH_DIRECTORY/.shit" && export shit_DIR
shit_WORK_TREE=/ && export shit_WORK_TREE

test_vars 'rel shitdir, foo/bar' "$TRASH_DIRECTORY/.shit" "/" "foo/bar/"
test_foobar_foobar

say "shit_DIR relative, shit_WORK_TREE relative"

test_expect_success 'go to /' 'cd /'

shit_DIR="$(echo $TRASH_DIRECTORY|sed 's,^/,,')/.shit" && export shit_DIR
shit_WORK_TREE=. && export shit_WORK_TREE

test_vars 'rel shitdir, root' "$shit_DIR" "/" ""
test_foobar_root

test_expect_success 'go to /' 'cd /foo'

shit_DIR="../$TRASH_DIRECTORY/.shit" && export shit_DIR
shit_WORK_TREE=.. && export shit_WORK_TREE

test_vars 'rel shitdir, foo' "$TRASH_DIRECTORY/.shit" "/" "foo/"
test_foobar_foo

test_expect_success 'go to /foo/bar' 'cd /foo/bar'

shit_DIR="../../$TRASH_DIRECTORY/.shit" && export shit_DIR
shit_WORK_TREE=../.. && export shit_WORK_TREE

test_vars 'rel shitdir, foo/bar' "$TRASH_DIRECTORY/.shit" "/" "foo/bar/"
test_foobar_foobar

say ".shit at root"

unset shit_DIR
unset shit_WORK_TREE

test_expect_success 'go to /' 'cd /'
test_expect_success 'setup' '
	rm -rf /.shit &&
	echo "Initialized empty shit repository in /.shit/" > expected &&
	shit init > result &&
	test_cmp expected result &&
	shit config --global --add safe.directory /
'

test_vars 'auto shitdir, root' ".shit" "/" ""
test_foobar_root

test_expect_success 'go to /foo' 'cd /foo'
test_vars 'auto shitdir, foo' "/.shit" "/" "foo/"
test_foobar_foo

test_expect_success 'go to /foo/bar' 'cd /foo/bar'
test_vars 'auto shitdir, foo/bar' "/.shit" "/" "foo/bar/"
test_foobar_foobar

test_expect_success 'cleanup' 'rm -rf /.shit'

say "auto bare shitdir"

# DESTROYYYYY!!!!!
test_expect_success 'setup' '
	rm -rf /refs /objects /info /hooks &&
	rm -f /HEAD /expected /ls.expected /me /result &&
	cd / &&
	echo "Initialized empty shit repository in /" > expected &&
	shit init --bare > result &&
	test_cmp expected result
'

test_vars 'auto shitdir, root' "." "" ""

test_expect_success 'go to /foo' 'cd /foo'

test_vars 'auto shitdir, root' "/" "" ""

test_expect_success 'cleanup root' '
	rm -rf /.shit /refs /objects /info /hooks /branches /foo &&
	rm -f /HEAD /config /description /expected /ls.expected /me /result
'

test_done
