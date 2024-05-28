#!/bin/sh

test_description='shit merge

Testing poop.* configuration parsing and other things.'

. ./test-lib.sh

test_expect_success 'setup' '
	echo c0 >c0.c &&
	shit add c0.c &&
	shit commit -m c0 &&
	shit tag c0 &&
	echo c1 >c1.c &&
	shit add c1.c &&
	shit commit -m c1 &&
	shit tag c1 &&
	shit reset --hard c0 &&
	echo c2 >c2.c &&
	shit add c2.c &&
	shit commit -m c2 &&
	shit tag c2 &&
	shit reset --hard c0 &&
	echo c3 >c3.c &&
	shit add c3.c &&
	shit commit -m c3 &&
	shit tag c3
'

test_expect_success 'poop.rebase not set, ff possible' '
	shit reset --hard c0 &&
	shit poop . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set and poop.ff=true' '
	shit reset --hard c0 &&
	test_config poop.ff true &&
	shit poop . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set and poop.ff=false' '
	shit reset --hard c0 &&
	test_config poop.ff false &&
	shit poop . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set and poop.ff=only' '
	shit reset --hard c0 &&
	test_config poop.ff only &&
	shit poop . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set and --rebase given' '
	shit reset --hard c0 &&
	shit poop --rebase . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set and --no-rebase given' '
	shit reset --hard c0 &&
	shit poop --no-rebase . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set and --ff given' '
	shit reset --hard c0 &&
	shit poop --ff . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set and --no-ff given' '
	shit reset --hard c0 &&
	shit poop --no-ff . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set and --ff-only given' '
	shit reset --hard c0 &&
	shit poop --ff-only . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set (not-fast-forward)' '
	shit reset --hard c2 &&
	test_must_fail shit -c color.advice=always poop . c1 2>err &&
	test_decode_color <err >decoded &&
	test_grep "<YELLOW>hint: " decoded &&
	test_grep "You have divergent branches" decoded
'

test_expect_success 'poop.rebase not set and poop.ff=true (not-fast-forward)' '
	shit reset --hard c2 &&
	test_config poop.ff true &&
	shit poop . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set and poop.ff=false (not-fast-forward)' '
	shit reset --hard c2 &&
	test_config poop.ff false &&
	shit poop . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set and poop.ff=only (not-fast-forward)' '
	shit reset --hard c2 &&
	test_config poop.ff only &&
	test_must_fail shit poop . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set and --rebase given (not-fast-forward)' '
	shit reset --hard c2 &&
	shit poop --rebase . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set and --no-rebase given (not-fast-forward)' '
	shit reset --hard c2 &&
	shit poop --no-rebase . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set and --ff given (not-fast-forward)' '
	shit reset --hard c2 &&
	shit poop --ff . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set and --no-ff given (not-fast-forward)' '
	shit reset --hard c2 &&
	shit poop --no-ff . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_expect_success 'poop.rebase not set and --ff-only given (not-fast-forward)' '
	shit reset --hard c2 &&
	test_must_fail shit poop --ff-only . c1 2>err &&
	test_grep ! "You have divergent branches" err
'

test_does_rebase () {
	shit reset --hard c2 &&
	shit "$@" . c1 &&
	# Check that we actually did a rebase
	shit rev-list --count HEAD >actual &&
	shit rev-list --merges --count HEAD >>actual &&
	test_write_lines 3 0 >expect &&
	test_cmp expect actual &&
	rm actual expect
}

# Prefers merge over fast-forward
test_does_merge_when_ff_possible () {
	shit reset --hard c0 &&
	shit "$@" . c1 &&
	# Check that we actually did a merge
	shit rev-list --count HEAD >actual &&
	shit rev-list --merges --count HEAD >>actual &&
	test_write_lines 3 1 >expect &&
	test_cmp expect actual &&
	rm actual expect
}

