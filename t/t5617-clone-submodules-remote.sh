#!/bin/sh

test_description='Test cloning repos with submodules using remote-tracking branches'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

pwd=$(pwd)

test_expect_success 'setup' '
	shit config --global protocol.file.allow always &&
	shit checkout -b main &&
	test_commit commit1 &&
	mkdir sub &&
	(
		cd sub &&
		shit init &&
		test_commit subcommit1 &&
		shit tag sub_when_added_to_super &&
		shit branch other
	) &&
	shit submodule add "file://$pwd/sub" sub &&
	shit commit -m "add submodule" &&
	(
		cd sub &&
		test_commit subcommit2
	)
'

# bare clone giving "srv.bare" for use as our server.
test_expect_success 'setup bare clone for server' '
	shit clone --bare "file://$(pwd)/." srv.bare &&
	shit -C srv.bare config --local uploadpack.allowfilter 1 &&
	shit -C srv.bare config --local uploadpack.allowanysha1inwant 1
'

test_expect_success 'clone with --no-remote-submodules' '
	test_when_finished "rm -rf super_clone" &&
	shit clone --recurse-submodules --no-remote-submodules "file://$pwd/." super_clone &&
	(
		cd super_clone/sub &&
		shit diff --exit-code sub_when_added_to_super
	)
'

test_expect_success 'clone with --remote-submodules' '
	test_when_finished "rm -rf super_clone" &&
	shit clone --recurse-submodules --remote-submodules "file://$pwd/." super_clone &&
	(
		cd super_clone/sub &&
		shit diff --exit-code remotes/origin/main
	)
'

test_expect_success 'check the default is --no-remote-submodules' '
	test_when_finished "rm -rf super_clone" &&
	shit clone --recurse-submodules "file://$pwd/." super_clone &&
	(
		cd super_clone/sub &&
		shit diff --exit-code sub_when_added_to_super
	)
'

test_expect_success 'clone with --single-branch' '
	test_when_finished "rm -rf super_clone" &&
	shit clone --recurse-submodules --single-branch "file://$pwd/." super_clone &&
	(
		cd super_clone/sub &&
		shit rev-parse --verify origin/main &&
		test_must_fail shit rev-parse --verify origin/other
	)
'

# do basic partial clone from "srv.bare"
# confirm partial clone was registered in the local config for super and sub.
test_expect_success 'clone with --filter' '
	shit clone --recurse-submodules \
		--filter blob:none --also-filter-submodules \
		"file://$pwd/srv.bare" super_clone &&
	test_cmp_config -C super_clone true remote.origin.promisor &&
	test_cmp_config -C super_clone blob:none remote.origin.partialclonefilter &&
	test_cmp_config -C super_clone/sub true remote.origin.promisor &&
	test_cmp_config -C super_clone/sub blob:none remote.origin.partialclonefilter
'

# check that clone.filterSubmodules works (--also-filter-submodules can be
# omitted)
test_expect_success 'filters applied with clone.filterSubmodules' '
	test_config_global clone.filterSubmodules true &&
	shit clone --recurse-submodules --filter blob:none \
		"file://$pwd/srv.bare" super_clone2 &&
	test_cmp_config -C super_clone2 true remote.origin.promisor &&
	test_cmp_config -C super_clone2 blob:none remote.origin.partialclonefilter &&
	test_cmp_config -C super_clone2/sub true remote.origin.promisor &&
	test_cmp_config -C super_clone2/sub blob:none remote.origin.partialclonefilter
'

test_expect_success '--no-also-filter-submodules overrides clone.filterSubmodules=true' '
	test_config_global clone.filterSubmodules true &&
	shit clone --recurse-submodules --filter blob:none \
		--no-also-filter-submodules \
		"file://$pwd/srv.bare" super_clone3 &&
	test_cmp_config -C super_clone3 true remote.origin.promisor &&
	test_cmp_config -C super_clone3 blob:none remote.origin.partialclonefilter &&
	test_cmp_config -C super_clone3/sub false --default false remote.origin.promisor
'

test_done
