#!/bin/sh
#
# Copyright (c) 2010 Stefan-W. Hahn
#

test_description='shit-am mbox with dos line ending.

'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

# Three patches which will be added as files with dos line ending.

cat >file1 <<\EOF
line 1
EOF

cat >file1a <<\EOF
line 1
line 4
EOF

cat >file2 <<\EOF
line 1
line 2
EOF

cat >file3 <<\EOF
line 1
line 2
line 3
EOF

test_expect_success 'setup repository with dos files' '
	append_cr <file1 >file &&
	shit add file &&
	shit commit -m Initial &&
	shit tag initial &&
	append_cr <file2 >file &&
	shit commit -a -m Second &&
	append_cr <file3 >file &&
	shit commit -a -m Third
'

test_expect_success 'am with dos files without --keep-cr' '
	shit checkout -b dosfiles initial &&
	shit format-patch -k initial..main &&
	test_must_fail shit am -k -3 000*.patch &&
	shit am --abort &&
	rm -rf .shit/rebase-apply 000*.patch
'

test_expect_success 'am with dos files with --keep-cr' '
	shit checkout -b dosfiles-keep-cr initial &&
	shit format-patch -k --stdout initial..main >output &&
	shit am --keep-cr -k -3 output &&
	shit diff --exit-code main
'

test_expect_success 'am with dos files config am.keepcr' '
	shit config am.keepcr 1 &&
	shit checkout -b dosfiles-conf-keepcr initial &&
	shit format-patch -k --stdout initial..main >output &&
	shit am -k -3 output &&
	shit diff --exit-code main
'

test_expect_success 'am with dos files config am.keepcr overridden by --no-keep-cr' '
	shit config am.keepcr 1 &&
	shit checkout -b dosfiles-conf-keepcr-override initial &&
	shit format-patch -k initial..main &&
	test_must_fail shit am -k -3 --no-keep-cr 000*.patch &&
	shit am --abort &&
	rm -rf .shit/rebase-apply 000*.patch
'

test_expect_success 'am with dos files with --keep-cr continue' '
	shit checkout -b dosfiles-keep-cr-continue initial &&
	shit format-patch -k initial..main &&
	append_cr <file1a >file &&
	shit commit -m "different patch" file &&
	test_must_fail shit am --keep-cr -k -3 000*.patch &&
	append_cr <file2 >file &&
	shit add file &&
	shit am -3 --resolved &&
	shit diff --exit-code main
'

test_expect_success 'am with unix files config am.keepcr overridden by --no-keep-cr' '
	shit config am.keepcr 1 &&
	shit checkout -b unixfiles-conf-keepcr-override initial &&
	cp -f file1 file &&
	shit commit -m "line ending to unix" file &&
	shit format-patch -k initial..main &&
	shit am -k -3 --no-keep-cr 000*.patch &&
	shit diff --exit-code -w main
'

test_done
