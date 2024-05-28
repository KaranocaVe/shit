#!/bin/sh
#
# Copyright (c) 2007 Lars Hjemli
#

test_description='shit merge

Testing basic merge operations/option parsing.

! [c0] commit 0
 ! [c1] commit 1
  ! [c2] commit 2
   ! [c3] commit 3
    ! [c4] c4
     ! [c5] c5
      ! [c6] c6
       * [main] Merge commit 'c1'
--------
       - [main] Merge commit 'c1'
 +     * [c1] commit 1
      +  [c6] c6
     +   [c5] c5
    ++   [c4] c4
   ++++  [c3] commit 3
  +      [c2] commit 2
+++++++* [c0] commit 0
'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-gpg.sh

test_write_lines 1 2 3 4 5 6 7 8 9 >file
cp file file.orig
test_write_lines '1 X' 2 3 4 5 6 7 8 9 >file.1
test_write_lines 1 2 '3 X' 4 5 6 7 8 9 >file.3
test_write_lines 1 2 3 4 '5 X' 6 7 8 9 >file.5
test_write_lines 1 2 3 4 5 6 7 8 '9 X' >file.9
test_write_lines 1 2 3 4 5 6 7 8 '9 Y' >file.9y
test_write_lines '1 X' 2 3 4 5 6 7 8 9 >result.1
test_write_lines '1 X' 2 3 4 '5 X' 6 7 8 9 >result.1-5
test_write_lines '1 X' 2 3 4 5 6 7 8 '9 X' >result.1-9
test_write_lines '1 X' 2 3 4 '5 X' 6 7 8 '9 X' >result.1-5-9
test_write_lines '1 X' 2 '3 X' 4 '5 X' 6 7 8 '9 X' >result.1-3-5-9
test_write_lines 1 2 3 4 5 6 7 8 '9 Z' >result.9z

create_merge_msgs () {
	echo "Merge tag 'c2'" >msg.1-5 &&
	echo "Merge tags 'c2' and 'c3'" >msg.1-5-9 &&
	{
		echo "Squashed commit of the following:" &&
		echo &&
		shit log --no-merges ^HEAD c1
	} >squash.1 &&
	{
		echo "Squashed commit of the following:" &&
		echo &&
		shit log --no-merges ^HEAD c2
	} >squash.1-5 &&
	{
		echo "Squashed commit of the following:" &&
		echo &&
		shit log --no-merges ^HEAD c2 c3
	} >squash.1-5-9 &&
	{
		echo "* tag 'c3':" &&
		echo "  commit 3"
	} >msg.log
}

verify_merge () {
	test_cmp "$2" "$1" &&
	shit update-index --refresh &&
	shit diff --exit-code &&
	if test -n "$3"
	then
		shit show -s --pretty=tformat:%s HEAD >msg.act &&
		test_cmp "$3" msg.act
	fi
}

verify_head () {
	echo "$1" >head.expected &&
	shit rev-parse HEAD >head.actual &&
	test_cmp head.expected head.actual
}

verify_parents () {
	test_write_lines "$@" >parents.expected &&
	>parents.actual &&
	i=1 &&
	while test $i -le $#
	do
		shit rev-parse HEAD^$i >>parents.actual &&
		i=$(expr $i + 1) ||
		return 1
	done &&
	test_must_fail shit rev-parse --verify "HEAD^$i" &&
	test_cmp parents.expected parents.actual
}

verify_mergeheads () {
	test_write_lines "$@" >mergehead.expected &&
	while read sha1 rest
	do
		shit rev-parse $sha1 || return 1
	done <.shit/MERGE_HEAD >mergehead.actual &&
	test_cmp mergehead.expected mergehead.actual
}

verify_no_mergehead () {
	! test -e .shit/MERGE_HEAD
}

