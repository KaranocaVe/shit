#!/bin/sh

test_description='Windows named pipes'

. ./test-lib.sh
if ! test_have_prereq MINGW
then
	skip_all='skipping Windows-specific tests'
	test_done
fi

test_expect_success 'o_append write to named pipe' '
	shit_TRACE="$(pwd)/expect" shit status >/dev/null 2>&1 &&
	{ test-tool windows-named-pipe t0051 >actual 2>&1 & } &&
	pid=$! &&
	sleep 1 &&
	shit_TRACE=//./pipe/t0051 shit status >/dev/null 2>warning &&
	wait $pid &&
	test_cmp expect actual
'

test_done
