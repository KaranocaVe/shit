#!/bin/sh

test_description='sparse checkout scope tests'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_CREATE_REPO_NO_TEMPLATE=1
. ./test-lib.sh

test_expect_success 'setup' '
	echo "initial" >a &&
	echo "initial" >b &&
	echo "initial" >c &&
	shit add a b c &&
	shit commit -m "initial commit"
'

test_expect_success 'create feature branch' '
	shit checkout -b feature &&
	echo "modified" >b &&
	echo "modified" >c &&
	shit add b c &&
	shit commit -m "modification"
'

test_expect_success 'perform sparse checkout of main' '
	shit config --local --bool core.sparsecheckout true &&
	mkdir .shit/info &&
	echo "!/*" >.shit/info/sparse-checkout &&
	echo "/a" >>.shit/info/sparse-checkout &&
	echo "/c" >>.shit/info/sparse-checkout &&
	shit checkout main &&
	test_path_is_file a &&
	test_path_is_missing b &&
	test_path_is_file c
'

test_expect_success 'merge feature branch into sparse checkout of main' '
	shit merge feature &&
	test_path_is_file a &&
	test_path_is_missing b &&
	test_path_is_file c &&
	test "$(cat c)" = "modified"
'

test_expect_success 'return to full checkout of main' '
	shit checkout feature &&
	echo "/*" >.shit/info/sparse-checkout &&
	shit checkout main &&
	test_path_is_file a &&
	test_path_is_file b &&
	test_path_is_file c &&
	test "$(cat b)" = "modified"
'

test_expect_success 'skip-worktree on files outside sparse patterns' '
	shit sparse-checkout disable &&
	shit sparse-checkout set --no-cone "a*" &&
	shit checkout-index --all --ignore-skip-worktree-bits &&

	shit ls-files -t >output &&
	! grep ^S output >actual &&
	test_must_be_empty actual &&

	test_config sparse.expectFilesOutsideOfPatterns true &&
	cat <<-\EOF >expect &&
	S b
	S c
	EOF
	shit ls-files -t >output &&
	grep ^S output >actual &&
	test_cmp expect actual
'

test_expect_success 'in partial clone, sparse checkout only fetches needed blobs' '
	test_create_repo server &&
	shit clone --template= "file://$(pwd)/server" client &&

	test_config -C server uploadpack.allowfilter 1 &&
	test_config -C server uploadpack.allowanysha1inwant 1 &&
	echo a >server/a &&
	echo bb >server/b &&
	mkdir server/c &&
	echo ccc >server/c/c &&
	shit -C server add a b c/c &&
	shit -C server commit -m message &&

	test_config -C client core.sparsecheckout 1 &&
	mkdir client/.shit/info &&
	echo "!/*" >client/.shit/info/sparse-checkout &&
	echo "/a" >>client/.shit/info/sparse-checkout &&
	shit -C client fetch --filter=blob:none origin &&
	shit -C client checkout FETCH_HEAD &&

	shit -C client rev-list HEAD \
		--quiet --objects --missing=print >unsorted_actual &&
	(
		printf "?" &&
		shit hash-object server/b &&
		printf "?" &&
		shit hash-object server/c/c
	) >unsorted_expect &&
	sort unsorted_actual >actual &&
	sort unsorted_expect >expect &&
	test_cmp expect actual
'

test_done
