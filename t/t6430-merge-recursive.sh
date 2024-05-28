#!/bin/sh

test_description='merge-recursive backend test'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-merge.sh

test_expect_success 'setup 1' '

	echo hello >a &&
	o0=$(shit hash-object a) &&
	cp a b &&
	cp a c &&
	mkdir d &&
	cp a d/e &&

	test_tick &&
	shit add a b c d/e &&
	shit commit -m initial &&
	c0=$(shit rev-parse --verify HEAD) &&
	shit branch side &&
	shit branch df-1 &&
	shit branch df-2 &&
	shit branch df-3 &&
	shit branch remove &&
	shit branch submod &&
	shit branch copy &&
	shit branch rename &&
	shit branch rename-ln &&

	echo hello >>a &&
	cp a d/e &&
	o1=$(shit hash-object a) &&

	shit add a d/e &&

	test_tick &&
	shit commit -m "main modifies a and d/e" &&
	c1=$(shit rev-parse --verify HEAD) &&
	( shit ls-tree -r HEAD && shit ls-files -s ) >actual &&
	(
		echo "100644 blob $o1	a" &&
		echo "100644 blob $o0	b" &&
		echo "100644 blob $o0	c" &&
		echo "100644 blob $o1	d/e" &&
		echo "100644 $o1 0	a" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o1 0	d/e"
	) >expected &&
	test_cmp expected actual
'

test_expect_success 'setup 2' '

	rm -rf [abcd] &&
	shit checkout side &&
	( shit ls-tree -r HEAD && shit ls-files -s ) >actual &&
	(
		echo "100644 blob $o0	a" &&
		echo "100644 blob $o0	b" &&
		echo "100644 blob $o0	c" &&
		echo "100644 blob $o0	d/e" &&
		echo "100644 $o0 0	a" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o0 0	d/e"
	) >expected &&
	test_cmp expected actual &&

	echo goodbye >>a &&
	o2=$(shit hash-object a) &&

	shit add a &&

	test_tick &&
	shit commit -m "side modifies a" &&
	c2=$(shit rev-parse --verify HEAD) &&
	( shit ls-tree -r HEAD && shit ls-files -s ) >actual &&
	(
		echo "100644 blob $o2	a" &&
		echo "100644 blob $o0	b" &&
		echo "100644 blob $o0	c" &&
		echo "100644 blob $o0	d/e" &&
		echo "100644 $o2 0	a" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o0 0	d/e"
	) >expected &&
	test_cmp expected actual
'

test_expect_success 'setup 3' '

	rm -rf [abcd] &&
	shit checkout df-1 &&
	( shit ls-tree -r HEAD && shit ls-files -s ) >actual &&
	(
		echo "100644 blob $o0	a" &&
		echo "100644 blob $o0	b" &&
		echo "100644 blob $o0	c" &&
		echo "100644 blob $o0	d/e" &&
		echo "100644 $o0 0	a" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o0 0	d/e"
	) >expected &&
	test_cmp expected actual &&

	rm -f b && mkdir b && echo df-1 >b/c && shit add b/c &&
	o3=$(shit hash-object b/c) &&

	test_tick &&
	shit commit -m "df-1 makes b/c" &&
	c3=$(shit rev-parse --verify HEAD) &&
	( shit ls-tree -r HEAD && shit ls-files -s ) >actual &&
	(
		echo "100644 blob $o0	a" &&
		echo "100644 blob $o3	b/c" &&
		echo "100644 blob $o0	c" &&
		echo "100644 blob $o0	d/e" &&
		echo "100644 $o0 0	a" &&
		echo "100644 $o3 0	b/c" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o0 0	d/e"
	) >expected &&
	test_cmp expected actual
'

test_expect_success 'setup 4' '

	rm -rf [abcd] &&
	shit checkout df-2 &&
	( shit ls-tree -r HEAD && shit ls-files -s ) >actual &&
	(
		echo "100644 blob $o0	a" &&
		echo "100644 blob $o0	b" &&
		echo "100644 blob $o0	c" &&
		echo "100644 blob $o0	d/e" &&
		echo "100644 $o0 0	a" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o0 0	d/e"
	) >expected &&
	test_cmp expected actual &&

	rm -f a && mkdir a && echo df-2 >a/c && shit add a/c &&
	o4=$(shit hash-object a/c) &&

	test_tick &&
	shit commit -m "df-2 makes a/c" &&
	c4=$(shit rev-parse --verify HEAD) &&
	( shit ls-tree -r HEAD && shit ls-files -s ) >actual &&
	(
		echo "100644 blob $o4	a/c" &&
		echo "100644 blob $o0	b" &&
		echo "100644 blob $o0	c" &&
		echo "100644 blob $o0	d/e" &&
		echo "100644 $o4 0	a/c" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o0 0	d/e"
	) >expected &&
	test_cmp expected actual
