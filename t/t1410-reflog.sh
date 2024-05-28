#!/bin/sh
#
# Copyright (c) 2007 Junio C Hamano
#

test_description='Test prune and reflog expiration'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

check_have () {
	gaah= &&
	for N in "$@"
	do
		eval "o=\$$N" && shit cat-file -t $o || {
			echo Gaah $N
			gaah=$N
			break
		}
	done &&
	test -z "$gaah"
}

check_fsck () {
	shit fsck --full >fsck.output
	case "$1" in
	'')
		test_must_be_empty fsck.output ;;
	*)
		test_grep "$1" fsck.output ;;
	esac
}

corrupt () {
	mv .shit/objects/$(test_oid_to_path $1) .shit/$1
}

recover () {
	aa=$(echo $1 | cut -c 1-2)
	mkdir -p .shit/objects/$aa
	mv .shit/$1 .shit/objects/$(test_oid_to_path $1)
}

check_dont_have () {
	gaah= &&
	for N in "$@"
	do
		eval "o=\$$N"
		shit cat-file -t $o && {
			echo Gaah $N
			gaah=$N
			break
		}
	done
	test -z "$gaah"
}

test_expect_success setup '
	mkdir -p A/B &&
	echo rat >C &&
	echo ox >A/D &&
	echo tiger >A/B/E &&
	shit add . &&

	test_tick && shit commit -m rabbit &&
	H=$(shit rev-parse --verify HEAD) &&
	A=$(shit rev-parse --verify HEAD:A) &&
	B=$(shit rev-parse --verify HEAD:A/B) &&
	C=$(shit rev-parse --verify HEAD:C) &&
	D=$(shit rev-parse --verify HEAD:A/D) &&
	E=$(shit rev-parse --verify HEAD:A/B/E) &&
	check_fsck &&

	test_chmod +x C &&
	shit add C &&
	test_tick && shit commit -m dragon &&
	L=$(shit rev-parse --verify HEAD) &&
	check_fsck &&

	rm -f C A/B/E &&
	echo snake >F &&
	echo horse >A/G &&
	shit add F A/G &&
	test_tick && shit commit -a -m sheep &&
	F=$(shit rev-parse --verify HEAD:F) &&
	G=$(shit rev-parse --verify HEAD:A/G) &&
	I=$(shit rev-parse --verify HEAD:A) &&
	J=$(shit rev-parse --verify HEAD) &&
	check_fsck &&

	rm -f A/G &&
	test_tick && shit commit -a -m monkey &&
	K=$(shit rev-parse --verify HEAD) &&
	check_fsck &&

	check_have A B C D E F G H I J K L &&

	shit prune &&

	check_have A B C D E F G H I J K L &&

	check_fsck &&

	shit reflog refs/heads/main >output &&
	test_line_count = 4 output
'

test_expect_success 'correct usage on sub-command -h' '
	test_expect_code 129 shit reflog expire -h >err &&
	grep "shit reflog expire" err
'

test_expect_success 'correct usage on "shit reflog show -h"' '
	test_expect_code 129 shit reflog show -h >err &&
	grep -F "shit reflog [show]" err
'

test_expect_success 'pass through -- to sub-command' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	test_commit -C repo message --a-file contents dash-tag &&

	shit -C repo reflog show -- --does-not-exist >out &&
	test_must_be_empty out &&
	shit -C repo reflog show >expect &&
	shit -C repo reflog show -- --a-file >actual &&
	test_cmp expect actual
'

test_expect_success rewind '
	test_tick && shit reset --hard HEAD~2 &&
	test -f C &&
	test -f A/B/E &&
	! test -f F &&
	! test -f A/G &&

	check_have A B C D E F G H I J K L &&

	shit prune &&

	check_have A B C D E F G H I J K L &&

	shit reflog refs/heads/main >output &&
	test_line_count = 5 output
'

test_expect_success 'corrupt and check' '

	corrupt $F &&
	check_fsck "missing blob $F"

'

test_expect_success 'reflog expire --dry-run should not touch reflog' '

	shit reflog expire --dry-run \
		--expire=$(($test_tick - 10000)) \
		--expire-unreachable=$(($test_tick - 10000)) \
		--stale-fix \
		--all &&

	shit reflog refs/heads/main >output &&
	test_line_count = 5 output &&

	check_fsck "missing blob $F"
'

test_expect_success 'reflog expire' '

	shit reflog expire --verbose \
		--expire=$(($test_tick - 10000)) \
		--expire-unreachable=$(($test_tick - 10000)) \
		--stale-fix \
		--all &&

	shit reflog refs/heads/main >output &&
	test_line_count = 2 output &&

	check_fsck "dangling commit $K"
'

