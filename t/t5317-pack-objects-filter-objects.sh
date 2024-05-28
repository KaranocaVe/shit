#!/bin/sh

test_description='shit pack-objects using object filtering'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# Test blob:none filter.

test_expect_success 'setup r1' '
	shit init r1 &&
	for n in 1 2 3 4 5
	do
		echo "This is file: $n" > r1/file.$n &&
		shit -C r1 add file.$n &&
		shit -C r1 commit -m "$n" || return 1
	done
'

parse_verify_pack_blob_oid () {
	awk '{print $1}' -
}

test_expect_success 'verify blob count in normal packfile' '
	shit -C r1 ls-files -s file.1 file.2 file.3 file.4 file.5 \
		>ls_files_result &&
	test_parse_ls_files_stage_oids <ls_files_result |
	sort >expected &&

	shit -C r1 pack-objects --revs --stdout >all.pack <<-EOF &&
	HEAD
	EOF
	shit -C r1 index-pack ../all.pack &&

	shit -C r1 verify-pack -v ../all.pack >verify_result &&
	grep blob verify_result |
	parse_verify_pack_blob_oid |
	sort >observed &&

	test_cmp expected observed
'

test_expect_success 'verify blob:none packfile has no blobs' '
	shit -C r1 pack-objects --revs --stdout --filter=blob:none >filter.pack <<-EOF &&
	HEAD
	EOF
	shit -C r1 index-pack ../filter.pack &&

	shit -C r1 verify-pack -v ../filter.pack >verify_result &&
	! grep blob verify_result
'

test_expect_success 'verify blob:none packfile without --stdout' '
	shit -C r1 pack-objects --revs --filter=blob:none mypackname >packhash <<-EOF &&
	HEAD
	EOF
	shit -C r1 verify-pack -v "mypackname-$(cat packhash).pack" >verify_result &&
	! grep blob verify_result
'

test_expect_success 'verify normal and blob:none packfiles have same commits/trees' '
	shit -C r1 verify-pack -v ../all.pack >verify_result &&
	grep -E "commit|tree" verify_result |
	parse_verify_pack_blob_oid |
	sort >expected &&

	shit -C r1 verify-pack -v ../filter.pack >verify_result &&
	grep -E "commit|tree" verify_result |
	parse_verify_pack_blob_oid |
	sort >observed &&

	test_cmp expected observed
'

test_expect_success 'get an error for missing tree object' '
	shit init r5 &&
	echo foo >r5/foo &&
	shit -C r5 add foo &&
	shit -C r5 commit -m "foo" &&
	shit -C r5 rev-parse HEAD^{tree} >tree &&
	del=$(sed "s|..|&/|" tree) &&
	rm r5/.shit/objects/$del &&
	test_must_fail shit -C r5 pack-objects --revs --stdout 2>bad_tree <<-EOF &&
	HEAD
	EOF
	grep "bad tree object" bad_tree
'

test_expect_success 'setup for tests of tree:0' '
	mkdir r1/subtree &&
	echo "This is a file in a subtree" >r1/subtree/file &&
	shit -C r1 add subtree/file &&
	shit -C r1 commit -m subtree
'

test_expect_success 'verify tree:0 packfile has no blobs or trees' '
	shit -C r1 pack-objects --revs --stdout --filter=tree:0 >commitsonly.pack <<-EOF &&
	HEAD
	EOF
	shit -C r1 index-pack ../commitsonly.pack &&
	shit -C r1 verify-pack -v ../commitsonly.pack >objs &&
	! grep -E "tree|blob" objs
'

test_expect_success 'grab tree directly when using tree:0' '
	# We should get the tree specified directly but not its blobs or subtrees.
	shit -C r1 pack-objects --revs --stdout --filter=tree:0 >commitsonly.pack <<-EOF &&
	HEAD:
	EOF
	shit -C r1 index-pack ../commitsonly.pack &&
	shit -C r1 verify-pack -v ../commitsonly.pack >objs &&
	awk "/tree|blob/{print \$1}" objs >trees_and_blobs &&
	shit -C r1 rev-parse HEAD: >expected &&
	test_cmp expected trees_and_blobs
'

