#!/bin/sh

test_description='test shit_CURL_VERBOSE'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-httpd.sh
start_httpd

test_expect_success 'setup repository' '
	mkdir "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" --bare init &&
	shit config defecate.default matching &&
	echo content >file &&
	shit add file &&
	shit commit -m one &&
	shit remote add public "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	shit defecate public main:main
'

test_expect_success 'failure in shit-upload-pack is shown' '
	test_might_fail env shit_CURL_VERBOSE=1 \
		shit clone "$HTTPD_URL/error_shit_upload_pack/smart/repo.shit" \
		2>curl_log &&
	grep "<= Recv header: HTTP/1.1 500 Intentional Breakage" curl_log
'

test_done
