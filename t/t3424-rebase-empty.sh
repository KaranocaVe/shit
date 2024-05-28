#!/bin/sh

test_description='shit rebase of commits that start or become empty'

. ./test-lib.sh

test_expect_success 'setup test repository' '
	test_write_lines 1 2 3 4 5 6 7 8 9 10 >numbers &&
	test_write_lines A B C D E F G H I J >letters &&
	shit add numbers letters &&
	shit commit -m A &&

	shit branch upstream &&
	shit branch localmods &&

	shit checkout upstream &&
	test_write_lines A B C D E >letters &&
	shit add letters &&
	shit commit -m B &&

	test_write_lines 1 2 3 4 five 6 7 8 9 ten >numbers &&
	shit add numbers &&
	shit commit -m C &&

	shit checkout localmods &&
	test_write_lines 1 2 3 4 five 6 7 8 9 10 >numbers &&
	shit add numbers &&
	shit commit -m C2 &&

	shit commit --allow-empty -m D &&

	test_write_lines A B C D E >letters &&
	shit add letters &&
	shit commit -m "Five letters ought to be enough for anybody"
'

test_expect_failure 'rebase (apply-backend)' '
	test_when_finished "shit rebase --abort" &&
	shit checkout -B testing localmods &&
	# rebase (--apply) should not drop commits that start empty
	shit rebase --apply upstream &&

	test_write_lines D C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --merge --empty=drop' '
	shit checkout -B testing localmods &&
	shit rebase --merge --empty=drop upstream &&

	test_write_lines D C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --merge uses default of --empty=drop' '
	shit checkout -B testing localmods &&
	shit rebase --merge upstream &&

	test_write_lines D C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --merge --empty=keep' '
	shit checkout -B testing localmods &&
	shit rebase --merge --empty=keep upstream &&

	test_write_lines D C2 C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --merge --empty=stop' '
	shit checkout -B testing localmods &&
	test_must_fail shit rebase --merge --empty=stop upstream &&

	shit rebase --skip &&

	test_write_lines D C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --merge --empty=ask' '
	shit checkout -B testing localmods &&
	test_must_fail shit rebase --merge --empty=ask upstream &&

	shit rebase --skip &&

	test_write_lines D C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --interactive --empty=drop' '
	shit checkout -B testing localmods &&
	shit rebase --interactive --empty=drop upstream &&

	test_write_lines D C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --interactive --empty=keep' '
	shit checkout -B testing localmods &&
	shit rebase --interactive --empty=keep upstream &&

	test_write_lines D C2 C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --interactive --empty=stop' '
	shit checkout -B testing localmods &&
	test_must_fail shit rebase --interactive --empty=stop upstream &&

	shit rebase --skip &&

	test_write_lines D C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --interactive uses default of --empty=stop' '
	shit checkout -B testing localmods &&
	test_must_fail shit rebase --interactive upstream &&

	shit rebase --skip &&

	test_write_lines D C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --merge --empty=drop --keep-empty' '
	shit checkout -B testing localmods &&
	shit rebase --merge --empty=drop --keep-empty upstream &&

	test_write_lines D C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --merge --empty=drop --no-keep-empty' '
	shit checkout -B testing localmods &&
	shit rebase --merge --empty=drop --no-keep-empty upstream &&

	test_write_lines C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --merge --empty=keep --keep-empty' '
	shit checkout -B testing localmods &&
	shit rebase --merge --empty=keep --keep-empty upstream &&

	test_write_lines D C2 C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --merge --empty=keep --no-keep-empty' '
	shit checkout -B testing localmods &&
	shit rebase --merge --empty=keep --no-keep-empty upstream &&

	test_write_lines C2 C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --merge does not leave state laying around' '
	shit checkout -B testing localmods~2 &&
	shit rebase --merge upstream &&

	test_path_is_missing .shit/CHERRY_PICK_HEAD &&
	test_path_is_missing .shit/MERGE_MSG
'

test_expect_success 'rebase --exec --empty=drop' '
	shit checkout -B testing localmods &&
	shit rebase --exec "true" --empty=drop upstream &&

	test_write_lines D C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --exec --empty=keep' '
	shit checkout -B testing localmods &&
	shit rebase --exec "true" --empty=keep upstream &&

	test_write_lines D C2 C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --exec uses default of --empty=keep' '
	shit checkout -B testing localmods &&
	shit rebase --exec "true" upstream &&

	test_write_lines D C2 C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase --exec --empty=stop' '
	shit checkout -B testing localmods &&
	test_must_fail shit rebase --exec "true" --empty=stop upstream &&

	shit rebase --skip &&

	test_write_lines D C B A >expect &&
	shit log --format=%s >actual &&
	test_cmp expect actual
'

test_done
