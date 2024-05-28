#!/bin/sh
#
# Copyright (c) 2014 Heiko Voigt
#

test_description='Test submodules config cache infrastructure

This test verifies that parsing .shitmodules configurations directly
from the database and from the worktree works.
'

TEST_NO_CREATE_REPO=1
. ./test-lib.sh

test_expect_success 'setup' '
	shit config --global protocol.file.allow always
'
test_expect_success 'submodule config cache setup' '
	mkdir submodule &&
	(cd submodule &&
		shit init &&
		echo a >a &&
		shit add . &&
		shit commit -ma
	) &&
	mkdir super &&
	(cd super &&
		shit init &&
		shit submodule add ../submodule &&
		shit submodule add ../submodule a &&
		shit commit -m "add as submodule and as a" &&
		shit mv a b &&
		shit commit -m "move a to b"
	)
'

test_expect_success 'configuration parsing with error' '
	test_when_finished "rm -rf repo" &&
	test_create_repo repo &&
	cat >repo/.shitmodules <<-\EOF &&
	[submodule "s"]
		path
		ignore
	EOF
	(
		cd repo &&
		test_must_fail test-tool submodule-config "" s 2>actual &&
		test_grep "bad config" actual
	)
'

cat >super/expect <<EOF
Submodule name: 'a' for path 'a'
Submodule name: 'a' for path 'b'
Submodule name: 'submodule' for path 'submodule'
Submodule name: 'submodule' for path 'submodule'
EOF

test_expect_success 'test parsing and lookup of submodule config by path' '
	(cd super &&
		test-tool submodule-config \
			HEAD^ a \
			HEAD b \
			HEAD^ submodule \
			HEAD submodule \
				>actual &&
		test_cmp expect actual
	)
'

test_expect_success 'test parsing and lookup of submodule config by name' '
	(cd super &&
		test-tool submodule-config --name \
			HEAD^ a \
			HEAD a \
			HEAD^ submodule \
			HEAD submodule \
				>actual &&
		test_cmp expect actual
	)
'

cat >super/expect_error <<EOF
Submodule name: 'a' for path 'b'
Submodule name: 'submodule' for path 'submodule'
EOF

test_expect_success 'error in history of one submodule config lets continue, stderr message contains blob ref' '
	ORIG=$(shit -C super rev-parse HEAD) &&
	test_when_finished "shit -C super reset --hard $ORIG" &&
	(cd super &&
		cp .shitmodules .shitmodules.bak &&
		echo "	value = \"" >>.shitmodules &&
		shit add .shitmodules &&
		mv .shitmodules.bak .shitmodules &&
		shit commit -m "add error" &&
		sha1=$(shit rev-parse HEAD) &&
		test-tool submodule-config \
			HEAD b \
			HEAD submodule \
				>actual \
				2>actual_stderr &&
		test_cmp expect_error actual &&
		test_grep "submodule-blob $sha1:.shitmodules" actual_stderr >/dev/null
	)
'

test_expect_success 'using different treeishs works' '
	(
		cd super &&
		shit tag new_tag &&
		tree=$(shit rev-parse HEAD^{tree}) &&
		commit=$(shit rev-parse HEAD^{commit}) &&
		test-tool submodule-config $commit b >expect &&
		test-tool submodule-config $tree b >actual.1 &&
		test-tool submodule-config new_tag b >actual.2 &&
		test_cmp expect actual.1 &&
		test_cmp expect actual.2
	)
'

test_expect_success 'error in history in fetchrecursesubmodule lets continue' '
	ORIG=$(shit -C super rev-parse HEAD) &&
	test_when_finished "shit -C super reset --hard $ORIG" &&
	(cd super &&
		shit config -f .shitmodules \
			submodule.submodule.fetchrecursesubmodules blabla &&
		shit add .shitmodules &&
		shit config --unset -f .shitmodules \
			submodule.submodule.fetchrecursesubmodules &&
		shit commit -m "add error in fetchrecursesubmodules" &&
		test-tool submodule-config \
			HEAD b \
			HEAD submodule \
				>actual &&
		test_cmp expect_error actual
	)
