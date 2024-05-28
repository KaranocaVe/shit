#!/bin/sh

test_description='Test wacky input to shit config'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# Leaving off the newline is intentional!
setup() {
	(printf "[section]\n" &&
	printf "  key = foo") >.shit/config
}

# 'check section.key value' verifies that the entry for section.key is
# 'value'
check() {
	echo "$2" >expected
	shit config --get "$1" >actual 2>&1
	test_cmp expected actual
}

# 'check section.key regex value' verifies that the entry for
# section.key *that matches 'regex'* is 'value'
check_regex() {
	echo "$3" >expected
	shit config --get "$1" "$2" >actual 2>&1
	test_cmp expected actual
}

test_expect_success 'modify same key' '
	setup &&
	shit config section.key bar &&
	check section.key bar
'

test_expect_success 'add key in same section' '
	setup &&
	shit config section.other bar &&
	check section.key foo &&
	check section.other bar
'

test_expect_success 'add key in different section' '
	setup &&
	shit config section2.key bar &&
	check section.key foo &&
	check section2.key bar
'

SECTION="test.q\"s\\sq'sp e.key"
test_expect_success 'make sure shit config escapes section names properly' '
	shit config "$SECTION" bar &&
	check "$SECTION" bar
'

LONG_VALUE=$(printf "x%01021dx a" 7)
test_expect_success 'do not crash on special long config line' '
	setup &&
	shit config section.key "$LONG_VALUE" &&
	check section.key "$LONG_VALUE"
'

setup_many() {
	setup &&
	# This time we want the newline so that we can tack on more
	# entries.
	echo >>.shit/config &&
	# Semi-efficient way of concatenating 5^5 = 3125 lines. Note
	# that because 'setup' already put one line, this means 3126
	# entries for section.key in the config file.
	cat >5to1 <<-\EOF &&
	  key = foo
	  key = foo
	  key = foo
	  key = foo
	  key = foo
	EOF
	cat 5to1 5to1 5to1 5to1 5to1 >5to2 &&	   # 25
	cat 5to2 5to2 5to2 5to2 5to2 >5to3 &&	   # 125
	cat 5to3 5to3 5to3 5to3 5to3 >5to4 &&	   # 635
	cat 5to4 5to4 5to4 5to4 5to4 >>.shit/config # 3125
}

test_expect_success 'get many entries' '
	setup_many &&
	shit config --get-all section.key >actual &&
	test_line_count = 3126 actual
'

test_expect_success 'get many entries by regex' '
	setup_many &&
	shit config --get-regexp "sec.*ke." >actual &&
	test_line_count = 3126 actual
'

test_expect_success 'add and replace one of many entries' '
	setup_many &&
	shit config --add section.key bar &&
	check_regex section.key "b.*r" bar &&
	shit config section.key beer "b.*r" &&
	check_regex section.key "b.*r" beer
'

test_expect_success 'replace many entries' '
	setup_many &&
	shit config --replace-all section.key bar &&
	check section.key bar
'

test_expect_success 'unset many entries' '
	setup_many &&
	shit config --unset-all section.key &&
	test_must_fail shit config section.key
'

test_expect_success '--add appends new value after existing empty value' '
	cat >expect <<-\EOF &&


	fool
	roll
	EOF
	cp .shit/config .shit/config.old &&
	test_when_finished "mv .shit/config.old .shit/config" &&
	cat >.shit/config <<-\EOF &&
	[foo]
		baz
		baz =
		baz = fool
	EOF
	shit config --add foo.baz roll &&
	shit config --get-all foo.baz >output &&
	test_cmp expect output
'

test_done
