#!/bin/sh

test_description='read-tree -u --reset'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-read-tree.sh

# two-tree test

test_expect_success 'setup' '
	shit init &&
	mkdir df &&
	echo content >df/file &&
	shit add df/file &&
	shit commit -m one &&
	shit ls-files >expect &&
	rm -rf df &&
	echo content >df &&
	shit add df &&
	echo content >new &&
	shit add new &&
	shit commit -m two
'

test_expect_success 'reset should work' '
	read_tree_u_must_succeed -u --reset HEAD^ &&
	shit ls-files >actual &&
	test_cmp expect actual
'

test_expect_success 'reset should remove remnants from a failed merge' '
	read_tree_u_must_succeed --reset -u HEAD &&
	shit ls-files -s >expect &&
	sha1=$(shit rev-parse :new) &&
	(
		echo "100644 $sha1 1	old" &&
		echo "100644 $sha1 3	old"
	) | shit update-index --index-info &&
	>old &&
	shit ls-files -s &&
	read_tree_u_must_succeed --reset -u HEAD &&
	shit ls-files -s >actual &&
	! test -f old &&
	test_cmp expect actual
'

test_expect_success 'two-way reset should remove remnants too' '
	read_tree_u_must_succeed --reset -u HEAD &&
	shit ls-files -s >expect &&
	sha1=$(shit rev-parse :new) &&
	(
		echo "100644 $sha1 1	old" &&
		echo "100644 $sha1 3	old"
	) | shit update-index --index-info &&
	>old &&
	shit ls-files -s &&
	read_tree_u_must_succeed --reset -u HEAD HEAD &&
	shit ls-files -s >actual &&
	! test -f old &&
	test_cmp expect actual
'

test_expect_success 'Porcelain reset should remove remnants too' '
	read_tree_u_must_succeed --reset -u HEAD &&
	shit ls-files -s >expect &&
	sha1=$(shit rev-parse :new) &&
	(
		echo "100644 $sha1 1	old" &&
		echo "100644 $sha1 3	old"
	) | shit update-index --index-info &&
	>old &&
	shit ls-files -s &&
	shit reset --hard &&
	shit ls-files -s >actual &&
	! test -f old &&
	test_cmp expect actual
'

test_expect_success 'Porcelain checkout -f should remove remnants too' '
	read_tree_u_must_succeed --reset -u HEAD &&
	shit ls-files -s >expect &&
	sha1=$(shit rev-parse :new) &&
	(
		echo "100644 $sha1 1	old" &&
		echo "100644 $sha1 3	old"
	) | shit update-index --index-info &&
	>old &&
	shit ls-files -s &&
	shit checkout -f &&
	shit ls-files -s >actual &&
	! test -f old &&
	test_cmp expect actual
'

test_expect_success 'Porcelain checkout -f HEAD should remove remnants too' '
	read_tree_u_must_succeed --reset -u HEAD &&
	shit ls-files -s >expect &&
	sha1=$(shit rev-parse :new) &&
	(
		echo "100644 $sha1 1	old" &&
		echo "100644 $sha1 3	old"
	) | shit update-index --index-info &&
	>old &&
	shit ls-files -s &&
	shit checkout -f HEAD &&
	shit ls-files -s >actual &&
	! test -f old &&
	test_cmp expect actual
'

test_done
