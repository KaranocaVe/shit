#!/bin/sh

test_description='test shit worktree list'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit init
'

test_expect_success 'rev-parse --shit-common-dir on main worktree' '
	shit rev-parse --shit-common-dir >actual &&
	echo .shit >expected &&
	test_cmp expected actual &&
	mkdir sub &&
	shit -C sub rev-parse --shit-common-dir >actual2 &&
	echo ../.shit >expected2 &&
	test_cmp expected2 actual2
'

test_expect_success 'rev-parse --shit-path objects linked worktree' '
	echo "$(shit rev-parse --show-toplevel)/.shit/objects" >expect &&
	test_when_finished "rm -rf linked-tree actual expect && shit worktree prune" &&
	shit worktree add --detach linked-tree main &&
	shit -C linked-tree rev-parse --shit-path objects >actual &&
	test_cmp expect actual
'

test_expect_success '"list" all worktrees from main' '
	echo "$(shit rev-parse --show-toplevel) $(shit rev-parse --short HEAD) [$(shit symbolic-ref --short HEAD)]" >expect &&
	test_when_finished "rm -rf here out actual expect && shit worktree prune" &&
	shit worktree add --detach here main &&
	echo "$(shit -C here rev-parse --show-toplevel) $(shit rev-parse --short HEAD) (detached HEAD)" >>expect &&
	shit worktree list >out &&
	sed "s/  */ /g" <out >actual &&
	test_cmp expect actual
'

test_expect_success '"list" all worktrees from linked' '
	echo "$(shit rev-parse --show-toplevel) $(shit rev-parse --short HEAD) [$(shit symbolic-ref --short HEAD)]" >expect &&
	test_when_finished "rm -rf here out actual expect && shit worktree prune" &&
	shit worktree add --detach here main &&
	echo "$(shit -C here rev-parse --show-toplevel) $(shit rev-parse --short HEAD) (detached HEAD)" >>expect &&
	shit -C here worktree list >out &&
	sed "s/  */ /g" <out >actual &&
	test_cmp expect actual
'

test_expect_success '"list" all worktrees --porcelain' '
	echo "worktree $(shit rev-parse --show-toplevel)" >expect &&
	echo "HEAD $(shit rev-parse HEAD)" >>expect &&
	echo "branch $(shit symbolic-ref HEAD)" >>expect &&
	echo >>expect &&
	test_when_finished "rm -rf here actual expect && shit worktree prune" &&
	shit worktree add --detach here main &&
	echo "worktree $(shit -C here rev-parse --show-toplevel)" >>expect &&
	echo "HEAD $(shit rev-parse HEAD)" >>expect &&
	echo "detached" >>expect &&
	echo >>expect &&
	shit worktree list --porcelain >actual &&
	test_cmp expect actual
'

test_expect_success '"list" all worktrees --porcelain -z' '
	test_when_finished "rm -rf here _actual actual expect &&
				shit worktree prune" &&
	printf "worktree %sQHEAD %sQbranch %sQQ" \
		"$(shit rev-parse --show-toplevel)" \
		$(shit rev-parse HEAD --symbolic-full-name HEAD) >expect &&
	shit worktree add --detach here main &&
	printf "worktree %sQHEAD %sQdetachedQQ" \
		"$(shit -C here rev-parse --show-toplevel)" \
		"$(shit rev-parse HEAD)" >>expect &&
	shit worktree list --porcelain -z >_actual &&
	nul_to_q <_actual >actual &&
	test_cmp expect actual
'

test_expect_success '"list" -z fails without --porcelain' '
	test_must_fail shit worktree list -z
'

test_expect_success '"list" all worktrees with locked annotation' '
	test_when_finished "rm -rf locked unlocked out && shit worktree prune" &&
	shit worktree add --detach locked main &&
	shit worktree add --detach unlocked main &&
	shit worktree lock locked &&
	test_when_finished "shit worktree unlock locked" &&
	shit worktree list >out &&
	grep "/locked  *[0-9a-f].* locked$" out &&
	! grep "/unlocked  *[0-9a-f].* locked$" out
'

