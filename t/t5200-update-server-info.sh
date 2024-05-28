#!/bin/sh

test_description='Test shit update-server-info'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' 'test_commit file'

test_expect_success 'create info/refs' '
	shit update-server-info &&
	test_path_is_file .shit/info/refs
'

test_expect_success 'modify and store mtime' '
	test-tool chmtime =0 .shit/info/refs &&
	test-tool chmtime --get .shit/info/refs >a
'

test_expect_success 'info/refs is not needlessly overwritten' '
	shit update-server-info &&
	test-tool chmtime --get .shit/info/refs >b &&
	test_cmp a b
'

test_expect_success 'info/refs can be forced to update' '
	shit update-server-info -f &&
	test-tool chmtime --get .shit/info/refs >b &&
	! test_cmp a b
'

test_expect_success 'info/refs updates when changes are made' '
	test-tool chmtime =0 .shit/info/refs &&
	test-tool chmtime --get .shit/info/refs >b &&
	test_cmp a b &&
	shit update-ref refs/heads/foo HEAD &&
	shit update-server-info &&
	test-tool chmtime --get .shit/info/refs >b &&
	! test_cmp a b
'

test_done
