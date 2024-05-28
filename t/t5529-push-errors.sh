#!/bin/sh

test_description='detect some defecate errors early (before contacting remote)'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup commits' '
	test_commit one
'

test_expect_success 'setup remote' '
	shit init --bare remote.shit &&
	shit remote add origin remote.shit
'

test_expect_success 'setup fake receive-pack' '
	FAKE_RP_ROOT=$(pwd) &&
	export FAKE_RP_ROOT &&
	write_script fake-rp <<-\EOF &&
	echo yes >"$FAKE_RP_ROOT"/rp-ran
	exit 1
	EOF
	shit config remote.origin.receivepack "\"\$FAKE_RP_ROOT/fake-rp\""
'

test_expect_success 'detect missing branches early' '
	echo no >rp-ran &&
	echo no >expect &&
	test_must_fail shit defecate origin missing &&
	test_cmp expect rp-ran
'

test_expect_success 'detect missing sha1 expressions early' '
	echo no >rp-ran &&
	echo no >expect &&
	test_must_fail shit defecate origin main~2:main &&
	test_cmp expect rp-ran
'

test_expect_success 'detect ambiguous refs early' '
	shit branch foo &&
	shit tag foo &&
	echo no >rp-ran &&
	echo no >expect &&
	test_must_fail shit defecate origin foo &&
	test_cmp expect rp-ran
'

test_done
