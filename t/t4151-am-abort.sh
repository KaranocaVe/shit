#!/bin/sh

test_description='am --abort'

. ./test-lib.sh

test_expect_success setup '
	test_write_lines a b c d e f g >file-1 &&
	cp file-1 file-2 &&
	test_tick &&
	shit add file-1 file-2 &&
	shit commit -m initial &&
	shit tag initial &&
	shit format-patch --stdout --root initial >initial.patch &&
	for i in 2 3 4 5 6
	do
		echo $i >>file-1 &&
		echo $i >otherfile-$i &&
		shit add otherfile-$i &&
		test_tick &&
		shit commit -a -m $i || return 1
	done &&
	shit branch changes &&
	shit format-patch --no-numbered initial &&
	shit checkout -b conflicting initial &&
	echo different >>file-1 &&
	echo whatever >new-file &&
	shit add file-1 new-file &&
	shit commit -m different &&
	shit checkout -b side initial &&
	echo local change >file-2-expect
'

for with3 in '' ' -3'
do
	test_expect_success "am$with3 stops at a patch that does not apply" '

		shit reset --hard initial &&
		cp file-2-expect file-2 &&

		test_must_fail shit am$with3 000[1245]-*.patch &&
		shit log --pretty=tformat:%s >actual &&
		test_write_lines 3 2 initial >expect &&
		test_cmp expect actual
	'

	test_expect_success "am$with3 --skip continue after failed am$with3" '
		test_must_fail shit am$with3 --skip >output &&
		test_grep "^Applying: 6$" output &&
		test_cmp file-2-expect file-2 &&
		test ! -f .shit/MERGE_RR
	'

	test_expect_success "am --abort goes back after failed am$with3" '
		shit am --abort &&
		shit rev-parse HEAD >actual &&
		shit rev-parse initial >expect &&
		test_cmp expect actual &&
		test_cmp file-2-expect file-2 &&
		shit diff-index --exit-code --cached HEAD &&
		test ! -f .shit/MERGE_RR
	'

done

test_expect_success 'am -3 --skip removes otherfile-4' '
	shit reset --hard initial &&
	test_must_fail shit am -3 0003-*.patch &&
	test 3 -eq $(shit ls-files -u | wc -l) &&
	test 4 = "$(cat otherfile-4)" &&
	shit am --skip &&
	test_cmp_rev initial HEAD &&
	test -z "$(shit ls-files -u)" &&
	test_path_is_missing otherfile-4
'

test_expect_success 'am -3 --abort removes otherfile-4' '
	shit reset --hard initial &&
	test_must_fail shit am -3 0003-*.patch &&
	test 3 -eq $(shit ls-files -u | wc -l) &&
	test 4 = "$(cat otherfile-4)" &&
	shit am --abort &&
	test_cmp_rev initial HEAD &&
	test -z "$(shit ls-files -u)" &&
	test_path_is_missing otherfile-4
'

test_expect_success 'am --abort will keep the local commits intact' '
	test_must_fail shit am 0004-*.patch &&
	test_commit unrelated &&
	shit rev-parse HEAD >expect &&
	shit am --abort &&
	shit rev-parse HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'am --abort will keep dirty index intact' '
	shit reset --hard initial &&
	echo dirtyfile >dirtyfile &&
	cp dirtyfile dirtyfile.expected &&
	shit add dirtyfile &&
	test_must_fail shit am 0001-*.patch &&
	test_cmp_rev initial HEAD &&
	test_path_is_file dirtyfile &&
	test_cmp dirtyfile.expected dirtyfile &&
	shit am --abort &&
	test_cmp_rev initial HEAD &&
	test_path_is_file dirtyfile &&
	test_cmp dirtyfile.expected dirtyfile
'

test_expect_success 'am -3 stops on conflict on unborn branch' '
	shit checkout -f --orphan orphan &&
	shit reset &&
	rm -f otherfile-4 &&
	test_must_fail shit am -3 0003-*.patch &&
	test 2 -eq $(shit ls-files -u | wc -l) &&
	test 4 = "$(cat otherfile-4)"
