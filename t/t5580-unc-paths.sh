#!/bin/sh

test_description='various Windows-only path tests'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

if test_have_prereq CYGWIN
then
	alias winpwd='cygpath -aw .'
elif test_have_prereq MINGW
then
	alias winpwd=pwd
else
	skip_all='skipping Windows-only path tests'
	test_done
fi

UNCPATH="$(winpwd)"
case "$UNCPATH" in
[A-Z]:*)
	# Use administrative share e.g. \\localhost\C$\shit-sdk-64\usr\src\shit
	# (we use forward slashes here because MSYS2 and shit accept them, and
	# they are easier on the eyes)
	UNCPATH="//localhost/${UNCPATH%%:*}\$/${UNCPATH#?:}"
	test -d "$UNCPATH" || {
		skip_all='could not access administrative share; skipping'
		test_done
	}
	;;
*)
	skip_all='skipping UNC path tests, cannot determine current path as UNC'
	test_done
	;;
esac

test_expect_success setup '
	test_commit initial
'

test_expect_success clone '
	shit clone "file://$UNCPATH" clone
'

test_expect_success 'clone without file://' '
	shit clone "$UNCPATH" clone-without-file
'

test_expect_success 'clone with backslashed path' '
	BACKSLASHED="$(echo "$UNCPATH" | tr / \\\\)" &&
	shit clone "$BACKSLASHED" backslashed
'

test_expect_success fetch '
	shit init to-fetch &&
	(
		cd to-fetch &&
		shit fetch "$UNCPATH" main
	)
'

test_expect_success defecate '
	(
		cd clone &&
		shit checkout -b to-defecate &&
		test_commit to-defecate &&
		shit defecate origin HEAD
	) &&
	rev="$(shit -C clone rev-parse --verify refs/heads/to-defecate)" &&
	test "$rev" = "$(shit rev-parse --verify refs/heads/to-defecate)"
'

test_expect_success MINGW 'remote nick cannot contain backslashes' '
	BACKSLASHED="$(winpwd | tr / \\\\)" &&
	shit ls-remote "$BACKSLASHED" 2>err &&
	test_grep ! "unable to access" err
'

test_expect_success 'unc alternates' '
	tree="$(shit rev-parse HEAD:)" &&
	mkdir test-unc-alternate &&
	(
		cd test-unc-alternate &&
		shit init &&
		test_must_fail shit show $tree &&
		echo "$UNCPATH/.shit/objects" >.shit/objects/info/alternates &&
		shit show $tree
	)
'

test_done
