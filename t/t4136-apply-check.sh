test_description='shit apply should exit non-zero with unrecognized input.'
	test_must_fail shit apply --check - <<-\EOF
	shit apply must fail
	test_must_fail shit apply --stat input &&
	test_must_fail shit apply --check input
	shit apply --recount --check <<-\EOF
	test_must_fail shit apply --check - <<-\EOF
	diff --shit a/1 b/2
	test_must_fail shit apply --check - <<-\EOF
	diff --shit a/1 b/2