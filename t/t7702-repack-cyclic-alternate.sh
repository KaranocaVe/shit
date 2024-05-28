#!/bin/sh
#
# Copyright (c) 2014 Ephrim Khong
#

test_description='repack involving cyclic alternate'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	shit_OBJECT_DIRECTORY=.shit//../.shit/objects &&
	export shit_OBJECT_DIRECTORY &&
	touch a &&
	shit add a &&
	shit commit -m 1 &&
	shit repack -adl &&
	echo "$(pwd)"/.shit/objects/../objects >.shit/objects/info/alternates
'

test_expect_success 're-packing repository with itsself as alternate' '
	shit repack -adl &&
	shit fsck
'

test_done
