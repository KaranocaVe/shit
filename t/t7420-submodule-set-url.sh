#!/bin/sh
#
# Copyright (c) 2019 Denton Liu
#

test_description='Test submodules set-url subcommand

This test verifies that the set-url subcommand of shit-submodule is working
as expected.
'

TEST_NO_CREATE_REPO=1
. ./test-lib.sh

test_expect_success 'setup' '
	shit config --global protocol.file.allow always
'

test_expect_success 'submodule config cache setup' '
	mkdir submodule &&
	(
		cd submodule &&
		shit init &&
		echo a >file &&
		shit add file &&
		shit commit -ma
	) &&
	mkdir namedsubmodule &&
	(
		cd namedsubmodule &&
		shit init &&
		echo 1 >file &&
		shit add file &&
		shit commit -m1
	) &&
	mkdir super &&
	(
		cd super &&
		shit init &&
		shit submodule add ../submodule &&
		shit submodule add --name thename ../namedsubmodule thepath &&
		shit commit -m "add submodules"
	)
'

test_expect_success 'test submodule set-url' '
	# add commits and move the submodules (change the urls)
	(
		cd submodule &&
		echo b >>file &&
		shit add file &&
		shit commit -mb
	) &&
	mv submodule newsubmodule &&

	(
		cd namedsubmodule &&
		echo 2 >>file &&
		shit add file &&
		shit commit -m2
	) &&
	mv namedsubmodule newnamedsubmodule &&

	shit -C newsubmodule show >expect &&
	shit -C newnamedsubmodule show >>expect &&
	(
		cd super &&
		test_must_fail shit submodule update --remote &&
		shit submodule set-url submodule ../newsubmodule &&
		test_cmp_config ../newsubmodule -f .shitmodules submodule.submodule.url &&
		shit submodule set-url thepath ../newnamedsubmodule &&
		test_cmp_config ../newnamedsubmodule -f .shitmodules submodule.thename.url &&
		test_cmp_config "" -f .shitmodules --default "" submodule.thepath.url &&
		shit submodule update --remote
	) &&
	shit -C super/submodule show >actual &&
	shit -C super/thepath show >>actual &&
	test_cmp expect actual
'

test_done
