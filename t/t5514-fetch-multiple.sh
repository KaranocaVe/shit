#!/bin/sh

test_description='fetch --all works correctly'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

setup_repository () {
	mkdir "$1" && (
	cd "$1" &&
	shit init &&
	>file &&
	shit add file &&
	test_tick &&
	shit commit -m "Initial" &&
	shit checkout -b side &&
	>elif &&
	shit add elif &&
	test_tick &&
	shit commit -m "Second" &&
	shit checkout main
	)
}

setup_test_clone () {
	test_dir="$1" &&
	shit clone one "$test_dir" &&
	for r in one two three
	do
		shit -C "$test_dir" remote add "$r" "../$r" || return 1
	done
}

test_expect_success setup '
	setup_repository one &&
	setup_repository two &&
	(
		cd two && shit branch another
	) &&
	shit clone --mirror two three &&
	shit clone one test
'

cat > test/expect << EOF
  one/main
  one/side
  origin/HEAD -> origin/main
  origin/main
  origin/side
  three/another
  three/main
  three/side
  two/another
  two/main
  two/side
EOF

test_expect_success 'shit fetch --all' '
	(cd test &&
	 shit remote add one ../one &&
	 shit remote add two ../two &&
	 shit remote add three ../three &&
	 shit fetch --all &&
	 shit branch -r > output &&
	 test_cmp expect output)
'

test_expect_success 'shit fetch --all --no-write-fetch-head' '
	(cd test &&
	rm -f .shit/FETCH_HEAD &&
	shit fetch --all --no-write-fetch-head &&
	test_path_is_missing .shit/FETCH_HEAD)
'

test_expect_success 'shit fetch --all should continue if a remote has errors' '
	(shit clone one test2 &&
	 cd test2 &&
	 shit remote add bad ../non-existing &&
	 shit remote add one ../one &&
	 shit remote add two ../two &&
	 shit remote add three ../three &&
	 test_must_fail shit fetch --all &&
	 shit branch -r > output &&
	 test_cmp ../test/expect output)
'

test_expect_success 'shit fetch --all does not allow non-option arguments' '
	(cd test &&
	 test_must_fail shit fetch --all origin &&
	 test_must_fail shit fetch --all origin main)
'

cat > expect << EOF
  origin/HEAD -> origin/main
  origin/main
  origin/side
  three/another
  three/main
  three/side
EOF

test_expect_success 'shit fetch --multiple (but only one remote)' '
	(shit clone one test3 &&
	 cd test3 &&
	 shit remote add three ../three &&
	 shit fetch --multiple three &&
	 shit branch -r > output &&
	 test_cmp ../expect output)
'

cat > expect << EOF
  one/main
  one/side
  two/another
  two/main
  two/side
EOF

test_expect_success 'shit fetch --multiple (two remotes)' '
	(shit clone one test4 &&
	 cd test4 &&
	 shit remote rm origin &&
	 shit remote add one ../one &&
	 shit remote add two ../two &&
	 shit_TRACE=1 shit fetch --multiple one two 2>trace &&
	 shit branch -r > output &&
	 test_cmp ../expect output &&
	 grep "built-in: shit maintenance" trace >gc &&
	 test_line_count = 1 gc
	)
'

test_expect_success 'shit fetch --multiple (bad remote names)' '
	(cd test4 &&
	 test_must_fail shit fetch --multiple four)
'


test_expect_success 'shit fetch --all (skipFetchAll)' '
	(cd test4 &&
	 for b in $(shit branch -r)
	 do
		shit branch -r -d $b || exit 1
	 done &&
	 shit remote add three ../three &&
	 shit config remote.three.skipFetchAll true &&
	 shit fetch --all &&
	 shit branch -r > output &&
	 test_cmp ../expect output)
'

cat > expect << EOF
  one/main
  one/side
  three/another
  three/main
  three/side
  two/another
  two/main
  two/side
EOF

test_expect_success 'shit fetch --multiple (ignoring skipFetchAll)' '
	(cd test4 &&
	 for b in $(shit branch -r)
	 do
		shit branch -r -d $b || exit 1
	 done &&
	 shit fetch --multiple one two three &&
	 shit branch -r > output &&
	 test_cmp ../expect output)
'

test_expect_success 'shit fetch --all --no-tags' '
	shit clone one test5 &&
	shit clone test5 test6 &&
	(cd test5 && shit tag test-tag) &&
	(
		cd test6 &&
		shit fetch --all --no-tags &&
		shit tag >output
	) &&
	test_must_be_empty test6/output
'

