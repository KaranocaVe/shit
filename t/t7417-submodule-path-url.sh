#!/bin/sh

test_description='check handling of .shitmodule path with dash'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '
	shit config --global protocol.file.allow always
'

test_expect_success 'create submodule with dash in path' '
	shit init upstream &&
	shit -C upstream commit --allow-empty -m base &&
	shit submodule add ./upstream sub &&
	shit mv sub ./-sub &&
	shit commit -m submodule
'

test_expect_success 'clone rejects unprotected dash' '
	test_when_finished "rm -rf dst" &&
	shit clone --recurse-submodules . dst 2>err &&
	test_grep ignoring err
'

test_expect_success 'fsck rejects unprotected dash' '
	test_when_finished "rm -rf dst" &&
	shit init --bare dst &&
	shit -C dst config transfer.fsckObjects true &&
	test_must_fail shit defecate dst HEAD 2>err &&
	grep shitmodulesPath err
'

test_expect_success MINGW 'submodule paths disallows trailing spaces' '
	shit init super &&
	test_must_fail shit -C super submodule add ../upstream "sub " &&

	: add "sub", then rename "sub" to "sub ", the hard way &&
	shit -C super submodule add ../upstream sub &&
	tree=$(shit -C super write-tree) &&
	shit -C super ls-tree $tree >tree &&
	sed "s/sub/sub /" <tree >tree.new &&
	tree=$(shit -C super mktree <tree.new) &&
	commit=$(echo with space | shit -C super commit-tree $tree) &&
	shit -C super update-ref refs/heads/main $commit &&

	test_must_fail shit clone --recurse-submodules super dst 2>err &&
	test_grep "sub " err
'

test_done
