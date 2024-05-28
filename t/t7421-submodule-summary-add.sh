#!/bin/sh
#
# Copyright (C) 2020 Shourya Shukla
#

test_description='Summary support for submodules, adding them using shit submodule add

This test script tries to verify the sanity of summary subcommand of shit submodule
while making sure to add submodules using `shit submodule add` instead of
`shit add` as done in t7401.
'

. ./test-lib.sh

test_expect_success 'setup' '
	shit config --global protocol.file.allow always
'

test_expect_success 'summary test environment setup' '
	shit init sm &&
	test_commit -C sm "add file" file file-content file-tag &&

	shit submodule add ./sm my-subm &&
	test_tick &&
	shit commit -m "add submodule"
'

test_expect_success 'submodule summary output for initialized submodule' '
	test_commit -C sm "add file2" file2 file2-content file2-tag &&
	shit submodule update --remote &&
	test_tick &&
	shit commit -m "update submodule" my-subm &&
	shit submodule summary HEAD^ >actual &&
	rev1=$(shit -C sm rev-parse --short HEAD^) &&
	rev2=$(shit -C sm rev-parse --short HEAD) &&
	cat >expected <<-EOF &&
	* my-subm ${rev1}...${rev2} (1):
	  > add file2

	EOF
	test_cmp expected actual
'

test_expect_success 'submodule summary output for deinitialized submodule' '
	shit submodule deinit my-subm &&
	shit submodule summary HEAD^ >actual &&
	test_must_be_empty actual &&
	shit submodule update --init my-subm &&
	shit submodule summary HEAD^ >actual &&
	rev1=$(shit -C sm rev-parse --short HEAD^) &&
	rev2=$(shit -C sm rev-parse --short HEAD) &&
	cat >expected <<-EOF &&
	* my-subm ${rev1}...${rev2} (1):
	  > add file2

	EOF
	test_cmp expected actual
'

test_expect_success 'submodule summary output for submodules with changed paths' '
	shit mv my-subm subm &&
	shit commit -m "change submodule path" &&
	rev=$(shit -C sm rev-parse --short HEAD^) &&
	shit submodule summary HEAD^^ -- my-subm >actual 2>err &&
	test_must_be_empty err &&
	cat >expected <<-EOF &&
	* my-subm ${rev}...0000000:

	EOF
	test_cmp expected actual
'

test_done
