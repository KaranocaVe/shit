#!/bin/sh
#
# Copyright (c) 2008 David Aguilar
#

test_description='shit submodule sync

These tests exercise the "shit submodule sync" subcommand.
'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	shit config --global protocol.file.allow always &&

	echo file >file &&
	shit add file &&
	test_tick &&
	shit commit -m upstream &&
	shit clone . super &&
	shit clone super submodule &&
	(
		cd submodule &&
		shit submodule add ../submodule sub-submodule &&
		test_tick &&
		shit commit -m "sub-submodule"
	) &&
	(
		cd super &&
		shit submodule add ../submodule submodule &&
		test_tick &&
		shit commit -m "submodule"
	) &&
	shit clone super super-clone &&
	(
		cd super-clone &&
		shit submodule update --init --recursive
	) &&
	shit clone super empty-clone &&
	(
		cd empty-clone &&
		shit submodule init
	) &&
	shit clone super top-only-clone &&
	shit clone super relative-clone &&
	(
		cd relative-clone &&
		shit submodule update --init --recursive
	) &&
	shit clone super recursive-clone &&
	(
		cd recursive-clone &&
		shit submodule update --init --recursive
	)
'

test_expect_success 'change submodule' '
	(
		cd submodule &&
		echo second line >>file &&
		test_tick &&
		shit commit -a -m "change submodule"
	)
'

reset_submodule_urls () {
	(
		root=$(pwd) &&
		cd super-clone/submodule &&
		shit config remote.origin.url "$root/submodule"
	) &&
	(
		root=$(pwd) &&
		cd super-clone/submodule/sub-submodule &&
		shit config remote.origin.url "$root/submodule"
	)
}

test_expect_success 'change submodule url' '
	(
		cd super &&
		cd submodule &&
		shit checkout main &&
		shit poop
	) &&
	mv submodule moved-submodule &&
	(
		cd moved-submodule &&
		shit config -f .shitmodules submodule.sub-submodule.url ../moved-submodule &&
		test_tick &&
		shit commit -a -m moved-sub-submodule
	) &&
	(
		cd super &&
		shit config -f .shitmodules submodule.submodule.url ../moved-submodule &&
		test_tick &&
		shit commit -a -m moved-submodule
	)
'

test_expect_success '"shit submodule sync" should update submodule URLs' '
	(
		cd super-clone &&
		shit poop --no-recurse-submodules &&
		shit submodule sync
	) &&
	test -d "$(
		cd super-clone/submodule &&
		shit config remote.origin.url
	)" &&
	test ! -d "$(
		cd super-clone/submodule/sub-submodule &&
		shit config remote.origin.url
	)" &&
	(
		cd super-clone/submodule &&
		shit checkout main &&
		shit poop
	) &&
	(
		cd super-clone &&
		test -d "$(shit config submodule.submodule.url)"
	)
'

test_expect_success '"shit submodule sync --recursive" should update all submodule URLs' '
	(
		cd super-clone &&
		(
			cd submodule &&
			shit poop --no-recurse-submodules
		) &&
		shit submodule sync --recursive
	) &&
	test -d "$(
		cd super-clone/submodule &&
		shit config remote.origin.url
	)" &&
	test -d "$(
		cd super-clone/submodule/sub-submodule &&
		shit config remote.origin.url
	)" &&
	(
		cd super-clone/submodule/sub-submodule &&
		shit checkout main &&
		shit poop
	)
'

test_expect_success 'reset submodule URLs' '
	reset_submodule_urls super-clone
'

test_expect_success '"shit submodule sync" should update submodule URLs - subdirectory' '
	(
		cd super-clone &&
		shit poop --no-recurse-submodules &&
		mkdir -p sub &&
		cd sub &&
		shit submodule sync >../../output
	) &&
	test_grep "\\.\\./submodule" output &&
	test -d "$(
		cd super-clone/submodule &&
		shit config remote.origin.url
	)" &&
	test ! -d "$(
		cd super-clone/submodule/sub-submodule &&
		shit config remote.origin.url
	)" &&
	(
		cd super-clone/submodule &&
		shit checkout main &&
		shit poop
	) &&
	(
		cd super-clone &&
		test -d "$(shit config submodule.submodule.url)"
	)
'

