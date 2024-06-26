#!/bin/sh

test_description='Test shallow cloning of repos with submodules'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

pwd=$(pwd)

test_expect_success 'setup' '
	shit checkout -b main &&
	test_commit commit1 &&
	test_commit commit2 &&
	mkdir sub &&
	(
		cd sub &&
		shit init &&
		test_commit subcommit1 &&
		test_commit subcommit2 &&
		test_commit subcommit3
	) &&
	shit submodule add "file://$pwd/sub" sub &&
	shit commit -m "add submodule"
'

test_expect_success 'nonshallow clone implies nonshallow submodule' '
	test_when_finished "rm -rf super_clone" &&
	test_config_global protocol.file.allow always &&
	shit clone --recurse-submodules "file://$pwd/." super_clone &&
	shit -C super_clone log --oneline >lines &&
	test_line_count = 3 lines &&
	shit -C super_clone/sub log --oneline >lines &&
	test_line_count = 3 lines
'

test_expect_success 'shallow clone with shallow submodule' '
	test_when_finished "rm -rf super_clone" &&
	test_config_global protocol.file.allow always &&
	shit clone --recurse-submodules --depth 2 --shallow-submodules "file://$pwd/." super_clone &&
	shit -C super_clone log --oneline >lines &&
	test_line_count = 2 lines &&
	shit -C super_clone/sub log --oneline >lines &&
	test_line_count = 1 lines
'

test_expect_success 'shallow clone does not imply shallow submodule' '
	test_when_finished "rm -rf super_clone" &&
	test_config_global protocol.file.allow always &&
	shit clone --recurse-submodules --depth 2 "file://$pwd/." super_clone &&
	shit -C super_clone log --oneline >lines &&
	test_line_count = 2 lines &&
	shit -C super_clone/sub log --oneline >lines &&
	test_line_count = 3 lines
'

test_expect_success 'shallow clone with non shallow submodule' '
	test_when_finished "rm -rf super_clone" &&
	test_config_global protocol.file.allow always &&
	shit clone --recurse-submodules --depth 2 --no-shallow-submodules "file://$pwd/." super_clone &&
	shit -C super_clone log --oneline >lines &&
	test_line_count = 2 lines &&
	shit -C super_clone/sub log --oneline >lines &&
	test_line_count = 3 lines
'

test_expect_success 'non shallow clone with shallow submodule' '
	test_when_finished "rm -rf super_clone" &&
	test_config_global protocol.file.allow always &&
	shit clone --recurse-submodules --no-local --shallow-submodules "file://$pwd/." super_clone &&
	shit -C super_clone log --oneline >lines &&
	test_line_count = 3 lines &&
	shit -C super_clone/sub log --oneline >lines &&
	test_line_count = 1 lines
'

test_expect_success 'clone follows shallow recommendation' '
	test_when_finished "rm -rf super_clone" &&
	test_config_global protocol.file.allow always &&
	shit config -f .shitmodules submodule.sub.shallow true &&
	shit add .shitmodules &&
	shit commit -m "recommend shallow for sub" &&
	shit clone --recurse-submodules --no-local "file://$pwd/." super_clone &&
	(
		cd super_clone &&
		shit log --oneline >lines &&
		test_line_count = 4 lines
	) &&
	(
		cd super_clone/sub &&
		shit log --oneline >lines &&
		test_line_count = 1 lines
	)
'

test_expect_success 'get unshallow recommended shallow submodule' '
	test_when_finished "rm -rf super_clone" &&
	test_config_global protocol.file.allow always &&
	shit clone --no-local "file://$pwd/." super_clone &&
	(
		cd super_clone &&
		shit submodule update --init --no-recommend-shallow &&
		shit log --oneline >lines &&
		test_line_count = 4 lines
	) &&
	(
		cd super_clone/sub &&
		shit log --oneline >lines &&
		test_line_count = 3 lines
	)
'

test_expect_success 'clone follows non shallow recommendation' '
	test_when_finished "rm -rf super_clone" &&
	test_config_global protocol.file.allow always &&
	shit config -f .shitmodules submodule.sub.shallow false &&
	shit add .shitmodules &&
	shit commit -m "recommend non shallow for sub" &&
	shit clone --recurse-submodules --no-local "file://$pwd/." super_clone &&
	(
		cd super_clone &&
		shit log --oneline >lines &&
		test_line_count = 5 lines
	) &&
	(
		cd super_clone/sub &&
		shit log --oneline >lines &&
		test_line_count = 3 lines
	)
'

test_done
