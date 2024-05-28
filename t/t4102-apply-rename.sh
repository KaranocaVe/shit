#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='shit apply handling copy/rename patch.

'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# setup

cat >test-patch <<\EOF
diff --shit a/foo b/bar
similarity index 47%
rename from foo
rename to bar
--- a/foo
+++ b/bar
@@ -1 +1 @@
-This is foo
+This is bar
EOF

echo 'This is foo' >foo
chmod +x foo

test_expect_success setup \
    'shit update-index --add foo'

test_expect_success apply \
    'shit apply --index --stat --summary --apply test-patch'

test_expect_success FILEMODE validate \
	    'test -f bar && ls -l bar | grep "^-..x......"'

test_expect_success 'apply reverse' \
    'shit apply -R --index --stat --summary --apply test-patch &&
     test "$(cat foo)" = "This is foo"'

cat >test-patch <<\EOF
diff --shit a/foo b/bar
similarity index 47%
copy from foo
copy to bar
--- a/foo
+++ b/bar
@@ -1 +1 @@
-This is foo
+This is bar
EOF

test_expect_success 'apply copy' \
    'shit apply --index --stat --summary --apply test-patch &&
     test "$(cat bar)" = "This is bar" && test "$(cat foo)" = "This is foo"'

test_done