# Test blob:limit=<n>[kmg] filter.
# We boundary test around the size parameter.  The filter is strictly less than
# the value, so size 500 and 1000 should have the same results, but 1001 should
# filter more.

test_expect_success 'setup r2' '
	shit init r2 &&
	for n in 1000 10000
	do
		printf "%"$n"s" X > r2/large.$n &&
		shit -C r2 add large.$n &&
		shit -C r2 commit -m "$n" || return 1
	done
'

test_expect_success 'verify blob count in normal packfile' '
	shit -C r2 ls-files -s large.1000 large.10000 >ls_files_result &&
	test_parse_ls_files_stage_oids <ls_files_result |
	sort >expected &&

	shit -C r2 pack-objects --revs --stdout >all.pack <<-EOF &&
	HEAD
	EOF
	shit -C r2 index-pack ../all.pack &&

	shit -C r2 verify-pack -v ../all.pack >verify_result &&
	grep blob verify_result |
	parse_verify_pack_blob_oid |
	sort >observed &&

	test_cmp expected observed
'

test_expect_success 'verify blob:limit=500 omits all blobs' '
	shit -C r2 pack-objects --revs --stdout --filter=blob:limit=500 >filter.pack <<-EOF &&
	HEAD
	EOF
	shit -C r2 index-pack ../filter.pack &&

	shit -C r2 verify-pack -v ../filter.pack >verify_result &&
	! grep blob verify_result
'

test_expect_success 'verify blob:limit=1000' '
	shit -C r2 pack-objects --revs --stdout --filter=blob:limit=1000 >filter.pack <<-EOF &&
	HEAD
	EOF
	shit -C r2 index-pack ../filter.pack &&

	shit -C r2 verify-pack -v ../filter.pack >verify_result &&
	! grep blob verify_result
'

test_expect_success 'verify blob:limit=1001' '
	shit -C r2 ls-files -s large.1000 >ls_files_result &&
	test_parse_ls_files_stage_oids <ls_files_result |
	sort >expected &&

	shit -C r2 pack-objects --revs --stdout --filter=blob:limit=1001 >filter.pack <<-EOF &&
	HEAD
	EOF
	shit -C r2 index-pack ../filter.pack &&

	shit -C r2 verify-pack -v ../filter.pack >verify_result &&
	grep blob verify_result |
	parse_verify_pack_blob_oid |
	sort >observed &&

	test_cmp expected observed
'

test_expect_success 'verify blob:limit=10001' '
	shit -C r2 ls-files -s large.1000 large.10000 >ls_files_result &&
	test_parse_ls_files_stage_oids <ls_files_result |
	sort >expected &&

	shit -C r2 pack-objects --revs --stdout --filter=blob:limit=10001 >filter.pack <<-EOF &&
	HEAD
	EOF
	shit -C r2 index-pack ../filter.pack &&

	shit -C r2 verify-pack -v ../filter.pack >verify_result &&
	grep blob verify_result |
	parse_verify_pack_blob_oid |
	sort >observed &&

	test_cmp expected observed
'

test_expect_success 'verify blob:limit=1k' '
	shit -C r2 ls-files -s large.1000 >ls_files_result &&
	test_parse_ls_files_stage_oids <ls_files_result |
	sort >expected &&

	shit -C r2 pack-objects --revs --stdout --filter=blob:limit=1k >filter.pack <<-EOF &&
	HEAD
	EOF
	shit -C r2 index-pack ../filter.pack &&

	shit -C r2 verify-pack -v ../filter.pack >verify_result &&
	grep blob verify_result |
	parse_verify_pack_blob_oid |
	sort >observed &&

	test_cmp expected observed
'

test_expect_success 'verify explicitly specifying oversized blob in input' '
	shit -C r2 ls-files -s large.1000 large.10000 >ls_files_result &&
	test_parse_ls_files_stage_oids <ls_files_result |
	sort >expected &&

	echo HEAD >objects &&
	shit -C r2 rev-parse HEAD:large.10000 >>objects &&
	shit -C r2 pack-objects --revs --stdout --filter=blob:limit=1k <objects >filter.pack &&
	shit -C r2 index-pack ../filter.pack &&

	shit -C r2 verify-pack -v ../filter.pack >verify_result &&
	grep blob verify_result |
	parse_verify_pack_blob_oid |
	sort >observed &&

	test_cmp expected observed
