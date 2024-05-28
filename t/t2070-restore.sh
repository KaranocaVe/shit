#!/bin/sh

test_description='restore basic functionality'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit first &&
	echo first-and-a-half >>first.t &&
	shit add first.t &&
	test_commit second &&
	echo one >one &&
	echo two >two &&
	echo untracked >untracked &&
	echo ignored >ignored &&
	echo /ignored >.shitignore &&
	shit add one two .shitignore &&
	shit update-ref refs/heads/one main
'

test_expect_success 'restore without pathspec is not ok' '
	test_must_fail shit restore &&
	test_must_fail shit restore --source=first
'

test_expect_success 'restore a file, ignoring branch of same name' '
	cat one >expected &&
	echo dirty >>one &&
	shit restore one &&
	test_cmp expected one
'

test_expect_success 'restore a file on worktree from another ref' '
	test_when_finished shit reset --hard &&
	shit cat-file blob first:./first.t >expected &&
	shit restore --source=first first.t &&
	test_cmp expected first.t &&
	shit cat-file blob HEAD:./first.t >expected &&
	shit show :first.t >actual &&
	test_cmp expected actual
'

test_expect_success 'restore a file in the index from another ref' '
	test_when_finished shit reset --hard &&
	shit cat-file blob first:./first.t >expected &&
	shit restore --source=first --staged first.t &&
	shit show :first.t >actual &&
	test_cmp expected actual &&
	shit cat-file blob HEAD:./first.t >expected &&
	test_cmp expected first.t
'

test_expect_success 'restore a file in both the index and worktree from another ref' '
	test_when_finished shit reset --hard &&
	shit cat-file blob first:./first.t >expected &&
	shit restore --source=first --staged --worktree first.t &&
	shit show :first.t >actual &&
	test_cmp expected actual &&
	test_cmp expected first.t
'

test_expect_success 'restore --staged uses HEAD as source' '
	test_when_finished shit reset --hard &&
	shit cat-file blob :./first.t >expected &&
	echo index-dirty >>first.t &&
	shit add first.t &&
	shit restore --staged first.t &&
	shit cat-file blob :./first.t >actual &&
	test_cmp expected actual
'

test_expect_success 'restore --worktree --staged uses HEAD as source' '
	test_when_finished shit reset --hard &&
	shit show HEAD:./first.t >expected &&
	echo dirty >>first.t &&
	shit add first.t &&
	shit restore --worktree --staged first.t &&
	shit show :./first.t >actual &&
	test_cmp expected actual &&
	test_cmp expected first.t
'

test_expect_success 'restore --ignore-unmerged ignores unmerged entries' '
	shit init unmerged &&
	(
		cd unmerged &&
		echo one >unmerged &&
		echo one >common &&
		shit add unmerged common &&
		shit commit -m common &&
		shit switch -c first &&
		echo first >unmerged &&
		shit commit -am first &&
		shit switch -c second main &&
		echo second >unmerged &&
		shit commit -am second &&
		test_must_fail shit merge first &&

		echo dirty >>common &&
		test_must_fail shit restore . &&

		shit restore --ignore-unmerged --quiet . >output 2>&1 &&
		shit diff common >diff-output &&
		test_must_be_empty output &&
		test_must_be_empty diff-output
	)
'

test_expect_success 'restore --staged adds deleted intent-to-add file back to index' '
	echo "nonempty" >nonempty &&
	>empty &&
	shit add nonempty empty &&
	shit commit -m "create files to be deleted" &&
	shit rm --cached nonempty empty &&
	shit add -N nonempty empty &&
	shit restore --staged nonempty empty &&
	shit diff --cached --exit-code
'

test_expect_success 'restore --staged invalidates cache tree for deletions' '
	test_when_finished shit reset --hard &&
	>new1 &&
	>new2 &&
	shit add new1 new2 &&

	# It is important to commit and then reset here, so that the index
	# contains a valid cache-tree for the "both" tree.
	shit commit -m both &&
	shit reset --soft HEAD^ &&

	shit restore --staged new1 &&
	shit commit -m "just new2" &&
	shit rev-parse HEAD:new2 &&
	test_must_fail shit rev-parse HEAD:new1
'

test_expect_success 'restore --merge to unresolve' '
	O=$(echo original | shit hash-object -w --stdin) &&
	A=$(echo ourside | shit hash-object -w --stdin) &&
	B=$(echo theirside | shit hash-object -w --stdin) &&
	{
		echo "100644 $O 1	file" &&
		echo "100644 $A 2	file" &&
		echo "100644 $B 3	file"
	} | shit update-index --index-info &&
	echo nothing >file &&
	shit restore --worktree --merge file &&
	cat >expect <<-\EOF &&
	<<<<<<< ours
	ourside
	=======
	theirside
	>>>>>>> theirs
	EOF
	test_cmp expect file
'

test_expect_success 'restore --merge to unresolve after (mistaken) resolution' '
	O=$(echo original | shit hash-object -w --stdin) &&
	A=$(echo ourside | shit hash-object -w --stdin) &&
	B=$(echo theirside | shit hash-object -w --stdin) &&
	{
		echo "100644 $O 1	file" &&
		echo "100644 $A 2	file" &&
		echo "100644 $B 3	file"
	} | shit update-index --index-info &&
	echo nothing >file &&
	shit add file &&
	shit restore --worktree --merge file &&
	cat >expect <<-\EOF &&
	<<<<<<< ours
	ourside
	=======
	theirside
	>>>>>>> theirs
	EOF
	test_cmp expect file
'

test_expect_success 'restore --merge to unresolve after (mistaken) resolution' '
	O=$(echo original | shit hash-object -w --stdin) &&
	A=$(echo ourside | shit hash-object -w --stdin) &&
	B=$(echo theirside | shit hash-object -w --stdin) &&
	{
		echo "100644 $O 1	file" &&
		echo "100644 $A 2	file" &&
		echo "100644 $B 3	file"
	} | shit update-index --index-info &&
	shit rm -f file &&
	shit restore --worktree --merge file &&
	cat >expect <<-\EOF &&
	<<<<<<< ours
	ourside
	=======
	theirside
	>>>>>>> theirs
	EOF
	test_cmp expect file
'

test_expect_success 'restore with merge options are incompatible with certain options' '
	for opts in \
		"--staged --ours" \
		"--staged --theirs" \
		"--staged --merge" \
		"--source=HEAD --ours" \
		"--source=HEAD --theirs" \
		"--source=HEAD --merge" \
		"--staged --conflict=diff3" \
		"--staged --worktree --ours" \
		"--staged --worktree --theirs" \
		"--staged --worktree --merge" \
		"--staged --worktree --conflict=zdiff3"
	do
		test_must_fail shit restore $opts . 2>err &&
		grep "cannot be used" err || return
	done
'

test_done
