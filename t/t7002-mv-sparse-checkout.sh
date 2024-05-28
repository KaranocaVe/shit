#!/bin/sh

test_description='shit mv in sparse working trees'

. ./test-lib.sh

setup_sparse_checkout () {
	mkdir folder1 &&
	touch folder1/file1 &&
	shit add folder1 &&
	shit sparse-checkout set --cone sub
}

cleanup_sparse_checkout () {
	shit sparse-checkout disable &&
	shit reset --hard
}

test_expect_success 'setup' "
	mkdir -p sub/dir sub/dir2 &&
	touch a b c sub/d sub/dir/e sub/dir2/e &&
	shit add -A &&
	shit commit -m files &&

	cat >sparse_error_header <<-EOF &&
	The following paths and/or pathspecs matched paths that exist
	outside of your sparse-checkout definition, so will not be
	updated in the index:
	EOF

	cat >sparse_hint <<-EOF &&
	hint: If you intend to update such entries, try one of the following:
	hint: * Use the --sparse option.
	hint: * Disable or modify the sparsity rules.
	hint: Disable this message with \"shit config advice.updateSparsePath false\"
	EOF

	cat >dirty_error_header <<-EOF &&
	The following paths have been moved outside the
	sparse-checkout definition but are not sparse due to local
	modifications.
	EOF

	cat >dirty_hint <<-EOF
	hint: To correct the sparsity of these paths, do the following:
	hint: * Use \"shit add --sparse <paths>\" to update the index
	hint: * Use \"shit sparse-checkout reapply\" to apply the sparsity rules
	hint: Disable this message with \"shit config advice.updateSparsePath false\"
	EOF
"

test_expect_success 'mv refuses to move sparse-to-sparse' '
	test_when_finished rm -f e &&
	shit reset --hard &&
	shit sparse-checkout set --no-cone a &&
	touch b &&
	test_must_fail shit mv b e 2>stderr &&
	cat sparse_error_header >expect &&
	echo b >>expect &&
	echo e >>expect &&
	cat sparse_hint >>expect &&
	test_cmp expect stderr &&
	shit mv --sparse b e 2>stderr &&
	test_must_be_empty stderr
'

test_expect_success 'mv refuses to move sparse-to-sparse, ignores failure' '
	test_when_finished rm -f b c e &&
	shit reset --hard &&
	shit sparse-checkout set a &&

	# tracked-to-untracked
	touch b &&
	shit mv -k b e 2>stderr &&
	test_path_exists b &&
	test_path_is_missing e &&
	cat sparse_error_header >expect &&
	echo b >>expect &&
	echo e >>expect &&
	cat sparse_hint >>expect &&
	test_cmp expect stderr &&

	shit mv --sparse b e 2>stderr &&
	test_must_be_empty stderr &&
	test_path_is_missing b &&
	test_path_exists e &&

	# tracked-to-tracked
	shit reset --hard &&
	touch b &&
	shit mv -k b c 2>stderr &&
	test_path_exists b &&
	test_path_is_missing c &&
	cat sparse_error_header >expect &&
	echo b >>expect &&
	echo c >>expect &&
	cat sparse_hint >>expect &&
	test_cmp expect stderr &&

	shit mv --sparse b c 2>stderr &&
	test_must_be_empty stderr &&
	test_path_is_missing b &&
	test_path_exists c
'

test_expect_success 'mv refuses to move non-sparse-to-sparse' '
	test_when_finished rm -f b c e &&
	shit reset --hard &&
	shit sparse-checkout set a &&

	# tracked-to-untracked
	test_must_fail shit mv a e 2>stderr &&
	test_path_exists a &&
	test_path_is_missing e &&
	cat sparse_error_header >expect &&
	echo e >>expect &&
	cat sparse_hint >>expect &&
	test_cmp expect stderr &&
	shit mv --sparse a e 2>stderr &&
	test_must_be_empty stderr &&
	test_path_is_missing a &&
	test_path_exists e &&

	# tracked-to-tracked
	rm e &&
	shit reset --hard &&
	test_must_fail shit mv a c 2>stderr &&
	test_path_exists a &&
	test_path_is_missing c &&
	cat sparse_error_header >expect &&
	echo c >>expect &&
	cat sparse_hint >>expect &&
	test_cmp expect stderr &&
	shit mv --sparse a c 2>stderr &&
	test_must_be_empty stderr &&
	test_path_is_missing a &&
	test_path_exists c
'

test_expect_success 'mv refuses to move sparse-to-non-sparse' '
	test_when_finished rm -f b c e &&
	shit reset --hard &&
	shit sparse-checkout set a e &&

	# tracked-to-untracked
	touch b &&
	test_must_fail shit mv b e 2>stderr &&
	cat sparse_error_header >expect &&
	echo b >>expect &&
	cat sparse_hint >>expect &&
	test_cmp expect stderr &&
	shit mv --sparse b e 2>stderr &&
	test_must_be_empty stderr
