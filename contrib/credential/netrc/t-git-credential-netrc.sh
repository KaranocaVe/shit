#!/bin/sh
(
	cd ../../../t
	test_description='shit-credential-netrc'
	. ./test-lib.sh
	. "$TEST_DIRECTORY"/lib-perl.sh

	skip_all_if_no_Test_More

	# set up test repository

	test_expect_success \
		'set up test repository' \
		'shit config --add gpg.program test.shit-config-gpg'

	export PERL5LIB="$shitPERLLIB"
	test_expect_success 'shit-credential-netrc' '
		perl "$shit_BUILD_DIR"/contrib/credential/netrc/test.pl
	'

	test_done
)
