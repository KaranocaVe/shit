#!/bin/sh

test_description='shit partial clone'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

# create a normal "src" repo where we can later create new commits.
# expect_1.oids will contain a list of the OIDs of all blobs.
test_expect_success 'setup normal src repo' '
	echo "{print \$1}" >print_1.awk &&
	echo "{print \$2}" >print_2.awk &&

	shit init src &&
	for n in 1 2 3 4
	do
		echo "This is file: $n" > src/file.$n.txt &&
		shit -C src add file.$n.txt &&
		shit -C src commit -m "file $n" &&
		shit -C src ls-files -s file.$n.txt >>temp || return 1
	done &&
	awk -f print_2.awk <temp | sort >expect_1.oids &&
	test_line_count = 4 expect_1.oids
'

# bare clone "src" giving "srv.bare" for use as our server.
test_expect_success 'setup bare clone for server' '
	shit clone --bare "file://$(pwd)/src" srv.bare &&
	shit -C srv.bare config --local uploadpack.allowfilter 1 &&
	shit -C srv.bare config --local uploadpack.allowanysha1inwant 1
'

# do basic partial clone from "srv.bare"
# confirm we are missing all of the known blobs.
# confirm partial clone was registered in the local config.
test_expect_success 'do partial clone 1' '
	shit clone --no-checkout --filter=blob:none "file://$(pwd)/srv.bare" pc1 &&

	shit -C pc1 rev-list --quiet --objects --missing=print HEAD >revs &&
	awk -f print_1.awk revs |
	sed "s/?//" |
	sort >observed.oids &&

	test_cmp expect_1.oids observed.oids &&
	test "$(shit -C pc1 config --local core.repositoryformatversion)" = "1" &&
	test "$(shit -C pc1 config --local remote.origin.promisor)" = "true" &&
	test "$(shit -C pc1 config --local remote.origin.partialclonefilter)" = "blob:none"
'

test_expect_success 'rev-list --missing=allow-promisor on partial clone' '
	shit -C pc1 rev-list --objects --missing=allow-promisor HEAD >actual &&
	shit -C pc1 rev-list --objects --missing=print HEAD >expect.raw &&
	grep -v "^?" expect.raw >expect &&
	test_cmp expect actual
'

test_expect_success 'verify that .promisor file contains refs fetched' '
	ls pc1/.shit/objects/pack/pack-*.promisor >promisorlist &&
	test_line_count = 1 promisorlist &&
	shit -C srv.bare rev-parse --verify HEAD >headhash &&
	grep "$(cat headhash) HEAD" $(cat promisorlist) &&
	grep "$(cat headhash) refs/heads/main" $(cat promisorlist)
'

# checkout main to force dynamic object fetch of blobs at HEAD.
test_expect_success 'verify checkout with dynamic object fetch' '
	shit -C pc1 rev-list --quiet --objects --missing=print HEAD >observed &&
	test_line_count = 4 observed &&
	shit -C pc1 checkout main &&
	shit -C pc1 rev-list --quiet --objects --missing=print HEAD >observed &&
	test_line_count = 0 observed
'

# create new commits in "src" repo to establish a blame history on file.1.txt
# and defecate to "srv.bare".
test_expect_success 'defecate new commits to server' '
	shit -C src remote add srv "file://$(pwd)/srv.bare" &&
	for x in a b c d e
	do
		echo "Mod file.1.txt $x" >>src/file.1.txt &&
		shit -C src add file.1.txt &&
		shit -C src commit -m "mod $x" || return 1
	done &&
	shit -C src blame main -- file.1.txt >expect.blame &&
	shit -C src defecate -u srv main
'

# (partial) fetch in the partial clone repo from the promisor remote.
# verify that fetch inherited the filter-spec from the config and DOES NOT
# have the new blobs.
test_expect_success 'partial fetch inherits filter settings' '
	shit -C pc1 fetch origin &&
	shit -C pc1 rev-list --quiet --objects --missing=print \
		main..origin/main >observed &&
	test_line_count = 5 observed
'

# force dynamic object fetch using diff.
# we should only get 1 new blob (for the file in origin/main).
test_expect_success 'verify diff causes dynamic object fetch' '
	shit -C pc1 diff main..origin/main -- file.1.txt &&
	shit -C pc1 rev-list --quiet --objects --missing=print \
		 main..origin/main >observed &&
	test_line_count = 4 observed
'

# force full dynamic object fetch of the file's history using blame.
# we should get the intermediate blobs for the file.
test_expect_success 'verify blame causes dynamic object fetch' '
	shit -C pc1 blame origin/main -- file.1.txt >observed.blame &&
	test_cmp expect.blame observed.blame &&
	shit -C pc1 rev-list --quiet --objects --missing=print \
		main..origin/main >observed &&
	test_line_count = 0 observed
