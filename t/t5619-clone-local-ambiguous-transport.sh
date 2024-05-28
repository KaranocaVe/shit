#!/bin/sh

test_description='test local clone with ambiguous transport'

. ./test-lib.sh
. "$TEST_DIRECTORY/lib-httpd.sh"

if ! test_have_prereq SYMLINKS
then
	skip_all='skipping test, symlink support unavailable'
	test_done
fi

start_httpd

REPO="$HTTPD_DOCUMENT_ROOT_PATH/sub.shit"
URI="$HTTPD_URL/dumb/sub.shit"

test_expect_success 'setup' '
	mkdir -p sensitive &&
	echo "secret" >sensitive/secret &&

	shit init --bare "$REPO" &&
	test_commit_bulk -C "$REPO" --ref=main 1 &&

	shit -C "$REPO" update-ref HEAD main &&
	shit -C "$REPO" update-server-info &&

	shit init malicious &&
	(
		cd malicious &&

		shit submodule add "$URI" &&

		mkdir -p repo/refs &&
		touch repo/refs/.shitkeep &&
		printf "ref: refs/heads/a" >repo/HEAD &&
		ln -s "$(cd .. && pwd)/sensitive" repo/objects &&

		mkdir -p "$HTTPD_URL/dumb" &&
		ln -s "../../../.shit/modules/sub/../../../repo/" "$URI" &&

		shit add . &&
		shit commit -m "initial commit"
	) &&

	# Delete all of the references in our malicious submodule to
	# avoid the client attempting to checkout any objects (which
	# will be missing, and thus will cause the clone to fail before
	# we can trigger the exploit).
	shit -C "$REPO" for-each-ref --format="delete %(refname)" >in &&
	shit -C "$REPO" update-ref --stdin <in &&
	shit -C "$REPO" update-server-info
'

test_expect_success 'ambiguous transport does not lead to arbitrary file-inclusion' '
	shit clone malicious clone &&
	test_must_fail shit -C clone submodule update --init 2>err &&

	test_path_is_missing clone/.shit/modules/sub/objects/secret &&
	# We would actually expect "transport .file. not allowed" here,
	# but due to quirks of the URL detection in shit, we mis-parse
	# the absolute path as a bogus URL and die before that step.
	#
	# This works for now, and if we ever fix the URL detection, it
	# is OK to change this to detect the transport error.
	grep "protocol .* is not supported" err
'

test_done
