#!/bin/sh
#
# Copyright (c) 2009 Christian Couder
#

test_description='Tests for "shit reset" with "--merge" and "--keep" options'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	printf "line %d\n" 1 2 3 >file1 &&
	cat file1 >file2 &&
	shit add file1 file2 &&
	test_tick &&
	shit commit -m "Initial commit" &&
	shit tag initial &&
	echo line 4 >>file1 &&
	cat file1 >file2 &&
	test_tick &&
	shit commit -m "add line 4 to file1" file1 &&
	shit tag second
'

# The next test will test the following:
#
#           working index HEAD target         working index HEAD
#           ----------------------------------------------------
# file1:     C       C     C    D     --merge  D       D     D
# file2:     C       D     D    D     --merge  C       D     D
test_expect_success 'reset --merge is ok with changes in file it does not touch' '
	shit reset --merge HEAD^ &&
	! grep 4 file1 &&
	grep 4 file2 &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse initial)" &&
	test -z "$(shit diff --cached)"
'

test_expect_success 'reset --merge is ok when switching back' '
	shit reset --merge second &&
	grep 4 file1 &&
	grep 4 file2 &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse second)" &&
	test -z "$(shit diff --cached)"
'

# The next test will test the following:
#
#           working index HEAD target         working index HEAD
#           ----------------------------------------------------
# file1:     C       C     C    D     --keep   D       D     D
# file2:     C       D     D    D     --keep   C       D     D
test_expect_success 'reset --keep is ok with changes in file it does not touch' '
	shit reset --hard second &&
	cat file1 >file2 &&
	shit reset --keep HEAD^ &&
	! grep 4 file1 &&
	grep 4 file2 &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse initial)" &&
	test -z "$(shit diff --cached)"
'

test_expect_success 'reset --keep is ok when switching back' '
	shit reset --keep second &&
	grep 4 file1 &&
	grep 4 file2 &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse second)" &&
	test -z "$(shit diff --cached)"
'

# The next test will test the following:
#
#           working index HEAD target         working index HEAD
#           ----------------------------------------------------
# file1:     B       B     C    D     --merge  D       D     D
# file2:     C       D     D    D     --merge  C       D     D
test_expect_success 'reset --merge discards changes added to index (1)' '
	shit reset --hard second &&
	cat file1 >file2 &&
	echo "line 5" >> file1 &&
	shit add file1 &&
	shit reset --merge HEAD^ &&
	! grep 4 file1 &&
	! grep 5 file1 &&
	grep 4 file2 &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse initial)" &&
	test -z "$(shit diff --cached)"
'

test_expect_success 'reset --merge is ok again when switching back (1)' '
	shit reset --hard initial &&
	echo "line 5" >> file2 &&
	shit add file2 &&
	shit reset --merge second &&
	! grep 4 file2 &&
	! grep 5 file1 &&
	grep 4 file1 &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse second)" &&
	test -z "$(shit diff --cached)"
'

# The next test will test the following:
#
#           working index HEAD target         working index HEAD
#           ----------------------------------------------------
# file1:     B       B     C    D     --keep   (disallowed)
test_expect_success 'reset --keep fails with changes in index in files it touches' '
	shit reset --hard second &&
	echo "line 5" >> file1 &&
	shit add file1 &&
	test_must_fail shit reset --keep HEAD^
'

# The next test will test the following:
#
#           working index HEAD target         working index HEAD
#           ----------------------------------------------------
# file1:     C       C     C    D     --merge  D       D     D
# file2:     C       C     D    D     --merge  D       D     D
test_expect_success 'reset --merge discards changes added to index (2)' '
	shit reset --hard second &&
	echo "line 4" >> file2 &&
	shit add file2 &&
	shit reset --merge HEAD^ &&
	! grep 4 file2 &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse initial)" &&
	test -z "$(shit diff)" &&
	test -z "$(shit diff --cached)"
'

test_expect_success 'reset --merge is ok again when switching back (2)' '
	shit reset --hard initial &&
	shit reset --merge second &&
	! grep 4 file2 &&
	grep 4 file1 &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse second)" &&
	test -z "$(shit diff --cached)"
'

# The next test will test the following:
#
#           working index HEAD target         working index HEAD
#           ----------------------------------------------------
# file1:     C       C     C    D     --keep   D       D     D
# file2:     C       C     D    D     --keep   C       D     D
test_expect_success 'reset --keep keeps changes it does not touch' '
	shit reset --hard second &&
	echo "line 4" >> file2 &&
	shit add file2 &&
	shit reset --keep HEAD^ &&
	grep 4 file2 &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse initial)" &&
	test -z "$(shit diff --cached)"
'

