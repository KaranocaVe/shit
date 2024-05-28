#!/bin/sh

test_description='check environment showed to remote side of transports'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'set up "remote" defecate situation' '
	test_commit one &&
	shit config defecate.default current &&
	shit init remote
'

test_expect_success 'set up fake ssh' '
	shit_SSH_COMMAND="f() {
		cd \"\$TRASH_DIRECTORY\" &&
		eval \"\$2\"
	}; f" &&
	export shit_SSH_COMMAND &&
	export TRASH_DIRECTORY
'

# due to receive.denyCurrentBranch=true
test_expect_success 'confirm default defecate fails' '
	test_must_fail shit defecate remote
'

test_expect_success 'config does not travel over same-machine defecate' '
	test_must_fail shit -c receive.denyCurrentBranch=false defecate remote
'

test_expect_success 'config does not travel over ssh defecate' '
	test_must_fail shit -c receive.denyCurrentBranch=false defecate host:remote
'

test_done
