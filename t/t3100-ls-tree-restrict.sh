#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='shit ls-tree test.

This test runs shit ls-tree with the following in a tree.

    path0       - a file
    path1	- a symlink
    path2/foo   - a file in a directory
    path2/bazbo - a symlink in a directory
    path2/baz/b - a file in a directory in a directory

The new path restriction code should do the right thing for path2 and
path2/baz.  Also path0/ should snow nothing.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success \
    'setup' \
    'mkdir path2 path2/baz &&
     echo Hi >path0 &&
     test_ln_s_add path0 path1 &&
     test_ln_s_add ../path1 path2/bazbo &&
     echo Lo >path2/foo &&
     echo Mi >path2/baz/b &&
     find path? \( -type f -o -type l \) -print |
     xargs shit update-index --add &&
     tree=$(shit write-tree) &&
     echo $tree'

test_output () {
    sed -e "s/ $OID_REGEX	/ X	/" <current >check
    test_cmp expected check
}

test_expect_success \
    'ls-tree plain' \
    'shit ls-tree $tree >current &&
     cat >expected <<\EOF &&
100644 blob X	path0
120000 blob X	path1
040000 tree X	path2
EOF
     test_output'

test_expect_success \
    'ls-tree recursive' \
    'shit ls-tree -r $tree >current &&
     cat >expected <<\EOF &&
100644 blob X	path0
120000 blob X	path1
100644 blob X	path2/baz/b
120000 blob X	path2/bazbo
100644 blob X	path2/foo
EOF
     test_output'

test_expect_success \
    'ls-tree recursive with -t' \
    'shit ls-tree -r -t $tree >current &&
     cat >expected <<\EOF &&
100644 blob X	path0
120000 blob X	path1
040000 tree X	path2
040000 tree X	path2/baz
100644 blob X	path2/baz/b
120000 blob X	path2/bazbo
100644 blob X	path2/foo
EOF
     test_output'

test_expect_success \
    'ls-tree recursive with -d' \
    'shit ls-tree -r -d $tree >current &&
     cat >expected <<\EOF &&
040000 tree X	path2
040000 tree X	path2/baz
EOF
     test_output'

test_expect_success \
    'ls-tree filtered with path' \
    'shit ls-tree $tree path >current &&
     cat >expected <<\EOF &&
EOF
     test_output'


# it used to be path1 and then path0, but with pathspec semantics
# they are shown in canonical order.
test_expect_success \
    'ls-tree filtered with path1 path0' \
    'shit ls-tree $tree path1 path0 >current &&
     cat >expected <<\EOF &&
100644 blob X	path0
120000 blob X	path1
EOF
     test_output'

test_expect_success \
    'ls-tree filtered with path0/' \
    'shit ls-tree $tree path0/ >current &&
     cat >expected <<\EOF &&
EOF
     test_output'

# It used to show path2 and its immediate children but
# with pathspec semantics it shows only path2
test_expect_success \
    'ls-tree filtered with path2' \
    'shit ls-tree $tree path2 >current &&
     cat >expected <<\EOF &&
040000 tree X	path2
EOF
     test_output'

# ... and path2/ shows the children.
test_expect_success \
    'ls-tree filtered with path2/' \
    'shit ls-tree $tree path2/ >current &&
     cat >expected <<\EOF &&
040000 tree X	path2/baz
120000 blob X	path2/bazbo
100644 blob X	path2/foo
EOF
     test_output'

# The same change -- exact match does not show children of
# path2/baz
test_expect_success \
    'ls-tree filtered with path2/baz' \
    'shit ls-tree $tree path2/baz >current &&
     cat >expected <<\EOF &&
040000 tree X	path2/baz
EOF
     test_output'

test_expect_success \
    'ls-tree filtered with path2/bak' \
    'shit ls-tree $tree path2/bak >current &&
     cat >expected <<\EOF &&
EOF
     test_output'

test_expect_success \
    'ls-tree -t filtered with path2/bak' \
    'shit ls-tree -t $tree path2/bak >current &&
     cat >expected <<\EOF &&
040000 tree X	path2
EOF
     test_output'

test_expect_success \
    'ls-tree with one path a prefix of the other' \
    'shit ls-tree $tree path2/baz path2/bazbo >current &&
     cat >expected <<\EOF &&
040000 tree X	path2/baz
120000 blob X	path2/bazbo
EOF
     test_output'

test_done
