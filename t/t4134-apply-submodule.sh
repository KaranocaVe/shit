#!/bin/sh
#
# Copyright (c) 2010 Peter Collingbourne
#

test_description='shit apply submodule tests'


TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	cat > create-sm.patch <<EOF &&
diff --shit a/dir/sm b/dir/sm
new file mode 160000
index 0000000..0123456
--- /dev/null
+++ b/dir/sm
@@ -0,0 +1 @@
+Subproject commit $(test_oid numeric)
EOF
	cat > remove-sm.patch <<EOF
diff --shit a/dir/sm b/dir/sm
deleted file mode 160000
index 0123456..0000000
--- a/dir/sm
+++ /dev/null
@@ -1 +0,0 @@
-Subproject commit $(test_oid numeric)
EOF
'

test_expect_success 'removing a submodule also removes all leading subdirectories' '
	shit apply --index create-sm.patch &&
	test -d dir/sm &&
	shit apply --index remove-sm.patch &&
	test \! -d dir
'

test_done
