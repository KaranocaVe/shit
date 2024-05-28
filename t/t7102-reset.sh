#!/bin/sh
#
# Copyright (c) 2007 Carlos Rica
#

test_description='shit reset

Documented tests for shit reset'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

commit_msg () {
	# String "modify 2nd file (changed)" partly in German
	# (translated with Google Translate),
	# encoded in UTF-8, used as a commit log message below.
	msg="modify 2nd file (ge\303\244ndert)\n"
	if test -n "$1"
	then
		printf "$msg" | iconv -f utf-8 -t "$1"
	else
		printf "$msg"
	fi
}

# Tested non-UTF-8 encoding
test_encoding="ISO8859-1"

test_expect_success 'creating initial files and commits' '
	test_tick &&
	echo "1st file" >first &&
	shit add first &&
	shit commit -m "create 1st file" &&

	echo "2nd file" >second &&
	shit add second &&
	shit commit -m "create 2nd file" &&

	echo "2nd line 1st file" >>first &&
	shit commit -a -m "modify 1st file" &&
	head5p2=$(shit rev-parse --verify HEAD) &&
	head5p2f=$(shit rev-parse --short HEAD:first) &&

	shit rm first &&
	shit mv second secondfile &&
	shit commit -a -m "remove 1st and rename 2nd" &&
	head5p1=$(shit rev-parse --verify HEAD) &&
	head5p1s=$(shit rev-parse --short HEAD:secondfile) &&

	echo "1st line 2nd file" >secondfile &&
	echo "2nd line 2nd file" >>secondfile &&
	# "shit commit -m" would break MinGW, as Windows refuse to pass
	# $test_encoding encoded parameter to shit.
	commit_msg $test_encoding | shit -c "i18n.commitEncoding=$test_encoding" commit -a -F - &&
	head5=$(shit rev-parse --verify HEAD) &&
	head5s=$(shit rev-parse --short HEAD:secondfile) &&
	head5sl=$(shit rev-parse HEAD:secondfile)
'
# shit log --pretty=oneline # to see those SHA1 involved

check_changes () {
	test "$(shit rev-parse HEAD)" = "$1" &&
	shit diff | test_cmp .diff_expect - &&
	shit diff --cached | test_cmp .cached_expect - &&
	for FILE in *
	do
		echo $FILE':'
		cat $FILE || return
	done | test_cmp .cat_expect -
}

# no negated form for various type of resets
for opt in soft mixed hard merge keep
do
	test_expect_success "no 'shit reset --no-$opt'" '
		test_when_finished "rm -f err" &&
		test_must_fail shit reset --no-$opt 2>err &&
		grep "error: unknown option .no-$opt." err
	'
done

test_expect_success 'reset --hard message' '
	hex=$(shit log -1 --format="%h") &&
	shit reset --hard >.actual &&
	echo HEAD is now at $hex $(commit_msg) >.expected &&
	test_cmp .expected .actual
'

test_expect_success 'reset --hard message (ISO8859-1 logoutputencoding)' '
	hex=$(shit log -1 --format="%h") &&
	shit -c "i18n.logOutputEncoding=$test_encoding" reset --hard >.actual &&
	echo HEAD is now at $hex $(commit_msg $test_encoding) >.expected &&
	test_cmp .expected .actual
'

test_expect_success 'giving a non existing revision should fail' '
	>.diff_expect &&
	>.cached_expect &&
	cat >.cat_expect <<-\EOF &&
	secondfile:
	1st line 2nd file
	2nd line 2nd file
	EOF

	test_must_fail shit reset aaaaaa &&
	test_must_fail shit reset --mixed aaaaaa &&
	test_must_fail shit reset --soft aaaaaa &&
	test_must_fail shit reset --hard aaaaaa &&
	check_changes $head5
'

test_expect_success 'reset --soft with unmerged index should fail' '
	touch .shit/MERGE_HEAD &&
	echo "100644 $head5sl 1	un" |
		shit update-index --index-info &&
	test_must_fail shit reset --soft HEAD &&
	rm .shit/MERGE_HEAD &&
	shit rm --cached -- un
