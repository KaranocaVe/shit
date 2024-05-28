#!/bin/sh

test_description='shit apply --3way'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

print_sanitized_conflicted_diff () {
	shit diff HEAD >diff.raw &&
	sed -e '
		/^index /d
		s/^\(+[<>|][<>|][<>|][<>|]*\) .*/\1/
	' diff.raw
}

test_expect_success setup '
	test_tick &&
	test_write_lines 1 2 3 4 5 6 7 >one &&
	cat one >two &&
	shit add one two &&
	shit commit -m initial &&

	shit branch side &&

	test_tick &&
	test_write_lines 1 two 3 4 5 six 7 >one &&
	test_write_lines 1 two 3 4 5 6 7 >two &&
	shit commit -a -m main &&

	shit checkout side &&
	test_write_lines 1 2 3 4 five 6 7 >one &&
	test_write_lines 1 2 3 4 five 6 7 >two &&
	shit commit -a -m side &&

	shit checkout main
'

test_expect_success 'apply without --3way' '
	shit diff side^ side >P.diff &&

	# should fail to apply
	shit reset --hard &&
	shit checkout main^0 &&
	test_must_fail shit apply --index P.diff &&
	# should leave things intact
	shit diff-files --exit-code &&
	shit diff-index --exit-code --cached HEAD
'

test_apply_with_3way () {
	# Merging side should be similar to applying this patch
	shit diff ...side >P.diff &&

	# The corresponding conflicted merge
	shit reset --hard &&
	shit checkout main^0 &&
	test_must_fail shit merge --no-commit side &&
	shit ls-files -s >expect.ls &&
	print_sanitized_conflicted_diff >expect.diff &&

	# should fail to apply
	shit reset --hard &&
	shit checkout main^0 &&
	test_must_fail shit apply --index --3way P.diff &&
	shit ls-files -s >actual.ls &&
	print_sanitized_conflicted_diff >actual.diff &&

	# The result should resemble the corresponding merge
	test_cmp expect.ls actual.ls &&
	test_cmp expect.diff actual.diff
}

test_expect_success 'apply with --3way' '
	test_apply_with_3way
'

test_expect_success 'apply with --3way with merge.conflictStyle = diff3' '
	test_config merge.conflictStyle diff3 &&
	test_apply_with_3way
'

test_expect_success 'apply with --3way with rerere enabled' '
	test_config rerere.enabled true &&

	# Merging side should be similar to applying this patch
	shit diff ...side >P.diff &&

	# The corresponding conflicted merge
	shit reset --hard &&
	shit checkout main^0 &&
	test_must_fail shit merge --no-commit side &&

	# Manually resolve and record the resolution
	test_write_lines 1 two 3 4 five six 7 >one &&
	shit rerere &&
	cat one >expect &&

	# should fail to apply
	shit reset --hard &&
	shit checkout main^0 &&
	test_must_fail shit apply --index --3way P.diff &&

	# but rerere should have replayed the recorded resolution
	test_cmp expect one
'

test_expect_success 'apply -3 with add/add conflict setup' '
	shit reset --hard &&

	shit checkout -b adder &&
	test_write_lines 1 2 3 4 5 6 7 >three &&
	test_write_lines 1 2 3 4 5 6 7 >four &&
	shit add three four &&
	shit commit -m "add three and four" &&

	shit checkout -b another adder^ &&
	test_write_lines 1 2 3 4 5 6 7 >three &&
	test_write_lines 1 2 3 four 5 6 7 >four &&
	shit add three four &&
	shit commit -m "add three and four" &&

	# Merging another should be similar to applying this patch
	shit diff adder...another >P.diff &&

	shit checkout adder^0 &&
	test_must_fail shit merge --no-commit another &&
	shit ls-files -s >expect.ls &&
	print_sanitized_conflicted_diff >expect.diff
'

test_expect_success 'apply -3 with add/add conflict' '
	# should fail to apply ...
	shit reset --hard &&
	shit checkout adder^0 &&
	test_must_fail shit apply --index --3way P.diff &&
	# ... and leave conflicts in the index and in the working tree
	shit ls-files -s >actual.ls &&
	print_sanitized_conflicted_diff >actual.diff &&

	# The result should resemble the corresponding merge
	test_cmp expect.ls actual.ls &&
	test_cmp expect.diff actual.diff
'

test_expect_success 'apply -3 with add/add conflict (dirty working tree)' '
	# should fail to apply ...
	shit reset --hard &&
	shit checkout adder^0 &&
	echo >>four &&
	cat four >four.save &&
	cat three >three.save &&
	shit ls-files -s >expect.ls &&
	test_must_fail shit apply --index --3way P.diff &&
	# ... and should not touch anything
	shit ls-files -s >actual.ls &&
	test_cmp expect.ls actual.ls &&
	test_cmp four.save four &&
	test_cmp three.save three
