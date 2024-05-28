#!/bin/sh

test_description='applying patch with mode bits'


TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	echo original >file &&
	shit add file &&
	test_tick &&
	shit commit -m initial &&
	shit tag initial &&
	echo modified >file &&
	shit diff --stat -p >patch-0.txt &&
	chmod +x file &&
	shit diff --stat -p >patch-1.txt &&
	sed "s/^\(new mode \).*/\1/" <patch-1.txt >patch-empty-mode.txt &&
	sed "s/^\(new mode \).*/\1garbage/" <patch-1.txt >patch-bogus-mode.txt
'

test_expect_success FILEMODE 'same mode (no index)' '
	shit reset --hard &&
	chmod +x file &&
	shit apply patch-0.txt &&
	test -x file
'

test_expect_success FILEMODE 'same mode (with index)' '
	shit reset --hard &&
	chmod +x file &&
	shit add file &&
	shit apply --index patch-0.txt &&
	test -x file &&
	shit diff --exit-code
'

test_expect_success FILEMODE 'same mode (index only)' '
	shit reset --hard &&
	chmod +x file &&
	shit add file &&
	shit apply --cached patch-0.txt &&
	shit ls-files -s file >ls-files-output &&
	test_grep "^100755" ls-files-output
'

test_expect_success FILEMODE 'mode update (no index)' '
	shit reset --hard &&
	shit apply patch-1.txt &&
	test -x file
'

test_expect_success FILEMODE 'mode update (with index)' '
	shit reset --hard &&
	shit apply --index patch-1.txt &&
	test -x file &&
	shit diff --exit-code
'

test_expect_success FILEMODE 'mode update (index only)' '
	shit reset --hard &&
	shit apply --cached patch-1.txt &&
	shit ls-files -s file >ls-files-output &&
	test_grep "^100755" ls-files-output
'

test_expect_success FILEMODE 'empty mode is rejected' '
	shit reset --hard &&
	test_must_fail shit apply patch-empty-mode.txt 2>err &&
	test_grep "invalid mode" err
'

test_expect_success FILEMODE 'bogus mode is rejected' '
	shit reset --hard &&
	test_must_fail shit apply patch-bogus-mode.txt 2>err &&
	test_grep "invalid mode" err
'

test_expect_success POSIXPERM 'do not use core.sharedRepository for working tree files' '
	shit reset --hard &&
	test_config core.sharedRepository 0666 &&
	(
		# Remove a default ACL if possible.
		(setfacl -k . 2>/dev/null || true) &&
		umask 0077 &&

		# Test both files (f1) and leading dirs (d)
		mkdir d &&
		touch f1 d/f2 &&
		shit add f1 d/f2 &&
		shit diff --staged >patch-f1-and-f2.txt &&

		rm -rf d f1 &&
		shit apply patch-f1-and-f2.txt &&

		echo "-rw-------" >f1_mode.expected &&
		echo "drwx------" >d_mode.expected &&
		test_modebits f1 >f1_mode.actual &&
		test_modebits d >d_mode.actual &&
		test_cmp f1_mode.expected f1_mode.actual &&
		test_cmp d_mode.expected d_mode.actual
	)
'

test_expect_success 'shit apply respects core.fileMode' '
	test_config core.fileMode false &&
	echo true >script.sh &&
	shit add --chmod=+x script.sh &&
	shit ls-files -s script.sh >ls-files-output &&
	test_grep "^100755" ls-files-output &&
	test_tick && shit commit -m "Add script" &&
	shit ls-tree -r HEAD script.sh >ls-tree-output &&
	test_grep "^100755" ls-tree-output &&

	echo true >>script.sh &&
	test_tick && shit commit -m "Modify script" script.sh &&
	shit format-patch -1 --stdout >patch &&
	test_grep "^index.*100755$" patch &&

	shit switch -c branch HEAD^ &&
	shit apply --index patch 2>err &&
	test_grep ! "has type 100644, expected 100755" err &&
	shit reset --hard &&

	shit apply patch 2>err &&
	test_grep ! "has type 100644, expected 100755" err &&

	shit apply --cached patch 2>err &&
	test_grep ! "has type 100644, expected 100755" err
'

test_done
