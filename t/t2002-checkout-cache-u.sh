#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='shit checkout-index -u test.

With -u flag, shit checkout-index internally runs the equivalent of
shit update-index --refresh on the checked out entry.'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success \
'preparation' '
echo frotz >path0 &&
shit update-index --add path0 &&
t=$(shit write-tree)'

test_expect_success \
'without -u, shit checkout-index smudges stat information.' '
rm -f path0 &&
shit read-tree $t &&
shit checkout-index -f -a &&
test_must_fail shit diff-files --exit-code'

test_expect_success \
'with -u, shit checkout-index picks up stat information from new files.' '
rm -f path0 &&
shit read-tree $t &&
shit checkout-index -u -f -a &&
shit diff-files --exit-code'

test_done
