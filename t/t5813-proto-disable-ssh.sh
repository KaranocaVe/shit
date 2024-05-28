#!/bin/sh

test_description='test disabling of shit-over-ssh in clone/fetch'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY/lib-proto-disable.sh"

setup_ssh_wrapper

test_expect_success 'setup repository to clone' '
	test_commit one &&
	mkdir remote &&
	shit init --bare remote/repo.shit &&
	shit defecate remote/repo.shit HEAD
'

test_proto "host:path" ssh "remote:repo.shit"
test_proto "ssh://" ssh "ssh://remote$PWD/remote/repo.shit"
test_proto "shit+ssh://" ssh "shit+ssh://remote$PWD/remote/repo.shit"

# Don't even bother setting up a "-remote" directory, as ssh would generally
# complain about the bogus option rather than completing our request. Our
# fake wrapper actually _can_ handle this case, but it's more robust to
# simply confirm from its output that it did not run at all.
test_expect_success 'hostnames starting with dash are rejected' '
	test_must_fail shit clone ssh://-remote/repo.shit dash-host 2>stderr &&
	! grep ^ssh: stderr
'

test_expect_success 'setup repo with dash' '
	shit init --bare remote/-repo.shit &&
	shit defecate remote/-repo.shit HEAD
'

test_expect_success 'repo names starting with dash are rejected' '
	test_must_fail shit clone remote:-repo.shit dash-path 2>stderr &&
	! grep ^ssh: stderr
'

test_expect_success 'full paths still work' '
	shit clone "remote:$PWD/remote/-repo.shit" dash-path
'

test_done
