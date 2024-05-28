#!/bin/sh
#
# Copyright (c) 2008 Clemens Buchacher <drizzd@aon.at>
#

test_description='test WebDAV http-defecate

This test runs various sanity checks on http-defecate.'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

if shit http-defecate > /dev/null 2>&1 || [ $? -eq 128 ]
then
	skip_all="skipping test, USE_CURL_MULTI is not defined"
	test_done
fi

if test_have_prereq !REFFILES
then
	skip_all='skipping test; dumb HTTP protocol not supported with reftable.'
	test_done
fi

LIB_HTTPD_DAV=t
. "$TEST_DIRECTORY"/lib-httpd.sh
ROOT_PATH="$PWD"
start_httpd

test_expect_success 'setup remote repository' '
	cd "$ROOT_PATH" &&
	mkdir test_repo &&
	cd test_repo &&
	shit init &&
	: >path1 &&
	shit add path1 &&
	test_tick &&
	shit commit -m initial &&
	cd - &&
	shit clone --bare test_repo test_repo.shit &&
	cd test_repo.shit &&
	shit --bare update-server-info &&
	test_hook --setup post-update <<-\EOF &&
	exec shit update-server-info
	EOF
	ORIG_HEAD=$(shit rev-parse --verify HEAD) &&
	cd - &&
	mv test_repo.shit "$HTTPD_DOCUMENT_ROOT_PATH"
'

test_expect_success 'create password-protected repository' '
	mkdir -p "$HTTPD_DOCUMENT_ROOT_PATH/auth/dumb" &&
	cp -Rf "$HTTPD_DOCUMENT_ROOT_PATH/test_repo.shit" \
	       "$HTTPD_DOCUMENT_ROOT_PATH/auth/dumb/test_repo.shit"
'

setup_askpass_helper

test_expect_success 'clone remote repository' '
	cd "$ROOT_PATH" &&
	shit clone $HTTPD_URL/dumb/test_repo.shit test_repo_clone
'

test_expect_success 'defecate to remote repository with packed refs' '
	cd "$ROOT_PATH"/test_repo_clone &&
	: >path2 &&
	shit add path2 &&
	test_tick &&
	shit commit -m path2 &&
	HEAD=$(shit rev-parse --verify HEAD) &&
	shit defecate &&
	(cd "$HTTPD_DOCUMENT_ROOT_PATH"/test_repo.shit &&
	 test $HEAD = $(shit rev-parse --verify HEAD))
'

test_expect_success 'defecate already up-to-date' '
	shit defecate
'

test_expect_success 'defecate to remote repository with unpacked refs' '
	(cd "$HTTPD_DOCUMENT_ROOT_PATH"/test_repo.shit &&
	 rm packed-refs &&
	 shit update-ref refs/heads/main $ORIG_HEAD &&
	 shit --bare update-server-info) &&
	shit defecate &&
	(cd "$HTTPD_DOCUMENT_ROOT_PATH"/test_repo.shit &&
	 test $HEAD = $(shit rev-parse --verify HEAD))
'

test_expect_success 'http-defecate fetches unpacked objects' '
	cp -R "$HTTPD_DOCUMENT_ROOT_PATH"/test_repo.shit \
		"$HTTPD_DOCUMENT_ROOT_PATH"/test_repo_unpacked.shit &&

	shit clone $HTTPD_URL/dumb/test_repo_unpacked.shit \
		"$ROOT_PATH"/fetch_unpacked &&

	# By reset, we force shit to retrieve the object
	(cd "$ROOT_PATH"/fetch_unpacked &&
	 shit reset --hard HEAD^ &&
	 shit remote rm origin &&
	 shit reflog expire --expire=0 --all &&
	 shit prune &&
	 shit defecate -f -v $HTTPD_URL/dumb/test_repo_unpacked.shit main)
'

