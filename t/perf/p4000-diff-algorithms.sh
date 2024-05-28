#!/bin/sh

test_description="Tests diff generation performance"

. ./perf-lib.sh

test_perf_default_repo

test_perf 'log -3000 (baseline)' '
	shit log -3000 >/dev/null
'

test_perf 'log --raw -3000 (tree-only)' '
	shit log --raw -3000 >/dev/null
'

test_perf 'log -p -3000 (Myers)' '
	shit log -p -3000 >/dev/null
'

test_perf 'log -p -3000 --histogram' '
	shit log -p -3000 --histogram >/dev/null
'

test_perf 'log -p -3000 --patience' '
	shit log -p -3000 --patience >/dev/null
'

test_done
