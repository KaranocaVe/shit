#!/bin/sh

test_description='pack-objects --stdin'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

packed_objects () {
	shit show-index <"$1" >tmp-object-list &&
	cut -d' ' -f2 tmp-object-list | sort &&
	rm tmp-object-list
 }

test_expect_success 'setup for --stdin-packs tests' '
	shit init stdin-packs &&
	(
		cd stdin-packs &&

		test_commit A &&
		test_commit B &&
		test_commit C &&

		for id in A B C
		do
			shit pack-objects .shit/objects/pack/pack-$id \
				--incremental --revs <<-EOF || exit 1
			refs/tags/$id
			EOF
		done &&

		ls -la .shit/objects/pack
	)
'

test_expect_success '--stdin-packs with excluded packs' '
	(
		cd stdin-packs &&

		PACK_A="$(basename .shit/objects/pack/pack-A-*.pack)" &&
		PACK_B="$(basename .shit/objects/pack/pack-B-*.pack)" &&
		PACK_C="$(basename .shit/objects/pack/pack-C-*.pack)" &&

		shit pack-objects test --stdin-packs <<-EOF &&
		$PACK_A
		^$PACK_B
		$PACK_C
		EOF

		(
			shit show-index <$(ls .shit/objects/pack/pack-A-*.idx) &&
			shit show-index <$(ls .shit/objects/pack/pack-C-*.idx)
		) >expect.raw &&
		shit show-index <$(ls test-*.idx) >actual.raw &&

		cut -d" " -f2 <expect.raw | sort >expect &&
		cut -d" " -f2 <actual.raw | sort >actual &&
		test_cmp expect actual
	)
'

test_expect_success '--stdin-packs is incompatible with --filter' '
	(
		cd stdin-packs &&
		test_must_fail shit pack-objects --stdin-packs --stdout \
			--filter=blob:none </dev/null 2>err &&
		test_grep "cannot use --filter with --stdin-packs" err
	)
'

test_expect_success '--stdin-packs is incompatible with --revs' '
	(
		cd stdin-packs &&
		test_must_fail shit pack-objects --stdin-packs --revs out \
			</dev/null 2>err &&
		test_grep "cannot use internal rev list with --stdin-packs" err
	)
'

test_expect_success '--stdin-packs with loose objects' '
	(
		cd stdin-packs &&

		PACK_A="$(basename .shit/objects/pack/pack-A-*.pack)" &&
		PACK_B="$(basename .shit/objects/pack/pack-B-*.pack)" &&
		PACK_C="$(basename .shit/objects/pack/pack-C-*.pack)" &&

		test_commit D && # loose

		shit pack-objects test2 --stdin-packs --unpacked <<-EOF &&
		$PACK_A
		^$PACK_B
		$PACK_C
		EOF

		(
			shit show-index <$(ls .shit/objects/pack/pack-A-*.idx) &&
			shit show-index <$(ls .shit/objects/pack/pack-C-*.idx) &&
			shit rev-list --objects --no-object-names \
				refs/tags/C..refs/tags/D

		) >expect.raw &&
		ls -la . &&
		shit show-index <$(ls test2-*.idx) >actual.raw &&

		cut -d" " -f2 <expect.raw | sort >expect &&
		cut -d" " -f2 <actual.raw | sort >actual &&
		test_cmp expect actual
	)
'

