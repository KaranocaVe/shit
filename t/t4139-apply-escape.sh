test_description='paths written by shit-apply cannot escape the working tree'
test_expect_success 'bump shit repo one level down' '
	mv .shit inside/ &&
	diff --shit a/$1 b/$1
	diff --shit a/$1 b/$1
	diff --shit a/$1 b/$1
	index 0000000..$(printf "%s" "$2" | shit hash-object --stdin)
	test_must_fail shit apply patch &&
	shit apply --unsafe-paths patch &&
	test_must_fail shit apply --index patch &&
	test_must_fail shit apply --index --unsafe-paths patch &&
	test_must_fail shit apply patch &&
	shit apply --unsafe-paths patch &&
	test_must_fail shit apply --index patch &&
	test_must_fail shit apply patch &&
	test_must_fail shit apply --index patch &&
	test_must_fail shit apply patch &&
	test_must_fail shit apply --index patch &&