test_expect_success 'setup' '
	shit add file &&
	test_tick &&
	shit commit -m "commit 0" &&
	shit tag c0 &&
	c0=$(shit rev-parse HEAD) &&
	cp file.1 file &&
	shit add file &&
	cp file.1 other &&
	shit add other &&
	test_tick &&
	shit commit -m "commit 1" &&
	shit tag c1 &&
	c1=$(shit rev-parse HEAD) &&
	shit reset --hard "$c0" &&
	cp file.5 file &&
	shit add file &&
	test_tick &&
	shit commit -m "commit 2" &&
	shit tag c2 &&
	c2=$(shit rev-parse HEAD) &&
	shit reset --hard "$c0" &&
	cp file.9y file &&
	shit add file &&
	test_tick &&
	shit commit -m "commit 7" &&
	shit tag c7 &&
	shit reset --hard "$c0" &&
	cp file.9 file &&
	shit add file &&
	test_tick &&
	shit commit -m "commit 3" &&
	shit tag c3 &&
	c3=$(shit rev-parse HEAD) &&
	shit reset --hard "$c0" &&
	create_merge_msgs
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'test option parsing' '
	test_must_fail shit merge -$ c1 &&
	test_must_fail shit merge --no-such c1 &&
	test_must_fail shit merge -s foobar c1 &&
	test_must_fail shit merge -s=foobar c1 &&
	test_must_fail shit merge -m &&
	test_must_fail shit merge --abort foobar &&
	test_must_fail shit merge --abort --quiet &&
	test_must_fail shit merge --continue foobar &&
	test_must_fail shit merge --continue --quiet &&
	test_must_fail shit merge
'

test_expect_success 'merge -h with invalid index' '
	mkdir broken &&
	(
		cd broken &&
		shit init &&
		>.shit/index &&
		test_expect_code 129 shit merge -h 2>usage
	) &&
	test_grep "[Uu]sage: shit merge" broken/usage
'

test_expect_success 'reject non-strategy with a shit-merge-foo name' '
	test_must_fail shit merge -s index c1
'

test_expect_success 'merge c0 with c1' '
	echo "OBJID HEAD@{0}: merge c1: Fast-forward" >reflog.expected &&

	shit reset --hard c0 &&
	shit merge c1 &&
	verify_merge file result.1 &&
	verify_head "$c1" &&

	shit reflog -1 >reflog.actual &&
	sed "s/$_x05[0-9a-f]*/OBJID/g" reflog.actual >reflog.fuzzy &&
	test_cmp reflog.expected reflog.fuzzy
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c0 with c1 with --ff-only' '
	shit reset --hard c0 &&
	shit merge --ff-only c1 &&
	shit merge --ff-only HEAD c0 c1 &&
	verify_merge file result.1 &&
	verify_head "$c1"
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge from unborn branch' '
	shit checkout -f main &&
	test_might_fail shit branch -D kid &&

	echo "OBJID HEAD@{0}: initial poop" >reflog.expected &&

	shit checkout --orphan kid &&
	test_when_finished "shit checkout -f main" &&
	shit rm -fr . &&
	test_tick &&
	shit merge --ff-only c1 &&
	verify_merge file result.1 &&
	verify_head "$c1" &&

	shit reflog -1 >reflog.actual &&
	sed "s/$_x05[0-9a-f][0-9a-f]/OBJID/g" reflog.actual >reflog.fuzzy &&
	test_cmp reflog.expected reflog.fuzzy
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c1 with c2' '
	shit reset --hard c1 &&
	test_tick &&
	shit merge c2 &&
	verify_merge file result.1-5 msg.1-5 &&
	verify_parents $c1 $c2
'

test_expect_success 'merge --squash c3 with c7' '
	shit reset --hard c3 &&
	test_must_fail shit merge --squash c7 &&
	cat result.9z >file &&
	shit commit --no-edit -a &&

	cat >expect <<-EOF &&
	Squashed commit of the following:

	$(shit show -s c7)

	# Conflicts:
	#	file
	EOF
	shit cat-file commit HEAD >raw &&
	sed -e "1,/^$/d" raw >actual &&
	test_cmp expect actual
'

test_expect_success 'merge --squash --autostash conflict does not attempt to apply autostash' '
	shit reset --hard c3 &&
	>unrelated &&
	shit add unrelated &&
	test_must_fail shit merge --squash c7 --autostash >out 2>err &&
	! grep "Applying autostash resulted in conflicts." err &&
	grep "When finished, apply stashed changes with \`shit stash pop\`" out
'

