#!/bin/sh

test_description='unpack-trees error messages'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh


test_expect_success 'setup' '
	echo one >one &&
	shit add one &&
	shit commit -a -m First &&

	shit checkout -b branch &&
	echo two >two &&
	echo three >three &&
	echo four >four &&
	echo five >five &&
	shit add two three four five &&
	shit commit -m Second &&

	shit checkout main &&
	echo other >two &&
	echo other >three &&
	echo other >four &&
	echo other >five
'

cat >expect <<\EOF
error: The following untracked working tree files would be overwritten by merge:
	five
	four
	three
	two
Please move or remove them before you merge.
Aborting
EOF

test_expect_success 'untracked files overwritten by merge (fast and non-fast forward)' '
	test_must_fail shit merge branch 2>out &&
	test_cmp out expect &&
	shit commit --allow-empty -m empty &&
	(
		shit_MERGE_VERBOSITY=0 &&
		export shit_MERGE_VERBOSITY &&
		test_must_fail shit merge branch 2>out2
	) &&
	echo "Merge with strategy ${shit_TEST_MERGE_ALGORITHM:-ort} failed." >>expect &&
	test_cmp out2 expect &&
	shit reset --hard HEAD^
'

cat >expect <<\EOF
error: Your local changes to the following files would be overwritten by merge:
	four
	three
	two
Please commit your changes or stash them before you merge.
error: The following untracked working tree files would be overwritten by merge:
	five
Please move or remove them before you merge.
Aborting
EOF

test_expect_success 'untracked files or local changes ovewritten by merge' '
	shit add two &&
	shit add three &&
	shit add four &&
	test_must_fail shit merge branch 2>out &&
	test_cmp out expect
'

cat >expect <<\EOF
error: Your local changes to the following files would be overwritten by checkout:
	rep/one
	rep/two
Please commit your changes or stash them before you switch branches.
Aborting
EOF

test_expect_success 'cannot switch branches because of local changes' '
	shit add five &&
	mkdir rep &&
	echo one >rep/one &&
	echo two >rep/two &&
	shit add rep/one rep/two &&
	shit commit -m Fourth &&
	shit checkout main &&
	echo uno >rep/one &&
	echo dos >rep/two &&
	test_must_fail shit checkout branch 2>out &&
	test_cmp out expect
'

cat >expect <<\EOF
error: Your local changes to the following files would be overwritten by checkout:
	rep/one
	rep/two
Please commit your changes or stash them before you switch branches.
Aborting
EOF

test_expect_success 'not uptodate file porcelain checkout error' '
	shit add rep/one rep/two &&
	test_must_fail shit checkout branch 2>out &&
	test_cmp out expect
'

cat >expect <<\EOF
error: Updating the following directories would lose untracked files in them:
	rep
	rep2

Aborting
EOF

test_expect_success 'not_uptodate_dir porcelain checkout error' '
	shit init uptodate &&
	cd uptodate &&
	mkdir rep &&
	mkdir rep2 &&
	touch rep/foo &&
	touch rep2/foo &&
	shit add rep/foo rep2/foo &&
	shit commit -m init &&
	shit checkout -b branch &&
	shit rm rep -r &&
	shit rm rep2 -r &&
	>rep &&
	>rep2 &&
	shit add rep rep2 &&
	shit commit -m "added test as a file" &&
	shit checkout main &&
	>rep/untracked-file &&
	>rep2/untracked-file &&
	test_must_fail shit checkout branch 2>out &&
	test_cmp out ../expect
'

test_done