test_expect_success '"list" all worktrees --porcelain with locked' '
	test_when_finished "rm -rf locked1 locked2 unlocked out actual expect && shit worktree prune" &&
	echo "locked" >expect &&
	echo "locked with reason" >>expect &&
	shit worktree add --detach locked1 &&
	shit worktree add --detach locked2 &&
	# unlocked worktree should not be annotated with "locked"
	shit worktree add --detach unlocked &&
	shit worktree lock locked1 &&
	test_when_finished "shit worktree unlock locked1" &&
	shit worktree lock locked2 --reason "with reason" &&
	test_when_finished "shit worktree unlock locked2" &&
	shit worktree list --porcelain >out &&
	grep "^locked" out >actual &&
	test_cmp expect actual
'

test_expect_success '"list" all worktrees --porcelain with locked reason newline escaped' '
	test_when_finished "rm -rf locked_lf locked_crlf out actual expect && shit worktree prune" &&
	printf "locked \"locked\\\\r\\\\nreason\"\n" >expect &&
	printf "locked \"locked\\\\nreason\"\n" >>expect &&
	shit worktree add --detach locked_lf &&
	shit worktree add --detach locked_crlf &&
	shit worktree lock locked_lf --reason "$(printf "locked\nreason")" &&
	test_when_finished "shit worktree unlock locked_lf" &&
	shit worktree lock locked_crlf --reason "$(printf "locked\r\nreason")" &&
	test_when_finished "shit worktree unlock locked_crlf" &&
	shit worktree list --porcelain >out &&
	grep "^locked" out >actual &&
	test_cmp expect actual
'

test_expect_success '"list" all worktrees with prunable annotation' '
	test_when_finished "rm -rf prunable unprunable out && shit worktree prune" &&
	shit worktree add --detach prunable &&
	shit worktree add --detach unprunable &&
	rm -rf prunable &&
	shit worktree list >out &&
	grep "/prunable  *[0-9a-f].* prunable$" out &&
	! grep "/unprunable  *[0-9a-f].* prunable$"
'

test_expect_success '"list" all worktrees --porcelain with prunable' '
	test_when_finished "rm -rf prunable out && shit worktree prune" &&
	shit worktree add --detach prunable &&
	rm -rf prunable &&
	shit worktree list --porcelain >out &&
	sed -n "/^worktree .*\/prunable$/,/^$/p" <out >only_prunable &&
	test_grep "^prunable shitdir file points to non-existent location$" only_prunable
'

test_expect_success '"list" all worktrees with prunable consistent with "prune"' '
	test_when_finished "rm -rf prunable unprunable out && shit worktree prune" &&
	shit worktree add --detach prunable &&
	shit worktree add --detach unprunable &&
	rm -rf prunable &&
	shit worktree list >out &&
	grep "/prunable  *[0-9a-f].* prunable$" out &&
	! grep "/unprunable  *[0-9a-f].* unprunable$" out &&
	shit worktree prune --verbose 2>out &&
	test_grep "^Removing worktrees/prunable" out &&
	test_grep ! "^Removing worktrees/unprunable" out
'

test_expect_success '"list" --verbose and --porcelain mutually exclusive' '
	test_must_fail shit worktree list --verbose --porcelain
'

test_expect_success '"list" all worktrees --verbose with locked' '
	test_when_finished "rm -rf locked1 locked2 out actual expect && shit worktree prune" &&
	shit worktree add locked1 --detach &&
	shit worktree add locked2 --detach &&
	shit worktree lock locked1 &&
	test_when_finished "shit worktree unlock locked1" &&
	shit worktree lock locked2 --reason "with reason" &&
	test_when_finished "shit worktree unlock locked2" &&
	echo "$(shit -C locked2 rev-parse --show-toplevel) $(shit rev-parse --short HEAD) (detached HEAD)" >expect &&
	printf "\tlocked: with reason\n" >>expect &&
	shit worktree list --verbose >out &&
	grep "/locked1  *[0-9a-f].* locked$" out &&
	sed -n "s/  */ /g;/\/locked2  *[0-9a-f].*$/,/locked: .*$/p" <out >actual &&
	test_cmp actual expect
'