'

test_expect_success 'recursive mv refuses to move (possible) sparse' '
	test_when_finished rm -rf b c e sub2 &&
	shit reset --hard &&
	# Without cone mode, "sub" and "sub2" do not match
	shit sparse-checkout set sub/dir sub2/dir &&

	# Add contained contents to ensure we avoid non-existence errors
	mkdir sub/dir2 &&
	touch sub/d sub/dir2/e &&

	test_must_fail shit mv sub sub2 2>stderr &&
	cat sparse_error_header >expect &&
	cat >>expect <<-\EOF &&
	sub/d
	sub2/d
	sub/dir2/e
	sub2/dir2/e
	EOF
	cat sparse_hint >>expect &&
	test_cmp expect stderr &&
	shit mv --sparse sub sub2 2>stderr &&
	test_must_be_empty stderr &&
	shit commit -m "moved sub to sub2" &&
	shit rev-parse HEAD~1:sub >expect &&
	shit rev-parse HEAD:sub2 >actual &&
	test_cmp expect actual &&
	shit reset --hard HEAD~1
'

test_expect_success 'recursive mv refuses to move sparse' '
	shit reset --hard &&
	# Use cone mode so "sub/" matches the sparse-checkout patterns
	shit sparse-checkout init --cone &&
	shit sparse-checkout set sub/dir sub2/dir &&

	# Add contained contents to ensure we avoid non-existence errors
	mkdir sub/dir2 &&
	touch sub/dir2/e &&

	test_must_fail shit mv sub sub2 2>stderr &&
	cat sparse_error_header >expect &&
	cat >>expect <<-\EOF &&
	sub/dir2/e
	sub2/dir2/e
	EOF
	cat sparse_hint >>expect &&
	test_cmp expect stderr &&
	shit mv --sparse sub sub2 2>stderr &&
	test_must_be_empty stderr &&
	shit commit -m "moved sub to sub2" &&
	shit rev-parse HEAD~1:sub >expect &&
	shit rev-parse HEAD:sub2 >actual &&
	test_cmp expect actual &&
	shit reset --hard HEAD~1
'

test_expect_success 'can move files to non-sparse dir' '
	shit reset --hard &&
	shit sparse-checkout init --no-cone &&
	shit sparse-checkout set a b c w !/x y/ &&
	mkdir -p w x/y &&

	shit mv a w/new-a 2>stderr &&
	shit mv b x/y/new-b 2>stderr &&
	test_must_be_empty stderr
'

test_expect_success 'refuse to move file to non-skip-worktree sparse path' '
	test_when_finished "cleanup_sparse_checkout" &&
	shit reset --hard &&
	shit sparse-checkout init --no-cone &&
	shit sparse-checkout set a !/x y/ !x/y/z &&
	mkdir -p x/y/z &&

	test_must_fail shit mv a x/y/z/new-a 2>stderr &&
	echo x/y/z/new-a | cat sparse_error_header - sparse_hint >expect &&
	test_cmp expect stderr
'

test_expect_success 'refuse to move out-of-cone directory without --sparse' '
	test_when_finished "cleanup_sparse_checkout" &&
	setup_sparse_checkout &&

	test_must_fail shit mv folder1 sub 2>stderr &&
	cat sparse_error_header >expect &&
	echo folder1/file1 >>expect &&
	cat sparse_hint >>expect &&
	test_cmp expect stderr
'

test_expect_success 'can move out-of-cone directory with --sparse' '
	test_when_finished "cleanup_sparse_checkout" &&
	setup_sparse_checkout &&

	shit mv --sparse folder1 sub 2>stderr &&
	test_must_be_empty stderr &&

	test_path_is_dir sub/folder1 &&
	test_path_is_file sub/folder1/file1
'

test_expect_success 'refuse to move out-of-cone file without --sparse' '
	test_when_finished "cleanup_sparse_checkout" &&
	setup_sparse_checkout &&

	test_must_fail shit mv folder1/file1 sub 2>stderr &&
	cat sparse_error_header >expect &&
	echo folder1/file1 >>expect &&
	cat sparse_hint >>expect &&
	test_cmp expect stderr
'

test_expect_success 'can move out-of-cone file with --sparse' '
	test_when_finished "cleanup_sparse_checkout" &&
	setup_sparse_checkout &&

	shit mv --sparse folder1/file1 sub 2>stderr &&
	test_must_be_empty stderr &&

	test_path_is_file sub/file1
'

