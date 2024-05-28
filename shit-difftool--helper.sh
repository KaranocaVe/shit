#!/bin/sh
# shit-difftool--helper is a shit_EXTERNAL_DIFF-compatible diff tool launcher.
# This script is typically launched by using the 'shit difftool'
# convenience command.
#
# Copyright (c) 2009, 2010 David Aguilar

TOOL_MODE=diff
. shit-mergetool--lib

# difftool.prompt controls the default prompt/no-prompt behavior
# and is overridden with $shit_DIFFTOOL*_PROMPT.
should_prompt () {
	prompt_merge=$(shit config --bool mergetool.prompt || echo true)
	prompt=$(shit config --bool difftool.prompt || echo $prompt_merge)
	if test "$prompt" = true
	then
		test -z "$shit_DIFFTOOL_NO_PROMPT"
	else
		test -n "$shit_DIFFTOOL_PROMPT"
	fi
}

# Indicates that --extcmd=... was specified
use_ext_cmd () {
	test -n "$shit_DIFFTOOL_EXTCMD"
}

launch_merge_tool () {
	# Merged is the filename as it appears in the work tree
	# Local is the contents of a/filename
	# Remote is the contents of b/filename
	# Custom merge tool commands might use $BASE so we provide it
	MERGED="$1"
	LOCAL="$2"
	REMOTE="$3"
	BASE="$1"

	# $LOCAL and $REMOTE are temporary files so prompt
	# the user with the real $MERGED name before launching $merge_tool.
	if should_prompt
	then
		printf "\nViewing (%s/%s): '%s'\n" "$shit_DIFF_PATH_COUNTER" \
			"$shit_DIFF_PATH_TOTAL" "$MERGED"
		if use_ext_cmd
		then
			printf "Launch '%s' [Y/n]? " \
				"$shit_DIFFTOOL_EXTCMD"
		else
			printf "Launch '%s' [Y/n]? " "$merge_tool"
		fi
		read ans || return
		if test "$ans" = n
		then
			return
		fi
	fi

	if use_ext_cmd
	then
		export BASE
		eval $shit_DIFFTOOL_EXTCMD '"$LOCAL"' '"$REMOTE"'
	else
		initialize_merge_tool "$merge_tool"
		# ignore the error from the above --- run_merge_tool
		# will diagnose unusable tool by itself
		run_merge_tool "$merge_tool"
	fi
}

if ! use_ext_cmd
then
	if test -n "$shit_DIFF_TOOL"
	then
		merge_tool="$shit_DIFF_TOOL"
	else
		merge_tool="$(get_merge_tool)"
		subshell_exit_status=$?
		if test $subshell_exit_status -gt 1
		then
			exit $subshell_exit_status
		fi
	fi
fi

if test -n "$shit_DIFFTOOL_DIRDIFF"
then
	LOCAL="$1"
	REMOTE="$2"
	initialize_merge_tool "$merge_tool"
	# ignore the error from the above --- run_merge_tool
	# will diagnose unusable tool by itself
	run_merge_tool "$merge_tool" false

	status=$?
	if test $status -ge 126
	then
		# Command not found (127), not executable (126) or
		# exited via a signal (>= 128).
		exit $status
	fi

	if test "$shit_DIFFTOOL_TRUST_EXIT_CODE" = true
	then
		exit $status
	fi
else
	# Launch the merge tool on each path provided by 'shit diff'
	while test $# -gt 6
	do
		launch_merge_tool "$1" "$2" "$5"
		status=$?
		if test $status -ge 126
		then
			# Command not found (127), not executable (126) or
			# exited via a signal (>= 128).
			exit $status
		fi

		if test "$status" != 0 &&
			test "$shit_DIFFTOOL_TRUST_EXIT_CODE" = true
		then
			exit $status
		fi
		shift 7
	done
fi

exit 0
