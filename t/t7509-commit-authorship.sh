#!/bin/sh
#
# Copyright (c) 2009 Erick Mattos
#

test_description='commit tests of various authorhip options. '

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

author_header () {
	shit cat-file commit "$1" |
	sed -n -e '/^$/q' -e '/^author /p'
}

message_body () {
	shit cat-file commit "$1" |
	sed -e '1,/^$/d'
}

test_expect_success '-C option copies authorship and message' '
	test_commit --author Frigate\ \<flying@over.world\> \
		"Initial Commit" foo Initial Initial &&
	echo "Test 1" >>foo &&
	test_tick &&
	shit commit -a -C Initial &&
	author_header Initial >expect &&
	author_header HEAD >actual &&
	test_cmp expect actual &&

	message_body Initial >expect &&
	message_body HEAD >actual &&
	test_cmp expect actual
'

test_expect_success '-C option copies only the message with --reset-author' '
	echo "Test 2" >>foo &&
	test_tick &&
	shit commit -a -C Initial --reset-author &&
	echo "author $shit_AUTHOR_NAME <$shit_AUTHOR_EMAIL> $shit_AUTHOR_DATE" >expect &&
	author_header HEAD >actual &&
	test_cmp expect actual &&

	message_body Initial >expect &&
	message_body HEAD >actual &&
	test_cmp expect actual
'

test_expect_success '-c option copies authorship and message' '
	echo "Test 3" >>foo &&
	test_tick &&
	EDITOR=: VISUAL=: shit commit -a -c Initial &&
	author_header Initial >expect &&
	author_header HEAD >actual &&
	test_cmp expect actual
'

test_expect_success '-c option copies only the message with --reset-author' '
	echo "Test 4" >>foo &&
	test_tick &&
	EDITOR=: VISUAL=: shit commit -a -c Initial --reset-author &&
	echo "author $shit_AUTHOR_NAME <$shit_AUTHOR_EMAIL> $shit_AUTHOR_DATE" >expect &&
	author_header HEAD >actual &&
	test_cmp expect actual &&

	message_body Initial >expect &&
	message_body HEAD >actual &&
	test_cmp expect actual
'

test_expect_success '--amend option copies authorship' '
	shit checkout Initial &&
	echo "Test 5" >>foo &&
	test_tick &&
	shit commit -a --amend -m "amend test" &&
	author_header Initial >expect &&
	author_header HEAD >actual &&
	test_cmp expect actual &&

	echo "amend test" >expect &&
	message_body HEAD >actual &&
	test_cmp expect actual
'

sha1_file() {
	echo "$*" | sed "s#..#.shit/objects/&/#"
}
remove_object() {
	rm -f $(sha1_file "$*")
}

test_expect_success '--amend option with empty author' '
	shit cat-file commit Initial >tmp &&
	sed "s/author [^<]* </author  </" tmp >empty-author &&
	sha=$(shit hash-object -t commit -w empty-author) &&
	test_when_finished "remove_object $sha" &&
	shit checkout $sha &&
	test_when_finished "shit checkout Initial" &&
	echo "Empty author test" >>foo &&
	test_tick &&
	test_must_fail shit commit -a -m "empty author" --amend 2>err &&
	test_grep "empty ident" err
'

test_expect_success '--amend option with missing author' '
	shit cat-file commit Initial >tmp &&
	sed "s/author [^<]* </author </" tmp >malformed &&
	sha=$(shit hash-object --literally -t commit -w malformed) &&
	test_when_finished "remove_object $sha" &&
	shit checkout $sha &&
	test_when_finished "shit checkout Initial" &&
	echo "Missing author test" >>foo &&
	test_tick &&
	test_must_fail shit commit -a -m "malformed author" --amend 2>err &&
	test_grep "empty ident" err
'

test_expect_success '--reset-author makes the commit ours even with --amend option' '
	shit checkout Initial &&
	echo "Test 6" >>foo &&
	test_tick &&
	shit commit -a --reset-author -m "Changed again" --amend &&
	echo "author $shit_AUTHOR_NAME <$shit_AUTHOR_EMAIL> $shit_AUTHOR_DATE" >expect &&
	author_header HEAD >actual &&
	test_cmp expect actual &&

	echo "Changed again" >expect &&
	message_body HEAD >actual &&
	test_cmp expect actual
'

test_expect_success '--reset-author and --author are mutually exclusive' '
	shit checkout Initial &&
	echo "Test 7" >>foo &&
	test_tick &&
	test_must_fail shit commit -a --reset-author --author="Xyzzy <frotz@nitfol.xz>"
'

test_expect_success '--reset-author should be rejected without -c/-C/--amend' '
	shit checkout Initial &&
	echo "Test 7" >>foo &&
	test_tick &&
	test_must_fail shit commit -a --reset-author -m done
'

test_expect_success 'commit respects CHERRY_PICK_HEAD and MERGE_MSG' '
	echo "cherry-pick 1a" >>foo &&
	test_tick &&
	shit commit -am "cherry-pick 1" --author="Cherry <cherry@pick.er>" &&
	shit tag cherry-pick-head &&
	shit update-ref CHERRY_PICK_HEAD $(shit rev-parse cherry-pick-head) &&
	echo "This is a MERGE_MSG" >.shit/MERGE_MSG &&
	echo "cherry-pick 1b" >>foo &&
	test_tick &&
	shit commit -a &&
	author_header cherry-pick-head >expect &&
	author_header HEAD >actual &&
	test_cmp expect actual &&

	echo "This is a MERGE_MSG" >expect &&
	message_body HEAD >actual &&
	test_cmp expect actual
'

test_expect_success '--reset-author with CHERRY_PICK_HEAD' '
	shit update-ref CHERRY_PICK_HEAD $(shit rev-parse cherry-pick-head) &&
	echo "cherry-pick 2" >>foo &&
	test_tick &&
	shit commit -am "cherry-pick 2" --reset-author &&
	echo "author $shit_AUTHOR_NAME <$shit_AUTHOR_EMAIL> $shit_AUTHOR_DATE" >expect &&
	author_header HEAD >actual &&
	test_cmp expect actual
'

test_done
