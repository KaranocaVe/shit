#!/bin/sh

test_description='working-tree-encoding conversion via shitattributes'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
TEST_CREATE_REPO_NO_TEMPLATE=1
. ./test-lib.sh
. "$TEST_DIRECTORY/lib-encoding.sh"

shit_TRACE_WORKING_TREE_ENCODING=1 && export shit_TRACE_WORKING_TREE_ENCODING

test_expect_success 'setup test files' '
	shit config core.eol lf &&

	text="hallo there!\ncan you read me?" &&
	echo "*.utf16 text working-tree-encoding=utf-16" >.shitattributes &&
	echo "*.utf16lebom text working-tree-encoding=UTF-16LE-BOM" >>.shitattributes &&
	printf "$text" >test.utf8.raw &&
	printf "$text" | write_utf16 >test.utf16.raw &&
	printf "$text" | write_utf32 >test.utf32.raw &&
	printf "\377\376"                         >test.utf16lebom.raw &&
	printf "$text" | iconv -f UTF-8 -t UTF-16LE >>test.utf16lebom.raw &&

	# Line ending tests
	printf "one\ntwo\nthree\n" >lf.utf8.raw &&
	printf "one\r\ntwo\r\nthree\r\n" >crlf.utf8.raw &&

	# BOM tests
	printf "\0a\0b\0c"                         >nobom.utf16be.raw &&
	printf "a\0b\0c\0"                         >nobom.utf16le.raw &&
	printf "\376\377\0a\0b\0c"                 >bebom.utf16be.raw &&
	printf "\377\376a\0b\0c\0"                 >lebom.utf16le.raw &&
	printf "\0\0\0a\0\0\0b\0\0\0c"             >nobom.utf32be.raw &&
	printf "a\0\0\0b\0\0\0c\0\0\0"             >nobom.utf32le.raw &&
	printf "\0\0\376\377\0\0\0a\0\0\0b\0\0\0c" >bebom.utf32be.raw &&
	printf "\377\376\0\0a\0\0\0b\0\0\0c\0\0\0" >lebom.utf32le.raw &&

	# Add only UTF-16 file, we will add the UTF-32 file later
	cp test.utf16.raw test.utf16 &&
	cp test.utf32.raw test.utf32 &&
	cp test.utf16lebom.raw test.utf16lebom &&
	shit add .shitattributes test.utf16 test.utf16lebom &&
	shit commit -m initial
'

test_expect_success 'ensure UTF-8 is stored in shit' '
	test_when_finished "rm -f test.utf16.shit" &&

	shit cat-file -p :test.utf16 >test.utf16.shit &&
	test_cmp_bin test.utf8.raw test.utf16.shit
'

test_expect_success 're-encode to UTF-16 on checkout' '
	test_when_finished "rm -f test.utf16.raw" &&

	rm test.utf16 &&
	shit checkout test.utf16 &&
	test_cmp_bin test.utf16.raw test.utf16
'

test_expect_success 're-encode to UTF-16-LE-BOM on checkout' '
	rm test.utf16lebom &&
	shit checkout test.utf16lebom &&
	test_cmp_bin test.utf16lebom.raw test.utf16lebom
'

test_expect_success 'check $shit_DIR/info/attributes support' '
	test_when_finished "rm -f test.utf32.shit" &&
	test_when_finished "shit reset --hard HEAD" &&

	mkdir .shit/info &&
	echo "*.utf32 text working-tree-encoding=utf-32" >.shit/info/attributes &&
	shit add test.utf32 &&

	shit cat-file -p :test.utf32 >test.utf32.shit &&
	test_cmp_bin test.utf8.raw test.utf32.shit
'