test_expect_success 'refuse to move sparse file to existing destination' '
	test_when_finished "cleanup_sparse_checkout" &&
	mkdir folder1 &&
	touch folder1/file1 &&
	touch sub/file1 &&
	shit add folder1 sub/file1 &&
	shit sparse-checkout set --cone sub &&

	test_must_fail shit mv --sparse folder1/file1 sub 2>stderr &&
	echo "fatal: destination exists, source=folder1/file1, destination=sub/file1" >expect &&
	test_cmp expect stderr
'

test_expect_success 'move sparse file to existing destination with --force and --sparse' '
	test_when_finished "cleanup_sparse_checkout" &&
	mkdir folder1 &&
	touch folder1/file1 &&
	touch sub/file1 &&
	echo "overwrite" >folder1/file1 &&
	shit add folder1 sub/file1 &&
	shit sparse-checkout set --cone sub &&

	shit mv --sparse --force folder1/file1 sub 2>stderr &&
	test_must_be_empty stderr &&
	echo "overwrite" >expect &&
	test_cmp expect sub/file1
'

test_expect_success 'move clean path from in-cone to out-of-cone' '
	test_when_finished "cleanup_sparse_checkout" &&
	setup_sparse_checkout &&

	test_must_fail shit mv sub/d folder1 2>stderr &&
	cat sparse_error_header >expect &&
	echo "folder1/d" >>expect &&
	cat sparse_hint >>expect &&
	test_cmp expect stderr &&

	shit mv --sparse sub/d folder1 2>stderr &&
	test_must_be_empty stderr &&

	test_path_is_missing sub/d &&
	test_path_is_missing folder1/d &&
	shit ls-files -t >actual &&
	! grep "^H sub/d\$" actual &&
	grep "S folder1/d" actual
'

test_expect_success 'move clean path from in-cone to out-of-cone overwrite' '
	test_when_finished "cleanup_sparse_checkout" &&
	setup_sparse_checkout &&
	echo "sub/file1 overwrite" >sub/file1 &&
	shit add sub/file1 &&

	test_must_fail shit mv sub/file1 folder1 2>stderr &&
	cat sparse_error_header >expect &&
	echo "folder1/file1" >>expect &&
	cat sparse_hint >>expect &&
	test_cmp expect stderr &&

	test_must_fail shit mv --sparse sub/file1 folder1 2>stderr &&
	echo "fatal: destination exists in the index, source=sub/file1, destination=folder1/file1" \
	>expect &&
	test_cmp expect stderr &&

	shit mv --sparse -f sub/file1 folder1 2>stderr &&
	test_must_be_empty stderr &&

	test_path_is_missing sub/file1 &&
	test_path_is_missing folder1/file1 &&
	shit ls-files -t >actual &&
	! grep "H sub/file1" actual &&
	grep "S folder1/file1" actual &&

	# compare file content before move and after move
	echo "sub/file1 overwrite" >expect &&
	shit ls-files -s -- folder1/file1 | awk "{print \$2}" >oid &&
	shit cat-file blob $(cat oid) >actual &&
	test_cmp expect actual
'

# This test is testing the same behavior as the
# "move clean path from in-cone to out-of-cone overwrite" above.
# The only difference is the <destination> changes from "folder1" to "folder1/file1"
test_expect_success 'move clean path from in-cone to out-of-cone file overwrite' '
	test_when_finished "cleanup_sparse_checkout" &&
	setup_sparse_checkout &&
	echo "sub/file1 overwrite" >sub/file1 &&
	shit add sub/file1 &&

	test_must_fail shit mv sub/file1 folder1/file1 2>stderr &&
	cat sparse_error_header >expect &&
	echo "folder1/file1" >>expect &&
	cat sparse_hint >>expect &&
	test_cmp expect stderr &&

	test_must_fail shit mv --sparse sub/file1 folder1/file1 2>stderr &&
	echo "fatal: destination exists in the index, source=sub/file1, destination=folder1/file1" \
	>expect &&
	test_cmp expect stderr &&

	shit mv --sparse -f sub/file1 folder1/file1 2>stderr &&
	test_must_be_empty stderr &&

	test_path_is_missing sub/file1 &&
	test_path_is_missing folder1/file1 &&
	shit ls-files -t >actual &&
	! grep "H sub/file1" actual &&
	grep "S folder1/file1" actual &&

	# compare file content before move and after move
	echo "sub/file1 overwrite" >expect &&
	shit ls-files -s -- folder1/file1 | awk "{print \$2}" >oid &&
	shit cat-file blob $(cat oid) >actual &&
	test_cmp expect actual
'