'

test_expect_success 'setup 5' '

	rm -rf [abcd] &&
	shit checkout remove &&
	( shit ls-tree -r HEAD && shit ls-files -s ) >actual &&
	(
		echo "100644 blob $o0	a" &&
		echo "100644 blob $o0	b" &&
		echo "100644 blob $o0	c" &&
		echo "100644 blob $o0	d/e" &&
		echo "100644 $o0 0	a" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o0 0	d/e"
	) >expected &&
	test_cmp expected actual &&

	rm -f b &&
	echo remove-conflict >a &&

	shit add a &&
	shit rm b &&
	o5=$(shit hash-object a) &&

	test_tick &&
	shit commit -m "remove removes b and modifies a" &&
	c5=$(shit rev-parse --verify HEAD) &&
	( shit ls-tree -r HEAD && shit ls-files -s ) >actual &&
	(
		echo "100644 blob $o5	a" &&
		echo "100644 blob $o0	c" &&
		echo "100644 blob $o0	d/e" &&
		echo "100644 $o5 0	a" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o0 0	d/e"
	) >expected &&
	test_cmp expected actual

'

test_expect_success 'setup 6' '

	rm -rf [abcd] &&
	shit checkout df-3 &&
	( shit ls-tree -r HEAD && shit ls-files -s ) >actual &&
	(
		echo "100644 blob $o0	a" &&
		echo "100644 blob $o0	b" &&
		echo "100644 blob $o0	c" &&
		echo "100644 blob $o0	d/e" &&
		echo "100644 $o0 0	a" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o0 0	d/e"
	) >expected &&
	test_cmp expected actual &&

	rm -fr d && echo df-3 >d && shit add d &&
	o6=$(shit hash-object d) &&

	test_tick &&
	shit commit -m "df-3 makes d" &&
	c6=$(shit rev-parse --verify HEAD) &&
	( shit ls-tree -r HEAD && shit ls-files -s ) >actual &&
	(
		echo "100644 blob $o0	a" &&
		echo "100644 blob $o0	b" &&
		echo "100644 blob $o0	c" &&
		echo "100644 blob $o6	d" &&
		echo "100644 $o0 0	a" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o6 0	d"
	) >expected &&
	test_cmp expected actual
'

test_expect_success 'setup 7' '

	shit checkout submod &&
	shit rm d/e &&
	test_tick &&
	shit commit -m "remove d/e" &&
	shit update-index --add --cacheinfo 160000 $c1 d &&
	test_tick &&
	shit commit -m "make d/ a submodule"
'

test_expect_success 'setup 8' '
	shit checkout rename &&
	shit mv a e &&
	shit add e &&
	test_tick &&
	shit commit -m "rename a->e" &&
	c7=$(shit rev-parse --verify HEAD) &&
	shit checkout rename-ln &&
	shit mv a e &&
	test_ln_s_add e a &&
	test_tick &&
	shit commit -m "rename a->e, symlink a->e" &&
	oln=$(printf e | shit hash-object --stdin)
'

test_expect_success 'setup 9' '
	shit checkout copy &&
	cp a e &&
	shit add e &&
	test_tick &&
	shit commit -m "copy a->e"
'

test_expect_success 'merge-recursive simple' '

	rm -fr [abcd] &&
	shit checkout -f "$c2" &&

	test_expect_code 1 shit merge-recursive "$c0" -- "$c2" "$c1"
'

test_expect_success 'merge-recursive result' '

	shit ls-files -s >actual &&
	(
		echo "100644 $o0 1	a" &&
		echo "100644 $o2 2	a" &&
		echo "100644 $o1 3	a" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o1 0	d/e"
	) >expected &&
	test_cmp expected actual

'

test_expect_success 'fail if the index has unresolved entries' '

	rm -fr [abcd] &&
	shit checkout -f "$c1" &&

	test_must_fail shit merge "$c5" &&
	test_must_fail shit merge "$c5" 2> out &&
	test_grep "not possible because you have unmerged files" out &&
	shit add -u &&
	test_must_fail shit merge "$c5" 2> out &&
	test_grep "You have not concluded your merge" out &&
	rm -f .shit/MERGE_HEAD &&
	test_must_fail shit merge "$c5" 2> out &&
	test_grep "Your local changes to the following files would be overwritten by merge:" out
