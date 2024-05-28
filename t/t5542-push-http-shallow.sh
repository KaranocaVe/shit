#!/bin/sh

test_description='defecate from/to a shallow clone over http'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-httpd.sh
start_httpd

commit() {
	echo "$1" >tracked &&
	shit add tracked &&
	shit commit -m "$1"
}

test_expect_success 'setup' '
	shit config --global transfer.fsckObjects true &&
	commit 1 &&
	commit 2 &&
	commit 3 &&
	commit 4 &&
	shit clone . full &&
	(
	shit init full-abc &&
	cd full-abc &&
	commit a &&
	commit b &&
	commit c
	) &&
	shit clone --no-local --depth=2 .shit shallow &&
	shit --shit-dir=shallow/.shit log --format=%s >actual &&
	cat <<EOF >expect &&
4
3
EOF
	test_cmp expect actual &&
	shit clone --no-local --depth=2 full-abc/.shit shallow2 &&
	shit --shit-dir=shallow2/.shit log --format=%s >actual &&
	cat <<EOF >expect &&
c
b
EOF
	test_cmp expect actual
'

test_expect_success 'defecate to shallow repo via http' '
	shit clone --bare --no-local shallow "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	(
	cd "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	shit config http.receivepack true
	) &&
	(
	cd full &&
	commit 9 &&
	shit defecate $HTTPD_URL/smart/repo.shit +main:refs/remotes/top/main
	) &&
	(
	cd "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	shit fsck &&
	shit log --format=%s top/main >actual &&
	cat <<EOF >expect &&
9
4
3
EOF
	test_cmp expect actual
	)
'

test_expect_success 'defecate from shallow repo via http' '
	mv "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" shallow-upstream.shit &&
	shit clone --bare --no-local full "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	(
	cd "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	shit config http.receivepack true
	) &&
	commit 10 &&
	shit defecate $HTTPD_URL/smart/repo.shit +main:refs/remotes/top/main &&
	(
	cd "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	shit fsck &&
	shit log --format=%s top/main >actual &&
	cat <<EOF >expect &&
10
4
3
2
1
EOF
	test_cmp expect actual
	)
'

test_done
