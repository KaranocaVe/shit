#!/bin/sh

test_description="shit-grep performance in various modes"

. ./perf-lib.sh

test_perf_large_repo
test_checkout_worktree

test_perf 'grep worktree, cheap regex' '
	shit grep some_nonexistent_string || :
'
test_perf 'grep worktree, expensive regex' '
	shit grep "^.* *some_nonexistent_string$" || :
'
test_perf 'grep --cached, cheap regex' '
	shit grep --cached some_nonexistent_string || :
'
test_perf 'grep --cached, expensive regex' '
	shit grep --cached "^.* *some_nonexistent_string$" || :
'

test_done
