#!/bin/sh
#
# Copyright (C) 2005 Rene Scharfe
#

test_description='shit commit-tree options test

This test checks that shit commit-tree can create a specific commit
object by defining all environment variables that it understands.

Also make sure that command line parser understands the normal
"flags first and then non flag arguments" command line.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

cat >expected <<EOF
tree $EMPTY_TREE
author Author Name <author@email> 1117148400 +0000
committer Committer Name <committer@email> 1117150200 +0000

comment text
EOF

test_expect_success \
    'test preparation: write empty tree' \
    'shit write-tree >treeid'

test_expect_success \
    'construct commit' \
    'echo comment text |
     shit_AUTHOR_NAME="Author Name" \
     shit_AUTHOR_EMAIL="author@email" \
     shit_AUTHOR_DATE="2005-05-26 23:00" \
     shit_COMMITTER_NAME="Committer Name" \
     shit_COMMITTER_EMAIL="committer@email" \
     shit_COMMITTER_DATE="2005-05-26 23:30" \
     TZ=GMT shit commit-tree $(cat treeid) >commitid 2>/dev/null'

test_expect_success \
    'read commit' \
    'shit cat-file commit $(cat commitid) >commit'

test_expect_success \
    'compare commit' \
    'test_cmp expected commit'


test_expect_success 'flags and then non flags' '
	test_tick &&
	echo comment text |
	shit commit-tree $(cat treeid) >commitid &&
	echo comment text |
	shit commit-tree $(cat treeid) -p $(cat commitid) >childid-1 &&
	echo comment text |
	shit commit-tree -p $(cat commitid) $(cat treeid) >childid-2 &&
	test_cmp childid-1 childid-2 &&
	shit commit-tree $(cat treeid) -m foo >childid-3 &&
	shit commit-tree -m foo $(cat treeid) >childid-4 &&
	test_cmp childid-3 childid-4
'

test_done