test_expect_success '--stale-fix handles missing objects generously' '
	shit -c core.logAllRefUpdates=false fast-import --date-format=now <<-EOS &&
	commit refs/heads/stale-fix
	mark :1
	committer Author <a@uth.or> now
	data <<EOF
	start stale fix
	EOF
	M 100644 inline file
	data <<EOF
	contents
	EOF
	commit refs/heads/stale-fix
	committer Author <a@uth.or> now
	data <<EOF
	stale fix branch tip
	EOF
	from :1
	EOS

	parent_oid=$(shit rev-parse stale-fix^) &&
	test_when_finished "recover $parent_oid" &&
	corrupt $parent_oid &&
	shit reflog expire --stale-fix
'

test_expect_success 'prune and fsck' '

	shit prune &&
	check_fsck &&

	check_have A B C D E H L &&
	check_dont_have F G I J K

'

test_expect_success 'recover and check' '

	recover $F &&
	check_fsck "dangling blob $F"

'

test_expect_success 'delete' '
	echo 1 > C &&
	test_tick &&
	shit commit -m rat C &&

	echo 2 > C &&
	test_tick &&
	shit commit -m ox C &&

	echo 3 > C &&
	test_tick &&
	shit commit -m tiger C &&

	HEAD_entry_count=$(shit reflog | wc -l) &&
	main_entry_count=$(shit reflog show main | wc -l) &&

	test $HEAD_entry_count = 5 &&
	test $main_entry_count = 5 &&


	shit reflog delete main@{1} &&
	shit reflog show main > output &&
	test_line_count = $(($main_entry_count - 1)) output &&
	test $HEAD_entry_count = $(shit reflog | wc -l) &&
	! grep ox < output &&

	main_entry_count=$(wc -l < output) &&

	shit reflog delete HEAD@{1} &&
	test $(($HEAD_entry_count -1)) = $(shit reflog | wc -l) &&
	test $main_entry_count = $(shit reflog show main | wc -l) &&

	HEAD_entry_count=$(shit reflog | wc -l) &&

	shit reflog delete main@{07.04.2005.15:15:00.-0700} &&
	shit reflog show main > output &&
	test_line_count = $(($main_entry_count - 1)) output &&
	! grep dragon < output

'

test_expect_success 'rewind2' '

	test_tick && shit reset --hard HEAD~2 &&
	shit reflog refs/heads/main >output &&
	test_line_count = 4 output
'

test_expect_success '--expire=never' '

	shit reflog expire --verbose \
		--expire=never \
		--expire-unreachable=never \
		--all &&
	shit reflog refs/heads/main >output &&
	test_line_count = 4 output
'

test_expect_success 'gc.reflogexpire=never' '
	test_config gc.reflogexpire never &&
	test_config gc.reflogexpireunreachable never &&

	shit reflog expire --verbose --all >output &&
	test_line_count = 9 output &&

	shit reflog refs/heads/main >output &&
	test_line_count = 4 output
'

test_expect_success 'gc.reflogexpire=false' '
	test_config gc.reflogexpire false &&
	test_config gc.reflogexpireunreachable false &&

	shit reflog expire --verbose --all &&
	shit reflog refs/heads/main >output &&
	test_line_count = 4 output

'

test_expect_success 'shit reflog expire unknown reference' '
	test_config gc.reflogexpire never &&
	test_config gc.reflogexpireunreachable never &&

	test_must_fail shit reflog expire main@{123} 2>stderr &&
	test_grep "points nowhere" stderr &&
	test_must_fail shit reflog expire does-not-exist 2>stderr &&
	test_grep "points nowhere" stderr
'

test_expect_success 'checkout should not delete log for packed ref' '
	test $(shit reflog main | wc -l) = 4 &&
	shit branch foo &&
	shit pack-refs --all &&
	shit checkout foo &&
	test $(shit reflog main | wc -l) = 4
'

test_expect_success 'stale dirs do not cause d/f conflicts (reflogs on)' '
	test_when_finished "shit branch -d one || shit branch -d one/two" &&

	shit branch one/two main &&
	echo "one/two@{0} branch: Created from main" >expect &&
	shit log -g --format="%gd %gs" one/two >actual &&
	test_cmp expect actual &&
	shit branch -d one/two &&

	# now logs/refs/heads/one is a stale directory, but
	# we should move it out of the way to create "one" reflog
	shit branch one main &&
	echo "one@{0} branch: Created from main" >expect &&
	shit log -g --format="%gd %gs" one >actual &&
	test_cmp expect actual
'

test_expect_success 'stale dirs do not cause d/f conflicts (reflogs off)' '
	test_when_finished "shit branch -d one || shit branch -d one/two" &&

	shit branch one/two main &&
	echo "one/two@{0} branch: Created from main" >expect &&
	shit log -g --format="%gd %gs" one/two >actual &&
	test_cmp expect actual &&
	shit branch -d one/two &&

	# same as before, but we only create a reflog for "one" if
	# it already exists, which it does not
	shit -c core.logallrefupdates=false branch one main &&
	shit log -g --format="%gd %gs" one >actual &&
	test_must_be_empty actual
'

