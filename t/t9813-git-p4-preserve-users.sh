#!/bin/sh

test_description='shit p4 preserve users'

. ./lib-shit-p4.sh

test_expect_success 'start p4d' '
	start_p4d
'

test_expect_success 'create files' '
	(
		cd "$cli" &&
		p4 client -o | sed "/LineEnd/s/:.*/:unix/" | p4 client -i &&
		echo file1 >file1 &&
		echo file2 >file2 &&
		p4 add file1 file2 &&
		p4 submit -d "add files"
	)
'

p4_grant_admin() {
	name=$1 &&
	{
		p4 protect -o &&
		echo "    admin user $name * //depot/..."
	} | p4 protect -i
}

p4_check_commit_author() {
	file=$1 user=$2 &&
	p4 changes -m 1 //depot/$file | grep -q $user
}

make_change_by_user() {
	file=$1 name=$2 email=$3 &&
	echo "username: a change by $name" >>"$file" &&
	shit add "$file" &&
	shit commit --author "$name <$email>" -m "a change by $name"
}

# Test username support, submitting as user 'alice'
test_expect_success 'preserve users' '
	p4_add_user alice &&
	p4_add_user bob &&
	p4_grant_admin alice &&
	shit p4 clone --dest="$shit" //depot &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		echo "username: a change by alice" >>file1 &&
		echo "username: a change by bob" >>file2 &&
		shit commit --author "Alice <alice@example.com>" -m "a change by alice" file1 &&
		shit commit --author "Bob <bob@example.com>" -m "a change by bob" file2 &&
		shit config shit-p4.skipSubmitEditCheck true &&
		P4EDITOR="test-tool chmtime +5" P4USER=alice P4PASSWD=secret &&
		export P4EDITOR P4USER P4PASSWD &&
		shit p4 commit --preserve-user &&
		p4_check_commit_author file1 alice &&
		p4_check_commit_author file2 bob
	)
'

# Test username support, submitting as bob, who lacks admin rights. Should
# not submit change to p4 (shit diff should show deltas).
test_expect_success 'refuse to preserve users without perms' '
	shit p4 clone --dest="$shit" //depot &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit config shit-p4.skipSubmitEditCheck true &&
		echo "username-noperms: a change by alice" >>file1 &&
		shit commit --author "Alice <alice@example.com>" -m "perms: a change by alice" file1 &&
		P4EDITOR="test-tool chmtime +5" P4USER=bob P4PASSWD=secret &&
		export P4EDITOR P4USER P4PASSWD &&
		test_must_fail shit p4 commit --preserve-user &&
		! shit diff --exit-code HEAD..p4/master
	)
'

# What happens with unknown author? Without allowMissingP4Users it should fail.
test_expect_success 'preserve user where author is unknown to p4' '
	shit p4 clone --dest="$shit" //depot &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit config shit-p4.skipSubmitEditCheck true &&
		echo "username-bob: a change by bob" >>file1 &&
		shit commit --author "Bob <bob@example.com>" -m "preserve: a change by bob" file1 &&
		echo "username-unknown: a change by charlie" >>file1 &&
		shit commit --author "Charlie <charlie@example.com>" -m "preserve: a change by charlie" file1 &&
		P4EDITOR="test-tool chmtime +5" P4USER=alice P4PASSWD=secret &&
		export P4EDITOR P4USER P4PASSWD &&
		test_must_fail shit p4 commit --preserve-user &&
		! shit diff --exit-code HEAD..p4/master &&

		echo "$0: repeat with allowMissingP4Users enabled" &&
		shit config shit-p4.allowMissingP4Users true &&
		shit config shit-p4.preserveUser true &&
		shit p4 commit &&
		shit diff --exit-code HEAD..p4/master &&
		p4_check_commit_author file1 alice
	)
'

# If we're *not* using --preserve-user, shit-p4 should warn if we're submitting
# changes that are not all ours.
# Test: user in p4 and user unknown to p4.
# Test: warning disabled and user is the same.
test_expect_success 'not preserving user with mixed authorship' '
	shit p4 clone --dest="$shit" //depot &&
	test_when_finished cleanup_shit &&
	(
		cd "$shit" &&
		shit config shit-p4.skipSubmitEditCheck true &&
		p4_add_user derek &&

		make_change_by_user usernamefile3 Derek derek@example.com &&
		P4EDITOR=cat P4USER=alice P4PASSWD=secret &&
		export P4EDITOR P4USER P4PASSWD &&
		shit p4 commit >actual &&
		grep "shit author derek@example.com does not match" actual &&

		make_change_by_user usernamefile3 Charlie charlie@example.com &&
		shit p4 commit >actual &&
		grep "shit author charlie@example.com does not match" actual &&

		make_change_by_user usernamefile3 alice alice@example.com &&
		shit p4 commit >actual &&
		! grep "shit author.*does not match" actual &&

		shit config shit-p4.skipUserNameCheck true &&
		make_change_by_user usernamefile3 Charlie charlie@example.com &&
		shit p4 commit >actual &&
		! grep "shit author.*does not match" actual &&

		p4_check_commit_author usernamefile3 alice
	)
'

test_done
