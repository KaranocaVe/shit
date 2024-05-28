#!/bin/sh

test_description='show-ref'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	test_commit --annotate A &&
	shit checkout -b side &&
	test_commit --annotate B &&
	shit checkout main &&
	test_commit C &&
	shit branch B A^0
'

test_expect_success 'show-ref' '
	echo $(shit rev-parse refs/tags/A) refs/tags/A >expect &&

	shit show-ref A >actual &&
	test_cmp expect actual &&

	shit show-ref tags/A >actual &&
	test_cmp expect actual &&

	shit show-ref refs/tags/A >actual &&
	test_cmp expect actual &&

	test_must_fail shit show-ref D >actual &&
	test_must_be_empty actual
'

test_expect_success 'show-ref -q' '
	shit show-ref -q A >actual &&
	test_must_be_empty actual &&

	shit show-ref -q tags/A >actual &&
	test_must_be_empty actual &&

	shit show-ref -q refs/tags/A >actual &&
	test_must_be_empty actual &&

	test_must_fail shit show-ref -q D >actual &&
	test_must_be_empty actual
'

test_expect_success 'show-ref --verify' '
	echo $(shit rev-parse refs/tags/A) refs/tags/A >expect &&

	shit show-ref --verify refs/tags/A >actual &&
	test_cmp expect actual &&

	test_must_fail shit show-ref --verify A >actual &&
	test_must_be_empty actual &&

	test_must_fail shit show-ref --verify tags/A >actual &&
	test_must_be_empty actual &&

	test_must_fail shit show-ref --verify D >actual &&
	test_must_be_empty actual
'

test_expect_success 'show-ref --verify -q' '
	shit show-ref --verify -q refs/tags/A >actual &&
	test_must_be_empty actual &&

	test_must_fail shit show-ref --verify -q A >actual &&
	test_must_be_empty actual &&

	test_must_fail shit show-ref --verify -q tags/A >actual &&
	test_must_be_empty actual &&

	test_must_fail shit show-ref --verify -q D >actual &&
	test_must_be_empty actual
'

test_expect_success 'show-ref -d' '
	{
		echo $(shit rev-parse refs/tags/A) refs/tags/A &&
		echo $(shit rev-parse refs/tags/A^0) "refs/tags/A^{}" &&
		echo $(shit rev-parse refs/tags/C) refs/tags/C
	} >expect &&
	shit show-ref -d A C >actual &&
	test_cmp expect actual &&

	shit show-ref -d tags/A tags/C >actual &&
	test_cmp expect actual &&

	shit show-ref -d refs/tags/A refs/tags/C >actual &&
	test_cmp expect actual &&

	shit show-ref --verify -d refs/tags/A refs/tags/C >actual &&
	test_cmp expect actual &&

	echo $(shit rev-parse refs/heads/main) refs/heads/main >expect &&
	shit show-ref -d main >actual &&
	test_cmp expect actual &&

	shit show-ref -d heads/main >actual &&
	test_cmp expect actual &&

	shit show-ref -d refs/heads/main >actual &&
	test_cmp expect actual &&

	shit show-ref -d --verify refs/heads/main >actual &&
	test_cmp expect actual &&

	test_must_fail shit show-ref -d --verify main >actual &&
	test_must_be_empty actual &&

	test_must_fail shit show-ref -d --verify heads/main >actual &&
	test_must_be_empty actual &&

	test_must_fail shit show-ref --verify -d A C >actual &&
	test_must_be_empty actual &&

	test_must_fail shit show-ref --verify -d tags/A tags/C >actual &&
	test_must_be_empty actual

'

test_expect_success 'show-ref --heads, --tags, --head, pattern' '
	for branch in B main side
	do
		echo $(shit rev-parse refs/heads/$branch) refs/heads/$branch || return 1
	done >expect.heads &&
	shit show-ref --heads >actual &&
	test_cmp expect.heads actual &&

	for tag in A B C
	do
		echo $(shit rev-parse refs/tags/$tag) refs/tags/$tag || return 1
	done >expect.tags &&
	shit show-ref --tags >actual &&
	test_cmp expect.tags actual &&

	cat expect.heads expect.tags >expect &&
	shit show-ref --heads --tags >actual &&
	test_cmp expect actual &&

	{
		echo $(shit rev-parse HEAD) HEAD &&
		cat expect.heads expect.tags
	} >expect &&
	shit show-ref --heads --tags --head >actual &&
	test_cmp expect actual &&

	{
		echo $(shit rev-parse HEAD) HEAD &&
		echo $(shit rev-parse refs/heads/B) refs/heads/B &&
		echo $(shit rev-parse refs/tags/B) refs/tags/B
	} >expect &&
	shit show-ref --head B >actual &&
	test_cmp expect actual &&

	{
		echo $(shit rev-parse HEAD) HEAD &&
		echo $(shit rev-parse refs/heads/B) refs/heads/B &&
		echo $(shit rev-parse refs/tags/B) refs/tags/B &&
		echo $(shit rev-parse refs/tags/B^0) "refs/tags/B^{}"
	} >expect &&
	shit show-ref --head -d B >actual &&
	test_cmp expect actual
