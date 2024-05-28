#!/bin/sh

test_description='test protocol filtering with submodules'
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-proto-disable.sh

setup_ext_wrapper
setup_ssh_wrapper

test_expect_success 'setup repository with submodules' '
	mkdir remote &&
	shit init remote/repo.shit &&
	(cd remote/repo.shit && test_commit one) &&
	# submodule-add should probably trust what we feed it on the cmdline,
	# but its implementation is overly conservative.
	shit_ALLOW_PROTOCOL=ssh shit submodule add remote:repo.shit ssh-module &&
	shit_ALLOW_PROTOCOL=ext shit submodule add "ext::fake-remote %S repo.shit" ext-module &&
	shit commit -m "add submodules"
'

test_expect_success 'clone with recurse-submodules fails' '
	test_must_fail shit clone --recurse-submodules . dst
'

test_expect_success 'setup individual updates' '
	rm -rf dst &&
	shit clone . dst &&
	shit -C dst submodule init
'

test_expect_success 'update of ssh allowed' '
	shit -C dst submodule update ssh-module
'

test_expect_success 'update of ext not allowed' '
	test_must_fail shit -C dst submodule update ext-module
'

test_expect_success 'user can filter protocols with shit_ALLOW_PROTOCOL' '
	shit_ALLOW_PROTOCOL=ext shit -C dst submodule update ext-module
'

test_done
