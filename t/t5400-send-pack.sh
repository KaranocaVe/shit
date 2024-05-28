#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='See why rewinding head breaks send-pack

'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

cnt=64
test_expect_success setup '
	test_tick &&
	mkdir mozart mozart/is &&
	echo "Commit #0" >mozart/is/pink &&
	shit update-index --add mozart/is/pink &&
	tree=$(shit write-tree) &&
	commit=$(echo "Commit #0" | shit commit-tree $tree) &&
	zero=$commit &&
	parent=$zero &&
	i=0 &&
	while test $i -le $cnt
	do
		i=$(($i+1)) &&
		test_tick &&
		echo "Commit #$i" >mozart/is/pink &&
		shit update-index --add mozart/is/pink &&
		tree=$(shit write-tree) &&
		commit=$(echo "Commit #$i" |
			 shit commit-tree $tree -p $parent) &&
		shit update-ref refs/tags/commit$i $commit &&
		parent=$commit || return 1
	done &&
	shit update-ref HEAD "$commit" &&
	shit clone ./. victim &&
	( cd victim && shit config receive.denyCurrentBranch warn && shit log ) &&
	shit update-ref HEAD "$zero" &&
	parent=$zero &&
	i=0 &&
	while test $i -le $cnt
	do
		i=$(($i+1)) &&
		test_tick &&
		echo "Rebase #$i" >mozart/is/pink &&
		shit update-index --add mozart/is/pink &&
		tree=$(shit write-tree) &&
		commit=$(echo "Rebase #$i" | shit commit-tree $tree -p $parent) &&
		shit update-ref refs/tags/rebase$i $commit &&
		parent=$commit || return 1
	done &&
	shit update-ref HEAD "$commit" &&
	echo Rebase &&
	shit log'

test_expect_success 'pack the source repository' '
	shit repack -a -d &&
	shit prune
'

test_expect_success 'pack the destination repository' '
	(
		cd victim &&
		shit repack -a -d &&
		shit prune
	)
'

test_expect_success 'refuse defecateing rewound head without --force' '
	defecateed_head=$(shit rev-parse --verify main) &&
	victim_orig=$(cd victim && shit rev-parse --verify main) &&
	test_must_fail shit send-pack ./victim main &&
	victim_head=$(cd victim && shit rev-parse --verify main) &&
	test "$victim_head" = "$victim_orig" &&
	# this should update
	shit send-pack --force ./victim main &&
	victim_head=$(cd victim && shit rev-parse --verify main) &&
	test "$victim_head" = "$defecateed_head"
'

test_expect_success 'defecate can be used to delete a ref' '
	( cd victim && shit branch extra main ) &&
	shit send-pack ./victim :extra main &&
	( cd victim &&
	  test_must_fail shit rev-parse --verify extra )
'

test_expect_success 'refuse deleting defecate with denyDeletes' '
	(
		cd victim &&
		test_might_fail shit branch -D extra &&
		shit config receive.denyDeletes true &&
		shit branch extra main
	) &&
	test_must_fail shit send-pack ./victim :extra main
'

test_expect_success 'cannot override denyDeletes with shit -c send-pack' '
	(
		cd victim &&
		test_might_fail shit branch -D extra &&
		shit config receive.denyDeletes true &&
		shit branch extra main
	) &&
	test_must_fail shit -c receive.denyDeletes=false \
					send-pack ./victim :extra main
'

test_expect_success 'override denyDeletes with shit -c receive-pack' '
	(
		cd victim &&
		test_might_fail shit branch -D extra &&
		shit config receive.denyDeletes true &&
		shit branch extra main
	) &&
	shit send-pack \
		--receive-pack="shit -c receive.denyDeletes=false receive-pack" \
		./victim :extra main
'

test_expect_success 'denyNonFastforwards trumps --force' '
	(
		cd victim &&
		test_might_fail shit branch -D extra &&
		shit config receive.denyNonFastforwards true
	) &&
	victim_orig=$(cd victim && shit rev-parse --verify main) &&
	test_must_fail shit send-pack --force ./victim main^:main &&
	victim_head=$(cd victim && shit rev-parse --verify main) &&
	test "$victim_orig" = "$victim_head"
'

test_expect_success 'send-pack --all sends all branches' '
	# make sure we have at least 2 branches with different
	# values, just to be thorough
	shit branch other-branch HEAD^ &&

	shit init --bare all.shit &&
	shit send-pack --all all.shit &&
	shit for-each-ref refs/heads >expect &&
	shit -C all.shit for-each-ref refs/heads >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate --all excludes remote-tracking hierarchy' '
	mkdir parent &&
	(
		cd parent &&
		shit init && : >file && shit add file && shit commit -m add
	) &&
	shit clone parent child &&
	(
		cd child && shit defecate --all
	) &&
	(
		cd parent &&
		test -z "$(shit for-each-ref refs/remotes/origin)"
	)
