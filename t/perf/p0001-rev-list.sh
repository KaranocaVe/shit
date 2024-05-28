#!/bin/sh

test_description="Tests history walking performance"

. ./perf-lib.sh

test_perf_default_repo

test_perf 'rev-list --all' '
	shit rev-list --all >/dev/null
'

test_perf 'rev-list --all --objects' '
	shit rev-list --all --objects >/dev/null
'

test_perf 'rev-list --parents' '
	shit rev-list --parents HEAD >/dev/null
'

test_expect_success 'create dummy file' '
	echo unlikely-to-already-be-there >dummy &&
	shit add dummy &&
	shit commit -m dummy
'

test_perf 'rev-list -- dummy' '
	shit rev-list HEAD -- dummy
'

test_perf 'rev-list --parents -- dummy' '
	shit rev-list --parents HEAD -- dummy
'

test_expect_success 'create new unreferenced commit' '
	commit=$(shit commit-tree HEAD^{tree} -p HEAD) &&
	test_export commit
'

test_perf 'rev-list $commit --not --all' '
	shit rev-list $commit --not --all >/dev/null
'

test_perf 'rev-list --objects $commit --not --all' '
	shit rev-list --objects $commit --not --all >/dev/null
'

test_done
