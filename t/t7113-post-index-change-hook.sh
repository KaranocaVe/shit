#!/bin/sh

test_description='post index change hook'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	mkdir -p dir1 &&
	touch dir1/file1.txt &&
	echo testing >dir1/file2.txt &&
	shit add . &&
	shit commit -m "initial"
'

test_expect_success 'test status, add, commit, others trigger hook without flags set' '
	test_hook post-index-change <<-\EOF &&
		if test "$1" -eq 1; then
			echo "Invalid combination of flags passed to hook; updated_workdir is set." >testfailure
			exit 1
		fi
		if test "$2" -eq 1; then
			echo "Invalid combination of flags passed to hook; updated_skipworktree is set." >testfailure
			exit 1
		fi
		if test -f ".shit/index.lock"; then
			echo ".shit/index.lock exists" >testfailure
			exit 3
		fi
		if ! test -f ".shit/index"; then
			echo ".shit/index does not exist" >testfailure
			exit 3
		fi
		echo "success" >testsuccess
	EOF
	mkdir -p dir2 &&
	touch dir2/file1.txt &&
	touch dir2/file2.txt &&
	: force index to be dirty &&
	test-tool chmtime +60 dir1/file1.txt &&
	shit status &&
	test_path_is_file testsuccess && rm -f testsuccess &&
	test_path_is_missing testfailure &&
	shit add . &&
	test_path_is_file testsuccess && rm -f testsuccess &&
	test_path_is_missing testfailure &&
	shit commit -m "second" &&
	test_path_is_file testsuccess && rm -f testsuccess &&
	test_path_is_missing testfailure &&
	shit checkout -- dir1/file1.txt &&
	test_path_is_file testsuccess && rm -f testsuccess &&
	test_path_is_missing testfailure &&
	shit update-index &&
	test_path_is_missing testsuccess &&
	test_path_is_missing testfailure &&
	shit reset --soft &&
	test_path_is_missing testsuccess &&
	test_path_is_missing testfailure
'

test_expect_success 'test checkout and reset trigger the hook' '
	test_hook post-index-change <<-\EOF &&
		if test "$1" -eq 1 && test "$2" -eq 1; then
			echo "Invalid combination of flags passed to hook; updated_workdir and updated_skipworktree are both set." >testfailure
			exit 1
		fi
		if test "$1" -eq 0 && test "$2" -eq 0; then
			echo "Invalid combination of flags passed to hook; neither updated_workdir or updated_skipworktree are set." >testfailure
			exit 2
		fi
		if test "$1" -eq 1; then
			if test -f ".shit/index.lock"; then
				echo "updated_workdir set but .shit/index.lock exists" >testfailure
				exit 3
			fi
			if ! test -f ".shit/index"; then
				echo "updated_workdir set but .shit/index does not exist" >testfailure
				exit 3
			fi
		else
			echo "update_workdir should be set for checkout" >testfailure
			exit 4
		fi
		echo "success" >testsuccess
	EOF
	: force index to be dirty &&
	test-tool chmtime +60 dir1/file1.txt &&
	shit checkout main &&
	test_path_is_file testsuccess && rm -f testsuccess &&
	test_path_is_missing testfailure &&
	test-tool chmtime +60 dir1/file1.txt &&
	shit checkout HEAD &&
	test_path_is_file testsuccess && rm -f testsuccess &&
	test_path_is_missing testfailure &&
	test-tool chmtime +60 dir1/file1.txt &&
	shit reset --hard &&
	test_path_is_file testsuccess && rm -f testsuccess &&
	test_path_is_missing testfailure &&
	shit checkout -B test &&
	test_path_is_file testsuccess && rm -f testsuccess &&
	test_path_is_missing testfailure
'

test_expect_success 'test reset --mixed and update-index triggers the hook' '
	test_hook post-index-change <<-\EOF &&
		if test "$1" -eq 1 && test "$2" -eq 1; then
			echo "Invalid combination of flags passed to hook; updated_workdir and updated_skipworktree are both set." >testfailure
			exit 1
		fi
		if test "$1" -eq 0 && test "$2" -eq 0; then
			echo "Invalid combination of flags passed to hook; neither updated_workdir or updated_skipworktree are set." >testfailure
			exit 2
		fi
		if test "$2" -eq 1; then
			if test -f ".shit/index.lock"; then
				echo "updated_skipworktree set but .shit/index.lock exists" >testfailure
				exit 3
			fi
			if ! test -f ".shit/index"; then
				echo "updated_skipworktree set but .shit/index does not exist" >testfailure
				exit 3
			fi
		else
			echo "updated_skipworktree should be set for reset --mixed and update-index" >testfailure
			exit 4
		fi
		echo "success" >testsuccess
	EOF
	: force index to be dirty &&
	test-tool chmtime +60 dir1/file1.txt &&
	shit reset --mixed --quiet HEAD~1 &&
	test_path_is_file testsuccess && rm -f testsuccess &&
	test_path_is_missing testfailure &&
	shit hash-object -w --stdin <dir1/file2.txt >expect &&
	shit update-index --cacheinfo 100644 "$(cat expect)" dir1/file1.txt &&
	test_path_is_file testsuccess && rm -f testsuccess &&
	test_path_is_missing testfailure &&
	shit update-index --skip-worktree dir1/file2.txt &&
	shit update-index --remove dir1/file2.txt &&
	test_path_is_file testsuccess && rm -f testsuccess &&
	test_path_is_missing testfailure
'

test_done
