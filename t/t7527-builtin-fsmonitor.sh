#!/bin/sh

test_description='built-in file system watcher'

. ./test-lib.sh

if ! test_have_prereq FSMONITOR_DAEMON
then
	skip_all="fsmonitor--daemon is not supported on this platform"
	test_done
fi

stop_daemon_delete_repo () {
	r=$1 &&
	test_might_fail shit -C $r fsmonitor--daemon stop &&
	rm -rf $1
}

start_daemon () {
	r= tf= t2= tk= &&

	while test "$#" -ne 0
	do
		case "$1" in
		-C)
			r="-C ${2?}"
			shift
			;;
		--tf)
			tf="${2?}"
			shift
			;;
		--t2)
			t2="${2?}"
			shift
			;;
		--tk)
			tk="${2?}"
			shift
			;;
		-*)
			BUG "error: unknown option: '$1'"
			;;
		*)
			BUG "error: unbound argument: '$1'"
			;;
		esac
		shift
	done &&

	(
		if test -n "$tf"
		then
			shit_TRACE_FSMONITOR="$tf"
			export shit_TRACE_FSMONITOR
		fi &&

		if test -n "$t2"
		then
			shit_TRACE2_PERF="$t2"
			export shit_TRACE2_PERF
		fi &&

		if test -n "$tk"
		then
			shit_TEST_FSMONITOR_TOKEN="$tk"
			export shit_TEST_FSMONITOR_TOKEN
		fi &&

		shit $r fsmonitor--daemon start &&
		shit $r fsmonitor--daemon status
	)
}

# Is a Trace2 data event present with the given catetory and key?
# We do not care what the value is.
#
have_t2_data_event () {
	c=$1 &&
	k=$2 &&

	grep -e '"event":"data".*"category":"'"$c"'".*"key":"'"$k"'"'
}

test_expect_success 'explicit daemon start and stop' '
	test_when_finished "stop_daemon_delete_repo test_explicit" &&

	shit init test_explicit &&
	start_daemon -C test_explicit &&

	shit -C test_explicit fsmonitor--daemon stop &&
	test_must_fail shit -C test_explicit fsmonitor--daemon status
'

test_expect_success 'implicit daemon start' '
	test_when_finished "stop_daemon_delete_repo test_implicit" &&

	shit init test_implicit &&
	test_must_fail shit -C test_implicit fsmonitor--daemon status &&

	# query will implicitly start the daemon.
	#
	# for test-script simplicity, we send a V1 timestamp rather than
	# a V2 token.  either way, the daemon response to any query contains
	# a new V2 token.  (the daemon may complain that we sent a V1 request,
	# but this test case is only concerned with whether the daemon was
	# implicitly started.)

	shit_TRACE2_EVENT="$PWD/.shit/trace" \
		test-tool -C test_implicit fsmonitor-client query --token 0 >actual &&
	nul_to_q <actual >actual.filtered &&
	grep "builtin:" actual.filtered &&

	# confirm that a daemon was started in the background.
	#
	# since the mechanism for starting the background daemon is platform
	# dependent, just confirm that the foreground command received a
	# response from the daemon.

	have_t2_data_event fsm_client query/response-length <.shit/trace &&

	shit -C test_implicit fsmonitor--daemon status &&
	shit -C test_implicit fsmonitor--daemon stop &&
	test_must_fail shit -C test_implicit fsmonitor--daemon status
'

# Verify that the daemon has shutdown.  Spin a few seconds to
# make the test a little more robust during CI testing.
#
# We're looking for an implicit shutdown, such as when we delete or
# rename the ".shit" directory.  Our delete/rename will cause a file
# system event that the daemon will see and the daemon will
# auto-shutdown as soon as it sees it.  But this is racy with our `shit
# fsmonitor--daemon status` commands (and we cannot use a cookie file
# here to help us).  So spin a little and give the daemon a chance to
# see the event.  (This is primarily for underpowered CI build/test
# machines (where it might take a moment to wake and reschedule the
# daemon process) to avoid false alarms during test runs.)
#
IMPLICIT_TIMEOUT=5

verify_implicit_shutdown () {
	r=$1 &&

	k=0 &&
	while test "$k" -lt $IMPLICIT_TIMEOUT
	do
		shit -C $r fsmonitor--daemon status || return 0

		sleep 1
		k=$(( $k + 1 ))
	done &&

	return 1
}

test_expect_success 'implicit daemon stop (delete .shit)' '
	test_when_finished "stop_daemon_delete_repo test_implicit_1" &&

	shit init test_implicit_1 &&

	start_daemon -C test_implicit_1 &&

	# deleting the .shit directory will implicitly stop the daemon.
	rm -rf test_implicit_1/.shit &&

	# [1] Create an empty .shit directory so that the following shit
	#     command will stay relative to the `-C` directory.
	#
	#     Without this, the shit command will override the requested
	#     -C argument and crawl out to the containing shit source tree.
	#     This would make the test result dependent upon whether we
	#     were using fsmonitor on our development worktree.
	#
	mkdir test_implicit_1/.shit &&

	verify_implicit_shutdown test_implicit_1
'

test_expect_success 'implicit daemon stop (rename .shit)' '
	test_when_finished "stop_daemon_delete_repo test_implicit_2" &&

	shit init test_implicit_2 &&

	start_daemon -C test_implicit_2 &&

	# renaming the .shit directory will implicitly stop the daemon.
	mv test_implicit_2/.shit test_implicit_2/.xxx &&

	# See [1] above.
	#
	mkdir test_implicit_2/.shit &&

	verify_implicit_shutdown test_implicit_2
'

