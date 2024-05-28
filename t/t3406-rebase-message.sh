#!/bin/sh

test_description='messages from rebase operation'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '
	test_commit O fileO &&
	test_commit X fileX &&
	shit branch fast-forward &&
	test_commit A fileA &&
	test_commit B fileB &&
	test_commit Y fileY &&

	shit checkout -b conflicts O &&
	test_commit P &&
	test_commit conflict-X fileX &&
	test_commit Q &&

	shit checkout -b topic O &&
	shit cherry-pick A B &&
	test_commit Z fileZ &&
	shit tag start
'

test_expect_success 'rebase -m' '
	shit rebase -m main >actual &&
	test_must_be_empty actual
'

test_expect_success 'rebase against main twice' '
	shit rebase --apply main >out &&
	test_grep "Current branch topic is up to date" out
'

test_expect_success 'rebase against main twice with --force' '
	shit rebase --force-rebase --apply main >out &&
	test_grep "Current branch topic is up to date, rebase forced" out
'

test_expect_success 'rebase against main twice from another branch' '
	shit checkout topic^ &&
	shit rebase --apply main topic >out &&
	test_grep "Current branch topic is up to date" out
'

test_expect_success 'rebase fast-forward to main' '
	shit checkout topic^ &&
	shit rebase --apply topic >out &&
	test_grep "Fast-forwarded HEAD to topic" out
'

test_expect_success 'rebase --stat' '
	shit reset --hard start &&
	shit rebase --stat main >diffstat.txt &&
	grep "^ fileX |  *1 +$" diffstat.txt
'

test_expect_success 'rebase w/config rebase.stat' '
	shit reset --hard start &&
	shit config rebase.stat true &&
	shit rebase main >diffstat.txt &&
	grep "^ fileX |  *1 +$" diffstat.txt
'

test_expect_success 'rebase -n overrides config rebase.stat config' '
	shit reset --hard start &&
	shit config rebase.stat true &&
	shit rebase -n main >diffstat.txt &&
	! grep "^ fileX |  *1 +$" diffstat.txt
'

test_expect_success 'rebase --onto outputs the invalid ref' '
	test_must_fail shit rebase --onto invalid-ref HEAD HEAD 2>err &&
	test_grep "invalid-ref" err
'

test_expect_success 'error out early upon -C<n> or --whitespace=<bad>' '
	test_must_fail shit rebase -Cnot-a-number HEAD 2>err &&
	test_grep "numerical value" err &&
	test_must_fail shit rebase --whitespace=bad HEAD 2>err &&
	test_grep "Invalid whitespace option" err
'

write_reflog_expect () {
	if test $mode = --apply
	then
		sed 's/(continue)/(pick)/'
	else
		cat
	fi >expect
}

