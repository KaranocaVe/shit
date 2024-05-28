#!/bin/sh

VERSION_A=.
VERSION_B=v1.0.0

: ${LIB_shit_DAEMON_PORT:=5500}
LIB_shit_DAEMON_COMMAND='shit.a daemon'

test_description='clone and fetch by older client'
. ./interop-lib.sh
. "$TEST_DIRECTORY"/lib-shit-daemon.sh

start_shit_daemon --export-all

repo=$shit_DAEMON_DOCUMENT_ROOT_PATH/repo

test_expect_success "create repo served by $VERSION_A" '
	shit.a init "$repo" &&
	shit.a -C "$repo" commit --allow-empty -m one
'

test_expect_success "clone with $VERSION_B" '
	shit.b clone "$shit_DAEMON_URL/repo" child &&
	echo one >expect &&
	shit.a -C child log -1 --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success "fetch with $VERSION_B" '
	shit.a -C "$repo" commit --allow-empty -m two &&
	(
		cd child &&
		shit.b fetch
	) &&
	echo two >expect &&
	shit.a -C child log -1 --format=%s FETCH_HEAD >actual &&
	test_cmp expect actual
'

test_done