# File systems on Windows may or may not have shortnames.
# This is a volume-specific setting on modern systems.
# "C:/" drives are required to have them enabled.  Other
# hard drives default to disabled.
#
# This is a crude test to see if shortnames are enabled
# on the volume containing the test directory.  It is
# crude, but it does not require elevation like `fsutil`.
#
test_lazy_prereq SHORTNAMES '
	mkdir .foo &&
	test -d "FOO~1"
'

# Here we assume that the shortname of ".shit" is "shit~1".
test_expect_success MINGW,SHORTNAMES 'implicit daemon stop (rename shit~1)' '
	test_when_finished "stop_daemon_delete_repo test_implicit_1s" &&

	shit init test_implicit_1s &&

	start_daemon -C test_implicit_1s &&

	# renaming the .shit directory will implicitly stop the daemon.
	# this moves {.shit, shit~1} to {.shitxyz, shitXYZ~1}.
	# the rename-from FS Event will contain the shortname.
	#
	mv test_implicit_1s/shit~1 test_implicit_1s/.shitxyz &&

	# See [1] above.
	# this moves {.shitxyz, shitXYZ~1} to {.shit, shit~1}.
	mv test_implicit_1s/.shitxyz test_implicit_1s/.shit &&

	verify_implicit_shutdown test_implicit_1s
'

# Here we first create a file with LONGNAME of "shit~1" before
# we create the repo.  This will cause the shortname of ".shit"
# to be "shit~2".
test_expect_success MINGW,SHORTNAMES 'implicit daemon stop (rename shit~2)' '
	test_when_finished "stop_daemon_delete_repo test_implicit_1s2" &&

	mkdir test_implicit_1s2 &&
	echo HELLO >test_implicit_1s2/shit~1 &&
	shit init test_implicit_1s2 &&

	test_path_is_file test_implicit_1s2/shit~1 &&
	test_path_is_dir  test_implicit_1s2/shit~2 &&

	start_daemon -C test_implicit_1s2 &&

	# renaming the .shit directory will implicitly stop the daemon.
	# the rename-from FS Event will contain the shortname.
	#
	mv test_implicit_1s2/shit~2 test_implicit_1s2/.shitxyz &&

	# See [1] above.
	mv test_implicit_1s2/.shitxyz test_implicit_1s2/.shit &&

	verify_implicit_shutdown test_implicit_1s2
'

test_expect_success 'cannot start multiple daemons' '
	test_when_finished "stop_daemon_delete_repo test_multiple" &&

	shit init test_multiple &&

	start_daemon -C test_multiple &&

	test_must_fail shit -C test_multiple fsmonitor--daemon start 2>actual &&
	grep "fsmonitor--daemon is already running" actual &&

	shit -C test_multiple fsmonitor--daemon stop &&
	test_must_fail shit -C test_multiple fsmonitor--daemon status
'

# These tests use the main repo in the trash directory

test_expect_success 'setup' '
	>tracked &&
	>modified &&
	>delete &&
	>rename &&
	mkdir dir1 &&
	>dir1/tracked &&
	>dir1/modified &&
	>dir1/delete &&
	>dir1/rename &&
	mkdir dir2 &&
	>dir2/tracked &&
	>dir2/modified &&
	>dir2/delete &&
	>dir2/rename &&
	mkdir dirtorename &&
	>dirtorename/a &&
	>dirtorename/b &&

	cat >.shitignore <<-\EOF &&
	.shitignore
	expect*
	actual*
	flush*
	trace*
	EOF

	mkdir -p T1/T2/T3/T4 &&
	echo 1 >T1/F1 &&
	echo 1 >T1/T2/F1 &&
	echo 1 >T1/T2/T3/F1 &&
	echo 1 >T1/T2/T3/T4/F1 &&
	echo 2 >T1/F2 &&
	echo 2 >T1/T2/F2 &&
	echo 2 >T1/T2/T3/F2 &&
	echo 2 >T1/T2/T3/T4/F2 &&

	shit -c core.fsmonitor=false add . &&
	test_tick &&
	shit -c core.fsmonitor=false commit -m initial &&

	shit config core.fsmonitor true
'

# The test already explicitly stopped (or tried to stop) the daemon.
# This is here in case something else fails first.
#
redundant_stop_daemon () {
	test_might_fail shit fsmonitor--daemon stop
}

test_expect_success 'update-index implicitly starts daemon' '
	test_when_finished redundant_stop_daemon &&

	test_must_fail shit fsmonitor--daemon status &&

	shit_TRACE2_EVENT="$PWD/.shit/trace_implicit_1" \
		shit update-index --fsmonitor &&

	shit fsmonitor--daemon status &&
	test_might_fail shit fsmonitor--daemon stop &&

	# Confirm that the trace2 log contains a record of the
	# daemon starting.
	test_subcommand shit fsmonitor--daemon start <.shit/trace_implicit_1
'

test_expect_success 'status implicitly starts daemon' '
	test_when_finished redundant_stop_daemon &&

	test_must_fail shit fsmonitor--daemon status &&

	shit_TRACE2_EVENT="$PWD/.shit/trace_implicit_2" \
		shit status >actual &&

	shit fsmonitor--daemon status &&
	test_might_fail shit fsmonitor--daemon stop &&

	# Confirm that the trace2 log contains a record of the
	# daemon starting.
	test_subcommand shit fsmonitor--daemon start <.shit/trace_implicit_2
'

edit_files () {
	echo 1 >modified &&
	echo 2 >dir1/modified &&
	echo 3 >dir2/modified &&
	>dir1/untracked
}

delete_files () {
	rm -f delete &&
	rm -f dir1/delete &&
	rm -f dir2/delete
}

create_files () {
	echo 1 >new &&
	echo 2 >dir1/new &&
	echo 3 >dir2/new
}

rename_files () {
	mv rename renamed &&
	mv dir1/rename dir1/renamed &&
	mv dir2/rename dir2/renamed
}

