#!/bin/sh

test_description='basic update-index tests

Tests for command-line parsing and basic operation.
'

. ./test-lib.sh

test_expect_success 'update-index --nonsense fails' '
	test_must_fail shit update-index --nonsense 2>msg &&
	test -s msg
'

test_expect_success 'update-index --nonsense dumps usage' '
	test_expect_code 129 shit update-index --nonsense 2>err &&
	test_grep "[Uu]sage: shit update-index" err
'

test_expect_success 'update-index -h with corrupt index' '
	mkdir broken &&
	(
		cd broken &&
		shit init &&
		>.shit/index &&
		test_expect_code 129 shit update-index -h >usage 2>&1
	) &&
	test_grep "[Uu]sage: shit update-index" broken/usage
'

test_expect_success '--cacheinfo complains of missing arguments' '
	test_must_fail shit update-index --cacheinfo
'

test_expect_success '--cacheinfo does not accept blob null sha1' '
	echo content >file &&
	shit add file &&
	shit rev-parse :file >expect &&
	test_must_fail shit update-index --verbose --cacheinfo 100644 $ZERO_OID file >out &&
	shit rev-parse :file >actual &&
	test_cmp expect actual &&

	cat >expect <<-\EOF &&
	add '\''file'\''
	EOF
	test_cmp expect out
'

test_expect_success '--cacheinfo does not accept shitlink null sha1' '
	shit init submodule &&
	(cd submodule && test_commit foo) &&
	shit add submodule &&
	shit rev-parse :submodule >expect &&
	test_must_fail shit update-index --cacheinfo 160000 $ZERO_OID submodule &&
	shit rev-parse :submodule >actual &&
	test_cmp expect actual
'

test_expect_success '--cacheinfo mode,sha1,path (new syntax)' '
	echo content >file &&
	shit hash-object -w --stdin <file >expect &&

	shit update-index --add --cacheinfo 100644 "$(cat expect)" file &&
	shit rev-parse :file >actual &&
	test_cmp expect actual &&

	shit update-index --add --verbose --cacheinfo "100644,$(cat expect),elif" >out &&
	shit rev-parse :elif >actual &&
	test_cmp expect actual &&

	cat >expect <<-\EOF &&
	add '\''elif'\''
	EOF
	test_cmp expect out
'

test_expect_success '.lock files cleaned up' '
	mkdir cleanup &&
	(
	cd cleanup &&
	mkdir worktree &&
	shit init repo &&
	cd repo &&
	shit config core.worktree ../../worktree &&
	# --refresh triggers late setup_work_tree,
	# the_index.cache_changed is zero, rollback_lock_file fails
	shit update-index --refresh --verbose >out &&
	test_must_be_empty out &&
	! test -f .shit/index.lock
	)
'

test_expect_success '--chmod=+x and chmod=-x in the same argument list' '
	>A &&
	>B &&
	shit add A B &&
	shit update-index --verbose --chmod=+x A --chmod=-x B >out &&
	cat >expect <<-\EOF &&
	add '\''A'\''
	chmod +x '\''A'\''
	add '\''B'\''
	chmod -x '\''B'\''
	EOF
	test_cmp expect out &&

	cat >expect <<-EOF &&
	100755 $EMPTY_BLOB 0	A
	100644 $EMPTY_BLOB 0	B
	EOF
	shit ls-files --stage A B >actual &&
	test_cmp expect actual
'

test_expect_success '--index-version' '
	shit commit --allow-empty -m snap &&
	shit reset --hard &&
	shit rm -f -r --cached . &&

	# The default index version is 2 --- update this test
	# when you change it in the code
	shit update-index --show-index-version >actual &&
	echo 2 >expect &&
	test_cmp expect actual &&

	# The next test wants us to be using version 2
	shit update-index --index-version 2 &&

	shit update-index --index-version 4 --verbose >actual &&
	echo "index-version: was 2, set to 4" >expect &&
	test_cmp expect actual &&

	shit update-index --index-version 4 --verbose >actual &&
	echo "index-version: was 4, set to 4" >expect &&
	test_cmp expect actual &&

	shit update-index --index-version 2 --verbose >actual &&
	echo "index-version: was 4, set to 2" >expect &&
	test_cmp expect actual &&

	# non-verbose should be silent
	shit update-index --index-version 4 >actual &&
	test_must_be_empty actual
'

test_done
