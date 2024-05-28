#!/bin/sh
#
# Copyright (c) 2008 Alec Berryman

test_description='shit svn fetch repository with deleted and readded directory'

. ./lib-shit-svn.sh

# Don't run this by default; it opens up a port.
require_svnserve

test_expect_success 'load repository' '
    svnadmin load -q "$rawsvnrepo" < "$TEST_DIRECTORY"/t9126/follow-deleted-readded.dump
    '

test_expect_success 'fetch repository' '
    start_svnserve &&
    shit svn init svn://127.0.0.1:$SVNSERVE_PORT &&
    shit svn fetch
    '

test_done