file_to_directory () {
	rm -f delete &&
	mkdir delete &&
	echo 1 >delete/new
}

directory_to_file () {
	rm -rf dir1 &&
	echo 1 >dir1
}

move_directory_contents_deeper() {
	mkdir T1/_new_ &&
	mv T1/[A-Z]* T1/_new_
}

move_directory_up() {
	mv T1/T2/T3 T1
}

move_directory() {
	mv T1/T2/T3 T1/T2/NewT3
}

# The next few test cases confirm that our fsmonitor daemon sees each type
# of OS filesystem notification that we care about.  At this layer we just
# ensure we are getting the OS notifications and do not try to confirm what
# is reported by `shit status`.
#
# We run a simple query after modifying the filesystem just to introduce
# a bit of a delay so that the trace logging from the daemon has time to
# get flushed to disk.
#
# We `reset` and `clean` at the bottom of each test (and before stopping the
# daemon) because these commands might implicitly restart the daemon.

clean_up_repo_and_stop_daemon () {
	shit reset --hard HEAD &&
	shit clean -fd &&
	test_might_fail shit fsmonitor--daemon stop &&
	rm -f .shit/trace
}

test_expect_success 'edit some files' '
	test_when_finished clean_up_repo_and_stop_daemon &&

	start_daemon --tf "$PWD/.shit/trace" &&

	edit_files &&

	test-tool fsmonitor-client query --token 0 &&

	grep "^event: dir1/modified$"  .shit/trace &&
	grep "^event: dir2/modified$"  .shit/trace &&
	grep "^event: modified$"       .shit/trace &&
	grep "^event: dir1/untracked$" .shit/trace
'

test_expect_success 'create some files' '
	test_when_finished clean_up_repo_and_stop_daemon &&

	start_daemon --tf "$PWD/.shit/trace" &&

	create_files &&

	test-tool fsmonitor-client query --token 0 &&

	grep "^event: dir1/new$" .shit/trace &&
	grep "^event: dir2/new$" .shit/trace &&
	grep "^event: new$"      .shit/trace
'

test_expect_success 'delete some files' '
	test_when_finished clean_up_repo_and_stop_daemon &&

	start_daemon --tf "$PWD/.shit/trace" &&

	delete_files &&

	test-tool fsmonitor-client query --token 0 &&

	grep "^event: dir1/delete$" .shit/trace &&
	grep "^event: dir2/delete$" .shit/trace &&
	grep "^event: delete$"      .shit/trace
'

test_expect_success 'rename some files' '
	test_when_finished clean_up_repo_and_stop_daemon &&

	start_daemon --tf "$PWD/.shit/trace" &&

	rename_files &&

	test-tool fsmonitor-client query --token 0 &&

	grep "^event: dir1/rename$"  .shit/trace &&
	grep "^event: dir2/rename$"  .shit/trace &&
	grep "^event: rename$"       .shit/trace &&
	grep "^event: dir1/renamed$" .shit/trace &&
	grep "^event: dir2/renamed$" .shit/trace &&
	grep "^event: renamed$"      .shit/trace
'

test_expect_success 'rename directory' '
	test_when_finished clean_up_repo_and_stop_daemon &&

	start_daemon --tf "$PWD/.shit/trace" &&

	mv dirtorename dirrenamed &&

	test-tool fsmonitor-client query --token 0 &&

	grep "^event: dirtorename/*$" .shit/trace &&
	grep "^event: dirrenamed/*$"  .shit/trace
'

test_expect_success 'file changes to directory' '
	test_when_finished clean_up_repo_and_stop_daemon &&

	start_daemon --tf "$PWD/.shit/trace" &&

	file_to_directory &&

	test-tool fsmonitor-client query --token 0 &&

	grep "^event: delete$"     .shit/trace &&
	grep "^event: delete/new$" .shit/trace
'

test_expect_success 'directory changes to a file' '
	test_when_finished clean_up_repo_and_stop_daemon &&

	start_daemon --tf "$PWD/.shit/trace" &&

	directory_to_file &&

	test-tool fsmonitor-client query --token 0 &&

	grep "^event: dir1$" .shit/trace
'

# The next few test cases exercise the token-resync code.  When filesystem
# drops events (because of filesystem velocity or because the daemon isn't
# polling fast enough), we need to discard the cached data (relative to the
# current token) and start collecting events under a new token.
#
# the 'test-tool fsmonitor-client flush' command can be used to send a
# "flush" message to a running daemon and ask it to do a flush/resync.

test_expect_success 'flush cached data' '
	test_when_finished "stop_daemon_delete_repo test_flush" &&

	shit init test_flush &&

	start_daemon -C test_flush --tf "$PWD/.shit/trace_daemon" --tk true &&

	# The daemon should have an initial token with no events in _0 and
	# then a few (probably platform-specific number of) events in _1.
	# These should both have the same <token_id>.

	test-tool -C test_flush fsmonitor-client query --token "builtin:test_00000001:0" >actual_0 &&
	nul_to_q <actual_0 >actual_q0 &&

	>test_flush/file_1 &&
	>test_flush/file_2 &&

	test-tool -C test_flush fsmonitor-client query --token "builtin:test_00000001:0" >actual_1 &&
	nul_to_q <actual_1 >actual_q1 &&

	grep "file_1" actual_q1 &&

	# Force a flush.  This will change the <token_id>, reset the <seq_nr>, and
	# flush the file data.  Then create some events and ensure that the file
	# again appears in the cache.  It should have the new <token_id>.

	test-tool -C test_flush fsmonitor-client flush >flush_0 &&
	nul_to_q <flush_0 >flush_q0 &&
	grep "^builtin:test_00000002:0Q/Q$" flush_q0 &&

	test-tool -C test_flush fsmonitor-client query --token "builtin:test_00000002:0" >actual_2 &&
	nul_to_q <actual_2 >actual_q2 &&

	grep "^builtin:test_00000002:0Q$" actual_q2 &&

	>test_flush/file_3 &&

	test-tool -C test_flush fsmonitor-client query --token "builtin:test_00000002:0" >actual_3 &&
	nul_to_q <actual_3 >actual_q3 &&

	grep "file_3" actual_q3
