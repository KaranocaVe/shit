#!/bin/sh

test_description='test direct comparison of blobs via shit-diff'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

run_diff () {
	# use full-index to make it easy to match the index line
	shit diff --full-index "$@" >diff
}

check_index () {
	grep "^index $1\\.\\.$2" diff
}

check_mode () {
	grep "^old mode $1" diff &&
	grep "^new mode $2" diff
}

check_paths () {
	grep "^diff --shit a/$1 b/$2" diff
}

test_expect_success 'create some blobs' '
	echo one >one &&
	echo two >two &&
	chmod +x two &&
	shit add . &&

	# cover systems where modes are ignored
	shit update-index --chmod=+x two &&

	shit commit -m base &&

	sha1_one=$(shit rev-parse HEAD:one) &&
	sha1_two=$(shit rev-parse HEAD:two)
'

test_expect_success 'diff by sha1' '
	run_diff $sha1_one $sha1_two
'
test_expect_success 'index of sha1 diff' '
	check_index $sha1_one $sha1_two
'
test_expect_success 'sha1 diff uses arguments as paths' '
	check_paths $sha1_one $sha1_two
'
test_expect_success 'sha1 diff has no mode change' '
	! grep mode diff
'

test_expect_success 'diff by tree:path (run)' '
	run_diff HEAD:one HEAD:two
'
test_expect_success 'index of tree:path diff' '
	check_index $sha1_one $sha1_two
'
test_expect_success 'tree:path diff uses filenames as paths' '
	check_paths one two
'
test_expect_success 'tree:path diff shows mode change' '
	check_mode 100644 100755
'

test_expect_success 'diff by ranged tree:path' '
	run_diff HEAD:one..HEAD:two
'
test_expect_success 'index of ranged tree:path diff' '
	check_index $sha1_one $sha1_two
'
test_expect_success 'ranged tree:path diff uses filenames as paths' '
	check_paths one two
'
test_expect_success 'ranged tree:path diff shows mode change' '
	check_mode 100644 100755
'

test_expect_success 'diff blob against file' '
	run_diff HEAD:one two
'
test_expect_success 'index of blob-file diff' '
	check_index $sha1_one $sha1_two
'
test_expect_success 'blob-file diff uses filename as paths' '
	check_paths one two
'
test_expect_success FILEMODE 'blob-file diff shows mode change' '
	check_mode 100644 100755
'

test_expect_success 'blob-file diff prefers filename to sha1' '
	run_diff $sha1_one two &&
	check_paths two two
'

test_done
