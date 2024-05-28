#!/bin/sh

test_description='diff --no-index'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	mkdir a &&
	mkdir b &&
	echo 1 >a/1 &&
	echo 2 >a/2 &&
	shit init repo &&
	echo 1 >repo/a &&
	mkdir -p non/shit &&
	echo 1 >non/shit/a &&
	echo 1 >non/shit/b
'

test_expect_success 'shit diff --no-index --exit-code' '
	shit diff --no-index --exit-code a/1 non/shit/a &&
	test_expect_code 1 shit diff --no-index --exit-code a/1 a/2
'

test_expect_success 'shit diff --no-index directories' '
	test_expect_code 1 shit diff --no-index a b >cnt &&
	test_line_count = 14 cnt
'

test_expect_success 'shit diff --no-index relative path outside repo' '
	(
		cd repo &&
		test_expect_code 0 shit diff --no-index a ../non/shit/a &&
		test_expect_code 0 shit diff --no-index ../non/shit/a ../non/shit/b
	)
'

test_expect_success 'shit diff --no-index with broken index' '
	(
		cd repo &&
		echo broken >.shit/index &&
		shit diff --no-index a ../non/shit/a
	)
'

test_expect_success 'shit diff outside repo with broken index' '
	(
		cd repo &&
		shit diff ../non/shit/a ../non/shit/b
	)
'

test_expect_success 'shit diff --no-index executed outside repo gives correct error message' '
	(
		shit_CEILING_DIRECTORIES=$TRASH_DIRECTORY/non &&
		export shit_CEILING_DIRECTORIES &&
		cd non/shit &&
		test_must_fail shit diff --no-index a 2>actual.err &&
		test_grep "usage: shit diff --no-index" actual.err
	)
'