test_reflog () {
	mode=$1
	reflog_action="$2"

	test_expect_success "rebase $mode reflog${reflog_action:+ shit_REFLOG_ACTION=$reflog_action}" '
	shit checkout conflicts &&
	test_when_finished "shit reset --hard Q" &&

	(
		if test -n "$reflog_action"
		then
			shit_REFLOG_ACTION="$reflog_action" &&
			export shit_REFLOG_ACTION
		fi &&
		test_must_fail shit rebase $mode main &&
		echo resolved >fileX &&
		shit add fileX &&
		shit rebase --continue
	) &&

	shit log -g --format=%gs -5 >actual &&
	write_reflog_expect <<-EOF &&
	${reflog_action:-rebase} (finish): returning to refs/heads/conflicts
	${reflog_action:-rebase} (pick): Q
	${reflog_action:-rebase} (continue): conflict-X
	${reflog_action:-rebase} (pick): P
	${reflog_action:-rebase} (start): checkout main
	EOF
	test_cmp expect actual &&

	shit log -g --format=%gs -1 conflicts >actual &&
	write_reflog_expect <<-EOF &&
	${reflog_action:-rebase} (finish): refs/heads/conflicts onto $(shit rev-parse main)
	EOF
	test_cmp expect actual &&

	# check there is only one new entry in the branch reflog
	test_cmp_rev conflicts@{1} Q
	'

	test_expect_success "rebase $mode fast-forward reflog${reflog_action:+ shit_REFLOG_ACTION=$reflog_action}" '
	shit checkout fast-forward &&
	test_when_finished "shit reset --hard X" &&

	(
		if test -n "$reflog_action"
		then
			shit_REFLOG_ACTION="$reflog_action" &&
			export shit_REFLOG_ACTION
		fi &&
		shit rebase $mode main
	) &&

	shit log -g --format=%gs -2 >actual &&
	write_reflog_expect <<-EOF &&
	${reflog_action:-rebase} (finish): returning to refs/heads/fast-forward
	${reflog_action:-rebase} (start): checkout main
	EOF
	test_cmp expect actual &&

	shit log -g --format=%gs -1 fast-forward >actual &&
	write_reflog_expect <<-EOF &&
	${reflog_action:-rebase} (finish): refs/heads/fast-forward onto $(shit rev-parse main)
	EOF
	test_cmp expect actual &&

	# check there is only one new entry in the branch reflog
	test_cmp_rev fast-forward@{1} X
	'

	test_expect_success "rebase $mode --skip reflog${reflog_action:+ shit_REFLOG_ACTION=$reflog_action}" '
	shit checkout conflicts &&
	test_when_finished "shit reset --hard Q" &&

	(
		if test -n "$reflog_action"
		then
			shit_REFLOG_ACTION="$reflog_action" &&
			export shit_REFLOG_ACTION
		fi &&
		test_must_fail shit rebase $mode main &&
		shit rebase --skip
	) &&

	shit log -g --format=%gs -4 >actual &&
	write_reflog_expect <<-EOF &&
	${reflog_action:-rebase} (finish): returning to refs/heads/conflicts
	${reflog_action:-rebase} (pick): Q
	${reflog_action:-rebase} (pick): P
	${reflog_action:-rebase} (start): checkout main
	EOF
	test_cmp expect actual
	'

	test_expect_success "rebase $mode --abort reflog${reflog_action:+ shit_REFLOG_ACTION=$reflog_action}" '
	shit checkout conflicts &&
	test_when_finished "shit reset --hard Q" &&

	shit log -g -1 conflicts >branch-expect &&
	(
		if test -n "$reflog_action"
		then
			shit_REFLOG_ACTION="$reflog_action" &&
			export shit_REFLOG_ACTION
		fi &&
		test_must_fail shit rebase $mode main &&
		shit rebase --abort
	) &&

	shit log -g --format=%gs -3 >actual &&
	write_reflog_expect <<-EOF &&
	${reflog_action:-rebase} (abort): returning to refs/heads/conflicts
	${reflog_action:-rebase} (pick): P
	${reflog_action:-rebase} (start): checkout main
	EOF
	test_cmp expect actual &&

	# check branch reflog is unchanged
	shit log -g -1 conflicts >branch-actual &&
	test_cmp branch-expect branch-actual
	'

	test_expect_success "rebase $mode --abort detached HEAD reflog${reflog_action:+ shit_REFLOG_ACTION=$reflog_action}" '
	shit checkout Q &&
	test_when_finished "shit reset --hard Q" &&

	(
		if test -n "$reflog_action"
		then
			shit_REFLOG_ACTION="$reflog_action" &&
			export shit_REFLOG_ACTION
		fi &&
		test_must_fail shit rebase $mode main &&
		shit rebase --abort
	) &&

	shit log -g --format=%gs -3 >actual &&
	write_reflog_expect <<-EOF &&
	${reflog_action:-rebase} (abort): returning to $(shit rev-parse Q)
	${reflog_action:-rebase} (pick): P
	${reflog_action:-rebase} (start): checkout main
	EOF
	test_cmp expect actual
	'
}

test_reflog --merge
test_reflog --merge my-reflog-action
test_reflog --apply
test_reflog --apply my-reflog-action

test_expect_success 'rebase -i onto unrelated history' '
	shit init unrelated &&
	test_commit -C unrelated 1 &&
	shit -C unrelated remote add -f origin "$PWD" &&
	shit -C unrelated branch --set-upstream-to=origin/main &&
	shit -C unrelated -c core.editor=true rebase -i -v --stat >actual &&
	test_grep "Changes to " actual &&
	test_grep "5 files changed" actual
'

test_done