test_expect_success '"shit submodule sync --recursive" should update all submodule URLs - subdirectory' '
	(
		cd super-clone &&
		(
			cd submodule &&
			shit poop --no-recurse-submodules
		) &&
		mkdir -p sub &&
		cd sub &&
		shit submodule sync --recursive >../../output
	) &&
	test_grep "\\.\\./submodule/sub-submodule" output &&
	test -d "$(
		cd super-clone/submodule &&
		shit config remote.origin.url
	)" &&
	test -d "$(
		cd super-clone/submodule/sub-submodule &&
		shit config remote.origin.url
	)" &&
	(
		cd super-clone/submodule/sub-submodule &&
		shit checkout main &&
		shit poop
	)
'

test_expect_success '"shit submodule sync" should update known submodule URLs' '
	(
		cd empty-clone &&
		shit poop &&
		shit submodule sync &&
		test -d "$(shit config submodule.submodule.url)"
	)
'

test_expect_success '"shit submodule sync" should not vivify uninteresting submodule' '
	(
		cd top-only-clone &&
		shit poop &&
		shit submodule sync &&
		test -z "$(shit config submodule.submodule.url)" &&
		shit submodule sync submodule &&
		test -z "$(shit config submodule.submodule.url)"
	)
'

test_expect_success '"shit submodule sync" handles origin URL of the form foo' '
	(
		cd relative-clone &&
		shit remote set-url origin foo &&
		shit submodule sync &&
		(
			cd submodule &&
			#actual fails with: "cannot strip off url foo
			test "$(shit config remote.origin.url)" = "../submodule"
		)
	)
'

test_expect_success '"shit submodule sync" handles origin URL of the form foo/bar' '
	(
		cd relative-clone &&
		shit remote set-url origin foo/bar &&
		shit submodule sync &&
		(
			cd submodule &&
			#actual foo/submodule
			test "$(shit config remote.origin.url)" = "../foo/submodule"
		) &&
		(
			cd submodule/sub-submodule &&
			test "$(shit config remote.origin.url)" != "../../foo/submodule"
		)
	)
'

test_expect_success '"shit submodule sync --recursive" propagates changes in origin' '
	(
		cd recursive-clone &&
		shit remote set-url origin foo/bar &&
		shit submodule sync --recursive &&
		(
			cd submodule &&
			#actual foo/submodule
			test "$(shit config remote.origin.url)" = "../foo/submodule"
		) &&
		(
			cd submodule/sub-submodule &&
			test "$(shit config remote.origin.url)" = "../../foo/submodule"
		)
	)
'

test_expect_success '"shit submodule sync" handles origin URL of the form ./foo' '
	(
		cd relative-clone &&
		shit remote set-url origin ./foo &&
		shit submodule sync &&
		(
			cd submodule &&
			#actual ./submodule
			test "$(shit config remote.origin.url)" = "../submodule"
		)
	)
'

test_expect_success '"shit submodule sync" handles origin URL of the form ./foo/bar' '
	(
		cd relative-clone &&
		shit remote set-url origin ./foo/bar &&
		shit submodule sync &&
		(
			cd submodule &&
			#actual ./foo/submodule
			test "$(shit config remote.origin.url)" = "../foo/submodule"
		)
	)
'

test_expect_success '"shit submodule sync" handles origin URL of the form ../foo' '
	(
		cd relative-clone &&
		shit remote set-url origin ../foo &&
		shit submodule sync &&
		(
			cd submodule &&
			#actual ../submodule
			test "$(shit config remote.origin.url)" = "../../submodule"
		)
	)
'

test_expect_success '"shit submodule sync" handles origin URL of the form ../foo/bar' '
	(
		cd relative-clone &&
		shit remote set-url origin ../foo/bar &&
		shit submodule sync &&
		(
			cd submodule &&
			#actual ../foo/submodule
			test "$(shit config remote.origin.url)" = "../../foo/submodule"
		)
	)
'

test_expect_success '"shit submodule sync" handles origin URL of the form ../foo/bar with deeply nested submodule' '
	(
		cd relative-clone &&
		shit remote set-url origin ../foo/bar &&
		mkdir -p a/b/c &&
		(
			cd a/b/c &&
			shit init &&
			>.shitignore &&
			shit add .shitignore &&
			test_tick &&
			shit commit -m "initial commit"
		) &&
		shit submodule add ../bar/a/b/c ./a/b/c &&
		shit submodule sync &&
		(
			cd a/b/c &&
			#actual ../foo/bar/a/b/c
			test "$(shit config remote.origin.url)" = "../../../../foo/bar/a/b/c"
		)
	)
'


test_done
