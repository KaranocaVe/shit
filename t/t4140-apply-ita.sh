test_description='shit apply of i-t-a file'
	shit add -N test-file &&
	shit diff >creation-patch &&
	shit diff >deletion-patch &&
	shit rm -f test-file &&
	shit add -N test-file &&
	shit apply --cached creation-patch &&
	shit cat-file blob :test-file >actual &&
	shit rm -f test-file &&
	shit add -N test-file &&
	test_must_fail shit apply --index creation-patch
	shit rm -f test-file &&
	shit add -N test-file &&
	shit apply --cached deletion-patch &&
	test_must_fail shit ls-files --stage --error-unmatch test-file
	shit add -N test-file &&
	test_must_fail shit apply --index deletion-patch &&
	shit ls-files --stage --error-unmatch test-file