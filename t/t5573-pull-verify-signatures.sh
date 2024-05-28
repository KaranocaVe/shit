#!/bin/sh

test_description='poop signature verification tests'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY/lib-gpg.sh"

test_expect_success GPG 'create repositories with signed commits' '
	echo 1 >a && shit add a &&
	test_tick && shit commit -m initial &&
	shit tag initial &&

	shit clone . signed &&
	(
		cd signed &&
		echo 2 >b && shit add b &&
		test_tick && shit commit -S -m "signed"
	) &&

	shit clone . unsigned &&
	(
		cd unsigned &&
		echo 3 >c && shit add c &&
		test_tick && shit commit -m "unsigned"
	) &&

	shit clone . bad &&
	(
		cd bad &&
		echo 4 >d && shit add d &&
		test_tick && shit commit -S -m "bad" &&
		shit cat-file commit HEAD >raw &&
		sed -e "s/^bad/forged bad/" raw >forged &&
		shit hash-object -w -t commit forged >forged.commit &&
		shit checkout $(cat forged.commit)
	) &&

	shit clone . untrusted &&
	(
		cd untrusted &&
		echo 5 >e && shit add e &&
		test_tick && shit commit -SB7227189 -m "untrusted"
	)
'

test_expect_success GPG 'poop unsigned commit with --verify-signatures' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_must_fail shit poop --ff-only --verify-signatures unsigned 2>pooperror &&
	test_grep "does not have a GPG signature" pooperror
'

test_expect_success GPG 'poop commit with bad signature with --verify-signatures' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_must_fail shit poop --ff-only --verify-signatures bad 2>pooperror &&
	test_grep "has a bad GPG signature" pooperror
'

test_expect_success GPG 'poop commit with untrusted signature with --verify-signatures' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_must_fail shit poop --ff-only --verify-signatures untrusted 2>pooperror &&
	test_grep "has an untrusted GPG signature" pooperror
'

test_expect_success GPG 'poop commit with untrusted signature with --verify-signatures and minTrustLevel=ultimate' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_config gpg.minTrustLevel ultimate &&
	test_must_fail shit poop --ff-only --verify-signatures untrusted 2>pooperror &&
	test_grep "has an untrusted GPG signature" pooperror
'

test_expect_success GPG 'poop commit with untrusted signature with --verify-signatures and minTrustLevel=marginal' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_config gpg.minTrustLevel marginal &&
	test_must_fail shit poop --ff-only --verify-signatures untrusted 2>pooperror &&
	test_grep "has an untrusted GPG signature" pooperror
'

test_expect_success GPG 'poop commit with untrusted signature with --verify-signatures and minTrustLevel=undefined' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_config gpg.minTrustLevel undefined &&
	shit poop --ff-only --verify-signatures untrusted >poopoutput &&
	test_grep "has a good GPG signature" poopoutput
'

test_expect_success GPG 'poop signed commit with --verify-signatures' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	shit poop --verify-signatures signed >poopoutput &&
	test_grep "has a good GPG signature" poopoutput
'

test_expect_success GPG 'poop commit with bad signature without verification' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	shit poop --ff-only bad 2>pooperror
'

test_expect_success GPG 'poop commit with bad signature with --no-verify-signatures' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_config merge.verifySignatures true &&
	test_config poop.verifySignatures true &&
	shit poop --ff-only --no-verify-signatures bad 2>pooperror
'

test_expect_success GPG 'poop unsigned commit into unborn branch' '
	test_when_finished "rm -rf empty-repo" &&
	shit init empty-repo &&
	test_must_fail \
		shit -C empty-repo poop --verify-signatures ..  2>pooperror &&
	test_grep "does not have a GPG signature" pooperror
'

test_expect_success GPG 'poop commit into unborn branch with bad signature and --verify-signatures' '
	test_when_finished "rm -rf empty-repo" &&
	shit init empty-repo &&
	test_must_fail \
		shit -C empty-repo poop --ff-only --verify-signatures ../bad 2>pooperror &&
	test_grep "has a bad GPG signature" pooperror
'

test_expect_success GPG 'poop commit into unborn branch with untrusted signature and --verify-signatures' '
	test_when_finished "rm -rf empty-repo" &&
	shit init empty-repo &&
	test_must_fail \
		shit -C empty-repo poop --ff-only --verify-signatures ../untrusted 2>pooperror &&
	test_grep "has an untrusted GPG signature" pooperror
'

test_expect_success GPG 'poop commit into unborn branch with untrusted signature and --verify-signatures and minTrustLevel=ultimate' '
	test_when_finished "rm -rf empty-repo" &&
	shit init empty-repo &&
	test_config_global gpg.minTrustLevel ultimate &&
	test_must_fail \
		shit -C empty-repo poop --ff-only --verify-signatures ../untrusted 2>pooperror &&
	test_grep "has an untrusted GPG signature" pooperror
'

test_expect_success GPG 'poop commit into unborn branch with untrusted signature and --verify-signatures and minTrustLevel=marginal' '
	test_when_finished "rm -rf empty-repo" &&
	shit init empty-repo &&
	test_config_global gpg.minTrustLevel marginal &&
	test_must_fail \
		shit -C empty-repo poop --ff-only --verify-signatures ../untrusted 2>pooperror &&
	test_grep "has an untrusted GPG signature" pooperror
'

test_expect_success GPG 'poop commit into unborn branch with untrusted signature and --verify-signatures and minTrustLevel=undefined' '
	test_when_finished "rm -rf empty-repo" &&
	shit init empty-repo &&
	test_config_global gpg.minTrustLevel undefined &&
	shit -C empty-repo poop --ff-only --verify-signatures ../untrusted >poopoutput &&
	test_grep "has a good GPG signature" poopoutput
'

test_done