'

test_expect_success 'merge-recursive remove conflict' '

	rm -fr [abcd] &&
	shit checkout -f "$c1" &&

	test_expect_code 1 shit merge-recursive "$c0" -- "$c1" "$c5"
'

test_expect_success 'merge-recursive remove conflict' '

	shit ls-files -s >actual &&
	(
		echo "100644 $o0 1	a" &&
		echo "100644 $o1 2	a" &&
		echo "100644 $o5 3	a" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o1 0	d/e"
	) >expected &&
	test_cmp expected actual

'

test_expect_success 'merge-recursive d/f simple' '
	rm -fr [abcd] &&
	shit reset --hard &&
	shit checkout -f "$c1" &&

	shit merge-recursive "$c0" -- "$c1" "$c3"
'

test_expect_success 'merge-recursive result' '

	shit ls-files -s >actual &&
	(
		echo "100644 $o1 0	a" &&
		echo "100644 $o3 0	b/c" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o1 0	d/e"
	) >expected &&
	test_cmp expected actual

'

test_expect_success 'merge-recursive d/f conflict' '

	rm -fr [abcd] &&
	shit reset --hard &&
	shit checkout -f "$c1" &&

	test_expect_code 1 shit merge-recursive "$c0" -- "$c1" "$c4"
'

test_expect_success 'merge-recursive d/f conflict result' '

	shit ls-files -s >actual &&
	(
		echo "100644 $o0 1	a" &&
		echo "100644 $o1 2	a" &&
		echo "100644 $o4 0	a/c" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o1 0	d/e"
	) >expected &&
	test_cmp expected actual

'

test_expect_success 'merge-recursive d/f conflict the other way' '

	rm -fr [abcd] &&
	shit reset --hard &&
	shit checkout -f "$c4" &&

	test_expect_code 1 shit merge-recursive "$c0" -- "$c4" "$c1"
'

test_expect_success 'merge-recursive d/f conflict result the other way' '

	shit ls-files -s >actual &&
	(
		echo "100644 $o0 1	a" &&
		echo "100644 $o1 3	a" &&
		echo "100644 $o4 0	a/c" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o1 0	d/e"
	) >expected &&
	test_cmp expected actual

'

test_expect_success 'merge-recursive d/f conflict' '

	rm -fr [abcd] &&
	shit reset --hard &&
	shit checkout -f "$c1" &&

	test_expect_code 1 shit merge-recursive "$c0" -- "$c1" "$c6"
'

test_expect_success 'merge-recursive d/f conflict result' '

	shit ls-files -s >actual &&
	(
		echo "100644 $o1 0	a" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o6 3	d" &&
		echo "100644 $o0 1	d/e" &&
		echo "100644 $o1 2	d/e"
	) >expected &&
	test_cmp expected actual

'

test_expect_success 'merge-recursive d/f conflict' '

	rm -fr [abcd] &&
	shit reset --hard &&
	shit checkout -f "$c6" &&

	test_expect_code 1 shit merge-recursive "$c0" -- "$c6" "$c1"
'

test_expect_success 'merge-recursive d/f conflict result' '

	shit ls-files -s >actual &&
	(
		echo "100644 $o1 0	a" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o6 2	d" &&
		echo "100644 $o0 1	d/e" &&
		echo "100644 $o1 3	d/e"
	) >expected &&
	test_cmp expected actual

'

test_expect_success SYMLINKS 'dir in working tree with symlink ancestor does not produce d/f conflict' '
	shit init sym &&
	(
		cd sym &&
		ln -s . foo &&
		mkdir bar &&
		>bar/file &&
		shit add foo bar/file &&
		shit commit -m "foo symlink" &&

		shit checkout -b branch1 &&
		shit commit --allow-empty -m "empty commit" &&

		shit checkout main &&
		shit rm foo &&
		mkdir foo &&
		>foo/bar &&
		shit add foo/bar &&
		shit commit -m "replace foo symlink with real foo dir and foo/bar file" &&

		shit checkout branch1 &&

		shit cherry-pick main &&
		test_path_is_dir foo &&
		test_path_is_file foo/bar
	)
'

test_expect_success 'reset and 3-way merge' '

	shit reset --hard "$c2" &&
	shit read-tree -m "$c0" "$c2" "$c1"

'

