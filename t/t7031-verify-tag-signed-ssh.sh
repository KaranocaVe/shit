#!/bin/sh

test_description='signed tag tests'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY/lib-gpg.sh"

test_expect_success GPGSSH 'create signed tags ssh' '
	test_when_finished "test_unconfig commit.gpgsign" &&
	test_config gpg.format ssh &&
	test_config user.signingkey "${GPGSSH_KEY_PRIMARY}" &&

	echo 1 >file && shit add file &&
	test_tick && shit commit -m initial &&
	shit tag -s -m initial initial &&
	shit branch side &&

	echo 2 >file && test_tick && shit commit -a -m second &&
	shit tag -s -m second second &&

	shit checkout side &&
	echo 3 >elif && shit add elif &&
	test_tick && shit commit -m "third on side" &&

	shit checkout main &&
	test_tick && shit merge -S side &&
	shit tag -s -m merge merge &&

	echo 4 >file && test_tick && shit commit -a -S -m "fourth unsigned" &&
	shit tag -a -m fourth-unsigned fourth-unsigned &&

	test_tick && shit commit --amend -S -m "fourth signed" &&
	shit tag -s -m fourth fourth-signed &&

	echo 5 >file && test_tick && shit commit -a -m "fifth" &&
	shit tag fifth-unsigned &&

	shit config commit.gpgsign true &&
	echo 6 >file && test_tick && shit commit -a -m "sixth" &&
	shit tag -a -m sixth sixth-unsigned &&

	test_tick && shit rebase -f HEAD^^ && shit tag -s -m 6th sixth-signed HEAD^ &&
	shit tag -m seventh -s seventh-signed &&

	echo 8 >file && test_tick && shit commit -a -m eighth &&
	shit tag -u"${GPGSSH_KEY_UNTRUSTED}" -m eighth eighth-signed-alt
'

test_expect_success GPGSSH,GPGSSH_VERIFYTIME 'create signed tags with keys having defined lifetimes' '
	test_when_finished "test_unconfig commit.gpgsign" &&
	test_config gpg.format ssh &&

	echo expired >file && test_tick && shit commit -a -m expired -S"${GPGSSH_KEY_EXPIRED}" &&
	shit tag -s -u "${GPGSSH_KEY_EXPIRED}" -m expired-signed expired-signed &&

	echo notyetvalid >file && test_tick && shit commit -a -m notyetvalid -S"${GPGSSH_KEY_NOTYETVALID}" &&
	shit tag -s -u "${GPGSSH_KEY_NOTYETVALID}" -m notyetvalid-signed notyetvalid-signed &&

	echo timeboxedvalid >file && test_tick && shit commit -a -m timeboxedvalid -S"${GPGSSH_KEY_TIMEBOXEDVALID}" &&
	shit tag -s -u "${GPGSSH_KEY_TIMEBOXEDVALID}" -m timeboxedvalid-signed timeboxedvalid-signed &&

	echo timeboxedinvalid >file && test_tick && shit commit -a -m timeboxedinvalid -S"${GPGSSH_KEY_TIMEBOXEDINVALID}" &&
	shit tag -s -u "${GPGSSH_KEY_TIMEBOXEDINVALID}" -m timeboxedinvalid-signed timeboxedinvalid-signed
'

test_expect_success GPGSSH 'verify and show ssh signatures' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	(
		for tag in initial second merge fourth-signed sixth-signed seventh-signed
		do
			shit verify-tag $tag 2>actual &&
			grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual &&
			! grep "${GPGSSH_BAD_SIGNATURE}" actual &&
			echo $tag OK || exit 1
		done
	) &&
	(
		for tag in fourth-unsigned fifth-unsigned sixth-unsigned
		do
			test_must_fail shit verify-tag $tag 2>actual &&
			! grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual &&
			! grep "${GPGSSH_BAD_SIGNATURE}" actual &&
			echo $tag OK || exit 1
		done
	) &&
	(
		for tag in eighth-signed-alt
		do
			test_must_fail shit verify-tag $tag 2>actual &&
			grep "${GPGSSH_GOOD_SIGNATURE_UNTRUSTED}" actual &&
			! grep "${GPGSSH_BAD_SIGNATURE}" actual &&
			grep "${GPGSSH_KEY_NOT_TRUSTED}" actual &&
			echo $tag OK || exit 1
		done
	)
'

