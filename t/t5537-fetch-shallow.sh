#!/bin/sh

test_description='fetch/clone from a shallow clone'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

commit() {
	echo "$1" >tracked &&
	shit add tracked &&
	shit commit -m "$1"
}

test_expect_success 'setup' '
	commit 1 &&
	commit 2 &&
	commit 3 &&
	commit 4 &&
	shit config --global transfer.fsckObjects true &&
	test_oid_cache <<-\EOF
	perl sha1:s/0034shallow %s/0036unshallow %s/
	perl sha256:s/004cshallow %s/004eunshallow %s/
	EOF
'

test_expect_success 'setup shallow clone' '
	shit clone --no-local --depth=2 .shit shallow &&
	shit --shit-dir=shallow/.shit log --format=%s >actual &&
	test_write_lines 4 3 >expect &&
	test_cmp expect actual
'

test_expect_success 'clone from shallow clone' '
	shit clone --no-local shallow shallow2 &&
	(
	cd shallow2 &&
	shit fsck &&
	shit log --format=%s >actual &&
	test_write_lines 4 3 >expect &&
	test_cmp expect actual
	)
'

test_expect_success 'fetch from shallow clone' '
	(
	cd shallow &&
	commit 5
	) &&
	(
	cd shallow2 &&
	shit fetch &&
	shit fsck &&
	shit log --format=%s origin/main >actual &&
	test_write_lines 5 4 3 >expect &&
	test_cmp expect actual
	)
'

test_expect_success 'fetch --depth from shallow clone' '
	(
	cd shallow &&
	commit 6
	) &&
	(
	cd shallow2 &&
	shit fetch --depth=2 &&
	shit fsck &&
	shit log --format=%s origin/main >actual &&
	test_write_lines 6 5 >expect &&
	test_cmp expect actual
	)
'

test_expect_success 'fetch --unshallow from shallow clone' '
	(
	cd shallow2 &&
	shit fetch --unshallow &&
	shit fsck &&
	shit log --format=%s origin/main >actual &&
	test_write_lines 6 5 4 3 >expect &&
	test_cmp expect actual
	)
'

test_expect_success 'fetch --unshallow from a full clone' '
	shit clone --no-local --depth=2 .shit shallow3 &&
	(
	cd shallow3 &&
	shit log --format=%s >actual &&
	test_write_lines 4 3 >expect &&
	test_cmp expect actual &&
	shit -c fetch.writeCommitGraph fetch --unshallow &&
	shit log origin/main --format=%s >actual &&
	test_write_lines 4 3 2 1 >expect &&
	test_cmp expect actual
	)
'

test_expect_success 'fetch something upstream has but hidden by clients shallow boundaries' '
	# the blob "1" is available in .shit but hidden by the
	# shallow2/.shit/shallow and it should be resent
	! shit --shit-dir=shallow2/.shit cat-file blob $(echo 1|shit hash-object --stdin) >/dev/null &&
	echo 1 >1.t &&
	shit add 1.t &&
	shit commit -m add-1-back &&
	(
	cd shallow2 &&
	shit fetch ../.shit +refs/heads/main:refs/remotes/top/main &&
	shit fsck &&
	shit log --format=%s top/main >actual &&
	test_write_lines add-1-back 4 3 >expect &&
	test_cmp expect actual
	) &&
	shit --shit-dir=shallow2/.shit cat-file blob $(echo 1|shit hash-object --stdin) >/dev/null
'