test_expect_success 'reset and bind merge' '

	shit reset --hard main &&
	shit read-tree --prefix=M/ main &&
	shit ls-files -s >actual &&
	(
		echo "100644 $o1 0	M/a" &&
		echo "100644 $o0 0	M/b" &&
		echo "100644 $o0 0	M/c" &&
		echo "100644 $o1 0	M/d/e" &&
		echo "100644 $o1 0	a" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o1 0	d/e"
	) >expected &&
	test_cmp expected actual &&

	shit read-tree --prefix=a1/ main &&
	shit ls-files -s >actual &&
	(
		echo "100644 $o1 0	M/a" &&
		echo "100644 $o0 0	M/b" &&
		echo "100644 $o0 0	M/c" &&
		echo "100644 $o1 0	M/d/e" &&
		echo "100644 $o1 0	a" &&
		echo "100644 $o1 0	a1/a" &&
		echo "100644 $o0 0	a1/b" &&
		echo "100644 $o0 0	a1/c" &&
		echo "100644 $o1 0	a1/d/e" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o1 0	d/e"
	) >expected &&
	test_cmp expected actual &&

	shit read-tree --prefix=z/ main &&
	shit ls-files -s >actual &&
	(
		echo "100644 $o1 0	M/a" &&
		echo "100644 $o0 0	M/b" &&
		echo "100644 $o0 0	M/c" &&
		echo "100644 $o1 0	M/d/e" &&
		echo "100644 $o1 0	a" &&
		echo "100644 $o1 0	a1/a" &&
		echo "100644 $o0 0	a1/b" &&
		echo "100644 $o0 0	a1/c" &&
		echo "100644 $o1 0	a1/d/e" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o1 0	d/e" &&
		echo "100644 $o1 0	z/a" &&
		echo "100644 $o0 0	z/b" &&
		echo "100644 $o0 0	z/c" &&
		echo "100644 $o1 0	z/d/e"
	) >expected &&
	test_cmp expected actual

'

test_expect_success 'merge-recursive w/ empty work tree - ours has rename' '
	(
		shit_WORK_TREE="$PWD/ours-has-rename-work" &&
		export shit_WORK_TREE &&
		shit_INDEX_FILE="$PWD/ours-has-rename-index" &&
		export shit_INDEX_FILE &&
		mkdir "$shit_WORK_TREE" &&
		shit read-tree -i -m $c7 2>actual-err &&
		test_must_be_empty actual-err &&
		shit update-index --ignore-missing --refresh 2>actual-err &&
		test_must_be_empty actual-err &&
		shit merge-recursive $c0 -- $c7 $c3 2>actual-err &&
		test_must_be_empty actual-err &&
		shit ls-files -s >actual-files 2>actual-err &&
		test_must_be_empty actual-err
	) &&
	cat >expected-files <<-EOF &&
	100644 $o3 0	b/c
	100644 $o0 0	c
	100644 $o0 0	d/e
	100644 $o0 0	e
	EOF
	test_cmp expected-files actual-files
'

test_expect_success 'merge-recursive w/ empty work tree - theirs has rename' '
	(
		shit_WORK_TREE="$PWD/theirs-has-rename-work" &&
		export shit_WORK_TREE &&
		shit_INDEX_FILE="$PWD/theirs-has-rename-index" &&
		export shit_INDEX_FILE &&
		mkdir "$shit_WORK_TREE" &&
		shit read-tree -i -m $c3 2>actual-err &&
		test_must_be_empty actual-err &&
		shit update-index --ignore-missing --refresh 2>actual-err &&
		test_must_be_empty actual-err &&
		shit merge-recursive $c0 -- $c3 $c7 2>actual-err &&
		test_must_be_empty actual-err &&
		shit ls-files -s >actual-files 2>actual-err &&
		test_must_be_empty actual-err
	) &&
	cat >expected-files <<-EOF &&
	100644 $o3 0	b/c
	100644 $o0 0	c
	100644 $o0 0	d/e
	100644 $o0 0	e
	EOF
	test_cmp expected-files actual-files
'

test_expect_success 'merge removes empty directories' '

	shit reset --hard main &&
	shit checkout -b rm &&
	shit rm d/e &&
	shit commit -mremoved-d/e &&
	shit checkout main &&
	shit merge -s recursive rm &&
	test_path_is_missing d
'

test_expect_success 'merge-recursive simple w/submodule' '

	shit checkout submod &&
	shit merge remove
'

test_expect_success 'merge-recursive simple w/submodule result' '

	shit ls-files -s >actual &&
	(
		echo "100644 $o5 0	a" &&
		echo "100644 $o0 0	c" &&
		echo "160000 $c1 0	d"
	) >expected &&
	test_cmp expected actual
'

