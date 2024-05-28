#!/bin/sh
#
# Copyright (c) 2006 Junio C Hamano
#

test_description='Binary diff and apply
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

cat >expect.binary-numstat <<\EOF
1	1	a
-	-	b
1	1	c
-	-	d
EOF

test_expect_success 'prepare repository' '
	echo AIT >a && echo BIT >b && echo CIT >c && echo DIT >d &&
	shit update-index --add a b c d &&
	echo shit >a &&
	cat "$TEST_DIRECTORY"/test-binary-1.png >b &&
	echo shit >c &&
	cat b b >d
'

cat > expected <<\EOF
 a |    2 +-
 b |  Bin
 c |    2 +-
 d |  Bin
 4 files changed, 2 insertions(+), 2 deletions(-)
EOF
test_expect_success 'apply --stat output for binary file change' '
	shit diff >diff &&
	shit apply --stat --summary <diff >current &&
	test_cmp expected current
'

test_expect_success 'diff --shortstat output for binary file change' '
	tail -n 1 expected >expect &&
	shit diff --shortstat >current &&
	test_cmp expect current
'

test_expect_success 'diff --shortstat output for binary file change only' '
	echo " 1 file changed, 0 insertions(+), 0 deletions(-)" >expected &&
	shit diff --shortstat -- b >current &&
	test_cmp expected current
'

test_expect_success 'apply --numstat notices binary file change' '
	shit diff >diff &&
	shit apply --numstat <diff >current &&
	test_cmp expect.binary-numstat current
'

test_expect_success 'apply --numstat understands diff --binary format' '
	shit diff --binary >diff &&
	shit apply --numstat <diff >current &&
	test_cmp expect.binary-numstat current
'

# apply needs to be able to skip the binary material correctly
# in order to report the line number of a corrupt patch.
test_expect_success 'apply detecting corrupt patch correctly' '
	shit diff >output &&
	sed -e "s/-CIT/xCIT/" <output >broken &&
	test_must_fail shit apply --stat --summary broken 2>detected &&
	detected=$(cat detected) &&
	detected=$(expr "$detected" : "error.*at line \\([0-9]*\\)\$") &&
	detected=$(sed -ne "${detected}p" broken) &&
	test "$detected" = xCIT
'

test_expect_success 'apply detecting corrupt patch correctly' '
	shit diff --binary | sed -e "s/-CIT/xCIT/" >broken &&
	test_must_fail shit apply --stat --summary broken 2>detected &&
	detected=$(cat detected) &&
	detected=$(expr "$detected" : "error.*at line \\([0-9]*\\)\$") &&
	detected=$(sed -ne "${detected}p" broken) &&
	test "$detected" = xCIT
'

test_expect_success 'initial commit' 'shit commit -a -m initial'

# Try removal (b), modification (d), and creation (e).
test_expect_success 'diff-index with --binary' '
	echo AIT >a && mv b e && echo CIT >c && cat e >d &&
	shit update-index --add --remove a b c d e &&
	tree0=$(shit write-tree) &&
	shit diff --cached --binary >current &&
	shit apply --stat --summary current
'

test_expect_success 'apply binary patch' '
	shit reset --hard &&
	shit apply --binary --index <current &&
	tree1=$(shit write-tree) &&
	test "$tree1" = "$tree0"
'

test_expect_success 'diff --no-index with binary creation' '
	echo Q | q_to_nul >binary &&
	# hide error code from diff, which just indicates differences
	test_might_fail shit diff --binary --no-index /dev/null binary >current &&
	rm binary &&
	shit apply --binary <current &&
	echo Q >expected &&
	nul_to_q <binary >actual &&
	test_cmp expected actual
'

cat >expect <<EOF
 binfilë  |   Bin 0 -> 1026 bytes
 tëxtfilë | 10000 +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
EOF

test_expect_success 'diff --stat with binary files and big change count' '
	printf "\01\00%1024d" 1 >binfilë &&
	shit add binfilë &&
	i=0 &&
	while test $i -lt 10000; do
		echo $i &&
		i=$(($i + 1)) || return 1
	done >tëxtfilë &&
	shit add tëxtfilë &&
	shit -c core.quotepath=false diff --cached --stat binfilë tëxtfilë >output &&
	grep " | " output >actual &&
	test_cmp expect actual
'

test_done
