#!/bin/sh

test_description='test if rebase detects and aborts on incompatible options'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_seq 2 9 >foo &&
	shit add foo &&
	shit commit -m orig &&

	shit branch A &&
	shit branch B &&

	shit checkout A &&
	test_seq 1 9 >foo &&
	shit add foo &&
	shit commit -m A &&

	shit checkout B &&
	echo "q qfoo();" | q_to_tab >>foo &&
	shit add foo &&
	shit commit -m B
'

#
# Rebase has a couple options which are specific to the apply backend,
# and several options which are specific to the merge backend.  Flags
# from the different sets cannot work together, and we do not want to
# just ignore one of the sets of flags.  Make sure rebase warns the
# user and aborts instead.
#

test_rebase_am_only () {
	opt=$1
	shift
	test_expect_success "$opt incompatible with --merge" "
		shit checkout B^0 &&
		test_must_fail shit rebase $opt --merge A
	"

	test_expect_success "$opt incompatible with --strategy=ours" "
		shit checkout B^0 &&
		test_must_fail shit rebase $opt --strategy=ours A
	"

	test_expect_success "$opt incompatible with --strategy-option=ours" "
		shit checkout B^0 &&
		test_must_fail shit rebase $opt --strategy-option=ours A
	"

	test_expect_success "$opt incompatible with --autosquash" "
		shit checkout B^0 &&
		test_must_fail shit rebase $opt --autosquash A
	"

	test_expect_success "$opt incompatible with --interactive" "
		shit checkout B^0 &&
		test_must_fail shit rebase $opt --interactive A
	"

	test_expect_success "$opt incompatible with --exec" "
		shit checkout B^0 &&
		test_must_fail shit rebase $opt --exec 'true' A
	"

	test_expect_success "$opt incompatible with --keep-empty" "
		shit checkout B^0 &&
		test_must_fail shit rebase $opt --keep-empty A
	"

	test_expect_success "$opt incompatible with --empty=..." "
		shit checkout B^0 &&
		test_must_fail shit rebase $opt --empty=ask A
	"

	test_expect_success "$opt incompatible with --no-reapply-cherry-picks" "
		shit checkout B^0 &&
		test_must_fail shit rebase $opt --no-reapply-cherry-picks A
	"

	test_expect_success "$opt incompatible with --reapply-cherry-picks" "
		shit checkout B^0 &&
		test_must_fail shit rebase $opt --reapply-cherry-picks A
	"

	test_expect_success "$opt incompatible with --rebase-merges" "
		shit checkout B^0 &&
		test_must_fail shit rebase $opt --rebase-merges A
	"

	test_expect_success "$opt incompatible with --update-refs" "
		shit checkout B^0 &&
		test_must_fail shit rebase $opt --update-refs A
	"

	test_expect_success "$opt incompatible with --root without --onto" "
		shit checkout B^0 &&
		test_must_fail shit rebase $opt --root A
	"

	test_expect_success "$opt incompatible with rebase.rebaseMerges" "
		shit checkout B^0 &&
		test_must_fail shit -c rebase.rebaseMerges=true rebase $opt A 2>err &&
		grep -e --no-rebase-merges err
	"

	test_expect_success "$opt incompatible with rebase.updateRefs" "
		shit checkout B^0 &&
		test_must_fail shit -c rebase.updateRefs=true rebase $opt A 2>err &&
		grep -e --no-update-refs err
	"

	test_expect_success "$opt okay with overridden rebase.rebaseMerges" "
		test_when_finished \"shit reset --hard B^0\" &&
		shit checkout B^0 &&
		shit -c rebase.rebaseMerges=true rebase --no-rebase-merges $opt A
	"

	test_expect_success "$opt okay with overridden rebase.updateRefs" "
		test_when_finished \"shit reset --hard B^0\" &&
		shit checkout B^0 &&
		shit -c rebase.updateRefs=true rebase --no-update-refs $opt A
	"
}

# Check options which imply --apply
test_rebase_am_only --whitespace=fix
test_rebase_am_only -C4
# Also check an explicit --apply
test_rebase_am_only --apply

test_done
