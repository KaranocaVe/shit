test_description='shit apply with too-large patch'
test_expect_success EXPENSIVE 'shit apply rejects patches that are too large' '
		diff --shit a/file b/file
	} | test_copy_bytes $sz | test_must_fail shit apply 2>err &&