'

test_expect_success 'apply -3 with ambiguous repeating file' '
	shit reset --hard &&
	test_write_lines 1 2 1 2 1 2 1 2 1 2 1 >one_two_repeat &&
	shit add one_two_repeat &&
	shit commit -m "init one" &&
	test_write_lines 1 2 1 2 1 2 1 2 one 2 1 >one_two_repeat &&
	shit commit -a -m "change one" &&

	shit diff HEAD~ >Repeat.diff &&
	shit reset --hard HEAD~ &&

	test_write_lines 1 2 1 2 1 2 one 2 1 2 one >one_two_repeat &&
	shit commit -a -m "change surrounding one" &&

	shit apply --index --3way Repeat.diff &&
	test_write_lines 1 2 1 2 1 2 one 2 one 2 one >expect &&

	test_cmp expect one_two_repeat
'

test_expect_success 'apply with --3way --cached clean apply' '
	# Merging side should be similar to applying this patch
	shit diff ...side >P.diff &&

	# The corresponding cleanly applied merge
	shit reset --hard &&
	shit checkout main~ &&
	shit merge --no-commit side &&
	shit ls-files -s >expect.ls &&

	# should succeed
	shit reset --hard &&
	shit checkout main~ &&
	shit apply --cached --3way P.diff &&
	shit ls-files -s >actual.ls &&
	print_sanitized_conflicted_diff >actual.diff &&

	# The cache should resemble the corresponding merge
	# (both files at stage #0)
	test_cmp expect.ls actual.ls &&
	# However the working directory should not change
	>expect.diff &&
	test_cmp expect.diff actual.diff
'

test_expect_success 'apply with --3way --cached and conflicts' '
	# Merging side should be similar to applying this patch
	shit diff ...side >P.diff &&

	# The corresponding conflicted merge
	shit reset --hard &&
	shit checkout main^0 &&
	test_must_fail shit merge --no-commit side &&
	shit ls-files -s >expect.ls &&

	# should fail to apply
	shit reset --hard &&
	shit checkout main^0 &&
	test_must_fail shit apply --cached --3way P.diff &&
	shit ls-files -s >actual.ls &&
	print_sanitized_conflicted_diff >actual.diff &&

	# The cache should resemble the corresponding merge
	# (one file at stage #0, one file at stages #1 #2 #3)
	test_cmp expect.ls actual.ls &&
	# However the working directory should not change
	>expect.diff &&
	test_cmp expect.diff actual.diff
'

test_expect_success 'apply binary file patch' '
	shit reset --hard main &&
	cp "$TEST_DIRECTORY/test-binary-1.png" bin.png &&
	shit add bin.png &&
	shit commit -m "add binary file" &&

	cp "$TEST_DIRECTORY/test-binary-2.png" bin.png &&

	shit diff --binary >bin.diff &&
	shit reset --hard &&

	# Apply must succeed.
	shit apply bin.diff
'

test_expect_success 'apply binary file patch with 3way' '
	shit reset --hard main &&
	cp "$TEST_DIRECTORY/test-binary-1.png" bin.png &&
	shit add bin.png &&
	shit commit -m "add binary file" &&

	cp "$TEST_DIRECTORY/test-binary-2.png" bin.png &&

	shit diff --binary >bin.diff &&
	shit reset --hard &&

	# Apply must succeed.
	shit apply --3way --index bin.diff
'

test_expect_success 'apply full-index patch with 3way' '
	shit reset --hard main &&
	cp "$TEST_DIRECTORY/test-binary-1.png" bin.png &&
	shit add bin.png &&
	shit commit -m "add binary file" &&

	cp "$TEST_DIRECTORY/test-binary-2.png" bin.png &&

	shit diff --full-index >bin.diff &&
	shit reset --hard &&

	# Apply must succeed.
	shit apply --3way --index bin.diff
'

test_expect_success 'apply delete then new patch with 3way' '
	shit reset --hard main &&
	test_write_lines 2 > delnew &&
	shit add delnew &&
	shit diff --cached >> new.patch &&
	shit reset --hard &&
	test_write_lines 1 > delnew &&
	shit add delnew &&
	shit commit -m "delnew" &&
	rm delnew &&
	shit diff >> delete-then-new.patch &&
	cat new.patch >> delete-then-new.patch &&

	shit checkout -- . &&
	# Apply must succeed.
	shit apply --3way delete-then-new.patch
'

test_done
