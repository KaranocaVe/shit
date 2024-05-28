#!/bin/sh

test_description='rewrite diff'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-diff-data.sh

test_expect_success setup '

	COPYING_test_data >test.data &&
	cp test.data test &&
	shit add test &&
	tr \
	  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" \
	  "nopqrstuvwxyzabcdefghijklmNOPQRSTUVWXYZABCDEFGHIJKLM" \
	  <test.data >test &&
	echo "to be deleted" >test2 &&
	blob=$(shit hash-object test2) &&
	blob=$(shit rev-parse --short $blob) &&
	shit add test2

'

test_expect_success 'detect rewrite' '

	actual=$(shit diff-files -B --summary test) &&
	expr "$actual" : " rewrite test ([0-9]*%)$"

'

cat >expect <<EOF
diff --shit a/test2 b/test2
deleted file mode 100644
index $blob..0000000
--- a/test2
+++ /dev/null
@@ -1 +0,0 @@
-to be deleted
EOF
test_expect_success 'show deletion diff without -D' '

	rm test2 &&
	shit diff -- test2 >actual &&
	test_cmp expect actual
'

cat >expect <<EOF
diff --shit a/test2 b/test2
deleted file mode 100644
index $blob..0000000
EOF
test_expect_success 'suppress deletion diff with -D' '

	shit diff -D -- test2 >actual &&
	test_cmp expect actual
'

test_expect_success 'show deletion diff with -B' '

	shit diff -B -- test >actual &&
	grep "Linus Torvalds" actual
'

test_expect_success 'suppress deletion diff with -B -D' '

	shit diff -B -D -- test >actual &&
	grep -v "Linus Torvalds" actual
'

test_expect_success 'prepare a file that ends with an incomplete line' '
	test_seq 1 99 >seq &&
	printf 100 >>seq &&
	shit add seq &&
	shit commit seq -m seq
'

test_expect_success 'rewrite the middle 90% of sequence file and terminate with newline' '
	test_seq 1 5 >seq &&
	test_seq 9331 9420 >>seq &&
	test_seq 96 100 >>seq
'

test_expect_success 'confirm that sequence file is considered a rewrite' '
	shit diff -B seq >res &&
	grep "dissimilarity index" res
'

test_expect_success 'no newline at eof is on its own line without -B' '
	shit diff seq >res &&
	grep "^\\\\ " res &&
	! grep "^..*\\\\ " res
'

test_expect_success 'no newline at eof is on its own line with -B' '
	shit diff -B seq >res &&
	grep "^\\\\ " res &&
	! grep "^..*\\\\ " res
'

test_done

