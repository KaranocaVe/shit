#!/bin/sh

test_description='merge signature verification tests'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY/lib-gpg.sh"

test_expect_success GPG 'create signed commits' '
	echo 1 >file && shit add file &&
	test_tick && shit commit -m initial &&
	shit tag initial &&

	shit checkout -b side-signed &&
	echo 3 >elif && shit add elif &&
	test_tick && shit commit -S -m "signed on side" &&
	shit checkout initial &&

	shit checkout -b side-unsigned &&
	echo 3 >foo && shit add foo &&
	test_tick && shit commit -m "unsigned on side" &&
	shit checkout initial &&

	shit checkout -b side-bad &&
	echo 3 >bar && shit add bar &&
	test_tick && shit commit -S -m "bad on side" &&
	shit cat-file commit side-bad >raw &&
	sed -e "s/^bad/forged bad/" raw >forged &&
	shit hash-object -w -t commit forged >forged.commit &&
	shit checkout initial &&

	shit checkout -b side-untrusted &&
	echo 3 >baz && shit add baz &&
	test_tick && shit commit -SB7227189 -m "untrusted on side" &&

	shit checkout main
'

test_expect_success GPG 'merge unsigned commit with verification' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_must_fail shit merge --ff-only --verify-signatures side-unsigned 2>mergeerror &&
	test_grep "does not have a GPG signature" mergeerror
'

test_expect_success GPG 'merge unsigned commit with merge.verifySignatures=true' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_config merge.verifySignatures true &&
	test_must_fail shit merge --ff-only side-unsigned 2>mergeerror &&
	test_grep "does not have a GPG signature" mergeerror
'

test_expect_success GPG 'merge commit with bad signature with verification' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_must_fail shit merge --ff-only --verify-signatures $(cat forged.commit) 2>mergeerror &&
	test_grep "has a bad GPG signature" mergeerror
'

test_expect_success GPG 'merge commit with bad signature with merge.verifySignatures=true' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_config merge.verifySignatures true &&
	test_must_fail shit merge --ff-only $(cat forged.commit) 2>mergeerror &&
	test_grep "has a bad GPG signature" mergeerror
'

test_expect_success GPG 'merge commit with untrusted signature with verification' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_must_fail shit merge --ff-only --verify-signatures side-untrusted 2>mergeerror &&
	test_grep "has an untrusted GPG signature" mergeerror
'

test_expect_success GPG 'merge commit with untrusted signature with verification and high minTrustLevel' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_config gpg.minTrustLevel marginal &&
	test_must_fail shit merge --ff-only --verify-signatures side-untrusted 2>mergeerror &&
	test_grep "has an untrusted GPG signature" mergeerror
'

test_expect_success GPG 'merge commit with untrusted signature with verification and low minTrustLevel' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_config gpg.minTrustLevel undefined &&
	shit merge --ff-only --verify-signatures side-untrusted >mergeoutput &&
	test_grep "has a good GPG signature" mergeoutput
'

test_expect_success GPG 'merge commit with untrusted signature with merge.verifySignatures=true' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_config merge.verifySignatures true &&
	test_must_fail shit merge --ff-only side-untrusted 2>mergeerror &&
	test_grep "has an untrusted GPG signature" mergeerror
'

test_expect_success GPG 'merge commit with untrusted signature with merge.verifySignatures=true and minTrustLevel' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_config merge.verifySignatures true &&
	test_config gpg.minTrustLevel marginal &&
	test_must_fail shit merge --ff-only side-untrusted 2>mergeerror &&
	test_grep "has an untrusted GPG signature" mergeerror
'

test_expect_success GPG 'merge signed commit with verification' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	shit merge --verbose --ff-only --verify-signatures side-signed >mergeoutput &&
	test_grep "has a good GPG signature" mergeoutput
'

test_expect_success GPG 'merge signed commit with merge.verifySignatures=true' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_config merge.verifySignatures true &&
	shit merge --verbose --ff-only side-signed >mergeoutput &&
	test_grep "has a good GPG signature" mergeoutput
'

test_expect_success GPG 'merge commit with bad signature without verification' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	shit merge $(cat forged.commit)
'

test_expect_success GPG 'merge commit with bad signature with merge.verifySignatures=false' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_config merge.verifySignatures false &&
	shit merge $(cat forged.commit)
'

test_expect_success GPG 'merge commit with bad signature with merge.verifySignatures=true and --no-verify-signatures' '
	test_when_finished "shit reset --hard && shit checkout initial" &&
	test_config merge.verifySignatures true &&
	shit merge --no-verify-signatures $(cat forged.commit)
'

test_expect_success GPG 'merge unsigned commit into unborn branch' '
	test_when_finished "shit checkout initial" &&
	shit checkout --orphan unborn &&
	test_must_fail shit merge --verify-signatures side-unsigned 2>mergeerror &&
	test_grep "does not have a GPG signature" mergeerror
'

test_done