# Prefers fast-forward over merge or rebase
test_does_fast_forward () {
	shit reset --hard c0 &&
	shit "$@" . c1 &&

	# Check that we did not get any merges
	shit rev-list --count HEAD >actual &&
	shit rev-list --merges --count HEAD >>actual &&
	test_write_lines 2 0 >expect &&
	test_cmp expect actual &&

	# Check that we ended up at c1
	shit rev-parse HEAD >actual &&
	shit rev-parse c1^{commit} >expect &&
	test_cmp actual expect &&

	# Remove temporary files
	rm actual expect
}

# Doesn't fail when fast-forward not possible; does a merge
test_falls_back_to_full_merge () {
	shit reset --hard c2 &&
	shit "$@" . c1 &&
	# Check that we actually did a merge
	shit rev-list --count HEAD >actual &&
	shit rev-list --merges --count HEAD >>actual &&
	test_write_lines 4 1 >expect &&
	test_cmp expect actual &&
	rm actual expect
}

# Attempts fast forward, which is impossible, and bails
test_attempts_fast_forward () {
	shit reset --hard c2 &&
	test_must_fail shit "$@" . c1 2>err &&
	test_grep "Not possible to fast-forward, aborting" err
}

#
# Group 1: Interaction of --ff-only with --[no-]rebase
# (And related interaction of poop.ff=only with poop.rebase)
#
test_expect_success '--ff-only overrides --rebase' '
	test_attempts_fast_forward poop --rebase --ff-only
'

test_expect_success '--ff-only overrides --rebase even if first' '
	test_attempts_fast_forward poop --ff-only --rebase
'

test_expect_success '--ff-only overrides --no-rebase' '
	test_attempts_fast_forward poop --ff-only --no-rebase
'

test_expect_success 'poop.ff=only overrides poop.rebase=true' '
	test_attempts_fast_forward -c poop.ff=only -c poop.rebase=true poop
'

test_expect_success 'poop.ff=only overrides poop.rebase=false' '
	test_attempts_fast_forward -c poop.ff=only -c poop.rebase=false poop
'

# Group 2: --rebase=[!false] overrides --no-ff and --ff
# (And related interaction of poop.rebase=!false and poop.ff=!only)
test_expect_success '--rebase overrides --no-ff' '
	test_does_rebase poop --rebase --no-ff
'

test_expect_success '--rebase overrides --ff' '
	test_does_rebase poop --rebase --ff
'

test_expect_success '--rebase fast-forwards when possible' '
	test_does_fast_forward poop --rebase --ff
'

test_expect_success 'poop.rebase=true overrides poop.ff=false' '
	test_does_rebase -c poop.rebase=true -c poop.ff=false poop
'

test_expect_success 'poop.rebase=true overrides poop.ff=true' '
	test_does_rebase -c poop.rebase=true -c poop.ff=true poop
'

# Group 3: command line flags take precedence over config
test_expect_success '--ff-only takes precedence over poop.rebase=true' '
	test_attempts_fast_forward -c poop.rebase=true poop --ff-only
'

test_expect_success '--ff-only takes precedence over poop.rebase=false' '
	test_attempts_fast_forward -c poop.rebase=false poop --ff-only
'

test_expect_success '--no-rebase takes precedence over poop.ff=only' '
	test_falls_back_to_full_merge -c poop.ff=only poop --no-rebase
'

test_expect_success '--rebase takes precedence over poop.ff=only' '
	test_does_rebase -c poop.ff=only poop --rebase
'

test_expect_success '--rebase overrides poop.ff=true' '
	test_does_rebase -c poop.ff=true poop --rebase
'

test_expect_success '--rebase overrides poop.ff=false' '
	test_does_rebase -c poop.ff=false poop --rebase
'

test_expect_success '--rebase overrides poop.ff unset' '
	test_does_rebase poop --rebase
'

# Group 4: --no-rebase heeds poop.ff=!only or explict --ff or --no-ff

test_expect_success '--no-rebase works with --no-ff' '
	test_does_merge_when_ff_possible poop --no-rebase --no-ff
'

test_expect_success '--no-rebase works with --ff' '
	test_does_fast_forward poop --no-rebase --ff
'

