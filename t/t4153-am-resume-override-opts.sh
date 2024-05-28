#!/bin/sh

test_description='shit-am command-line options override saved options'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-terminal.sh

format_patch () {
	shit format-patch --stdout -1 "$1" >"$1".eml
}

test_expect_success 'setup' '
	test_commit initial file &&
	test_commit first file &&

	shit checkout initial &&
	shit mv file file2 &&
	test_tick &&
	shit commit -m renamed-file &&
	shit tag renamed-file &&

	shit checkout -b side initial &&
	test_commit side1 file &&
	test_commit side2 file &&

	format_patch side1 &&
	format_patch side2
'

test_expect_success TTY '--3way overrides --no-3way' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout renamed-file &&

	# Applying side1 will fail as the file has been renamed.
	test_must_fail shit am --no-3way side[12].eml &&
	test_path_is_dir .shit/rebase-apply &&
	test_cmp_rev renamed-file HEAD &&
	test -z "$(shit ls-files -u)" &&

	# Applying side1 with am --3way will succeed due to the threeway-merge.
	# Applying side2 will fail as --3way does not apply to it.
	test_must_fail test_terminal shit am --3way </dev/zero &&
	test_path_is_dir .shit/rebase-apply &&
	test side1 = "$(cat file2)"
'

test_expect_success '--no-quiet overrides --quiet' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&

	# Applying side1 will be quiet.
	test_must_fail shit am --quiet side[123].eml >out &&
	test_path_is_dir .shit/rebase-apply &&
	test_grep ! "^Applying: " out &&
	echo side1 >file &&
	shit add file &&

	# Applying side1 will not be quiet.
	# Applying side2 will be quiet.
	shit am --no-quiet --continue >out &&
	echo "Applying: side1" >expected &&
	test_cmp expected out
'

test_expect_success '--signoff overrides --no-signoff' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&

	test_must_fail shit am --no-signoff side[12].eml &&
	test_path_is_dir .shit/rebase-apply &&
	echo side1 >file &&
	shit add file &&
	shit am --signoff --continue &&

	# Applied side1 will be signed off
	echo "Signed-off-by: $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL>" >expected &&
	shit cat-file commit HEAD^ | grep "Signed-off-by:" >actual &&
	test_cmp expected actual &&

	# Applied side2 will not be signed off
	test $(shit cat-file commit HEAD | grep -c "Signed-off-by:") -eq 0
'

test_expect_success TTY '--reject overrides --no-reject' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	rm -f file.rej &&

	test_must_fail shit am --no-reject side1.eml &&
	test_path_is_dir .shit/rebase-apply &&
	test_path_is_missing file.rej &&

	test_must_fail test_terminal shit am --reject </dev/zero &&
	test_path_is_dir .shit/rebase-apply &&
	test_path_is_file file.rej
'

test_done
