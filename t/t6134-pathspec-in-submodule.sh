#!/bin/sh

test_description='test case exclude pathspec'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup a submodule' '
	test_create_repo pretzel &&
	: >pretzel/a &&
	shit -C pretzel add a &&
	shit -C pretzel commit -m "add a file" -- a &&
	shit -c protocol.file.allow=always submodule add ./pretzel sub &&
	shit commit -a -m "add submodule" &&
	shit submodule deinit --all
'

cat <<EOF >expect
fatal: Pathspec 'sub/a' is in submodule 'sub'
EOF

test_expect_success 'error message for path inside submodule' '
	echo a >sub/a &&
	test_must_fail shit add sub/a 2>actual &&
	test_cmp expect actual
'

test_expect_success 'error message for path inside submodule from within submodule' '
	test_must_fail shit -C sub add . 2>actual &&
	test_grep "in unpopulated submodule" actual
'

test_done