'

test_expect_success 'verify blob:limit=1m' '
	shit -C r2 ls-files -s large.1000 large.10000 >ls_files_result &&
	test_parse_ls_files_stage_oids <ls_files_result |
	sort >expected &&

	shit -C r2 pack-objects --revs --stdout --filter=blob:limit=1m >filter.pack <<-EOF &&
	HEAD
	EOF
	shit -C r2 index-pack ../filter.pack &&

	shit -C r2 verify-pack -v ../filter.pack >verify_result &&
	grep blob verify_result |
	parse_verify_pack_blob_oid |
	sort >observed &&

	test_cmp expected observed
'

test_expect_success 'verify normal and blob:limit packfiles have same commits/trees' '
	shit -C r2 verify-pack -v ../all.pack >verify_result &&
	grep -E "commit|tree" verify_result |
	parse_verify_pack_blob_oid |
	sort >expected &&

	shit -C r2 verify-pack -v ../filter.pack >verify_result &&
	grep -E "commit|tree" verify_result |
	parse_verify_pack_blob_oid |
	sort >observed &&

	test_cmp expected observed
'

test_expect_success 'verify small limit and big limit results in small limit' '
	shit -C r2 ls-files -s large.1000 >ls_files_result &&
	test_parse_ls_files_stage_oids <ls_files_result |
	sort >expected &&

	shit -C r2 pack-objects --revs --stdout --filter=blob:limit=1001 \
		--filter=blob:limit=10001 >filter.pack <<-EOF &&
	HEAD
	EOF
	shit -C r2 index-pack ../filter.pack &&

	shit -C r2 verify-pack -v ../filter.pack >verify_result &&
	grep blob verify_result |
	parse_verify_pack_blob_oid |
	sort >observed &&

	test_cmp expected observed
'

test_expect_success 'verify big limit and small limit results in small limit' '
	shit -C r2 ls-files -s large.1000 >ls_files_result &&
	test_parse_ls_files_stage_oids <ls_files_result |
	sort >expected &&

	shit -C r2 pack-objects --revs --stdout --filter=blob:limit=10001 \
		--filter=blob:limit=1001 >filter.pack <<-EOF &&
	HEAD
	EOF
	shit -C r2 index-pack ../filter.pack &&

	shit -C r2 verify-pack -v ../filter.pack >verify_result &&
	grep blob verify_result |
	parse_verify_pack_blob_oid |
	sort >observed &&

	test_cmp expected observed
'

# Test sparse:path=<path> filter.
# !!!!
# NOTE: sparse:path filter support has been dropped for security reasons,
# so the tests have been changed to make sure that using it fails.
# !!!!
# Use a local file containing a sparse-checkout specification to filter
# out blobs not required for the corresponding sparse-checkout.  We do not
# require sparse-checkout to actually be enabled.

test_expect_success 'setup r3' '
	shit init r3 &&
	mkdir r3/dir1 &&
	for n in sparse1 sparse2
	do
		echo "This is file: $n" > r3/$n &&
		shit -C r3 add $n &&
		echo "This is file: dir1/$n" > r3/dir1/$n &&
		shit -C r3 add dir1/$n || return 1
	done &&
	shit -C r3 commit -m "sparse" &&
	echo dir1/ >pattern1 &&
	echo sparse1 >pattern2
'

test_expect_success 'verify blob count in normal packfile' '
	shit -C r3 ls-files -s sparse1 sparse2 dir1/sparse1 dir1/sparse2 \
		>ls_files_result &&
	test_parse_ls_files_stage_oids <ls_files_result |
	sort >expected &&

	shit -C r3 pack-objects --revs --stdout >all.pack <<-EOF &&
	HEAD
	EOF
	shit -C r3 index-pack ../all.pack &&

	shit -C r3 verify-pack -v ../all.pack >verify_result &&
	grep blob verify_result |
	parse_verify_pack_blob_oid |
	sort >observed &&

	test_cmp expected observed
'

test_expect_success 'verify sparse:path=pattern1 fails' '
	test_must_fail shit -C r3 pack-objects --revs --stdout \
		--filter=sparse:path=../pattern1 <<-EOF
	HEAD
	EOF
