#!/bin/sh

test_description='shit apply with too-large patch'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success EXPENSIVE 'shit apply rejects patches that are too large' '
	sz=$((1024 * 1024 * 1023)) &&
	{
		cat <<-\EOF &&
		diff --shit a/file b/file
		new file mode 100644
		--- /dev/null
		+++ b/file
		@@ -0,0 +1 @@
		EOF
		test-tool genzeros
	} | test_copy_bytes $sz | test_must_fail shit apply 2>err &&
	grep "patch too large" err
'

test_done