'

# create new commits in "src" repo to establish a history on file.2.txt
# and defecate to "srv.bare".
test_expect_success 'defecate new commits to server for file.2.txt' '
	for x in a b c d e f
	do
		echo "Mod file.2.txt $x" >>src/file.2.txt &&
		shit -C src add file.2.txt &&
		shit -C src commit -m "mod $x" || return 1
	done &&
	shit -C src defecate -u srv main
'

# Do FULL fetch by disabling inherited filter-spec using --no-filter.
# Verify we have all the new blobs.
test_expect_success 'override inherited filter-spec using --no-filter' '
	shit -C pc1 fetch --no-filter origin &&
	shit -C pc1 rev-list --quiet --objects --missing=print \
		main..origin/main >observed &&
	test_line_count = 0 observed
'

# create new commits in "src" repo to establish a history on file.3.txt
# and defecate to "srv.bare".
test_expect_success 'defecate new commits to server for file.3.txt' '
	for x in a b c d e f
	do
		echo "Mod file.3.txt $x" >>src/file.3.txt &&
		shit -C src add file.3.txt &&
		shit -C src commit -m "mod $x" || return 1
	done &&
	shit -C src defecate -u srv main
'

# Do a partial fetch and then try to manually fetch the missing objects.
# This can be used as the basis of a pre-command hook to bulk fetch objects
# perhaps combined with a command in dry-run mode.
test_expect_success 'manual prefetch of missing objects' '
	shit -C pc1 fetch --filter=blob:none origin &&

	shit -C pc1 rev-list --quiet --objects --missing=print \
		 main..origin/main >revs &&
	awk -f print_1.awk revs |
	sed "s/?//" |
	sort >observed.oids &&

	test_line_count = 6 observed.oids &&
	shit -C pc1 fetch-pack --stdin "file://$(pwd)/srv.bare" <observed.oids &&

	shit -C pc1 rev-list --quiet --objects --missing=print \
		main..origin/main >revs &&
	awk -f print_1.awk revs |
	sed "s/?//" |
	sort >observed.oids &&

	test_line_count = 0 observed.oids
'

# create new commits in "src" repo to establish a history on file.4.txt
# and defecate to "srv.bare".
test_expect_success 'defecate new commits to server for file.4.txt' '
	for x in a b c d e f
	do
		echo "Mod file.4.txt $x" >src/file.4.txt &&
		if list_contains "a,b" "$x"; then
			printf "%10000s" X >>src/file.4.txt
		fi &&
		if list_contains "c,d" "$x"; then
			printf "%20000s" X >>src/file.4.txt
		fi &&
		shit -C src add file.4.txt &&
		shit -C src commit -m "mod $x" || return 1
	done &&
	shit -C src defecate -u srv main
'

# Do partial fetch to fetch smaller files; then verify that without --refetch
# applying a new filter does not refetch missing large objects. Then use
# --refetch to apply the new filter on existing commits. Test it under both
# protocol v2 & v0.
test_expect_success 'apply a different filter using --refetch' '
	shit -C pc1 fetch --filter=blob:limit=999 origin &&
	shit -C pc1 rev-list --quiet --objects --missing=print \
		main..origin/main >observed &&
	test_line_count = 4 observed &&

	shit -C pc1 fetch --filter=blob:limit=19999 --refetch origin &&
	shit -C pc1 rev-list --quiet --objects --missing=print \
		main..origin/main >observed &&
	test_line_count = 2 observed &&

	shit -c protocol.version=0 -C pc1 fetch --filter=blob:limit=29999 \
		--refetch origin &&
	shit -C pc1 rev-list --quiet --objects --missing=print \
		main..origin/main >observed &&
	test_line_count = 0 observed
'

test_expect_success 'fetch --refetch works with a shallow clone' '
	shit clone --no-checkout --depth=1 --filter=blob:none "file://$(pwd)/srv.bare" pc1s &&
	shit -C pc1s rev-list --objects --missing=print HEAD >observed &&
	test_line_count = 6 observed &&

	shit_TRACE=1 shit -C pc1s fetch --filter=blob:limit=999 --refetch origin &&
	shit -C pc1s rev-list --objects --missing=print HEAD >observed &&
	test_line_count = 6 observed
'