'

# The next few test cases create repos where the .shit directory is NOT
# inside the one of the working directory.  That is, where .shit is a file
# that points to a directory elsewhere.  This happens for submodules and
# non-primary worktrees.

test_expect_success 'setup worktree base' '
	shit init wt-base &&
	echo 1 >wt-base/file1 &&
	shit -C wt-base add file1 &&
	shit -C wt-base commit -m "c1"
'

test_expect_success 'worktree with .shit file' '
	shit -C wt-base worktree add ../wt-secondary &&

	start_daemon -C wt-secondary \
		--tf "$PWD/trace_wt_secondary" \
		--t2 "$PWD/trace2_wt_secondary" &&

	shit -C wt-secondary fsmonitor--daemon stop &&
	test_must_fail shit -C wt-secondary fsmonitor--daemon status
'

# NEEDSWORK: Repeat one of the "edit" tests on wt-secondary and
# confirm that we get the same events and behavior -- that is, that
# fsmonitor--daemon correctly watches BOTH the working directory and
# the external shitDIR directory and behaves the same as when ".shit"
# is a directory inside the working directory.

test_expect_success 'cleanup worktrees' '
	stop_daemon_delete_repo wt-secondary &&
	stop_daemon_delete_repo wt-base
'

# The next few tests perform arbitrary/contrived file operations and
# confirm that status is correct.  That is, that the data (or lack of
# data) from fsmonitor doesn't cause incorrect results.  And doesn't
# cause incorrect results when the untracked-cache is enabled.

test_lazy_prereq UNTRACKED_CACHE '
	shit update-index --test-untracked-cache
'

test_expect_success 'Matrix: setup for untracked-cache,fsmonitor matrix' '
	test_unconfig core.fsmonitor &&
	shit update-index --no-fsmonitor &&
	test_might_fail shit fsmonitor--daemon stop
'

matrix_clean_up_repo () {
	shit reset --hard HEAD &&
	shit clean -fd
}

matrix_try () {
	uc=$1 &&
	fsm=$2 &&
	fn=$3 &&

	if test $uc = true && test $fsm = false
	then
		# The untracked-cache is buggy when FSMonitor is
		# DISABLED, so skip the tests for this matrix
		# combination.
		#
		# We've observed random, occasional test failures on
		# Windows and MacOS when the UC is turned on and FSM
		# is turned off.  These are rare, but they do happen
		# indicating that it is probably a race condition within
		# the untracked cache itself.
		#
		# It usually happens when a test does F/D trickery and
		# then the NEXT test fails because of extra status
		# output from stale UC data from the previous test.
		#
		# Since FSMonitor is not involved in the error, skip
		# the tests for this matrix combination.
		#
		return 0
	fi &&

	test_expect_success "Matrix[uc:$uc][fsm:$fsm] $fn" '
		matrix_clean_up_repo &&
		$fn &&
		if test $uc = false && test $fsm = false
		then
			shit status --porcelain=v1 >.shit/expect.$fn
		else
			shit status --porcelain=v1 >.shit/actual.$fn &&
			test_cmp .shit/expect.$fn .shit/actual.$fn
		fi
	'
}

uc_values="false"
test_have_prereq UNTRACKED_CACHE && uc_values="false true"
for uc_val in $uc_values
do
	if test $uc_val = false
	then
		test_expect_success "Matrix[uc:$uc_val] disable untracked cache" '
			shit config core.untrackedcache false &&
			shit update-index --no-untracked-cache
		'
	else
		test_expect_success "Matrix[uc:$uc_val] enable untracked cache" '
			shit config core.untrackedcache true &&
			shit update-index --untracked-cache
		'
	fi

	fsm_values="false true"
	for fsm_val in $fsm_values
	do
		if test $fsm_val = false
		then
			test_expect_success "Matrix[uc:$uc_val][fsm:$fsm_val] disable fsmonitor" '
				test_unconfig core.fsmonitor &&
				shit update-index --no-fsmonitor &&
				test_might_fail shit fsmonitor--daemon stop
			'
		else
			test_expect_success "Matrix[uc:$uc_val][fsm:$fsm_val] enable fsmonitor" '
				shit config core.fsmonitor true &&
				shit fsmonitor--daemon start &&
				shit update-index --fsmonitor
			'
		fi

		matrix_try $uc_val $fsm_val edit_files
		matrix_try $uc_val $fsm_val delete_files
		matrix_try $uc_val $fsm_val create_files
		matrix_try $uc_val $fsm_val rename_files
		matrix_try $uc_val $fsm_val file_to_directory
		matrix_try $uc_val $fsm_val directory_to_file

		matrix_try $uc_val $fsm_val move_directory_contents_deeper
		matrix_try $uc_val $fsm_val move_directory_up
		matrix_try $uc_val $fsm_val move_directory

		if test $fsm_val = true
		then
			test_expect_success "Matrix[uc:$uc_val][fsm:$fsm_val] disable fsmonitor at end" '
				test_unconfig core.fsmonitor &&
				shit update-index --no-fsmonitor &&
				test_might_fail shit fsmonitor--daemon stop
			'
		fi
	done
done

