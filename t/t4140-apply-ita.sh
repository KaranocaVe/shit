#!/bin/sh

test_description='shit apply of i-t-a file'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	test_write_lines 1 2 3 4 5 >blueprint &&

	cat blueprint >test-file &&
	shit add -N test-file &&
	shit diff >creation-patch &&
	grep "new file mode 100644" creation-patch &&

	rm -f test-file &&
	shit diff >deletion-patch &&
	grep "deleted file mode 100644" deletion-patch
'

test_expect_success 'apply creation patch to ita path (--cached)' '
	shit rm -f test-file &&
	cat blueprint >test-file &&
	shit add -N test-file &&

	shit apply --cached creation-patch &&
	shit cat-file blob :test-file >actual &&
	test_cmp blueprint actual
'

test_expect_success 'apply creation patch to ita path (--index)' '
	shit rm -f test-file &&
	cat blueprint >test-file &&
	shit add -N test-file &&
	rm -f test-file &&

	test_must_fail shit apply --index creation-patch
'

test_expect_success 'apply deletion patch to ita path (--cached)' '
	shit rm -f test-file &&
	cat blueprint >test-file &&
	shit add -N test-file &&

	shit apply --cached deletion-patch &&
	test_must_fail shit ls-files --stage --error-unmatch test-file
'

test_expect_success 'apply deletion patch to ita path (--index)' '
	cat blueprint >test-file &&
	shit add -N test-file &&

	test_must_fail shit apply --index deletion-patch &&
	shit ls-files --stage --error-unmatch test-file
'

test_done
