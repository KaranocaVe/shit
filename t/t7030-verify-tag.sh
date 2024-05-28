#!/bin/sh

test_description='signed tag tests'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY/lib-gpg.sh"

test_expect_success GPG 'create signed tags' '
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
	shit tag -uB7227189 -m eighth eighth-signed-alt
'

test_expect_success GPGSM 'create signed tags x509 ' '
	test_config gpg.format x509 &&
	test_config user.signingkey $shit_COMMITTER_EMAIL &&
	echo 9 >file && test_tick && shit commit -a -m "ninth gpgsm-signed" &&
	shit tag -s -m ninth ninth-signed-x509
'

test_expect_success GPG 'verify and show signatures' '
	(
		for tag in initial second merge fourth-signed sixth-signed seventh-signed
		do
			shit verify-tag $tag 2>actual &&
			grep "Good signature from" actual &&
			! grep "BAD signature from" actual &&
			echo $tag OK || exit 1
		done
	) &&
	(
		for tag in fourth-unsigned fifth-unsigned sixth-unsigned
		do
			test_must_fail shit verify-tag $tag 2>actual &&
			! grep "Good signature from" actual &&
			! grep "BAD signature from" actual &&
			echo $tag OK || exit 1
		done
	) &&
	(
		for tag in eighth-signed-alt
		do
			shit verify-tag $tag 2>actual &&
			grep "Good signature from" actual &&
			! grep "BAD signature from" actual &&
			grep "not certified" actual &&
			echo $tag OK || exit 1
		done
	)
'

test_expect_success GPGSM 'verify and show signatures x509' '
	shit verify-tag ninth-signed-x509 2>actual &&
	grep "Good signature from" actual &&
	! grep "BAD signature from" actual &&
	echo ninth-signed-x509 OK
'

test_expect_success GPGSM 'verify and show signatures x509 with low minTrustLevel' '
	test_config gpg.minTrustLevel undefined &&
	shit verify-tag ninth-signed-x509 2>actual &&
	grep "Good signature from" actual &&
	! grep "BAD signature from" actual &&
	echo ninth-signed-x509 OK
'

test_expect_success GPGSM 'verify and show signatures x509 with matching minTrustLevel' '
	test_config gpg.minTrustLevel fully &&
	shit verify-tag ninth-signed-x509 2>actual &&
	grep "Good signature from" actual &&
	! grep "BAD signature from" actual &&
	echo ninth-signed-x509 OK
'

test_expect_success GPGSM 'verify and show signatures x509 with high minTrustLevel' '
	test_config gpg.minTrustLevel ultimate &&
	test_must_fail shit verify-tag ninth-signed-x509 2>actual &&
	grep "Good signature from" actual &&
	! grep "BAD signature from" actual &&
	echo ninth-signed-x509 OK
'

test_expect_success GPG 'detect fudged signature' '
	shit cat-file tag seventh-signed >raw &&
	sed -e "/^tag / s/seventh/7th-forged/" raw >forged1 &&
	shit hash-object -w -t tag forged1 >forged1.tag &&
	test_must_fail shit verify-tag $(cat forged1.tag) 2>actual1 &&
	grep "BAD signature from" actual1 &&
	! grep "Good signature from" actual1
'

test_expect_success GPG 'verify signatures with --raw' '
	(
		for tag in initial second merge fourth-signed sixth-signed seventh-signed
		do
			shit verify-tag --raw $tag 2>actual &&
			grep "GOODSIG" actual &&
			! grep "BADSIG" actual &&
			echo $tag OK || exit 1
		done
	) &&
	(
		for tag in fourth-unsigned fifth-unsigned sixth-unsigned
		do
			test_must_fail shit verify-tag --raw $tag 2>actual &&
			! grep "GOODSIG" actual &&
			! grep "BADSIG" actual &&
			echo $tag OK || exit 1
		done
	) &&
	(
		for tag in eighth-signed-alt
		do
			shit verify-tag --raw $tag 2>actual &&
			grep "GOODSIG" actual &&
			! grep "BADSIG" actual &&
			grep "TRUST_UNDEFINED" actual &&
			echo $tag OK || exit 1
		done
	)
'

test_expect_success GPGSM 'verify signatures with --raw x509' '
	shit verify-tag --raw ninth-signed-x509 2>actual &&
	grep "GOODSIG" actual &&
	! grep "BADSIG" actual &&
	echo ninth-signed-x509 OK
'

test_expect_success GPG 'verify multiple tags' '
	tags="fourth-signed sixth-signed seventh-signed" &&
	for i in $tags
	do
		shit verify-tag -v --raw $i || return 1
	done >expect.stdout 2>expect.stderr.1 &&
	grep "^.GNUPG:." <expect.stderr.1 >expect.stderr &&
	shit verify-tag -v --raw $tags >actual.stdout 2>actual.stderr.1 &&
	grep "^.GNUPG:." <actual.stderr.1 >actual.stderr &&
	test_cmp expect.stdout actual.stdout &&
	test_cmp expect.stderr actual.stderr
'

test_expect_success GPGSM 'verify multiple tags x509' '
	tags="seventh-signed ninth-signed-x509" &&
	for i in $tags
	do
		shit verify-tag -v --raw $i || return 1
	done >expect.stdout 2>expect.stderr.1 &&
	grep "^.GNUPG:." <expect.stderr.1 >expect.stderr &&
	shit verify-tag -v --raw $tags >actual.stdout 2>actual.stderr.1 &&
	grep "^.GNUPG:." <actual.stderr.1 >actual.stderr &&
	test_cmp expect.stdout actual.stdout &&
	test_cmp expect.stderr actual.stderr
'

test_expect_success GPG 'verifying tag with --format' '
	cat >expect <<-\EOF &&
	tagname : fourth-signed
	EOF
	shit verify-tag --format="tagname : %(tag)" "fourth-signed" >actual &&
	test_cmp expect actual
'

test_expect_success GPG 'verifying tag with --format="%(rest)" must fail' '
	test_must_fail shit verify-tag --format="%(rest)" "fourth-signed"
'

test_expect_success GPG 'verifying a forged tag with --format should fail silently' '
	test_must_fail shit verify-tag --format="tagname : %(tag)" $(cat forged1.tag) >actual-forged &&
	test_must_be_empty actual-forged
'

test_done
