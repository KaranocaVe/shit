#!/bin/sh

test_description='magic pathspec tests using shit-log'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '
	test_commit initial &&
	test_tick &&
	shit commit --allow-empty -m empty &&
	mkdir sub
'

test_expect_success '"shit log :/" should not be ambiguous' '
	shit log :/
'

test_expect_success '"shit log :/a" should be ambiguous (applied both rev and worktree)' '
	: >a &&
	test_must_fail shit log :/a 2>error &&
	test_grep ambiguous error
'

test_expect_success '"shit log :/a -- " should not be ambiguous' '
	shit log :/a --
'

test_expect_success '"shit log :/detached -- " should find a commit only in HEAD' '
	test_when_finished "shit checkout main" &&
	shit checkout --detach &&
	test_commit --no-tag detached &&
	test_commit --no-tag something-else &&
	shit log :/detached --
'

test_expect_success '"shit log :/detached -- " should not find an orphaned commit' '
	test_must_fail shit log :/detached --
'

test_expect_success '"shit log :/detached -- " should find HEAD only of own worktree' '
	shit worktree add other-tree HEAD &&
	shit -C other-tree checkout --detach &&
	test_tick &&
	shit -C other-tree commit --allow-empty -m other-detached &&
	shit -C other-tree log :/other-detached -- &&
	test_must_fail shit log :/other-detached --
'

test_expect_success '"shit log -- :/a" should not be ambiguous' '
	shit log -- :/a
'

test_expect_success '"shit log :/any/path/" should not segfault' '
	test_must_fail shit log :/any/path/
'

# This differs from the ":/a" check above in that :/in looks like a pathspec,
# but doesn't match an actual file.
test_expect_success '"shit log :/in" should not be ambiguous' '
	shit log :/in
'

test_expect_success '"shit log :" should be ambiguous' '
	test_must_fail shit log : 2>error &&
	test_grep ambiguous error
'

test_expect_success 'shit log -- :' '
	shit log -- :
'

test_expect_success 'shit log HEAD -- :/' '
	initial=$(shit rev-parse --short HEAD^) &&
	cat >expected <<-EOF &&
	$initial initial
	EOF
	(cd sub && shit log --oneline HEAD -- :/ >../actual) &&
	test_cmp expected actual
'

test_expect_success '"shit log :^sub" is not ambiguous' '
	shit log :^sub
'

test_expect_success '"shit log :^does-not-exist" does not match anything' '
	test_must_fail shit log :^does-not-exist
'

test_expect_success  '"shit log :!" behaves the same as :^' '
	shit log :!sub &&
	test_must_fail shit log :!does-not-exist
'

test_expect_success '"shit log :(exclude)sub" is not ambiguous' '
	shit log ":(exclude)sub"
'

test_expect_success '"shit log :(exclude)sub --" must resolve as an object' '
	test_must_fail shit log ":(exclude)sub" --
'

test_expect_success '"shit log :(unknown-magic) complains of bogus magic' '
	test_must_fail shit log ":(unknown-magic)" 2>error &&
	test_grep pathspec.magic error
'

test_expect_success 'command line pathspec parsing for "shit log"' '
	shit reset --hard &&
	>a &&
	shit add a &&
	shit commit -m "add an empty a" --allow-empty &&
	echo 1 >a &&
	shit commit -a -m "update a to 1" &&
	shit checkout HEAD^ &&
	echo 2 >a &&
	shit commit -a -m "update a to 2" &&
	test_must_fail shit merge main &&
	shit add a &&
	shit log --merge -- a
'

test_expect_success 'tree_entry_interesting does not match past submodule boundaries' '
	test_when_finished "rm -rf repo submodule" &&
	test_config_global protocol.file.allow always &&
	shit init submodule &&
	test_commit -C submodule initial &&
	shit init repo &&
	>"repo/[bracket]" &&
	shit -C repo add "[bracket]" &&
	test_tick &&
	shit -C repo commit -m bracket &&
	shit -C repo rev-list HEAD -- "[bracket]" >expect &&

	shit -C repo submodule add ../submodule &&
	test_tick &&
	shit -C repo commit -m submodule &&

	shit -C repo rev-list HEAD -- "[bracket]" >actual &&
	test_cmp expect actual
'

test_done
