#!/bin/sh

test_description='format-patch -s should force MIME encoding as needed'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	>F &&
	shit add F &&
	shit commit -m initial &&
	echo new line >F &&

	test_tick &&
	shit commit -m "This adds some lines to F" F

'

test_expect_success 'format normally' '

	shit format-patch --stdout -1 >output &&
	! grep Content-Type output

'

test_expect_success 'format with signoff without funny signer name' '

	shit format-patch -s --stdout -1 >output &&
	! grep Content-Type output

'

test_expect_success 'format with non ASCII signer name' '

	shit_COMMITTER_NAME="はまの ふにおう" \
	shit format-patch -s --stdout -1 >output &&
	grep Content-Type output

'

test_expect_success 'attach and signoff do not duplicate mime headers' '

	shit_COMMITTER_NAME="はまの ふにおう" \
	shit format-patch -s --stdout -1 --attach >output &&
	test $(grep -ci ^MIME-Version: output) = 1

'

test_done

