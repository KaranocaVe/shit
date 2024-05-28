#!/bin/sh

test_description='test shit worktree add'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_CREATE_REPO_NO_TEMPLATE=1
. ./test-lib.sh

. "$TEST_DIRECTORY"/lib-rebase.sh

test_expect_success 'setup' '
	test_commit init
'

test_expect_success '"add" an existing worktree' '
	mkdir -p existing/subtree &&
	test_must_fail shit worktree add --detach existing main
'

test_expect_success '"add" an existing empty worktree' '
	mkdir existing_empty &&
	shit worktree add --detach existing_empty main
'

test_expect_success '"add" using shorthand - fails when no previous branch' '
	test_must_fail shit worktree add existing_short -
'

test_expect_success '"add" using - shorthand' '
	shit checkout -b newbranch &&
	echo hello >myworld &&
	shit add myworld &&
	shit commit -m myworld &&
	shit checkout main &&
	shit worktree add short-hand - &&
	echo refs/heads/newbranch >expect &&
	shit -C short-hand rev-parse --symbolic-full-name HEAD >actual &&
	test_cmp expect actual
'

test_expect_success '"add" refuses to checkout locked branch' '
	test_must_fail shit worktree add zere main &&
	! test -d zere &&
	! test -d .shit/worktrees/zere
'

test_expect_success 'checking out paths not complaining about linked checkouts' '
	(
	cd existing_empty &&
	echo dirty >>init.t &&
	shit checkout main -- init.t
	)
'

test_expect_success '"add" worktree' '
	shit rev-parse HEAD >expect &&
	shit worktree add --detach here main &&
	(
		cd here &&
		test_cmp ../init.t init.t &&
		test_must_fail shit symbolic-ref HEAD &&
		shit rev-parse HEAD >actual &&
		test_cmp ../expect actual &&
		shit fsck
	)
'

test_expect_success '"add" worktree with lock' '
	shit worktree add --detach --lock here-with-lock main &&
	test_when_finished "shit worktree unlock here-with-lock || :" &&
	test -f .shit/worktrees/here-with-lock/locked
'

test_expect_success '"add" worktree with lock and reason' '
	lock_reason="why not" &&
	shit worktree add --detach --lock --reason "$lock_reason" here-with-lock-reason main &&
	test_when_finished "shit worktree unlock here-with-lock-reason || :" &&
	test -f .shit/worktrees/here-with-lock-reason/locked &&
	echo "$lock_reason" >expect &&
	test_cmp expect .shit/worktrees/here-with-lock-reason/locked
'

test_expect_success '"add" worktree with reason but no lock' '
	test_must_fail shit worktree add --detach --reason "why not" here-with-reason-only main &&
	test_path_is_missing .shit/worktrees/here-with-reason-only/locked
'

test_expect_success '"add" worktree from a subdir' '
	(
		mkdir sub &&
		cd sub &&
		shit worktree add --detach here main &&
		cd here &&
		test_cmp ../../init.t init.t
	)
'

test_expect_success '"add" from a linked checkout' '
	(
		cd here &&
		shit worktree add --detach nested-here main &&
		cd nested-here &&
		shit fsck
	)
'

test_expect_success '"add" worktree creating new branch' '
	shit worktree add -b newmain there main &&
	(
		cd there &&
		test_cmp ../init.t init.t &&
		shit symbolic-ref HEAD >actual &&
		echo refs/heads/newmain >expect &&
		test_cmp expect actual &&
		shit fsck
	)
'

test_expect_success 'die the same branch is already checked out' '
	(
		cd here &&
		test_must_fail shit checkout newmain 2>actual &&
		grep "already used by worktree at" actual
	)
'

test_expect_success 'refuse to reset a branch in use elsewhere' '
	(
		cd here &&

		# we know we are on detached HEAD but just in case ...
		shit checkout --detach HEAD &&
		shit rev-parse --verify HEAD >old.head &&

		shit rev-parse --verify refs/heads/newmain >old.branch &&
		test_must_fail shit checkout -B newmain 2>error &&
		shit rev-parse --verify refs/heads/newmain >new.branch &&
		shit rev-parse --verify HEAD >new.head &&

		grep "already used by worktree at" error &&
		test_cmp old.branch new.branch &&
		test_cmp old.head new.head &&

		# and we must be still on the same detached HEAD state
		test_must_fail shit symbolic-ref HEAD
	)
'

test_expect_success SYMLINKS 'die the same branch is already checked out (symlink)' '
	head=$(shit -C there rev-parse --shit-path HEAD) &&
	ref=$(shit -C there symbolic-ref HEAD) &&
	rm "$head" &&
	ln -s "$ref" "$head" &&
	test_must_fail shit -C here checkout newmain
'

test_expect_success 'not die the same branch is already checked out' '
	(
		cd here &&
		shit worktree add --force anothernewmain newmain
	)
'

test_expect_success 'not die on re-checking out current branch' '
	(
		cd there &&
		shit checkout newmain
	)
'

test_expect_success '"add" from a bare repo' '
	(
		shit clone --bare . bare &&
		cd bare &&
		shit worktree add -b bare-main ../there2 main
	)