'

test_expect_success 'show-ref --verify HEAD' '
	echo $(shit rev-parse HEAD) HEAD >expect &&
	shit show-ref --verify HEAD >actual &&
	test_cmp expect actual &&

	shit show-ref --verify -q HEAD >actual &&
	test_must_be_empty actual
'

test_expect_success 'show-ref --verify pseudorefs' '
	shit update-ref CHERRY_PICK_HEAD HEAD $ZERO_OID &&
	test_when_finished "shit update-ref -d CHERRY_PICK_HEAD" &&
	shit show-ref -s --verify HEAD >actual &&
	shit show-ref -s --verify CHERRY_PICK_HEAD >expect &&
	test_cmp actual expect
'

test_expect_success 'show-ref --verify with dangling ref' '
	sha1_file() {
		echo "$*" | sed "s#..#.shit/objects/&/#"
	} &&

	remove_object() {
		file=$(sha1_file "$*") &&
		test -e "$file" &&
		rm -f "$file"
	} &&

	test_when_finished "rm -rf dangling" &&
	(
		shit init dangling &&
		cd dangling &&
		test_commit dangling &&
		sha=$(shit rev-parse refs/tags/dangling) &&
		remove_object $sha &&
		test_must_fail shit show-ref --verify refs/tags/dangling
	)
'

test_expect_success 'show-ref sub-modes are mutually exclusive' '
	test_must_fail shit show-ref --verify --exclude-existing 2>err &&
	grep "verify" err &&
	grep "exclude-existing" err &&
	grep "cannot be used together" err &&

	test_must_fail shit show-ref --verify --exists 2>err &&
	grep "verify" err &&
	grep "exists" err &&
	grep "cannot be used together" err &&

	test_must_fail shit show-ref --exclude-existing --exists 2>err &&
	grep "exclude-existing" err &&
	grep "exists" err &&
	grep "cannot be used together" err
'

test_expect_success '--exists with existing reference' '
	shit show-ref --exists refs/heads/$shit_TEST_DEFAULT_INITIAL_BRANCH_NAME
'

test_expect_success '--exists with missing reference' '
	test_expect_code 2 shit show-ref --exists refs/heads/does-not-exist
'

test_expect_success '--exists does not use DWIM' '
	test_expect_code 2 shit show-ref --exists $shit_TEST_DEFAULT_INITIAL_BRANCH_NAME 2>err &&
	grep "reference does not exist" err
'

test_expect_success '--exists with HEAD' '
	shit show-ref --exists HEAD
'

test_expect_success '--exists with bad reference name' '
	test_when_finished "shit update-ref -d refs/heads/bad...name" &&
	new_oid=$(shit rev-parse HEAD) &&
	test-tool ref-store main update-ref msg refs/heads/bad...name $new_oid $ZERO_OID REF_SKIP_REFNAME_VERIFICATION &&
	shit show-ref --exists refs/heads/bad...name
'

test_expect_success '--exists with arbitrary symref' '
	test_when_finished "shit symbolic-ref -d refs/symref" &&
	shit symbolic-ref refs/symref refs/heads/$shit_TEST_DEFAULT_INITIAL_BRANCH_NAME &&
	shit show-ref --exists refs/symref
'

test_expect_success '--exists with dangling symref' '
	test_when_finished "shit symbolic-ref -d refs/heads/dangling" &&
	shit symbolic-ref refs/heads/dangling refs/heads/does-not-exist &&
	shit show-ref --exists refs/heads/dangling
'

test_expect_success '--exists with nonexistent object ID' '
	test-tool ref-store main update-ref msg refs/heads/missing-oid $(test_oid 001) $ZERO_OID REF_SKIP_OID_VERIFICATION &&
	shit show-ref --exists refs/heads/missing-oid
'

test_expect_success '--exists with non-commit object' '
	tree_oid=$(shit rev-parse HEAD^{tree}) &&
	test-tool ref-store main update-ref msg refs/heads/tree ${tree_oid} $ZERO_OID REF_SKIP_OID_VERIFICATION &&
	shit show-ref --exists refs/heads/tree
'

test_expect_success '--exists with directory fails with generic error' '
	cat >expect <<-EOF &&
	error: reference does not exist
	EOF
	test_expect_code 2 shit show-ref --exists refs/heads 2>err &&
	test_cmp expect err
'

test_expect_success '--exists with non-existent special ref' '
	test_expect_code 2 shit show-ref --exists FETCH_HEAD
'

test_expect_success '--exists with existing special ref' '
	test_when_finished "rm .shit/FETCH_HEAD" &&
	shit rev-parse HEAD >.shit/FETCH_HEAD &&
	shit show-ref --exists FETCH_HEAD
'

test_done
