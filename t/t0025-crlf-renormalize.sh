#!/bin/sh

test_description='CRLF renormalization'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	shit config core.autocrlf false &&
	printf "LINEONE\nLINETWO\nLINETHREE\n" >LF.txt &&
	printf "LINEONE\r\nLINETWO\r\nLINETHREE\r\n" >CRLF.txt &&
	printf "LINEONE\r\nLINETWO\nLINETHREE\n" >CRLF_mix_LF.txt &&
	shit add . &&
	shit commit -m initial
'

test_expect_success 'renormalize CRLF in repo' '
	echo "*.txt text=auto" >.shitattributes &&
	shit add --renormalize "*.txt" &&
	cat >expect <<-\EOF &&
	i/lf w/crlf attr/text=auto CRLF.txt
	i/lf w/lf attr/text=auto LF.txt
	i/lf w/mixed attr/text=auto CRLF_mix_LF.txt
	EOF
	shit ls-files --eol >tmp &&
	sed -e "s/	/ /g" -e "s/  */ /g" tmp |
	sort >actual &&
	test_cmp expect actual
'

test_expect_success 'ignore-errors not mistaken for renormalize' '
	shit reset --hard &&
	echo "*.txt text=auto" >.shitattributes &&
	shit ls-files --eol >expect &&
	shit add --ignore-errors "*.txt" &&
	shit ls-files --eol >actual &&
	test_cmp expect actual
'

test_done