# Test Unicode UTF-8 characters in the pathname of the working
# directory root.  Use of "*A()" routines rather than "*W()" routines
# on Windows can sometimes lead to odd failures.
#
u1=$(printf "u_c3_a6__\xC3\xA6")
u2=$(printf "u_e2_99_ab__\xE2\x99\xAB")
u_values="$u1 $u2"
for u in $u_values
do
	test_expect_success "unicode in repo root path: $u" '
		test_when_finished "stop_daemon_delete_repo $u" &&

		shit init "$u" &&
		echo 1 >"$u"/file1 &&
		shit -C "$u" add file1 &&
		shit -C "$u" config core.fsmonitor true &&

		start_daemon -C "$u" &&
		shit -C "$u" status >actual &&
		grep "new file:   file1" actual
	'
done

# Test fsmonitor interaction with submodules.
#
# If we start the daemon in the super, it will see FS events for
# everything in the working directory cone and this includes any
# files/directories contained *within* the submodules.
#
# A `shit status` at top level will get events for items within the
# submodule and ignore them, since they aren't named in the index
# of the super repo.  This makes the fsmonitor response a little
# noisy, but it doesn't alter the correctness of the state of the
# super-proper.
#
# When we have submodules, `shit status` normally does a recursive
# status on each of the submodules and adds a summary row for any
# dirty submodules.  (See the "S..." bits in porcelain V2 output.)
#
# It is therefore important that the top level status not be tricked
# by the FSMonitor response to skip those recursive calls.  That is,
# even if FSMonitor says that the mtime of the submodule directory
# hasn't changed and it could be implicitly marked valid, we must
# not take that shortcut.  We need to force the recusion into the
# submodule so that we get a summary of the status *within* the
# submodule.

create_super () {
	super="$1" &&

	shit init "$super" &&
	echo x >"$super/file_1" &&
	echo y >"$super/file_2" &&
	echo z >"$super/file_3" &&
	mkdir "$super/dir_1" &&
	echo a >"$super/dir_1/file_11" &&
	echo b >"$super/dir_1/file_12" &&
	mkdir "$super/dir_1/dir_2" &&
	echo a >"$super/dir_1/dir_2/file_21" &&
	echo b >"$super/dir_1/dir_2/file_22" &&
	shit -C "$super" add . &&
	shit -C "$super" commit -m "initial $super commit"
}

create_sub () {
	sub="$1" &&

	shit init "$sub" &&
	echo x >"$sub/file_x" &&
	echo y >"$sub/file_y" &&
	echo z >"$sub/file_z" &&
	mkdir "$sub/dir_x" &&
	echo a >"$sub/dir_x/file_a" &&
	echo b >"$sub/dir_x/file_b" &&
	mkdir "$sub/dir_x/dir_y" &&
	echo a >"$sub/dir_x/dir_y/file_a" &&
	echo b >"$sub/dir_x/dir_y/file_b" &&
	shit -C "$sub" add . &&
	shit -C "$sub" commit -m "initial $sub commit"
}

my_match_and_clean () {
	shit -C super --no-optional-locks status --porcelain=v2 >actual.with &&
	shit -C super --no-optional-locks -c core.fsmonitor=false \
		status --porcelain=v2 >actual.without &&
	test_cmp actual.with actual.without &&

	shit -C super --no-optional-locks diff-index --name-status HEAD >actual.with &&
	shit -C super --no-optional-locks -c core.fsmonitor=false \
		diff-index --name-status HEAD >actual.without &&
	test_cmp actual.with actual.without &&

	shit -C super/dir_1/dir_2/sub reset --hard &&
	shit -C super/dir_1/dir_2/sub clean -d -f
}

test_expect_success 'submodule setup' '
	shit config --global protocol.file.allow always
'

test_expect_success 'submodule always visited' '
	test_when_finished "shit -C super fsmonitor--daemon stop; \
			    rm -rf super; \
			    rm -rf sub" &&

	create_super super &&
	create_sub sub &&

	shit -C super submodule add ../sub ./dir_1/dir_2/sub &&
	shit -C super commit -m "add sub" &&

	start_daemon -C super &&
	shit -C super config core.fsmonitor true &&
	shit -C super update-index --fsmonitor &&
	shit -C super status &&

	# Now run pairs of commands w/ and w/o FSMonitor while we make
	# some dirt in the submodule and confirm matching output.

	# Completely clean status.
	my_match_and_clean &&

	# .M S..U
	echo z >super/dir_1/dir_2/sub/dir_x/dir_y/foobar_u &&
	my_match_and_clean &&

	# .M S.M.
	echo z >super/dir_1/dir_2/sub/dir_x/dir_y/foobar_m &&
	shit -C super/dir_1/dir_2/sub add . &&
	my_match_and_clean &&

	# .M S.M.
	echo z >>super/dir_1/dir_2/sub/dir_x/dir_y/file_a &&
	shit -C super/dir_1/dir_2/sub add . &&
	my_match_and_clean &&

	# .M SC..
	echo z >>super/dir_1/dir_2/sub/dir_x/dir_y/file_a &&
	shit -C super/dir_1/dir_2/sub add . &&
	shit -C super/dir_1/dir_2/sub commit -m "SC.." &&
	my_match_and_clean
'

# If a submodule has a `sub/.shit/` directory (rather than a file
# pointing to the super's `.shit/modules/sub`) and `core.fsmonitor`
# turned on in the submodule and the daemon is not yet started in
# the submodule, and someone does a `shit submodule absorbshitdirs`
# in the super, shit will recursively invoke `shit submodule--helper`
# to do the work and this may try to read the index.  This will
# try to start the daemon in the submodule.

