#!/bin/sh
#
# Copyright (c) 2019 Doan Tran Cong Danh
#

test_description='rebase with changing encoding

Initial setup:

1 - 2              main
 \
  3 - 4            first
   \
    5 - 6          second
'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

compare_msg () {
	iconv -f "$2" -t "$3" "$TEST_DIRECTORY/t3434/$1" >expect &&
	shit cat-file commit HEAD >raw &&
	sed "1,/^$/d" raw >actual &&
	test_cmp expect actual
}

test_expect_success setup '
	test_commit one &&
	shit branch first &&
	test_commit two &&
	shit switch first &&
	test_commit three &&
	shit branch second &&
	test_commit four &&
	shit switch second &&
	test_commit five &&
	test_commit six
'

test_expect_success 'rebase --rebase-merges update encoding eucJP to UTF-8' '
	shit switch -c merge-eucJP-UTF-8 first &&
	shit config i18n.commitencoding eucJP &&
	shit merge -F "$TEST_DIRECTORY/t3434/eucJP.txt" second &&
	shit config i18n.commitencoding UTF-8 &&
	shit rebase --rebase-merges main &&
	compare_msg eucJP.txt eucJP UTF-8
'

test_expect_success 'rebase --rebase-merges update encoding eucJP to ISO-2022-JP' '
	shit switch -c merge-eucJP-ISO-2022-JP first &&
	shit config i18n.commitencoding eucJP &&
	shit merge -F "$TEST_DIRECTORY/t3434/eucJP.txt" second &&
	shit config i18n.commitencoding ISO-2022-JP &&
	shit rebase --rebase-merges main &&
	compare_msg eucJP.txt eucJP ISO-2022-JP
'

test_rebase_continue_update_encode () {
	old=$1
	new=$2
	msgfile=$3
	test_expect_success "rebase --continue update from $old to $new" '
		(shit rebase --abort || : abort current shit-rebase failure) &&
		shit switch -c conflict-$old-$new one &&
		echo for-conflict >two.t &&
		shit add two.t &&
		shit config i18n.commitencoding $old &&
		shit commit -F "$TEST_DIRECTORY/t3434/$msgfile" &&
		shit config i18n.commitencoding $new &&
		test_must_fail shit rebase -m main &&
		test -f .shit/rebase-merge/message &&
		shit stripspace -s <.shit/rebase-merge/message >two.t &&
		shit add two.t &&
		shit rebase --continue &&
		compare_msg $msgfile $old $new &&
		: shit-commit assume invalid utf-8 is latin1 &&
		test_cmp expect two.t
	'
}

test_rebase_continue_update_encode ISO-8859-1 UTF-8 ISO8859-1.txt
test_rebase_continue_update_encode eucJP UTF-8 eucJP.txt
test_rebase_continue_update_encode eucJP ISO-2022-JP eucJP.txt

test_done
