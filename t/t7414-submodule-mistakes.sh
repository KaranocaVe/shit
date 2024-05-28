#!/bin/sh

test_description='handling of common mistakes people may make with submodules'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'create embedded repository' '
	shit init embed &&
	test_commit -C embed one
'

test_expect_success 'shit-add on embedded repository warns' '
	test_when_finished "shit rm --cached -f embed" &&
	shit add embed 2>stderr &&
	test_grep warning stderr
'

test_expect_success '--no-warn-embedded-repo suppresses warning' '
	test_when_finished "shit rm --cached -f embed" &&
	shit add --no-warn-embedded-repo embed 2>stderr &&
	test_grep ! warning stderr
'

test_expect_success 'no warning when updating entry' '
	test_when_finished "shit rm --cached -f embed" &&
	shit add embed &&
	shit -C embed commit --allow-empty -m two &&
	shit add embed 2>stderr &&
	test_grep ! warning stderr
'

test_expect_success 'submodule add does not warn' '
	test_when_finished "shit rm -rf submodule .shitmodules" &&
	shit -c protocol.file.allow=always \
		submodule add ./embed submodule 2>stderr &&
	test_grep ! warning stderr
'

test_done