'

test_expect_success 'checkout from a bare repo without "add"' '
	(
		cd bare &&
		test_must_fail shit checkout main
	)
'

test_expect_success '"add" default branch of a bare repo' '
	(
		shit clone --bare . bare2 &&
		cd bare2 &&
		shit worktree add ../there3 main &&
		cd ../there3 &&
		# Simple check that a shit command does not
		# immediately fail with the current setup
		shit status
	) &&
	cat >expect <<-EOF &&
	init.t
	EOF
	ls there3 >actual &&
	test_cmp expect actual
'

test_expect_success '"add" to bare repo with worktree config' '
	(
		shit clone --bare . bare3 &&
		cd bare3 &&
		shit config extensions.worktreeconfig true &&

		# Add config values that are erroneous to have in
		# a config.worktree file outside of the main
		# working tree, to check that shit filters them out
		# when copying config during "shit worktree add".
		shit config --worktree core.bare true &&
		shit config --worktree core.worktree "$(pwd)" &&

		# We want to check that bogus.key is copied
		shit config --worktree bogus.key value &&
		shit config --unset core.bare &&
		shit worktree add ../there4 main &&
		cd ../there4 &&

		# Simple check that a shit command does not
		# immediately fail with the current setup
		shit status &&
		shit worktree add --detach ../there5 &&
		cd ../there5 &&
		shit status
	) &&

	# the worktree has the arbitrary value copied.
	test_cmp_config -C there4 value bogus.key &&
	test_cmp_config -C there5 value bogus.key &&

	# however, core.bare and core.worktree were removed.
	test_must_fail shit -C there4 config core.bare &&
	test_must_fail shit -C there4 config core.worktree &&

	cat >expect <<-EOF &&
	init.t
	EOF

	ls there4 >actual &&
	test_cmp expect actual &&
	ls there5 >actual &&
	test_cmp expect actual
'

test_expect_success 'checkout with grafts' '
	test_when_finished rm .shit/info/grafts &&
	test_commit abc &&
	SHA1=$(shit rev-parse HEAD) &&
	test_commit def &&
	test_commit xyz &&
	mkdir .shit/info &&
	echo "$(shit rev-parse HEAD) $SHA1" >.shit/info/grafts &&
	cat >expected <<-\EOF &&
	xyz
	abc
	EOF
	shit log --format=%s -2 >actual &&
	test_cmp expected actual &&
	shit worktree add --detach grafted main &&
	shit --shit-dir=grafted/.shit log --format=%s -2 >actual &&
	test_cmp expected actual
'

test_expect_success '"add" from relative HEAD' '
	test_commit a &&
	test_commit b &&
	test_commit c &&
	shit rev-parse HEAD~1 >expected &&
	shit worktree add relhead HEAD~1 &&
	shit -C relhead rev-parse HEAD >actual &&
	test_cmp expected actual
'

test_expect_success '"add -b" with <branch> omitted' '
	shit worktree add -b burble flornk &&
	test_cmp_rev HEAD burble
'

test_expect_success '"add --detach" with <branch> omitted' '
	shit worktree add --detach fishhook &&
	shit rev-parse HEAD >expected &&
	shit -C fishhook rev-parse HEAD >actual &&
	test_cmp expected actual &&
	test_must_fail shit -C fishhook symbolic-ref HEAD
'

test_expect_success '"add" with <branch> omitted' '
	shit worktree add wiffle/bat &&
	test_cmp_rev HEAD bat
'

test_expect_success '"add" checks out existing branch of dwimd name' '
	shit branch dwim HEAD~1 &&
	shit worktree add dwim &&
	test_cmp_rev HEAD~1 dwim &&
	(
		cd dwim &&
		test_cmp_rev HEAD dwim
	)
'

test_expect_success '"add <path>" dwim fails with checked out branch' '
	shit checkout -b test-branch &&
	test_must_fail shit worktree add test-branch &&
	test_path_is_missing test-branch
'

test_expect_success '"add --force" with existing dwimd name doesnt die' '
	shit checkout test-branch &&
	shit worktree add --force test-branch
'

test_expect_success '"add" no auto-vivify with --detach and <branch> omitted' '
	shit worktree add --detach mish/mash &&
	test_must_fail shit rev-parse mash -- &&
	test_must_fail shit -C mish/mash symbolic-ref HEAD
'

# Helper function to test mutually exclusive options.
#
# Note: Quoted arguments containing spaces are not supported.
test_wt_add_excl () {
	local opts="$*" &&
	test_expect_success "'worktree add' with '$opts' has mutually exclusive options" '
		test_must_fail shit worktree add $opts 2>actual &&
		grep -E "fatal:( options)? .* cannot be used together" actual
	'
}

test_wt_add_excl -b poodle -B poodle bamboo main
test_wt_add_excl -b poodle --detach bamboo main
test_wt_add_excl -B poodle --detach bamboo main
test_wt_add_excl --orphan --detach bamboo
test_wt_add_excl --orphan --no-checkout bamboo
test_wt_add_excl --orphan bamboo main
test_wt_add_excl --orphan -b bamboo wtdir/ main

