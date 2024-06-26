#!/bin/sh

test_description='shit apply with weird postimage filenames'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	vector=$TEST_DIRECTORY/t4135 &&

	test_tick &&
	shit commit --allow-empty -m preimage &&
	shit tag preimage &&

	reset_preimage() {
		shit checkout -f preimage^0 &&
		shit read-tree -u --reset HEAD &&
		shit update-index --refresh
	}
'

try_filename() {
	desc=$1
	postimage=$2
	prereq=${3:-}
	exp1=${4:-success}
	exp2=${5:-success}
	exp3=${6:-success}

	test_expect_$exp1 $prereq "$desc, shit-style file creation patch" "
		echo postimage >expected &&
		reset_preimage &&
		rm -f '$postimage' &&
		shit apply -v \"\$vector\"/'shit-$desc.diff' &&
		test_cmp expected '$postimage'
	"

	test_expect_$exp2 $prereq "$desc, traditional patch" "
		echo postimage >expected &&
		reset_preimage &&
		echo preimage >'$postimage' &&
		shit apply -v \"\$vector\"/'diff-$desc.diff' &&
		test_cmp expected '$postimage'
	"

	test_expect_$exp3 $prereq "$desc, traditional file creation patch" "
		echo postimage >expected &&
		reset_preimage &&
		rm -f '$postimage' &&
		shit apply -v \"\$vector\"/'add-$desc.diff' &&
		test_cmp expected '$postimage'
	"
}

try_filename 'plain'            'postimage.txt'
try_filename 'with spaces'      'post image.txt'
try_filename 'with tab'         'post	image.txt' FUNNYNAMES
try_filename 'with backslash'   'post\image.txt' BSLASHPSPEC
try_filename 'with quote'       '"postimage".txt' FUNNYNAMES success failure success

test_expect_success 'whitespace-damaged traditional patch' '
	echo postimage >expected &&
	reset_preimage &&
	rm -f postimage.txt &&
	shit apply -v "$vector/damaged.diff" &&
	test_cmp expected postimage.txt
'

test_expect_success 'traditional patch with colon in timezone' '
	echo postimage >expected &&
	reset_preimage &&
	rm -f "post image.txt" &&
	shit apply "$vector/funny-tz.diff" &&
	test_cmp expected "post image.txt"
'

test_expect_success 'traditional, whitespace-damaged, colon in timezone' '
	echo postimage >expected &&
	reset_preimage &&
	rm -f "post image.txt" &&
	shit apply "$vector/damaged-tz.diff" &&
	test_cmp expected "post image.txt"
'

cat >diff-from-svn <<\EOF
Index: Makefile
===================================================================
diff --shit a/branches/Makefile
deleted file mode 100644
--- a/branches/Makefile	(revision 13)
+++ /dev/null	(nonexistent)
@@ +1 0,0 @@
-
EOF

test_expect_success 'apply handles a diff generated by Subversion' '
	>Makefile &&
	shit apply -p2 diff-from-svn &&
	test_path_is_missing Makefile
'

test_done
