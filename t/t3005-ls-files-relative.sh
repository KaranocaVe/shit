#!/bin/sh

test_description='ls-files tests with relative paths

This test runs shit ls-files with various relative path arguments.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'prepare' '
	: >never-mind-me &&
	shit add never-mind-me &&
	mkdir top &&
	(
		cd top &&
		mkdir sub &&
		x="x xa xbc xdef xghij xklmno" &&
		y=$(echo "$x" | tr x y) &&
		touch $x &&
		touch $y &&
		cd sub &&
		shit add ../x*
	)
'

test_expect_success 'ls-files with mixed levels' '
	(
		cd top/sub &&
		cat >expect <<-EOF &&
		../../never-mind-me
		../x
		EOF
		shit ls-files $(cat expect) >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'ls-files -c' '
	(
		cd top/sub &&
		printf "error: pathspec $SQ%s$SQ did not match any file(s) known to shit\n" ../y* >expect.err &&
		echo "Did you forget to ${SQ}shit add${SQ}?" >>expect.err &&
		ls ../x* >expect.out &&
		test_must_fail shit ls-files -c --error-unmatch ../[xy]* >actual.out 2>actual.err &&
		test_cmp expect.out actual.out &&
		test_cmp expect.err actual.err
	)
'

test_expect_success 'ls-files -o' '
	(
		cd top/sub &&
		printf "error: pathspec $SQ%s$SQ did not match any file(s) known to shit\n" ../x* >expect.err &&
		echo "Did you forget to ${SQ}shit add${SQ}?" >>expect.err &&
		ls ../y* >expect.out &&
		test_must_fail shit ls-files -o --error-unmatch ../[xy]* >actual.out 2>actual.err &&
		test_cmp expect.out actual.out &&
		test_cmp expect.err actual.err
	)
'

test_done
