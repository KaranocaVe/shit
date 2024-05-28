#!/bin/sh

test_description='help.autocorrect finding a match'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	# An alias
	shit config alias.lgf "log --format=%s --first-parent" &&

	# A random user-defined command
	write_script shit-distimdistim <<-EOF &&
		echo distimdistim was called
	EOF

	PATH="$PATH:." &&
	export PATH &&

	shit commit --allow-empty -m "a single log entry" &&

	# Sanity check
	shit lgf >actual &&
	echo "a single log entry" >expect &&
	test_cmp expect actual &&

	shit distimdistim >actual &&
	echo "distimdistim was called" >expect &&
	test_cmp expect actual
'

test_expect_success 'autocorrect showing candidates' '
	shit config help.autocorrect 0 &&

	test_must_fail shit lfg 2>actual &&
	grep "^	lgf" actual &&

	test_must_fail shit distimdist 2>actual &&
	grep "^	distimdistim" actual
'

for immediate in -1 immediate
do
	test_expect_success 'autocorrect running commands' '
		shit config help.autocorrect $immediate &&

		shit lfg >actual &&
		echo "a single log entry" >expect &&
		test_cmp expect actual &&

		shit distimdist >actual &&
		echo "distimdistim was called" >expect &&
		test_cmp expect actual
	'
done

test_expect_success 'autocorrect can be declined altogether' '
	shit config help.autocorrect never &&

	test_must_fail shit lfg 2>actual &&
	grep "is not a shit command" actual &&
	test_line_count = 1 actual
'

test_expect_success 'autocorrect works in work tree created from bare repo' '
	shit clone --bare . bare.shit &&
	shit -C bare.shit worktree add ../worktree &&
	shit -C worktree -c help.autocorrect=immediate stauts
'

test_done
