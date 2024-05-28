#!/bin/sh

test_description='filter-branch removal of trees with null sha1'

. ./test-lib.sh

test_expect_success 'setup: base commits' '
	test_commit one &&
	test_commit two &&
	test_commit three
'

test_expect_success 'setup: a commit with a bogus null sha1 in the tree' '
	{
		shit ls-tree HEAD &&
		printf "160000 commit $ZERO_OID\\tbroken\\n"
	} >broken-tree &&
	echo "add broken entry" >msg &&

	tree=$(shit mktree <broken-tree) &&
	test_tick &&
	commit=$(shit commit-tree $tree -p HEAD <msg) &&
	shit update-ref HEAD "$commit"
'

# we have to make one more commit on top removing the broken
# entry, since otherwise our index does not match HEAD (and filter-branch will
# complain). We could make the index match HEAD, but doing so would involve
# writing a null sha1 into the index.
test_expect_success 'setup: bring HEAD and index in sync' '
	test_tick &&
	shit commit -a -m "back to normal"
'

test_expect_success 'noop filter-branch complains' '
	test_must_fail shit filter-branch \
		--force --prune-empty \
		--index-filter "true"
'

test_expect_success 'filter commands are still checked' '
	test_must_fail shit filter-branch \
		--force --prune-empty \
		--index-filter "shit rm --cached --ignore-unmatch three.t"
'

test_expect_success 'removing the broken entry works' '
	echo three >expect &&
	shit filter-branch \
		--force --prune-empty \
		--index-filter "shit rm --cached --ignore-unmatch broken" &&
	shit log -1 --format=%s >actual &&
	test_cmp expect actual
'

test_done