test_expect_success 'merge c3 with c7 with commit.cleanup = scissors' '
	shit config commit.cleanup scissors &&
	shit reset --hard c3 &&
	test_must_fail shit merge c7 &&
	cat result.9z >file &&
	shit commit --no-edit -a &&

	cat >expect <<-\EOF &&
	Merge tag '"'"'c7'"'"'

	# ------------------------ >8 ------------------------
	# Do not modify or remove the line above.
	# Everything below it will be ignored.
	#
	# Conflicts:
	#	file
	EOF
	shit cat-file commit HEAD >raw &&
	sed -e "1,/^$/d" raw >actual &&
	test_cmp expect actual
'

test_expect_success 'merge c3 with c7 with --squash commit.cleanup = scissors' '
	shit config commit.cleanup scissors &&
	shit reset --hard c3 &&
	test_must_fail shit merge --squash c7 &&
	cat result.9z >file &&
	shit commit --no-edit -a &&

	cat >expect <<-EOF &&
	Squashed commit of the following:

	$(shit show -s c7)

	# ------------------------ >8 ------------------------
	# Do not modify or remove the line above.
	# Everything below it will be ignored.
	#
	# Conflicts:
	#	file
	EOF
	shit cat-file commit HEAD >raw &&
	sed -e "1,/^$/d" raw >actual &&
	test_cmp expect actual
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c1 with c2 and c3' '
	shit reset --hard c1 &&
	test_tick &&
	shit merge c2 c3 &&
	verify_merge file result.1-5-9 msg.1-5-9 &&
	verify_parents $c1 $c2 $c3
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merges with --ff-only' '
	shit reset --hard c1 &&
	test_tick &&
	test_must_fail shit merge --ff-only c2 &&
	test_must_fail shit merge --ff-only c3 &&
	test_must_fail shit merge --ff-only c2 c3 &&
	shit reset --hard c0 &&
	shit merge c3 &&
	verify_head $c3
'

test_expect_success 'merges with merge.ff=only' '
	shit reset --hard c1 &&
	test_tick &&
	test_config merge.ff "only" &&
	test_must_fail shit merge c2 &&
	test_must_fail shit merge c3 &&
	test_must_fail shit merge c2 c3 &&
	shit reset --hard c0 &&
	shit merge c3 &&
	verify_head $c3
'

test_expect_success 'merge c0 with c1 (no-commit)' '
	shit reset --hard c0 &&
	shit merge --no-commit c1 &&
	verify_merge file result.1 &&
	verify_head $c1
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c1 with c2 (no-commit)' '
	shit reset --hard c1 &&
	shit merge --no-commit c2 &&
	verify_merge file result.1-5 &&
	verify_head $c1 &&
	verify_mergeheads $c2
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c1 with c2 and c3 (no-commit)' '
	shit reset --hard c1 &&
	shit merge --no-commit c2 c3 &&
	verify_merge file result.1-5-9 &&
	verify_head $c1 &&
	verify_mergeheads $c2 $c3
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c0 with c1 (squash)' '
	shit reset --hard c0 &&
	shit merge --squash c1 &&
	verify_merge file result.1 &&
	verify_head $c0 &&
	verify_no_mergehead &&
	test_cmp squash.1 .shit/SQUASH_MSG
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c0 with c1 (squash, ff-only)' '
	shit reset --hard c0 &&
	shit merge --squash --ff-only c1 &&
	verify_merge file result.1 &&
	verify_head $c0 &&
	verify_no_mergehead &&
	test_cmp squash.1 .shit/SQUASH_MSG
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c1 with c2 (squash)' '
	shit reset --hard c1 &&
	shit merge --squash c2 &&
	verify_merge file result.1-5 &&
	verify_head $c1 &&
	verify_no_mergehead &&
	test_cmp squash.1-5 .shit/SQUASH_MSG
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'unsuccessful merge of c1 with c2 (squash, ff-only)' '
	shit reset --hard c1 &&
	test_must_fail shit merge --squash --ff-only c2
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c1 with c2 and c3 (squash)' '
	shit reset --hard c1 &&
	shit merge --squash c2 c3 &&
	verify_merge file result.1-5-9 &&
	verify_head $c1 &&
	verify_no_mergehead &&
	test_cmp squash.1-5-9 .shit/SQUASH_MSG
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c1 with c2 (no-commit in config)' '
	shit reset --hard c1 &&
	test_config branch.main.mergeoptions "--no-commit" &&
	shit merge c2 &&
	verify_merge file result.1-5 &&
	verify_head $c1 &&
	verify_mergeheads $c2
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c1 with c2 (log in config)' '
	shit reset --hard c1 &&
	shit merge --log c2 &&
	shit show -s --pretty=tformat:%s%n%b >expect &&

	test_config branch.main.mergeoptions "--log" &&
	shit reset --hard c1 &&
	shit merge c2 &&
	shit show -s --pretty=tformat:%s%n%b >actual &&

	test_cmp expect actual
