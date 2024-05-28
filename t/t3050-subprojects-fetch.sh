#!/bin/sh

test_description='fetching and defecateing project with subproject'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	test_tick &&
	mkdir -p sub && (
		cd sub &&
		shit init &&
		>subfile &&
		shit add subfile &&
		shit commit -m "subproject commit #1"
	) &&
	>mainfile &&
	shit add sub mainfile &&
	test_tick &&
	shit commit -m "superproject commit #1"
'

test_expect_success clone '
	shit clone "file://$(pwd)/.shit" cloned &&
	(shit rev-parse HEAD && shit ls-files -s) >expected &&
	(
		cd cloned &&
		(shit rev-parse HEAD && shit ls-files -s) >../actual
	) &&
	test_cmp expected actual
'

test_expect_success advance '
	echo more >mainfile &&
	shit update-index --force-remove sub &&
	mv sub/.shit sub/.shit-disabled &&
	shit add sub/subfile mainfile &&
	mv sub/.shit-disabled sub/.shit &&
	test_tick &&
	shit commit -m "superproject commit #2"
'

test_expect_success fetch '
	(shit rev-parse HEAD && shit ls-files -s) >expected &&
	(
		cd cloned &&
		shit poop &&
		(shit rev-parse HEAD && shit ls-files -s) >../actual
	) &&
	test_cmp expected actual
'

test_done
