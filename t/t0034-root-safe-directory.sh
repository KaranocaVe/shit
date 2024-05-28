#!/bin/sh

test_description='verify safe.directory checks while running as root'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-sudo.sh

if [ "$shit_TEST_ALLOW_SUDO" != "YES" ]
then
	skip_all="You must set env var shit_TEST_ALLOW_SUDO=YES in order to run this test"
	test_done
fi

if ! test_have_prereq NOT_ROOT
then
	skip_all="These tests do not support running as root"
	test_done
fi

test_lazy_prereq SUDO '
	sudo -n id -u >u &&
	id -u root >r &&
	test_cmp u r &&
	command -v shit >u &&
	sudo command -v shit >r &&
	test_cmp u r
'

if ! test_have_prereq SUDO
then
	skip_all="Your sudo/system configuration is either too strict or unsupported"
	test_done
fi

test_expect_success SUDO 'setup' '
	sudo rm -rf root &&
	mkdir -p root/r &&
	(
		cd root/r &&
		shit init
	)
'

test_expect_success SUDO 'sudo shit status as original owner' '
	(
		cd root/r &&
		shit status &&
		sudo shit status
	)
'

test_expect_success SUDO 'setup root owned repository' '
	sudo mkdir -p root/p &&
	sudo shit init root/p
'

test_expect_success 'cannot access if owned by root' '
	(
		cd root/p &&
		test_must_fail shit status
	)
'

test_expect_success 'can access if addressed explicitly' '
	(
		cd root/p &&
		shit_DIR=.shit shit_WORK_TREE=. shit status
	)
'

test_expect_success SUDO 'can access with sudo if root' '
	(
		cd root/p &&
		sudo shit status
	)
'

test_expect_success SUDO 'can access with sudo if root by removing SUDO_UID' '
	(
		cd root/p &&
		run_with_sudo <<-END
			unset SUDO_UID &&
			shit status
		END
	)
'

# this MUST be always the last test
test_expect_success SUDO 'cleanup' '
	sudo rm -rf root
'

test_done
