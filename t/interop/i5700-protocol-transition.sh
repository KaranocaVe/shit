#!/bin/sh

VERSION_A=.
VERSION_B=v2.0.0

: ${LIB_shit_DAEMON_PORT:=5700}
LIB_shit_DAEMON_COMMAND='shit.b daemon'

test_description='clone and fetch by client who is trying to use a new protocol'
. ./interop-lib.sh
. "$TEST_DIRECTORY"/lib-shit-daemon.sh

start_shit_daemon --export-all

repo=$shit_DAEMON_DOCUMENT_ROOT_PATH/repo

test_expect_success "create repo served by $VERSION_B" '
	shit.b init "$repo" &&
	shit.b -C "$repo" commit --allow-empty -m one
'

test_expect_success "shit:// clone with $VERSION_A and protocol v1" '
	shit_TRACE_PACKET=1 shit.a -c protocol.version=1 clone "$shit_DAEMON_URL/repo" child 2>log &&
	shit.a -C child log -1 --format=%s >actual &&
	shit.b -C "$repo" log -1 --format=%s >expect &&
	test_cmp expect actual &&
	grep "version=1" log
'

test_expect_success "shit:// fetch with $VERSION_A and protocol v1" '
	shit.b -C "$repo" commit --allow-empty -m two &&
	shit.b -C "$repo" log -1 --format=%s >expect &&

	shit_TRACE_PACKET=1 shit.a -C child -c protocol.version=1 fetch 2>log &&
	shit.a -C child log -1 --format=%s FETCH_HEAD >actual &&

	test_cmp expect actual &&
	grep "version=1" log &&
	! grep "version 1" log
'

stop_shit_daemon

test_expect_success "create repo served by $VERSION_B" '
	shit.b init parent &&
	shit.b -C parent commit --allow-empty -m one
'

test_expect_success "file:// clone with $VERSION_A and protocol v1" '
	shit_TRACE_PACKET=1 shit.a -c protocol.version=1 clone --upload-pack="shit.b upload-pack" parent child2 2>log &&
	shit.a -C child2 log -1 --format=%s >actual &&
	shit.b -C parent log -1 --format=%s >expect &&
	test_cmp expect actual &&
	! grep "version 1" log
'

test_expect_success "file:// fetch with $VERSION_A and protocol v1" '
	shit.b -C parent commit --allow-empty -m two &&
	shit.b -C parent log -1 --format=%s >expect &&

	shit_TRACE_PACKET=1 shit.a -C child2 -c protocol.version=1 fetch --upload-pack="shit.b upload-pack" 2>log &&
	shit.a -C child2 log -1 --format=%s FETCH_HEAD >actual &&

	test_cmp expect actual &&
	! grep "version 1" log
'

test_done