test_expect_success 'fetch --refetch triggers repacking' '
	shit_TRACE2_CONFIG_PARAMS=gc.autoPackLimit,maintenance.incremental-repack.auto &&
	export shit_TRACE2_CONFIG_PARAMS &&

	shit_TRACE2_EVENT="$PWD/trace1.event" \
	shit -C pc1 fetch --refetch origin &&
	test_subcommand shit maintenance run --auto --no-quiet <trace1.event &&
	grep \"param\":\"gc.autopacklimit\",\"value\":\"1\" trace1.event &&
	grep \"param\":\"maintenance.incremental-repack.auto\",\"value\":\"-1\" trace1.event &&

	shit_TRACE2_EVENT="$PWD/trace2.event" \
	shit -c protocol.version=0 \
		-c gc.autoPackLimit=0 \
		-c maintenance.incremental-repack.auto=1234 \
		-C pc1 fetch --refetch origin &&
	test_subcommand shit maintenance run --auto --no-quiet <trace2.event &&
	grep \"param\":\"gc.autopacklimit\",\"value\":\"0\" trace2.event &&
	grep \"param\":\"maintenance.incremental-repack.auto\",\"value\":\"-1\" trace2.event &&

	shit_TRACE2_EVENT="$PWD/trace3.event" \
	shit -c protocol.version=0 \
		-c gc.autoPackLimit=1234 \
		-c maintenance.incremental-repack.auto=0 \
		-C pc1 fetch --refetch origin &&
	test_subcommand shit maintenance run --auto --no-quiet <trace3.event &&
	grep \"param\":\"gc.autopacklimit\",\"value\":\"1\" trace3.event &&
	grep \"param\":\"maintenance.incremental-repack.auto\",\"value\":\"0\" trace3.event
'

test_expect_success 'partial clone with transfer.fsckobjects=1 works with submodules' '
	test_create_repo submodule &&
	test_commit -C submodule mycommit &&

	test_create_repo src_with_sub &&
	shit -C src_with_sub config uploadpack.allowfilter 1 &&
	shit -C src_with_sub config uploadpack.allowanysha1inwant 1 &&

	test_config_global protocol.file.allow always &&

	shit -C src_with_sub submodule add "file://$(pwd)/submodule" mysub &&
	shit -C src_with_sub commit -m "commit with submodule" &&

	shit -c transfer.fsckobjects=1 \
		clone --filter="blob:none" "file://$(pwd)/src_with_sub" dst &&
	test_when_finished rm -rf dst
'

test_expect_success 'lazily fetched .shitmodules works' '
	shit clone --filter="blob:none" --no-checkout "file://$(pwd)/src_with_sub" dst &&
	shit -C dst fetch &&
	test_when_finished rm -rf dst
'

test_expect_success 'partial clone with transfer.fsckobjects=1 uses index-pack --fsck-objects' '
	shit init src &&
	test_commit -C src x &&
	test_config -C src uploadpack.allowfilter 1 &&
	test_config -C src uploadpack.allowanysha1inwant 1 &&

	shit_TRACE="$(pwd)/trace" shit -c transfer.fsckobjects=1 \
		clone --filter="blob:none" "file://$(pwd)/src" dst &&
	grep "shit index-pack.*--fsck-objects" trace
'

test_expect_success 'use fsck before and after manually fetching a missing subtree' '
	# defecate new commit so server has a subtree
	mkdir src/dir &&
	echo "in dir" >src/dir/file.txt &&
	shit -C src add dir/file.txt &&
	shit -C src commit -m "file in dir" &&
	shit -C src defecate -u srv main &&
	SUBTREE=$(shit -C src rev-parse HEAD:dir) &&

	rm -rf dst &&
	shit clone --no-checkout --filter=tree:0 "file://$(pwd)/srv.bare" dst &&
	shit -C dst fsck &&

	# Make sure we only have commits, and all trees and blobs are missing.
	shit -C dst rev-list --missing=allow-any --objects main \
		>fetched_objects &&
	awk -f print_1.awk fetched_objects |
	xargs -n1 shit -C dst cat-file -t >fetched_types &&

	sort -u fetched_types >unique_types.observed &&
	echo commit >unique_types.expected &&
	test_cmp unique_types.expected unique_types.observed &&

	# Auto-fetch a tree with cat-file.
	shit -C dst cat-file -p $SUBTREE >tree_contents &&
	grep file.txt tree_contents &&

	# fsck still works after an auto-fetch of a tree.
	shit -C dst fsck &&

	# Auto-fetch all remaining trees and blobs with --missing=error
	shit -C dst rev-list --missing=error --objects main >fetched_objects &&
	test_line_count = 88 fetched_objects &&

	awk -f print_1.awk fetched_objects |
	xargs -n1 shit -C dst cat-file -t >fetched_types &&

	sort -u fetched_types >unique_types.observed &&
	test_write_lines blob commit tree >unique_types.expected &&
	test_cmp unique_types.expected unique_types.observed
'

