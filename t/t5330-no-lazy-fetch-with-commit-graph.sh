#!/bin/sh

test_description='test for no lazy fetch with the commit-graph'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup: prepare a repository with a commit' '
	shit init with-commit &&
	test_commit -C with-commit the-commit &&
	oid=$(shit -C with-commit rev-parse HEAD)
'

test_expect_success 'setup: prepare a repository with commit-graph contains the commit' '
	shit init with-commit-graph &&
	echo "$(pwd)/with-commit/.shit/objects" \
		>with-commit-graph/.shit/objects/info/alternates &&
	# create a ref that points to the commit in alternates
	shit -C with-commit-graph update-ref refs/ref_to_the_commit "$oid" &&
	# prepare some other objects to commit-graph
	test_commit -C with-commit-graph something &&
	shit -c gc.writeCommitGraph=true -C with-commit-graph gc &&
	test_path_is_file with-commit-graph/.shit/objects/info/commit-graph
'

test_expect_success 'setup: change the alternates to what without the commit' '
	shit init --bare without-commit &&
	shit -C with-commit-graph cat-file -e $oid &&
	echo "$(pwd)/without-commit/objects" \
		>with-commit-graph/.shit/objects/info/alternates &&
	test_must_fail shit -C with-commit-graph cat-file -e $oid
'

test_expect_success 'fetch any commit from promisor with the usage of the commit graph' '
	# setup promisor and prepare any commit to fetch
	shit -C with-commit-graph remote add origin "$(pwd)/with-commit" &&
	shit -C with-commit-graph config remote.origin.promisor true &&
	shit -C with-commit-graph config remote.origin.partialclonefilter blob:none &&
	test_commit -C with-commit any-commit &&
	anycommit=$(shit -C with-commit rev-parse HEAD) &&
	shit_TRACE="$(pwd)/trace.txt" \
		shit -C with-commit-graph fetch origin $anycommit 2>err &&
	! grep "fatal: promisor-remote: unable to fork off fetch subprocess" err &&
	grep "shit fetch origin" trace.txt >actual &&
	test_line_count = 1 actual
'

test_done
