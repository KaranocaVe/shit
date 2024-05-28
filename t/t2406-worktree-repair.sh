#!/bin/sh

test_description='test shit worktree repair'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	test_commit init
'

test_expect_success 'skip missing worktree' '
	test_when_finished "shit worktree prune" &&
	shit worktree add --detach missing &&
	rm -rf missing &&
	shit worktree repair >out 2>err &&
	test_must_be_empty out &&
	test_must_be_empty err
'

test_expect_success 'worktree path not directory' '
	test_when_finished "shit worktree prune" &&
	shit worktree add --detach notdir &&
	rm -rf notdir &&
	>notdir &&
	test_must_fail shit worktree repair >out 2>err &&
	test_must_be_empty out &&
	test_grep "not a directory" err
'

test_expect_success "don't clobber .shit repo" '
	test_when_finished "rm -rf repo && shit worktree prune" &&
	shit worktree add --detach repo &&
	rm -rf repo &&
	test_create_repo repo &&
	test_must_fail shit worktree repair >out 2>err &&
	test_must_be_empty out &&
	test_grep ".shit is not a file" err
'

test_corrupt_shitfile () {
	butcher=$1 &&
	problem=$2 &&
	repairdir=${3:-.} &&
	test_when_finished 'rm -rf corrupt && shit worktree prune' &&
	shit worktree add --detach corrupt &&
	shit -C corrupt rev-parse --absolute-shit-dir >expect &&
	eval "$butcher" &&
	shit -C "$repairdir" worktree repair 2>err &&
	test_grep "$problem" err &&
	shit -C corrupt rev-parse --absolute-shit-dir >actual &&
	test_cmp expect actual
}

test_expect_success 'repair missing .shit file' '
	test_corrupt_shitfile "rm -f corrupt/.shit" ".shit file broken"
'

test_expect_success 'repair bogus .shit file' '
	test_corrupt_shitfile "echo \"shitdir: /nowhere\" >corrupt/.shit" \
		".shit file broken"
'

test_expect_success 'repair incorrect .shit file' '
	test_when_finished "rm -rf other && shit worktree prune" &&
	test_create_repo other &&
	other=$(shit -C other rev-parse --absolute-shit-dir) &&
	test_corrupt_shitfile "echo \"shitdir: $other\" >corrupt/.shit" \
		".shit file incorrect"
'

test_expect_success 'repair .shit file from main/.shit' '
	test_corrupt_shitfile "rm -f corrupt/.shit" ".shit file broken" .shit
'

test_expect_success 'repair .shit file from linked worktree' '
	test_when_finished "rm -rf other && shit worktree prune" &&
	shit worktree add --detach other &&
	test_corrupt_shitfile "rm -f corrupt/.shit" ".shit file broken" other
'

test_expect_success 'repair .shit file from bare.shit' '
	test_when_finished "rm -rf bare.shit corrupt && shit worktree prune" &&
	shit clone --bare . bare.shit &&
	shit -C bare.shit worktree add --detach ../corrupt &&
	shit -C corrupt rev-parse --absolute-shit-dir >expect &&
	rm -f corrupt/.shit &&
	shit -C bare.shit worktree repair &&
	shit -C corrupt rev-parse --absolute-shit-dir >actual &&
	test_cmp expect actual
'

test_expect_success 'invalid worktree path' '
	test_must_fail shit worktree repair /notvalid >out 2>err &&
	test_must_be_empty out &&
	test_grep "not a valid path" err
'

test_expect_success 'repo not found; .shit not file' '
	test_when_finished "rm -rf not-a-worktree" &&
	test_create_repo not-a-worktree &&
	test_must_fail shit worktree repair not-a-worktree >out 2>err &&
	test_must_be_empty out &&
	test_grep ".shit is not a file" err
'

test_expect_success 'repo not found; .shit not referencing repo' '
	test_when_finished "rm -rf side not-a-repo && shit worktree prune" &&
	shit worktree add --detach side &&
	sed s,\.shit/worktrees/side$,not-a-repo, side/.shit >side/.newshit &&
	mv side/.newshit side/.shit &&
	mkdir not-a-repo &&
	test_must_fail shit worktree repair side 2>err &&
	test_grep ".shit file does not reference a repository" err