test_expect_success 'implicitly construct combine: filter with repeated flags' '
	shit_TRACE=$(pwd)/trace shit clone --bare \
		--filter=blob:none --filter=tree:1 \
		"file://$(pwd)/srv.bare" pc2 &&
	grep "trace:.* shit pack-objects .*--filter=combine:blob:none+tree:1" \
		trace &&
	shit -C pc2 rev-list --objects --missing=allow-any HEAD >objects &&

	# We should have gotten some root trees.
	grep " $" objects &&
	# Should not have gotten any non-root trees or blobs.
	! grep " ." objects &&

	xargs -n 1 shit -C pc2 cat-file -t <objects >types &&
	sort -u types >unique_types.actual &&
	test_write_lines commit tree >unique_types.expected &&
	test_cmp unique_types.expected unique_types.actual
'

test_expect_success 'upload-pack complains of bogus filter config' '
	printf 0000 |
	test_must_fail shit \
		-c uploadpackfilter.tree.maxdepth \
		upload-pack . >/dev/null 2>err &&
	test_grep "unable to parse.*tree.maxdepth" err
'

test_expect_success 'upload-pack fails banned object filters' '
	test_config -C srv.bare uploadpackfilter.blob:none.allow false &&
	test_must_fail ok=sigpipe shit clone --no-checkout --filter=blob:none \
		"file://$(pwd)/srv.bare" pc3 2>err &&
	test_grep "filter '\''blob:none'\'' not supported" err
'

test_expect_success 'upload-pack fails banned combine object filters' '
	test_config -C srv.bare uploadpackfilter.allow false &&
	test_config -C srv.bare uploadpackfilter.combine.allow true &&
	test_config -C srv.bare uploadpackfilter.tree.allow true &&
	test_config -C srv.bare uploadpackfilter.blob:none.allow false &&
	test_must_fail ok=sigpipe shit clone --no-checkout --filter=tree:1 \
		--filter=blob:none "file://$(pwd)/srv.bare" pc3 2>err &&
	test_grep "filter '\''blob:none'\'' not supported" err
'

test_expect_success 'upload-pack fails banned object filters with fallback' '
	test_config -C srv.bare uploadpackfilter.allow false &&
	test_must_fail ok=sigpipe shit clone --no-checkout --filter=blob:none \
		"file://$(pwd)/srv.bare" pc3 2>err &&
	test_grep "filter '\''blob:none'\'' not supported" err
'

test_expect_success 'upload-pack limits tree depth filters' '
	test_config -C srv.bare uploadpackfilter.allow false &&
	test_config -C srv.bare uploadpackfilter.tree.allow true &&
	test_config -C srv.bare uploadpackfilter.tree.maxDepth 0 &&
	test_must_fail ok=sigpipe shit clone --no-checkout --filter=tree:1 \
		"file://$(pwd)/srv.bare" pc3 2>err &&
	test_grep "tree filter allows max depth 0, but got 1" err &&

	shit clone --no-checkout --filter=tree:0 "file://$(pwd)/srv.bare" pc4 &&

	test_config -C srv.bare uploadpackfilter.tree.maxDepth 5 &&
	shit clone --no-checkout --filter=tree:5 "file://$(pwd)/srv.bare" pc5 &&
	test_must_fail ok=sigpipe shit clone --no-checkout --filter=tree:6 \
		"file://$(pwd)/srv.bare" pc6 2>err &&
	test_grep "tree filter allows max depth 5, but got 6" err
'

test_expect_success 'partial clone fetches blobs pointed to by refs even if normally filtered out' '
	rm -rf src dst &&
	shit init src &&
	test_commit -C src x &&
	test_config -C src uploadpack.allowfilter 1 &&
	test_config -C src uploadpack.allowanysha1inwant 1 &&

	# Create a tag pointing to a blob.
	BLOB=$(echo blob-contents | shit -C src hash-object --stdin -w) &&
	shit -C src tag myblob "$BLOB" &&

	shit clone --filter="blob:none" "file://$(pwd)/src" dst 2>err &&
	! grep "does not point to a valid object" err &&
	shit -C dst fsck
'

test_expect_success 'fetch what is specified on CLI even if already promised' '
	rm -rf src dst.shit &&
	shit init src &&
	test_commit -C src foo &&
	test_config -C src uploadpack.allowfilter 1 &&
	test_config -C src uploadpack.allowanysha1inwant 1 &&

	shit hash-object --stdin <src/foo.t >blob &&

	shit clone --bare --filter=blob:none "file://$(pwd)/src" dst.shit &&
	shit -C dst.shit rev-list --objects --quiet --missing=print HEAD >missing_before &&
	grep "?$(cat blob)" missing_before &&
	shit -C dst.shit fetch origin $(cat blob) &&
	shit -C dst.shit rev-list --objects --quiet --missing=print HEAD >missing_after &&
	! grep "?$(cat blob)" missing_after
'

