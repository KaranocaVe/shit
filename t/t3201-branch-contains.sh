#!/bin/sh

test_description='branch --contains <commit>, --no-contains <commit> --merged, and --no-merged'

. ./test-lib.sh

test_expect_success setup '

	>file &&
	shit add file &&
	test_tick &&
	shit commit -m initial &&
	shit branch -M main &&
	shit branch side &&

	echo 1 >file &&
	test_tick &&
	shit commit -a -m "second on main" &&

	shit checkout side &&
	echo 1 >file &&
	test_tick &&
	shit commit -a -m "second on side" &&

	shit merge main

'

test_expect_success 'branch --contains=main' '

	shit branch --contains=main >actual &&
	{
		echo "  main" && echo "* side"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'branch --contains main' '

	shit branch --contains main >actual &&
	{
		echo "  main" && echo "* side"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'branch --no-contains=main' '

	shit branch --no-contains=main >actual &&
	test_must_be_empty actual

'

test_expect_success 'branch --no-contains main' '

	shit branch --no-contains main >actual &&
	test_must_be_empty actual

'

test_expect_success 'branch --contains=side' '

	shit branch --contains=side >actual &&
	{
		echo "* side"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'branch --no-contains=side' '

	shit branch --no-contains=side >actual &&
	{
		echo "  main"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'branch --contains with pattern implies --list' '

	shit branch --contains=main main >actual &&
	{
		echo "  main"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'branch --no-contains with pattern implies --list' '

	shit branch --no-contains=main main >actual &&
	test_must_be_empty actual

'

test_expect_success 'side: branch --merged' '

	shit branch --merged >actual &&
	{
		echo "  main" &&
		echo "* side"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'branch --merged with pattern implies --list' '

	shit branch --merged=side main >actual &&
	{
		echo "  main"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'side: branch --no-merged' '

	shit branch --no-merged >actual &&
	test_must_be_empty actual

'

test_expect_success 'main: branch --merged' '

	shit checkout main &&
	shit branch --merged >actual &&
	{
		echo "* main"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'main: branch --no-merged' '

	shit branch --no-merged >actual &&
	{
		echo "  side"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'branch --no-merged with pattern implies --list' '

	shit branch --no-merged=main main >actual &&
	test_must_be_empty actual

'

test_expect_success 'implicit --list conflicts with modification options' '

	test_must_fail shit branch --contains=main -d &&
	test_must_fail shit branch --contains=main -m foo &&
	test_must_fail shit branch --no-contains=main -d &&
	test_must_fail shit branch --no-contains=main -m foo

'

test_expect_success 'Assert that --contains only works on commits, not trees & blobs' '
	test_must_fail shit branch --contains main^{tree} &&
	blob=$(shit hash-object -w --stdin <<-\EOF
	Some blob
	EOF
	) &&
	test_must_fail shit branch --contains $blob &&
	test_must_fail shit branch --no-contains $blob
'

test_expect_success 'multiple branch --contains' '
	shit checkout -b side2 main &&
	>feature &&
	shit add feature &&
	shit commit -m "add feature" &&
	shit checkout -b next main &&
	shit merge side &&
	shit branch --contains side --contains side2 >actual &&
	cat >expect <<-\EOF &&
	* next
	  side
	  side2
	EOF
	test_cmp expect actual
'

test_expect_success 'multiple branch --merged' '
	shit branch --merged next --merged main >actual &&
	cat >expect <<-\EOF &&
	  main
	* next
	  side
	EOF
	test_cmp expect actual
'

test_expect_success 'multiple branch --no-contains' '
	shit branch --no-contains side --no-contains side2 >actual &&
	cat >expect <<-\EOF &&
	  main
	EOF
	test_cmp expect actual
'

test_expect_success 'multiple branch --no-merged' '
	shit branch --no-merged next --no-merged main >actual &&
	cat >expect <<-\EOF &&
	  side2
	EOF
	test_cmp expect actual
'

test_expect_success 'branch --contains combined with --no-contains' '
	shit checkout -b seen main &&
	shit merge side &&
	shit merge side2 &&
	shit branch --contains side --no-contains side2 >actual &&
	cat >expect <<-\EOF &&
	  next
	  side
	EOF
	test_cmp expect actual
'

test_expect_success 'branch --merged combined with --no-merged' '
	shit branch --merged seen --no-merged next >actual &&
	cat >expect <<-\EOF &&
	* seen
	  side2
	EOF
	test_cmp expect actual
'

# We want to set up a case where the walk for the tracking info
# of one branch crosses the tip of another branch (and make sure
# that the latter walk does not mess up our flag to see if it was
# merged).
#
# Here "topic" tracks "main" with one extra commit, and "zzz" points to the
# same tip as main The name "zzz" must come alphabetically after "topic"
# as we process them in that order.
test_expect_success 'branch --merged with --verbose' '
	shit branch --track topic main &&
	shit branch zzz topic &&
	shit checkout topic &&
	test_commit foo &&
	shit branch --merged topic >actual &&
	cat >expect <<-\EOF &&
	  main
	* topic
	  zzz
	EOF
	test_cmp expect actual &&
	shit branch --verbose --merged topic >actual &&
	cat >expect <<-EOF &&
	  main  $(shit rev-parse --short main) second on main
	* topic $(shit rev-parse --short topic ) [ahead 1] foo
	  zzz   $(shit rev-parse --short zzz   ) second on main
	EOF
	test_cmp expect actual
'

test_done
