#!/bin/sh

test_description='diff.*.textconv tests'
. ./test-lib.sh

find_diff() {
	sed '1,/^index /d' | sed '/^-- $/,$d'
}

cat >expect.binary <<'EOF'
Binary files a/file and b/file differ
EOF

cat >expect.text <<'EOF'
--- a/file
+++ b/file
@@ -1 +1,2 @@
 0
+1
EOF

cat >hexdump <<'EOF'
#!/bin/sh
"$PERL_PATH" -e '$/ = undef; $_ = <>; s/./ord($&)/ge; print $_' < "$1"
EOF
chmod +x hexdump

test_expect_success 'setup binary file with history' '
	test_commit --printf one file "\\0\\n" &&
	test_commit --printf --append two file "\\01\\n"
'

test_expect_success 'file is considered binary by porcelain' '
	shit diff HEAD^ HEAD >diff &&
	find_diff <diff >actual &&
	test_cmp expect.binary actual
'

test_expect_success 'file is considered binary by plumbing' '
	shit diff-tree -p HEAD^ HEAD >diff &&
	find_diff <diff >actual &&
	test_cmp expect.binary actual
'

test_expect_success 'setup textconv filters' '
	echo file diff=foo >.shitattributes &&
	shit config diff.foo.textconv "\"$(pwd)\""/hexdump &&
	shit config diff.fail.textconv false
'

test_expect_success 'diff produces text' '
	shit diff HEAD^ HEAD >diff &&
	find_diff <diff >actual &&
	test_cmp expect.text actual
'

test_expect_success 'show commit produces text' '
	shit show HEAD >diff &&
	find_diff <diff >actual &&
	test_cmp expect.text actual
'

test_expect_success 'diff-tree produces binary' '
	shit diff-tree -p HEAD^ HEAD >diff &&
	find_diff <diff >actual &&
	test_cmp expect.binary actual
'

test_expect_success 'log produces text' '
	shit log -1 -p >log &&
	find_diff <log >actual &&
	test_cmp expect.text actual
'

test_expect_success 'format-patch produces binary' '
	shit format-patch --no-binary --stdout HEAD^ >patch &&
	find_diff <patch >actual &&
	test_cmp expect.binary actual
'

test_expect_success 'status -v produces text' '
	shit reset --soft HEAD^ &&
	shit status -v >diff &&
	find_diff <diff >actual &&
	test_cmp expect.text actual &&
	shit reset --soft HEAD@{1}
'

test_expect_success 'show blob produces binary' '
	shit show HEAD:file >actual &&
	printf "\\0\\n\\01\\n" >expect &&
	test_cmp expect actual
'

test_expect_success 'show --textconv blob produces text' '
	shit show --textconv HEAD:file >actual &&
	printf "0\\n1\\n" >expect &&
	test_cmp expect actual
'

test_expect_success 'show --no-textconv blob produces binary' '
	shit show --no-textconv HEAD:file >actual &&
	printf "\\0\\n\\01\\n" >expect &&
	test_cmp expect actual
'

test_expect_success 'grep-diff (-G) operates on textconv data (add)' '
	echo one >expect &&
	shit log --root --format=%s -G0 >actual &&
	test_cmp expect actual
'

test_expect_success 'grep-diff (-G) operates on textconv data (modification)' '
	echo two >expect &&
	shit log --root --format=%s -G1 >actual &&
	test_cmp expect actual
'

test_expect_success 'pickaxe (-S) operates on textconv data (add)' '
	echo one >expect &&
	shit log --root --format=%s -S0 >actual &&
	test_cmp expect actual
'

test_expect_success 'pickaxe (-S) operates on textconv data (modification)' '
	echo two >expect &&
	shit log --root --format=%s -S1 >actual &&
	test_cmp expect actual
'

cat >expect.stat <<'EOF'
 file | Bin 2 -> 4 bytes
 1 file changed, 0 insertions(+), 0 deletions(-)
EOF
test_expect_success 'diffstat does not run textconv' '
	echo file diff=fail >.shitattributes &&
	shit diff --stat HEAD^ HEAD >actual &&
	test_cmp expect.stat actual &&

	head -n1 <expect.stat >expect.line1 &&
	head -n1 <actual >actual.line1 &&
	test_cmp expect.line1 actual.line1
'
# restore working setup
echo file diff=foo >.shitattributes

symlink=$(shit rev-parse --short $(printf frotz | shit hash-object --stdin))
cat >expect.typechange <<EOF
--- a/file
+++ /dev/null
@@ -1,2 +0,0 @@
-0
-1
diff --shit a/file b/file
new file mode 120000
index 0000000..$symlink
--- /dev/null
+++ b/file
@@ -0,0 +1 @@
+frotz
\ No newline at end of file
EOF

test_expect_success 'textconv does not act on symlinks' '
	rm -f file &&
	test_ln_s_add frotz file &&
	shit commit -m typechange &&
	shit show >diff &&
	find_diff <diff >actual &&
	test_cmp expect.typechange actual
'

test_done
