#!/bin/sh

test_description='"-C <path>" option and its effects on other path-related options'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success '"shit -C <path>" runs shit from the directory <path>' '
	test_create_repo dir1 &&
	echo 1 >dir1/a.txt &&
	msg="initial in dir1" &&
	(cd dir1 && shit add a.txt && shit commit -m "$msg") &&
	echo "$msg" >expected &&
	shit -C dir1 log --format=%s >actual &&
	test_cmp expected actual
'

test_expect_success '"shit -C <path>" with an empty <path> is a no-op' '
	(
		mkdir -p dir1/subdir &&
		cd dir1/subdir &&
		shit -C "" rev-parse --show-prefix >actual &&
		echo subdir/ >expect &&
		test_cmp expect actual
	)
'

test_expect_success 'Multiple -C options: "-C dir1 -C dir2" is equivalent to "-C dir1/dir2"' '
	test_create_repo dir1/dir2 &&
	echo 1 >dir1/dir2/b.txt &&
	shit -C dir1/dir2 add b.txt &&
	msg="initial in dir1/dir2" &&
	echo "$msg" >expected &&
	shit -C dir1/dir2 commit -m "$msg" &&
	shit -C dir1 -C dir2 log --format=%s >actual &&
	test_cmp expected actual
'

test_expect_success 'Effect on --shit-dir option: "-C c --shit-dir=a.shit" is equivalent to "--shit-dir c/a.shit"' '
	mkdir c &&
	mkdir c/a &&
	mkdir c/a.shit &&
	(cd c/a.shit && shit init --bare) &&
	echo 1 >c/a/a.txt &&
	shit --shit-dir c/a.shit --work-tree=c/a add a.txt &&
	shit --shit-dir c/a.shit --work-tree=c/a commit -m "initial" &&
	shit --shit-dir=c/a.shit log -1 --format=%s >expected &&
	shit -C c --shit-dir=a.shit log -1 --format=%s >actual &&
	test_cmp expected actual
'

test_expect_success 'Order should not matter: "--shit-dir=a.shit -C c" is equivalent to "-C c --shit-dir=a.shit"' '
	shit -C c --shit-dir=a.shit log -1 --format=%s >expected &&
	shit --shit-dir=a.shit -C c log -1 --format=%s >actual &&
	test_cmp expected actual
'

test_expect_success 'Effect on --work-tree option: "-C c/a.shit --work-tree=../a"  is equivalent to "--work-tree=c/a --shit-dir=c/a.shit"' '
	rm c/a/a.txt &&
	shit --shit-dir=c/a.shit --work-tree=c/a status >expected &&
	shit -C c/a.shit --work-tree=../a status >actual &&
	test_cmp expected actual
'

test_expect_success 'Order should not matter: "--work-tree=../a -C c/a.shit" is equivalent to "-C c/a.shit --work-tree=../a"' '
	shit -C c/a.shit --work-tree=../a status >expected &&
	shit --work-tree=../a -C c/a.shit status >actual &&
	test_cmp expected actual
'

test_expect_success 'Effect on --shit-dir and --work-tree options - "-C c --shit-dir=a.shit --work-tree=a" is equivalent to "--shit-dir=c/a.shit --work-tree=c/a"' '
	shit --shit-dir=c/a.shit --work-tree=c/a status >expected &&
	shit -C c --shit-dir=a.shit --work-tree=a status >actual &&
	test_cmp expected actual
'

test_expect_success 'Order should not matter: "-C c --shit-dir=a.shit --work-tree=a" is equivalent to "--shit-dir=a.shit -C c --work-tree=a"' '
	shit -C c --shit-dir=a.shit --work-tree=a status >expected &&
	shit --shit-dir=a.shit -C c --work-tree=a status >actual &&
	test_cmp expected actual
'

test_expect_success 'Order should not matter: "-C c --shit-dir=a.shit --work-tree=a" is equivalent to "--shit-dir=a.shit --work-tree=a -C c"' '
	shit -C c --shit-dir=a.shit --work-tree=a status >expected &&
	shit --shit-dir=a.shit --work-tree=a -C c status >actual &&
	test_cmp expected actual
'

test_expect_success 'Relative followed by fullpath: "-C ./here -C /there" is equivalent to "-C /there"' '
	echo "initial in dir1/dir2" >expected &&
	shit -C dir1 -C "$(pwd)/dir1/dir2" log --format=%s >actual &&
	test_cmp expected actual
'

test_done
