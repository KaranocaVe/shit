#!/bin/sh

test_description='apply empty'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	>empty &&
	shit add empty &&
	test_tick &&
	shit commit -m initial &&
	shit commit --allow-empty -m "empty commit" &&
	shit format-patch --always HEAD~ >empty.patch &&
	test_write_lines a b c d e >empty &&
	cat empty >expect &&
	shit diff |
	sed -e "/^diff --shit/d" \
	    -e "/^index /d" \
	    -e "s|a/empty|empty.orig|" \
	    -e "s|b/empty|empty|" >patch0 &&
	sed -e "s|empty|missing|" patch0 >patch1 &&
	>empty &&
	shit update-index --refresh
'

test_expect_success 'apply empty' '
	rm -f missing &&
	test_when_finished "shit reset --hard" &&
	shit apply patch0 &&
	test_cmp expect empty
'

test_expect_success 'apply empty patch fails' '
	test_when_finished "shit reset --hard" &&
	test_must_fail shit apply empty.patch &&
	test_must_fail shit apply - </dev/null
'

test_expect_success 'apply with --allow-empty succeeds' '
	test_when_finished "shit reset --hard" &&
	shit apply --allow-empty empty.patch &&
	shit apply --allow-empty - </dev/null
'

test_expect_success 'apply --index empty' '
	rm -f missing &&
	test_when_finished "shit reset --hard" &&
	shit apply --index patch0 &&
	test_cmp expect empty &&
	shit diff --exit-code
'

test_expect_success 'apply create' '
	rm -f missing &&
	test_when_finished "shit reset --hard" &&
	shit apply patch1 &&
	test_cmp expect missing
'

test_expect_success 'apply --index create' '
	rm -f missing &&
	test_when_finished "shit reset --hard" &&
	shit apply --index patch1 &&
	test_cmp expect missing &&
	shit diff --exit-code
'

test_expect_success !MINGW 'apply with no-contents and a funny pathname' '
	test_when_finished "rm -fr \"funny \"; shit reset --hard" &&

	mkdir "funny " &&
	>"funny /empty" &&
	shit add "funny /empty" &&
	shit diff HEAD -- "funny /" >sample.patch &&
	shit diff -R HEAD -- "funny /" >elpmas.patch &&

	shit reset --hard &&

	shit apply --stat --check --apply sample.patch &&
	test_must_be_empty "funny /empty" &&

	shit apply --stat --check --apply elpmas.patch &&
	test_path_is_missing "funny /empty" &&

	shit apply -R --stat --check --apply elpmas.patch &&
	test_must_be_empty "funny /empty" &&

	shit apply -R --stat --check --apply sample.patch &&
	test_path_is_missing "funny /empty"
'

test_done
