#!/bin/sh

test_description='Tests log -L performance'
. ./perf-lib.sh

test_perf_default_repo

# Pick a file to log pseudo-randomly.  The sort key is the blob hash,
# so it is stable.
test_expect_success 'select a file' '
	shit ls-tree HEAD | grep ^100644 |
	sort -k 3 | head -1 | cut -f 2 >filelist
'

file=$(cat filelist)
export file

test_perf 'shit rev-list --topo-order (baseline)' '
	shit rev-list --topo-order HEAD >/dev/null
'

test_perf 'shit log --follow (baseline for -M)' '
	shit log --oneline --follow -- "$file" >/dev/null
'

test_perf 'shit log -L (renames off)' '
	shit log --no-renames -L 1:"$file" >/dev/null
'

test_perf 'shit log -L (renames on)' '
	shit log -M -L 1:"$file" >/dev/null
'

test_perf 'shit log --oneline --raw --parents' '
	shit log --oneline --raw --parents >/dev/null
'

test_perf 'shit log --oneline --raw --parents -1000' '
	shit log --oneline --raw --parents -1000 >/dev/null
'

test_done