test_expect_success 'no segfaults for reflog containing non-commit sha1s' '
	shit update-ref --create-reflog -m "Creating ref" \
		refs/tests/tree-in-reflog HEAD &&
	shit update-ref -m "Forcing tree" refs/tests/tree-in-reflog HEAD^{tree} &&
	shit update-ref -m "Restoring to commit" refs/tests/tree-in-reflog HEAD &&
	shit reflog refs/tests/tree-in-reflog
'

test_expect_failure 'reflog with non-commit entries displays all entries' '
	shit reflog refs/tests/tree-in-reflog >actual &&
	test_line_count = 3 actual
'

test_expect_success 'continue walking past root commits' '
	shit init orphanage &&
	(
		cd orphanage &&
		cat >expect <<-\EOF &&
		HEAD@{0} commit (initial): orphan2-1
		HEAD@{1} commit: orphan1-2
		HEAD@{2} commit (initial): orphan1-1
		HEAD@{3} commit (initial): initial
		EOF
		test_commit initial &&
		shit checkout --orphan orphan1 &&
		test_commit orphan1-1 &&
		test_commit orphan1-2 &&
		shit checkout --orphan orphan2 &&
		test_commit orphan2-1 &&
		shit log -g --format="%gd %gs" >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'expire with multiple worktrees' '
	shit init main-wt &&
	(
		cd main-wt &&
		test_tick &&
		test_commit foo &&
		shit  worktree add link-wt &&
		test_tick &&
		test_commit -C link-wt foobar &&
		test_tick &&
		shit reflog expire --verbose --all --expire=$test_tick &&
		test-tool ref-store worktree:link-wt for-each-reflog-ent HEAD >actual &&
		test_must_be_empty actual
	)
'

test_expect_success 'expire one of multiple worktrees' '
	shit init main-wt2 &&
	(
		cd main-wt2 &&
		test_tick &&
		test_commit foo &&
		shit worktree add link-wt &&
		test_tick &&
		test_commit -C link-wt foobar &&
		test_tick &&
		test-tool ref-store worktree:link-wt for-each-reflog-ent HEAD \
			>expect-link-wt &&
		shit reflog expire --verbose --all --expire=$test_tick \
			--single-worktree &&
		test-tool ref-store worktree:main for-each-reflog-ent HEAD \
			>actual-main &&
		test-tool ref-store worktree:link-wt for-each-reflog-ent HEAD \
			>actual-link-wt &&
		test_must_be_empty actual-main &&
		test_cmp expect-link-wt actual-link-wt
	)
'

test_expect_success 'empty reflog' '
	test_when_finished "rm -rf empty" &&
	shit init empty &&
	test_commit -C empty A &&
	test-tool ref-store main create-reflog refs/heads/foo &&
	shit -C empty reflog expire --all 2>err &&
	test_must_be_empty err
'

test_expect_success 'list reflogs' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&
		shit reflog list >actual &&
		test_must_be_empty actual &&

		test_commit A &&
		cat >expect <<-EOF &&
		HEAD
		refs/heads/main
		EOF
		shit reflog list >actual &&
		test_cmp expect actual &&

		shit branch b &&
		cat >expect <<-EOF &&
		HEAD
		refs/heads/b
		refs/heads/main
		EOF
		shit reflog list >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'list reflogs with worktree' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&

		test_commit A &&
		shit worktree add wt &&
		shit -c core.logAllRefUpdates=always \
			update-ref refs/worktree/main HEAD &&
		shit -c core.logAllRefUpdates=always \
			update-ref refs/worktree/per-worktree HEAD &&
		shit -c core.logAllRefUpdates=always -C wt \
			update-ref refs/worktree/per-worktree HEAD &&
		shit -c core.logAllRefUpdates=always -C wt \
			update-ref refs/worktree/worktree HEAD &&

		cat >expect <<-EOF &&
		HEAD
		refs/heads/main
		refs/heads/wt
		refs/worktree/main
		refs/worktree/per-worktree
		EOF
		shit reflog list >actual &&
		test_cmp expect actual &&

		cat >expect <<-EOF &&
		HEAD
		refs/heads/main
		refs/heads/wt
		refs/worktree/per-worktree
		refs/worktree/worktree
		EOF
		shit -C wt reflog list >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'reflog list returns error with additional args' '
	cat >expect <<-EOF &&
	error: list does not accept arguments: ${SQ}bogus${SQ}
	EOF
	test_must_fail shit reflog list bogus 2>err &&
	test_cmp expect err
'

test_expect_success 'reflog for symref with unborn target can be listed' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&
		test_commit A &&
		shit symbolic-ref HEAD refs/heads/unborn &&
		cat >expect <<-EOF &&
		HEAD
		refs/heads/main
		EOF
		shit reflog list >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'reflog with invalid object ID can be listed' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&
		test_commit A &&
		test-tool ref-store main update-ref msg refs/heads/missing \
			$(test_oid deadbeef) "$ZERO_OID" REF_SKIP_OID_VERIFICATION &&
		cat >expect <<-EOF &&
		HEAD
		refs/heads/main
		refs/heads/missing
		EOF
		shit reflog list >actual &&
		test_cmp expect actual
	)
'

test_done
