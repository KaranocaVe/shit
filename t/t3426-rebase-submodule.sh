#!/bin/sh

test_description='rebase can handle submodules'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-submodule-update.sh
. "$TEST_DIRECTORY"/lib-rebase.sh

shit_rebase () {
	shit status -su >expect &&
	ls -1pR * >>expect &&
	shit checkout -b ours HEAD &&
	echo x >>file1 &&
	shit add file1 &&
	shit commit -m add_x &&
	shit revert HEAD &&
	shit status -su >actual &&
	ls -1pR * >>actual &&
	test_cmp expect actual &&
	may_only_be_test_must_fail "$2" &&
	$2 shit rebase "$1"
}

test_submodule_switch_func "shit_rebase"

shit_rebase_interactive () {
	shit status -su >expect &&
	ls -1pR * >>expect &&
	shit checkout -b ours HEAD &&
	echo x >>file1 &&
	shit add file1 &&
	shit commit -m add_x &&
	shit revert HEAD &&
	shit status -su >actual &&
	ls -1pR * >>actual &&
	test_cmp expect actual &&
	set_fake_editor &&
	mkdir .shit/info &&
	echo "fake-editor.sh" >.shit/info/exclude &&
	may_only_be_test_must_fail "$2" &&
	$2 shit rebase -i "$1"
}

test_submodule_switch_func "shit_rebase_interactive"

test_expect_success 'rebase interactive ignores modified submodules' '
	test_when_finished "rm -rf super sub" &&
	shit init sub &&
	shit -C sub commit --allow-empty -m "Initial commit" &&
	shit init super &&
	shit -c protocol.file.allow=always \
		-C super submodule add ../sub &&
	shit -C super config submodule.sub.ignore dirty &&
	>super/foo &&
	shit -C super add foo &&
	shit -C super commit -m "Initial commit" &&
	test_commit -C super a &&
	test_commit -C super b &&
	test_commit -C super/sub c &&
	set_fake_editor &&
	shit -C super rebase -i HEAD^^
'

test_done