test_expect_success "submodule absorbshitdirs implicitly starts daemon" '
	test_when_finished "rm -rf super; \
			    rm -rf sub;   \
			    rm super-sub.trace" &&

	create_super super &&
	create_sub sub &&

	# Copy rather than submodule add so that we get a .shit dir.
	cp -R ./sub ./super/dir_1/dir_2/sub &&

	shit -C super/dir_1/dir_2/sub config core.fsmonitor true &&

	shit -C super submodule add ../sub ./dir_1/dir_2/sub &&
	shit -C super commit -m "add sub" &&

	test_path_is_dir super/dir_1/dir_2/sub/.shit &&

	cwd="$(cd super && pwd)" &&
	cat >expect <<-EOF &&
	Migrating shit directory of '\''dir_1/dir_2/sub'\'' from
	'\''$cwd/dir_1/dir_2/sub/.shit'\'' to
	'\''$cwd/.shit/modules/dir_1/dir_2/sub'\''
	EOF
	shit_TRACE2_EVENT="$PWD/super-sub.trace" \
		shit -C super submodule absorbshitdirs >out 2>actual &&
	test_cmp expect actual &&
	test_must_be_empty out &&

	# Confirm that the trace2 log contains a record of the
	# daemon starting.
	test_subcommand shit fsmonitor--daemon start <super-sub.trace
'

# On a case-insensitive file system, confirm that the daemon
# notices when the .shit directory is moved/renamed/deleted
# regardless of how it is spelled in the FS event.
# That is, does the FS event receive the spelling of the
# operation or does it receive the spelling preserved with
# the file/directory.
#
test_expect_success CASE_INSENSITIVE_FS 'case insensitive+preserving' '
	test_when_finished "stop_daemon_delete_repo test_insensitive" &&

	shit init test_insensitive &&

	start_daemon -C test_insensitive --tf "$PWD/insensitive.trace" &&

	mkdir -p test_insensitive/abc/def &&
	echo xyz >test_insensitive/ABC/DEF/xyz &&

	test_path_is_dir test_insensitive/.shit &&
	test_path_is_dir test_insensitive/.shit &&

	# Rename .shit using an alternate spelling to verify that
	# the daemon detects it and automatically shuts down.
	mv test_insensitive/.shit test_insensitive/.FOO &&

	# See [1] above.
	mv test_insensitive/.FOO test_insensitive/.shit &&

	verify_implicit_shutdown test_insensitive &&

	# Verify that events were reported using on-disk spellings of the
	# directories and files that we touched.  We may or may not get a
	# trailing slash on modified directories.
	#
	grep -E "^event: abc/?$"       ./insensitive.trace &&
	grep -E "^event: abc/def/?$"   ./insensitive.trace &&
	grep -E "^event: abc/def/xyz$" ./insensitive.trace
'

# The variable "unicode_debug" is defined in the following library
# script to dump information about how the (OS, FS) handles Unicode
# composition.  Uncomment the following line if you want to enable it.
#
# unicode_debug=true

. "$TEST_DIRECTORY/lib-unicode-nfc-nfd.sh"

# See if the OS or filesystem does NFC/NFD aliasing/munging.
#
# The daemon should err on the side of caution and send BOTH the
# NFC and NFD forms.  It does not know the original spelling of
# the pathname (how the user thinks it should be spelled), so
# emit both and let the client decide (when necessary).  This is
# similar to "core.precomposeUnicode".
#
test_expect_success !UNICODE_COMPOSITION_SENSITIVE 'Unicode nfc/nfd' '
	test_when_finished "stop_daemon_delete_repo test_unicode" &&

	shit init test_unicode &&

	start_daemon -C test_unicode --tf "$PWD/unicode.trace" &&

	# Create a directory using an NFC spelling.
	#
	mkdir test_unicode/nfc &&
	mkdir test_unicode/nfc/c_${utf8_nfc} &&

	# Create a directory using an NFD spelling.
	#
	mkdir test_unicode/nfd &&
	mkdir test_unicode/nfd/d_${utf8_nfd} &&

	test-tool -C test_unicode fsmonitor-client query --token 0 &&

	if test_have_prereq UNICODE_NFC_PRESERVED
	then
		# We should have seen NFC event from OS.
		# We should not have synthesized an NFD event.
		grep -E    "^event: nfc/c_${utf8_nfc}/?$" ./unicode.trace &&
		grep -E -v "^event: nfc/c_${utf8_nfd}/?$" ./unicode.trace
	else
		# We should have seen NFD event from OS.
		# We should have synthesized an NFC event.
		grep -E "^event: nfc/c_${utf8_nfd}/?$" ./unicode.trace &&
		grep -E "^event: nfc/c_${utf8_nfc}/?$" ./unicode.trace
	fi &&

	# We assume UNICODE_NFD_PRESERVED.
	# We should have seen explicit NFD from OS.
	# We should have synthesized an NFC event.
	grep -E "^event: nfd/d_${utf8_nfd}/?$" ./unicode.trace &&
	grep -E "^event: nfd/d_${utf8_nfc}/?$" ./unicode.trace
'

test_expect_success 'split-index and FSMonitor work well together' '
	shit init split-index &&
	test_when_finished "shit -C \"$PWD/split-index\" \
		fsmonitor--daemon stop" &&
	(
		cd split-index &&
		shit config core.splitIndex true &&
		# force split-index in most cases
		shit config splitIndex.maxPercentChange 99 &&
		shit config core.fsmonitor true &&

		# Create the following commit topology:
		#
		# *   merge three
		# |\
		# | * three
		# * | merge two
		# |\|
		# | * two
		# * | one
		# |/
		# * 5a5efd7 initial

		test_commit initial &&
		test_commit two &&
		test_commit three &&
		shit reset --hard initial &&
		test_commit one &&
		test_tick &&
		shit merge two &&
		test_tick &&
		shit merge three &&

		shit rebase --force-rebase -r one
	)
'

