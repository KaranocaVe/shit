#!/bin/sh
#
# Copyright (c) 2010 Jakub Narebski, Christian Couder
#

test_description='Move a binary file'

. ./test-lib.sh


test_expect_success 'prepare repository' '
	shit init &&
	echo foo > foo &&
	echo "barQ" | q_to_nul > bar &&
	shit add . &&
	shit commit -m "Initial commit"
'

test_expect_success 'move the files into a "sub" directory' '
	mkdir sub &&
	shit mv bar foo sub/ &&
	shit commit -m "Moved to sub/"
'

cat > expected <<\EOF
-	-	bar => sub/bar
0	0	foo => sub/foo

diff --shit a/bar b/sub/bar
similarity index 100%
rename from bar
rename to sub/bar
diff --shit a/foo b/sub/foo
similarity index 100%
rename from foo
rename to sub/foo
EOF

test_expect_success 'shit show -C -C report renames' '
	shit show -C -C --raw --binary --numstat >patch-with-stat &&
	tail -n 11 patch-with-stat >current &&
	test_cmp expected current
'

test_done
