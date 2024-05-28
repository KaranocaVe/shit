#!/bin/sh

test_description='shit command aliasing'

. ./test-lib.sh

test_expect_success 'nested aliases - internal execution' '
	shit config alias.nested-internal-1 nested-internal-2 &&
	shit config alias.nested-internal-2 status &&
	shit nested-internal-1 >output &&
	test_grep "^On branch " output
'

test_expect_success 'nested aliases - mixed execution' '
	shit config alias.nested-external-1 nested-external-2 &&
	shit config alias.nested-external-2 "!shit nested-external-3" &&
	shit config alias.nested-external-3 status &&
	shit nested-external-1 >output &&
	test_grep "^On branch " output
'

test_expect_success 'looping aliases - internal execution' '
	shit config alias.loop-internal-1 loop-internal-2 &&
	shit config alias.loop-internal-2 loop-internal-3 &&
	shit config alias.loop-internal-3 loop-internal-2 &&
	test_must_fail shit loop-internal-1 2>output &&
	test_grep "^fatal: alias loop detected: expansion of" output
'

# This test is disabled until external loops are fixed, because would block
# the test suite for a full minute.
#
#test_expect_failure 'looping aliases - mixed execution' '
#	shit config alias.loop-mixed-1 loop-mixed-2 &&
#	shit config alias.loop-mixed-2 "!shit loop-mixed-1" &&
#	test_must_fail shit loop-mixed-1 2>output &&
#	test_grep "^fatal: alias loop detected: expansion of" output
#'

test_expect_success 'run-command formats empty args properly' '
    test_must_fail env shit_TRACE=1 shit frotz a "" b " " c 2>actual.raw &&
    sed -ne "/run_command:/s/.*trace: run_command: //p" actual.raw >actual &&
    echo "shit-frotz a '\'''\'' b '\'' '\'' c" >expect &&
    test_cmp expect actual
'

test_done