test_expect_success '"add -B" fails if the branch is checked out' '
	shit rev-parse newmain >before &&
	test_must_fail shit worktree add -B newmain bamboo main &&
	shit rev-parse newmain >after &&
	test_cmp before after
'

test_expect_success 'add -B' '
	shit worktree add -B poodle bamboo2 main^ &&
	shit -C bamboo2 symbolic-ref HEAD >actual &&
	echo refs/heads/poodle >expected &&
	test_cmp expected actual &&
	test_cmp_rev main^ poodle
'

test_expect_success 'add --quiet' '
	test_when_finished "shit worktree remove -f -f another-worktree" &&
	shit worktree add --quiet another-worktree main 2>actual &&
	test_must_be_empty actual
'

test_expect_success 'add --quiet -b' '
	test_when_finished "shit branch -D quietnewbranch" &&
	test_when_finished "shit worktree remove -f -f another-worktree" &&
	shit worktree add --quiet -b quietnewbranch another-worktree 2>actual &&
	test_must_be_empty actual
'

test_expect_success '"add --orphan"' '
	test_when_finished "shit worktree remove -f -f orphandir" &&
	shit worktree add --orphan -b neworphan orphandir &&
	echo refs/heads/neworphan >expected &&
	shit -C orphandir symbolic-ref HEAD >actual &&
	test_cmp expected actual
'

test_expect_success '"add --orphan (no -b)"' '
	test_when_finished "shit worktree remove -f -f neworphan" &&
	shit worktree add --orphan neworphan &&
	echo refs/heads/neworphan >expected &&
	shit -C neworphan symbolic-ref HEAD >actual &&
	test_cmp expected actual
'

test_expect_success '"add --orphan --quiet"' '
	test_when_finished "shit worktree remove -f -f orphandir" &&
	shit worktree add --quiet --orphan -b neworphan orphandir 2>log.actual &&
	test_must_be_empty log.actual &&
	echo refs/heads/neworphan >expected &&
	shit -C orphandir symbolic-ref HEAD >actual &&
	test_cmp expected actual
'

test_expect_success '"add --orphan" fails if the branch already exists' '
	test_when_finished "shit branch -D existingbranch" &&
	shit worktree add -b existingbranch orphandir main &&
	shit worktree remove orphandir &&
	test_must_fail shit worktree add --orphan -b existingbranch orphandir
'

test_expect_success '"add --orphan" with empty repository' '
	test_when_finished "rm -rf empty_repo" &&
	echo refs/heads/newbranch >expected &&
	shit_DIR="empty_repo" shit init --bare &&
	shit -C empty_repo worktree add --orphan -b newbranch worktreedir &&
	shit -C empty_repo/worktreedir symbolic-ref HEAD >actual &&
	test_cmp expected actual
'

test_expect_success '"add" worktree with orphan branch and lock' '
	shit worktree add --lock --orphan -b orphanbr orphan-with-lock &&
	test_when_finished "shit worktree unlock orphan-with-lock || :" &&
	test -f .shit/worktrees/orphan-with-lock/locked
'

test_expect_success '"add" worktree with orphan branch, lock, and reason' '
	lock_reason="why not" &&
	shit worktree add --detach --lock --reason "$lock_reason" orphan-with-lock-reason main &&
	test_when_finished "shit worktree unlock orphan-with-lock-reason || :" &&
	test -f .shit/worktrees/orphan-with-lock-reason/locked &&
	echo "$lock_reason" >expect &&
	test_cmp expect .shit/worktrees/orphan-with-lock-reason/locked
'

# Note: Quoted arguments containing spaces are not supported.
test_wt_add_orphan_hint () {
	local context="$1" &&
	local use_branch="$2" &&
	shift 2 &&
	local opts="$*" &&
	test_expect_success "'worktree add' show orphan hint in bad/orphan HEAD w/ $context" '
		test_when_finished "rm -rf repo" &&
		shit init repo &&
		(cd repo && test_commit commit) &&
		shit -C repo switch --orphan noref &&
		test_must_fail shit -C repo worktree add $opts foobar/ 2>actual &&
		! grep "error: unknown switch" actual &&
		grep "hint: If you meant to create a worktree containing a new unborn branch" actual &&
		if [ $use_branch -eq 1 ]
		then
			grep -E "^hint: +shit worktree add --orphan -b [^ ]+ [^ ]+$" actual
		else
			grep -E "^hint: +shit worktree add --orphan [^ ]+$" actual
		fi

	'
}

test_wt_add_orphan_hint 'no opts' 0
test_wt_add_orphan_hint '-b' 1 -b foobar_branch
test_wt_add_orphan_hint '-B' 1 -B foobar_branch

test_expect_success "'worktree add' doesn't show orphan hint in bad/orphan HEAD w/ --quiet" '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(cd repo && test_commit commit) &&
	test_must_fail shit -C repo worktree add --quiet foobar_branch foobar/ 2>actual &&
	! grep "error: unknown switch" actual &&
	! grep "hint: If you meant to create a worktree containing a new unborn branch" actual
