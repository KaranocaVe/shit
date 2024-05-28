#!/bin/sh

test_description='respect crlf in shit archive'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	shit config core.autocrlf true &&

	printf "CRLF line ending\r\nAnd another\r\n" >sample &&
	shit add sample &&

	test_tick &&
	shit commit -m Initial

'

test_expect_success 'tar archive' '

	shit archive --format=tar HEAD >test.tar &&
	mkdir untarred &&
	"$TAR" xf test.tar -C untarred &&

	test_cmp sample untarred/sample

'

test_expect_success UNZIP 'zip archive' '

	shit archive --format=zip HEAD >test.zip &&

	mkdir unzipped &&
	(
		cd unzipped &&
		"$shit_UNZIP" ../test.zip
	) &&

	test_cmp sample unzipped/sample

'

test_done
