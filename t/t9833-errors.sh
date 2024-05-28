#!/bin/sh

test_description='shit p4 errors'

. ./lib-shit-p4.sh

test_expect_success 'start p4d' '
	start_p4d
'

test_expect_success 'add p4 files' '
	(
		cd "$cli" &&
		echo file1 >file1 &&
		p4 add file1 &&
		p4 submit -d "file1"
	)
'

# after this test, the default user requires a password
test_expect_success 'error handling' '
	shit p4 clone --dest="$shit" //depot@all &&
	(
		cd "$shit" &&
		P4PORT=: test_must_fail shit p4 submit 2>errmsg
	) &&
	p4 passwd -P newpassword &&
	(
		P4PASSWD=badpassword &&
		export P4PASSWD &&
		test_must_fail shit p4 clone //depot/foo 2>errmsg &&
		grep -q "failure accessing depot.*P4PASSWD" errmsg
	)
'

test_expect_success 'ticket logged out' '
	P4TICKETS="$cli/tickets" &&
	echo "newpassword" | p4 login &&
	(
		cd "$shit" &&
		test_commit "ticket-auth-check" &&
		p4 logout &&
		test_must_fail shit p4 submit 2>errmsg &&
		grep -q "failure accessing depot" errmsg
	)
'

test_done