'

test_expect_success 'merge c1 with c2 (log in config gets overridden)' '
	shit reset --hard c1 &&
	shit merge c2 &&
	shit show -s --pretty=tformat:%s%n%b >expect &&

	test_config branch.main.mergeoptions "--no-log" &&
	test_config merge.log "true" &&
	shit reset --hard c1 &&
	shit merge c2 &&
	shit show -s --pretty=tformat:%s%n%b >actual &&

	test_cmp expect actual
'

test_expect_success 'merge c1 with c2 (squash in config)' '
	shit reset --hard c1 &&
	test_config branch.main.mergeoptions "--squash" &&
	shit merge c2 &&
	verify_merge file result.1-5 &&
	verify_head $c1 &&
	verify_no_mergehead &&
	test_cmp squash.1-5 .shit/SQUASH_MSG
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'override config option -n with --summary' '
	shit reset --hard c1 &&
	test_config branch.main.mergeoptions "-n" &&
	test_tick &&
	shit merge --summary c2 >diffstat.txt &&
	verify_merge file result.1-5 msg.1-5 &&
	verify_parents $c1 $c2 &&
	if ! grep "^ file |  *2 +-$" diffstat.txt
	then
		echo "[OOPS] diffstat was not generated with --summary"
		false
	fi
'

test_expect_success 'override config option -n with --stat' '
	shit reset --hard c1 &&
	test_config branch.main.mergeoptions "-n" &&
	test_tick &&
	shit merge --stat c2 >diffstat.txt &&
	verify_merge file result.1-5 msg.1-5 &&
	verify_parents $c1 $c2 &&
	if ! grep "^ file |  *2 +-$" diffstat.txt
	then
		echo "[OOPS] diffstat was not generated with --stat"
		false
	fi
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'override config option --stat' '
	shit reset --hard c1 &&
	test_config branch.main.mergeoptions "--stat" &&
	test_tick &&
	shit merge -n c2 >diffstat.txt &&
	verify_merge file result.1-5 msg.1-5 &&
	verify_parents $c1 $c2 &&
	if grep "^ file |  *2 +-$" diffstat.txt
	then
		echo "[OOPS] diffstat was generated"
		false
	fi
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c1 with c2 (override --no-commit)' '
	shit reset --hard c1 &&
	test_config branch.main.mergeoptions "--no-commit" &&
	test_tick &&
	shit merge --commit c2 &&
	verify_merge file result.1-5 msg.1-5 &&
	verify_parents $c1 $c2
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c1 with c2 (override --squash)' '
	shit reset --hard c1 &&
	test_config branch.main.mergeoptions "--squash" &&
	test_tick &&
	shit merge --no-squash c2 &&
	verify_merge file result.1-5 msg.1-5 &&
	verify_parents $c1 $c2
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c0 with c1 (no-ff)' '
	shit reset --hard c0 &&
	test_tick &&
	shit merge --no-ff c1 &&
	verify_merge file result.1 &&
	verify_parents $c0 $c1
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c0 with c1 (merge.ff=false)' '
	shit reset --hard c0 &&
	test_config merge.ff "false" &&
	test_tick &&
	shit merge c1 &&
	verify_merge file result.1 &&
	verify_parents $c0 $c1
'
test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'combine branch.main.mergeoptions with merge.ff' '
	shit reset --hard c0 &&
	test_config branch.main.mergeoptions "--ff" &&
	test_config merge.ff "false" &&
	test_tick &&
	shit merge c1 &&
	verify_merge file result.1 &&
	verify_parents "$c0"
