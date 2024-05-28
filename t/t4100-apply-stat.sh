#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='shit apply --stat --summary test, with --recount

'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

UNC='s/^\(@@ -[1-9][0-9]*\),[0-9]* \(+[1-9][0-9]*\),[0-9]* @@/\1,999 \2,999 @@/'

num=0
while read title
do
	num=$(( $num + 1 ))
	test_expect_success "$title" '
		shit apply --stat --summary \
			<"$TEST_DIRECTORY/t4100/t-apply-$num.patch" >current &&
		test_cmp "$TEST_DIRECTORY"/t4100/t-apply-$num.expect current
	'

	test_expect_success "$title with recount" '
		sed -e "$UNC" <"$TEST_DIRECTORY/t4100/t-apply-$num.patch" |
		shit apply --recount --stat --summary >current &&
		test_cmp "$TEST_DIRECTORY"/t4100/t-apply-$num.expect current
	'
done <<\EOF
rename
copy
rewrite
mode
non shit (1)
non shit (2)
non shit (3)
incomplete (1)
incomplete (2)
EOF

test_done
