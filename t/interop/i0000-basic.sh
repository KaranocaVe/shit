#!/bin/sh

# Note that this test only works on real version numbers,
# as it depends on matching the output to "shit version".
VERSION_A=v1.6.6.3
VERSION_B=v2.11.1

test_description='sanity test interop library'
. ./interop-lib.sh

test_expect_success 'bare shit is forbidden' '
	test_must_fail shit version
'

test_expect_success "shit.a version ($VERSION_A)" '
	echo shit version ${VERSION_A#v} >expect &&
	shit.a version >actual &&
	test_cmp expect actual
'

test_expect_success "shit.b version ($VERSION_B)" '
	echo shit version ${VERSION_B#v} >expect &&
	shit.b version >actual &&
	test_cmp expect actual
'

test_done
