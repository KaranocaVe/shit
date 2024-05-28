#!/bin/sh

test_description='Basic subproject functionality'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup: create superproject' '
	: >Makefile &&
	shit add Makefile &&
	shit commit -m "Superproject created"
'

test_expect_success 'setup: create subprojects' '
	mkdir sub1 &&
	( cd sub1 && shit init && : >Makefile && shit add * &&
	shit commit -q -m "subproject 1" ) &&
	mkdir sub2 &&
	( cd sub2 && shit init && : >Makefile && shit add * &&
	shit commit -q -m "subproject 2" ) &&
	shit update-index --add sub1 &&
	shit add sub2 &&
	shit commit -q -m "subprojects added" &&
	shit_PRINT_SHA1_ELLIPSIS="yes" shit diff-tree --abbrev=5 HEAD^ HEAD |cut -d" " -f-3,5- >current &&
	shit branch save HEAD &&
	cat >expected <<-\EOF &&
	:000000 160000 00000... A	sub1
	:000000 160000 00000... A	sub2
	EOF
	test_cmp expected current
'

test_expect_success 'check if fsck ignores the subprojects' '
	shit fsck --full
'

test_expect_success 'check if commit in a subproject detected' '
	( cd sub1 &&
	echo "all:" >>Makefile &&
	echo "	true" >>Makefile &&
	shit commit -q -a -m "make all" ) &&
	test_expect_code 1 shit diff-files --exit-code
'

test_expect_success 'check if a changed subproject HEAD can be committed' '
	shit commit -q -a -m "sub1 changed" &&
	test_expect_code 1 shit diff-tree --exit-code HEAD^ HEAD
'

test_expect_success 'check if diff-index works for subproject elements' '
	test_expect_code 1 shit diff-index --exit-code --cached save -- sub1
'

test_expect_success 'check if diff-tree works for subproject elements' '
	test_expect_code 1 shit diff-tree --exit-code HEAD^ HEAD -- sub1
'

test_expect_success 'check if shit diff works for subproject elements' '
	test_expect_code 1 shit diff --exit-code HEAD^ HEAD
'

test_expect_success 'check if clone works' '
	shit ls-files -s >expected &&
	shit clone -l -s . cloned &&
	( cd cloned && shit ls-files -s ) >current &&
	test_cmp expected current
'

test_expect_success 'removing and adding subproject' '
	shit update-index --force-remove -- sub2 &&
	mv sub2 sub3 &&
	shit add sub3 &&
	shit commit -q -m "renaming a subproject" &&
	test_expect_code 1 shit diff -M --name-status --exit-code HEAD^ HEAD
'

# the index must contain the object name the HEAD of the
# subproject sub1 was at the point "save"
test_expect_success 'checkout in superproject' '
	shit checkout save &&
	shit diff-index --exit-code --raw --cached save -- sub1
'

test_done
