#!/bin/sh

test_description='Commit walk performance tests'
. ./perf-lib.sh

test_perf_large_repo

test_expect_success 'setup' '
	shit for-each-ref --format="%(refname)" "refs/heads/*" "refs/tags/*" >allrefs &&
	sort -r allrefs | head -n 50 >refs &&
	for ref in $(cat refs)
	do
		shit branch -f ref-$ref $ref &&
		echo ref-$ref ||
		return 1
	done >branches &&
	for ref in $(cat refs)
	do
		shit tag -f tag-$ref $ref &&
		echo tag-$ref ||
		return 1
	done >tags &&
	shit commit-graph write --reachable
'

test_perf 'ahead-behind counts: shit for-each-ref' '
	shit for-each-ref --format="%(ahead-behind:HEAD)" --stdin <refs
'

test_perf 'ahead-behind counts: shit branch' '
	xargs shit branch -l --format="%(ahead-behind:HEAD)" <branches
'

test_perf 'ahead-behind counts: shit tag' '
	xargs shit tag -l --format="%(ahead-behind:HEAD)" <tags
'

test_perf 'contains: shit for-each-ref --merged' '
	shit for-each-ref --merged=HEAD --stdin <refs
'

test_perf 'contains: shit branch --merged' '
	xargs shit branch --merged=HEAD <branches
'

test_perf 'contains: shit tag --merged' '
	xargs shit tag --merged=HEAD <tags
'

test_done