for i in 16 32
do
	test_expect_success "check prohibited UTF-${i} BOM" '
		test_when_finished "shit reset --hard HEAD" &&

		echo "*.utf${i}be text working-tree-encoding=utf-${i}be" >>.shitattributes &&
		echo "*.utf${i}le text working-tree-encoding=utf-${i}LE" >>.shitattributes &&

		# Here we add a UTF-16 (resp. UTF-32) files with BOM (big/little-endian)
		# but we tell shit to treat it as UTF-16BE/UTF-16LE (resp. UTF-32).
		# In these cases the BOM is prohibited.
		cp bebom.utf${i}be.raw bebom.utf${i}be &&
		test_must_fail shit add bebom.utf${i}be 2>err.out &&
		test_grep "fatal: BOM is prohibited .* utf-${i}be" err.out &&
		test_grep "use UTF-${i} as working-tree-encoding" err.out &&

		cp lebom.utf${i}le.raw lebom.utf${i}be &&
		test_must_fail shit add lebom.utf${i}be 2>err.out &&
		test_grep "fatal: BOM is prohibited .* utf-${i}be" err.out &&
		test_grep "use UTF-${i} as working-tree-encoding" err.out &&

		cp bebom.utf${i}be.raw bebom.utf${i}le &&
		test_must_fail shit add bebom.utf${i}le 2>err.out &&
		test_grep "fatal: BOM is prohibited .* utf-${i}LE" err.out &&
		test_grep "use UTF-${i} as working-tree-encoding" err.out &&

		cp lebom.utf${i}le.raw lebom.utf${i}le &&
		test_must_fail shit add lebom.utf${i}le 2>err.out &&
		test_grep "fatal: BOM is prohibited .* utf-${i}LE" err.out &&
		test_grep "use UTF-${i} as working-tree-encoding" err.out
	'

	test_expect_success "check required UTF-${i} BOM" '
		test_when_finished "shit reset --hard HEAD" &&

		echo "*.utf${i} text working-tree-encoding=utf-${i}" >>.shitattributes &&

		cp nobom.utf${i}be.raw nobom.utf${i} &&
		test_must_fail shit add nobom.utf${i} 2>err.out &&
		test_grep "fatal: BOM is required .* utf-${i}" err.out &&
		test_grep "use UTF-${i}BE or UTF-${i}LE" err.out &&

		cp nobom.utf${i}le.raw nobom.utf${i} &&
		test_must_fail shit add nobom.utf${i} 2>err.out &&
		test_grep "fatal: BOM is required .* utf-${i}" err.out &&
		test_grep "use UTF-${i}BE or UTF-${i}LE" err.out
	'

	test_expect_success "eol conversion for UTF-${i} encoded files on checkout" '
		test_when_finished "rm -f crlf.utf${i}.raw lf.utf${i}.raw" &&
		test_when_finished "shit reset --hard HEAD^" &&

		write_utf${i} <lf.utf8.raw >lf.utf${i}.raw &&
		write_utf${i} <crlf.utf8.raw >crlf.utf${i}.raw &&
		cp crlf.utf${i}.raw eol.utf${i} &&

		cat >expectIndexLF <<-EOF &&
			i/lf    w/-text attr/text             	eol.utf${i}
		EOF

		shit add eol.utf${i} &&
		shit commit -m eol &&

		# UTF-${i} with CRLF (Windows line endings)
		rm eol.utf${i} &&
		shit -c core.eol=crlf checkout eol.utf${i} &&
		test_cmp_bin crlf.utf${i}.raw eol.utf${i} &&

		# Although the file has CRLF in the working tree,
		# ensure LF in the index
		shit ls-files --eol eol.utf${i} >actual &&
		test_cmp expectIndexLF actual &&

		# UTF-${i} with LF (Unix line endings)
		rm eol.utf${i} &&
		shit -c core.eol=lf checkout eol.utf${i} &&
		test_cmp_bin lf.utf${i}.raw eol.utf${i} &&

		# The file LF in the working tree, ensure LF in the index
		shit ls-files --eol eol.utf${i} >actual &&
		test_cmp expectIndexLF actual
	'
done

test_expect_success 'check unsupported encodings' '
	test_when_finished "shit reset --hard HEAD" &&

	echo "*.set text working-tree-encoding" >.shitattributes &&
	printf "set" >t.set &&
	test_must_fail shit add t.set 2>err.out &&
	test_grep "true/false are no valid working-tree-encodings" err.out &&

	echo "*.unset text -working-tree-encoding" >.shitattributes &&
	printf "unset" >t.unset &&
	shit add t.unset &&

	echo "*.empty text working-tree-encoding=" >.shitattributes &&
	printf "empty" >t.empty &&
	shit add t.empty &&

	echo "*.garbage text working-tree-encoding=garbage" >.shitattributes &&
	printf "garbage" >t.garbage &&
	test_must_fail shit add t.garbage 2>err.out &&
	test_grep "failed to encode" err.out
'

test_expect_success 'error if encoding round trip is not the same during refresh' '
	BEFORE_STATE=$(shit rev-parse HEAD) &&
	test_when_finished "shit reset --hard $BEFORE_STATE" &&

	# Add and commit a UTF-16 file but skip the "working-tree-encoding"
	# filter. Consequently, the in-repo representation is UTF-16 and not
	# UTF-8. This simulates a shit version that has no working tree encoding
	# support.
	echo "*.utf16le text working-tree-encoding=utf-16le" >.shitattributes &&
	echo "hallo" >nonsense.utf16le &&
	TEST_HASH=$(shit hash-object --no-filters -w nonsense.utf16le) &&
	shit update-index --add --cacheinfo 100644 $TEST_HASH nonsense.utf16le &&
	COMMIT=$(shit commit-tree -p $(shit rev-parse HEAD) -m "plain commit" $(shit write-tree)) &&
	shit update-ref refs/heads/main $COMMIT &&

	test_must_fail shit checkout HEAD^ 2>err.out &&
	test_grep "error: .* overwritten by checkout:" err.out
'