'

test_expect_success 'reading submodules config from the working tree' '
	(cd super &&
		echo "../submodule" >expect &&
		test-tool submodule config-list submodule.submodule.url >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'unsetting submodules config from the working tree' '
	(cd super &&
		test-tool submodule config-unset submodule.submodule.url &&
		test-tool submodule config-list submodule.submodule.url >actual &&
		test_must_be_empty actual
	)
'


test_expect_success 'writing submodules config' '
	(cd super &&
		echo "new_url" >expect &&
		test-tool submodule config-set submodule.submodule.url "new_url" &&
		test-tool submodule config-list submodule.submodule.url >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'overwriting unstaged submodules config' '
	test_when_finished "shit -C super checkout .shitmodules" &&
	(cd super &&
		echo "newer_url" >expect &&
		test-tool submodule config-set submodule.submodule.url "newer_url" &&
		test-tool submodule config-list submodule.submodule.url >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'writeable .shitmodules when it is in the working tree' '
	test-tool -C super submodule config-writeable
'

test_expect_success 'writeable .shitmodules when it is nowhere in the repository' '
	ORIG=$(shit -C super rev-parse HEAD) &&
	test_when_finished "shit -C super reset --hard $ORIG" &&
	(cd super &&
		shit rm .shitmodules &&
		shit commit -m "remove .shitmodules from the current branch" &&
		test-tool submodule config-writeable
	)
'

test_expect_success 'non-writeable .shitmodules when it is in the index but not in the working tree' '
	test_when_finished "shit -C super checkout .shitmodules" &&
	(cd super &&
		rm -f .shitmodules &&
		test_must_fail test-tool submodule config-writeable
	)
'

test_expect_success 'non-writeable .shitmodules when it is in the current branch but not in the index' '
	ORIG=$(shit -C super rev-parse HEAD) &&
	test_when_finished "shit -C super reset --hard $ORIG" &&
	(cd super &&
		shit rm .shitmodules &&
		test_must_fail test-tool submodule config-writeable
	)
'

test_expect_success 'reading submodules config from the index when .shitmodules is not in the working tree' '
	ORIG=$(shit -C super rev-parse HEAD) &&
	test_when_finished "shit -C super reset --hard $ORIG" &&
	(cd super &&
		test-tool submodule config-set submodule.submodule.url "staged_url" &&
		shit add .shitmodules &&
		rm -f .shitmodules &&
		echo "staged_url" >expect &&
		test-tool submodule config-list submodule.submodule.url >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'reading submodules config from the current branch when .shitmodules is not in the index' '
	ORIG=$(shit -C super rev-parse HEAD) &&
	test_when_finished "shit -C super reset --hard $ORIG" &&
	(cd super &&
		shit rm .shitmodules &&
		echo "../submodule" >expect &&
		test-tool submodule config-list submodule.submodule.url >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'reading nested submodules config' '
	(cd super &&
		shit init submodule/nested_submodule &&
		echo "a" >submodule/nested_submodule/a &&
		shit -C submodule/nested_submodule add a &&
		shit -C submodule/nested_submodule commit -m "add a" &&
		shit -C submodule submodule add ./nested_submodule &&
		shit -C submodule add nested_submodule &&
		shit -C submodule commit -m "added nested_submodule" &&
		shit add submodule &&
		shit commit -m "updated submodule" &&
		echo "./nested_submodule" >expect &&
		test-tool submodule-nested-repo-config \
			submodule submodule.nested_submodule.url >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'reading nested submodules config when .shitmodules is not in the working tree' '
	test_when_finished "shit -C super/submodule checkout .shitmodules" &&
	(cd super &&
		echo "./nested_submodule" >expect &&
		rm submodule/.shitmodules &&
		test-tool submodule-nested-repo-config \
			submodule submodule.nested_submodule.url >actual 2>warning &&
		test_must_be_empty warning &&
		test_cmp expect actual
	)
'

test_done