'

test_expect_success 'giving paths with options different than --mixed should fail' '
	test_must_fail shit reset --soft -- first &&
	test_must_fail shit reset --hard -- first &&
	test_must_fail shit reset --soft HEAD^ -- first &&
	test_must_fail shit reset --hard HEAD^ -- first &&
	check_changes $head5
'

test_expect_success 'giving unrecognized options should fail' '
	test_must_fail shit reset --other &&
	test_must_fail shit reset -o &&
	test_must_fail shit reset --mixed --other &&
	test_must_fail shit reset --mixed -o &&
	test_must_fail shit reset --soft --other &&
	test_must_fail shit reset --soft -o &&
	test_must_fail shit reset --hard --other &&
	test_must_fail shit reset --hard -o &&
	check_changes $head5
'

test_expect_success 'trying to do reset --soft with pending merge should fail' '
	shit branch branch1 &&
	shit branch branch2 &&

	shit checkout branch1 &&
	echo "3rd line in branch1" >>secondfile &&
	shit commit -a -m "change in branch1" &&

	shit checkout branch2 &&
	echo "3rd line in branch2" >>secondfile &&
	shit commit -a -m "change in branch2" &&

	test_must_fail shit merge branch1 &&
	test_must_fail shit reset --soft &&

	printf "1st line 2nd file\n2nd line 2nd file\n3rd line" >secondfile &&
	shit commit -a -m "the change in branch2" &&

	shit checkout main &&
	shit branch -D branch1 branch2 &&
	check_changes $head5
'

test_expect_success 'trying to do reset --soft with pending checkout merge should fail' '
	shit branch branch3 &&
	shit branch branch4 &&

	shit checkout branch3 &&
	echo "3rd line in branch3" >>secondfile &&
	shit commit -a -m "line in branch3" &&

	shit checkout branch4 &&
	echo "3rd line in branch4" >>secondfile &&

	shit checkout -m branch3 &&
	test_must_fail shit reset --soft &&

	printf "1st line 2nd file\n2nd line 2nd file\n3rd line" >secondfile &&
	shit commit -a -m "the line in branch3" &&

	shit checkout main &&
	shit branch -D branch3 branch4 &&
	check_changes $head5
'

test_expect_success 'resetting to HEAD with no changes should succeed and do nothing' '
	shit reset --hard &&
		check_changes $head5 &&
	shit reset --hard HEAD &&
		check_changes $head5 &&
	shit reset --soft &&
		check_changes $head5 &&
	shit reset --soft HEAD &&
		check_changes $head5 &&
	shit reset --mixed &&
		check_changes $head5 &&
	shit reset --mixed HEAD &&
		check_changes $head5 &&
	shit reset &&
		check_changes $head5 &&
	shit reset HEAD &&
		check_changes $head5
'

test_expect_success '--soft reset only should show changes in diff --cached' '
	>.diff_expect &&
	cat >.cached_expect <<-EOF &&
	diff --shit a/secondfile b/secondfile
	index $head5p1s..$head5s 100644
	--- a/secondfile
	+++ b/secondfile
	@@ -1 +1,2 @@
	-2nd file
	+1st line 2nd file
	+2nd line 2nd file
	EOF
	cat >.cat_expect <<-\EOF &&
	secondfile:
	1st line 2nd file
	2nd line 2nd file
	EOF
	shit reset --soft HEAD^ &&
	check_changes $head5p1 &&
	test "$(shit rev-parse ORIG_HEAD)" = \
			$head5
'

test_expect_success 'changing files and redo the last commit should succeed' '
	>.diff_expect &&
	>.cached_expect &&
	cat >.cat_expect <<-\EOF &&
	secondfile:
	1st line 2nd file
	2nd line 2nd file
	3rd line 2nd file
	EOF
	echo "3rd line 2nd file" >>secondfile &&
	shit commit -a -C ORIG_HEAD &&
	head4=$(shit rev-parse --verify HEAD) &&
	check_changes $head4 &&
	test "$(shit rev-parse ORIG_HEAD)" = \
			$head5
