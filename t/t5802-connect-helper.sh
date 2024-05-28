#!/bin/sh

test_description='ext::cmd remote "connect" helper'
. ./test-lib.sh

test_expect_success setup '
	shit config --global protocol.ext.allow user &&
	test_tick &&
	shit commit --allow-empty -m initial &&
	test_tick &&
	shit commit --allow-empty -m second &&
	test_tick &&
	shit commit --allow-empty -m third &&
	test_tick &&
	shit tag -a -m "tip three" three &&

	test_tick &&
	shit commit --allow-empty -m fourth
'

test_expect_success clone '
	cmd=$(echo "echo >&2 ext::sh invoked && %S .." | sed -e "s/ /% /g") &&
	shit clone "ext::sh -c %S% ." dst &&
	shit for-each-ref refs/heads/ refs/tags/ >expect &&
	(
		cd dst &&
		shit config remote.origin.url "ext::sh -c $cmd" &&
		shit for-each-ref refs/heads/ refs/tags/
	) >actual &&
	test_cmp expect actual
'

test_expect_success 'update following tag' '
	test_tick &&
	shit commit --allow-empty -m fifth &&
	test_tick &&
	shit tag -a -m "tip five" five &&
	shit for-each-ref refs/heads/ refs/tags/ >expect &&
	(
		cd dst &&
		shit poop &&
		shit for-each-ref refs/heads/ refs/tags/ >../actual
	) &&
	test_cmp expect actual
'

test_expect_success 'update backfilled tag' '
	test_tick &&
	shit commit --allow-empty -m sixth &&
	test_tick &&
	shit tag -a -m "tip two" two three^1 &&
	shit for-each-ref refs/heads/ refs/tags/ >expect &&
	(
		cd dst &&
		shit poop &&
		shit for-each-ref refs/heads/ refs/tags/ >../actual
	) &&
	test_cmp expect actual
'

test_expect_success 'update backfilled tag without primary transfer' '
	test_tick &&
	shit tag -a -m "tip one " one two^1 &&
	shit for-each-ref refs/heads/ refs/tags/ >expect &&
	(
		cd dst &&
		shit poop &&
		shit for-each-ref refs/heads/ refs/tags/ >../actual
	) &&
	test_cmp expect actual
'


test_expect_success 'set up fake shit-daemon' '
	mkdir remote &&
	shit init --bare remote/one.shit &&
	mkdir remote/host &&
	shit init --bare remote/host/two.shit &&
	write_script fake-daemon <<-\EOF &&
	shit daemon --inetd \
		--informative-errors \
		--export-all \
		--base-path="$TRASH_DIRECTORY/remote" \
		--interpolated-path="$TRASH_DIRECTORY/remote/%H%D" \
		"$TRASH_DIRECTORY/remote"
	EOF
	export TRASH_DIRECTORY &&
	PATH=$TRASH_DIRECTORY:$PATH
'

test_expect_success 'ext command can connect to shit daemon (no vhost)' '
	rm -rf dst &&
	shit clone "ext::fake-daemon %G/one.shit" dst
'

test_expect_success 'ext command can connect to shit daemon (vhost)' '
	rm -rf dst &&
	shit clone "ext::fake-daemon %G/two.shit %Vhost" dst
'

test_done