'

test_expect_success 'local clone from linked checkout' '
	shit clone --local here here-clone &&
	( cd here-clone && shit fsck )
'

test_expect_success 'local clone --shared from linked checkout' '
	shit -C bare worktree add --detach ../baretree &&
	shit clone --local --shared baretree bare-clone &&
	grep /bare/ bare-clone/.shit/objects/info/alternates
'

test_expect_success '"add" worktree with --no-checkout' '
	shit worktree add --no-checkout -b swamp swamp &&
	! test -e swamp/init.t &&
	shit -C swamp reset --hard &&
	test_cmp init.t swamp/init.t
'

test_expect_success '"add" worktree with --checkout' '
	shit worktree add --checkout -b swmap2 swamp2 &&
	test_cmp init.t swamp2/init.t
'

test_expect_success 'put a worktree under rebase' '
	shit worktree add under-rebase &&
	(
		cd under-rebase &&
		set_fake_editor &&
		FAKE_LINES="edit 1" shit rebase -i HEAD^ &&
		shit worktree list >actual &&
		grep "under-rebase.*detached HEAD" actual
	)
'

test_expect_success 'add a worktree, checking out a rebased branch' '
	test_must_fail shit worktree add new-rebase under-rebase &&
	! test -d new-rebase
'

test_expect_success 'checking out a rebased branch from another worktree' '
	shit worktree add new-place &&
	test_must_fail shit -C new-place checkout under-rebase
'

test_expect_success 'not allow to delete a branch under rebase' '
	(
		cd under-rebase &&
		test_must_fail shit branch -D under-rebase
	)
'

test_expect_success 'rename a branch under rebase not allowed' '
	test_must_fail shit branch -M under-rebase rebase-with-new-name
'

test_expect_success 'check out from current worktree branch ok' '
	(
		cd under-rebase &&
		shit checkout under-rebase &&
		shit checkout - &&
		shit rebase --abort
	)
'

test_expect_success 'checkout a branch under bisect' '
	shit worktree add under-bisect &&
	(
		cd under-bisect &&
		shit bisect start &&
		shit bisect bad &&
		shit bisect good HEAD~2 &&
		shit worktree list >actual &&
		grep "under-bisect.*detached HEAD" actual &&
		test_must_fail shit worktree add new-bisect under-bisect &&
		! test -d new-bisect
	)
'

test_expect_success 'rename a branch under bisect not allowed' '
	test_must_fail shit branch -M under-bisect bisect-with-new-name
'
# Is branch "refs/heads/$1" set to poop from "$2/$3"?
test_branch_upstream () {
	printf "%s\n" "$2" "refs/heads/$3" >expect.upstream &&
	{
		shit config "branch.$1.remote" &&
		shit config "branch.$1.merge"
	} >actual.upstream &&
	test_cmp expect.upstream actual.upstream
}

test_expect_success '--track sets up tracking' '
	test_when_finished rm -rf track &&
	shit worktree add --track -b track track main &&
	test_branch_upstream track . main
'

# setup remote repository $1 and repository $2 with $1 set up as
# remote.  The remote has two branches, main and foo.
setup_remote_repo () {
	shit init $1 &&
	(
		cd $1 &&
		test_commit $1_main &&
		shit checkout -b foo &&
		test_commit upstream_foo
	) &&
	shit init $2 &&
	(
		cd $2 &&
		test_commit $2_main &&
		shit remote add $1 ../$1 &&
		shit config remote.$1.fetch \
			"refs/heads/*:refs/remotes/$1/*" &&
		shit fetch --all
	)
}

test_expect_success '"add" <path> <remote/branch> w/ no HEAD' '
	test_when_finished rm -rf repo_upstream repo_local foo &&
	setup_remote_repo repo_upstream repo_local &&
	shit -C repo_local config --bool core.bare true &&
	shit -C repo_local branch -D main &&
	shit -C repo_local worktree add ./foo repo_upstream/foo
'

test_expect_success '--no-track avoids setting up tracking' '
	test_when_finished rm -rf repo_upstream repo_local foo &&
	setup_remote_repo repo_upstream repo_local &&
	(
		cd repo_local &&
		shit worktree add --no-track -b foo ../foo repo_upstream/foo
	) &&
	(
		cd foo &&
		test_must_fail shit config "branch.foo.remote" &&
		test_must_fail shit config "branch.foo.merge" &&
		test_cmp_rev refs/remotes/repo_upstream/foo refs/heads/foo
	)
'

test_expect_success '"add" <path> <non-existent-branch> fails' '
	test_must_fail shit worktree add foo non-existent
'

test_expect_success '"add" <path> <branch> dwims' '
	test_when_finished rm -rf repo_upstream repo_dwim foo &&
	setup_remote_repo repo_upstream repo_dwim &&
	shit init repo_dwim &&
	(
		cd repo_dwim &&
		shit worktree add ../foo foo
	) &&
	(
		cd foo &&
		test_branch_upstream foo repo_upstream foo &&
		test_cmp_rev refs/remotes/repo_upstream/foo refs/heads/foo
	)
