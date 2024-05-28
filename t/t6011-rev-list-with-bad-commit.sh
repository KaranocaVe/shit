#!/bin/sh

test_description='shit rev-list should notice bad commits'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# Note:
# - compression level is set to zero to make "corruptions" easier to perform
# - reflog is disabled to avoid extra references which would twart the test

test_expect_success 'setup' \
   '
   shit init &&
   shit config core.compression 0 &&
   shit config core.logallrefupdates false &&
   echo "foo" > foo &&
   shit add foo &&
   shit commit -m "first commit" &&
   echo "bar" > bar &&
   shit add bar &&
   shit commit -m "second commit" &&
   echo "baz" > baz &&
   shit add baz &&
   shit commit -m "third commit" &&
   echo "foo again" >> foo &&
   shit add foo &&
   shit commit -m "fourth commit" &&
   shit repack -a -f -d
   '

test_expect_success 'verify number of revisions' \
   '
   revs=$(shit rev-list --all | wc -l) &&
   test $revs -eq 4 &&
   first_commit=$(shit rev-parse HEAD~3)
   '

test_expect_success 'corrupt second commit object' \
   '
   perl -i.bak -pe "s/second commit/socond commit/" .shit/objects/pack/*.pack &&
   test_must_fail shit fsck --full
   '

test_expect_success 'rev-list should fail' '
	test_must_fail env shit_TEST_COMMIT_GRAPH=0 shit -c core.commitGraph=false rev-list --all > /dev/null
'

test_expect_success 'shit repack _MUST_ fail' \
   '
   test_must_fail shit repack -a -f -d
   '

test_expect_success 'first commit is still available' \
   '
   shit log $first_commit
   '

test_done