# The FSMonitor daemon reports the OBSERVED pathname of modified files
# and thus contains the OBSERVED spelling on case-insensitive file
# systems.  The daemon does not (and should not) load the .shit/index
# file and therefore does not know the expected case-spelling.  Since
# it is possible for the user to create files/subdirectories with the
# incorrect case, a modified file event for a tracked will not have
# the EXPECTED case. This can cause `index_name_pos()` to incorrectly
# report that the file is untracked. This causes the client to fail to
# mark the file as possibly dirty (keeping the CE_FSMONITOR_VALID bit
# set) so that `shit status` will avoid inspecting it and thus not
# present in the status output.
#
# The setup is a little contrived.
#
test_expect_success CASE_INSENSITIVE_FS 'fsmonitor subdir case wrong on disk' '
	test_when_finished "stop_daemon_delete_repo subdir_case_wrong" &&

	shit init subdir_case_wrong &&
	(
		cd subdir_case_wrong &&
		echo x >AAA &&
		echo x >BBB &&

		mkdir dir1 &&
		echo x >dir1/file1 &&
		mkdir dir1/dir2 &&
		echo x >dir1/dir2/file2 &&
		mkdir dir1/dir2/dir3 &&
		echo x >dir1/dir2/dir3/file3 &&

		echo x >yyy &&
		echo x >zzz &&
		shit add . &&
		shit commit -m "data" &&

		# This will cause "dir1/" and everything under it
		# to be deleted.
		shit sparse-checkout set --cone --sparse-index &&

		# Create dir2 with the wrong case and then let shit
		# repopulate dir3 -- it will not correct the spelling
		# of dir2.
		mkdir dir1 &&
		mkdir dir1/DIR2 &&
		shit sparse-checkout add dir1/dir2/dir3
	) &&

	start_daemon -C subdir_case_wrong --tf "$PWD/subdir_case_wrong.trace" &&

	# Enable FSMonitor in the client. Run enough commands for
	# the .shit/index to sync up with the daemon with everything
	# marked clean.
	shit -C subdir_case_wrong config core.fsmonitor true &&
	shit -C subdir_case_wrong update-index --fsmonitor &&
	shit -C subdir_case_wrong status &&

	# Make some files dirty so that FSMonitor gets FSEvents for
	# each of them.
	echo xx >>subdir_case_wrong/AAA &&
	echo xx >>subdir_case_wrong/dir1/DIR2/dir3/file3 &&
	echo xx >>subdir_case_wrong/zzz &&

	shit_TRACE_FSMONITOR="$PWD/subdir_case_wrong.log" \
		shit -C subdir_case_wrong --no-optional-locks status --short \
			>"$PWD/subdir_case_wrong.out" &&

	# "shit status" should have gotten file events for each of
	# the 3 files.
	#
	# "dir2" should be in the observed case on disk.
	grep "fsmonitor_refresh_callback" \
		<"$PWD/subdir_case_wrong.log" \
		>"$PWD/subdir_case_wrong.log1" &&

	grep -q "AAA.*pos 0" "$PWD/subdir_case_wrong.log1" &&
	grep -q "zzz.*pos 6" "$PWD/subdir_case_wrong.log1" &&

	grep -q "dir1/DIR2/dir3/file3.*pos -3" "$PWD/subdir_case_wrong.log1" &&

	# Verify that we get a mapping event to correct the case.
	grep -q "MAP:.*dir1/DIR2/dir3/file3.*dir1/dir2/dir3/file3" \
		"$PWD/subdir_case_wrong.log1" &&

	# The refresh-callbacks should have caused "shit status" to clear
	# the CE_FSMONITOR_VALID bit on each of those files and caused
	# the worktree scan to visit them and mark them as modified.
	grep -q " M AAA" "$PWD/subdir_case_wrong.out" &&
	grep -q " M zzz" "$PWD/subdir_case_wrong.out" &&
	grep -q " M dir1/dir2/dir3/file3" "$PWD/subdir_case_wrong.out"
'