test_expect_success 'setup src repo for sparse filter' '
	shit init sparse-src &&
	shit -C sparse-src config --local uploadpack.allowfilter 1 &&
	shit -C sparse-src config --local uploadpack.allowanysha1inwant 1 &&
	test_commit -C sparse-src one &&
	test_commit -C sparse-src two &&
	echo /one.t >sparse-src/only-one &&
	shit -C sparse-src add . &&
	shit -C sparse-src commit -m "add sparse checkout files"
'

test_expect_success 'partial clone with sparse filter succeeds' '
	rm -rf dst.shit &&
	shit clone --no-local --bare \
		  --filter=sparse:oid=main:only-one \
		  sparse-src dst.shit &&
	(
		cd dst.shit &&
		shit rev-list --objects --missing=print HEAD >out &&
		grep "^$(shit rev-parse HEAD:one.t)" out &&
		grep "^?$(shit rev-parse HEAD:two.t)" out
	)
'

test_expect_success 'partial clone with unresolvable sparse filter fails cleanly' '
	rm -rf dst.shit &&
	test_must_fail shit clone --no-local --bare \
				 --filter=sparse:oid=main:no-such-name \
				 sparse-src dst.shit 2>err &&
	test_grep "unable to access sparse blob in .main:no-such-name" err &&
	test_must_fail shit clone --no-local --bare \
				 --filter=sparse:oid=main \
				 sparse-src dst.shit 2>err &&
	test_grep "unable to parse sparse filter data in" err
'

setup_triangle () {
	rm -rf big-blob.txt server client promisor-remote &&

	printf "line %d\n" $(test_seq 1 100) >big-blob.txt &&

	# Create a server with 2 commits: a commit with a big tree and a child
	# commit with an incremental change. Also, create a partial clone
	# client that only contains the first commit.
	shit init server &&
	shit -C server config --local uploadpack.allowfilter 1 &&
	for i in $(test_seq 1 100)
	do
		echo "make the tree big" >server/file$i &&
		shit -C server add file$i || return 1
	done &&
	shit -C server commit -m "initial" &&
	shit clone --bare --filter=tree:0 "file://$(pwd)/server" client &&
	echo another line >>server/file1 &&
	shit -C server commit -am "incremental change" &&

	# Create a promisor remote that only contains the tree and blob from
	# the first commit.
	shit init promisor-remote &&
	shit -C server config --local uploadpack.allowanysha1inwant 1 &&
	TREE_HASH=$(shit -C server rev-parse HEAD~1^{tree}) &&
	shit -C promisor-remote fetch --keep "file://$(pwd)/server" "$TREE_HASH" &&
	shit -C promisor-remote count-objects -v >object-count &&
	test_grep "count: 0" object-count &&
	test_grep "in-pack: 2" object-count &&

	# Set it as the promisor remote of client. Thus, whenever
	# the client lazy fetches, the lazy fetch will succeed only if it is
	# for this tree or blob.
	test_commit -C promisor-remote one && # so that ref advertisement is not empty
	shit -C promisor-remote config --local uploadpack.allowanysha1inwant 1 &&
	shit -C client remote set-url origin "file://$(pwd)/promisor-remote"
}

# NEEDSWORK: The tests beginning with "fetch lazy-fetches" below only
# test that "fetch" avoid fetching trees and blobs, but not commits or
# tags. Revisit this if shit is ever taught to support partial clones
# with commits and/or tags filtered out.

test_expect_success 'fetch lazy-fetches only to resolve deltas' '
	setup_triangle &&

	# Exercise to make sure it works. shit will not fetch anything from the
	# promisor remote other than for the big tree (because it needs to
	# resolve the delta).
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client \
		fetch "file://$(pwd)/server" main &&

	# Verify the assumption that the client needed to fetch the delta base
	# to resolve the delta.
	shit -C server rev-parse HEAD~1^{tree} >hash &&
	grep "want $(cat hash)" trace
'

test_expect_success 'fetch lazy-fetches only to resolve deltas, protocol v2' '
	setup_triangle &&

	shit -C server config --local protocol.version 2 &&
	shit -C client config --local protocol.version 2 &&
	shit -C promisor-remote config --local protocol.version 2 &&

	# Exercise to make sure it works. shit will not fetch anything from the
	# promisor remote other than for the big blob (because it needs to
	# resolve the delta).
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client \
		fetch "file://$(pwd)/server" main &&

	# Verify that protocol version 2 was used.
	grep "fetch< version 2" trace &&

	# Verify the assumption that the client needed to fetch the delta base
	# to resolve the delta.
	shit -C server rev-parse HEAD~1^{tree} >hash &&
	grep "want $(cat hash)" trace
'