test_expect_success 'move directory with one of the files overwrite' '
	test_when_finished "cleanup_sparse_checkout" &&
	mkdir -p folder1/dir &&
	touch folder1/dir/file1 &&
	shit add folder1 &&
	shit sparse-checkout set --cone sub &&

	echo test >sub/dir/file1 &&
	shit add sub/dir/file1 &&

	test_must_fail shit mv sub/dir folder1 2>stderr &&
	cat sparse_error_header >expect &&
	echo "folder1/dir/e" >>expect &&
	echo "folder1/dir/file1" >>expect &&
	cat sparse_hint >>expect &&
	test_cmp expect stderr &&

	test_must_fail shit mv --sparse sub/dir folder1 2>stderr &&
	echo "fatal: destination exists in the index, source=sub/dir/file1, destination=folder1/dir/file1" \
	>expect &&
	test_cmp expect stderr &&

	shit mv --sparse -f sub/dir folder1 2>stderr &&
	test_must_be_empty stderr &&

	test_path_is_missing sub/dir/file1 &&
	test_path_is_missing sub/dir/e &&
	test_path_is_missing folder1/file1 &&
	shit ls-files -t >actual &&
	! grep "H sub/dir/file1" actual &&
	! grep "H sub/dir/e" actual &&
	grep "S folder1/dir/file1" actual &&

	# compare file content before move and after move
	echo test >expect &&
	shit ls-files -s -- folder1/dir/file1 | awk "{print \$2}" >oid &&
	shit cat-file blob $(cat oid) >actual &&
	test_cmp expect actual
'

test_expect_success 'move dirty path from in-cone to out-of-cone' '
	test_when_finished "cleanup_sparse_checkout" &&
	setup_sparse_checkout &&
	echo "modified" >>sub/d &&

	test_must_fail shit mv sub/d folder1 2>stderr &&
	cat sparse_error_header >expect &&
	echo "folder1/d" >>expect &&
	cat sparse_hint >>expect &&
	test_cmp expect stderr &&

	shit mv --sparse sub/d folder1 2>stderr &&
	cat dirty_error_header >expect &&
	echo "folder1/d" >>expect &&
	cat dirty_hint >>expect &&
	test_cmp expect stderr &&

	test_path_is_missing sub/d &&
	test_path_is_file folder1/d &&
	shit ls-files -t >actual &&
	! grep "^H sub/d\$" actual &&
	grep "H folder1/d" actual
'

test_expect_success 'move dir from in-cone to out-of-cone' '
	test_when_finished "cleanup_sparse_checkout" &&
	setup_sparse_checkout &&
	mkdir sub/dir/deep &&

	test_must_fail shit mv sub/dir folder1 2>stderr &&
	cat sparse_error_header >expect &&
	echo "folder1/dir/e" >>expect &&
	cat sparse_hint >>expect &&
	test_cmp expect stderr &&

	shit mv --sparse sub/dir folder1 2>stderr &&
	test_must_be_empty stderr &&

	test_path_is_missing sub/dir &&
	test_path_is_missing folder1 &&
	shit ls-files -t >actual &&
	! grep "H sub/dir/e" actual &&
	grep "S folder1/dir/e" actual
'

test_expect_success 'move partially-dirty dir from in-cone to out-of-cone' '
	test_when_finished "cleanup_sparse_checkout" &&
	setup_sparse_checkout &&
	mkdir sub/dir/deep &&
	touch sub/dir/e2 sub/dir/e3 &&
	shit add sub/dir/e2 sub/dir/e3 &&
	echo "modified" >>sub/dir/e2 &&
	echo "modified" >>sub/dir/e3 &&

	test_must_fail shit mv sub/dir folder1 2>stderr &&
	cat sparse_error_header >expect &&
	echo "folder1/dir/e" >>expect &&
	echo "folder1/dir/e2" >>expect &&
	echo "folder1/dir/e3" >>expect &&
	cat sparse_hint >>expect &&
	test_cmp expect stderr &&

	shit mv --sparse sub/dir folder1 2>stderr &&
	cat dirty_error_header >expect &&
	echo "folder1/dir/e2" >>expect &&
	echo "folder1/dir/e3" >>expect &&
	cat dirty_hint >>expect &&
	test_cmp expect stderr &&

	test_path_is_missing sub/dir &&
	test_path_is_missing folder1/dir/e &&
	test_path_is_file folder1/dir/e2 &&
	test_path_is_file folder1/dir/e3 &&
	shit ls-files -t >actual &&
	! grep "H sub/dir/e" actual &&
	! grep "H sub/dir/e2" actual &&
	! grep "H sub/dir/e3" actual &&
	grep "S folder1/dir/e" actual &&
	grep "H folder1/dir/e2" actual &&
	grep "H folder1/dir/e3" actual
'

test_done