test_expect_success CASE_INSENSITIVE_FS 'fsmonitor file case wrong on disk' '
	test_when_finished "stop_daemon_delete_repo file_case_wrong" &&

	shit init file_case_wrong &&
	(
		cd file_case_wrong &&
		echo x >AAA &&
		echo x >BBB &&

		mkdir dir1 &&
		mkdir dir1/dir2 &&
		mkdir dir1/dir2/dir3 &&
		echo x >dir1/dir2/dir3/FILE-3-B &&
		echo x >dir1/dir2/dir3/XXXX-3-X &&
		echo x >dir1/dir2/dir3/file-3-a &&
		echo x >dir1/dir2/dir3/yyyy-3-y &&
		mkdir dir1/dir2/dir4 &&
		echo x >dir1/dir2/dir4/FILE-4-A &&
		echo x >dir1/dir2/dir4/XXXX-4-X &&
		echo x >dir1/dir2/dir4/file-4-b &&
		echo x >dir1/dir2/dir4/yyyy-4-y &&

		echo x >yyy &&
		echo x >zzz &&
		shit add . &&
		shit commit -m "data"
	) &&

	start_daemon -C file_case_wrong --tf "$PWD/file_case_wrong.trace" &&

	# Enable FSMonitor in the client. Run enough commands for
	# the .shit/index to sync up with the daemon with everything
	# marked clean.
	shit -C file_case_wrong config core.fsmonitor true &&
	shit -C file_case_wrong update-index --fsmonitor &&
	shit -C file_case_wrong status &&

	# Make some files dirty so that FSMonitor gets FSEvents for
	# each of them.
	echo xx >>file_case_wrong/AAA &&
	echo xx >>file_case_wrong/zzz &&

	# Rename some files so that FSMonitor sees a create and delete
	# FSEvent for each.  (A simple "mv foo FOO" is not portable
	# between macOS and Windows. It works on both platforms, but makes
	# the test messy, since (1) one platform updates "ctime" on the
	# moved file and one does not and (2) it causes a directory event
	# on one platform and not on the other which causes additional
	# scanning during "shit status" which causes a "H" vs "h" discrepancy
	# in "shit ls-files -f".)  So old-school it and move it out of the
	# way and copy it to the case-incorrect name so that we get fresh
	# "ctime" and "mtime" values.

	mv file_case_wrong/dir1/dir2/dir3/file-3-a file_case_wrong/dir1/dir2/dir3/ORIG &&
	cp file_case_wrong/dir1/dir2/dir3/ORIG     file_case_wrong/dir1/dir2/dir3/FILE-3-A &&
	rm file_case_wrong/dir1/dir2/dir3/ORIG &&
	mv file_case_wrong/dir1/dir2/dir4/FILE-4-A file_case_wrong/dir1/dir2/dir4/ORIG &&
	cp file_case_wrong/dir1/dir2/dir4/ORIG     file_case_wrong/dir1/dir2/dir4/file-4-a &&
	rm file_case_wrong/dir1/dir2/dir4/ORIG &&

	# Run status enough times to fully sync.
	#
	# The first instance should get the create and delete FSEvents
	# for each pair.  Status should update the index with a new FSM
	# token (so the next invocation will not see data for these
	# events).

	shit_TRACE_FSMONITOR="$PWD/file_case_wrong-try1.log" \
		shit -C file_case_wrong status --short \
			>"$PWD/file_case_wrong-try1.out" &&
	grep -q "fsmonitor_refresh_callback.*FILE-3-A.*pos -3" "$PWD/file_case_wrong-try1.log" &&
	grep -q "fsmonitor_refresh_callback.*file-3-a.*pos 4"  "$PWD/file_case_wrong-try1.log" &&
	grep -q "fsmonitor_refresh_callback.*FILE-4-A.*pos 6"  "$PWD/file_case_wrong-try1.log" &&
	grep -q "fsmonitor_refresh_callback.*file-4-a.*pos -9" "$PWD/file_case_wrong-try1.log" &&

	# FSM refresh will have invalidated the FSM bit and cause a regular
	# (real) scan of these tracked files, so they should have "H" status.
	# (We will not see a "h" status until the next refresh (on the next
	# command).)

	shit -C file_case_wrong ls-files -f >"$PWD/file_case_wrong-lsf1.out" &&
	grep -q "H dir1/dir2/dir3/file-3-a" "$PWD/file_case_wrong-lsf1.out" &&
	grep -q "H dir1/dir2/dir4/FILE-4-A" "$PWD/file_case_wrong-lsf1.out" &&


	# Try the status again. We assume that the above status command
	# advanced the token so that the next one will not see those events.

	shit_TRACE_FSMONITOR="$PWD/file_case_wrong-try2.log" \
		shit -C file_case_wrong status --short \
			>"$PWD/file_case_wrong-try2.out" &&
	! grep -q "fsmonitor_refresh_callback.*FILE-3-A.*pos" "$PWD/file_case_wrong-try2.log" &&
	! grep -q "fsmonitor_refresh_callback.*file-3-a.*pos" "$PWD/file_case_wrong-try2.log" &&
	! grep -q "fsmonitor_refresh_callback.*FILE-4-A.*pos" "$PWD/file_case_wrong-try2.log" &&
	! grep -q "fsmonitor_refresh_callback.*file-4-a.*pos" "$PWD/file_case_wrong-try2.log" &&

	# FSM refresh saw nothing, so it will mark all files as valid,
	# so they should now have "h" status.

	shit -C file_case_wrong ls-files -f >"$PWD/file_case_wrong-lsf2.out" &&
	grep -q "h dir1/dir2/dir3/file-3-a" "$PWD/file_case_wrong-lsf2.out" &&
	grep -q "h dir1/dir2/dir4/FILE-4-A" "$PWD/file_case_wrong-lsf2.out" &&


	# We now have files with clean content, but with case-incorrect
	# file names.  Modify them to see if status properly reports
	# them.

	echo xx >>file_case_wrong/dir1/dir2/dir3/FILE-3-A &&
	echo xx >>file_case_wrong/dir1/dir2/dir4/file-4-a &&

	shit_TRACE_FSMONITOR="$PWD/file_case_wrong-try3.log" \
		shit -C file_case_wrong --no-optional-locks status --short \
			>"$PWD/file_case_wrong-try3.out" &&

	# Verify that we get a mapping event to correct the case.
	grep -q "fsmonitor_refresh_callback MAP:.*dir1/dir2/dir3/FILE-3-A.*dir1/dir2/dir3/file-3-a" \
		"$PWD/file_case_wrong-try3.log" &&
	grep -q "fsmonitor_refresh_callback MAP:.*dir1/dir2/dir4/file-4-a.*dir1/dir2/dir4/FILE-4-A" \
		"$PWD/file_case_wrong-try3.log" &&

	# FSEvents are in observed case.
	grep -q "fsmonitor_refresh_callback.*FILE-3-A.*pos -3" "$PWD/file_case_wrong-try3.log" &&
	grep -q "fsmonitor_refresh_callback.*file-4-a.*pos -9" "$PWD/file_case_wrong-try3.log" &&

	# The refresh-callbacks should have caused "shit status" to clear
	# the CE_FSMONITOR_VALID bit on each of those files and caused
	# the worktree scan to visit them and mark them as modified.
	grep -q " M dir1/dir2/dir3/file-3-a" "$PWD/file_case_wrong-try3.out" &&
	grep -q " M dir1/dir2/dir4/FILE-4-A" "$PWD/file_case_wrong-try3.out"
'

test_done
