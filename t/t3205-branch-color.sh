#!/bin/sh

test_description='basic branch output coloring'
TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'set up some sample branches' '
	test_commit foo &&
	shit branch -M main &&
	shit update-ref refs/remotes/origin/main HEAD &&
	shit update-ref refs/heads/other HEAD
'

# choose non-default colors to make sure config
# is taking effect
test_expect_success 'set up some color config' '
	shit config color.branch.local blue &&
	shit config color.branch.remote yellow &&
	shit config color.branch.current cyan
'

test_expect_success 'regular output shows colors' '
	cat >expect <<-\EOF &&
	* <CYAN>main<RESET>
	  <BLUE>other<RESET>
	  <YELLOW>remotes/origin/main<RESET>
	EOF
	shit branch --color -a >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect actual
'

test_expect_success 'verbose output shows colors' '
	oid=$(shit rev-parse --short HEAD) &&
	cat >expect <<-EOF &&
	* <CYAN>main               <RESET> $oid foo
	  <BLUE>other              <RESET> $oid foo
	  <YELLOW>remotes/origin/main<RESET> $oid foo
	EOF
	shit branch --color -v -a >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect actual
'

test_done