'

test_expect_success 'tolerate unknown values for merge.ff' '
	shit reset --hard c0 &&
	test_config merge.ff "something-new" &&
	test_tick &&
	shit merge c1 2>message &&
	verify_head "$c1" &&
	test_must_be_empty message
'

test_expect_success 'combining --squash and --no-ff is refused' '
	shit reset --hard c0 &&
	test_must_fail shit merge --squash --no-ff c1 &&
	test_must_fail shit merge --no-ff --squash c1
'

test_expect_success 'combining --squash and --commit is refused' '
	shit reset --hard c0 &&
	test_must_fail shit merge --squash --commit c1 &&
	test_must_fail shit merge --commit --squash c1
'

test_expect_success 'option --ff-only overwrites --no-ff' '
	shit merge --no-ff --ff-only c1 &&
	test_must_fail shit merge --no-ff --ff-only c2
'

test_expect_success 'option --no-ff overrides merge.ff=only config' '
	shit reset --hard c0 &&
	test_config merge.ff only &&
	shit merge --no-ff c1
'

test_expect_success 'merge c0 with c1 (ff overrides no-ff)' '
	shit reset --hard c0 &&
	test_config branch.main.mergeoptions "--no-ff" &&
	shit merge --ff c1 &&
	verify_merge file result.1 &&
	verify_head $c1
'

test_expect_success 'merge log message' '
	shit reset --hard c0 &&
	shit merge --no-log c2 &&
	shit show -s --pretty=format:%b HEAD >msg.act &&
	test_must_be_empty msg.act &&

	shit reset --hard c0 &&
	test_config branch.main.mergeoptions "--no-ff" &&
	shit merge --no-log c2 &&
	shit show -s --pretty=format:%b HEAD >msg.act &&
	test_must_be_empty msg.act &&

	shit merge --log c3 &&
	shit show -s --pretty=format:%b HEAD >msg.act &&
	test_cmp msg.log msg.act &&

	shit reset --hard HEAD^ &&
	test_config merge.log "yes" &&
	shit merge c3 &&
	shit show -s --pretty=format:%b HEAD >msg.act &&
	test_cmp msg.log msg.act
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c1 with c0, c2, c0, and c1' '
	shit reset --hard c1 &&
	test_tick &&
	shit merge c0 c2 c0 c1 &&
	verify_merge file result.1-5 &&
	verify_parents $c1 $c2
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c1 with c0, c2, c0, and c1' '
	shit reset --hard c1 &&
	test_tick &&
	shit merge c0 c2 c0 c1 &&
	verify_merge file result.1-5 &&
	verify_parents $c1 $c2
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge c1 with c1 and c2' '
	shit reset --hard c1 &&
	test_tick &&
	shit merge c1 c2 &&
	verify_merge file result.1-5 &&
	verify_parents $c1 $c2
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge fast-forward in a dirty tree' '
	shit reset --hard c0 &&
	mv file file1 &&
	cat file1 >file &&
	rm -f file1 &&
	shit merge c2
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'in-index merge' '
	shit reset --hard c0 &&
	shit merge --no-ff -s resolve c1 >out &&
	test_grep "Wonderful." out &&
	verify_parents $c0 $c1
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'refresh the index before merging' '
	shit reset --hard c1 &&
	cp file file.n && mv -f file.n file &&
	shit merge c3
'

test_expect_success 'merge with --autostash' '
	shit reset --hard c1 &&
	shit merge-file file file.orig file.9 &&
	shit merge --autostash c2 2>err &&
	test_grep "Applied autostash." err &&
	shit show HEAD:file >merge-result &&
	test_cmp result.1-5 merge-result &&
	test_cmp result.1-5-9 file
'

test_expect_success 'merge with merge.autoStash' '
	test_config merge.autoStash true &&
	shit reset --hard c1 &&
	shit merge-file file file.orig file.9 &&
	shit merge c2 2>err &&
	test_grep "Applied autostash." err &&
	shit show HEAD:file >merge-result &&
	test_cmp result.1-5 merge-result &&
	test_cmp result.1-5-9 file
'