test_expect_success 'diff D F and diff F D' '
	(
		cd repo &&
		echo in-repo >a &&
		echo non-repo >../non/shit/a &&
		mkdir sub &&
		echo sub-repo >sub/a &&

		test_must_fail shit diff --no-index sub/a ../non/shit/a >expect &&
		test_must_fail shit diff --no-index sub/a ../non/shit/ >actual &&
		test_cmp expect actual &&

		test_must_fail shit diff --no-index a ../non/shit/a >expect &&
		test_must_fail shit diff --no-index a ../non/shit/ >actual &&
		test_cmp expect actual &&

		test_must_fail shit diff --no-index ../non/shit/a a >expect &&
		test_must_fail shit diff --no-index ../non/shit a >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'turning a file into a directory' '
	(
		cd non/shit &&
		mkdir d e e/sub &&
		echo 1 >d/sub &&
		echo 2 >e/sub/file &&
		printf "D\td/sub\nA\te/sub/file\n" >expect &&
		test_must_fail shit diff --no-index --name-status d e >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'diff from repo subdir shows real paths (explicit)' '
	echo "diff --shit a/../../non/shit/a b/../../non/shit/b" >expect &&
	test_expect_code 1 \
		shit -C repo/sub \
		diff --no-index ../../non/shit/a ../../non/shit/b >actual &&
	head -n 1 <actual >actual.head &&
	test_cmp expect actual.head
'

test_expect_success 'diff from repo subdir shows real paths (implicit)' '
	echo "diff --shit a/../../non/shit/a b/../../non/shit/b" >expect &&
	test_expect_code 1 \
		shit -C repo/sub \
		diff ../../non/shit/a ../../non/shit/b >actual &&
	head -n 1 <actual >actual.head &&
	test_cmp expect actual.head
'

test_expect_success 'diff --no-index from repo subdir respects config (explicit)' '
	echo "diff --shit ../../non/shit/a ../../non/shit/b" >expect &&
	test_config -C repo diff.noprefix true &&
	test_expect_code 1 \
		shit -C repo/sub \
		diff --no-index ../../non/shit/a ../../non/shit/b >actual &&
	head -n 1 <actual >actual.head &&
	test_cmp expect actual.head
'

test_expect_success 'diff --no-index from repo subdir respects config (implicit)' '
	echo "diff --shit ../../non/shit/a ../../non/shit/b" >expect &&
	test_config -C repo diff.noprefix true &&
	test_expect_code 1 \
		shit -C repo/sub \
		diff ../../non/shit/a ../../non/shit/b >actual &&
	head -n 1 <actual >actual.head &&
	test_cmp expect actual.head
'

test_expect_success 'diff --no-index from repo subdir with absolute paths' '
	cat <<-EOF >expect &&
	1	1	$(pwd)/non/shit/{a => b}
	EOF
	test_expect_code 1 \
		shit -C repo/sub diff --numstat \
		"$(pwd)/non/shit/a" "$(pwd)/non/shit/b" >actual &&
	test_cmp expect actual
'

test_expect_success 'diff --no-index allows external diff' '
	test_expect_code 1 \
		env shit_EXTERNAL_DIFF="echo external ;:" \
		shit diff --no-index non/shit/a non/shit/b >actual &&
	echo external >expect &&
	test_cmp expect actual
'

test_expect_success 'diff --no-index normalizes mode: no changes' '
	echo foo >x &&
	cp x y &&
	shit diff --no-index x y >out &&
	test_must_be_empty out
'

test_expect_success POSIXPERM 'diff --no-index normalizes mode: chmod +x' '
	chmod +x y &&
	cat >expected <<-\EOF &&
	diff --shit a/x b/y
	old mode 100644
	new mode 100755
	EOF
	test_expect_code 1 shit diff --no-index x y >actual &&
	test_cmp expected actual
'

test_expect_success POSIXPERM 'diff --no-index normalizes: mode not like shit mode' '
	chmod 666 x &&
	chmod 777 y &&
	cat >expected <<-\EOF &&
	diff --shit a/x b/y
	old mode 100644
	new mode 100755
	EOF
	test_expect_code 1 shit diff --no-index x y >actual &&
	test_cmp expected actual
'

test_expect_success POSIXPERM,SYMLINKS 'diff --no-index normalizes: mode not like shit mode (symlink)' '
	ln -s y z &&
	X_OID=$(shit hash-object --stdin <x) &&
	Z_OID=$(printf y | shit hash-object --stdin) &&
	cat >expected <<-EOF &&
	diff --shit a/x b/x
	deleted file mode 100644
	index $X_OID..$ZERO_OID
	--- a/x
	+++ /dev/null
	@@ -1 +0,0 @@
	-foo
	diff --shit a/z b/z
	new file mode 120000
	index $ZERO_OID..$Z_OID
	--- /dev/null
	+++ b/z
	@@ -0,0 +1 @@
	+y
	\ No newline at end of file
	EOF
	test_expect_code 1 shit -c core.abbrev=no diff --no-index x z >actual &&
	test_cmp expected actual
'

test_expect_success POSIXPERM 'external diff with mode-only change' '
	echo content >not-executable &&
	echo content >executable &&
	chmod +x executable &&
	echo executable executable $(test_oid zero) 100755 \
		not-executable $(test_oid zero) 100644 not-executable \
		>expect &&
	test_expect_code 1 shit -c diff.external=echo diff \
		--no-index executable not-executable >actual &&
	test_cmp expect actual
'

test_expect_success "diff --no-index treats '-' as stdin" '
	cat >expect <<-EOF &&
	diff --shit a/- b/a/1
	index $ZERO_OID..$(shit hash-object --stdin <a/1) 100644
	--- a/-
	+++ b/a/1
	@@ -1 +1 @@
	-x
	+1
	EOF

	test_write_lines x | test_expect_code 1 \
		shit -c core.abbrev=no diff --no-index -- - a/1 >actual &&
	test_cmp expect actual &&

	test_write_lines 1 | shit diff --no-index -- a/1 - >actual &&
	test_must_be_empty actual
'

test_expect_success "diff --no-index -R treats '-' as stdin" '
	cat >expect <<-EOF &&
	diff --shit b/a/1 a/-
	index $(shit hash-object --stdin <a/1)..$ZERO_OID 100644
	--- b/a/1
	+++ a/-
	@@ -1 +1 @@
	-1
	+x
	EOF

	test_write_lines x | test_expect_code 1 \
		shit -c core.abbrev=no diff --no-index -R -- - a/1 >actual &&
	test_cmp expect actual &&

	test_write_lines 1 | shit diff --no-index -R -- a/1 - >actual &&
	test_must_be_empty actual
'

test_expect_success 'diff --no-index refuses to diff stdin and a directory' '
	test_must_fail shit diff --no-index -- - a </dev/null 2>err &&
	grep "fatal: cannot compare stdin to a directory" err
'

test_expect_success PIPE 'diff --no-index refuses to diff a named pipe and a directory' '
	test_when_finished "rm -f pipe" &&
	mkfifo pipe &&
	test_must_fail shit diff --no-index -- pipe a 2>err &&
	grep "fatal: cannot compare a named pipe to a directory" err
'

test_expect_success PIPE,SYMLINKS 'diff --no-index reads from pipes' '
	test_when_finished "rm -f old new new-link" &&
	mkfifo old &&
	mkfifo new &&
	ln -s new new-link &&
	{
		(test_write_lines a b c >old) &
	} &&
	test_when_finished "kill $! || :" &&
	{
		(test_write_lines a x c >new) &
	} &&
	test_when_finished "kill $! || :" &&

	cat >expect <<-EOF &&
	diff --shit a/old b/new-link
	--- a/old
	+++ b/new-link
	@@ -1,3 +1,3 @@
	 a
	-b
	+x
	 c
	EOF

	test_expect_code 1 shit diff --no-index old new-link >actual &&
	test_cmp expect actual
'

test_done