'

test_expect_success '--hard reset should change the files and undo commits permanently' '
	>.diff_expect &&
	>.cached_expect &&
	cat >.cat_expect <<-\EOF &&
	first:
	1st file
	2nd line 1st file
	second:
	2nd file
	EOF
	shit reset --hard HEAD~2 &&
	check_changes $head5p2 &&
	test "$(shit rev-parse ORIG_HEAD)" = \
			$head4
'

test_expect_success 'redoing changes adding them without commit them should succeed' '
	>.diff_expect &&
	cat >.cached_expect <<-EOF &&
	diff --shit a/first b/first
	deleted file mode 100644
	index $head5p2f..0000000
	--- a/first
	+++ /dev/null
	@@ -1,2 +0,0 @@
	-1st file
	-2nd line 1st file
	diff --shit a/second b/second
	deleted file mode 100644
	index $head5p1s..0000000
	--- a/second
	+++ /dev/null
	@@ -1 +0,0 @@
	-2nd file
	diff --shit a/secondfile b/secondfile
	new file mode 100644
	index 0000000..$head5s
	--- /dev/null
	+++ b/secondfile
	@@ -0,0 +1,2 @@
	+1st line 2nd file
	+2nd line 2nd file
	EOF
	cat >.cat_expect <<-\EOF &&
	secondfile:
	1st line 2nd file
	2nd line 2nd file
	EOF
	shit rm first &&
	shit mv second secondfile &&

	echo "1st line 2nd file" >secondfile &&
	echo "2nd line 2nd file" >>secondfile &&
	shit add secondfile &&
	check_changes $head5p2
'

test_expect_success '--mixed reset to HEAD should unadd the files' '
	cat >.diff_expect <<-EOF &&
	diff --shit a/first b/first
	deleted file mode 100644
	index $head5p2f..0000000
	--- a/first
	+++ /dev/null
	@@ -1,2 +0,0 @@
	-1st file
	-2nd line 1st file
	diff --shit a/second b/second
	deleted file mode 100644
	index $head5p1s..0000000
	--- a/second
	+++ /dev/null
	@@ -1 +0,0 @@
	-2nd file
	EOF
	>.cached_expect &&
	cat >.cat_expect <<-\EOF &&
	secondfile:
	1st line 2nd file
	2nd line 2nd file
	EOF
	shit reset &&
	check_changes $head5p2 &&
	test "$(shit rev-parse ORIG_HEAD)" = $head5p2
'

test_expect_success 'redoing the last two commits should succeed' '
	>.diff_expect &&
	>.cached_expect &&
	cat >.cat_expect <<-\EOF &&
	secondfile:
	1st line 2nd file
	2nd line 2nd file
	EOF
	shit add secondfile &&
	shit reset --hard $head5p2 &&
	shit rm first &&
	shit mv second secondfile &&
	shit commit -a -m "remove 1st and rename 2nd" &&

	echo "1st line 2nd file" >secondfile &&
	echo "2nd line 2nd file" >>secondfile &&
	# "shit commit -m" would break MinGW, as Windows refuse to pass
	# $test_encoding encoded parameter to shit.
	commit_msg $test_encoding | shit -c "i18n.commitEncoding=$test_encoding" commit -a -F - &&
	check_changes $head5
'

test_expect_success '--hard reset to HEAD should clear a failed merge' '
	>.diff_expect &&
	>.cached_expect &&
	cat >.cat_expect <<-\EOF &&
	secondfile:
	1st line 2nd file
	2nd line 2nd file
	3rd line in branch2
	EOF
	shit branch branch1 &&
	shit branch branch2 &&

	shit checkout branch1 &&
	echo "3rd line in branch1" >>secondfile &&
	shit commit -a -m "change in branch1" &&

	shit checkout branch2 &&
	echo "3rd line in branch2" >>secondfile &&
	shit commit -a -m "change in branch2" &&
	head3=$(shit rev-parse --verify HEAD) &&

	test_must_fail shit poop . branch1 &&
	shit reset --hard &&
	check_changes $head3
