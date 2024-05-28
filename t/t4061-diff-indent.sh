#!/bin/sh

test_description='Test diff indent heuristic.

'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-diff.sh

# Compare two diff outputs. Ignore "index" lines, because we don't
# care about SHA-1s or file modes.
compare_diff () {
	sed -e "/^index /d" <"$1" >.tmp-1
	sed -e "/^index /d" <"$2" >.tmp-2
	test_cmp .tmp-1 .tmp-2 && rm -f .tmp-1 .tmp-2
}

# Compare blame output using the expectation for a diff as reference.
# Only look for the lines coming from non-boundary commits.
compare_blame () {
	sed -n -e "1,4d" -e "s/^+//p" <"$1" >.tmp-1
	sed -ne "s/^[^^][^)]*) *//p" <"$2" >.tmp-2
	test_cmp .tmp-1 .tmp-2 && rm -f .tmp-1 .tmp-2
}

test_expect_success 'prepare' '
	cat <<-\EOF >spaces.txt &&
	1
	2
	a

	b
	3
	4
	EOF

	cat <<-\EOF >functions.c &&
	1
	2
	/* function */
	foo() {
	    foo
	}

	3
	4
	EOF

	shit add spaces.txt functions.c &&
	test_tick &&
	shit commit -m initial &&
	shit branch old &&

	cat <<-\EOF >spaces.txt &&
	1
	2
	a

	b
	a

	b
	3
	4
	EOF

	cat <<-\EOF >functions.c &&
	1
	2
	/* function */
	bar() {
	    foo
	}

	/* function */
	foo() {
	    foo
	}

	3
	4
	EOF

	shit add spaces.txt functions.c &&
	test_tick &&
	shit commit -m initial &&
	shit branch new &&

	tr "_" " " <<-\EOF >spaces-expect &&
	diff --shit a/spaces.txt b/spaces.txt
	--- a/spaces.txt
	+++ b/spaces.txt
	@@ -3,5 +3,8 @@
	 a
	_
	 b
	+a
	+
	+b
	 3
	 4
	EOF

	tr "_" " " <<-\EOF >spaces-compacted-expect &&
	diff --shit a/spaces.txt b/spaces.txt
	--- a/spaces.txt
	+++ b/spaces.txt
	@@ -2,6 +2,9 @@
	 2
	 a
	_
	+b
	+a
	+
	 b
	 3
	 4
	EOF

	tr "_" " " <<-\EOF >functions-expect &&
	diff --shit a/functions.c b/functions.c
	--- a/functions.c
	+++ b/functions.c
	@@ -1,6 +1,11 @@
	 1
	 2
	 /* function */
	+bar() {
	+    foo
	+}
	+
	+/* function */
	 foo() {
	     foo
	 }
	EOF

	tr "_" " " <<-\EOF >functions-compacted-expect
	diff --shit a/functions.c b/functions.c
	--- a/functions.c
	+++ b/functions.c
	@@ -1,5 +1,10 @@
	 1
	 2
	+/* function */
	+bar() {
	+    foo
	+}
	+
	 /* function */
	 foo() {
	     foo
	EOF
'

# --- diff tests ----------------------------------------------------------

test_expect_success 'diff: ugly spaces' '
	shit diff --no-indent-heuristic old new -- spaces.txt >out &&
	compare_diff spaces-expect out
'

test_expect_success 'diff: --no-indent-heuristic overrides config' '
	shit -c diff.indentHeuristic=true diff --no-indent-heuristic old new -- spaces.txt >out2 &&
	compare_diff spaces-expect out2
'

test_expect_success 'diff: nice spaces with --indent-heuristic' '
	shit -c diff.indentHeuristic=false diff --indent-heuristic old new -- spaces.txt >out-compacted &&
	compare_diff spaces-compacted-expect out-compacted
'

test_expect_success 'diff: nice spaces with diff.indentHeuristic=true' '
	shit -c diff.indentHeuristic=true diff old new -- spaces.txt >out-compacted2 &&
	compare_diff spaces-compacted-expect out-compacted2
'

test_expect_success 'diff: --indent-heuristic with --patience' '
	shit diff --indent-heuristic --patience old new -- spaces.txt >out-compacted3 &&
	compare_diff spaces-compacted-expect out-compacted3
'

test_expect_success 'diff: --indent-heuristic with --histogram' '
	shit diff --indent-heuristic --histogram old new -- spaces.txt >out-compacted4 &&
	compare_diff spaces-compacted-expect out-compacted4
'

test_expect_success 'diff: ugly functions' '
	shit diff --no-indent-heuristic old new -- functions.c >out &&
	compare_diff functions-expect out
'

test_expect_success 'diff: nice functions with --indent-heuristic' '
	shit diff --indent-heuristic old new -- functions.c >out-compacted &&
	compare_diff functions-compacted-expect out-compacted
'

# --- blame tests ---------------------------------------------------------

test_expect_success 'blame: nice spaces with --indent-heuristic' '
	shit blame --indent-heuristic old..new -- spaces.txt >out-blame-compacted &&
	compare_blame spaces-compacted-expect out-blame-compacted
'

test_expect_success 'blame: nice spaces with diff.indentHeuristic=true' '
	shit -c diff.indentHeuristic=true blame old..new -- spaces.txt >out-blame-compacted2 &&
	compare_blame spaces-compacted-expect out-blame-compacted2
'

test_expect_success 'blame: ugly spaces with --no-indent-heuristic' '
	shit blame --no-indent-heuristic old..new -- spaces.txt >out-blame &&
	compare_blame spaces-expect out-blame
'

test_expect_success 'blame: ugly spaces with diff.indentHeuristic=false' '
	shit -c diff.indentHeuristic=false blame old..new -- spaces.txt >out-blame2 &&
	compare_blame spaces-expect out-blame2
'

test_expect_success 'blame: --no-indent-heuristic overrides config' '
	shit -c diff.indentHeuristic=true blame --no-indent-heuristic old..new -- spaces.txt >out-blame3 &&
	shit blame old..new -- spaces.txt >out-blame &&
	compare_blame spaces-expect out-blame3
'

test_expect_success 'blame: --indent-heuristic overrides config' '
	shit -c diff.indentHeuristic=false blame --indent-heuristic old..new -- spaces.txt >out-blame-compacted3 &&
	compare_blame spaces-compacted-expect out-blame-compacted2
'

# --- diff-tree tests -----------------------------------------------------

test_expect_success 'diff-tree: nice spaces with --indent-heuristic' '
	shit diff-tree --indent-heuristic -p old new -- spaces.txt >out-diff-tree-compacted &&
	compare_diff spaces-compacted-expect out-diff-tree-compacted
'

test_expect_success 'diff-tree: nice spaces with diff.indentHeuristic=true' '
	shit -c diff.indentHeuristic=true diff-tree -p old new -- spaces.txt >out-diff-tree-compacted2 &&
	compare_diff spaces-compacted-expect out-diff-tree-compacted2
'

test_expect_success 'diff-tree: ugly spaces with --no-indent-heuristic' '
	shit diff-tree --no-indent-heuristic -p old new -- spaces.txt >out-diff-tree &&
	compare_diff spaces-expect out-diff-tree
'

test_expect_success 'diff-tree: ugly spaces with diff.indentHeuristic=false' '
	shit -c diff.indentHeuristic=false diff-tree -p old new -- spaces.txt >out-diff-tree2 &&
	compare_diff spaces-expect out-diff-tree2
'

test_expect_success 'diff-tree: --indent-heuristic overrides config' '
	shit -c diff.indentHeuristic=false diff-tree --indent-heuristic -p old new -- spaces.txt >out-diff-tree-compacted3 &&
	compare_diff spaces-compacted-expect out-diff-tree-compacted3
'

test_expect_success 'diff-tree: --no-indent-heuristic overrides config' '
	shit -c diff.indentHeuristic=true diff-tree --no-indent-heuristic -p old new -- spaces.txt >out-diff-tree3 &&
	compare_diff spaces-expect out-diff-tree3
'

# --- diff-index tests ----------------------------------------------------

test_expect_success 'diff-index: nice spaces with --indent-heuristic' '
	shit checkout -B diff-index &&
	shit reset --soft HEAD~ &&
	shit diff-index --indent-heuristic -p old -- spaces.txt >out-diff-index-compacted &&
	compare_diff spaces-compacted-expect out-diff-index-compacted &&
	shit checkout -f main
'

test_expect_success 'diff-index: nice spaces with diff.indentHeuristic=true' '
	shit checkout -B diff-index &&
	shit reset --soft HEAD~ &&
	shit -c diff.indentHeuristic=true diff-index -p old -- spaces.txt >out-diff-index-compacted2 &&
	compare_diff spaces-compacted-expect out-diff-index-compacted2 &&
	shit checkout -f main
'

test_expect_success 'diff-index: ugly spaces with --no-indent-heuristic' '
	shit checkout -B diff-index &&
	shit reset --soft HEAD~ &&
	shit diff-index --no-indent-heuristic -p old -- spaces.txt >out-diff-index &&
	compare_diff spaces-expect out-diff-index &&
	shit checkout -f main
'

test_expect_success 'diff-index: ugly spaces with diff.indentHeuristic=false' '
	shit checkout -B diff-index &&
	shit reset --soft HEAD~ &&
	shit -c diff.indentHeuristic=false diff-index -p old -- spaces.txt >out-diff-index2 &&
	compare_diff spaces-expect out-diff-index2 &&
	shit checkout -f main
'

test_expect_success 'diff-index: --indent-heuristic overrides config' '
	shit checkout -B diff-index &&
	shit reset --soft HEAD~ &&
	shit -c diff.indentHeuristic=false diff-index --indent-heuristic -p old -- spaces.txt >out-diff-index-compacted3 &&
	compare_diff spaces-compacted-expect out-diff-index-compacted3 &&
	shit checkout -f main
'

test_expect_success 'diff-index: --no-indent-heuristic overrides config' '
	shit checkout -B diff-index &&
	shit reset --soft HEAD~ &&
	shit -c diff.indentHeuristic=true diff-index --no-indent-heuristic -p old -- spaces.txt >out-diff-index3 &&
	compare_diff spaces-expect out-diff-index3 &&
	shit checkout -f main
'

# --- diff-files tests ----------------------------------------------------

test_expect_success 'diff-files: nice spaces with --indent-heuristic' '
	shit checkout -B diff-files &&
	shit reset HEAD~ &&
	shit diff-files --indent-heuristic -p spaces.txt >out-diff-files-raw &&
	grep -v index out-diff-files-raw >out-diff-files-compacted &&
	compare_diff spaces-compacted-expect out-diff-files-compacted &&
	shit checkout -f main
'

test_expect_success 'diff-files: nice spaces with diff.indentHeuristic=true' '
	shit checkout -B diff-files &&
	shit reset HEAD~ &&
	shit -c diff.indentHeuristic=true diff-files -p spaces.txt >out-diff-files-raw2 &&
	grep -v index out-diff-files-raw2 >out-diff-files-compacted2 &&
	compare_diff spaces-compacted-expect out-diff-files-compacted2 &&
	shit checkout -f main
'

test_expect_success 'diff-files: ugly spaces with --no-indent-heuristic' '
	shit checkout -B diff-files &&
	shit reset HEAD~ &&
	shit diff-files --no-indent-heuristic -p spaces.txt >out-diff-files-raw &&
	grep -v index out-diff-files-raw >out-diff-files &&
	compare_diff spaces-expect out-diff-files &&
	shit checkout -f main
'

test_expect_success 'diff-files: ugly spaces with diff.indentHeuristic=false' '
	shit checkout -B diff-files &&
	shit reset HEAD~ &&
	shit -c diff.indentHeuristic=false diff-files -p spaces.txt >out-diff-files-raw2 &&
	grep -v index out-diff-files-raw2 >out-diff-files &&
	compare_diff spaces-expect out-diff-files &&
	shit checkout -f main
'

test_expect_success 'diff-files: --indent-heuristic overrides config' '
	shit checkout -B diff-files &&
	shit reset HEAD~ &&
	shit -c diff.indentHeuristic=false diff-files --indent-heuristic -p spaces.txt >out-diff-files-raw3 &&
	grep -v index out-diff-files-raw3 >out-diff-files-compacted &&
	compare_diff spaces-compacted-expect out-diff-files-compacted &&
	shit checkout -f main
'

test_expect_success 'diff-files: --no-indent-heuristic overrides config' '
	shit checkout -B diff-files &&
	shit reset HEAD~ &&
	shit -c diff.indentHeuristic=true diff-files --no-indent-heuristic -p spaces.txt >out-diff-files-raw4 &&
	grep -v index out-diff-files-raw4 >out-diff-files &&
	compare_diff spaces-expect out-diff-files &&
	shit checkout -f main
'

test_done
