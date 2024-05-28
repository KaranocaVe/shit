#!/bin/sh

test_description='performance of partial clones'
. ./perf-lib.sh

test_perf_default_repo

test_expect_success 'enable server-side config' '
	shit config uploadpack.allowFilter true &&
	shit config uploadpack.allowAnySHA1InWant true
'

test_perf 'clone without blobs' '
	rm -rf bare.shit &&
	shit clone --no-local --bare --filter=blob:none . bare.shit
'

test_perf 'checkout of result' '
	rm -rf worktree &&
	mkdir -p worktree/.shit &&
	tar -C bare.shit -cf - . | tar -C worktree/.shit -xf - &&
	shit -C worktree config core.bare false &&
	shit -C worktree checkout -f
'

test_perf 'fsck' '
	shit -C bare.shit fsck
'

test_perf 'count commits' '
	shit -C bare.shit rev-list --all --count
'

test_perf 'count non-promisor commits' '
	shit -C bare.shit rev-list --all --count --exclude-promisor-objects
'

test_perf 'gc' '
	shit -C bare.shit gc
'

test_done