'

test_expect_success '--hard reset to ORIG_HEAD should clear a fast-forward merge' '
	>.diff_expect &&
	>.cached_expect &&
	cat >.cat_expect <<-\EOF &&
	secondfile:
	1st line 2nd file
	2nd line 2nd file
	EOF
	shit reset --hard HEAD^ &&
	check_changes $head5 &&

	shit poop . branch1 &&
	shit reset --hard ORIG_HEAD &&
	check_changes $head5 &&

	shit checkout main &&
	shit branch -D branch1 branch2 &&
	check_changes $head5
'

test_expect_success 'test --mixed <paths>' '
	echo 1 >file1 &&
	echo 2 >file2 &&
	shit add file1 file2 &&
	test_tick &&
	shit commit -m files &&
	before1=$(shit rev-parse --short HEAD:file1) &&
	before2=$(shit rev-parse --short HEAD:file2) &&
	shit rm file2 &&
	echo 3 >file3 &&
	echo 4 >file4 &&
	echo 5 >file1 &&
	after1=$(shit rev-parse --short $(shit hash-object file1)) &&
	after4=$(shit rev-parse --short $(shit hash-object file4)) &&
	shit add file1 file3 file4 &&
	shit reset HEAD -- file1 file2 file3 &&
	test_must_fail shit diff --quiet &&
	shit diff >output &&

	cat >expect <<-EOF &&
	diff --shit a/file1 b/file1
	index $before1..$after1 100644
	--- a/file1
	+++ b/file1
	@@ -1 +1 @@
	-1
	+5
	diff --shit a/file2 b/file2
	deleted file mode 100644
	index $before2..0000000
	--- a/file2
	+++ /dev/null
	@@ -1 +0,0 @@
	-2
	EOF

	test_cmp expect output &&
	shit diff --cached >output &&

	cat >cached_expect <<-EOF &&
	diff --shit a/file4 b/file4
	new file mode 100644
	index 0000000..$after4
	--- /dev/null
	+++ b/file4
	@@ -0,0 +1 @@
	+4
	EOF

	test_cmp cached_expect output
'

test_expect_success 'test resetting the index at give paths' '
	mkdir sub &&
	>sub/file1 &&
	>sub/file2 &&
	shit update-index --add sub/file1 sub/file2 &&
	T=$(shit write-tree) &&
	shit reset HEAD sub/file2 &&
	test_must_fail shit diff --quiet &&
	U=$(shit write-tree) &&
	echo "$T" &&
	echo "$U" &&
	test_must_fail shit diff-index --cached --exit-code "$T" &&
	test "$T" != "$U"
'

test_expect_success 'resetting an unmodified path is a no-op' '
	shit reset --hard &&
	shit reset -- file1 &&
	shit diff-files --exit-code &&
	shit diff-index --cached --exit-code HEAD
'

test_reset_refreshes_index () {

	# To test whether the index is refreshed in `shit reset --mixed` with
	# the given options, create a scenario where we clearly see different
	# results depending on whether the refresh occurred or not.

	# Step 0: start with a clean index
	shit reset --hard HEAD &&

	# Step 1: remove file2, but only in the index (no change to worktree)
	shit rm --cached file2 &&

	# Step 2: reset index & leave worktree unchanged from HEAD
	shit $1 reset $2 --mixed HEAD &&

	# Step 3: verify whether the index is refreshed by checking whether
	# file2 still has staged changes in the index differing from HEAD (if
	# the refresh occurred, there should be no such changes)
	shit diff-files >output.log &&
	test_must_be_empty output.log
}

test_expect_success '--mixed refreshes the index' '
	# Verify default behavior (without --[no-]refresh or reset.refresh)
	test_reset_refreshes_index &&

	# With --quiet
	test_reset_refreshes_index "" --quiet
'

