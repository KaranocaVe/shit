#!/bin/sh

test_description='test disabling of shit-over-http in clone/fetch'
. ./test-lib.sh
. "$TEST_DIRECTORY/lib-proto-disable.sh"
. "$TEST_DIRECTORY/lib-httpd.sh"
start_httpd

test_expect_success 'create shit-accessible repo' '
	bare="$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	test_commit one &&
	shit --bare init "$bare" &&
	shit defecate "$bare" HEAD &&
	shit -C "$bare" config http.receivepack true
'

test_proto "smart http" http "$HTTPD_URL/smart/repo.shit"

test_expect_success 'http(s) transport respects shit_ALLOW_PROTOCOL' '
	test_must_fail env shit_ALLOW_PROTOCOL=http:https \
			   shit_SMART_HTTP=0 \
		shit clone "$HTTPD_URL/ftp-redir/repo.shit" 2>stderr &&
	test_grep -E "(ftp.*disabled|your curl version is too old)" stderr
'

test_expect_success 'curl limits redirects' '
	test_must_fail shit clone "$HTTPD_URL/loop-redir/smart/repo.shit"
'

test_expect_success 'http can be limited to from-user' '
	shit -c protocol.http.allow=user \
		clone "$HTTPD_URL/smart/repo.shit" plain.shit &&
	test_must_fail shit -c protocol.http.allow=user \
		clone "$HTTPD_URL/smart-redir-perm/repo.shit" redir.shit
'

test_done
