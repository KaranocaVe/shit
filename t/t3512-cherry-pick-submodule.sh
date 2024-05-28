#!/bin/sh

test_description='cherry-pick can handle submodules'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-submodule-update.sh

if test "$shit_TEST_MERGE_ALGORITHM" != ort
then
	KNOWN_FAILURE_NOFF_MERGE_DOESNT_CREATE_EMPTY_SUBMODULE_DIR=1
	KNOWN_FAILURE_NOFF_MERGE_ATTEMPTS_TO_MERGE_REMOVED_SUBMODULE_FILES=1
fi
test_submodule_switch "cherry-pick"

test_expect_success 'unrelated submodule/file conflict is ignored' '
	test_config_global protocol.file.allow always &&

	test_create_repo sub &&

	touch sub/file &&
	shit -C sub add file &&
	shit -C sub commit -m "add a file in a submodule" &&

	test_create_repo a_repo &&
	(
		cd a_repo &&
		>a_file &&
		shit add a_file &&
		shit commit -m "add a file" &&

		shit branch test &&
		shit checkout test &&

		mkdir sub &&
		>sub/content &&
		shit add sub/content &&
		shit commit -m "add a regular folder with name sub" &&

		echo "123" >a_file &&
		shit add a_file &&
		shit commit -m "modify a file" &&

		shit checkout main &&

		shit submodule add ../sub sub &&
		shit submodule update sub &&
		shit commit -m "add a submodule info folder with name sub" &&

		shit cherry-pick test
	)
'

test_done
