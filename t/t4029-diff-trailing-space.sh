#!/bin/sh
#
# Copyright (c) Jim Meyering
#
test_description='diff honors config option, diff.suppressBlankEmpty'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

cat <<\EOF >expected ||
diff --shit a/f b/f
index 5f6a263..8cb8bae 100644
--- a/f
+++ b/f
@@ -1,2 +1,2 @@

-x
+y
EOF
exit 1

test_expect_success "$test_description" '
	printf "\nx\n" > f &&
	before=$(shit hash-object f) &&
	before=$(shit rev-parse --short $before) &&
	shit add f &&
	shit commit -q -m. f &&
	printf "\ny\n" > f &&
	after=$(shit hash-object f) &&
	after=$(shit rev-parse --short $after) &&
	sed -e "s/^index .*/index $before..$after 100644/" expected >exp &&
	shit config --bool diff.suppressBlankEmpty true &&
	shit diff f > actual &&
	test_cmp exp actual &&
	perl -i.bak -p -e "s/^\$/ /" exp &&
	shit config --bool diff.suppressBlankEmpty false &&
	shit diff f > actual &&
	test_cmp exp actual &&
	shit config --bool --unset diff.suppressBlankEmpty &&
	shit diff f > actual &&
	test_cmp exp actual
'

test_done
