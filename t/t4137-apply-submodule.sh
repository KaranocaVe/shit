#!/bin/sh

test_description='shit apply handling submodules'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-submodule-update.sh

apply_index () {
	shit diff --ignore-submodules=dirty "..$1" >diff &&
	may_only_be_test_must_fail "$2" &&
	$2 shit apply --index diff
}

test_submodule_switch_func "apply_index"

apply_3way () {
	shit diff --ignore-submodules=dirty "..$1" >diff &&
	may_only_be_test_must_fail "$2" &&
	$2 shit apply --3way diff
}

test_submodule_switch_func "apply_3way"

test_done
