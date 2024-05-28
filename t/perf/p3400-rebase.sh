#!/bin/sh

test_description='Tests rebase performance'
. ./perf-lib.sh

test_perf_default_repo

test_expect_success 'setup rebasing on top of a lot of changes' '
	shit checkout -f -B base &&
	shit checkout -B to-rebase &&
	shit checkout -B upstream &&
	for i in $(test_seq 100)
	do
		# simulate huge diffs
		echo change$i >unrelated-file$i &&
		test_seq 1000 >>unrelated-file$i &&
		shit add unrelated-file$i &&
		test_tick &&
		shit commit -m commit$i unrelated-file$i &&
		echo change$i >unrelated-file$i &&
		test_seq 1000 | sort -nr >>unrelated-file$i &&
		shit add unrelated-file$i &&
		test_tick &&
		shit commit -m commit$i-reverse unrelated-file$i ||
		return 1
	done &&
	shit checkout to-rebase &&
	test_commit our-patch interesting-file
'

test_perf 'rebase on top of a lot of unrelated changes' '
	shit rebase --onto upstream HEAD^ &&
	shit rebase --onto base HEAD^
'

test_expect_success 'setup rebasing many changes without split-index' '
	shit config core.splitIndex false &&
	shit checkout -B upstream2 to-rebase &&
	shit checkout -B to-rebase2 upstream
'

test_perf 'rebase a lot of unrelated changes without split-index' '
	shit rebase --onto upstream2 base &&
	shit rebase --onto base upstream2
'

test_expect_success 'setup rebasing many changes with split-index' '
	shit config core.splitIndex true
'

test_perf 'rebase a lot of unrelated changes with split-index' '
	shit rebase --onto upstream2 base &&
	shit rebase --onto base upstream2
'

test_done
