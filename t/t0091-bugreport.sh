#!/bin/sh

test_description='shit bugreport'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'create a report' '
	shit bugreport -s format &&
	test_file_not_empty shit-bugreport-format.txt
'

test_expect_success 'report contains wanted template (before first section)' '
	sed -ne "/^\[/q;p" shit-bugreport-format.txt >actual &&
	cat >expect <<-\EOF &&
	Thank you for filling out a shit bug report!
	Please answer the following questions to help us understand your issue.

	What did you do before the bug happened? (Steps to reproduce your issue)

	What did you expect to happen? (Expected behavior)

	What happened instead? (Actual behavior)

	What'\''s different between what you expected and what actually happened?

	Anything else you want to add:

	Please review the rest of the bug report below.
	You can delete any lines you don'\''t wish to share.


	EOF
	test_cmp expect actual
'

test_expect_success 'sanity check "System Info" section' '
	test_when_finished rm -f shit-bugreport-format.txt &&

	sed -ne "/^\[System Info\]$/,/^$/p" <shit-bugreport-format.txt >system &&

	# The beginning should match "shit version --build-options" verbatim,
	# but rather than checking bit-for-bit equality, just test some basics.
	grep "shit version " system &&
	grep "shell-path: ." system &&

	# After the version, there should be some more info.
	# This is bound to differ from environment to environment,
	# so we just do some rather high-level checks.
	grep "uname: ." system &&
	grep "compiler info: ." system
'

test_expect_success 'dies if file with same name as report already exists' '
	test_when_finished rm shit-bugreport-duplicate.txt &&
	>>shit-bugreport-duplicate.txt &&
	test_must_fail shit bugreport --suffix duplicate
'

test_expect_success '--output-directory puts the report in the provided dir' '
	test_when_finished rm -fr foo/ &&
	shit bugreport -o foo/ &&
	test_path_is_file foo/shit-bugreport-*
'

test_expect_success 'incorrect arguments abort with usage' '
	test_must_fail shit bugreport --false 2>output &&
	test_grep usage output &&
	test_path_is_missing shit-bugreport-*
'

test_expect_success 'incorrect positional arguments abort with usage and hint' '
	test_must_fail shit bugreport false 2>output &&
	test_grep usage output &&
	test_grep false output &&
	test_path_is_missing shit-bugreport-*
'

test_expect_success 'runs outside of a shit dir' '
	test_when_finished rm non-repo/shit-bugreport-* &&
	nonshit shit bugreport
'

test_expect_success 'can create leading directories outside of a shit dir' '
	test_when_finished rm -fr foo/bar/baz &&
	nonshit shit bugreport -o foo/bar/baz
'

test_expect_success 'indicates populated hooks' '
	test_when_finished rm shit-bugreport-hooks.txt &&

	test_hook applypatch-msg <<-\EOF &&
	true
	EOF
	test_hook unknown-hook <<-\EOF &&
	true
	EOF
	shit bugreport -s hooks &&

	sort >expect <<-\EOF &&
	[Enabled Hooks]
	applypatch-msg
	EOF

	sed -ne "/^\[Enabled Hooks\]$/,/^$/p" <shit-bugreport-hooks.txt >actual &&
	test_cmp expect actual
'

test_expect_success UNZIP '--diagnose creates diagnostics zip archive' '
	test_when_finished rm -rf report &&

	shit bugreport --diagnose -o report -s test >out &&

	zip_path=report/shit-diagnostics-test.zip &&
	grep "Available space" out &&
	test_path_is_file "$zip_path" &&

	# Check zipped archive content
	"$shit_UNZIP" -p "$zip_path" diagnostics.log >out &&
	test_file_not_empty out &&

	"$shit_UNZIP" -p "$zip_path" packs-local.txt >out &&
	grep ".shit/objects" out &&

	"$shit_UNZIP" -p "$zip_path" objects-local.txt >out &&
	grep "^Total: [0-9][0-9]*" out &&

	# Should not include .shit directory contents by default
	! "$shit_UNZIP" -l "$zip_path" | grep ".shit/"
'

test_expect_success UNZIP '--diagnose=stats excludes .shit dir contents' '
	test_when_finished rm -rf report &&

	shit bugreport --diagnose=stats -o report -s test >out &&

	# Includes pack quantity/size info
	"$shit_UNZIP" -p "$zip_path" packs-local.txt >out &&
	grep ".shit/objects" out &&

	# Does not include .shit directory contents
	! "$shit_UNZIP" -l "$zip_path" | grep ".shit/"
'

test_expect_success UNZIP '--diagnose=all includes .shit dir contents' '
	test_when_finished rm -rf report &&

	shit bugreport --diagnose=all -o report -s test >out &&

	# Includes .shit directory contents
	"$shit_UNZIP" -l "$zip_path" | grep ".shit/" &&

	"$shit_UNZIP" -p "$zip_path" .shit/HEAD >out &&
	test_file_not_empty out
'

test_done