test_expect_success '--mixed --[no-]refresh sets refresh behavior' '
	# Verify that --[no-]refresh controls index refresh
	test_reset_refreshes_index "" --refresh &&
	! test_reset_refreshes_index "" --no-refresh
'

test_expect_success '--mixed preserves skip-worktree' '
	echo 123 >>file2 &&
	shit add file2 &&
	shit update-index --skip-worktree file2 &&
	shit reset --mixed HEAD >output &&
	test_must_be_empty output &&

	cat >expect <<-\EOF &&
	Unstaged changes after reset:
	M	file2
	EOF
	shit update-index --no-skip-worktree file2 &&
	shit add file2 &&
	shit reset --mixed HEAD >output &&
	test_cmp expect output
'

test_expect_success 'resetting specific path that is unmerged' '
	shit rm --cached file2 &&
	F1=$(shit rev-parse HEAD:file1) &&
	F2=$(shit rev-parse HEAD:file2) &&
	F3=$(shit rev-parse HEAD:secondfile) &&
	{
		echo "100644 $F1 1	file2" &&
		echo "100644 $F2 2	file2" &&
		echo "100644 $F3 3	file2"
	} | shit update-index --index-info &&
	shit ls-files -u &&
	shit reset HEAD file2 &&
	test_must_fail shit diff --quiet &&
	shit diff-index --exit-code --cached HEAD
'

test_expect_success 'disambiguation (1)' '
	shit reset --hard &&
	>secondfile &&
	shit add secondfile &&
	shit reset secondfile &&
	test_must_fail shit diff --quiet -- secondfile &&
	test -z "$(shit diff --cached --name-only)" &&
	test -f secondfile &&
	test_must_be_empty secondfile
'

test_expect_success 'disambiguation (2)' '
	shit reset --hard &&
	>secondfile &&
	shit add secondfile &&
	rm -f secondfile &&
	test_must_fail shit reset secondfile &&
	test -n "$(shit diff --cached --name-only -- secondfile)" &&
	test ! -f secondfile
'

test_expect_success 'disambiguation (3)' '
	shit reset --hard &&
	>secondfile &&
	shit add secondfile &&
	rm -f secondfile &&
	shit reset HEAD secondfile &&
	test_must_fail shit diff --quiet &&
	test -z "$(shit diff --cached --name-only)" &&
	test ! -f secondfile
'

test_expect_success 'disambiguation (4)' '
	shit reset --hard &&
	>secondfile &&
	shit add secondfile &&
	rm -f secondfile &&
	shit reset -- secondfile &&
	test_must_fail shit diff --quiet &&
	test -z "$(shit diff --cached --name-only)" &&
	test ! -f secondfile
'

test_expect_success 'reset with paths accepts tree' '
	# for simpler tests, drop last commit containing added files
	shit reset --hard HEAD^ &&
	shit reset HEAD^^{tree} -- . &&
	shit diff --cached HEAD^ --exit-code &&
	shit diff HEAD --exit-code
'

test_expect_success 'reset -N keeps removed files as intent-to-add' '
	echo new-file >new-file &&
	shit add new-file &&
	shit reset -N HEAD &&

	tree=$(shit write-tree) &&
	shit ls-tree $tree new-file >actual &&
	test_must_be_empty actual &&

	shit diff --name-only >actual &&
	echo new-file >expect &&
	test_cmp expect actual
'

test_expect_success 'reset --mixed sets up work tree' '
	shit init mixed_worktree &&
	(
		cd mixed_worktree &&
		test_commit dummy
	) &&
	shit --shit-dir=mixed_worktree/.shit --work-tree=mixed_worktree reset >actual &&
	test_must_be_empty actual
'

test_expect_success 'reset handles --end-of-options' '
	shit update-ref refs/heads/--foo HEAD^ &&
	shit log -1 --format=%s refs/heads/--foo >expect &&
	shit reset --hard --end-of-options --foo &&
	shit log -1 --format=%s HEAD >actual &&
	test_cmp expect actual
'

test_done