test_expect_success 'fetch does not lazy-fetch missing targets of its refs' '
	rm -rf server client trace &&

	test_create_repo server &&
	test_config -C server uploadpack.allowfilter 1 &&
	test_config -C server uploadpack.allowanysha1inwant 1 &&
	test_commit -C server foo &&

	shit clone --filter=blob:none "file://$(pwd)/server" client &&
	# Make all refs point to nothing by deleting all objects.
	rm client/.shit/objects/pack/* &&

	test_commit -C server bar &&
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client fetch \
		--no-tags --recurse-submodules=no \
		origin refs/tags/bar &&
	FOO_HASH=$(shit -C server rev-parse foo) &&
	! grep "want $FOO_HASH" trace
'

# The following two tests must be in this order. It is important that
# the srv.bare repository did not have tags during clone, but has tags
# in the fetch.

test_expect_success 'verify fetch succeeds when asking for new tags' '
	shit clone --filter=blob:none "file://$(pwd)/srv.bare" tag-test &&
	for i in I J K
	do
		test_commit -C src $i &&
		shit -C src branch $i || return 1
	done &&
	shit -C srv.bare fetch --tags origin +refs/heads/*:refs/heads/* &&
	shit -C tag-test -c protocol.version=2 fetch --tags origin
'

test_expect_success 'verify fetch downloads only one pack when updating refs' '
	shit clone --filter=blob:none "file://$(pwd)/srv.bare" pack-test &&
	ls pack-test/.shit/objects/pack/*pack >pack-list &&
	test_line_count = 2 pack-list &&
	for i in A B C
	do
		test_commit -C src $i &&
		shit -C src branch $i || return 1
	done &&
	shit -C srv.bare fetch origin +refs/heads/*:refs/heads/* &&
	shit -C pack-test fetch origin &&
	ls pack-test/.shit/objects/pack/*pack >pack-list &&
	test_line_count = 3 pack-list
'

test_expect_success 'single-branch tag following respects partial clone' '
	shit clone --single-branch -b B --filter=blob:none \
		"file://$(pwd)/srv.bare" single &&
	shit -C single rev-parse --verify refs/tags/B &&
	shit -C single rev-parse --verify refs/tags/A &&
	test_must_fail shit -C single rev-parse --verify refs/tags/C
'

test_expect_success 'fetch from a partial clone, protocol v0' '
	rm -rf server client trace &&

	# Pretend that the server is a partial clone
	shit init server &&
	shit -C server remote add a_remote "file://$(pwd)/" &&
	test_config -C server core.repositoryformatversion 1 &&
	test_config -C server extensions.partialclone a_remote &&
	test_config -C server protocol.version 0 &&
	test_commit -C server foo &&

	# Fetch from the server
	shit init client &&
	test_config -C client protocol.version 0 &&
	test_commit -C client bar &&
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client fetch "file://$(pwd)/server" &&
	! grep "version 2" trace
'

test_expect_success 'fetch from a partial clone, protocol v2' '
	rm -rf server client trace &&

	# Pretend that the server is a partial clone
	shit init server &&
	shit -C server remote add a_remote "file://$(pwd)/" &&
	test_config -C server core.repositoryformatversion 1 &&
	test_config -C server extensions.partialclone a_remote &&
	test_config -C server protocol.version 2 &&
	test_commit -C server foo &&

	# Fetch from the server
	shit init client &&
	test_config -C client protocol.version 2 &&
	test_commit -C client bar &&
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client fetch "file://$(pwd)/server" &&
	grep "version 2" trace
'

test_expect_success 'repack does not loosen promisor objects' '
	rm -rf client trace &&
	shit clone --bare --filter=blob:none "file://$(pwd)/srv.bare" client &&
	test_when_finished "rm -rf client trace" &&
	shit_TRACE2_PERF="$(pwd)/trace" shit -C client repack -A -d &&
	grep "loosen_unused_packed_objects/loosened:0" trace
'

test_expect_success 'lazy-fetch in submodule succeeds' '
	# setup
	test_config_global protocol.file.allow always &&

	test_when_finished "rm -rf src-sub" &&
	shit init src-sub &&
	shit -C src-sub config uploadpack.allowfilter 1 &&
	shit -C src-sub config uploadpack.allowanysha1inwant 1 &&

	# This blob must be missing in the subsequent commit.
	echo foo >src-sub/file &&
	shit -C src-sub add file &&
	shit -C src-sub commit -m "submodule one" &&
	SUB_ONE=$(shit -C src-sub rev-parse HEAD) &&

	echo bar >src-sub/file &&
	shit -C src-sub add file &&
	shit -C src-sub commit -m "submodule two" &&
	SUB_TWO=$(shit -C src-sub rev-parse HEAD) &&

	test_when_finished "rm -rf src-super" &&
	shit init src-super &&
	shit -C src-super config uploadpack.allowfilter 1 &&
	shit -C src-super config uploadpack.allowanysha1inwant 1 &&
	shit -C src-super submodule add ../src-sub src-sub &&

	shit -C src-super/src-sub checkout $SUB_ONE &&
	shit -C src-super add src-sub &&
	shit -C src-super commit -m "superproject one" &&

	shit -C src-super/src-sub checkout $SUB_TWO &&
	shit -C src-super add src-sub &&
	shit -C src-super commit -m "superproject two" &&

	# the fetch
	test_when_finished "rm -rf client" &&
	shit clone --filter=blob:none --also-filter-submodules \
		--recurse-submodules "file://$(pwd)/src-super" client &&

	# Trigger lazy-fetch from the superproject
	shit -C client restore --recurse-submodules --source=HEAD^ :/
'

. "$TEST_DIRECTORY"/lib-httpd.sh
start_httpd

# Converts bytes into their hexadecimal representation. For example,
# "printf 'ab\r\n' | hex_unpack" results in '61620d0a'.
hex_unpack () {
	perl -e '$/ = undef; $input = <>; print unpack("H2" x length($input), $input)'
}

# Inserts $1 at the start of the string and every 2 characters thereafter.
intersperse () {
	sed 's/\(..\)/'$1'\1/g'
}

# Create a one-time-perl command to replace the existing packfile with $1.
replace_packfile () {
	# The protocol requires that the packfile be sent in sideband 1, hence
	# the extra \x01 byte at the beginning.
	cp $1 "$HTTPD_ROOT_PATH/one-time-pack" &&
	echo 'if (/packfile/) {
		print;
		my $length = -s "one-time-pack";
		printf "%04x\x01", $length + 5;
		print `cat one-time-pack` . "0000";
		last
	}' >"$HTTPD_ROOT_PATH/one-time-perl"
}

test_expect_success 'upon cloning, check that all refs point to objects' '
	SERVER="$HTTPD_DOCUMENT_ROOT_PATH/server" &&
	rm -rf "$SERVER" repo &&
	test_create_repo "$SERVER" &&
	test_commit -C "$SERVER" foo &&
	test_config -C "$SERVER" uploadpack.allowfilter 1 &&
	test_config -C "$SERVER" uploadpack.allowanysha1inwant 1 &&

	# Create a tag pointing to a blob.
	BLOB=$(echo blob-contents | shit -C "$SERVER" hash-object --stdin -w) &&
	shit -C "$SERVER" tag myblob "$BLOB" &&

	# Craft a packfile not including that blob.
	shit -C "$SERVER" rev-parse HEAD |
	shit -C "$SERVER" pack-objects --stdout >incomplete.pack &&

	# Replace the existing packfile with the crafted one. The protocol
	# requires that the packfile be sent in sideband 1, hence the extra
	# \x01 byte at the beginning.
	replace_packfile incomplete.pack &&

	# Use protocol v2 because the perl command looks for the "packfile"
	# section header.
	test_config -C "$SERVER" protocol.version 2 &&
	test_must_fail shit -c protocol.version=2 clone \
		--filter=blob:none $HTTPD_URL/one_time_perl/server repo 2>err &&

	test_grep "did not send all necessary objects" err &&

	# Ensure that the one-time-perl script was used.
	! test -e "$HTTPD_ROOT_PATH/one-time-perl"
'

test_expect_success 'when partial cloning, tolerate server not sending target of tag' '
	SERVER="$HTTPD_DOCUMENT_ROOT_PATH/server" &&
	rm -rf "$SERVER" repo &&
	test_create_repo "$SERVER" &&
	test_commit -C "$SERVER" foo &&
	test_config -C "$SERVER" uploadpack.allowfilter 1 &&
	test_config -C "$SERVER" uploadpack.allowanysha1inwant 1 &&

	# Create an annotated tag pointing to a blob.
	BLOB=$(echo blob-contents | shit -C "$SERVER" hash-object --stdin -w) &&
	shit -C "$SERVER" tag -m message -a myblob "$BLOB" &&

	# Craft a packfile including the tag, but not the blob it points to.
	# Also, omit objects referenced from HEAD in order to force a second
	# fetch (to fetch missing objects) upon the automatic checkout that
	# happens after a clone.
	printf "%s\n%s\n--not\n%s\n%s\n" \
		$(shit -C "$SERVER" rev-parse HEAD) \
		$(shit -C "$SERVER" rev-parse myblob) \
		$(shit -C "$SERVER" rev-parse HEAD^{tree}) \
		$(shit -C "$SERVER" rev-parse myblob^{blob}) |
		shit -C "$SERVER" pack-objects --thin --stdout >incomplete.pack &&

	# Replace the existing packfile with the crafted one. The protocol
	# requires that the packfile be sent in sideband 1, hence the extra
	# \x01 byte at the beginning.
	replace_packfile incomplete.pack &&

	# Use protocol v2 because the perl command looks for the "packfile"
	# section header.
	test_config -C "$SERVER" protocol.version 2 &&

	# Exercise to make sure it works.
	shit -c protocol.version=2 clone \
		--filter=blob:none $HTTPD_URL/one_time_perl/server repo 2> err &&
	! grep "missing object referenced by" err &&

	# Ensure that the one-time-perl script was used.
	! test -e "$HTTPD_ROOT_PATH/one-time-perl"
'

test_expect_success 'tolerate server sending REF_DELTA against missing promisor objects' '
	SERVER="$HTTPD_DOCUMENT_ROOT_PATH/server" &&
	rm -rf "$SERVER" repo &&
	test_create_repo "$SERVER" &&
	test_config -C "$SERVER" uploadpack.allowfilter 1 &&
	test_config -C "$SERVER" uploadpack.allowanysha1inwant 1 &&

	# Create a commit with 2 blobs to be used as delta bases.
	for i in $(test_seq 10)
	do
		echo "this is a line" >>"$SERVER/foo.txt" &&
		echo "this is another line" >>"$SERVER/have.txt" || return 1
	done &&
	shit -C "$SERVER" add foo.txt have.txt &&
	shit -C "$SERVER" commit -m bar &&
	shit -C "$SERVER" rev-parse HEAD:foo.txt >deltabase_missing &&
	shit -C "$SERVER" rev-parse HEAD:have.txt >deltabase_have &&

	# Clone. The client has deltabase_have but not deltabase_missing.
	shit -c protocol.version=2 clone --no-checkout \
		--filter=blob:none $HTTPD_URL/one_time_perl/server repo &&
	shit -C repo hash-object -w -- "$SERVER/have.txt" &&

	# Sanity check to ensure that the client does not have
	# deltabase_missing.
	shit -C repo rev-list --objects --ignore-missing \
		-- $(cat deltabase_missing) >objlist &&
	test_line_count = 0 objlist &&

	# Another commit. This commit will be fetched by the client.
	echo "abcdefghijklmnopqrstuvwxyz" >>"$SERVER/foo.txt" &&
	echo "abcdefghijklmnopqrstuvwxyz" >>"$SERVER/have.txt" &&
	shit -C "$SERVER" add foo.txt have.txt &&
	shit -C "$SERVER" commit -m baz &&

	# Pack a thin pack containing, among other things, HEAD:foo.txt
	# delta-ed against HEAD^:foo.txt and HEAD:have.txt delta-ed against
	# HEAD^:have.txt.
	printf "%s\n--not\n%s\n" \
		$(shit -C "$SERVER" rev-parse HEAD) \
		$(shit -C "$SERVER" rev-parse HEAD^) |
		shit -C "$SERVER" pack-objects --thin --stdout >thin.pack &&

	# Ensure that the pack contains one delta against HEAD^:foo.txt. Since
	# the delta contains at least 26 novel characters, the size cannot be
	# contained in 4 bits, so the object header will take up 2 bytes. The
	# most significant nybble of the first byte is 0b1111 (0b1 to indicate
	# that the header continues, and 0b111 to indicate REF_DELTA), followed
	# by any 3 nybbles, then the OID of the delta base.
	printf "f.,..%s" $(intersperse "," <deltabase_missing) >want &&
	hex_unpack <thin.pack | intersperse "," >have &&
	grep $(cat want) have &&

	# Ensure that the pack contains one delta against HEAD^:have.txt,
	# similar to the above.
	printf "f.,..%s" $(intersperse "," <deltabase_have) >want &&
	hex_unpack <thin.pack | intersperse "," >have &&
	grep $(cat want) have &&

	replace_packfile thin.pack &&

	# Use protocol v2 because the perl command looks for the "packfile"
	# section header.
	test_config -C "$SERVER" protocol.version 2 &&

	# Fetch the thin pack and ensure that index-pack is able to handle the
	# REF_DELTA object with a missing promisor delta base.
	shit_TRACE_PACKET="$(pwd)/trace" shit -C repo -c protocol.version=2 fetch &&

	# Ensure that the missing delta base was directly fetched, but not the
	# one that the client has.
	grep "want $(cat deltabase_missing)" trace &&
	! grep "want $(cat deltabase_have)" trace &&

	# Ensure that the one-time-perl script was used.
	! test -e "$HTTPD_ROOT_PATH/one-time-perl"
'

# DO NOT add non-httpd-specific tests here, because the last part of this
# test script is only executed when httpd is available and enabled.

test_done
