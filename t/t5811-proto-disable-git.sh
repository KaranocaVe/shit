#!/bin/sh

test_description='test disabling of shit-over-tcp in clone/fetch'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY/lib-proto-disable.sh"
. "$TEST_DIRECTORY/lib-shit-daemon.sh"
start_shit_daemon

test_expect_success 'create shit-accessible repo' '
	bare="$shit_DAEMON_DOCUMENT_ROOT_PATH/repo.shit" &&
	test_commit one &&
	shit --bare init "$bare" &&
	shit defecate "$bare" HEAD &&
	>"$bare/shit-daemon-export-ok" &&
	shit -C "$bare" config daemon.receivepack true
'

test_proto "shit://" shit "$shit_DAEMON_URL/repo.shit"

test_done