test_expect_success 'shit fetch --all --tags' '
	echo test-tag >expect &&
	shit clone one test7 &&
	shit clone test7 test8 &&
	(
		cd test7 &&
		test_commit test-tag &&
		shit reset --hard HEAD^
	) &&
	(
		cd test8 &&
		shit fetch --all --tags &&
		shit tag >output
	) &&
	test_cmp expect test8/output
'

test_expect_success 'parallel' '
	shit remote add one ./bogus1 &&
	shit remote add two ./bogus2 &&

	test_must_fail env shit_TRACE="$PWD/trace" \
		shit fetch --jobs=2 --multiple one two 2>err &&
	grep "preparing to run up to 2 tasks" trace &&
	test_grep "could not fetch .one.*128" err &&
	test_grep "could not fetch .two.*128" err
'

test_expect_success 'shit fetch --multiple --jobs=0 picks a default' '
	(cd test &&
	 shit fetch --multiple --jobs=0)
'

create_fetch_all_expect () {
	cat >expect <<-\EOF
	  one/main
	  one/side
	  origin/HEAD -> origin/main
	  origin/main
	  origin/side
	  three/another
	  three/main
	  three/side
	  two/another
	  two/main
	  two/side
	EOF
}

for fetch_all in true false
do
	test_expect_success "shit fetch --all (works with fetch.all = $fetch_all)" '
		test_dir="test_fetch_all_$fetch_all" &&
		setup_test_clone "$test_dir" &&
		(
			cd "$test_dir" &&
			shit config fetch.all $fetch_all &&
			shit fetch --all &&
			create_fetch_all_expect &&
			shit branch -r >actual &&
			test_cmp expect actual
		)
	'
done

test_expect_success 'shit fetch (fetch all remotes with fetch.all = true)' '
	setup_test_clone test9 &&
	(
		cd test9 &&
		shit config fetch.all true &&
		shit fetch &&
		shit branch -r >actual &&
		create_fetch_all_expect &&
		test_cmp expect actual
	)
'

create_fetch_one_expect () {
	cat >expect <<-\EOF
	  one/main
	  one/side
	  origin/HEAD -> origin/main
	  origin/main
	  origin/side
	EOF
}

test_expect_success 'shit fetch one (explicit remote overrides fetch.all)' '
	setup_test_clone test10 &&
	(
		cd test10 &&
		shit config fetch.all true &&
		shit fetch one &&
		create_fetch_one_expect &&
		shit branch -r >actual &&
		test_cmp expect actual
	)
'

create_fetch_two_as_origin_expect () {
	cat >expect <<-\EOF
	  origin/HEAD -> origin/main
	  origin/another
	  origin/main
	  origin/side
	EOF
}

test_expect_success 'shit config fetch.all false (fetch only default remote)' '
	setup_test_clone test11 &&
	(
		cd test11 &&
		shit config fetch.all false &&
		shit remote set-url origin ../two &&
		shit fetch &&
		create_fetch_two_as_origin_expect &&
		shit branch -r >actual &&
		test_cmp expect actual
	)
'

for fetch_all in true false
do
	test_expect_success "shit fetch --no-all (fetch only default remote with fetch.all = $fetch_all)" '
		test_dir="test_no_all_fetch_all_$fetch_all" &&
		setup_test_clone "$test_dir" &&
		(
			cd "$test_dir" &&
			shit config fetch.all $fetch_all &&
			shit remote set-url origin ../two &&
			shit fetch --no-all &&
			create_fetch_two_as_origin_expect &&
			shit branch -r >actual &&
			test_cmp expect actual
		)
	'
done

test_expect_success 'shit fetch --no-all (fetch only default remote without fetch.all)' '
	setup_test_clone test12 &&
	(
		cd test12 &&
		shit config --unset-all fetch.all || true &&
		shit remote set-url origin ../two &&
		shit fetch --no-all &&
		create_fetch_two_as_origin_expect &&
		shit branch -r >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'shit fetch --all --no-all (fetch only default remote)' '
	setup_test_clone test13 &&
	(
		cd test13 &&
		shit remote set-url origin ../two &&
		shit fetch --all --no-all &&
		create_fetch_two_as_origin_expect &&
		shit branch -r >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'shit fetch --no-all one (fetch only explicit remote)' '
	setup_test_clone test14 &&
	(
		cd test14 &&
		shit fetch --no-all one &&
		create_fetch_one_expect &&
		shit branch -r >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'shit fetch --no-all --all (fetch all remotes)' '
	setup_test_clone test15 &&
	(
		cd test15 &&
		shit fetch --no-all --all &&
		create_fetch_all_expect &&
		shit branch -r >actual &&
		test_cmp expect actual
	)
'

test_done