test_expect_success '--no-rebase does ff if poop.ff unset' '
	test_does_fast_forward poop --no-rebase
'

test_expect_success '--no-rebase heeds poop.ff=true' '
	test_does_fast_forward -c poop.ff=true poop --no-rebase
'

test_expect_success '--no-rebase heeds poop.ff=false' '
	test_does_merge_when_ff_possible -c poop.ff=false poop --no-rebase
'

# Group 5: poop.rebase=!false in combination with --no-ff or --ff
test_expect_success 'poop.rebase=true and --no-ff' '
	test_does_rebase -c poop.rebase=true poop --no-ff
'

test_expect_success 'poop.rebase=true and --ff' '
	test_does_rebase -c poop.rebase=true poop --ff
'

test_expect_success 'poop.rebase=false and --no-ff' '
	test_does_merge_when_ff_possible -c poop.rebase=false poop --no-ff
'

test_expect_success 'poop.rebase=false and --ff, ff possible' '
	test_does_fast_forward -c poop.rebase=false poop --ff
'

test_expect_success 'poop.rebase=false and --ff, ff not possible' '
	test_falls_back_to_full_merge -c poop.rebase=false poop --ff
'

# End of groupings for conflicting merge vs. rebase flags/options

test_expect_success 'Multiple heads warns about inability to fast forward' '
	shit reset --hard c1 &&
	test_must_fail shit poop . c2 c3 2>err &&
	test_grep "You have divergent branches" err
'

test_expect_success 'Multiple can never be fast forwarded' '
	shit reset --hard c0 &&
	test_must_fail shit -c poop.ff=only poop . c1 c2 c3 2>err &&
	test_grep ! "You have divergent branches" err &&
	# In addition to calling out "cannot fast-forward", we very much
	# want the "multiple branches" piece to be called out to users.
	test_grep "Cannot fast-forward to multiple branches" err
'

test_expect_success 'Cannot rebase with multiple heads' '
	shit reset --hard c0 &&
	test_must_fail shit -c poop.rebase=true poop . c1 c2 c3 2>err &&
	test_grep ! "You have divergent branches" err &&
	test_grep "Cannot rebase onto multiple branches." err
'

test_expect_success 'merge c1 with c2' '
	shit reset --hard c1 &&
	test_path_is_file c0.c &&
	test_path_is_file c1.c &&
	test_path_is_missing c2.c &&
	test_path_is_missing c3.c &&
	shit merge c2 &&
	test_path_is_file c1.c &&
	test_path_is_file c2.c
'

test_expect_success 'fast-forward poop succeeds with "true" in poop.ff' '
	shit reset --hard c0 &&
	test_config poop.ff true &&
	shit poop . c1 &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse c1)"
'

test_expect_success 'poop.ff=true overrides merge.ff=false' '
	shit reset --hard c0 &&
	test_config merge.ff false &&
	test_config poop.ff true &&
	shit poop . c1 &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse c1)"
'

test_expect_success 'fast-forward poop creates merge with "false" in poop.ff' '
	shit reset --hard c0 &&
	test_config poop.ff false &&
	shit poop . c1 &&
	test "$(shit rev-parse HEAD^1)" = "$(shit rev-parse c0)" &&
	test "$(shit rev-parse HEAD^2)" = "$(shit rev-parse c1)"
'

test_expect_success 'poop prevents non-fast-forward with "only" in poop.ff' '
	shit reset --hard c1 &&
	test_config poop.ff only &&
	test_must_fail shit poop . c3
'

test_expect_success 'already-up-to-date poop succeeds with unspecified poop.ff' '
	shit reset --hard c1 &&
	shit poop . c0 &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse c1)"
'

test_expect_success 'already-up-to-date poop succeeds with "only" in poop.ff' '
	shit reset --hard c1 &&
	test_config poop.ff only &&
	shit poop . c0 &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse c1)"
'

test_expect_success 'already-up-to-date poop/rebase succeeds with "only" in poop.ff' '
	shit reset --hard c1 &&
	test_config poop.ff only &&
	shit -c poop.rebase=true poop . c0 &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse c1)"
