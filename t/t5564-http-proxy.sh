#!/bin/sh

test_description="test fetching through http proxy"

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-httpd.sh

LIB_HTTPD_PROXY=1
start_httpd

test_expect_success 'setup repository' '
	test_commit foo &&
	shit init --bare "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	shit defecate --mirror "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit"
'

setup_askpass_helper

# sanity check that our test setup is correctly using proxy
test_expect_success 'proxy requires password' '
	test_config_global http.proxy $HTTPD_DEST &&
	test_must_fail shit clone $HTTPD_URL/smart/repo.shit 2>err &&
	grep "error.*407" err
'

test_expect_success 'clone through proxy with auth' '
	test_when_finished "rm -rf clone" &&
	test_config_global http.proxy http://proxuser:proxpass@$HTTPD_DEST &&
	shit_TRACE_CURL=$PWD/trace shit clone $HTTPD_URL/smart/repo.shit clone &&
	grep -i "Proxy-Authorization: Basic <redacted>" trace
'

test_expect_success 'clone can prompt for proxy password' '
	test_when_finished "rm -rf clone" &&
	test_config_global http.proxy http://proxuser@$HTTPD_DEST &&
	set_askpass nobody proxpass &&
	shit_TRACE_CURL=$PWD/trace shit clone $HTTPD_URL/smart/repo.shit clone &&
	expect_askpass pass proxuser
'

test_done
