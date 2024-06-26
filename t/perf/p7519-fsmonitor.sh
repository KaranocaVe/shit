#!/bin/sh

test_description="Test core.fsmonitor"

. ./perf-lib.sh

#
# Performance test for the fsmonitor feature which enables shit to talk to a
# file system change monitor and avoid having to scan the working directory
# for new or modified files.
#
# By default, the performance test will utilize the Watchman file system
# monitor if it is installed.  If Watchman is not installed, it will use a
# dummy integration script that does not report any new or modified files.
# The dummy script has very little overhead which provides optimistic results.
#
# The performance test will also use the untracked cache feature if it is
# available as fsmonitor uses it to speed up scanning for untracked files.
#
# There are 3 environment variables that can be used to alter the default
# behavior of the performance test:
#
# shit_PERF_7519_UNTRACKED_CACHE: used to configure core.untrackedCache
# shit_PERF_7519_SPLIT_INDEX: used to configure core.splitIndex
# shit_PERF_7519_FSMONITOR: used to configure core.fsMonitor. May be an
#   absolute path to an integration. May be a space delimited list of
#   absolute paths to integrations.
#
# The big win for using fsmonitor is the elimination of the need to scan the
# working directory looking for changed and untracked files. If the file
# information is all cached in RAM, the benefits are reduced.
#
# shit_PERF_7519_DROP_CACHE: if set, the OS caches are dropped between tests
#
# shit_PERF_7519_TRACE: if set, enable trace logging during the test.
#   Trace logs will be grouped by fsmonitor provider.

test_perf_large_repo
test_checkout_worktree

test_lazy_prereq UNTRACKED_CACHE '
	{ shit update-index --test-untracked-cache; ret=$?; } &&
	test $ret -ne 1
'

test_lazy_prereq WATCHMAN '
	command -v watchman
'

if test_have_prereq WATCHMAN
then
	# Convert unix style paths to escaped Windows style paths for Watchman
	case "$(uname -s)" in
	MSYS_NT*)
	  shit_WORK_TREE="$(cygpath -aw "$PWD" | sed 's,\\,/,g')"
	  ;;
	*)
	  shit_WORK_TREE="$PWD"
	  ;;
	esac
fi

trace_start () {
	if test -n "$shit_PERF_7519_TRACE"
	then
		name="$1"
		TEST_TRACE_DIR="$TEST_OUTPUT_DIRECTORY/test-trace/p7519/"
		echo "Writing trace logging to $TEST_TRACE_DIR"

		mkdir -p "$TEST_TRACE_DIR"

		# Start Trace2 logging and any other shit_TRACE_* logs that you
		# want for this named test case.

		shit_TRACE2_PERF="$TEST_TRACE_DIR/$name.trace2perf"
		export shit_TRACE2_PERF

		>"$shit_TRACE2_PERF"
	fi
}

trace_stop () {
	if test -n "$shit_PERF_7519_TRACE"
	then
		unset shit_TRACE2_PERF
	fi
}

touch_files () {
	n=$1 &&
	d="$n"_files &&

	(cd $d && test_seq 1 $n | xargs touch )
}

test_expect_success "one time repo setup" '
	# set untrackedCache depending on the environment
	if test -n "$shit_PERF_7519_UNTRACKED_CACHE"
	then
		shit config core.untrackedCache "$shit_PERF_7519_UNTRACKED_CACHE"
	else
		if test_have_prereq UNTRACKED_CACHE
		then
			shit config core.untrackedCache true
		else
			shit config core.untrackedCache false
		fi
	fi &&

	# set core.splitindex depending on the environment
	if test -n "$shit_PERF_7519_SPLIT_INDEX"
	then
		shit config core.splitIndex "$shit_PERF_7519_SPLIT_INDEX"
	fi &&

	mkdir 1_file 10_files 100_files 1000_files 10000_files &&
	: 1_file directory should be left empty &&
	touch_files 10 &&
	touch_files 100 &&
	touch_files 1000 &&
	touch_files 10000 &&
	shit add 1_file 10_files 100_files 1000_files 10000_files &&
	shit commit -qm "Add files" &&

	# If Watchman exists, watch the work tree and attempt a query.
	if test_have_prereq WATCHMAN; then
		watchman watch "$shit_WORK_TREE" &&
		watchman watch-list | grep -q -F "p7519-fsmonitor"
	fi
'