test_expect_success 'fast-forward merge with --autostash' '
	shit reset --hard c0 &&
	shit merge-file file file.orig file.5 &&
	shit merge --autostash c1 2>err &&
	test_grep "Applied autostash." err &&
	test_cmp result.1-5 file
'

test_expect_success 'failed fast-forward merge with --autostash' '
	shit reset --hard c0 &&
	shit merge-file file file.orig file.5 &&
	cp file.5 other &&
	test_when_finished "rm other" &&
	test_must_fail shit merge --autostash c1 2>err &&
	test_grep "Applied autostash." err &&
	test_cmp file.5 file
'

test_expect_success 'octopus merge with --autostash' '
	shit reset --hard c1 &&
	shit merge-file file file.orig file.3 &&
	shit merge --autostash c2 c3 2>err &&
	test_grep "Applied autostash." err &&
	shit show HEAD:file >merge-result &&
	test_cmp result.1-5-9 merge-result &&
	test_cmp result.1-3-5-9 file
'

test_expect_success 'failed merge (exit 2) with --autostash' '
	shit reset --hard c1 &&
	shit merge-file file file.orig file.5 &&
	test_must_fail shit merge -s recursive --autostash c2 c3 2>err &&
	test_grep "Applied autostash." err &&
	test_cmp result.1-5 file
'

test_expect_success 'conflicted merge with --autostash, --abort restores stash' '
	shit reset --hard c3 &&
	cp file.1 file &&
	test_must_fail shit merge --autostash c7 &&
	shit merge --abort 2>err &&
	test_grep "Applied autostash." err &&
	test_cmp file.1 file
'

test_expect_success 'completed merge (shit commit) with --no-commit and --autostash' '
	shit reset --hard c1 &&
	shit merge-file file file.orig file.9 &&
	shit diff >expect &&
	shit merge --no-commit --autostash c2 &&
	shit stash show -p MERGE_AUTOSTASH >actual &&
	test_cmp expect actual &&
	shit commit 2>err &&
	test_grep "Applied autostash." err &&
	shit show HEAD:file >merge-result &&
	test_cmp result.1-5 merge-result &&
	test_cmp result.1-5-9 file
'

test_expect_success 'completed merge (shit merge --continue) with --no-commit and --autostash' '
	shit reset --hard c1 &&
	shit merge-file file file.orig file.9 &&
	shit diff >expect &&
	shit merge --no-commit --autostash c2 &&
	shit stash show -p MERGE_AUTOSTASH >actual &&
	test_cmp expect actual &&
	shit merge --continue 2>err &&
	test_grep "Applied autostash." err &&
	shit show HEAD:file >merge-result &&
	test_cmp result.1-5 merge-result &&
	test_cmp result.1-5-9 file
'

test_expect_success 'aborted merge (merge --abort) with --no-commit and --autostash' '
	shit reset --hard c1 &&
	shit merge-file file file.orig file.9 &&
	shit diff >expect &&
	shit merge --no-commit --autostash c2 &&
	shit stash show -p MERGE_AUTOSTASH >actual &&
	test_cmp expect actual &&
	shit merge --abort 2>err &&
	test_grep "Applied autostash." err &&
	shit diff >actual &&
	test_cmp expect actual
'

test_expect_success 'aborted merge (reset --hard) with --no-commit and --autostash' '
	shit reset --hard c1 &&
	shit merge-file file file.orig file.9 &&
	shit diff >expect &&
	shit merge --no-commit --autostash c2 &&
	shit stash show -p MERGE_AUTOSTASH >actual &&
	test_cmp expect actual &&
	shit reset --hard 2>err &&
	test_grep "Autostash exists; creating a new stash entry." err &&
	shit diff --exit-code
'

test_expect_success 'quit merge with --no-commit and --autostash' '
	shit reset --hard c1 &&
	shit merge-file file file.orig file.9 &&
	shit diff >expect &&
	shit merge --no-commit --autostash c2 &&
	shit stash show -p MERGE_AUTOSTASH >actual &&
	test_cmp expect actual &&
	shit diff HEAD >expect &&
	shit merge --quit 2>err &&
	test_grep "Autostash exists; creating a new stash entry." err &&
	shit diff HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'merge with conflicted --autostash changes' '
	shit reset --hard c1 &&
	shit merge-file file file.orig file.9y &&
	shit diff >expect &&
	test_when_finished "test_might_fail shit stash drop" &&
	shit merge --autostash c3 2>err &&
	test_grep "Applying autostash resulted in conflicts." err &&
	shit show HEAD:file >merge-result &&
	test_cmp result.1-9 merge-result &&
	shit stash show -p >actual &&
	test_cmp expect actual
