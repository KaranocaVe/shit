#!/bin/sh

test_description='avoid rewriting packed-refs unnecessarily'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

if test_have_prereq !REFFILES
then
  skip_all='skipping files-backend specific pack-refs tests'
  test_done
fi

# Add an identifying mark to the packed-refs file header line. This
# shouldn't upset readers, and it should be omitted if the file is
# ever rewritten.
mark_packed_refs () {
	sed -e "s/^\(#.*\)/\1 t1409 /" .shit/packed-refs >.shit/packed-refs.new &&
	mv .shit/packed-refs.new .shit/packed-refs
}

# Verify that the packed-refs file is still marked.
check_packed_refs_marked () {
	grep -q '^#.* t1409 ' .shit/packed-refs
}

test_expect_success 'setup' '
	shit commit --allow-empty -m "Commit A" &&
	A=$(shit rev-parse HEAD) &&
	shit commit --allow-empty -m "Commit B" &&
	B=$(shit rev-parse HEAD) &&
	shit commit --allow-empty -m "Commit C" &&
	C=$(shit rev-parse HEAD)
'

test_expect_success 'do not create packed-refs file gratuitously' '
	test_path_is_missing .shit/packed-refs &&
	shit update-ref refs/heads/foo $A &&
	test_path_is_missing .shit/packed-refs &&
	shit update-ref refs/heads/foo $B &&
	test_path_is_missing .shit/packed-refs &&
	shit update-ref refs/heads/foo $C $B &&
	test_path_is_missing .shit/packed-refs &&
	shit update-ref -d refs/heads/foo &&
	test_path_is_missing .shit/packed-refs
'

test_expect_success 'check that marking the packed-refs file works' '
	shit for-each-ref >expected &&
	shit pack-refs --all &&
	mark_packed_refs &&
	check_packed_refs_marked &&
	shit for-each-ref >actual &&
	test_cmp expected actual &&
	shit pack-refs --all &&
	! check_packed_refs_marked &&
	shit for-each-ref >actual2 &&
	test_cmp expected actual2
'

test_expect_success 'leave packed-refs untouched on update of packed' '
	shit update-ref refs/heads/packed-update $A &&
	shit pack-refs --all &&
	mark_packed_refs &&
	shit update-ref refs/heads/packed-update $B &&
	check_packed_refs_marked
'

test_expect_success 'leave packed-refs untouched on checked update of packed' '
	shit update-ref refs/heads/packed-checked-update $A &&
	shit pack-refs --all &&
	mark_packed_refs &&
	shit update-ref refs/heads/packed-checked-update $B $A &&
	check_packed_refs_marked
'

test_expect_success 'leave packed-refs untouched on verify of packed' '
	shit update-ref refs/heads/packed-verify $A &&
	shit pack-refs --all &&
	mark_packed_refs &&
	echo "verify refs/heads/packed-verify $A" | shit update-ref --stdin &&
	check_packed_refs_marked
'

test_expect_success 'touch packed-refs on delete of packed' '
	shit update-ref refs/heads/packed-delete $A &&
	shit pack-refs --all &&
	mark_packed_refs &&
	shit update-ref -d refs/heads/packed-delete &&
	! check_packed_refs_marked
'

test_expect_success 'leave packed-refs untouched on update of loose' '
	shit pack-refs --all &&
	shit update-ref refs/heads/loose-update $A &&
	mark_packed_refs &&
	shit update-ref refs/heads/loose-update $B &&
	check_packed_refs_marked
'

test_expect_success 'leave packed-refs untouched on checked update of loose' '
	shit pack-refs --all &&
	shit update-ref refs/heads/loose-checked-update $A &&
	mark_packed_refs &&
	shit update-ref refs/heads/loose-checked-update $B $A &&
	check_packed_refs_marked
'

test_expect_success 'leave packed-refs untouched on verify of loose' '
	shit pack-refs --all &&
	shit update-ref refs/heads/loose-verify $A &&
	mark_packed_refs &&
	echo "verify refs/heads/loose-verify $A" | shit update-ref --stdin &&
	check_packed_refs_marked
'

test_expect_success 'leave packed-refs untouched on delete of loose' '
	shit pack-refs --all &&
	shit update-ref refs/heads/loose-delete $A &&
	mark_packed_refs &&
	shit update-ref -d refs/heads/loose-delete &&
	check_packed_refs_marked
'

test_done