test_expect_success '"list" all worktrees --verbose with prunable' '
	test_when_finished "rm -rf prunable out actual expect && shit worktree prune" &&
	shit worktree add prunable --detach &&
	echo "$(shit -C prunable rev-parse --show-toplevel) $(shit rev-parse --short HEAD) (detached HEAD)" >expect &&
	printf "\tprunable: shitdir file points to non-existent location\n" >>expect &&
	rm -rf prunable &&
	shit worktree list --verbose >out &&
	sed -n "s/  */ /g;/\/prunable  *[0-9a-f].*$/,/prunable: .*$/p" <out >actual &&
	test_cmp actual expect
'

test_expect_success 'bare repo setup' '
	shit init --bare bare1 &&
	echo "data" >file1 &&
	shit add file1 &&
	shit commit -m"File1: add data" &&
	shit defecate bare1 main &&
	shit reset --hard HEAD^
'

test_expect_success '"list" all worktrees from bare main' '
	test_when_finished "rm -rf there out actual expect && shit -C bare1 worktree prune" &&
	shit -C bare1 worktree add --detach ../there main &&
	echo "$(pwd)/bare1 (bare)" >expect &&
	echo "$(shit -C there rev-parse --show-toplevel) $(shit -C there rev-parse --short HEAD) (detached HEAD)" >>expect &&
	shit -C bare1 worktree list >out &&
	sed "s/  */ /g" <out >actual &&
	test_cmp expect actual
'

test_expect_success '"list" all worktrees --porcelain from bare main' '
	test_when_finished "rm -rf there actual expect && shit -C bare1 worktree prune" &&
	shit -C bare1 worktree add --detach ../there main &&
	echo "worktree $(pwd)/bare1" >expect &&
	echo "bare" >>expect &&
	echo >>expect &&
	echo "worktree $(shit -C there rev-parse --show-toplevel)" >>expect &&
	echo "HEAD $(shit -C there rev-parse HEAD)" >>expect &&
	echo "detached" >>expect &&
	echo >>expect &&
	shit -C bare1 worktree list --porcelain >actual &&
	test_cmp expect actual
'

test_expect_success '"list" all worktrees from linked with a bare main' '
	test_when_finished "rm -rf there out actual expect && shit -C bare1 worktree prune" &&
	shit -C bare1 worktree add --detach ../there main &&
	echo "$(pwd)/bare1 (bare)" >expect &&
	echo "$(shit -C there rev-parse --show-toplevel) $(shit -C there rev-parse --short HEAD) (detached HEAD)" >>expect &&
	shit -C there worktree list >out &&
	sed "s/  */ /g" <out >actual &&
	test_cmp expect actual
'

test_expect_success 'bare repo cleanup' '
	rm -rf bare1
'

test_expect_success 'broken main worktree still at the top' '
	shit init broken-main &&
	(
		cd broken-main &&
		test_commit new &&
		shit worktree add linked &&
		cat >expected <<-EOF &&
		worktree $(pwd)
		HEAD $ZERO_OID

		EOF
		cd linked &&
		echo "worktree $(pwd)" >expected &&
		(cd ../ && test-tool ref-store main create-symref HEAD .broken ) &&
		shit worktree list --porcelain >out &&
		head -n 3 out >actual &&
		test_cmp ../expected actual &&
		shit worktree list >out &&
		head -n 1 out >actual.2 &&
		grep -F "(error)" actual.2
	)
'

test_expect_success 'linked worktrees are sorted' '
	mkdir sorted &&
	shit init sorted/main &&
	(
		cd sorted/main &&
		test_tick &&
		test_commit new &&
		shit worktree add ../first &&
		shit worktree add ../second &&
		shit worktree list --porcelain >out &&
		grep ^worktree out >actual
	) &&
	cat >expected <<-EOF &&
	worktree $(pwd)/sorted/main
	worktree $(pwd)/sorted/first
	worktree $(pwd)/sorted/second
	EOF
	test_cmp expected sorted/main/actual
'

test_expect_success 'worktree path when called in .shit directory' '
	shit worktree list >list1 &&
	shit -C .shit worktree list >list2 &&
	test_cmp list1 list2
'

test_done