test_expect_success 'fetch that requires changes in .shit/shallow is filtered' '
	(
	cd shallow &&
	shit checkout --orphan no-shallow &&
	commit no-shallow
	) &&
	shit init notshallow &&
	(
	cd notshallow &&
	shit fetch ../shallow/.shit refs/heads/*:refs/remotes/shallow/* &&
	shit for-each-ref --format="%(refname)" >actual.refs &&
	echo refs/remotes/shallow/no-shallow >expect.refs &&
	test_cmp expect.refs actual.refs &&
	shit log --format=%s shallow/no-shallow >actual &&
	echo no-shallow >expect &&
	test_cmp expect actual
	)
'

test_expect_success 'fetch --update-shallow' '
	(
	cd shallow &&
	shit checkout main &&
	commit 7 &&
	shit tag -m foo heavy-tag HEAD^ &&
	shit tag light-tag HEAD^:tracked
	) &&
	(
	cd notshallow &&
	shit fetch --update-shallow ../shallow/.shit refs/heads/*:refs/remotes/shallow/* &&
	shit fsck &&
	shit for-each-ref --sort=refname --format="%(refname)" >actual.refs &&
	cat <<-\EOF >expect.refs &&
	refs/remotes/shallow/main
	refs/remotes/shallow/no-shallow
	refs/tags/heavy-tag
	refs/tags/light-tag
	EOF
	test_cmp expect.refs actual.refs &&
	shit log --format=%s shallow/main >actual &&
	test_write_lines 7 6 5 4 3 >expect &&
	test_cmp expect actual
	)
'

test_expect_success 'fetch --update-shallow into a repo with submodules' '
	test_config_global protocol.file.allow always &&

	shit init a-submodule &&
	test_commit -C a-submodule foo &&

	test_when_finished "rm -rf repo-with-sub" &&
	shit init repo-with-sub &&
	shit -C repo-with-sub submodule add ../a-submodule a-submodule &&
	shit -C repo-with-sub commit -m "added submodule" &&
	shit -C repo-with-sub fetch --update-shallow ../shallow/.shit refs/heads/*:refs/remotes/shallow/*
'

test_expect_success 'fetch --update-shallow a commit that is also a shallow point into a repo with submodules' '
	test_when_finished "rm -rf repo-with-sub" &&
	shit init repo-with-sub &&
	shit -c protocol.file.allow=always -C repo-with-sub \
		submodule add ../a-submodule a-submodule &&
	shit -C repo-with-sub commit -m "added submodule" &&

	SHALLOW=$(cat shallow/.shit/shallow) &&
	shit -C repo-with-sub fetch --update-shallow ../shallow/.shit "$SHALLOW":refs/heads/a-shallow
'

test_expect_success 'fetch --update-shallow (with fetch.writeCommitGraph)' '
	(
	cd shallow &&
	shit checkout main &&
	commit 8 &&
	shit tag -m foo heavy-tag-for-graph HEAD^ &&
	shit tag light-tag-for-graph HEAD^:tracked
	) &&
	test_config -C notshallow fetch.writeCommitGraph true &&
	(
	cd notshallow &&
	shit fetch --update-shallow ../shallow/.shit refs/heads/*:refs/remotes/shallow/* &&
	shit fsck &&
	shit for-each-ref --sort=refname --format="%(refname)" >actual.refs &&
	cat <<-EOF >expect.refs &&
	refs/remotes/shallow/main
	refs/remotes/shallow/no-shallow
	refs/tags/heavy-tag
	refs/tags/heavy-tag-for-graph
	refs/tags/light-tag
	refs/tags/light-tag-for-graph
	EOF
	test_cmp expect.refs actual.refs &&
	shit log --format=%s shallow/main >actual &&
	test_write_lines 8 7 6 5 4 3 >expect &&
	test_cmp expect actual
	)
'

test_expect_success POSIXPERM,SANITY 'shallow fetch from a read-only repo' '
	cp -R .shit read-only.shit &&
	test_when_finished "find read-only.shit -type d -print | xargs chmod +w" &&
	find read-only.shit -print | xargs chmod -w &&
	shit clone --no-local --depth=2 read-only.shit from-read-only &&
	shit --shit-dir=from-read-only/.shit log --format=%s >actual &&
	test_write_lines add-1-back 4 >expect &&
	test_cmp expect actual
'

test_expect_success '.shit/shallow is edited by repack' '
	shit init shallow-server &&
	test_commit -C shallow-server A &&
	test_commit -C shallow-server B &&
	shit -C shallow-server checkout -b branch &&
	test_commit -C shallow-server C &&
	test_commit -C shallow-server E &&
	test_commit -C shallow-server D &&
	d="$(shit -C shallow-server rev-parse --verify D^0)" &&
	shit -C shallow-server checkout main &&

	shit clone --depth=1 --no-tags --no-single-branch \
		"file://$PWD/shallow-server" shallow-client &&

	: now remove the branch and fetch with prune &&
	shit -C shallow-server branch -D branch &&
	shit -C shallow-client fetch --prune --depth=1 \
		origin "+refs/heads/*:refs/remotes/origin/*" &&
	shit -C shallow-client repack -adfl &&
	test_must_fail shit -C shallow-client rev-parse --verify $d^0 &&
	! grep $d shallow-client/.shit/shallow &&

	shit -C shallow-server branch branch-orig $d &&
	shit -C shallow-client fetch --prune --depth=2 \
		origin "+refs/heads/*:refs/remotes/origin/*"
'

. "$TEST_DIRECTORY"/lib-httpd.sh
start_httpd

REPO="$HTTPD_DOCUMENT_ROOT_PATH/repo"

test_expect_success 'shallow fetches check connectivity before writing shallow file' '
	rm -rf "$REPO" client &&

	shit init "$REPO" &&
	test_commit -C "$REPO" one &&
	test_commit -C "$REPO" two &&
	test_commit -C "$REPO" three &&

	shit init client &&

	# Use protocol v2 to ensure that shallow information is sent exactly
	# once by the server, since we are planning to manipulate it.
	shit -C "$REPO" config protocol.version 2 &&
	shit -C client config protocol.version 2 &&

	shit -C client fetch --depth=2 "$HTTPD_URL/one_time_perl/repo" main:a_branch &&

	# Craft a situation in which the server sends back an unshallow request
	# with an empty packfile. This is done by refetching with a shorter
	# depth (to ensure that the packfile is empty), and overwriting the
	# shallow line in the response with the unshallow line we want.
	printf "$(test_oid perl)" \
	       "$(shit -C "$REPO" rev-parse HEAD)" \
	       "$(shit -C "$REPO" rev-parse HEAD^)" \
	       >"$HTTPD_ROOT_PATH/one-time-perl" &&
	test_must_fail env shit_TEST_SIDEBAND_ALL=0 shit -C client \
		fetch --depth=1 "$HTTPD_URL/one_time_perl/repo" \
		main:a_branch &&

	# Ensure that the one-time-perl script was used.
	! test -e "$HTTPD_ROOT_PATH/one-time-perl" &&

	# Ensure that the resulting repo is consistent, despite our failure to
	# fetch.
	shit -C client fsck
'

# DO NOT add non-httpd-specific tests here, because the last part of this
# test script is only executed when httpd is available and enabled.

test_done
