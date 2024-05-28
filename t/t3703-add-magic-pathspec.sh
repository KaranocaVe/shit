#!/bin/sh

test_description='magic pathspec tests using shit-add'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	mkdir sub anothersub &&
	: >sub/foo &&
	: >anothersub/foo
'

test_expect_success 'add :/' "
	cat >expected <<-EOF &&
	add 'anothersub/foo'
	add 'expected'
	add 'sub/actual'
	add 'sub/foo'
	EOF
	(cd sub && shit add -n :/ >actual) &&
	test_cmp expected sub/actual
"

cat >expected <<EOF
add 'anothersub/foo'
EOF

test_expect_success 'add :/anothersub' '
	(cd sub && shit add -n :/anothersub >actual) &&
	test_cmp expected sub/actual
'

test_expect_success 'add :/non-existent' '
	(cd sub && test_must_fail shit add -n :/non-existent)
'

cat >expected <<EOF
add 'sub/foo'
EOF

if test_have_prereq !MINGW && mkdir ":" 2>/dev/null
then
	test_set_prereq COLON_DIR
fi

test_expect_success COLON_DIR 'a file with the same (long) magic name exists' '
	: >":(icase)ha" &&
	test_must_fail shit add -n ":(icase)ha" &&
	shit add -n "./:(icase)ha"
'

test_expect_success COLON_DIR 'a file with the same (short) magic name exists' '
	: >":/bar" &&
	test_must_fail shit add -n :/bar &&
	shit add -n "./:/bar"
'

test_done
