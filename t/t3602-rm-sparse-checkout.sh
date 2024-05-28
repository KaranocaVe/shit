#!/bin/sh

test_description='shit rm in sparse checked out working trees'

. ./test-lib.sh

test_expect_success 'setup' "
	mkdir -p sub/dir &&
	touch a b c sub/d sub/dir/e &&
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

	echo b | cat sparse_error_header - >sparse_entry_b_error &&
	cat sparse_entry_b_error sparse_hint >b_error_and_hint
"

for opt in "" -f --dry-run
do
	test_expect_success "rm${opt:+ $opt} does not remove sparse entries" '
		shit sparse-checkout set --no-cone a &&
		test_must_fail shit rm $opt b 2>stderr &&
		test_cmp b_error_and_hint stderr &&
		shit ls-files --error-unmatch b
	'
done

test_expect_success 'recursive rm does not remove sparse entries' '
	shit reset --hard &&
	shit sparse-checkout set sub/dir &&
	shit rm -r sub &&
	shit status --porcelain -uno >actual &&
	cat >expected <<-\EOF &&
	D  sub/dir/e
	EOF
	test_cmp expected actual &&

	shit rm --sparse -r sub &&
	shit status --porcelain -uno >actual2 &&
	cat >expected2 <<-\EOF &&
	D  sub/d
	D  sub/dir/e
	EOF
	test_cmp expected2 actual2
'

test_expect_success 'recursive rm --sparse removes sparse entries' '
	shit reset --hard &&
	shit sparse-checkout set "sub/dir" &&
	shit rm --sparse -r sub &&
	shit status --porcelain -uno >actual &&
	cat >expected <<-\EOF &&
	D  sub/d
	D  sub/dir/e
	EOF
	test_cmp expected actual
'

test_expect_success 'rm obeys advice.updateSparsePath' '
	shit reset --hard &&
	shit sparse-checkout set a &&
	test_must_fail shit -c advice.updateSparsePath=false rm b 2>stderr &&
	test_cmp sparse_entry_b_error stderr
'

test_expect_success 'do not advice about sparse entries when they do not match the pathspec' '
	shit reset --hard &&
	shit sparse-checkout set a &&
	test_must_fail shit rm nonexistent 2>stderr &&
	grep "fatal: pathspec .nonexistent. did not match any files" stderr &&
	! grep -F -f sparse_error_header stderr
'

test_expect_success 'do not warn about sparse entries when pathspec matches dense entries' '
	shit reset --hard &&
	shit sparse-checkout set a &&
	shit rm "[ba]" 2>stderr &&
	test_must_be_empty stderr &&
	shit ls-files --error-unmatch b &&
	test_must_fail shit ls-files --error-unmatch a
'

test_expect_success 'do not warn about sparse entries with --ignore-unmatch' '
	shit reset --hard &&
	shit sparse-checkout set a &&
	shit rm --ignore-unmatch b 2>stderr &&
	test_must_be_empty stderr &&
	shit ls-files --error-unmatch b
'

test_expect_success 'refuse to rm a non-skip-worktree path outside sparse cone' '
	shit reset --hard &&
	shit sparse-checkout set a &&
	shit update-index --no-skip-worktree b &&
	test_must_fail shit rm b 2>stderr &&
	test_cmp b_error_and_hint stderr &&
	shit rm --sparse b 2>stderr &&
	test_must_be_empty stderr &&
	test_path_is_missing b
'

test_expect_success 'can remove files from non-sparse dir' '
	shit reset --hard &&
	shit sparse-checkout disable &&
	mkdir -p w x/y &&
	test_commit w/f &&
	test_commit x/y/f &&

	shit sparse-checkout set --no-cone w !/x y/ &&
	shit rm w/f.t x/y/f.t 2>stderr &&
	test_must_be_empty stderr
'

test_expect_success 'refuse to remove non-skip-worktree file from sparse dir' '
	shit reset --hard &&
	shit sparse-checkout disable &&
	mkdir -p x/y/z &&
	test_commit x/y/z/f &&
	shit sparse-checkout set --no-cone !/x y/ !x/y/z &&

	shit update-index --no-skip-worktree x/y/z/f.t &&
	test_must_fail shit rm x/y/z/f.t 2>stderr &&
	echo x/y/z/f.t | cat sparse_error_header - sparse_hint >expect &&
	test_cmp expect stderr
'

test_done
