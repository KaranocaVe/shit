#!/bin/sh

test_description="Test bundle-uri with protocol v2 and 'shit://' transport"

TEST_NO_CREATE_REPO=1

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

# Test protocol v2 with 'shit://' transport
#
BUNDLE_URI_PROTOCOL=shit
. "$TEST_DIRECTORY"/lib-bundle-uri-protocol.sh

test_done