'

test_expect_success 'verify sparse:path=pattern2 fails' '
	test_must_fail shit -C r3 pack-objects --revs --stdout \
		--filter=sparse:path=../pattern2 <<-EOF
	HEAD
	EOF
'

# Test sparse:oid=<oid-ish> filter.
# Use a blob containing a sparse-checkout specification to filter
# out blobs not required for the corresponding sparse-checkout.  We do not
# require sparse-checkout to actually be enabled.

test_expect_success 'setup r4' '
	shit init r4 &&
	mkdir r4/dir1 &&
	for n in sparse1 sparse2
	do
		echo "This is file: $n" > r4/$n &&
		shit -C r4 add $n &&
		echo "This is file: dir1/$n" > r4/dir1/$n &&
		shit -C r4 add dir1/$n || return 1
	done &&
	echo dir1/ >r4/pattern &&
	shit -C r4 add pattern &&
	shit -C r4 commit -m "pattern"
'

test_expect_success 'verify blob count in normal packfile' '
	shit -C r4 ls-files -s pattern sparse1 sparse2 dir1/sparse1 dir1/sparse2 \
		>ls_files_result &&
	test_parse_ls_files_stage_oids <ls_files_result |
	sort >expected &&

	shit -C r4 pack-objects --revs --stdout >all.pack <<-EOF &&
	HEAD
	EOF
	shit -C r4 index-pack ../all.pack &&

	shit -C r4 verify-pack -v ../all.pack >verify_result &&
	grep blob verify_result |
	parse_verify_pack_blob_oid |
	sort >observed &&

	test_cmp expected observed
'

test_expect_success 'verify sparse:oid=OID' '
	shit -C r4 ls-files -s dir1/sparse1 dir1/sparse2 >ls_files_result &&
	test_parse_ls_files_stage_oids <ls_files_result |
	sort >expected &&

	shit -C r4 ls-files -s pattern >staged &&
	oid=$(test_parse_ls_files_stage_oids <staged) &&
	shit -C r4 pack-objects --revs --stdout --filter=sparse:oid=$oid >filter.pack <<-EOF &&
	HEAD
	EOF
	shit -C r4 index-pack ../filter.pack &&

	shit -C r4 verify-pack -v ../filter.pack >verify_result &&
	grep blob verify_result |
	parse_verify_pack_blob_oid |
	sort >observed &&

	test_cmp expected observed
'

test_expect_success 'verify sparse:oid=oid-ish' '
	shit -C r4 ls-files -s dir1/sparse1 dir1/sparse2 >ls_files_result &&
	test_parse_ls_files_stage_oids <ls_files_result |
	sort >expected &&

	shit -C r4 pack-objects --revs --stdout --filter=sparse:oid=main:pattern >filter.pack <<-EOF &&
	HEAD
	EOF
	shit -C r4 index-pack ../filter.pack &&

	shit -C r4 verify-pack -v ../filter.pack >verify_result &&
	grep blob verify_result |
	parse_verify_pack_blob_oid |
	sort >observed &&

	test_cmp expected observed
'

# Delete some loose objects and use pack-objects, but WITHOUT any filtering.
# This models previously omitted objects that we did not receive.

test_expect_success 'setup r1 - delete loose blobs' '
	shit -C r1 ls-files -s file.1 file.2 file.3 file.4 file.5 \
		>ls_files_result &&
	test_parse_ls_files_stage_oids <ls_files_result |
	sort >expected &&

	for id in `sed "s|..|&/|" expected`
	do
		rm r1/.shit/objects/$id || return 1
	done
'

test_expect_success 'verify pack-objects fails w/ missing objects' '
	test_must_fail shit -C r1 pack-objects --revs --stdout >miss.pack <<-EOF
	HEAD
	EOF
'

test_expect_success 'verify pack-objects fails w/ --missing=error' '
	test_must_fail shit -C r1 pack-objects --revs --stdout --missing=error >miss.pack <<-EOF
	HEAD
	EOF
'

test_expect_success 'verify pack-objects w/ --missing=allow-any' '
	shit -C r1 pack-objects --revs --stdout --missing=allow-any >miss.pack <<-EOF
	HEAD
	EOF
'

test_done