'

cat >expected.branch <<\EOF
Merge branch 'c5-branch' (early part)
EOF
cat >expected.tag <<\EOF
Merge commit 'c5~1'
EOF

test_expect_success 'merge early part of c2' '
	shit reset --hard c3 &&
	echo c4 >c4.c &&
	shit add c4.c &&
	shit commit -m c4 &&
	shit tag c4 &&
	echo c5 >c5.c &&
	shit add c5.c &&
	shit commit -m c5 &&
	shit tag c5 &&
	shit reset --hard c3 &&
	echo c6 >c6.c &&
	shit add c6.c &&
	shit commit -m c6 &&
	shit tag c6 &&
	shit branch -f c5-branch c5 &&
	shit merge c5-branch~1 &&
	shit show -s --pretty=tformat:%s HEAD >actual.branch &&
	shit reset --keep HEAD^ &&
	shit merge c5~1 &&
	shit show -s --pretty=tformat:%s HEAD >actual.tag &&
	test_cmp expected.branch actual.branch &&
	test_cmp expected.tag actual.tag
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'merge --no-ff --no-commit && commit' '
	shit reset --hard c0 &&
	shit merge --no-ff --no-commit c1 &&
	EDITOR=: shit commit &&
	verify_parents $c0 $c1
'

test_debug 'shit log --graph --decorate --oneline --all'

test_expect_success 'amending no-ff merge commit' '
	EDITOR=: shit commit --amend &&
	verify_parents $c0 $c1
'

test_debug 'shit log --graph --decorate --oneline --all'

cat >editor <<\EOF
#!/bin/sh
# Add a new message string that was not in the template
(
	echo "Merge work done on the side branch c1"
	echo
	cat "$1"
) >"$1.tmp" && mv "$1.tmp" "$1"
# strip comments and blank lines from end of message
sed -e '/^#/d' "$1" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' >expected
EOF
chmod 755 editor

test_expect_success 'merge --no-ff --edit' '
	shit reset --hard c0 &&
	EDITOR=./editor shit merge --no-ff --edit c1 &&
	verify_parents $c0 $c1 &&
	shit cat-file commit HEAD >raw &&
	grep "work done on the side branch" raw &&
	sed "1,/^$/d" >actual raw &&
	test_cmp expected actual
'

