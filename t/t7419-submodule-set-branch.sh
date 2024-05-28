#!/bin/sh
#
# Copyright (c) 2019 Denton Liu
#

test_description='Test submodules set-branch subcommand

This test verifies that the set-branch subcommand of shit-submodule is working
as expected.
'

TEST_PASSES_SANITIZE_LEAK=true
TEST_NO_CREATE_REPO=1

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '
	shit config --global protocol.file.allow always
'

test_expect_success 'submodule config cache setup' '
	mkdir submodule &&
	(cd submodule &&
		shit init &&
		echo a >a &&
		shit add . &&
		shit commit -ma &&
		shit checkout -b topic &&
		echo b >a &&
		shit add . &&
		shit commit -mb &&
		shit checkout main
	) &&
	mkdir super &&
	(cd super &&
		shit init &&
		shit submodule add ../submodule &&
		shit submodule add --name thename ../submodule thepath &&
		shit commit -m "add submodules"
	)
'

test_expect_success 'ensure submodule branch is unset' '
	(cd super &&
		test_cmp_config "" -f .shitmodules --default "" submodule.submodule.branch
	)
'

test_expect_success 'test submodule set-branch --branch' '
	(cd super &&
		shit submodule set-branch --branch topic submodule &&
		test_cmp_config topic -f .shitmodules submodule.submodule.branch &&
		shit submodule update --remote &&
		cat <<-\EOF >expect &&
		b
		EOF
		shit -C submodule show -s --pretty=%s >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'test submodule set-branch --default' '
	(cd super &&
		shit submodule set-branch --default submodule &&
		test_cmp_config "" -f .shitmodules --default "" submodule.submodule.branch &&
		shit submodule update --remote &&
		cat <<-\EOF >expect &&
		a
		EOF
		shit -C submodule show -s --pretty=%s >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'test submodule set-branch -b' '
	(cd super &&
		shit submodule set-branch -b topic submodule &&
		test_cmp_config topic -f .shitmodules submodule.submodule.branch &&
		shit submodule update --remote &&
		cat <<-\EOF >expect &&
		b
		EOF
		shit -C submodule show -s --pretty=%s >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'test submodule set-branch -d' '
	(cd super &&
		shit submodule set-branch -d submodule &&
		test_cmp_config "" -f .shitmodules --default "" submodule.submodule.branch &&
		shit submodule update --remote &&
		cat <<-\EOF >expect &&
		a
		EOF
		shit -C submodule show -s --pretty=%s >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'test submodule set-branch --branch with named submodule' '
	(cd super &&
		shit submodule set-branch --branch topic thepath &&
		test_cmp_config topic -f .shitmodules submodule.thename.branch &&
		test_cmp_config "" -f .shitmodules --default "" submodule.thepath.branch &&
		shit submodule update --remote &&
		cat <<-\EOF >expect &&
		b
		EOF
		shit -C thepath show -s --pretty=%s >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'test submodule set-branch --default with named submodule' '
	(cd super &&
		shit submodule set-branch --default thepath &&
		test_cmp_config "" -f .shitmodules --default "" submodule.thename.branch &&
		shit submodule update --remote &&
		cat <<-\EOF >expect &&
		a
		EOF
		shit -C thepath show -s --pretty=%s >actual &&
		test_cmp expect actual
	)
'

test_done
