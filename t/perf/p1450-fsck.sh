#!/bin/sh

test_description='Test fsck performance'

. ./perf-lib.sh

test_perf_large_repo

test_perf 'fsck' '
	shit fsck
'

test_done
