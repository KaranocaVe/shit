#!/bin/sh

test_description='checkout can handle submodules'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-submodule-update.sh

test_expect_success 'setup' '
	mkdir submodule &&
	(cd submodule &&
	 shit init &&
	 test_commit first) &&
	shit add submodule &&
	test_tick &&
	shit commit -m superproject &&
	(cd submodule &&
	 test_commit second) &&
	shit add submodule &&
	test_tick &&
	shit commit -m updated.superproject
'

test_expect_success '"reset <submodule>" updates the index' '
	shit update-index --refresh &&
	shit diff-files --quiet &&
	shit diff-index --quiet --cached HEAD &&
	shit reset HEAD^ submodule &&
	test_must_fail shit diff-files --quiet &&
	shit reset submodule &&
	shit diff-files --quiet
'

test_expect_success '"checkout <submodule>" updates the index only' '
	shit update-index --refresh &&
	shit diff-files --quiet &&
	shit diff-index --quiet --cached HEAD &&
	shit checkout HEAD^ submodule &&
	test_must_fail shit diff-files --quiet &&
	shit checkout HEAD submodule &&
	shit diff-files --quiet
'

test_expect_success '"checkout <submodule>" honors diff.ignoreSubmodules' '
	shit config diff.ignoreSubmodules dirty &&
	echo x> submodule/untracked &&
	shit checkout HEAD >actual 2>&1 &&
	test_must_be_empty actual
'

test_expect_success '"checkout <submodule>" honors submodule.*.ignore from .shitmodules' '
	shit config diff.ignoreSubmodules none &&
	shit config -f .shitmodules submodule.submodule.path submodule &&
	shit config -f .shitmodules submodule.submodule.ignore untracked &&
	shit checkout HEAD >actual 2>&1 &&
	test_must_be_empty actual
'

test_expect_success '"checkout <submodule>" honors submodule.*.ignore from .shit/config' '
	shit config -f .shitmodules submodule.submodule.ignore none &&
	shit config submodule.submodule.path submodule &&
	shit config submodule.submodule.ignore all &&
	shit checkout HEAD >actual 2>&1 &&
	test_must_be_empty actual
'

KNOWN_FAILURE_DIRECTORY_SUBMODULE_CONFLICTS=1
test_submodule_switch_recursing_with_args "checkout"

test_submodule_forced_switch_recursing_with_args "checkout -f"

test_submodule_switch "checkout"

test_submodule_forced_switch "checkout -f"

test_done
