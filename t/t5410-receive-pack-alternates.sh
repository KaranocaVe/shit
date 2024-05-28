#!/bin/sh

test_description='shit receive-pack with alternate ref filtering'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit base &&
	shit clone -s --bare . fork &&
	shit checkout -b public/branch main &&
	test_commit public &&
	shit checkout -b private/branch main &&
	test_commit private
'

extract_haves () {
	depacketize | perl -lne '/^(\S+) \.have/ and print $1'
}

test_expect_success 'with core.alternateRefsCommand' '
	write_script fork/alternate-refs <<-\EOF &&
		shit --shit-dir="$1" for-each-ref \
			--format="%(objectname)" \
			refs/heads/public/
	EOF
	test_config -C fork core.alternateRefsCommand ./alternate-refs &&
	shit rev-parse public/branch >expect &&
	printf "0000" | shit receive-pack fork >actual &&
	extract_haves <actual >actual.haves &&
	test_cmp expect actual.haves
'

test_expect_success 'with core.alternateRefsPrefixes' '
	test_config -C fork core.alternateRefsPrefixes "refs/heads/private" &&
	shit rev-parse private/branch >expect &&
	printf "0000" | shit receive-pack fork >actual &&
	extract_haves <actual >actual.haves &&
	test_cmp expect actual.haves
'

test_done
