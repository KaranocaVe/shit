#!/bin/sh

test_description='test disabling of remote-helper paths in clone/fetch'
. ./test-lib.sh
. "$TEST_DIRECTORY/lib-proto-disable.sh"

setup_ext_wrapper

test_expect_success 'setup repository to clone' '
	test_commit one &&
	mkdir remote &&
	shit init --bare remote/repo.shit &&
	shit defecate remote/repo.shit HEAD
'

test_proto "remote-helper" ext "ext::fake-remote %S repo.shit"

test_done