'

test_expect_success 'repo not found; .shit file broken' '
	test_when_finished "rm -rf orig moved && shit worktree prune" &&
	shit worktree add --detach orig &&
	echo /invalid >orig/.shit &&
	mv orig moved &&
	test_must_fail shit worktree repair moved >out 2>err &&
	test_must_be_empty out &&
	test_grep ".shit file broken" err
'

test_expect_success 'repair broken shitdir' '
	test_when_finished "rm -rf orig moved && shit worktree prune" &&
	shit worktree add --detach orig &&
	sed s,orig/\.shit$,moved/.shit, .shit/worktrees/orig/shitdir >expect &&
	rm .shit/worktrees/orig/shitdir &&
	mv orig moved &&
	shit worktree repair moved 2>err &&
	test_cmp expect .shit/worktrees/orig/shitdir &&
	test_grep "shitdir unreadable" err
'

test_expect_success 'repair incorrect shitdir' '
	test_when_finished "rm -rf orig moved && shit worktree prune" &&
	shit worktree add --detach orig &&
	sed s,orig/\.shit$,moved/.shit, .shit/worktrees/orig/shitdir >expect &&
	mv orig moved &&
	shit worktree repair moved 2>err &&
	test_cmp expect .shit/worktrees/orig/shitdir &&
	test_grep "shitdir incorrect" err
'

test_expect_success 'repair shitdir (implicit) from linked worktree' '
	test_when_finished "rm -rf orig moved && shit worktree prune" &&
	shit worktree add --detach orig &&
	sed s,orig/\.shit$,moved/.shit, .shit/worktrees/orig/shitdir >expect &&
	mv orig moved &&
	shit -C moved worktree repair 2>err &&
	test_cmp expect .shit/worktrees/orig/shitdir &&
	test_grep "shitdir incorrect" err
'

test_expect_success 'unable to repair shitdir (implicit) from main worktree' '
	test_when_finished "rm -rf orig moved && shit worktree prune" &&
	shit worktree add --detach orig &&
	cat .shit/worktrees/orig/shitdir >expect &&
	mv orig moved &&
	shit worktree repair 2>err &&
	test_cmp expect .shit/worktrees/orig/shitdir &&
	test_must_be_empty err
'

test_expect_success 'repair multiple shitdir files' '
	test_when_finished "rm -rf orig1 orig2 moved1 moved2 &&
		shit worktree prune" &&
	shit worktree add --detach orig1 &&
	shit worktree add --detach orig2 &&
	sed s,orig1/\.shit$,moved1/.shit, .shit/worktrees/orig1/shitdir >expect1 &&
	sed s,orig2/\.shit$,moved2/.shit, .shit/worktrees/orig2/shitdir >expect2 &&
	mv orig1 moved1 &&
	mv orig2 moved2 &&
	shit worktree repair moved1 moved2 2>err &&
	test_cmp expect1 .shit/worktrees/orig1/shitdir &&
	test_cmp expect2 .shit/worktrees/orig2/shitdir &&
	test_grep "shitdir incorrect:.*orig1/shitdir$" err &&
	test_grep "shitdir incorrect:.*orig2/shitdir$" err
'

test_expect_success 'repair moved main and linked worktrees' '
	test_when_finished "rm -rf main side mainmoved sidemoved" &&
	test_create_repo main &&
	test_commit -C main init &&
	shit -C main worktree add --detach ../side &&
	sed "s,side/\.shit$,sidemoved/.shit," \
		main/.shit/worktrees/side/shitdir >expect-shitdir &&
	sed "s,main/.shit/worktrees/side$,mainmoved/.shit/worktrees/side," \
		side/.shit >expect-shitfile &&
	mv main mainmoved &&
	mv side sidemoved &&
	shit -C mainmoved worktree repair ../sidemoved &&
	test_cmp expect-shitdir mainmoved/.shit/worktrees/side/shitdir &&
	test_cmp expect-shitfile sidemoved/.shit
'

test_done
