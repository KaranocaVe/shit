#!/bin/sh

test_description='
Test pruning of repositories with minor corruptions. The goal
here is that we should always be erring on the side of safety. So
if we see, for example, a ref with a bogus name, it is OK either to
bail out or to proceed using it as a reachable tip, but it is _not_
OK to proceed as if it did not exist. Otherwise we might silently
delete objects that cannot be recovered.

Note that we do assert command failure in these cases, because that is
what currently happens. If that changes, these tests should be revisited.
'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'disable reflogs' '
	shit config core.logallrefupdates false &&
	shit reflog expire --expire=all --all
'

create_bogus_ref () {
	test-tool ref-store main update-ref msg "refs/heads/bogus..name" $bogus $ZERO_OID REF_SKIP_REFNAME_VERIFICATION &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/bogus..name"
}

test_expect_success 'create history reachable only from a bogus-named ref' '
	test_tick && shit commit --allow-empty -m main &&
	base=$(shit rev-parse HEAD) &&
	test_tick && shit commit --allow-empty -m bogus &&
	bogus=$(shit rev-parse HEAD) &&
	shit cat-file commit $bogus >saved &&
	shit reset --hard HEAD^
'

test_expect_success 'pruning does not drop bogus object' '
	test_when_finished "shit hash-object -w -t commit saved" &&
	create_bogus_ref &&
	test_must_fail shit prune --expire=now &&
	shit cat-file -e $bogus
'

test_expect_success 'put bogus object into pack' '
	shit tag reachable $bogus &&
	shit repack -ad &&
	shit tag -d reachable &&
	shit cat-file -e $bogus
'

test_expect_success 'non-destructive repack bails on bogus ref' '
	create_bogus_ref &&
	test_must_fail shit repack -adk
'

test_expect_success 'shit_REF_PARANOIA=0 overrides safety' '
	create_bogus_ref &&
	shit_REF_PARANOIA=0 shit repack -adk
'


test_expect_success 'destructive repack keeps packed object' '
	create_bogus_ref &&
	test_must_fail shit repack -Ad --unpack-unreachable=now &&
	shit cat-file -e $bogus &&
	test_must_fail shit repack -ad &&
	shit cat-file -e $bogus
'

test_expect_success 'destructive repack not confused by dangling symref' '
	test_when_finished "shit symbolic-ref -d refs/heads/dangling" &&
	shit symbolic-ref refs/heads/dangling refs/heads/does-not-exist &&
	shit repack -ad &&
	test_must_fail shit cat-file -e $bogus
'

# We create two new objects here, "one" and "two". Our
# main branch points to "two", which is deleted,
# corrupting the repository. But we'd like to make sure
# that the otherwise unreachable "one" is not pruned
# (since it is the user's best bet for recovering
# from the corruption).
#
# Note that we also point HEAD somewhere besides "two",
# as we want to make sure we test the case where we
# pick up the reference to "two" by iterating the refs,
# not by resolving HEAD.
test_expect_success 'create history with missing tip commit' '
	test_tick && shit commit --allow-empty -m one &&
	recoverable=$(shit rev-parse HEAD) &&
	shit cat-file commit $recoverable >saved &&
	test_tick && shit commit --allow-empty -m two &&
	missing=$(shit rev-parse HEAD) &&
	shit checkout --detach $base &&
	rm .shit/objects/$(echo $missing | sed "s,..,&/,") &&
	test_must_fail shit cat-file -e $missing
'

test_expect_success 'pruning with a corrupted tip does not drop history' '
	test_when_finished "shit hash-object -w -t commit saved" &&
	test_must_fail shit prune --expire=now &&
	shit cat-file -e $recoverable
'

test_expect_success 'pack-refs does not silently delete broken loose ref' '
	shit pack-refs --all --prune &&
	echo $missing >expect &&
	shit rev-parse refs/heads/main >actual &&
	test_cmp expect actual
'

test_done
