#!/bin/sh

test_description='pack should notice missing commit objects'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	for i in 1 2 3 4 5
	do
		echo "$i" >"file$i" &&
		shit add "file$i" &&
		test_tick &&
		shit commit -m "$i" &&
		shit tag "tag$i" || return 1
	done &&
	obj=$(shit rev-parse --verify tag3) &&
	fanout=$(expr "$obj" : "\(..\)") &&
	remainder=$(expr "$obj" : "..\(.*\)") &&
	rm -f ".shit/objects/$fanout/$remainder"
'

test_expect_success 'check corruption' '
	test_must_fail shit fsck
'

test_expect_success 'rev-list notices corruption (1)' '
	test_must_fail env shit_TEST_COMMIT_GRAPH=0 shit -c core.commitGraph=false rev-list HEAD
'

test_expect_success 'rev-list notices corruption (2)' '
	test_must_fail env shit_TEST_COMMIT_GRAPH=0 shit -c core.commitGraph=false rev-list --objects HEAD
'

test_expect_success 'pack-objects notices corruption' '
	echo HEAD |
	test_must_fail shit pack-objects --revs pack
'

test_done
