#!/bin/sh

test_description='Test shit config in different settings (with --default)'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'uses --default when entry missing' '
	echo quux >expect &&
	shit config -f config --default=quux core.foo >actual &&
	test_cmp expect actual
'

test_expect_success 'does not use --default when entry present' '
	echo bar >expect &&
	shit -c core.foo=bar config --default=baz core.foo >actual &&
	test_cmp expect actual
'

test_expect_success 'canonicalizes --default with appropriate type' '
	echo true >expect &&
	shit config -f config --default=yes --bool core.foo >actual &&
	test_cmp expect actual
'

test_expect_success 'dies when --default cannot be parsed' '
	test_must_fail shit config -f config --type=expiry-date --default=x --get \
		not.a.section 2>error &&
	test_grep "failed to format default config value" error
'

test_expect_success 'does not allow --default without --get' '
	test_must_fail shit config --default=quux --unset a.section >output 2>&1 &&
	test_grep "\-\-default is only applicable to" output
'

test_done
