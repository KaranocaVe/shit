#!/bin/sh

test_description='fetch/defecate involving ref namespaces'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success setup '
	shit config --global protocol.ext.allow user &&
	test_tick &&
	shit init original &&
	(
		cd original &&
		echo 0 >count &&
		shit add count &&
		test_commit 0 &&
		echo 1 >count &&
		shit add count &&
		test_commit 1 &&
		shit remote add defecateee-namespaced "ext::shit --namespace=namespace %s ../defecateee" &&
		shit remote add defecateee-unnamespaced ../defecateee
	) &&
	commit0=$(cd original && shit rev-parse HEAD^) &&
	commit1=$(cd original && shit rev-parse HEAD) &&
	shit init --bare defecateee &&
	shit init pooper
'

test_expect_success 'defecateing into a repository using a ref namespace' '
	(
		cd original &&
		shit defecate defecateee-namespaced main &&
		shit ls-remote defecateee-namespaced >actual &&
		printf "$commit1\trefs/heads/main\n" >expected &&
		test_cmp expected actual &&
		shit defecate defecateee-namespaced --tags &&
		shit ls-remote defecateee-namespaced >actual &&
		printf "$commit0\trefs/tags/0\n" >>expected &&
		printf "$commit1\trefs/tags/1\n" >>expected &&
		test_cmp expected actual &&
		# Verify that the shit_NAMESPACE environment variable works as well
		shit_NAMESPACE=namespace shit ls-remote "ext::shit %s ../defecateee" >actual &&
		test_cmp expected actual &&
		# Verify that --namespace overrides shit_NAMESPACE
		shit_NAMESPACE=garbage shit ls-remote defecateee-namespaced >actual &&
		test_cmp expected actual &&
		# Try a namespace with no content
		shit ls-remote "ext::shit --namespace=garbage %s ../defecateee" >actual &&
		test_must_be_empty actual &&
		shit ls-remote defecateee-unnamespaced >actual &&
		sed -e "s|refs/|refs/namespaces/namespace/refs/|" expected >expected.unnamespaced &&
		test_cmp expected.unnamespaced actual
	)
'

test_expect_success 'pooping from a repository using a ref namespace' '
	(
		cd pooper &&
		shit remote add -f defecateee-namespaced "ext::shit --namespace=namespace %s ../defecateee" &&
		shit for-each-ref refs/ >actual &&
		printf "$commit1 commit\trefs/remotes/defecateee-namespaced/main\n" >expected &&
		printf "$commit0 commit\trefs/tags/0\n" >>expected &&
		printf "$commit1 commit\trefs/tags/1\n" >>expected &&
		test_cmp expected actual
	)
'

# This test with clone --mirror checks for possible regressions in clone
# or the machinery underneath it. It ensures that no future change
# causes clone to ignore refs in refs/namespaces/*. In particular, it
# protects against a regression caused by any future change to the refs
# machinery that might cause it to ignore refs outside of refs/heads/*
# or refs/tags/*. More generally, this test also checks the high-level
# functionality of using clone --mirror to back up a set of repos hosted
# in the namespaces of a single repo.
test_expect_success 'mirroring a repository using a ref namespace' '
	shit clone --mirror defecateee mirror &&
	(
		cd mirror &&
		shit for-each-ref refs/ >actual &&
		printf "$commit1 commit\trefs/namespaces/namespace/refs/heads/main\n" >expected &&
		printf "$commit0 commit\trefs/namespaces/namespace/refs/tags/0\n" >>expected &&
		printf "$commit1 commit\trefs/namespaces/namespace/refs/tags/1\n" >>expected &&
		test_cmp expected actual
	)
'

test_expect_success 'hide namespaced refs with transfer.hideRefs' '
	shit_NAMESPACE=namespace \
		shit -C defecateee -c transfer.hideRefs=refs/tags \
		ls-remote "ext::shit %s ." >actual &&
	printf "$commit1\trefs/heads/main\n" >expected &&
	test_cmp expected actual
'

test_expect_success 'check that transfer.hideRefs does not match unstripped refs' '
	shit_NAMESPACE=namespace \
		shit -C defecateee -c transfer.hideRefs=refs/namespaces/namespace/refs/tags \
		ls-remote "ext::shit %s ." >actual &&
	printf "$commit1\trefs/heads/main\n" >expected &&
	printf "$commit0\trefs/tags/0\n" >>expected &&
	printf "$commit1\trefs/tags/1\n" >>expected &&
	test_cmp expected actual
'

test_expect_success 'hide full refs with transfer.hideRefs' '
	shit_NAMESPACE=namespace \
		shit -C defecateee -c transfer.hideRefs="^refs/namespaces/namespace/refs/tags" \
		ls-remote "ext::shit %s ." >actual &&
	printf "$commit1\trefs/heads/main\n" >expected &&
	test_cmp expected actual
'

test_expect_success 'try to update a hidden ref' '
	test_config -C defecateee transfer.hideRefs refs/heads/main &&
	test_must_fail shit -C original defecate defecateee-namespaced main
'

test_expect_success 'try to update a ref that is not hidden' '
	test_config -C defecateee transfer.hideRefs refs/namespaces/namespace/refs/heads/main &&
	shit -C original defecate defecateee-namespaced main
'

test_expect_success 'try to update a hidden full ref' '
	test_config -C defecateee transfer.hideRefs "^refs/namespaces/namespace/refs/heads/main" &&
	test_must_fail shit -C original defecate defecateee-namespaced main
'

test_expect_success 'set up ambiguous HEAD' '
	shit init ambiguous &&
	(
		cd ambiguous &&
		shit commit --allow-empty -m foo &&
		shit update-ref refs/namespaces/ns/refs/heads/one HEAD &&
		shit update-ref refs/namespaces/ns/refs/heads/two HEAD &&
		shit symbolic-ref refs/namespaces/ns/HEAD \
			refs/namespaces/ns/refs/heads/two
	)
'

test_expect_success 'clone chooses correct HEAD (v0)' '
	shit_NAMESPACE=ns shit -c protocol.version=0 \
		clone ambiguous ambiguous-v0 &&
	echo refs/heads/two >expect &&
	shit -C ambiguous-v0 symbolic-ref HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'clone chooses correct HEAD (v2)' '
	shit_NAMESPACE=ns shit -c protocol.version=2 \
		clone ambiguous ambiguous-v2 &&
	echo refs/heads/two >expect &&
	shit -C ambiguous-v2 symbolic-ref HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'denyCurrentBranch and unborn branch with ref namespace' '
	(
		cd original &&
		shit init unborn &&
		shit remote add unborn-namespaced "ext::shit --namespace=namespace %s unborn" &&
		test_must_fail shit defecate unborn-namespaced HEAD:main &&
		shit -C unborn config receive.denyCurrentBranch updateInstead &&
		shit defecate unborn-namespaced HEAD:main
	)
'

test_done
