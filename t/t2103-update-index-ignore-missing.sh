#!/bin/sh

test_description='update-index with options'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success basics '
	>one &&
	>two &&
	>three &&

	# need --add when adding
	test_must_fail shit update-index one &&
	test -z "$(shit ls-files)" &&
	shit update-index --add one &&
	test zone = "z$(shit ls-files)" &&

	# update-index is atomic
	echo 1 >one &&
	test_must_fail shit update-index one two &&
	echo "M	one" >expect &&
	shit diff-files --name-status >actual &&
	test_cmp expect actual &&

	shit update-index --add one two three &&
	test_write_lines one three two >expect &&
	shit ls-files >actual &&
	test_cmp expect actual &&

	test_tick &&
	(
		test_create_repo xyzzy &&
		cd xyzzy &&
		>file &&
		shit add file &&
		shit commit -m "sub initial"
	) &&
	shit add xyzzy &&

	test_tick &&
	shit commit -m initial &&
	shit tag initial
'

test_expect_success '--ignore-missing --refresh' '
	shit reset --hard initial &&
	echo 2 >one &&
	test_must_fail shit update-index --refresh &&
	echo 1 >one &&
	shit update-index --refresh &&
	rm -f two &&
	test_must_fail shit update-index --refresh &&
	shit update-index --ignore-missing --refresh

'

test_expect_success '--unmerged --refresh' '
	shit reset --hard initial &&
	info=$(shit ls-files -s one | sed -e "s/ 0	/ 1	/") &&
	shit rm --cached one &&
	echo "$info" | shit update-index --index-info &&
	test_must_fail shit update-index --refresh &&
	shit update-index --unmerged --refresh &&
	echo 2 >two &&
	test_must_fail shit update-index --unmerged --refresh >actual &&
	grep two actual &&
	! grep one actual &&
	! grep three actual
'

test_expect_success '--ignore-submodules --refresh (1)' '
	shit reset --hard initial &&
	rm -f two &&
	test_must_fail shit update-index --ignore-submodules --refresh
'

test_expect_success '--ignore-submodules --refresh (2)' '
	shit reset --hard initial &&
	test_tick &&
	(
		cd xyzzy &&
		shit commit -m "sub second" --allow-empty
	) &&
	test_must_fail shit update-index --refresh &&
	test_must_fail shit update-index --ignore-missing --refresh &&
	shit update-index --ignore-submodules --refresh
'

test_done
