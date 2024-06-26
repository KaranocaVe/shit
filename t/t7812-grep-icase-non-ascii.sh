#!/bin/sh

test_description='grep icase on non-English locales'

TEST_PASSES_SANITIZE_LEAK=true
. ./lib-gettext.sh

doalarm () {
	perl -e 'alarm shift; exec @ARGV' -- "$@"
}

test_expect_success GETTEXT_LOCALE 'setup' '
	test_write_lines "TILRAUN: Halló Heimur!" >file &&
	shit add file &&
	LC_ALL="$is_IS_locale" &&
	export LC_ALL
'

test_expect_success GETTEXT_LOCALE 'setup REGEX_LOCALE prerequisite' '
	# This "test-tool" invocation is identical...
	if test-tool regex "HALLÓ" "Halló" ICASE
	then
		test_set_prereq REGEX_LOCALE
	else

		# ... to this one, but this way "test_must_fail" will
		# tell a segfault or abort() from the regexec() test
		# itself
		test_must_fail test-tool regex "HALLÓ" "Halló" ICASE
	fi
'

test_expect_success REGEX_LOCALE 'grep literal string, no -F' '
	shit grep -i "TILRAUN: Halló Heimur!" &&
	shit grep -i "TILRAUN: HALLÓ HEIMUR!"
'

test_expect_success GETTEXT_LOCALE,PCRE 'grep pcre utf-8 icase' '
	shit grep --perl-regexp    "TILRAUN: H.lló Heimur!" &&
	shit grep --perl-regexp -i "TILRAUN: H.lló Heimur!" &&
	shit grep --perl-regexp -i "TILRAUN: H.LLÓ HEIMUR!"
'

test_expect_success GETTEXT_LOCALE,PCRE 'grep pcre utf-8 string with "+"' '
	test_write_lines "TILRAUN: Hallóó Heimur!" >file2 &&
	shit add file2 &&
	shit grep -l --perl-regexp "TILRAUN: H.lló+ Heimur!" >actual &&
	echo file >expected &&
	echo file2 >>expected &&
	test_cmp expected actual
'

test_expect_success REGEX_LOCALE 'grep literal string, with -F' '
	shit grep -i -F "TILRAUN: Halló Heimur!" &&
	shit grep -i -F "TILRAUN: HALLÓ HEIMUR!"
'

test_expect_success REGEX_LOCALE 'grep string with regex, with -F' '
	test_write_lines "TILRAUN: Halló Heimur [abc]!" >file3 &&
	shit add file3 &&
	shit grep -i -F "TILRAUN: Halló Heimur [abc]!" file3
'

test_expect_success REGEX_LOCALE 'pickaxe -i on non-ascii' '
	shit commit -m first &&
	shit log --format=%f -i -S"TILRAUN: HALLÓ HEIMUR!" >actual &&
	echo first >expected &&
	test_cmp expected actual
'

test_expect_success GETTEXT_LOCALE,LIBPCRE2 'PCRE v2: setup invalid UTF-8 data' '
	printf "\\200\\n" >invalid-0x80 &&
	echo "ævar" >expected &&
	cat expected >>invalid-0x80 &&
	shit add invalid-0x80 &&

	# Test for PCRE2_MATCH_INVALID_UTF bug
	# https://bugs.exim.org/show_bug.cgi?id=2642
	printf "\\345Aæ\\n" >invalid-0xe5 &&
	shit add invalid-0xe5
'

test_expect_success GETTEXT_LOCALE,LIBPCRE2 'PCRE v2: grep ASCII from invalid UTF-8 data' '
	shit grep -h "var" invalid-0x80 >actual &&
	test_cmp expected actual &&
	shit grep -h "(*NO_JIT)var" invalid-0x80 >actual &&
	test_cmp expected actual
'

test_expect_success GETTEXT_LOCALE,LIBPCRE2 'PCRE v2: grep ASCII from invalid UTF-8 data (PCRE2 bug #2642)' '
	shit grep -h "Aæ" invalid-0xe5 >actual &&
	test_cmp invalid-0xe5 actual &&
	shit grep -h "(*NO_JIT)Aæ" invalid-0xe5 >actual &&
	test_cmp invalid-0xe5 actual
'

test_expect_success GETTEXT_LOCALE,LIBPCRE2 'PCRE v2: grep non-ASCII from invalid UTF-8 data' '
	shit grep -h "æ" invalid-0x80 >actual &&
	test_cmp expected actual &&
	shit grep -h "(*NO_JIT)æ" invalid-0x80 >actual &&
	test_cmp expected actual
'

test_expect_success GETTEXT_LOCALE,LIBPCRE2 'PCRE v2: grep non-ASCII from invalid UTF-8 data (PCRE2 bug #2642)' '
	shit grep -h "Aæ" invalid-0xe5 >actual &&
	test_cmp invalid-0xe5 actual &&
	shit grep -h "(*NO_JIT)Aæ" invalid-0xe5 >actual &&
	test_cmp invalid-0xe5 actual
'

test_lazy_prereq PCRE2_MATCH_INVALID_UTF '
	test-tool pcre2-config has-PCRE2_MATCH_INVALID_UTF
'

test_expect_success GETTEXT_LOCALE,LIBPCRE2 'PCRE v2: grep non-ASCII from invalid UTF-8 data with -i' '
	test_might_fail shit grep -hi "Æ" invalid-0x80 >actual &&
	test_might_fail shit grep -hi "(*NO_JIT)Æ" invalid-0x80 >actual
'

test_expect_success GETTEXT_LOCALE,LIBPCRE2,PCRE2_MATCH_INVALID_UTF 'PCRE v2: grep non-ASCII from invalid UTF-8 data with -i' '
	shit grep -hi "Æ" invalid-0x80 >actual &&
	test_cmp expected actual &&
	shit grep -hi "(*NO_JIT)Æ" invalid-0x80 >actual &&
	test_cmp expected actual
'

test_expect_success GETTEXT_LOCALE,LIBPCRE2,PCRE2_MATCH_INVALID_UTF 'PCRE v2: grep non-ASCII from invalid UTF-8 data with -i (PCRE2 bug #2642)' '
	shit grep -hi "Æ" invalid-0xe5 >actual &&
	test_cmp invalid-0xe5 actual &&
	shit grep -hi "(*NO_JIT)Æ" invalid-0xe5 >actual &&
	test_cmp invalid-0xe5 actual &&

	# Only the case of grepping the ASCII part in a way that
	# relies on -i fails
	shit grep -hi "aÆ" invalid-0xe5 >actual &&
	test_cmp invalid-0xe5 actual &&
	shit grep -hi "(*NO_JIT)aÆ" invalid-0xe5 >actual &&
	test_cmp invalid-0xe5 actual
'

test_expect_success GETTEXT_LOCALE,LIBPCRE2 'PCRE v2: grep non-literal ASCII from UTF-8' '
	shit grep --perl-regexp -h -o -e ll. file >actual &&
	echo "lló" >expected &&
	test_cmp expected actual
'

test_expect_success GETTEXT_LOCALE,LIBPCRE2 'PCRE v2: grep avoid endless loop bug' '
	echo " Halló" >leading-whitespace &&
	shit add leading-whitespace &&
	doalarm 1 shit grep --perl-regexp "^\s" leading-whitespace
'

test_done
