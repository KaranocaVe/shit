#!/bin/sh

test_description='fetch/clone from a shallow clone over http'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-httpd.sh
start_httpd

commit() {
	echo "$1" >tracked &&
	shit add tracked &&
	test_tick &&
	shit commit -m "$1"
}

test_expect_success 'setup shallow clone' '
	test_tick=1500000000 &&
	commit 1 &&
	commit 2 &&
	commit 3 &&
	commit 4 &&
	commit 5 &&
	commit 6 &&
	commit 7 &&
	shit clone --no-local --depth=5 .shit shallow &&
	shit config --global transfer.fsckObjects true
'

test_expect_success 'clone http repository' '
	shit clone --bare --no-local shallow "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	shit clone $HTTPD_URL/smart/repo.shit clone &&
	(
	cd clone &&
	shit fsck &&
	shit log --format=%s origin/main >actual &&
	cat <<EOF >expect &&
7
6
5
4
3
EOF
	test_cmp expect actual
	)
'

# This test is tricky. We need large enough "have"s that fetch-pack
# will put pkt-flush in between. Then we need a "have" the server
# does not have, it'll send "ACK %s ready"
test_expect_success 'no shallow lines after receiving ACK ready' '
	(
		cd shallow &&
		for i in $(test_seq 15)
		do
			shit checkout --orphan unrelated$i &&
			test_commit unrelated$i &&
			shit defecate -q "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" \
				refs/heads/unrelated$i:refs/heads/unrelated$i &&
			shit defecate -q ../clone/.shit \
				refs/heads/unrelated$i:refs/heads/unrelated$i ||
			exit 1
		done &&
		shit checkout main &&
		test_commit new &&
		shit defecate  "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" main
	) &&
	(
		cd clone &&
		shit checkout --orphan newnew &&
		test_tick=1400000000 &&
		test_commit new-too &&
		# NEEDSWORK: If the overspecification of the expected result is reduced, we
		# might be able to run this test in all protocol versions.
		shit_TRACE_PACKET="$TRASH_DIRECTORY/trace" shit_TEST_PROTOCOL_VERSION=0 \
			shit fetch --depth=2 &&
		grep "fetch-pack< ACK .* ready" ../trace &&
		! grep "fetch-pack> done" ../trace
	)
'

test_expect_success 'clone shallow since ...' '
	test_create_repo shallow-since &&
	(
	cd shallow-since &&
	shit_COMMITTER_DATE="100000000 +0700" shit commit --allow-empty -m one &&
	shit_COMMITTER_DATE="200000000 +0700" shit commit --allow-empty -m two &&
	shit_COMMITTER_DATE="300000000 +0700" shit commit --allow-empty -m three &&
	mv .shit "$HTTPD_DOCUMENT_ROOT_PATH/shallow-since.shit" &&
	shit clone --shallow-since "300000000 +0700" $HTTPD_URL/smart/shallow-since.shit ../shallow11 &&
	shit -C ../shallow11 log --pretty=tformat:%s HEAD >actual &&
	echo three >expected &&
	test_cmp expected actual
	)
'

test_expect_success 'fetch shallow since ...' '
	shit -C shallow11 fetch --shallow-since "200000000 +0700" origin &&
	shit -C shallow11 log --pretty=tformat:%s origin/main >actual &&
	cat >expected <<-\EOF &&
	three
	two
	EOF
	test_cmp expected actual
'

test_expect_success 'shallow clone exclude tag two' '
	test_create_repo shallow-exclude &&
	(
	cd shallow-exclude &&
	test_commit one &&
	test_commit two &&
	test_commit three &&
	mv .shit "$HTTPD_DOCUMENT_ROOT_PATH/shallow-exclude.shit" &&
	shit clone --shallow-exclude two $HTTPD_URL/smart/shallow-exclude.shit ../shallow12 &&
	shit -C ../shallow12 log --pretty=tformat:%s HEAD >actual &&
	echo three >expected &&
	test_cmp expected actual
	)
'

test_expect_success 'fetch exclude tag one' '
	shit -C shallow12 fetch --shallow-exclude one origin &&
	shit -C shallow12 log --pretty=tformat:%s origin/main >actual &&
	test_write_lines three two >expected &&
	test_cmp expected actual
'

test_expect_success 'fetching deepen' '
	test_create_repo shallow-deepen &&
	(
	cd shallow-deepen &&
	test_commit one &&
	test_commit two &&
	test_commit three &&
	mv .shit "$HTTPD_DOCUMENT_ROOT_PATH/shallow-deepen.shit" &&
	shit clone --depth 1 $HTTPD_URL/smart/shallow-deepen.shit deepen &&
	mv "$HTTPD_DOCUMENT_ROOT_PATH/shallow-deepen.shit" .shit &&
	test_commit four &&
	shit -C deepen log --pretty=tformat:%s main >actual &&
	echo three >expected &&
	test_cmp expected actual &&
	mv .shit "$HTTPD_DOCUMENT_ROOT_PATH/shallow-deepen.shit" &&
	shit -C deepen fetch --deepen=1 &&
	shit -C deepen log --pretty=tformat:%s origin/main >actual &&
	cat >expected <<-\EOF &&
	four
	three
	two
	EOF
	test_cmp expected actual
	)
'

test_done
