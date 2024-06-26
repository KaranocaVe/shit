#!/bin/sh

test_description='test custom script in place of pack-objects'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'create some history to fetch' '
	test_commit one &&
	test_commit two
'

test_expect_success 'create debugging hook script' '
	write_script .shit/hook <<-\EOF
		echo >&2 "hook running"
		echo "$*" >hook.args
		cat >hook.stdin
		"$@" <hook.stdin >hook.stdout
		cat hook.stdout
	EOF
'

clear_hook_results () {
	rm -rf .shit/hook.* dst.shit
}

test_expect_success 'hook runs via global config' '
	clear_hook_results &&
	test_config_global uploadpack.packObjectsHook ./hook &&
	shit clone --no-local . dst.shit 2>stderr &&
	grep "hook running" stderr
'

test_expect_success 'hook outputs are sane' '
	# check that we recorded a usable pack
	shit index-pack --stdin <.shit/hook.stdout &&

	# check that we recorded args and stdin. We do not check
	# the full argument list or the exact pack contents, as it would make
	# the test brittle. So just sanity check that we could replay
	# the packing procedure.
	grep "^shit" .shit/hook.args &&
	$(cat .shit/hook.args) <.shit/hook.stdin >replay
'

test_expect_success 'hook runs from -c config' '
	clear_hook_results &&
	shit clone --no-local \
	  -u "shit -c uploadpack.packObjectsHook=./hook upload-pack" \
	  . dst.shit 2>stderr &&
	grep "hook running" stderr
'

test_expect_success 'hook does not run from repo config' '
	clear_hook_results &&
	test_config uploadpack.packObjectsHook "./hook" &&
	shit clone --no-local . dst.shit 2>stderr &&
	! grep "hook running" stderr &&
	test_path_is_missing .shit/hook.args &&
	test_path_is_missing .shit/hook.stdin &&
	test_path_is_missing .shit/hook.stdout &&

	# check that global config is used instead
	test_config_global uploadpack.packObjectsHook ./hook &&
	shit clone --no-local . dst2.shit 2>stderr &&
	grep "hook running" stderr
'

test_expect_success 'hook works with partial clone' '
	clear_hook_results &&
	test_config_global uploadpack.packObjectsHook ./hook &&
	test_config_global uploadpack.allowFilter true &&
	shit clone --bare --no-local --filter=blob:none . dst.shit &&
	shit -C dst.shit rev-list --objects --missing=allow-any --no-object-names --all >objects &&
	shit -C dst.shit cat-file --batch-check="%(objecttype)" <objects >types &&
	! grep blob types
'

test_done