setup_for_fsmonitor_hook () {
	# set INTEGRATION_SCRIPT depending on the environment
	if test -n "$INTEGRATION_PATH"
	then
		INTEGRATION_SCRIPT="$INTEGRATION_PATH"
	else
		#
		# Choose integration script based on existence of Watchman.
		# Fall back to an empty integration script.
		#
		mkdir .shit/hooks &&
		if test_have_prereq WATCHMAN
		then
			INTEGRATION_SCRIPT=".shit/hooks/fsmonitor-watchman" &&
			cp "$TEST_DIRECTORY/../templates/hooks--fsmonitor-watchman.sample" "$INTEGRATION_SCRIPT"
		else
			INTEGRATION_SCRIPT=".shit/hooks/fsmonitor-empty" &&
			write_script "$INTEGRATION_SCRIPT"<<-\EOF
			EOF
		fi
	fi &&

	shit config core.fsmonitor "$INTEGRATION_SCRIPT" &&
	shit update-index --fsmonitor 2>error &&
	if test_have_prereq WATCHMAN
	then
		test_must_be_empty error  # ensure no silent error
	else
		grep "Empty last update token" error
	fi
}

test_perf_w_drop_caches () {
	if test -n "$shit_PERF_7519_DROP_CACHE"; then
		test_perf "$1" --setup "test-tool drop-caches" "$2"
	else
		test_perf "$@"
	fi
}

test_fsmonitor_suite () {
	if test -n "$USE_FSMONITOR_DAEMON"
	then
		DESC="builtin fsmonitor--daemon"
	elif test -n "$INTEGRATION_SCRIPT"
	then
		DESC="fsmonitor=$(basename $INTEGRATION_SCRIPT)"
	else
		DESC="fsmonitor=disabled"
	fi

	test_expect_success "test_initialization" '
		shit reset --hard &&
		shit status  # Warm caches
	'

	test_perf_w_drop_caches "status ($DESC)" '
		shit status
	'

	test_perf_w_drop_caches "status -uno ($DESC)" '
		shit status -uno
	'

	test_perf_w_drop_caches "status -uall ($DESC)" '
		shit status -uall
	'

	# Update the mtimes on upto 100k files to make status think
	# that they are dirty.  For simplicity, omit any files with
	# LFs (i.e. anything that ls-files thinks it needs to dquote)
	# and any files with whitespace so that they pass thru xargs
	# properly.
	#
	test_perf_w_drop_caches "status (dirty) ($DESC)" '
		shit ls-files | \
			head -100000 | \
			grep -v \" | \
			grep -v " ." | \
			xargs test-tool chmtime -300 &&
		shit status
	'

	test_perf_w_drop_caches "diff ($DESC)" '
		shit diff
	'

	test_perf_w_drop_caches "diff HEAD ($DESC)" '
		shit diff HEAD
	'

	test_perf_w_drop_caches "diff -- 0_files ($DESC)" '
		shit diff -- 1_file
	'

	test_perf_w_drop_caches "diff -- 10_files ($DESC)" '
		shit diff -- 10_files
	'

	test_perf_w_drop_caches "diff -- 100_files ($DESC)" '
		shit diff -- 100_files
	'

	test_perf_w_drop_caches "diff -- 1000_files ($DESC)" '
		shit diff -- 1000_files
	'

	test_perf_w_drop_caches "diff -- 10000_files ($DESC)" '
		shit diff -- 10000_files
	'

	test_perf_w_drop_caches "add ($DESC)" '
		shit add  --all
	'
}

#
# Run a full set of perf tests using each Hook-based fsmonitor provider,
# such as Watchman.
#

trace_start fsmonitor-watchman
if test -n "$shit_PERF_7519_FSMONITOR"; then
	for INTEGRATION_PATH in $shit_PERF_7519_FSMONITOR; do
		test_expect_success "setup for fsmonitor $INTEGRATION_PATH" 'setup_for_fsmonitor_hook'
		test_fsmonitor_suite
	done
else
	test_expect_success "setup for fsmonitor hook" 'setup_for_fsmonitor_hook'
	test_fsmonitor_suite
fi

if test_have_prereq WATCHMAN
then
	watchman watch-del "$shit_WORK_TREE" >/dev/null 2>&1 &&

	# Work around Watchman bug on Windows where it holds on to handles
	# preventing the removal of the trash directory
	watchman shutdown-server >/dev/null 2>&1
fi
trace_stop

#
# Run a full set of perf tests with the fsmonitor feature disabled.
#

trace_start fsmonitor-disabled
test_expect_success "setup without fsmonitor" '
	unset INTEGRATION_SCRIPT &&
	shit config --unset core.fsmonitor &&
	shit update-index --no-fsmonitor
'

test_fsmonitor_suite
trace_stop

#
# Run a full set of perf tests using the built-in fsmonitor--daemon.
# It does not use the Hook API, so it has a different setup.
# Explicitly start the daemon here and before we start client commands
# so that we can later add custom tracing.
#
if test_have_prereq FSMONITOR_DAEMON
then
	USE_FSMONITOR_DAEMON=t

	test_expect_success "setup for builtin fsmonitor" '
		trace_start fsmonitor--daemon--server &&
		shit fsmonitor--daemon start &&

		trace_start fsmonitor--daemon--client &&

		shit config core.fsmonitor true &&
		shit update-index --fsmonitor
	'

	test_fsmonitor_suite

	shit fsmonitor--daemon stop
	trace_stop
fi

test_done
