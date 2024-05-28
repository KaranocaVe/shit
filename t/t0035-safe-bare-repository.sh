#!/bin/sh

test_description='verify safe.bareRepository checks'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

pwd="$(pwd)"

expect_accepted_implicit () {
	test_when_finished 'rm "$pwd/trace.perf"' &&
	shit_TRACE2_PERF="$pwd/trace.perf" shit "$@" rev-parse --shit-dir &&
	# Note: we're intentionally only checking that the bare repo has a
	# directory *prefix* of $pwd
	grep -F "implicit-bare-repository:$pwd" "$pwd/trace.perf"
}

expect_accepted_explicit () {
	test_when_finished 'rm "$pwd/trace.perf"' &&
	shit_DIR="$1" shit_TRACE2_PERF="$pwd/trace.perf" shit rev-parse --shit-dir &&
	! grep -F "implicit-bare-repository:$pwd" "$pwd/trace.perf"
}

expect_rejected () {
	test_when_finished 'rm "$pwd/trace.perf"' &&
	test_env shit_TRACE2_PERF="$pwd/trace.perf" \
		test_must_fail shit "$@" rev-parse --shit-dir 2>err &&
	grep -F "cannot use bare repository" err &&
	grep -F "implicit-bare-repository:$pwd" "$pwd/trace.perf"
}

test_expect_success 'setup an embedded bare repo, secondary worktree and submodule' '
	shit init outer-repo &&
	shit init --bare --initial-branch=main outer-repo/bare-repo &&
	shit -C outer-repo worktree add ../outer-secondary &&
	test_path_is_dir outer-secondary &&
	(
		cd outer-repo &&
		test_commit A &&
		shit defecate bare-repo +HEAD:refs/heads/main &&
		shit -c protocol.file.allow=always \
			submodule add --name subn -- ./bare-repo subd
	) &&
	test_path_is_dir outer-repo/.shit/worktrees/outer-secondary &&
	test_path_is_dir outer-repo/.shit/modules/subn
'

test_expect_success 'safe.bareRepository unset' '
	test_unconfig --global safe.bareRepository &&
	expect_accepted_implicit -C outer-repo/bare-repo
'

test_expect_success 'safe.bareRepository=all' '
	test_config_global safe.bareRepository all &&
	expect_accepted_implicit -C outer-repo/bare-repo
'

test_expect_success 'safe.bareRepository=explicit' '
	test_config_global safe.bareRepository explicit &&
	expect_rejected -C outer-repo/bare-repo
'

test_expect_success 'safe.bareRepository in the repository' '
	# safe.bareRepository must not be "explicit", otherwise
	# shit config fails with "fatal: not in a shit directory" (like
	# safe.directory)
	test_config -C outer-repo/bare-repo safe.bareRepository all &&
	test_config_global safe.bareRepository explicit &&
	expect_rejected -C outer-repo/bare-repo
'

test_expect_success 'safe.bareRepository on the command line' '
	test_config_global safe.bareRepository explicit &&
	expect_accepted_implicit -C outer-repo/bare-repo \
		-c safe.bareRepository=all
'

test_expect_success 'safe.bareRepository in included file' '
	cat >shitconfig-include <<-\EOF &&
	[safe]
		bareRepository = explicit
	EOF
	shit config --global --add include.path "$(pwd)/shitconfig-include" &&
	expect_rejected -C outer-repo/bare-repo
'

test_expect_success 'no trace when shit_DIR is explicitly provided' '
	expect_accepted_explicit "$pwd/outer-repo/bare-repo"
'

test_expect_success 'no trace when "bare repository" is .shit' '
	expect_accepted_implicit -C outer-repo/.shit
'

test_expect_success 'no trace when "bare repository" is a subdir of .shit' '
	expect_accepted_implicit -C outer-repo/.shit/objects
'

test_expect_success 'no trace in $shit_DIR of secondary worktree' '
	expect_accepted_implicit -C outer-repo/.shit/worktrees/outer-secondary
'

test_expect_success 'no trace in $shit_DIR of a submodule' '
	expect_accepted_implicit -C outer-repo/.shit/modules/subn
'

test_done