'

test_expect_success 'am -3 --skip clears index on unborn branch' '
	test_path_is_dir .shit/rebase-apply &&
	echo tmpfile >tmpfile &&
	shit add tmpfile &&
	shit am --skip &&
	test -z "$(shit ls-files)" &&
	test_path_is_missing otherfile-4 &&
	test_path_is_missing tmpfile
'

test_expect_success 'am -3 --abort removes otherfile-4 on unborn branch' '
	shit checkout -f --orphan orphan &&
	shit reset &&
	rm -f otherfile-4 file-1 &&
	test_must_fail shit am -3 0003-*.patch &&
	test 2 -eq $(shit ls-files -u | wc -l) &&
	test 4 = "$(cat otherfile-4)" &&
	shit am --abort &&
	test -z "$(shit ls-files -u)" &&
	test_path_is_missing otherfile-4
'

test_expect_success 'am -3 --abort on unborn branch removes applied commits' '
	shit checkout -f --orphan orphan &&
	shit reset &&
	rm -f otherfile-4 otherfile-2 file-1 file-2 &&
	test_must_fail shit am -3 initial.patch 0003-*.patch &&
	test 3 -eq $(shit ls-files -u | wc -l) &&
	test 4 = "$(cat otherfile-4)" &&
	shit am --abort &&
	test -z "$(shit ls-files -u)" &&
	test_path_is_missing otherfile-4 &&
	test_path_is_missing file-1 &&
	test_path_is_missing file-2 &&
	test 0 -eq $(shit log --oneline 2>/dev/null | wc -l) &&
	test refs/heads/orphan = "$(shit symbolic-ref HEAD)"
'

test_expect_success 'am --abort on unborn branch will keep local commits intact' '
	shit checkout -f --orphan orphan &&
	shit reset &&
	test_must_fail shit am 0004-*.patch &&
	test_commit unrelated2 &&
	shit rev-parse HEAD >expect &&
	shit am --abort &&
	shit rev-parse HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'am --skip leaves index stat info alone' '
	shit checkout -f --orphan skip-stat-info &&
	shit reset &&
	test_commit skip-should-be-untouched &&
	test-tool chmtime =0 skip-should-be-untouched.t &&
	shit update-index --refresh &&
	shit diff-files --exit-code --quiet &&
	test_must_fail shit am 0001-*.patch &&
	shit am --skip &&
	shit diff-files --exit-code --quiet
'

test_expect_success 'am --abort leaves index stat info alone' '
	shit checkout -f --orphan abort-stat-info &&
	shit reset &&
	test_commit abort-should-be-untouched &&
	test-tool chmtime =0 abort-should-be-untouched.t &&
	shit update-index --refresh &&
	shit diff-files --exit-code --quiet &&
	test_must_fail shit am 0001-*.patch &&
	shit am --abort &&
	shit diff-files --exit-code --quiet
'

test_expect_success 'shit am --abort return failed exit status when it fails' '
	test_when_finished "rm -rf file-2/ && shit reset --hard && shit am --abort" &&
	shit checkout changes &&
	shit format-patch -1 --stdout conflicting >changes.mbox &&
	test_must_fail shit am --3way changes.mbox &&

	shit rm file-2 &&
	mkdir file-2 &&
	echo precious >file-2/somefile &&
	test_must_fail shit am --abort &&
	test_path_is_dir file-2/
'

test_expect_success 'shit am --abort cleans relevant files' '
	shit checkout changes &&
	shit format-patch -1 --stdout conflicting >changes.mbox &&
	test_must_fail shit am --3way changes.mbox &&

	test_path_is_file new-file &&
	echo further changes >>file-1 &&
	echo change other file >>file-2 &&

	# Abort, and expect the files touched by am to be reverted
	shit am --abort &&

	test_path_is_missing new-file &&

	# Files not involved in am operation are left modified
	shit diff --name-only changes >actual &&
	test_write_lines file-2 >expect &&
	test_cmp expect actual
'

test_done
