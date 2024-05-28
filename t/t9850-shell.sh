#!/bin/sh

test_description='shit shell tests'
. ./test-lib.sh

test_expect_success 'shell allows upload-pack' '
	printf 0000 >input &&
	shit upload-pack . <input >expect &&
	shit shell -c "shit-upload-pack $SQ.$SQ" <input >actual &&
	test_cmp expect actual
'

test_expect_success 'shell forbids other commands' '
	test_must_fail shit shell -c "shit config foo.bar baz"
'

test_expect_success 'shell forbids interactive use by default' '
	test_must_fail shit shell
'

test_expect_success 'shell allows interactive command' '
	mkdir shit-shell-commands &&
	write_script shit-shell-commands/ping <<-\EOF &&
	echo pong
	EOF
	echo pong >expect &&
	echo ping | shit shell >actual &&
	test_cmp expect actual
'

test_expect_success 'shell complains of overlong commands' '
	perl -e "print \"a\" x 2**12 for (0..2**19)" |
	test_must_fail shit shell 2>err &&
	grep "too long" err
'

test_done
