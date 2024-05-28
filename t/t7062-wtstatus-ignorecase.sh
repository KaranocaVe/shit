#!/bin/sh

test_description='shit-status with core.ignorecase=true'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'status with hash collisions' '
	# note: "V/", "V/XQANY/" and "WURZAUP/" produce the same hash code
	# in name-hash.c::hash_name
	mkdir V &&
	mkdir V/XQANY &&
	mkdir WURZAUP &&
	touch V/XQANY/test &&
	shit config core.ignorecase true &&
	shit add . &&
	# test is successful if shit status completes (no endless loop)
	shit status
'

test_done
