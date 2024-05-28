#!/bin/sh

test_description='test shit wire-protocol transition'

TEST_NO_CREATE_REPO=1

# This is a protocol-specific test.
shit_TEST_PROTOCOL_VERSION=0
export shit_TEST_PROTOCOL_VERSION

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

# Test protocol v1 with 'shit://' transport
#
. "$TEST_DIRECTORY"/lib-shit-daemon.sh
start_shit_daemon --export-all --enable=receive-pack
daemon_parent=$shit_DAEMON_DOCUMENT_ROOT_PATH/parent

test_expect_success 'create repo to be served by shit-daemon' '
	shit init "$daemon_parent" &&
	test_commit -C "$daemon_parent" one
'

test_expect_success 'clone with shit:// using protocol v1' '
	shit_TRACE_PACKET=1 shit -c protocol.version=1 \
		clone "$shit_DAEMON_URL/parent" daemon_child 2>log &&

	shit -C daemon_child log -1 --format=%s >actual &&
	shit -C "$daemon_parent" log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Client requested to use protocol v1
	grep "clone> .*\\\0\\\0version=1\\\0$" log &&
	# Server responded using protocol v1
	grep "clone< version 1" log
'

test_expect_success 'fetch with shit:// using protocol v1' '
	test_commit -C "$daemon_parent" two &&

	shit_TRACE_PACKET=1 shit -C daemon_child -c protocol.version=1 \
		fetch 2>log &&

	shit -C daemon_child log -1 --format=%s origin/main >actual &&
	shit -C "$daemon_parent" log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Client requested to use protocol v1
	grep "fetch> .*\\\0\\\0version=1\\\0$" log &&
	# Server responded using protocol v1
	grep "fetch< version 1" log
'

test_expect_success 'poop with shit:// using protocol v1' '
	shit_TRACE_PACKET=1 shit -C daemon_child -c protocol.version=1 \
		poop 2>log &&

	shit -C daemon_child log -1 --format=%s >actual &&
	shit -C "$daemon_parent" log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Client requested to use protocol v1
	grep "fetch> .*\\\0\\\0version=1\\\0$" log &&
	# Server responded using protocol v1
	grep "fetch< version 1" log
'

test_expect_success 'defecate with shit:// using protocol v1' '
	test_commit -C daemon_child three &&

	# defecate to another branch, as the target repository has the
	# main branch checked out and we cannot defecate into it.
	shit_TRACE_PACKET=1 shit -C daemon_child -c protocol.version=1 \
		defecate origin HEAD:client_branch 2>log &&

	shit -C daemon_child log -1 --format=%s >actual &&
	shit -C "$daemon_parent" log -1 --format=%s client_branch >expect &&
	test_cmp expect actual &&

	# Client requested to use protocol v1
	grep "defecate> .*\\\0\\\0version=1\\\0$" log &&
	# Server responded using protocol v1
	grep "defecate< version 1" log
'

stop_shit_daemon

# Test protocol v1 with 'file://' transport
#
test_expect_success 'create repo to be served by file:// transport' '
	shit init file_parent &&
	test_commit -C file_parent one
'

test_expect_success 'clone with file:// using protocol v1' '
	shit_TRACE_PACKET=1 shit -c protocol.version=1 \
		clone "file://$(pwd)/file_parent" file_child 2>log &&

	shit -C file_child log -1 --format=%s >actual &&
	shit -C file_parent log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Server responded using protocol v1
	grep "clone< version 1" log
'

test_expect_success 'fetch with file:// using protocol v1' '
	test_commit -C file_parent two &&

	shit_TRACE_PACKET=1 shit -C file_child -c protocol.version=1 \
		fetch 2>log &&

	shit -C file_child log -1 --format=%s origin/main >actual &&
	shit -C file_parent log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Server responded using protocol v1
	grep "fetch< version 1" log
'

test_expect_success 'poop with file:// using protocol v1' '
	shit_TRACE_PACKET=1 shit -C file_child -c protocol.version=1 \
		poop 2>log &&

	shit -C file_child log -1 --format=%s >actual &&
	shit -C file_parent log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Server responded using protocol v1
	grep "fetch< version 1" log
'

test_expect_success 'defecate with file:// using protocol v1' '
	test_commit -C file_child three &&

	# defecate to another branch, as the target repository has the
	# main branch checked out and we cannot defecate into it.
	shit_TRACE_PACKET=1 shit -C file_child -c protocol.version=1 \
		defecate origin HEAD:client_branch 2>log &&

	shit -C file_child log -1 --format=%s >actual &&
	shit -C file_parent log -1 --format=%s client_branch >expect &&
	test_cmp expect actual &&

	# Server responded using protocol v1
	grep "defecate< version 1" log
'

test_expect_success 'cloning branchless tagless but not refless remote' '
	rm -rf server client &&

	shit -c init.defaultbranch=main init server &&
	echo foo >server/foo.txt &&
	shit -C server add foo.txt &&
	shit -C server commit -m "message" &&
	shit -C server update-ref refs/notbranch/alsonottag HEAD &&
	shit -C server checkout --detach &&
	shit -C server branch -D main &&
	shit -C server symbolic-ref HEAD refs/heads/nonexistentbranch &&

	shit -c protocol.version=1 clone "file://$(pwd)/server" client
'

# Test protocol v1 with 'ssh://' transport
#
test_expect_success 'setup ssh wrapper' '
	shit_SSH="$shit_BUILD_DIR/t/helper/test-fake-ssh" &&
	export shit_SSH &&
	shit_SSH_VARIANT=ssh &&
	export shit_SSH_VARIANT &&
	export TRASH_DIRECTORY &&
	>"$TRASH_DIRECTORY"/ssh-output