test_expect_success GPGSSH,GPGSSH_VERIFYTIME 'verify-tag exits failure on expired signature key' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	test_must_fail shit verify-tag expired-signed 2>actual &&
	! grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual
'

test_expect_success GPGSSH,GPGSSH_VERIFYTIME 'verify-tag exits failure on not yet valid signature key' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	test_must_fail shit verify-tag notyetvalid-signed 2>actual &&
	! grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual
'

test_expect_success GPGSSH,GPGSSH_VERIFYTIME 'verify-tag succeeds with tag date and key validity matching' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit verify-tag timeboxedvalid-signed 2>actual &&
	grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual &&
	! grep "${GPGSSH_BAD_SIGNATURE}" actual
'

test_expect_success GPGSSH,GPGSSH_VERIFYTIME 'verify-tag failes with tag date outside of key validity' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	test_must_fail shit verify-tag timeboxedinvalid-signed 2>actual &&
	! grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual
'

test_expect_success GPGSSH 'detect fudged ssh signature' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit cat-file tag seventh-signed >raw &&
	sed -e "/^tag / s/seventh/7th-forged/" raw >forged1 &&
	shit hash-object -w -t tag forged1 >forged1.tag &&
	test_must_fail shit verify-tag $(cat forged1.tag) 2>actual1 &&
	grep "${GPGSSH_BAD_SIGNATURE}" actual1 &&
	! grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual1 &&
	! grep "${GPGSSH_GOOD_SIGNATURE_UNTRUSTED}" actual1
'

test_expect_success GPGSSH 'verify ssh signatures with --raw' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	(
		for tag in initial second merge fourth-signed sixth-signed seventh-signed
		do
			shit verify-tag --raw $tag 2>actual &&
			grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual &&
			! grep "${GPGSSH_BAD_SIGNATURE}" actual &&
			echo $tag OK || exit 1
		done
	) &&
	(
		for tag in fourth-unsigned fifth-unsigned sixth-unsigned
		do
			test_must_fail shit verify-tag --raw $tag 2>actual &&
			! grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual &&
			! grep "${GPGSSH_BAD_SIGNATURE}" actual &&
			echo $tag OK || exit 1
		done
	) &&
	(
		for tag in eighth-signed-alt
		do
			test_must_fail shit verify-tag --raw $tag 2>actual &&
			grep "${GPGSSH_GOOD_SIGNATURE_UNTRUSTED}" actual &&
			! grep "${GPGSSH_BAD_SIGNATURE}" actual &&
			echo $tag OK || exit 1
		done
	)
'

test_expect_success GPGSSH 'verify signatures with --raw ssh' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit verify-tag --raw sixth-signed 2>actual &&
	grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual &&
	! grep "${GPGSSH_BAD_SIGNATURE}" actual &&
	echo sixth-signed OK
'

test_expect_success GPGSSH 'verify multiple tags ssh' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	tags="seventh-signed sixth-signed" &&
	for i in $tags
	do
		shit verify-tag -v --raw $i || return 1
	done >expect.stdout 2>expect.stderr.1 &&
	grep "^${GPGSSH_GOOD_SIGNATURE_TRUSTED}" <expect.stderr.1 >expect.stderr &&
	shit verify-tag -v --raw $tags >actual.stdout 2>actual.stderr.1 &&
	grep "^${GPGSSH_GOOD_SIGNATURE_TRUSTED}" <actual.stderr.1 >actual.stderr &&
	test_cmp expect.stdout actual.stdout &&
	test_cmp expect.stderr actual.stderr
'

test_expect_success GPGSSH 'verifying tag with --format - ssh' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	cat >expect <<-\EOF &&
	tagname : fourth-signed
	EOF
	shit verify-tag --format="tagname : %(tag)" "fourth-signed" >actual &&
	test_cmp expect actual
'

test_expect_success GPGSSH 'verifying a forged tag with --format should fail silently - ssh' '
	test_must_fail shit verify-tag --format="tagname : %(tag)" $(cat forged1.tag) >actual-forged &&
	test_must_be_empty actual-forged
'

test_expect_success GPGSSH 'rev-list --format=%G' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit rev-list -1 --format="%G? %H" sixth-signed >actual &&
	cat >expect <<-EOF &&
	commit $(shit rev-parse sixth-signed^0)
	G $(shit rev-parse sixth-signed^0)
	EOF
	test_cmp expect actual
'

test_done