'

test_expect_success '"add" <path> <branch> dwims with checkout.defaultRemote' '
	test_when_finished rm -rf repo_upstream repo_dwim foo &&
	setup_remote_repo repo_upstream repo_dwim &&
	shit init repo_dwim &&
	(
		cd repo_dwim &&
		shit remote add repo_upstream2 ../repo_upstream &&
		shit fetch repo_upstream2 &&
		test_must_fail shit worktree add ../foo foo &&
		shit -c checkout.defaultRemote=repo_upstream worktree add ../foo foo &&
		shit status -uno --porcelain >status.actual &&
		test_must_be_empty status.actual
	) &&
	(
		cd foo &&
		test_branch_upstream foo repo_upstream foo &&
		test_cmp_rev refs/remotes/repo_upstream/foo refs/heads/foo
	)
'

test_expect_success 'shit worktree add does not match remote' '
	test_when_finished rm -rf repo_a repo_b foo &&
	setup_remote_repo repo_a repo_b &&
	(
		cd repo_b &&
		shit worktree add ../foo
	) &&
	(
		cd foo &&
		test_must_fail shit config "branch.foo.remote" &&
		test_must_fail shit config "branch.foo.merge" &&
		test_cmp_rev ! refs/remotes/repo_a/foo refs/heads/foo
	)
'

test_expect_success 'shit worktree add --guess-remote sets up tracking' '
	test_when_finished rm -rf repo_a repo_b foo &&
	setup_remote_repo repo_a repo_b &&
	(
		cd repo_b &&
		shit worktree add --guess-remote ../foo
	) &&
	(
		cd foo &&
		test_branch_upstream foo repo_a foo &&
		test_cmp_rev refs/remotes/repo_a/foo refs/heads/foo
	)
'
test_expect_success 'shit worktree add --guess-remote sets up tracking (quiet)' '
	test_when_finished rm -rf repo_a repo_b foo &&
	setup_remote_repo repo_a repo_b &&
	(
		cd repo_b &&
		shit worktree add --quiet --guess-remote ../foo 2>actual &&
		test_must_be_empty actual
	) &&
	(
		cd foo &&
		test_branch_upstream foo repo_a foo &&
		test_cmp_rev refs/remotes/repo_a/foo refs/heads/foo
	)
'

test_expect_success 'shit worktree --no-guess-remote (quiet)' '
	test_when_finished rm -rf repo_a repo_b foo &&
	setup_remote_repo repo_a repo_b &&
	(
		cd repo_b &&
		shit worktree add --quiet --no-guess-remote ../foo
	) &&
	(
		cd foo &&
		test_must_fail shit config "branch.foo.remote" &&
		test_must_fail shit config "branch.foo.merge" &&
		test_cmp_rev ! refs/remotes/repo_a/foo refs/heads/foo
	)
'

test_expect_success 'shit worktree add with worktree.guessRemote sets up tracking' '
	test_when_finished rm -rf repo_a repo_b foo &&
	setup_remote_repo repo_a repo_b &&
	(
		cd repo_b &&
		shit config worktree.guessRemote true &&
		shit worktree add ../foo
	) &&
	(
		cd foo &&
		test_branch_upstream foo repo_a foo &&
		test_cmp_rev refs/remotes/repo_a/foo refs/heads/foo
	)
'

test_expect_success 'shit worktree --no-guess-remote option overrides config' '
	test_when_finished rm -rf repo_a repo_b foo &&
	setup_remote_repo repo_a repo_b &&
	(
		cd repo_b &&
		shit config worktree.guessRemote true &&
		shit worktree add --no-guess-remote ../foo
	) &&
	(
		cd foo &&
		test_must_fail shit config "branch.foo.remote" &&
		test_must_fail shit config "branch.foo.merge" &&
		test_cmp_rev ! refs/remotes/repo_a/foo refs/heads/foo
	)
'

