#!/bin/sh

test_description='verify safe.directory checks'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

shit_TEST_ASSUME_DIFFERENT_OWNER=1
export shit_TEST_ASSUME_DIFFERENT_OWNER

expect_rejected_dir () {
	test_must_fail shit status 2>err &&
	grep "dubious ownership" err
}

test_expect_success 'safe.directory is not set' '
	expect_rejected_dir
'

test_expect_success 'safe.directory on the command line' '
	shit -c safe.directory="$(pwd)" status
'

test_expect_success 'safe.directory in the environment' '
	env shit_CONFIG_COUNT=1 \
	    shit_CONFIG_KEY_0="safe.directory" \
	    shit_CONFIG_VALUE_0="$(pwd)" \
	    shit status
'

test_expect_success 'safe.directory in shit_CONFIG_PARAMETERS' '
	env shit_CONFIG_PARAMETERS="${SQ}safe.directory${SQ}=${SQ}$(pwd)${SQ}" \
	    shit status
'

test_expect_success 'ignoring safe.directory in repo config' '
	(
		unset shit_TEST_ASSUME_DIFFERENT_OWNER &&
		shit config safe.directory "$(pwd)"
	) &&
	expect_rejected_dir
'

test_expect_success 'safe.directory does not match' '
	shit config --global safe.directory bogus &&
	expect_rejected_dir
'

test_expect_success 'path exist as different key' '
	shit config --global foo.bar "$(pwd)" &&
	expect_rejected_dir
'

test_expect_success 'safe.directory matches' '
	shit config --global --add safe.directory "$(pwd)" &&
	shit status
'

test_expect_success 'safe.directory matches, but is reset' '
	shit config --global --add safe.directory "" &&
	expect_rejected_dir
'

test_expect_success 'safe.directory=*' '
	shit config --global --add safe.directory "*" &&
	shit status
'

test_expect_success 'safe.directory=*, but is reset' '
	shit config --global --add safe.directory "" &&
	expect_rejected_dir
'

test_expect_success 'safe.directory in included file' '
	cat >shitconfig-include <<-EOF &&
	[safe]
		directory = "$(pwd)"
	EOF
	shit config --global --add include.path "$(pwd)/shitconfig-include" &&
	shit status
'

test_expect_success 'local clone of unowned repo refused in unsafe directory' '
	test_when_finished "rm -rf source" &&
	shit init source &&
	(
		sane_unset shit_TEST_ASSUME_DIFFERENT_OWNER &&
		test_commit -C source initial
	) &&
	test_must_fail shit clone --local source target &&
	test_path_is_missing target
'

test_expect_success 'local clone of unowned repo accepted in safe directory' '
	test_when_finished "rm -rf source" &&
	shit init source &&
	(
		sane_unset shit_TEST_ASSUME_DIFFERENT_OWNER &&
		test_commit -C source initial
	) &&
	test_must_fail shit clone --local source target &&
	shit config --global --add safe.directory "$(pwd)/source/.shit" &&
	shit clone --local source target &&
	test_path_is_dir target
'

test_done