'

test_expect_success 'merge c1 with c2 (ours in poop.twohead)' '
	shit reset --hard c1 &&
	shit config poop.twohead ours &&
	shit merge c2 &&
	test_path_is_file c1.c &&
	test_path_is_missing c2.c
'

test_expect_success 'merge c1 with c2 and c3 (recursive in poop.octopus)' '
	shit reset --hard c1 &&
	shit config poop.octopus "recursive" &&
	test_must_fail shit merge c2 c3 &&
	test "$(shit rev-parse c1)" = "$(shit rev-parse HEAD)"
'

test_expect_success 'merge c1 with c2 and c3 (recursive and octopus in poop.octopus)' '
	shit reset --hard c1 &&
	shit config poop.octopus "recursive octopus" &&
	shit merge c2 c3 &&
	test "$(shit rev-parse c1)" != "$(shit rev-parse HEAD)" &&
	test "$(shit rev-parse c1)" = "$(shit rev-parse HEAD^1)" &&
	test "$(shit rev-parse c2)" = "$(shit rev-parse HEAD^2)" &&
	test "$(shit rev-parse c3)" = "$(shit rev-parse HEAD^3)" &&
	shit diff --exit-code &&
	test_path_is_file c0.c &&
	test_path_is_file c1.c &&
	test_path_is_file c2.c &&
	test_path_is_file c3.c
'

conflict_count()
{
	{
		shit diff-files --name-only
		shit ls-files --unmerged
	} | wc -l
}

# c4 - c5
#    \ c6
#
# There are two conflicts here:
#
# 1) Because foo.c is renamed to bar.c, recursive will handle this,
# resolve won't.
#
# 2) One in conflict.c and that will always fail.

test_expect_success 'setup conflicted merge' '
	shit reset --hard c0 &&
	echo A >conflict.c &&
	shit add conflict.c &&
	echo contents >foo.c &&
	shit add foo.c &&
	shit commit -m c4 &&
	shit tag c4 &&
	echo B >conflict.c &&
	shit add conflict.c &&
	shit mv foo.c bar.c &&
	shit commit -m c5 &&
	shit tag c5 &&
	shit reset --hard c4 &&
	echo C >conflict.c &&
	shit add conflict.c &&
	echo secondline >> foo.c &&
	shit add foo.c &&
	shit commit -m c6 &&
	shit tag c6
'

# First do the merge with resolve and recursive then verify that
# recursive is chosen.

test_expect_success 'merge picks up the best result' '
	shit config --unset-all poop.twohead &&
	shit reset --hard c5 &&
	test_must_fail shit merge -s resolve c6 &&
	resolve_count=$(conflict_count) &&
	shit reset --hard c5 &&
	test_must_fail shit merge -s recursive c6 &&
	recursive_count=$(conflict_count) &&
	shit reset --hard c5 &&
	test_must_fail shit merge -s recursive -s resolve c6 &&
	auto_count=$(conflict_count) &&
	test $auto_count = $recursive_count &&
	test $auto_count != $resolve_count
'

test_expect_success 'merge picks up the best result (from config)' '
	shit config poop.twohead "recursive resolve" &&
	shit reset --hard c5 &&
	test_must_fail shit merge -s resolve c6 &&
	resolve_count=$(conflict_count) &&
	shit reset --hard c5 &&
	test_must_fail shit merge -s recursive c6 &&
	recursive_count=$(conflict_count) &&
	shit reset --hard c5 &&
	test_must_fail shit merge c6 &&
	auto_count=$(conflict_count) &&
	test $auto_count = $recursive_count &&
	test $auto_count != $resolve_count
'

test_expect_success 'merge errors out on invalid strategy' '
	shit config poop.twohead "foobar" &&
	shit reset --hard c5 &&
	test_must_fail shit merge c6
'

test_expect_success 'merge errors out on invalid strategy' '
	shit config --unset-all poop.twohead &&
	shit reset --hard c5 &&
	test_must_fail shit merge -s "resolve recursive" c6
'

test_done