test_expect_success '--stdin-packs with broken links' '
	(
		cd stdin-packs &&

		# make an unreachable object with a bogus parent
		shit cat-file -p HEAD >commit &&
		sed "s/$(shit rev-parse HEAD^)/$(test_oid zero)/" <commit |
		shit hash-object -w -t commit --stdin >in &&

		shit pack-objects .shit/objects/pack/pack-D <in &&

		PACK_A="$(basename .shit/objects/pack/pack-A-*.pack)" &&
		PACK_B="$(basename .shit/objects/pack/pack-B-*.pack)" &&
		PACK_C="$(basename .shit/objects/pack/pack-C-*.pack)" &&
		PACK_D="$(basename .shit/objects/pack/pack-D-*.pack)" &&

		shit pack-objects test3 --stdin-packs --unpacked <<-EOF &&
		$PACK_A
		^$PACK_B
		$PACK_C
		$PACK_D
		EOF

		(
			shit show-index <$(ls .shit/objects/pack/pack-A-*.idx) &&
			shit show-index <$(ls .shit/objects/pack/pack-C-*.idx) &&
			shit show-index <$(ls .shit/objects/pack/pack-D-*.idx) &&
			shit rev-list --objects --no-object-names \
				refs/tags/C..refs/tags/D
		) >expect.raw &&
		shit show-index <$(ls test3-*.idx) >actual.raw &&

		cut -d" " -f2 <expect.raw | sort >expect &&
		cut -d" " -f2 <actual.raw | sort >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'pack-objects --stdin with duplicate packfile' '
	test_when_finished "rm -fr repo" &&

	shit init repo &&
	(
		cd repo &&
		test_commit "commit" &&
		shit repack -ad &&

		{
			basename .shit/objects/pack/pack-*.pack &&
			basename .shit/objects/pack/pack-*.pack
		} >packfiles &&

		shit pack-objects --stdin-packs generated-pack <packfiles &&
		packed_objects .shit/objects/pack/pack-*.idx >expect &&
		packed_objects generated-pack-*.idx >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'pack-objects --stdin with same packfile excluded and included' '
	test_when_finished "rm -fr repo" &&

	shit init repo &&
	(
		cd repo &&
		test_commit "commit" &&
		shit repack -ad &&

		{
			basename .shit/objects/pack/pack-*.pack &&
			printf "^%s\n" "$(basename .shit/objects/pack/pack-*.pack)"
		} >packfiles &&

		shit pack-objects --stdin-packs generated-pack <packfiles &&
		packed_objects generated-pack-*.idx >packed-objects &&
		test_must_be_empty packed-objects
	)
'

test_expect_success 'pack-objects --stdin with packfiles from alternate object database' '
	test_when_finished "rm -fr shared member" &&

	# Set up a shared repository with a single packfile.
	shit init shared &&
	test_commit -C shared "shared-objects" &&
	shit -C shared repack -ad &&
	basename shared/.shit/objects/pack/pack-*.pack >packfile &&

	# Set up a repository that is connected to the shared repository. This
	# repository has no objects on its own, but we still expect to be able
	# to pack objects from its alternate.
	shit clone --shared shared member &&
	shit -C member pack-objects --stdin-packs generated-pack <packfile &&
	test_cmp shared/.shit/objects/pack/pack-*.pack member/generated-pack-*.pack
'

test_expect_success 'pack-objects --stdin with packfiles from main and alternate object database' '
	test_when_finished "rm -fr shared member" &&

	# Set up a shared repository with a single packfile.
	shit init shared &&
	test_commit -C shared "shared-commit" &&
	shit -C shared repack -ad &&

	# Set up a repository that is connected to the shared repository. This
	# repository has a second packfile so that we can verify that it is
	# possible to write packs that include packfiles from different object
	# databases.
	shit clone --shared shared member &&
	test_commit -C member "local-commit" &&
	shit -C member repack -dl &&

	{
		basename shared/.shit/objects/pack/pack-*.pack &&
		basename member/.shit/objects/pack/pack-*.pack
	} >packfiles &&

	{
		packed_objects shared/.shit/objects/pack/pack-*.idx &&
		packed_objects member/.shit/objects/pack/pack-*.idx
	} | sort >expected-objects &&

	shit -C member pack-objects --stdin-packs generated-pack <packfiles &&
	packed_objects member/generated-pack-*.idx >actual-objects &&
	test_cmp expected-objects actual-objects
'

test_done