test_expect_success 'reset --keep keeps changes when switching back' '
	shit reset --keep second &&
	grep 4 file2 &&
	grep 4 file1 &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse second)" &&
	test -z "$(shit diff --cached)"
'

# The next test will test the following:
#
#           working index HEAD target         working index HEAD
#           ----------------------------------------------------
# file1:     A       B     B    C     --merge  (disallowed)
test_expect_success 'reset --merge fails with changes in file it touches' '
	shit reset --hard second &&
	echo "line 5" >> file1 &&
	test_tick &&
	shit commit -m "add line 5" file1 &&
	sed -e "s/line 1/changed line 1/" <file1 >file3 &&
	mv file3 file1 &&
	test_must_fail shit reset --merge HEAD^ 2>err.log &&
	grep file1 err.log | grep "not uptodate"
'

# The next test will test the following:
#
#           working index HEAD target         working index HEAD
#           ----------------------------------------------------
# file1:     A       B     B    C     --keep   (disallowed)
test_expect_success 'reset --keep fails with changes in file it touches' '
	shit reset --hard second &&
	echo "line 5" >> file1 &&
	test_tick &&
	shit commit -m "add line 5" file1 &&
	sed -e "s/line 1/changed line 1/" <file1 >file3 &&
	mv file3 file1 &&
	test_must_fail shit reset --keep HEAD^ 2>err.log &&
	grep file1 err.log | grep "not uptodate"
'

test_expect_success 'setup 3 different branches' '
	shit reset --hard second &&
	shit branch branch1 &&
	shit branch branch2 &&
	shit branch branch3 &&
	shit checkout branch1 &&
	echo "line 5 in branch1" >> file1 &&
	test_tick &&
	shit commit -a -m "change in branch1" &&
	shit checkout branch2 &&
	echo "line 5 in branch2" >> file1 &&
	test_tick &&
	shit commit -a -m "change in branch2" &&
	shit tag third &&
	shit checkout branch3 &&
	echo a new file >file3 &&
	rm -f file1 &&
	shit add file3 &&
	test_tick &&
	shit commit -a -m "change in branch3"
'

# The next test will test the following:
#
#           working index HEAD target         working index HEAD
#           ----------------------------------------------------
# file1:     X       U     B    C     --merge  C       C     C
test_expect_success '"reset --merge HEAD^" is ok with pending merge' '
	shit checkout third &&
	test_must_fail shit merge branch1 &&
	shit reset --merge HEAD^ &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse second)" &&
	test -z "$(shit diff --cached)" &&
	test -z "$(shit diff)"
'

# The next test will test the following:
#
#           working index HEAD target         working index HEAD
#           ----------------------------------------------------
# file1:     X       U     B    C     --keep   (disallowed)
test_expect_success '"reset --keep HEAD^" fails with pending merge' '
	shit reset --hard third &&
	test_must_fail shit merge branch1 &&
	test_must_fail shit reset --keep HEAD^ 2>err.log &&
	test_grep "middle of a merge" err.log
'

# The next test will test the following:
#
#           working index HEAD target         working index HEAD
#           ----------------------------------------------------
# file1:     X       U     B    B     --merge  B       B     B
test_expect_success '"reset --merge HEAD" is ok with pending merge' '
	shit reset --hard third &&
	test_must_fail shit merge branch1 &&
	shit reset --merge HEAD &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse third)" &&
	test -z "$(shit diff --cached)" &&
	test -z "$(shit diff)"
'

# The next test will test the following:
#
#           working index HEAD target         working index HEAD
#           ----------------------------------------------------
# file1:     X       U     B    B     --keep   (disallowed)
test_expect_success '"reset --keep HEAD" fails with pending merge' '
	shit reset --hard third &&
	test_must_fail shit merge branch1 &&
	test_must_fail shit reset --keep HEAD 2>err.log &&
	test_grep "middle of a merge" err.log
'

test_expect_success '--merge is ok with added/deleted merge' '
	shit reset --hard third &&
	rm -f file2 &&
	test_must_fail shit merge branch3 &&
	! test -f file2 &&
	test -f file3 &&
	shit diff --exit-code file3 &&
	shit diff --exit-code branch3 file3 &&
	shit reset --merge HEAD &&
	! test -f file3 &&
	! test -f file2 &&
	shit diff --exit-code --cached
'

test_expect_success '--keep fails with added/deleted merge' '
	shit reset --hard third &&
	rm -f file2 &&
	test_must_fail shit merge branch3 &&
	! test -f file2 &&
	test -f file3 &&
	shit diff --exit-code file3 &&
	shit diff --exit-code branch3 file3 &&
	test_must_fail shit reset --keep HEAD 2>err.log &&
	test_grep "middle of a merge" err.log
'

test_done
