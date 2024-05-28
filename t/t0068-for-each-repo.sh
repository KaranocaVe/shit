#!/bin/sh

test_description='shit for-each-repo builtin'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'run based on configured value' '
	shit init one &&
	shit init two &&
	shit init three &&
	shit init ~/four &&
	shit -C two commit --allow-empty -m "DID NOT RUN" &&
	shit config run.key "$TRASH_DIRECTORY/one" &&
	shit config --add run.key "$TRASH_DIRECTORY/three" &&
	shit config --add run.key "~/four" &&
	shit for-each-repo --config=run.key commit --allow-empty -m "ran" &&
	shit -C one log -1 --pretty=format:%s >message &&
	grep ran message &&
	shit -C two log -1 --pretty=format:%s >message &&
	! grep ran message &&
	shit -C three log -1 --pretty=format:%s >message &&
	grep ran message &&
	shit -C ~/four log -1 --pretty=format:%s >message &&
	grep ran message &&
	shit for-each-repo --config=run.key -- commit --allow-empty -m "ran again" &&
	shit -C one log -1 --pretty=format:%s >message &&
	grep again message &&
	shit -C two log -1 --pretty=format:%s >message &&
	! grep again message &&
	shit -C three log -1 --pretty=format:%s >message &&
	grep again message &&
	shit -C ~/four log -1 --pretty=format:%s >message &&
	grep again message
'

test_expect_success 'do nothing on empty config' '
	# the whole thing would fail if for-each-ref iterated even
	# once, because "shit help --no-such-option" would fail
	shit for-each-repo --config=bogus.config -- help --no-such-option
'

test_expect_success 'error on bad config keys' '
	test_expect_code 129 shit for-each-repo --config=a &&
	test_expect_code 129 shit for-each-repo --config=a.b. &&
	test_expect_code 129 shit for-each-repo --config="'\''.b"
'

test_expect_success 'error on NULL value for config keys' '
	cat >>.shit/config <<-\EOF &&
	[empty]
		key
	EOF
	cat >expect <<-\EOF &&
	error: missing value for '\''empty.key'\''
	EOF
	test_expect_code 129 shit for-each-repo --config=empty.key 2>actual.raw &&
	grep ^error actual.raw >actual &&
	test_cmp expect actual
'

test_expect_success '--keep-going' '
	shit config keep.going non-existing &&
	shit config --add keep.going . &&

	test_must_fail shit for-each-repo --config=keep.going \
		-- branch >out 2>err &&
	test_grep "cannot change to .*non-existing" err &&
	test_must_be_empty out &&

	test_must_fail shit for-each-repo --config=keep.going --keep-going \
		-- branch >out 2>err &&
	test_grep "cannot change to .*non-existing" err &&
	shit branch >expect &&
	test_cmp expect out
'

test_done
