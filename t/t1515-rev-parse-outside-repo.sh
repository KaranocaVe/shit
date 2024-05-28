#!/bin/sh

test_description='check that certain rev-parse options work outside repo'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'set up non-repo directory' '
	shit_CEILING_DIRECTORIES=$(pwd) &&
	export shit_CEILING_DIRECTORIES &&
	mkdir non-repo &&
	cd non-repo &&
	# confirm that shit does not find a repo
	test_must_fail shit rev-parse --shit-dir
'

# Rather than directly test the output of sq-quote directly,
# make sure the shell can read back a tricky case, since
# that's what we really care about anyway.
tricky="really tricky with \\ and \" and '"
dump_args () {
	for i in "$@"; do
		echo "arg: $i"
	done
}
test_expect_success 'rev-parse --sq-quote' '
	dump_args "$tricky" easy >expect &&
	eval "dump_args $(shit rev-parse --sq-quote "$tricky" easy)" >actual &&
	test_cmp expect actual
'

test_expect_success 'rev-parse --local-env-vars' '
	shit rev-parse --local-env-vars >actual &&
	# we do not want to depend on the complete list here,
	# so just look for something plausible
	grep ^shit_DIR actual
'

test_expect_success 'rev-parse --resolve-shit-dir' '
	shit init --separate-shit-dir repo dir &&
	test_must_fail shit rev-parse --resolve-shit-dir . &&
	echo "$(pwd)/repo" >expect &&
	shit rev-parse --resolve-shit-dir dir/.shit >actual &&
	test_cmp expect actual
'

test_done
