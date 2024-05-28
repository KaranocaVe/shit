#!/bin/sh

test_description='shit diagnose'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success UNZIP 'creates diagnostics zip archive' '
	test_when_finished rm -rf report &&

	shit diagnose -o report -s test >out &&
	grep "Available space" out &&

	zip_path=report/shit-diagnostics-test.zip &&
	test_path_is_file "$zip_path" &&

	# Check zipped archive content
	"$shit_UNZIP" -p "$zip_path" diagnostics.log >out &&
	test_file_not_empty out &&

	"$shit_UNZIP" -p "$zip_path" packs-local.txt >out &&
	grep ".shit/objects" out &&

	"$shit_UNZIP" -p "$zip_path" objects-local.txt >out &&
	grep "^Total: [0-9][0-9]*" out &&

	# Should not include .shit directory contents by default
	! "$shit_UNZIP" -l "$zip_path" | grep ".shit/"
'

test_expect_success UNZIP 'counts loose objects' '
	test_commit A &&

	# After committing, should have non-zero loose objects
	shit diagnose -o test-count -s 1 >out &&
	zip_path=test-count/shit-diagnostics-1.zip &&
	"$shit_UNZIP" -p "$zip_path" objects-local.txt >out &&
	grep "^Total: [1-9][0-9]* loose objects" out
'

test_expect_success UNZIP '--mode=stats excludes .shit dir contents' '
	test_when_finished rm -rf report &&

	shit diagnose -o report -s test --mode=stats >out &&

	# Includes pack quantity/size info
	zip_path=report/shit-diagnostics-test.zip &&
	"$shit_UNZIP" -p "$zip_path" packs-local.txt >out &&
	grep ".shit/objects" out &&

	# Does not include .shit directory contents
	! "$shit_UNZIP" -l "$zip_path" | grep ".shit/"
'

test_expect_success UNZIP '--mode=all includes .shit dir contents' '
	test_when_finished rm -rf report &&

	shit diagnose -o report -s test --mode=all >out &&

	# Includes pack quantity/size info
	zip_path=report/shit-diagnostics-test.zip &&
	"$shit_UNZIP" -p "$zip_path" packs-local.txt >out &&
	grep ".shit/objects" out &&

	# Includes .shit directory contents
	"$shit_UNZIP" -l "$zip_path" | grep ".shit/" &&

	"$shit_UNZIP" -p "$zip_path" .shit/HEAD >out &&
	test_file_not_empty out
'

test_done
