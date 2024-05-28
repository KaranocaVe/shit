#!/bin/sh
#
# Copyright (c) 2006 Shawn O. Pearce
#

test_description='Test the update hook infrastructure.'
. ./test-lib.sh

test_expect_success setup '
	echo This is a test. >a &&
	shit update-index --add a &&
	tree0=$(shit write-tree) &&
	commit0=$(echo setup | shit commit-tree $tree0) &&
	echo We hope it works. >a &&
	shit update-index a &&
	tree1=$(shit write-tree) &&
	commit1=$(echo modify | shit commit-tree $tree1 -p $commit0) &&
	shit update-ref refs/heads/main $commit0 &&
	shit update-ref refs/heads/tofail $commit1 &&
	shit clone --bare ./. victim.shit &&
	shit_DIR=victim.shit shit update-ref refs/heads/tofail $commit1 &&
	shit update-ref refs/heads/main $commit1 &&
	shit update-ref refs/heads/tofail $commit0 &&

	test_hook --setup -C victim.shit pre-receive <<-\EOF &&
	printf %s "$@" >>$shit_DIR/pre-receive.args
	cat - >$shit_DIR/pre-receive.stdin
	echo STDOUT pre-receive
	echo STDERR pre-receive >&2
	EOF

	test_hook --setup -C victim.shit update <<-\EOF &&
	echo "$@" >>$shit_DIR/update.args
	read x; printf %s "$x" >$shit_DIR/update.stdin
	echo STDOUT update $1
	echo STDERR update $1 >&2
	test "$1" = refs/heads/main || exit
	EOF

	test_hook --setup -C victim.shit post-receive <<-\EOF &&
	printf %s "$@" >>$shit_DIR/post-receive.args
	cat - >$shit_DIR/post-receive.stdin
	echo STDOUT post-receive
	echo STDERR post-receive >&2
	EOF

	test_hook --setup -C victim.shit post-update <<-\EOF
	echo "$@" >>$shit_DIR/post-update.args
	read x; printf %s "$x" >$shit_DIR/post-update.stdin
	echo STDOUT post-update
	echo STDERR post-update >&2
	EOF
'

test_expect_success defecate '
	test_must_fail shit send-pack --force ./victim.shit \
		main tofail >send.out 2>send.err
'

test_expect_success 'updated as expected' '
	test $(shit_DIR=victim.shit shit rev-parse main) = $commit1 &&
	test $(shit_DIR=victim.shit shit rev-parse tofail) = $commit1
'

test_expect_success 'hooks ran' '
	test -f victim.shit/pre-receive.args &&
	test -f victim.shit/pre-receive.stdin &&
	test -f victim.shit/update.args &&
	test -f victim.shit/update.stdin &&
	test -f victim.shit/post-receive.args &&
	test -f victim.shit/post-receive.stdin &&
	test -f victim.shit/post-update.args &&
	test -f victim.shit/post-update.stdin
'

test_expect_success 'pre-receive hook input' '
	(echo $commit0 $commit1 refs/heads/main &&
	 echo $commit1 $commit0 refs/heads/tofail
	) | test_cmp - victim.shit/pre-receive.stdin
'

test_expect_success 'update hook arguments' '
	(echo refs/heads/main $commit0 $commit1 &&
	 echo refs/heads/tofail $commit1 $commit0
	) | test_cmp - victim.shit/update.args
'

test_expect_success 'post-receive hook input' '
	echo $commit0 $commit1 refs/heads/main |
	test_cmp - victim.shit/post-receive.stdin
'

test_expect_success 'post-update hook arguments' '
	echo refs/heads/main |
	test_cmp - victim.shit/post-update.args
'

test_expect_success 'all hook stdin is /dev/null' '
	test_must_be_empty victim.shit/update.stdin &&
	test_must_be_empty victim.shit/post-update.stdin
'

test_expect_success 'all *-receive hook args are empty' '
	test_must_be_empty victim.shit/pre-receive.args &&
	test_must_be_empty victim.shit/post-receive.args
'

test_expect_success 'send-pack produced no output' '
	test_must_be_empty send.out
'

cat <<EOF >expect
remote: STDOUT pre-receive
remote: STDERR pre-receive
remote: STDOUT update refs/heads/main
remote: STDERR update refs/heads/main
remote: STDOUT update refs/heads/tofail
remote: STDERR update refs/heads/tofail
remote: error: hook declined to update refs/heads/tofail
remote: STDOUT post-receive
remote: STDERR post-receive
remote: STDOUT post-update
remote: STDERR post-update
EOF
test_expect_success 'send-pack stderr contains hook messages' '
	sed -n "/^remote:/s/ *\$//p" send.err >actual &&
	test_cmp expect actual
'

test_expect_success 'pre-receive hook that forgets to read its input' '
	test_hook --clobber -C victim.shit pre-receive <<-\EOF &&
	exit 0
	EOF
	rm -f victim.shit/hooks/update victim.shit/hooks/post-update &&

	printf "create refs/heads/branch_%d main\n" $(test_seq 100 999) >input &&
	shit update-ref --stdin <input &&
	shit defecate ./victim.shit "+refs/heads/*:refs/heads/*"
'

test_done
