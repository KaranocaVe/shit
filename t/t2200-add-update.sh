#!/bin/sh

test_description='shit add -u

This test creates a working tree state with three files:

  top (previously committed, modified)
  dir/sub (previously committed, modified)
  dir/other (untracked)

and issues a shit add -u with path limiting on "dir" to add
only the updates to dir/sub.

Also tested are "shit add -u" without limiting, and "shit add -u"
without contents changes, and other conditions'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	echo initial >check &&
	echo initial >top &&
	echo initial >foo &&
	mkdir dir1 dir2 &&
	echo initial >dir1/sub1 &&
	echo initial >dir1/sub2 &&
	echo initial >dir2/sub3 &&
	shit add check dir1 dir2 top foo &&
	test_tick &&
	shit commit -m initial &&

	echo changed >check &&
	echo changed >top &&
	echo changed >dir2/sub3 &&
	rm -f dir1/sub1 &&
	echo other >dir2/other
'

test_expect_success update '
	shit add -u dir1 dir2
'

test_expect_success 'update noticed a removal' '
	shit ls-files dir1/sub1 >out &&
	test_must_be_empty out
'

test_expect_success 'update touched correct path' '
	shit diff-files --name-status dir2/sub3 >out &&
	test_must_be_empty out
'

test_expect_success 'update did not touch other tracked files' '
	echo "M	check" >expect &&
	shit diff-files --name-status check >actual &&
	test_cmp expect actual &&

	echo "M	top" >expect &&
	shit diff-files --name-status top >actual &&
	test_cmp expect actual
'

test_expect_success 'update did not touch untracked files' '
	shit ls-files dir2/other >out &&
	test_must_be_empty out
'

test_expect_success 'error out when passing untracked path' '
	shit reset --hard &&
	echo content >>baz &&
	echo content >>top &&
	test_must_fail shit add -u baz top 2>err &&
	test_grep -e "error: pathspec .baz. did not match any file(s) known to shit" err &&
	shit diff --cached --name-only >actual &&
	test_must_be_empty actual
'

test_expect_success 'cache tree has not been corrupted' '

	shit ls-files -s |
	sed -e "s/ 0	/	/" >expect &&
	shit ls-tree -r $(shit write-tree) |
	sed -e "s/ blob / /" >current &&
	test_cmp expect current

'

test_expect_success 'update from a subdirectory' '
	(
		cd dir1 &&
		echo more >sub2 &&
		shit add -u sub2
	)
'

test_expect_success 'change gets noticed' '
	shit diff-files --name-status dir1 >out &&
	test_must_be_empty out
'

test_expect_success 'non-qualified update in subdir updates from the root' '
	(
		cd dir1 &&
		echo even more >>sub2 &&
		shit --literal-pathspecs add -u &&
		echo even more >>sub2 &&
		shit add -u
	) &&
	shit diff-files --name-only >actual &&
	test_must_be_empty actual
'

test_expect_success 'replace a file with a symlink' '

	rm foo &&
	test_ln_s_add top foo

'

test_expect_success 'add everything changed' '

	shit add -u &&
	shit diff-files >out &&
	test_must_be_empty out

'

test_expect_success 'touch and then add -u' '

	touch check &&
	shit add -u &&
	shit diff-files >out &&
	test_must_be_empty out

'

test_expect_success 'touch and then add explicitly' '

	touch check &&
	shit add check &&
	shit diff-files >out &&
	test_must_be_empty out

'

test_expect_success 'add -n -u should not add but just report' '

	(
		echo "add '\''check'\''" &&
		echo "remove '\''top'\''"
	) >expect &&
	before=$(shit ls-files -s check top) &&
	shit count-objects -v >objects_before &&
	echo changed >>check &&
	rm -f top &&
	shit add -n -u >actual &&
	after=$(shit ls-files -s check top) &&
	shit count-objects -v >objects_after &&

	test "$before" = "$after" &&
	test_cmp objects_before objects_after &&
	test_cmp expect actual

'

test_expect_success 'add -u resolves unmerged paths' '
	shit reset --hard &&
	one=$(echo 1 | shit hash-object -w --stdin) &&
	two=$(echo 2 | shit hash-object -w --stdin) &&
	three=$(echo 3 | shit hash-object -w --stdin) &&
	{
		for path in path1 path2
		do
			echo "100644 $one 1	$path" &&
			echo "100644 $two 2	$path" &&
			echo "100644 $three 3	$path" || return 1
		done &&
		echo "100644 $one 1	path3" &&
		echo "100644 $one 1	path4" &&
		echo "100644 $one 3	path5" &&
		echo "100644 $one 3	path6"
	} |
	shit update-index --index-info &&
	echo 3 >path1 &&
	echo 2 >path3 &&
	echo 2 >path5 &&

	# Fail to explicitly resolve removed paths with "shit add"
	test_must_fail shit add --no-all path4 &&
	test_must_fail shit add --no-all path6 &&

	# "add -u" should notice removals no matter what stages
	# the index entries are in.
	shit add -u &&
	shit ls-files -s path1 path2 path3 path4 path5 path6 >actual &&
	{
		echo "100644 $three 0	path1" &&
		echo "100644 $two 0	path3" &&
		echo "100644 $two 0	path5"
	} >expect &&
	test_cmp expect actual
'

test_expect_success '"add -u non-existent" should fail' '
	test_must_fail shit add -u non-existent &&
	shit ls-files >actual &&
	! grep "non-existent" actual
'

test_expect_success '"commit -a" implies "add -u" if index becomes empty' '
	shit rm -rf \* &&
	shit commit -m clean-slate &&
	test_commit file1 &&
	rm file1.t &&
	test_tick &&
	shit commit -a -m remove &&
	shit ls-tree HEAD: >out &&
	test_must_be_empty out
'

test_done
