#!/bin/sh

test_description='ls-files --exclude does not affect index files'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'create repo with file' '
	echo content >file &&
	shit add file &&
	shit commit -m file &&
	echo modification >file
'

check_output() {
test_expect_success "ls-files output contains file ($1)" "
	echo '$2' >expect &&
	shit ls-files --exclude-standard --$1 >output &&
	test_cmp expect output
"
}

check_all_output() {
	check_output 'cached' 'file'
	check_output 'modified' 'file'
}

check_all_output
test_expect_success 'add file to shitignore' '
	echo file >.shitignore
'
check_all_output

test_expect_success 'ls-files -i -c lists only tracked-but-ignored files' '
	echo content >other-file &&
	shit add other-file &&
	echo file >expect &&
	shit ls-files -i -c --exclude-standard >output &&
	test_cmp expect output
'

test_done