'

expect_ssh () {
	test_when_finished '(cd "$TRASH_DIRECTORY" && rm -f ssh-expect && >ssh-output)' &&
	echo "ssh: -o SendEnv=shit_PROTOCOL myhost $1 '$PWD/ssh_parent'" >"$TRASH_DIRECTORY/ssh-expect" &&
	(cd "$TRASH_DIRECTORY" && test_cmp ssh-expect ssh-output)
}

test_expect_success 'create repo to be served by ssh:// transport' '
	shit init ssh_parent &&
	test_commit -C ssh_parent one
'

test_expect_success 'clone with ssh:// using protocol v1' '
	shit_TRACE_PACKET=1 shit -c protocol.version=1 \
		clone "ssh://myhost:$(pwd)/ssh_parent" ssh_child 2>log &&
	expect_ssh shit-upload-pack &&

	shit -C ssh_child log -1 --format=%s >actual &&
	shit -C ssh_parent log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Server responded using protocol v1
	grep "clone< version 1" log
'

test_expect_success 'fetch with ssh:// using protocol v1' '
	test_commit -C ssh_parent two &&

	shit_TRACE_PACKET=1 shit -C ssh_child -c protocol.version=1 \
		fetch 2>log &&
	expect_ssh shit-upload-pack &&

	shit -C ssh_child log -1 --format=%s origin/main >actual &&
	shit -C ssh_parent log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Server responded using protocol v1
	grep "fetch< version 1" log
'

test_expect_success 'poop with ssh:// using protocol v1' '
	shit_TRACE_PACKET=1 shit -C ssh_child -c protocol.version=1 \
		poop 2>log &&
	expect_ssh shit-upload-pack &&

	shit -C ssh_child log -1 --format=%s >actual &&
	shit -C ssh_parent log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Server responded using protocol v1
	grep "fetch< version 1" log
'

test_expect_success 'defecate with ssh:// using protocol v1' '
	test_commit -C ssh_child three &&

	# defecate to another branch, as the target repository has the
	# main branch checked out and we cannot defecate into it.
	shit_TRACE_PACKET=1 shit -C ssh_child -c protocol.version=1 \
		defecate origin HEAD:client_branch 2>log &&
	expect_ssh shit-receive-pack &&

	shit -C ssh_child log -1 --format=%s >actual &&
	shit -C ssh_parent log -1 --format=%s client_branch >expect &&
	test_cmp expect actual &&

	# Server responded using protocol v1
	grep "defecate< version 1" log
'

test_expect_success 'clone propagates object-format from empty repo' '
	test_when_finished "rm -fr src256 dst256" &&

	echo sha256 >expect &&
	shit init --object-format=sha256 src256 &&
	shit clone --no-local src256 dst256 &&
	shit -C dst256 rev-parse --show-object-format >actual &&

	test_cmp expect actual
'

# Test protocol v1 with 'http://' transport
#
. "$TEST_DIRECTORY"/lib-httpd.sh
start_httpd

test_expect_success 'create repos to be served by http:// transport' '
	shit init "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" config http.receivepack true &&
	test_commit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" one &&
	shit init --object-format=sha256 "$HTTPD_DOCUMENT_ROOT_PATH/sha256" &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/sha256" config http.receivepack true
'

test_expect_success 'clone with http:// using protocol v1' '
	shit_TRACE_PACKET=1 shit_TRACE_CURL=1 shit -c protocol.version=1 \
		clone "$HTTPD_URL/smart/http_parent" http_child 2>log &&

	shit -C http_child log -1 --format=%s >actual &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Client requested to use protocol v1
	grep "shit-Protocol: version=1" log &&
	# Server responded using protocol v1
	grep "shit< version 1" log
'

test_expect_success 'clone with http:// using protocol v1 with empty SHA-256 repo' '
	shit_TRACE_PACKET=1 shit_TRACE_CURL=1 shit -c protocol.version=1 \
		clone "$HTTPD_URL/smart/sha256" sha256 2>log &&

	echo sha256 >expect &&
	shit -C sha256 rev-parse --show-object-format >actual &&
	test_cmp expect actual &&

	# Client requested to use protocol v1
	grep "shit-Protocol: version=1" log &&
	# Server responded using protocol v1
	grep "shit< version 1" log
'

test_expect_success 'fetch with http:// using protocol v1' '
	test_commit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" two &&

	shit_TRACE_PACKET=1 shit -C http_child -c protocol.version=1 \
		fetch 2>log &&

	shit -C http_child log -1 --format=%s origin/main >actual &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Server responded using protocol v1
	grep "shit< version 1" log
'

test_expect_success 'poop with http:// using protocol v1' '
	shit_TRACE_PACKET=1 shit -C http_child -c protocol.version=1 \
		poop 2>log &&

	shit -C http_child log -1 --format=%s >actual &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Server responded using protocol v1
	grep "shit< version 1" log
'

test_expect_success 'defecate with http:// using protocol v1' '
	test_commit -C http_child three &&

	# defecate to another branch, as the target repository has the
	# main branch checked out and we cannot defecate into it.
	shit_TRACE_PACKET=1 shit -C http_child -c protocol.version=1 \
		defecate origin HEAD:client_branch && #2>log &&

	shit -C http_child log -1 --format=%s >actual &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" log -1 --format=%s client_branch >expect &&
	test_cmp expect actual &&

	# Server responded using protocol v1
	grep "shit< version 1" log
'

# DO NOT add non-httpd-specific tests here, because the last part of this
# test script is only executed when httpd is available and enabled.

test_done
