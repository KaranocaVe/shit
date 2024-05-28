#!/bin/sh

test_description='combined and merge diff handle binary files and textconv'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup binary merge conflict' '
	echo oneQ1 | q_to_nul >binary &&
	shit add binary &&
	shit commit -m one &&
	echo twoQ2 | q_to_nul >binary &&
	shit commit -a -m two &&
	two=$(shit rev-parse --short HEAD:binary) &&
	shit checkout -b branch-binary HEAD^ &&
	echo threeQ3 | q_to_nul >binary &&
	shit commit -a -m three &&
	three=$(shit rev-parse --short HEAD:binary) &&
	test_must_fail shit merge main &&
	echo resolvedQhooray | q_to_nul >binary &&
	shit commit -a -m resolved &&
	res=$(shit rev-parse --short HEAD:binary)
'

cat >expect <<EOF
resolved

diff --shit a/binary b/binary
index $three..$res 100644
Binary files a/binary and b/binary differ
resolved

diff --shit a/binary b/binary
index $two..$res 100644
Binary files a/binary and b/binary differ
EOF
test_expect_success 'diff -m indicates binary-ness' '
	shit show --format=%s -m >actual &&
	test_cmp expect actual
'

cat >expect <<EOF
resolved

diff --combined binary
index $three,$two..$res
Binary files differ
EOF
test_expect_success 'diff -c indicates binary-ness' '
	shit show --format=%s -c >actual &&
	test_cmp expect actual
'

cat >expect <<EOF
resolved

diff --cc binary
index $three,$two..$res
Binary files differ
EOF
test_expect_success 'diff --cc indicates binary-ness' '
	shit show --format=%s --cc >actual &&
	test_cmp expect actual
'

test_expect_success 'setup non-binary with binary attribute' '
	shit checkout main &&
	test_commit one text &&
	test_commit two text &&
	two=$(shit rev-parse --short HEAD:text) &&
	shit checkout -b branch-text HEAD^ &&
	test_commit three text &&
	three=$(shit rev-parse --short HEAD:text) &&
	test_must_fail shit merge main &&
	test_commit resolved text &&
	res=$(shit rev-parse --short HEAD:text) &&
	echo text -diff >.shitattributes
'

cat >expect <<EOF
resolved

diff --shit a/text b/text
index $three..$res 100644
Binary files a/text and b/text differ
resolved

diff --shit a/text b/text
index $two..$res 100644
Binary files a/text and b/text differ
EOF
test_expect_success 'diff -m respects binary attribute' '
	shit show --format=%s -m >actual &&
	test_cmp expect actual
'

cat >expect <<EOF
resolved

diff --combined text
index $three,$two..$res
Binary files differ
EOF
test_expect_success 'diff -c respects binary attribute' '
	shit show --format=%s -c >actual &&
	test_cmp expect actual
'

cat >expect <<EOF
resolved

diff --cc text
index $three,$two..$res
Binary files differ
EOF
test_expect_success 'diff --cc respects binary attribute' '
	shit show --format=%s --cc >actual &&
	test_cmp expect actual
'

test_expect_success 'setup textconv attribute' '
	echo "text diff=upcase" >.shitattributes &&
	shit config diff.upcase.textconv "tr a-z A-Z <"
'

cat >expect <<EOF
resolved

diff --shit a/text b/text
index $three..$res 100644
--- a/text
+++ b/text
@@ -1 +1 @@
-THREE
+RESOLVED
resolved

diff --shit a/text b/text
index $two..$res 100644
--- a/text
+++ b/text
@@ -1 +1 @@
-TWO
+RESOLVED
EOF
test_expect_success 'diff -m respects textconv attribute' '
	shit show --format=%s -m >actual &&
	test_cmp expect actual
'

cat >expect <<EOF
resolved

diff --combined text
index $three,$two..$res
--- a/text
+++ b/text
@@@ -1,1 -1,1 +1,1 @@@
- THREE
 -TWO
++RESOLVED
EOF
test_expect_success 'diff -c respects textconv attribute' '
	shit show --format=%s -c >actual &&
	test_cmp expect actual
'

cat >expect <<EOF
resolved

diff --cc text
index $three,$two..$res
--- a/text
+++ b/text
@@@ -1,1 -1,1 +1,1 @@@
- THREE
 -TWO
++RESOLVED
EOF
test_expect_success 'diff --cc respects textconv attribute' '
	shit show --format=%s --cc >actual &&
	test_cmp expect actual
'

cat >expect <<EOF
diff --combined text
index $three,$two..$res
--- a/text
+++ b/text
@@@ -1,1 -1,1 +1,1 @@@
- three
 -two
++resolved
EOF
test_expect_success 'diff-tree plumbing does not respect textconv' '
	shit diff-tree HEAD -c -p >full &&
	tail -n +2 full >actual &&
	test_cmp expect actual
'

cat >expect <<EOF
diff --cc text
index $three,$two..0000000
--- a/text
+++ b/text
@@@ -1,1 -1,1 +1,5 @@@
++<<<<<<< HEAD
 +THREE
++=======
+ TWO
++>>>>>>> MAIN
EOF
test_expect_success 'diff --cc respects textconv on worktree file' '
	shit reset --hard HEAD^ &&
	test_must_fail shit merge main &&
	shit diff >actual &&
	test_cmp expect actual
'

test_done
