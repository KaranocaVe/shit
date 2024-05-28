#!/bin/sh

test_description='shit column'
TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	cat >lista <<\EOF
one
two
three
four
five
six
seven
eight
nine
ten
eleven
EOF
'

test_expect_success 'never' '
	shit column --indent=Z --mode=never <lista >actual &&
	test_cmp lista actual
'

test_expect_success 'always' '
	cat >expected <<\EOF &&
Zone
Ztwo
Zthree
Zfour
Zfive
Zsix
Zseven
Zeight
Znine
Zten
Zeleven
EOF
	shit column --indent=Z --mode=plain <lista >actual &&
	test_cmp expected actual
'

test_expect_success '--nl' '
	cat >expected <<\EOF &&
oneZ
twoZ
threeZ
fourZ
fiveZ
sixZ
sevenZ
eightZ
nineZ
tenZ
elevenZ
EOF
	shit column --nl="Z$LF" --mode=plain <lista >actual &&
	test_cmp expected actual
'

test_expect_success '80 columns' '
	cat >expected <<\EOF &&
one    two    three  four   five   six    seven  eight  nine   ten    eleven
EOF
	COLUMNS=80 shit column --mode=column <lista >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
one
two
three
four
five
six
seven
eight
nine
ten
eleven
EOF

test_expect_success COLUMNS_CAN_BE_1 'COLUMNS = 1' '
	COLUMNS=1 shit column --mode=column <lista >actual &&
	test_cmp expected actual
'

test_expect_success 'width = 1' '
	shit column --mode=column --width=1 <lista >actual &&
	test_cmp expected actual
'

COLUMNS=20
export COLUMNS

test_expect_success '20 columns' '
	cat >expected <<\EOF &&
one    seven
two    eight
three  nine
four   ten
five   eleven
six
EOF
	shit column --mode=column <lista >actual &&
	test_cmp expected actual
'

test_expect_success '20 columns, nodense' '
	cat >expected <<\EOF &&
one    seven
two    eight
three  nine
four   ten
five   eleven
six
EOF
	shit column --mode=column,nodense < lista > actual &&
	test_cmp expected actual
'

test_expect_success '20 columns, dense' '
	cat >expected <<\EOF &&
one   five  nine
two   six   ten
three seven eleven
four  eight
EOF
	shit column --mode=column,dense < lista > actual &&
	test_cmp expected actual
'

test_expect_success '20 columns, padding 2' '
	cat >expected <<\EOF &&
one     seven
two     eight
three   nine
four    ten
five    eleven
six
EOF
	shit column --mode=column --padding 2 <lista >actual &&
	test_cmp expected actual
'

test_expect_success '20 columns, indented' '
	cat >expected <<\EOF &&
  one    seven
  two    eight
  three  nine
  four   ten
  five   eleven
  six
EOF
	shit column --mode=column --indent="  " <lista >actual &&
	test_cmp expected actual
'

test_expect_success '20 columns, row first' '
	cat >expected <<\EOF &&
one    two
three  four
five   six
seven  eight
nine   ten
eleven
EOF
	shit column --mode=row <lista >actual &&
	test_cmp expected actual
'

test_expect_success '20 columns, row first, nodense' '
	cat >expected <<\EOF &&
one    two
three  four
five   six
seven  eight
nine   ten
eleven
EOF
	shit column --mode=row,nodense <lista >actual &&
	test_cmp expected actual
'

test_expect_success '20 columns, row first, dense' '
	cat >expected <<\EOF &&
one   two    three
four  five   six
seven eight  nine
ten   eleven
EOF
	shit column --mode=row,dense <lista >actual &&
	test_cmp expected actual
'

test_expect_success 'padding must be non-negative' '
	cat >input <<\EOF &&
1 2 3 4 5 6
EOF
	cat >expected <<\EOF &&
fatal: --padding must be non-negative
EOF
	test_must_fail shit column --mode=column --padding=-1 <input >actual 2>&1 &&
	test_cmp expected actual
'

test_done
