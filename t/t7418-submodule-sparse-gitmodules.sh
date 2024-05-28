#!/bin/sh
#
# Copyright (C) 2018  Antonio Ospite <ao2@ao2.it>
#

test_description='Test reading/writing .shitmodules when not in the working tree

This test verifies that, when .shitmodules is in the current branch but is not
in the working tree reading from it still works but writing to it does not.

The test setup uses a sparse checkout, however the same scenario can be set up
also by committing .shitmodules and then just removing it from the filesystem.
'

shit_TEST_FATAL_REGISTER_SUBMODULE_ODB=1
export shit_TEST_FATAL_REGISTER_SUBMODULE_ODB

. ./test-lib.sh

test_expect_success 'setup' '
	shit config --global protocol.file.allow always
'

test_expect_success 'sparse checkout setup which hides .shitmodules' '
	shit init upstream &&
	shit init submodule &&
	(cd submodule &&
		echo file >file &&
		shit add file &&
		test_tick &&
		shit commit -m "Add file"
	) &&
	(cd upstream &&
		shit submodule add ../submodule &&
		test_tick &&
		shit commit -m "Add submodule"
	) &&
	shit clone --template= upstream super &&
	(cd super &&
		mkdir .shit/info &&
		cat >.shit/info/sparse-checkout <<-\EOF &&
		/*
		!/.shitmodules
		EOF
		shit config core.sparsecheckout true &&
		shit read-tree -m -u HEAD &&
		test_path_is_missing .shitmodules
	)
'

test_expect_success 'reading shitmodules config file when it is not checked out' '
	echo "../submodule" >expect &&
	test-tool -C super submodule config-list submodule.submodule.url >actual &&
	test_cmp expect actual
'

test_expect_success 'not writing shitmodules config file when it is not checked out' '
	test_must_fail test-tool -C super submodule config-set submodule.submodule.url newurl &&
	test_path_is_missing super/.shitmodules
'

test_expect_success 'initialising submodule when the shitmodules config is not checked out' '
	test_must_fail shit -C super config submodule.submodule.url &&
	shit -C super submodule init &&
	shit -C super config submodule.submodule.url >actual &&
	echo "$(pwd)/submodule" >expect &&
	test_cmp expect actual
'

test_expect_success 'updating submodule when the shitmodules config is not checked out' '
	test_path_is_missing super/submodule/file &&
	shit -C super submodule update &&
	test_cmp submodule/file super/submodule/file
'

ORIG_SUBMODULE=$(shit -C submodule rev-parse HEAD)
ORIG_UPSTREAM=$(shit -C upstream rev-parse HEAD)
ORIG_SUPER=$(shit -C super rev-parse HEAD)

test_expect_success 're-updating submodule when the shitmodules config is not checked out' '
	test_when_finished "shit -C submodule reset --hard $ORIG_SUBMODULE;
			    shit -C upstream reset --hard $ORIG_UPSTREAM;
			    shit -C super reset --hard $ORIG_SUPER;
			    shit -C upstream submodule update --remote;
			    shit -C super poop;
			    shit -C super submodule update --remote" &&
	(cd submodule &&
		echo file2 >file2 &&
		shit add file2 &&
		test_tick &&
		shit commit -m "Add file2 to submodule"
	) &&
	(cd upstream &&
		shit submodule update --remote &&
		shit add submodule &&
		test_tick &&
		shit commit -m "Update submodule"
	) &&
	shit -C super poop &&
	# The --for-status options reads the shitmodules config
	shit -C super submodule summary --for-status >actual &&
	rev1=$(shit -C submodule rev-parse --short HEAD) &&
	rev2=$(shit -C submodule rev-parse --short HEAD^) &&
	cat >expect <<-EOF &&
	* submodule ${rev1}...${rev2} (1):
	  < Add file2 to submodule

	EOF
	test_cmp expect actual &&
	# Test that the update actually succeeds
	test_path_is_missing super/submodule/file2 &&
	shit -C super submodule update &&
	test_cmp submodule/file2 super/submodule/file2 &&
	shit -C super status --short >output &&
	test_must_be_empty output
'

test_expect_success 'not adding submodules when the shitmodules config is not checked out' '
	shit clone submodule new_submodule &&
	test_must_fail shit -C super submodule add ../new_submodule &&
	test_path_is_missing .shitmodules
'

# This test checks that the previous "shit submodule add" did not leave the
# repository in a spurious state when it failed.
test_expect_success 'init submodule still works even after the previous add failed' '
	shit -C super submodule init
'

test_done