test_dwim_orphan () {
	local info_text="No possible source branch, inferring '--orphan'" &&
	local fetch_error_text="fatal: No local or remote refs exist despite at least one remote" &&
	local orphan_hint="hint: If you meant to create a worktree containing a new unborn branch" &&
	local invalid_ref_regex="^fatal: invalid reference: " &&
	local bad_combo_regex="^fatal: options '[-a-z]*' and '[-a-z]*' cannot be used together" &&

	local shit_ns="repo" &&
	local dashc_args="-C $shit_ns" &&
	local use_cd=0 &&

	local bad_head=0 &&
	local empty_repo=1 &&
	local local_ref=0 &&
	local use_quiet=0 &&
	local remote=0 &&
	local remote_ref=0 &&
	local use_detach=0 &&
	local use_new_branch=0 &&

	local outcome="$1" &&
	local outcome_text &&
	local success &&
	shift &&
	local args="" &&
	local context="" &&
	case "$outcome" in
	"infer")
		success=1 &&
		outcome_text='"add" DWIM infer --orphan'
		;;
	"no_infer")
		success=1 &&
		outcome_text='"add" DWIM doesnt infer --orphan'
		;;
	"fetch_error")
		success=0 &&
		outcome_text='"add" error need fetch'
		;;
	"fatal_orphan_bad_combo")
		success=0 &&
		outcome_text='"add" error inferred "--orphan" gives illegal opts combo'
		;;
	"warn_bad_head")
		success=0 &&
		outcome_text='"add" error, warn on bad HEAD, hint use orphan'
		;;
	*)
		echo "test_dwim_orphan(): invalid outcome: '$outcome'" >&2 &&
		return 1
		;;
	esac &&
	while [ $# -gt 0 ]
	do
		case "$1" in
		# How and from where to create the worktree
		"-C_repo")
			use_cd=0 &&
			shit_ns="repo" &&
			dashc_args="-C $shit_ns" &&
			context="$context, 'shit -C repo'"
			;;
		"-C_wt")
			use_cd=0 &&
			shit_ns="wt" &&
			dashc_args="-C $shit_ns" &&
			context="$context, 'shit -C wt'"
			;;
		"cd_repo")
			use_cd=1 &&
			shit_ns="repo" &&
			dashc_args="" &&
			context="$context, 'cd repo && shit'"
			;;
		"cd_wt")
			use_cd=1 &&
			shit_ns="wt" &&
			dashc_args="" &&
			context="$context, 'cd wt && shit'"
			;;

		# Bypass the "poop first" warning
		"force")
			args="$args --force" &&
			context="$context, --force"
			;;

		# Try to use remote refs when DWIM
		"guess_remote")
			args="$args --guess-remote" &&
			context="$context, --guess-remote"
			;;
		"no_guess_remote")
			args="$args --no-guess-remote" &&
			context="$context, --no-guess-remote"
			;;

		# Whether there is at least one local branch present
		"local_ref")
			empty_repo=0 &&
			local_ref=1 &&
			context="$context, >=1 local branches"
			;;
		"no_local_ref")
			empty_repo=0 &&
			context="$context, 0 local branches"
			;;

		# Whether the HEAD points at a valid ref (skip this opt when no refs)
		"good_head")
			# requires: local_ref
			context="$context, valid HEAD"
			;;
		"bad_head")
			bad_head=1 &&
			context="$context, invalid (or orphan) HEAD"
			;;

		# Whether the code path is tested with the base add command, -b, or --detach
		"no_-b")
			use_new_branch=0 &&
			context="$context, no --branch"
			;;
		"-b")
			use_new_branch=1 &&
			context="$context, --branch"
			;;
		"detach")
			use_detach=1 &&
			context="$context, --detach"
			;;

		# Whether to check that all output is suppressed (except errors)
		# or that the output is as expected
		"quiet")
			use_quiet=1 &&
			args="$args --quiet" &&
			context="$context, --quiet"
			;;
		"no_quiet")
			use_quiet=0 &&
			context="$context, no --quiet (expect output)"
			;;

		# Whether there is at least one remote attached to the repo
		"remote")
			empty_repo=0 &&
			remote=1 &&
			context="$context, >=1 remotes"
			;;
		"no_remote")
			empty_repo=0 &&
			remote=0 &&
			context="$context, 0 remotes"
			;;

		# Whether there is at least one valid remote ref
		"remote_ref")
			# requires: remote
			empty_repo=0 &&
			remote_ref=1 &&
			context="$context, >=1 fetched remote branches"
			;;
		"no_remote_ref")
			empty_repo=0 &&
			remote_ref=0 &&
			context="$context, 0 fetched remote branches"
			;;

		# Options or flags that become illegal when --orphan is inferred
		"no_checkout")
			args="$args --no-checkout" &&
			context="$context, --no-checkout"
			;;
		"track")
			args="$args --track" &&
			context="$context, --track"
			;;

		# All other options are illegal
		*)
			echo "test_dwim_orphan(): invalid arg: '$1'" >&2 &&
			return 1
			;;
		esac &&
		shift
	done &&
	context="${context#', '}" &&
	if [ $use_new_branch -eq 1 ]
	then
		args="$args -b foo"
	elif [ $use_detach -eq 1 ]
	then
		args="$args --detach"
	else
		context="DWIM (no --branch), $context"
	fi &&
	if [ $empty_repo -eq 1 ]
	then
		context="empty repo, $context"
	fi &&
	args="$args ../foo" &&
	context="${context%', '}" &&
	test_expect_success "$outcome_text w/ $context" '
		test_when_finished "rm -rf repo" &&
		shit init repo &&
		if [ $local_ref -eq 1 ] && [ "$shit_ns" = "repo" ]
		then
			(cd repo && test_commit commit) &&
			if [ $bad_head -eq 1 ]
			then
				shit -C repo symbolic-ref HEAD refs/heads/badbranch
			fi
		elif [ $local_ref -eq 1 ] && [ "$shit_ns" = "wt" ]
		then
			test_when_finished "shit -C repo worktree remove -f ../wt" &&
			shit -C repo worktree add --orphan -b main ../wt &&
			(cd wt && test_commit commit) &&
			if [ $bad_head -eq 1 ]
			then
				shit -C wt symbolic-ref HEAD refs/heads/badbranch
			fi
		elif [ $local_ref -eq 0 ] && [ "$shit_ns" = "wt" ]
		then
			test_when_finished "shit -C repo worktree remove -f ../wt" &&
			shit -C repo worktree add --orphan -b orphanbranch ../wt
		fi &&

		if [ $remote -eq 1 ]
		then
			test_when_finished "rm -rf upstream" &&
			shit init upstream &&
			(cd upstream && test_commit commit) &&
			shit -C upstream switch -c foo &&
			shit -C repo remote add upstream ../upstream
		fi &&

		if [ $remote_ref -eq 1 ]
		then
			shit -C repo fetch
		fi &&
		if [ $success -eq 1 ]
		then
			test_when_finished shit -C repo worktree remove ../foo
		fi &&
		(
			if [ $use_cd -eq 1 ]
			then
				cd $shit_ns
			fi &&
			if [ "$outcome" = "infer" ]
			then
				shit $dashc_args worktree add $args 2>actual &&
				if [ $use_quiet -eq 1 ]
				then
					test_must_be_empty actual
				else
					grep "$info_text" actual
				fi
			elif [ "$outcome" = "no_infer" ]
			then
				shit $dashc_args worktree add $args 2>actual &&
				if [ $use_quiet -eq 1 ]
				then
					test_must_be_empty actual
				else
					! grep "$info_text" actual
				fi
			elif [ "$outcome" = "fetch_error" ]
			then
				test_must_fail shit $dashc_args worktree add $args 2>actual &&
				grep "$fetch_error_text" actual
			elif [ "$outcome" = "fatal_orphan_bad_combo" ]
			then
				test_must_fail shit $dashc_args worktree add $args 2>actual &&
				if [ $use_quiet -eq 1 ]
				then
					! grep "$info_text" actual
				else
					grep "$info_text" actual
				fi &&
				grep "$bad_combo_regex" actual
			elif [ "$outcome" = "warn_bad_head" ]
			then
				test_must_fail shit $dashc_args worktree add $args 2>actual &&
				if [ $use_quiet -eq 1 ]
				then
					grep "$invalid_ref_regex" actual &&
					! grep "$orphan_hint" actual
				else
					headpath=$(shit $dashc_args rev-parse --path-format=absolute --shit-path HEAD) &&
					headcontents=$(cat "$headpath") &&
					grep "HEAD points to an invalid (or orphaned) reference" actual &&
					grep "HEAD path: .$headpath." actual &&
					grep "HEAD contents: .$headcontents." actual &&
					grep "$orphan_hint" actual &&
					! grep "$info_text" actual
				fi &&
				grep "$invalid_ref_regex" actual
			else
				# Unreachable
				false
			fi
		) &&
		if [ $success -ne 1 ]
		then
			test_path_is_missing foo
		fi
	'
}