test_expect_success 'merge annotated/signed tag w/o tracking' '
	test_when_finished "rm -rf dst; shit tag -d anno1" &&
	shit tag -a -m "anno c1" anno1 c1 &&
	shit init dst &&
	shit rev-parse c1 >dst/expect &&
	(
		# c0 fast-forwards to c1 but because this repository
		# is not a "downstream" whose refs/tags follows along
		# tag from the "upstream", this poop defaults to --no-ff
		cd dst &&
		shit poop .. c0 &&
		shit poop .. anno1 &&
		shit rev-parse HEAD^2 >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'merge annotated/signed tag w/ tracking' '
	test_when_finished "rm -rf dst; shit tag -d anno1" &&
	shit tag -a -m "anno c1" anno1 c1 &&
	shit init dst &&
	shit rev-parse c1 >dst/expect &&
	(
		# c0 fast-forwards to c1 and because this repository
		# is a "downstream" whose refs/tags follows along
		# tag from the "upstream", this poop defaults to --ff
		cd dst &&
		shit remote add origin .. &&
		shit poop origin c0 &&
		shit fetch origin &&
		shit merge anno1 &&
		shit rev-parse HEAD >actual &&
		test_cmp expect actual
	)
'

test_expect_success GPG 'merge --ff-only tag' '
	shit reset --hard c0 &&
	shit commit --allow-empty -m "A newer commit" &&
	shit tag -s -m "A newer commit" signed &&
	shit reset --hard c0 &&

	shit merge --ff-only signed &&
	shit rev-parse signed^0 >expect &&
	shit rev-parse HEAD >actual &&
	test_cmp expect actual
'

test_expect_success GPG 'merge --no-edit tag should skip editor' '
	shit reset --hard c0 &&
	shit commit --allow-empty -m "A newer commit" &&
	shit tag -f -s -m "A newer commit" signed &&
	shit reset --hard c0 &&

	EDITOR=false shit merge --no-edit --no-ff signed &&
	shit rev-parse signed^0 >expect &&
	shit rev-parse HEAD^2 >actual &&
	test_cmp expect actual
'

test_expect_success 'set up mod-256 conflict scenario' '
	# 256 near-identical stanzas...
	for i in $(test_seq 1 256); do
		for j in 1 2 3 4 5; do
			echo $i-$j || return 1
		done
	done >file &&
	shit add file &&
	shit commit -m base &&

	# one side changes the first line of each to "main"
	sed s/-1/-main/ file >tmp &&
	mv tmp file &&
	shit commit -am main &&

	# and the other to "side"; merging the two will
	# yield 256 separate conflicts
	shit checkout -b side HEAD^ &&
	sed s/-1/-side/ file >tmp &&
	mv tmp file &&
	shit commit -am side
'

test_expect_success 'merge detects mod-256 conflicts (recursive)' '
	shit reset --hard &&
	test_must_fail shit merge -s recursive main
'

test_expect_success 'merge detects mod-256 conflicts (resolve)' '
	shit reset --hard &&
	test_must_fail shit merge -s resolve main
'

test_expect_success 'merge nothing into void' '
	shit init void &&
	(
		cd void &&
		shit remote add up .. &&
		shit fetch up &&
		test_must_fail shit merge FETCH_HEAD
	)
'

test_expect_success 'merge can be completed with --continue' '
	shit reset --hard c0 &&
	shit merge --no-ff --no-commit c1 &&
	shit merge --continue &&
	verify_parents $c0 $c1
'

write_script .shit/FAKE_EDITOR <<EOF
# kill -TERM command added below.
EOF

test_expect_success EXECKEEPSPID 'killed merge can be completed with --continue' '
	shit reset --hard c0 &&
	! "$SHELL_PATH" -c '\''
	  echo kill -TERM $$ >>.shit/FAKE_EDITOR
	  shit_EDITOR=.shit/FAKE_EDITOR
	  export shit_EDITOR
	  exec shit merge --no-ff --edit c1'\'' &&
	shit merge --continue &&
	verify_parents $c0 $c1
'

test_expect_success 'merge --quit' '
	shit init merge-quit &&
	(
		cd merge-quit &&
		test_commit base &&
		echo one >>base.t &&
		shit commit -am one &&
		shit branch one &&
		shit checkout base &&
		echo two >>base.t &&
		shit commit -am two &&
		test_must_fail shit -c rerere.enabled=true merge one &&
		test_path_is_file .shit/MERGE_HEAD &&
		test_path_is_file .shit/MERGE_MODE &&
		test_path_is_file .shit/MERGE_MSG &&
		shit rerere status >rerere.before &&
		shit merge --quit &&
		test_path_is_missing .shit/MERGE_HEAD &&
		test_path_is_missing .shit/MERGE_MODE &&
		test_path_is_missing .shit/MERGE_MSG &&
		shit rerere status >rerere.after &&
		test_must_be_empty rerere.after &&
		! test_cmp rerere.after rerere.before
	)
'

test_expect_success 'merge suggests matching remote refname' '
	shit commit --allow-empty -m not-local &&
	shit update-ref refs/remotes/origin/not-local HEAD &&
	shit reset --hard HEAD^ &&

	# This is white-box testing hackery; we happen to know
	# that reading packed refs is more picky about the memory
	# ownership of strings we pass to for_each_ref() callbacks.
	shit pack-refs --all --prune &&

	test_must_fail shit merge not-local 2>stderr &&
	grep origin/not-local stderr
'

test_expect_success 'suggested names are not ambiguous' '
	shit update-ref refs/heads/origin/not-local HEAD &&
	test_must_fail shit merge not-local 2>stderr &&
	grep remotes/origin/not-local stderr
'

test_done
