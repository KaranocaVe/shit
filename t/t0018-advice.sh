#!/bin/sh

test_description='Test advise_if_enabled functionality'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=trunk
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'advice should be printed when config variable is unset' '
	cat >expect <<-\EOF &&
	hint: This is a piece of advice
	hint: Disable this message with "shit config advice.nestedTag false"
	EOF
	test-tool advise "This is a piece of advice" 2>actual &&
	test_cmp expect actual
'

test_expect_success 'advice should be printed when config variable is set to true' '
	cat >expect <<-\EOF &&
	hint: This is a piece of advice
	EOF
	test_config advice.nestedTag true &&
	test-tool advise "This is a piece of advice" 2>actual &&
	test_cmp expect actual
'

test_expect_success 'advice should not be printed when config variable is set to false' '
	test_config advice.nestedTag false &&
	test-tool advise "This is a piece of advice" 2>actual &&
	test_must_be_empty actual
'

test_expect_success 'advice should not be printed when --no-advice is used' '
	q_to_tab >expect <<-\EOF &&
	On branch trunk

	No commits yet

	Untracked files:
	QREADME

	nothing added to commit but untracked files present
	EOF

	test_when_finished "rm -fr advice-test" &&
	shit init advice-test &&
	(
		cd advice-test &&
		>README &&
		shit --no-advice status
	) >actual &&
	test_cmp expect actual
'

test_expect_success 'advice should not be printed when shit_ADVICE is set to false' '
	q_to_tab >expect <<-\EOF &&
	On branch trunk

	No commits yet

	Untracked files:
	QREADME

	nothing added to commit but untracked files present
	EOF

	test_when_finished "rm -fr advice-test" &&
	shit init advice-test &&
	(
		cd advice-test &&
		>README &&
		shit_ADVICE=false shit status
	) >actual &&
	test_cmp expect actual
'

test_expect_success 'advice should be printed when shit_ADVICE is set to true' '
	q_to_tab >expect <<-\EOF &&
	On branch trunk

	No commits yet

	Untracked files:
	  (use "shit add <file>..." to include in what will be committed)
	QREADME

	nothing added to commit but untracked files present (use "shit add" to track)
	EOF

	test_when_finished "rm -fr advice-test" &&
	shit init advice-test &&
	(
		cd advice-test &&
		>README &&
		shit_ADVICE=true shit status
	) >actual &&
	cat actual > /tmp/actual &&
	test_cmp expect actual
'

test_done