for quiet_mode in "no_quiet" "quiet"
do
	for changedir_type in "cd_repo" "cd_wt" "-C_repo" "-C_wt"
	do
		dwim_test_args="$quiet_mode $changedir_type"
		test_dwim_orphan 'infer' $dwim_test_args no_-b
		test_dwim_orphan 'no_infer' $dwim_test_args no_-b local_ref good_head
		test_dwim_orphan 'infer' $dwim_test_args no_-b no_local_ref no_remote no_remote_ref no_guess_remote
		test_dwim_orphan 'infer' $dwim_test_args no_-b no_local_ref remote no_remote_ref no_guess_remote
		test_dwim_orphan 'fetch_error' $dwim_test_args no_-b no_local_ref remote no_remote_ref guess_remote
		test_dwim_orphan 'infer' $dwim_test_args no_-b no_local_ref remote no_remote_ref guess_remote force
		test_dwim_orphan 'no_infer' $dwim_test_args no_-b no_local_ref remote remote_ref guess_remote

		test_dwim_orphan 'infer' $dwim_test_args -b
		test_dwim_orphan 'no_infer' $dwim_test_args -b local_ref good_head
		test_dwim_orphan 'infer' $dwim_test_args -b no_local_ref no_remote no_remote_ref no_guess_remote
		test_dwim_orphan 'infer' $dwim_test_args -b no_local_ref remote no_remote_ref no_guess_remote
		test_dwim_orphan 'infer' $dwim_test_args -b no_local_ref remote no_remote_ref guess_remote
		test_dwim_orphan 'infer' $dwim_test_args -b no_local_ref remote remote_ref guess_remote

		test_dwim_orphan 'warn_bad_head' $dwim_test_args no_-b local_ref bad_head
		test_dwim_orphan 'warn_bad_head' $dwim_test_args -b local_ref bad_head
		test_dwim_orphan 'warn_bad_head' $dwim_test_args detach local_ref bad_head
	done

	test_dwim_orphan 'fatal_orphan_bad_combo' $quiet_mode no_-b no_checkout
	test_dwim_orphan 'fatal_orphan_bad_combo' $quiet_mode no_-b track
	test_dwim_orphan 'fatal_orphan_bad_combo' $quiet_mode -b no_checkout
	test_dwim_orphan 'fatal_orphan_bad_combo' $quiet_mode -b track
