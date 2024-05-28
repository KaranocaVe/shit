#!/bin/sh

test_description='shit am handling submodules'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-submodule-update.sh

am () {
	shit format-patch --stdout --ignore-submodules=dirty "..$1" >patch &&
	may_only_be_test_must_fail "$2" &&
	$2 shit am patch
}

test_submodule_switch_func "am"

am_3way () {
	shit format-patch --stdout --ignore-submodules=dirty "..$1" >patch &&
	may_only_be_test_must_fail "$2" &&
	$2 shit am --3way patch
}

KNOWN_FAILURE_NOFF_MERGE_ATTEMPTS_TO_MERGE_REMOVED_SUBMODULE_FILES=1
test_submodule_switch_func "am_3way"

test_expect_success 'setup diff.submodule' '
	test_commit one &&
	INITIAL=$(shit rev-parse HEAD) &&

	shit init submodule &&
	(
		cd submodule &&
		test_commit two &&
		shit rev-parse HEAD >../initial-submodule
	) &&
	shit submodule add ./submodule &&
	shit commit -m first &&

	(
		cd submodule &&
		test_commit three &&
		shit rev-parse HEAD >../first-submodule
	) &&
	shit add submodule &&
	shit commit -m second &&
	SECOND=$(shit rev-parse HEAD) &&

	(
		cd submodule &&
		shit mv two.t four.t &&
		shit commit -m "second submodule" &&
		shit rev-parse HEAD >../second-submodule
	) &&
	test_commit four &&
	shit add submodule &&
	shit commit --amend --no-edit &&
	THIRD=$(shit rev-parse HEAD) &&
	shit submodule update --init
'

run_test() {
	START_COMMIT=$1 &&
	EXPECT=$2 &&
	# Abort any merges in progress: the previous
	# test may have failed, and we should clean up.
	test_might_fail shit am --abort &&
	shit reset --hard $START_COMMIT &&
	rm -f *.patch &&
	shit format-patch -1 &&
	shit reset --hard $START_COMMIT^ &&
	shit submodule update &&
	shit am *.patch &&
	shit submodule update &&
	shit -C submodule rev-parse HEAD >actual &&
	test_cmp $EXPECT actual
}

test_expect_success 'diff.submodule unset' '
	test_unconfig diff.submodule &&
	run_test $SECOND first-submodule
'

test_expect_success 'diff.submodule unset with extra file' '
	test_unconfig diff.submodule &&
	run_test $THIRD second-submodule
'

test_expect_success 'diff.submodule=log' '
	test_config diff.submodule log &&
	run_test $SECOND first-submodule
'

test_expect_success 'diff.submodule=log with extra file' '
	test_config diff.submodule log &&
	run_test $THIRD second-submodule
'

test_done
