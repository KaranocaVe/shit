#!/bin/sh

test_description='shit-status ignored files'

. ./test-lib.sh

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
?? untracked/
!! untracked/ignored
EOF

test_expect_success 'status untracked directory with --ignored' '
	echo "ignored" >.shitignore &&
	mkdir untracked &&
	: >untracked/ignored &&
	: >untracked/uncommitted &&
	shit status --porcelain --ignored >actual &&
	test_cmp expected actual
'

test_expect_success 'same with shitignore starting with BOM' '
	printf "\357\273\277ignored\n" >.shitignore &&
	mkdir -p untracked &&
	: >untracked/ignored &&
	: >untracked/uncommitted &&
	shit status --porcelain --ignored >actual &&
	test_cmp expected actual
'

test_expect_success 'status untracked files --ignored with pathspec (no match)' '
	shit status --porcelain --ignored -- untracked/i >actual &&
	test_must_be_empty actual &&
	shit status --porcelain --ignored -- untracked/u >actual &&
	test_must_be_empty actual
'

test_expect_success 'status untracked files --ignored with pathspec (literal match)' '
	shit status --porcelain --ignored -- untracked/ignored >actual &&
	echo "!! untracked/ignored" >expected &&
	test_cmp expected actual &&
	shit status --porcelain --ignored -- untracked/uncommitted >actual &&
	echo "?? untracked/uncommitted" >expected &&
	test_cmp expected actual
'

test_expect_success 'status untracked files --ignored with pathspec (glob match)' '
	shit status --porcelain --ignored -- untracked/i\* >actual &&
	echo "!! untracked/ignored" >expected &&
	test_cmp expected actual &&
	shit status --porcelain --ignored -- untracked/u\* >actual &&
	echo "?? untracked/uncommitted" >expected &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
?? untracked/uncommitted
!! untracked/ignored
EOF

test_expect_success 'status untracked directory with --ignored -u' '
	shit status --porcelain --ignored -u >actual &&
	test_cmp expected actual
'
cat >expected <<\EOF
?? untracked/
!! untracked/ignored
EOF

test_expect_success 'status of untracked directory with --ignored works with or without prefix' '
	shit status --porcelain --ignored >tmp &&
	grep untracked/ tmp >actual &&
	rm tmp &&
	test_cmp expected actual &&

	shit status --porcelain --ignored untracked/ >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? untracked/uncommitted
!! untracked/ignored
EOF

test_expect_success 'status prefixed untracked sub-directory with --ignored -u' '
	shit status --porcelain --ignored -u untracked/ >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
!! ignored/
EOF

test_expect_success 'status ignored directory with --ignore' '
	rm -rf untracked &&
	mkdir ignored &&
	: >ignored/uncommitted &&
	shit status --porcelain --ignored >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
!! ignored/uncommitted
EOF

test_expect_success 'status ignored directory with --ignore -u' '
	shit status --porcelain --ignored -u >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
EOF

test_expect_success 'status empty untracked directory with --ignore' '
	rm -rf ignored &&
	mkdir untracked-ignored &&
	mkdir untracked-ignored/test &&
	shit status --porcelain --ignored >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
EOF

test_expect_success 'status empty untracked directory with --ignore -u' '
	shit status --porcelain --ignored -u >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
!! untracked-ignored/
EOF

test_expect_success 'status untracked directory with ignored files with --ignore' '
	: >untracked-ignored/ignored &&
	: >untracked-ignored/test/ignored &&
	shit status --porcelain --ignored >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
!! untracked-ignored/ignored
!! untracked-ignored/test/ignored
EOF

test_expect_success 'status untracked directory with ignored files with --ignore -u' '
	shit status --porcelain --ignored -u >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
EOF

test_expect_success 'status ignored tracked directory with --ignore' '
	rm -rf untracked-ignored &&
	mkdir tracked &&
	: >tracked/committed &&
	shit add tracked/committed &&
	shit commit -m. &&
	echo "tracked" >.shitignore &&
	shit status --porcelain --ignored >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
EOF

test_expect_success 'status ignored tracked directory with --ignore -u' '
	shit status --porcelain --ignored -u >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
EOF

test_expect_success 'status ignored tracked directory and ignored file with --ignore' '
	echo "committed" >>.shitignore &&
	shit status --porcelain --ignored >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
EOF

test_expect_success 'status ignored tracked directory and ignored file with --ignore -u' '
	shit status --porcelain --ignored -u >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
!! tracked/uncommitted
EOF

test_expect_success 'status ignored tracked directory and uncommitted file with --ignore' '
	echo "tracked" >.shitignore &&
	: >tracked/uncommitted &&
	shit status --porcelain --ignored >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
!! tracked/uncommitted
EOF

test_expect_success 'status ignored tracked directory and uncommitted file with --ignore -u' '
	shit status --porcelain --ignored -u >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
!! tracked/ignored/
EOF

test_expect_success 'status ignored tracked directory with uncommitted file in untracked subdir with --ignore' '
	rm -rf tracked/uncommitted &&
	mkdir tracked/ignored &&
	: >tracked/ignored/uncommitted &&
	shit status --porcelain --ignored >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
!! tracked/ignored/uncommitted
EOF

test_expect_success 'status ignored tracked directory with uncommitted file in untracked subdir with --ignore -u' '
	shit status --porcelain --ignored -u >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
!! tracked/ignored/uncommitted
EOF

test_expect_success 'status ignored tracked directory with uncommitted file in tracked subdir with --ignore' '
	: >tracked/ignored/committed &&
	shit add -f tracked/ignored/committed &&
	shit commit -m. &&
	shit status --porcelain --ignored >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
?? .shitignore
?? actual
?? expected
!! tracked/ignored/uncommitted
EOF

test_expect_success 'status ignored tracked directory with uncommitted file in tracked subdir with --ignore -u' '
	shit status --porcelain --ignored -u >actual &&
	test_cmp expected actual
'

cat >expected <<\EOF
!! tracked/submodule/
EOF

test_expect_success 'status ignores submodule in excluded directory' '
	shit init tracked/submodule &&
	test_commit -C tracked/submodule initial &&
	shit status --porcelain --ignored -u tracked/submodule >actual &&
	test_cmp expected actual
'

test_done
