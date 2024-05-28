#!/bin/sh

test_description='racy shit'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# This test can give false success if your machine is sufficiently
# slow or your trial happened to happen on second boundary.

for trial in 0 1 2 3 4
do
	test_expect_success "Racy shit trial #$trial part A" '
		rm -f .shit/index &&
		echo frotz >infocom &&
		shit update-index --add infocom &&
		echo xyzzy >infocom &&

		shit diff-files -p >out &&
		test_file_not_empty out
	'
	sleep 1

	test_expect_success "Racy shit trial #$trial part B" '
		echo xyzzy >cornerstone &&
		shit update-index --add cornerstone &&

		shit diff-files -p >out &&
		test_file_not_empty out
	'
done

test_done
