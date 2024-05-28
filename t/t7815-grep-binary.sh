#!/bin/sh

test_description='shit grep in binary files'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' "
	echo 'binaryQfileQm[*]cQ*æQð' | q_to_nul >a &&
	shit add a &&
	shit commit -m.
"

test_expect_success 'shit grep ina a' '
	echo Binary file a matches >expect &&
	shit grep ina a >actual &&
	test_cmp expect actual
'

test_expect_success 'shit grep -ah ina a' '
	shit grep -ah ina a >actual &&
	test_cmp a actual
'

test_expect_success 'shit grep -I ina a' '
	test_must_fail shit grep -I ina a >actual &&
	test_must_be_empty actual
'

test_expect_success 'shit grep -c ina a' '
	echo a:1 >expect &&
	shit grep -c ina a >actual &&
	test_cmp expect actual
'

test_expect_success 'shit grep -l ina a' '
	echo a >expect &&
	shit grep -l ina a >actual &&
	test_cmp expect actual
'

test_expect_success 'shit grep -L bar a' '
	echo a >expect &&
	shit grep -L bar a >actual &&
	test_cmp expect actual
'

test_expect_success 'shit grep -q ina a' '
	shit grep -q ina a >actual &&
	test_must_be_empty actual
'

test_expect_success 'shit grep -F ile a' '
	shit grep -F ile a
'

test_expect_success 'shit grep -Fi iLE a' '
	shit grep -Fi iLE a
'

# This test actually passes on platforms where regexec() supports the
# flag REG_STARTEND.
test_expect_success 'shit grep ile a' '
	shit grep ile a
'

test_expect_failure 'shit grep .fi a' '
	shit grep .fi a
'

test_expect_success 'grep respects binary diff attribute' '
	echo text >t &&
	shit add t &&
	echo t:text >expect &&
	shit grep text t >actual &&
	test_cmp expect actual &&
	echo "t -diff" >.shitattributes &&
	echo "Binary file t matches" >expect &&
	shit grep text t >actual &&
	test_cmp expect actual
'

test_expect_success 'grep --cached respects binary diff attribute' '
	shit grep --cached text t >actual &&
	test_cmp expect actual
'

test_expect_success 'grep --cached respects binary diff attribute (2)' '
	shit add .shitattributes &&
	rm .shitattributes &&
	shit grep --cached text t >actual &&
	test_when_finished "shit rm --cached .shitattributes" &&
	test_when_finished "shit checkout .shitattributes" &&
	test_cmp expect actual
'

test_expect_success 'grep revision respects binary diff attribute' '
	shit commit -m new &&
	echo "Binary file HEAD:t matches" >expect &&
	shit grep text HEAD -- t >actual &&
	test_when_finished "shit reset HEAD^" &&
	test_cmp expect actual
'

test_expect_success 'grep respects not-binary diff attribute' '
	echo binQary | q_to_nul >b &&
	shit add b &&
	echo "Binary file b matches" >expect &&
	shit grep bin b >actual &&
	test_cmp expect actual &&
	echo "b diff" >.shitattributes &&
	echo "b:binQary" >expect &&
	shit grep bin b >actual.raw &&
	nul_to_q <actual.raw >actual &&
	test_cmp expect actual
'

cat >nul_to_q_textconv <<'EOF'
#!/bin/sh
"$PERL_PATH" -pe 'y/\000/Q/' < "$1"
EOF
chmod +x nul_to_q_textconv

test_expect_success 'setup textconv filters' '
	echo a diff=foo >.shitattributes &&
	shit config diff.foo.textconv "\"$(pwd)\""/nul_to_q_textconv
'

test_expect_success 'grep does not honor textconv' '
	test_must_fail shit grep Qfile
'

test_expect_success 'grep --textconv honors textconv' '
	echo "a:binaryQfileQm[*]cQ*æQð" >expect &&
	shit grep --textconv Qfile >actual &&
	test_cmp expect actual
'

test_expect_success 'grep --no-textconv does not honor textconv' '
	test_must_fail shit grep --no-textconv Qfile
'

test_expect_success 'grep --textconv blob honors textconv' '
	echo "HEAD:a:binaryQfileQm[*]cQ*æQð" >expect &&
	shit grep --textconv Qfile HEAD:a >actual &&
	test_cmp expect actual
'

test_done