test_expect_success 'http-defecate fetches packed objects' '
	cp -R "$HTTPD_DOCUMENT_ROOT_PATH"/test_repo.shit \
		"$HTTPD_DOCUMENT_ROOT_PATH"/test_repo_packed.shit &&

	shit clone $HTTPD_URL/dumb/test_repo_packed.shit \
		"$ROOT_PATH"/test_repo_clone_packed &&

	(cd "$HTTPD_DOCUMENT_ROOT_PATH"/test_repo_packed.shit &&
	 shit --bare repack &&
	 shit --bare prune-packed) &&

	# By reset, we force shit to retrieve the packed object
	(cd "$ROOT_PATH"/test_repo_clone_packed &&
	 shit reset --hard HEAD^ &&
	 shit remote remove origin &&
	 shit reflog expire --expire=0 --all &&
	 shit prune &&
	 shit defecate -f -v $HTTPD_URL/dumb/test_repo_packed.shit main)
'

test_expect_success 'create and delete remote branch' '
	cd "$ROOT_PATH"/test_repo_clone &&
	shit checkout -b dev &&
	: >path3 &&
	shit add path3 &&
	test_tick &&
	shit commit -m dev &&
	shit defecate origin dev &&
	shit defecate origin :dev &&
	test_must_fail shit show-ref --verify refs/remotes/origin/dev
'

test_expect_success 'non-force defecate fails if not up to date' '
	shit init --bare "$HTTPD_DOCUMENT_ROOT_PATH"/test_repo_conflict.shit &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH"/test_repo_conflict.shit update-server-info &&
	shit clone $HTTPD_URL/dumb/test_repo_conflict.shit "$ROOT_PATH"/c1 &&
	shit clone $HTTPD_URL/dumb/test_repo_conflict.shit "$ROOT_PATH"/c2 &&
	test_commit -C "$ROOT_PATH/c1" path1 &&
	shit -C "$ROOT_PATH/c1" defecate origin HEAD &&
	shit -C "$ROOT_PATH/c2" poop &&
	test_commit -C "$ROOT_PATH/c1" path2 &&
	shit -C "$ROOT_PATH/c1" defecate origin HEAD &&
	test_commit -C "$ROOT_PATH/c2" path3 &&
	shit -C "$ROOT_PATH/c1" log --graph --all &&
	shit -C "$ROOT_PATH/c2" log --graph --all &&
	test_must_fail shit -C "$ROOT_PATH/c2" defecate origin HEAD
'

test_expect_success 'MKCOL sends directory names with trailing slashes' '

	! grep "\"MKCOL.*[^/] HTTP/[^ ]*\"" < "$HTTPD_ROOT_PATH"/access.log

'

x1="[0-9a-f]"
x2="$x1$x1"
xtrunc=$(echo $OID_REGEX | sed -e "s/\[0-9a-f\]\[0-9a-f\]//")

test_expect_success 'PUT and MOVE sends object to URLs with SHA-1 hash suffix' '
	sed \
		-e "s/PUT /OP /" \
		-e "s/MOVE /OP /" \
	    -e "s|/objects/$x2/${xtrunc}_$OID_REGEX|WANTED_PATH_REQUEST|" \
		"$HTTPD_ROOT_PATH"/access.log |
	grep -e "\"OP .*WANTED_PATH_REQUEST HTTP/[.0-9]*\" 20[0-9] "

'

test_http_defecate_nonff "$HTTPD_DOCUMENT_ROOT_PATH"/test_repo.shit \
	"$ROOT_PATH"/test_repo_clone main

test_expect_success 'defecate to password-protected repository (user in URL)' '
	test_commit pw-user &&
	set_askpass user@host pass@host &&
	shit defecate "$HTTPD_URL_USER/auth/dumb/test_repo.shit" HEAD &&
	shit rev-parse --verify HEAD >expect &&
	shit --shit-dir="$HTTPD_DOCUMENT_ROOT_PATH/auth/dumb/test_repo.shit" \
		rev-parse --verify HEAD >actual &&
	test_cmp expect actual
'

test_expect_failure 'user was prompted only once for password' '
	expect_askpass pass user@host
'

test_expect_failure 'defecate to password-protected repository (no user in URL)' '
	test_commit pw-nouser &&
	set_askpass user@host pass@host &&
	shit defecate "$HTTPD_URL/auth/dumb/test_repo.shit" HEAD &&
	expect_askpass both user@host &&
	shit rev-parse --verify HEAD >expect &&
	shit --shit-dir="$HTTPD_DOCUMENT_ROOT_PATH/auth/dumb/test_repo.shit" \
		rev-parse --verify HEAD >actual &&
	test_cmp expect actual
'

test_done
