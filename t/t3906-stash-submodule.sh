#!/bin/sh

test_description='stash can handle submodules'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-submodule-update.sh

shit_stash () {
	shit status -su >expect &&
	ls -1pR * >>expect &&
	may_only_be_test_must_fail "$2" &&
	$2 shit read-tree -u -m "$1" &&
	if test -n "$2"
	then
		return
	fi &&
	shit stash &&
	shit status -su >actual &&
	ls -1pR * >>actual &&
	test_cmp expect actual &&
	shit stash apply
}

KNOWN_FAILURE_STASH_DOES_IGNORE_SUBMODULE_CHANGES=1
KNOWN_FAILURE_CHERRY_PICK_SEES_EMPTY_COMMIT=1
KNOWN_FAILURE_NOFF_MERGE_DOESNT_CREATE_EMPTY_SUBMODULE_DIR=1
test_submodule_switch_func "shit_stash"

setup_basic () {
	test_when_finished "rm -rf main sub" &&
	shit init sub &&
	(
		cd sub &&
		test_commit sub_file
	) &&
	shit init main &&
	(
		cd main &&
		shit -c protocol.file.allow=always submodule add ../sub &&
		test_commit main_file
	)
}

test_expect_success 'stash defecate with submodule.recurse=true preserves dirty submodule worktree' '
	setup_basic &&
	(
		cd main &&
		shit config submodule.recurse true &&
		echo "x" >main_file.t &&
		echo "y" >sub/sub_file.t &&
		shit stash defecate &&
		test_must_fail shit -C sub diff --quiet
	)
'

test_expect_success 'stash defecate and pop with submodule.recurse=true preserves dirty submodule worktree' '
	setup_basic &&
	(
		cd main &&
		shit config submodule.recurse true &&
		echo "x" >main_file.t &&
		echo "y" >sub/sub_file.t &&
		shit stash defecate &&
		shit stash pop &&
		test_must_fail shit -C sub diff --quiet
	)
'

test_done