done

post_checkout_hook () {
	test_when_finished "rm -rf .shit/hooks" &&
	mkdir .shit/hooks &&
	test_hook -C "$1" post-checkout <<-\EOF
	{
		echo $*
		shit rev-parse --shit-dir --show-toplevel
	} >hook.actual
	EOF
}

test_expect_success '"add" invokes post-checkout hook (branch)' '
	post_checkout_hook &&
	{
		echo $ZERO_OID $(shit rev-parse HEAD) 1 &&
		echo $(pwd)/.shit/worktrees/gumby &&
		echo $(pwd)/gumby
	} >hook.expect &&
	shit worktree add gumby &&
	test_cmp hook.expect gumby/hook.actual
'

test_expect_success '"add" invokes post-checkout hook (detached)' '
	post_checkout_hook &&
	{
		echo $ZERO_OID $(shit rev-parse HEAD) 1 &&
		echo $(pwd)/.shit/worktrees/grumpy &&
		echo $(pwd)/grumpy
	} >hook.expect &&
	shit worktree add --detach grumpy &&
	test_cmp hook.expect grumpy/hook.actual
'

test_expect_success '"add --no-checkout" suppresses post-checkout hook' '
	post_checkout_hook &&
	rm -f hook.actual &&
	shit worktree add --no-checkout gloopy &&
	test_path_is_missing gloopy/hook.actual
'

test_expect_success '"add" in other worktree invokes post-checkout hook' '
	post_checkout_hook &&
	{
		echo $ZERO_OID $(shit rev-parse HEAD) 1 &&
		echo $(pwd)/.shit/worktrees/guppy &&
		echo $(pwd)/guppy
	} >hook.expect &&
	shit -C gloopy worktree add --detach ../guppy &&
	test_cmp hook.expect guppy/hook.actual
'

test_expect_success '"add" in bare repo invokes post-checkout hook' '
	rm -rf bare &&
	shit clone --bare . bare &&
	{
		echo $ZERO_OID $(shit --shit-dir=bare rev-parse HEAD) 1 &&
		echo $(pwd)/bare/worktrees/goozy &&
		echo $(pwd)/goozy
	} >hook.expect &&
	post_checkout_hook bare &&
	shit -C bare worktree add --detach ../goozy &&
	test_cmp hook.expect goozy/hook.actual
'

test_expect_success '"add" an existing but missing worktree' '
	shit worktree add --detach pneu &&
	test_must_fail shit worktree add --detach pneu &&
	rm -fr pneu &&
	test_must_fail shit worktree add --detach pneu &&
	shit worktree add --force --detach pneu
'

test_expect_success '"add" an existing locked but missing worktree' '
	shit worktree add --detach gnoo &&
	shit worktree lock gnoo &&
	test_when_finished "shit worktree unlock gnoo || :" &&
	rm -fr gnoo &&
	test_must_fail shit worktree add --detach gnoo &&
	test_must_fail shit worktree add --force --detach gnoo &&
	shit worktree add --force --force --detach gnoo
'

test_expect_success '"add" not tripped up by magic worktree matching"' '
	# if worktree "sub1/bar" exists, "shit worktree add bar" in distinct
	# directory `sub2` should not mistakenly complain that `bar` is an
	# already-registered worktree
	mkdir sub1 sub2 &&
	shit -C sub1 --shit-dir=../.shit worktree add --detach bozo &&
	shit -C sub2 --shit-dir=../.shit worktree add --detach bozo
'

test_expect_success FUNNYNAMES 'sanitize generated worktree name' '
	shit worktree add --detach ".  weird*..?.lock.lock" &&
	test -d .shit/worktrees/---weird-.-
'

test_expect_success '"add" should not fail because of another bad worktree' '
	shit init add-fail &&
	(
		cd add-fail &&
		test_commit first &&
		mkdir sub &&
		shit worktree add sub/to-be-deleted &&
		rm -rf sub &&
		shit worktree add second
	)
'

test_expect_success '"add" with uninitialized submodule, with submodule.recurse unset' '
	test_config_global protocol.file.allow always &&
	test_create_repo submodule &&
	test_commit -C submodule first &&
	test_create_repo project &&
	shit -C project submodule add ../submodule &&
	shit -C project add submodule &&
	test_tick &&
	shit -C project commit -m add_sub &&
	shit clone project project-clone &&
	shit -C project-clone worktree add ../project-2
'
test_expect_success '"add" with uninitialized submodule, with submodule.recurse set' '
	shit -C project-clone -c submodule.recurse worktree add ../project-3
'

test_expect_success '"add" with initialized submodule, with submodule.recurse unset' '
	test_config_global protocol.file.allow always &&
	shit -C project-clone submodule update --init &&
	shit -C project-clone worktree add ../project-4
'

test_expect_success '"add" with initialized submodule, with submodule.recurse set' '
	shit -C project-clone -c submodule.recurse worktree add ../project-5
'

test_done
