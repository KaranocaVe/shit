#!/bin/sh

test_description='test fetching of oddly-named refs'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# afterwards we will have:
#  HEAD - two
#  refs/for/refs/heads/main - one
#  refs/heads/main - three
test_expect_success 'setup repo with odd suffix ref' '
	echo content >file &&
	shit add . &&
	shit commit -m one &&
	shit update-ref refs/for/refs/heads/main HEAD &&
	echo content >>file &&
	shit commit -a -m two &&
	echo content >>file &&
	shit commit -a -m three &&
	shit checkout HEAD^
'

test_expect_success 'suffix ref is ignored during fetch' '
	shit clone --bare file://"$PWD" suffix &&
	echo three >expect &&
	shit --shit-dir=suffix log -1 --format=%s refs/heads/main >actual &&
	test_cmp expect actual
'

test_expect_success 'try to create repo with absurdly long refname' '
	ref240=$ZERO_OID/$ZERO_OID/$ZERO_OID/$ZERO_OID/$ZERO_OID/$ZERO_OID &&
	ref1440=$ref240/$ref240/$ref240/$ref240/$ref240/$ref240 &&
	shit init long &&
	(
		cd long &&
		test_commit long &&
		test_commit main
	) &&
	if shit -C long update-ref refs/heads/$ref1440 long; then
		test_set_prereq LONG_REF
	else
		echo >&2 "long refs not supported"
	fi
'

test_expect_success LONG_REF 'fetch handles extremely long refname' '
	shit fetch long refs/heads/*:refs/remotes/long/* &&
	cat >expect <<-\EOF &&
	long
	main
	EOF
	shit for-each-ref --format="%(subject)" refs/remotes/long >actual &&
	test_cmp expect actual
'

test_expect_success LONG_REF 'defecate handles extremely long refname' '
	shit defecate long :refs/heads/$ref1440 &&
	shit -C long for-each-ref --format="%(subject)" refs/heads >actual &&
	echo main >expect &&
	test_cmp expect actual
'

test_done
