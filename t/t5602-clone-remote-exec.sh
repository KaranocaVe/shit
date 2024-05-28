#!/bin/sh

test_description=clone

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	echo "#!/bin/sh" > not_ssh &&
	echo "echo \"\$*\" > not_ssh_output" >> not_ssh &&
	echo "exit 1" >> not_ssh &&
	chmod +x not_ssh
'

test_expect_success 'clone calls shit upload-pack unqualified with no -u option' '
	test_must_fail env shit_SSH=./not_ssh shit clone localhost:/path/to/repo junk &&
	echo "localhost shit-upload-pack '\''/path/to/repo'\''" >expected &&
	test_cmp expected not_ssh_output
'

test_expect_success 'clone calls specified shit upload-pack with -u option' '
	test_must_fail env shit_SSH=./not_ssh \
		shit clone -u ./something/bin/shit-upload-pack localhost:/path/to/repo junk &&
	echo "localhost ./something/bin/shit-upload-pack '\''/path/to/repo'\''" >expected &&
	test_cmp expected not_ssh_output
'

test_done
