#!/bin/sh

test_description='reset --hard unmerged'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	mkdir before later &&
	>before/1 &&
	>before/2 &&
	>hello &&
	>later/3 &&
	shit add before hello later &&
	shit commit -m world &&

	H=$(shit rev-parse :hello) &&
	shit rm --cached hello &&
	echo "100644 $H 2	hello" | shit update-index --index-info &&

	rm -f hello &&
	mkdir -p hello &&
	>hello/world &&
	test "$(shit ls-files -o)" = hello/world

'

test_expect_success 'reset --hard should restore unmerged ones' '

	shit reset --hard &&
	shit ls-files --error-unmatch before/1 before/2 hello later/3 &&
	test -f hello

'

test_expect_success 'reset --hard did not corrupt index or cache-tree' '

	T=$(shit write-tree) &&
	rm -f .shit/index &&
	shit add before hello later &&
	U=$(shit write-tree) &&
	test "$T" = "$U"

'

test_done