test_expect_success 'merge-recursive copy vs. rename' '
	shit checkout -f copy &&
	shit merge rename &&
	( shit ls-tree -r HEAD && shit ls-files -s ) >actual &&
	(
		echo "100644 blob $o0	b" &&
		echo "100644 blob $o0	c" &&
		echo "100644 blob $o0	d/e" &&
		echo "100644 blob $o0	e" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o0 0	d/e" &&
		echo "100644 $o0 0	e"
	) >expected &&
	test_cmp expected actual
'

test_expect_merge_algorithm failure success 'merge-recursive rename vs. rename/symlink' '

	shit checkout -f rename &&
	shit merge rename-ln &&
	( shit ls-tree -r HEAD && shit ls-files -s ) >actual &&
	(
		echo "120000 blob $oln	a" &&
		echo "100644 blob $o0	b" &&
		echo "100644 blob $o0	c" &&
		echo "100644 blob $o0	d/e" &&
		echo "100644 blob $o0	e" &&
		echo "120000 $oln 0	a" &&
		echo "100644 $o0 0	b" &&
		echo "100644 $o0 0	c" &&
		echo "100644 $o0 0	d/e" &&
		echo "100644 $o0 0	e"
	) >expected &&
	test_cmp expected actual
'

test_expect_success 'merging with triple rename across D/F conflict' '
	shit reset --hard HEAD &&
	shit checkout -b topic &&
	shit rm -rf . &&

	echo "just a file" >sub1 &&
	mkdir -p sub2 &&
	echo content1 >sub2/file1 &&
	echo content2 >sub2/file2 &&
	echo content3 >sub2/file3 &&
	mkdir simple &&
	echo base >simple/bar &&
	shit add -A &&
	test_tick &&
	shit commit -m base &&

	shit checkout -b other &&
	echo more >>simple/bar &&
	test_tick &&
	shit commit -a -m changesimplefile &&

	shit checkout topic &&
	shit rm sub1 &&
	shit mv sub2 sub1 &&
	test_tick &&
	shit commit -m changefiletodir &&

	test_tick &&
	shit merge other
'

test_expect_success 'merge-recursive remembers the names of all base trees' '
	shit reset --hard HEAD &&

	# make the index match $c1 so that merge-recursive below does not
	# fail early
	shit diff --binary HEAD $c1 -- | shit apply --cached &&

	# more trees than static slots used by oid_to_hex()
	for commit in $c0 $c2 $c4 $c5 $c6 $c7
	do
		shit rev-parse "$commit^{tree}" || return 1
	done >trees &&

	# ignore the return code; it only fails because the input is weird...
	test_must_fail shit -c merge.verbosity=5 merge-recursive $(cat trees) -- $c1 $c3 >out &&

	# ...but make sure it fails in the expected way
	test_grep CONFLICT.*rename/rename out &&

	# merge-recursive prints in reverse order, but we do not care
	sort <trees >expect &&
	sed -n "s/^virtual //p" out | sort >actual &&
	test_cmp expect actual &&

	shit clean -fd
'

test_expect_success 'merge-recursive internal merge resolves to the sameness' '
	shit reset --hard HEAD &&

	# We are going to create a history leading to two criss-cross
	# branches A and B.  The common ancestor at the bottom, O0,
	# has two child commits O1 and O2, both of which will be merge
	# base between A and B, like so:
	#
	#       O1---A
	#      /  \ /
	#    O0    .
	#      \  / \
	#       O2---B
	#
	# The recently added "check to see if the index is different from
	# the tree into which something else is getting merged" check must
	# NOT kick in when an inner merge between O1 and O2 is made.  Both
	# O1 and O2 happen to have the same tree as O0 in this test to
	# trigger the bug---whether the inner merge is made by merging O2
	# into O1 or O1 into O2, their common ancestor O0 and the branch
	# being merged have the same tree.  We should not trigger the "is
	# the index dirty?" check in this case.

	echo "zero" >file &&
	shit add file &&
	test_tick &&
	shit commit -m "O0" &&
	O0=$(shit rev-parse HEAD) &&

	test_tick &&
	shit commit --allow-empty -m "O1" &&
	O1=$(shit rev-parse HEAD) &&

	shit reset --hard $O0 &&
	test_tick &&
	shit commit --allow-empty -m "O2" &&
	O2=$(shit rev-parse HEAD) &&

	test_tick &&
	shit merge -s ours $O1 &&
	B=$(shit rev-parse HEAD) &&

	shit reset --hard $O1 &&
	test_tick &&
	shit merge -s ours $O2 &&
	A=$(shit rev-parse HEAD) &&

	shit merge $B
'

test_done
