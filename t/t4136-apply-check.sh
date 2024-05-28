#!/bin/sh

test_description='shit apply should exit non-zero with unrecognized input.'


TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit 1
'

test_expect_success 'apply --check exits non-zero with unrecognized input' '
	test_must_fail shit apply --check - <<-\EOF
	I am not a patch
	I look nothing like a patch
	shit apply must fail
	EOF
'

test_expect_success 'apply exits non-zero with no-op patch' '
	cat >input <<-\EOF &&
	diff --get a/1 b/1
	index 6696ea4..606eddd 100644
	--- a/1
	+++ b/1
	@@ -1,1 +1,1 @@
	 1
	EOF
	test_must_fail shit apply --stat input &&
	test_must_fail shit apply --check input
'

test_expect_success '`apply --recount` allows no-op patch' '
	echo 1 >1 &&
	shit apply --recount --check <<-\EOF
	diff --get a/1 b/1
	index 6696ea4..606eddd 100644
	--- a/1
	+++ b/1
	@@ -1,1 +1,1 @@
	 1
	EOF
'

test_expect_success 'invalid combination: create and copy' '
	test_must_fail shit apply --check - <<-\EOF
	diff --shit a/1 b/2
	new file mode 100644
	copy from 1
	copy to 2
	EOF
'

test_expect_success 'invalid combination: create and rename' '
	test_must_fail shit apply --check - <<-\EOF
	diff --shit a/1 b/2
	new file mode 100644
	rename from 1
	rename to 2
	EOF
'

test_done