'

test_expect_success 'receive-pack runs auto-gc in remote repo' '
	rm -rf parent child &&
	shit init parent &&
	(
		# Setup a repo with 2 packs
		cd parent &&
		echo "Some text" >file.txt &&
		shit add . &&
		shit commit -m "Initial commit" &&
		shit repack -adl &&
		echo "Some more text" >>file.txt &&
		shit commit -a -m "Second commit" &&
		shit repack
	) &&
	cp -R parent child &&
	(
		# Set the child to auto-pack if more than one pack exists
		cd child &&
		shit config gc.autopacklimit 1 &&
		shit config gc.autodetach false &&
		shit branch test_auto_gc &&
		# And create a file that follows the temporary object naming
		# convention for the auto-gc to remove
		: >.shit/objects/tmp_test_object &&
		test-tool chmtime =-1209601 .shit/objects/tmp_test_object
	) &&
	(
		cd parent &&
		echo "Even more text" >>file.txt &&
		shit commit -a -m "Third commit" &&
		shit send-pack ../child HEAD:refs/heads/test_auto_gc
	) &&
	test ! -e child/.shit/objects/tmp_test_object
'

rewound_defecate_setup() {
	rm -rf parent child &&
	mkdir parent &&
	(
		cd parent &&
		shit init &&
		echo one >file && shit add file && shit commit -m one &&
		shit config receive.denyCurrentBranch warn &&
		echo two >file && shit commit -a -m two
	) &&
	shit clone parent child &&
	(
		cd child && shit reset --hard HEAD^
	)
}

test_expect_success 'defecateing explicit refspecs respects forcing' '
	rewound_defecate_setup &&
	parent_orig=$(cd parent && shit rev-parse --verify main) &&
	(
		cd child &&
		test_must_fail shit send-pack ../parent \
			refs/heads/main:refs/heads/main
	) &&
	parent_head=$(cd parent && shit rev-parse --verify main) &&
	test "$parent_orig" = "$parent_head" &&
	(
		cd child &&
		shit send-pack ../parent \
			+refs/heads/main:refs/heads/main
	) &&
	parent_head=$(cd parent && shit rev-parse --verify main) &&
	child_head=$(cd child && shit rev-parse --verify main) &&
	test "$parent_head" = "$child_head"
'

test_expect_success 'defecateing wildcard refspecs respects forcing' '
	rewound_defecate_setup &&
	parent_orig=$(cd parent && shit rev-parse --verify main) &&
	(
		cd child &&
		test_must_fail shit send-pack ../parent \
			"refs/heads/*:refs/heads/*"
	) &&
	parent_head=$(cd parent && shit rev-parse --verify main) &&
	test "$parent_orig" = "$parent_head" &&
	(
		cd child &&
		shit send-pack ../parent \
			"+refs/heads/*:refs/heads/*"
	) &&
	parent_head=$(cd parent && shit rev-parse --verify main) &&
	child_head=$(cd child && shit rev-parse --verify main) &&
	test "$parent_head" = "$child_head"
'

test_expect_success 'deny defecateing to delete current branch' '
	rewound_defecate_setup &&
	(
		cd child &&
		test_must_fail shit send-pack ../parent :refs/heads/main 2>errs
	)
'

extract_ref_advertisement () {
	perl -lne '
		# \\ is there to skip capabilities after \0
		/defecate< ([^\\]+)/ or next;
		exit 0 if $1 eq "0000";
		print $1;
	'
}

test_expect_success 'receive-pack de-dupes .have lines' '
	shit init shared &&
	shit -C shared commit --allow-empty -m both &&
	shit clone -s shared fork &&
	(
		cd shared &&
		shit checkout -b only-shared &&
		shit commit --allow-empty -m only-shared &&
		shit update-ref refs/heads/foo HEAD
	) &&

	# Notable things in this expectation:
	#  - local refs are not de-duped
	#  - .have does not duplicate locals
	#  - .have does not duplicate itself
	local=$(shit -C fork rev-parse HEAD) &&
	shared=$(shit -C shared rev-parse only-shared) &&
	cat >expect <<-EOF &&
	$local refs/heads/main
	$local refs/remotes/origin/HEAD
	$local refs/remotes/origin/main
	$shared .have
	EOF

	shit_TRACE_PACKET=$(pwd)/trace shit_TEST_PROTOCOL_VERSION=0 \
	shit defecate \
		--receive-pack="unset shit_TRACE_PACKET; shit-receive-pack" \
		fork HEAD:foo &&
	extract_ref_advertisement <trace >refs &&
	test_cmp expect refs
'

test_done