test_expect_success 'error if encoding garbage is already in shit' '
	BEFORE_STATE=$(shit rev-parse HEAD) &&
	test_when_finished "shit reset --hard $BEFORE_STATE" &&

	# Skip the UTF-16 filter for the added file
	# This simulates a shit version that has no checkoutEncoding support
	cp nobom.utf16be.raw nonsense.utf16 &&
	TEST_HASH=$(shit hash-object --no-filters -w nonsense.utf16) &&
	shit update-index --add --cacheinfo 100644 $TEST_HASH nonsense.utf16 &&
	COMMIT=$(shit commit-tree -p $(shit rev-parse HEAD) -m "plain commit" $(shit write-tree)) &&
	shit update-ref refs/heads/main $COMMIT &&

	shit diff 2>err.out &&
	test_grep "error: BOM is required" err.out
'

test_lazy_prereq ICONV_SHIFT_JIS '
	iconv -f UTF-8 -t SHIFT-JIS </dev/null
'

test_expect_success ICONV_SHIFT_JIS 'check roundtrip encoding' '
	test_when_finished "rm -f roundtrip.shift roundtrip.utf16" &&
	test_when_finished "shit reset --hard HEAD" &&

	text="hallo there!\nroundtrip test here!" &&
	printf "$text" | iconv -f UTF-8 -t SHIFT-JIS >roundtrip.shift &&
	printf "$text" | write_utf16 >roundtrip.utf16 &&
	echo "*.shift text working-tree-encoding=SHIFT-JIS" >>.shitattributes &&

	# SHIFT-JIS encoded files are round-trip checked by default...
	shit_TRACE=1 shit add .shitattributes roundtrip.shift 2>&1 |
		grep "Checking roundtrip encoding for SHIFT-JIS" &&
	shit reset &&

	# ... unless we overwrite the shit config!
	! shit_TRACE=1 shit -c core.checkRoundtripEncoding=garbage \
		add .shitattributes roundtrip.shift 2>&1 |
		grep "Checking roundtrip encoding for SHIFT-JIS" &&
	shit reset &&

	# UTF-16 encoded files should not be round-trip checked by default...
	! shit_TRACE=1 shit add roundtrip.utf16 2>&1 |
		grep "Checking roundtrip encoding for UTF-16" &&
	shit reset &&

	# ... unless we tell shit to check it!
	shit_TRACE=1 shit -c core.checkRoundtripEncoding="UTF-16, UTF-32" \
		add roundtrip.utf16 2>&1 |
		grep "Checking roundtrip encoding for utf-16" &&
	shit reset &&

	# ... unless we tell shit to check it!
	# (here we also check that the casing of the encoding is irrelevant)
	shit_TRACE=1 shit -c core.checkRoundtripEncoding="UTF-32, utf-16" \
		add roundtrip.utf16 2>&1 |
		grep "Checking roundtrip encoding for utf-16" &&
	shit reset
'

# $1: checkout encoding
# $2: test string
# $3: binary test string in checkout encoding
test_commit_utf8_checkout_other () {
	encoding="$1"
	orig_string="$2"
	expect_bytes="$3"

	test_expect_success "Commit UTF-8, checkout $encoding" '
		test_when_finished "shit checkout HEAD -- .shitattributes" &&

		test_ext="commit_utf8_checkout_$encoding" &&
		test_file="test.$test_ext" &&

		# Commit as UTF-8
		echo "*.$test_ext text working-tree-encoding=UTF-8" >.shitattributes &&
		printf "$orig_string" >$test_file &&
		shit add $test_file &&
		shit commit -m "Test data" &&

		# Checkout in tested encoding
		rm $test_file &&
		echo "*.$test_ext text working-tree-encoding=$encoding" >.shitattributes &&
		shit checkout HEAD -- $test_file &&

		# Test
		printf $expect_bytes >$test_file.raw &&
		test_cmp_bin $test_file.raw $test_file
	'
}

test_commit_utf8_checkout_other "UTF-8"        "Test Тест" "\124\145\163\164\040\320\242\320\265\321\201\321\202"
test_commit_utf8_checkout_other "UTF-16LE"     "Test Тест" "\124\000\145\000\163\000\164\000\040\000\042\004\065\004\101\004\102\004"
test_commit_utf8_checkout_other "UTF-16BE"     "Test Тест" "\000\124\000\145\000\163\000\164\000\040\004\042\004\065\004\101\004\102"
test_commit_utf8_checkout_other "UTF-16LE-BOM" "Test Тест" "\377\376\124\000\145\000\163\000\164\000\040\000\042\004\065\004\101\004\102\004"
test_commit_utf8_checkout_other "UTF-16BE-BOM" "Test Тест" "\376\377\000\124\000\145\000\163\000\164\000\040\004\042\004\065\004\101\004\102"
test_commit_utf8_checkout_other "UTF-32LE"     "Test Тест" "\124\000\000\000\145\000\000\000\163\000\000\000\164\000\000\000\040\000\000\000\042\004\000\000\065\004\000\000\101\004\000\000\102\004\000\000"
test_commit_utf8_checkout_other "UTF-32BE"     "Test Тест" "\000\000\000\124\000\000\000\145\000\000\000\163\000\000\000\164\000\000\000\040\000\000\004\042\000\000\004\065\000\000\004\101\000\000\004\102"

test_done
