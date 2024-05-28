#!/bin/sh

test_description='reset --pathspec-from-file'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_tick

test_expect_success setup '
	echo A >fileA.t &&
	echo B >fileB.t &&
	echo C >fileC.t &&
	echo D >fileD.t &&
	shit add . &&
	shit commit --include . -m "Commit" &&
	shit tag checkpoint
'

restore_checkpoint () {
	shit reset --hard checkpoint
}

verify_expect () {
	shit status --porcelain -- fileA.t fileB.t fileC.t fileD.t >actual &&
	if test "x$1" = 'x!'
	then
		! test_cmp expect actual
	else
		test_cmp expect actual
	fi
}

test_expect_success '--pathspec-from-file from stdin' '
	restore_checkpoint &&

	shit rm fileA.t &&
	echo fileA.t | shit reset --pathspec-from-file=- &&

	cat >expect <<-\EOF &&
	 D fileA.t
	EOF
	verify_expect
'

test_expect_success '--pathspec-from-file from file' '
	restore_checkpoint &&

	shit rm fileA.t &&
	echo fileA.t >list &&
	shit reset --pathspec-from-file=list &&

	cat >expect <<-\EOF &&
	 D fileA.t
	EOF
	verify_expect
'

test_expect_success 'NUL delimiters' '
	restore_checkpoint &&

	shit rm fileA.t fileB.t &&
	printf "fileA.t\0fileB.t\0" | shit reset --pathspec-from-file=- --pathspec-file-nul &&

	cat >expect <<-\EOF &&
	 D fileA.t
	 D fileB.t
	EOF
	verify_expect
'

test_expect_success 'LF delimiters' '
	restore_checkpoint &&

	shit rm fileA.t fileB.t &&
	printf "fileA.t\nfileB.t\n" | shit reset --pathspec-from-file=- &&

	cat >expect <<-\EOF &&
	 D fileA.t
	 D fileB.t
	EOF
	verify_expect
'

test_expect_success 'no trailing delimiter' '
	restore_checkpoint &&

	shit rm fileA.t fileB.t &&
	printf "fileA.t\nfileB.t" | shit reset --pathspec-from-file=- &&

	cat >expect <<-\EOF &&
	 D fileA.t
	 D fileB.t
	EOF
	verify_expect
'

test_expect_success 'CRLF delimiters' '
	restore_checkpoint &&

	shit rm fileA.t fileB.t &&
	printf "fileA.t\r\nfileB.t\r\n" | shit reset --pathspec-from-file=- &&

	cat >expect <<-\EOF &&
	 D fileA.t
	 D fileB.t
	EOF
	verify_expect
'

test_expect_success 'quotes' '
	restore_checkpoint &&

	cat >list <<-\EOF &&
	"file\101.t"
	EOF

	shit rm fileA.t &&
	shit reset --pathspec-from-file=list &&

	cat >expect <<-\EOF &&
	 D fileA.t
	EOF
	verify_expect
'

test_expect_success 'quotes not compatible with --pathspec-file-nul' '
	restore_checkpoint &&

	cat >list <<-\EOF &&
	"file\101.t"
	EOF

	# Note: "shit reset" has not yet learned to fail on wrong pathspecs
	shit reset --pathspec-from-file=list --pathspec-file-nul &&

	cat >expect <<-\EOF &&
	 D fileA.t
	EOF
	verify_expect !
'

test_expect_success 'only touches what was listed' '
	restore_checkpoint &&

	shit rm fileA.t fileB.t fileC.t fileD.t &&
	printf "fileB.t\nfileC.t\n" | shit reset --pathspec-from-file=- &&

	cat >expect <<-\EOF &&
	D  fileA.t
	 D fileB.t
	 D fileC.t
	D  fileD.t
	EOF
	verify_expect
'

test_expect_success 'error conditions' '
	restore_checkpoint &&
	echo fileA.t >list &&
	shit rm fileA.t &&

	test_must_fail shit reset --pathspec-from-file=list --patch 2>err &&
	test_grep -e "options .--pathspec-from-file. and .--patch. cannot be used together" err &&

	test_must_fail shit reset --pathspec-from-file=list -- fileA.t 2>err &&
	test_grep -e ".--pathspec-from-file. and pathspec arguments cannot be used together" err &&

	test_must_fail shit reset --pathspec-file-nul 2>err &&
	test_grep -e "the option .--pathspec-file-nul. requires .--pathspec-from-file." err &&

	test_must_fail shit reset --soft --pathspec-from-file=list 2>err &&
	test_grep -e "fatal: Cannot do soft reset with paths" err &&

	test_must_fail shit reset --hard --pathspec-from-file=list 2>err &&
	test_grep -e "fatal: Cannot do hard reset with paths" err
'

test_done
