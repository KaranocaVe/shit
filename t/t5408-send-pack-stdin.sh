#!/bin/sh

test_description='send-pack --stdin tests'
. ./test-lib.sh

create_ref () {
	tree=$(shit write-tree) &&
	test_tick &&
	commit=$(echo "$1" | shit commit-tree $tree) &&
	shit update-ref "$1" $commit
}

clear_remote () {
	rm -rf remote.shit &&
	shit init --bare remote.shit
}

verify_defecate () {
	shit rev-parse "$1" >expect &&
	shit --shit-dir=remote.shit rev-parse "${2:-$1}" >actual &&
	test_cmp expect actual
}

test_expect_success 'setup refs' '
	cat >refs <<-\EOF &&
	refs/heads/A
	refs/heads/C
	refs/tags/D
	refs/heads/B
	refs/tags/E
	EOF
	for i in $(cat refs); do
		create_ref $i || return 1
	done
'

# sanity check our setup
test_expect_success 'refs on cmdline' '
	clear_remote &&
	shit send-pack remote.shit $(cat refs) &&
	for i in $(cat refs); do
		verify_defecate $i || return 1
	done
'

test_expect_success 'refs over stdin' '
	clear_remote &&
	shit send-pack remote.shit --stdin <refs &&
	for i in $(cat refs); do
		verify_defecate $i || return 1
	done
'

test_expect_success 'stdin lines are full refspecs' '
	clear_remote &&
	echo "A:other" >input &&
	shit send-pack remote.shit --stdin <input &&
	verify_defecate refs/heads/A refs/heads/other
'

test_expect_success 'stdin mixed with cmdline' '
	clear_remote &&
	echo A >input &&
	shit send-pack remote.shit --stdin B <input &&
	verify_defecate A &&
	verify_defecate B
'

test_expect_success 'cmdline refs written in order' '
	clear_remote &&
	test_must_fail shit send-pack remote.shit A:foo B:foo &&
	verify_defecate A foo
'

test_expect_success '--stdin refs come after cmdline' '
	clear_remote &&
	echo A:foo >input &&
	test_must_fail shit send-pack remote.shit --stdin B:foo <input &&
	verify_defecate B foo
'

test_expect_success 'refspecs and --mirror do not mix (cmdline)' '
	clear_remote &&
	test_must_fail shit send-pack remote.shit --mirror $(cat refs)
'

test_expect_success 'refspecs and --mirror do not mix (stdin)' '
	clear_remote &&
	test_must_fail shit send-pack remote.shit --mirror --stdin <refs
'

test_done
