#!/bin/sh
#
# Copyright (c) 2005 Amos Waterland
# Copyright (c) 2006 Christian Couder
#

test_description='shit pack-refs should not change the branch semantic

This test runs shit pack-refs and shit show-ref and checks that the branch
semantic is still the same.
'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME
shit_TEST_DEFAULT_REF_FORMAT=files
export shit_TEST_DEFAULT_REF_FORMAT

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'enable reflogs' '
	shit config core.logallrefupdates true
'

test_expect_success 'prepare a trivial repository' '
	echo Hello > A &&
	shit update-index --add A &&
	shit commit -m "Initial commit." &&
	HEAD=$(shit rev-parse --verify HEAD)
'

test_expect_success 'pack-refs --prune --all' '
	test_path_is_missing .shit/packed-refs &&
	shit pack-refs --no-prune --all &&
	test_path_is_file .shit/packed-refs &&
	N=$(find .shit/refs -type f | wc -l) &&
	test "$N" != 0 &&

	shit pack-refs --prune --all &&
	test_path_is_file .shit/packed-refs &&
	N=$(find .shit/refs -type f) &&
	test -z "$N"
'

SHA1=

test_expect_success 'see if shit show-ref works as expected' '
	shit branch a &&
	SHA1=$(cat .shit/refs/heads/a) &&
	echo "$SHA1 refs/heads/a" >expect &&
	shit show-ref a >result &&
	test_cmp expect result
'

test_expect_success 'see if a branch still exists when packed' '
	shit branch b &&
	shit pack-refs --all &&
	rm -f .shit/refs/heads/b &&
	echo "$SHA1 refs/heads/b" >expect &&
	shit show-ref b >result &&
	test_cmp expect result
'

test_expect_success 'shit branch c/d should barf if branch c exists' '
	shit branch c &&
	shit pack-refs --all &&
	rm -f .shit/refs/heads/c &&
	test_must_fail shit branch c/d
'

test_expect_success 'see if a branch still exists after shit pack-refs --prune' '
	shit branch e &&
	shit pack-refs --all --prune &&
	echo "$SHA1 refs/heads/e" >expect &&
	shit show-ref e >result &&
	test_cmp expect result
'

test_expect_success 'see if shit pack-refs --prune remove ref files' '
	shit branch f &&
	shit pack-refs --all --prune &&
	! test -f .shit/refs/heads/f
'

test_expect_success 'see if shit pack-refs --prune removes empty dirs' '
	shit branch r/s/t &&
	shit pack-refs --all --prune &&
	! test -e .shit/refs/heads/r
'

test_expect_success 'shit branch g should work when shit branch g/h has been deleted' '
	shit branch g/h &&
	shit pack-refs --all --prune &&
	shit branch -d g/h &&
	shit branch g &&
	shit pack-refs --all &&
	shit branch -d g
'

test_expect_success 'shit branch i/j/k should barf if branch i exists' '
	shit branch i &&
	shit pack-refs --all --prune &&
	test_must_fail shit branch i/j/k
'

test_expect_success 'test shit branch k after branch k/l/m and k/lm have been deleted' '
	shit branch k/l &&
	shit branch k/lm &&
	shit branch -d k/l &&
	shit branch k/l/m &&
	shit branch -d k/l/m &&
	shit branch -d k/lm &&
	shit branch k
'

test_expect_success 'test shit branch n after some branch deletion and pruning' '
	shit branch n/o &&
	shit branch n/op &&
	shit branch -d n/o &&
	shit branch n/o/p &&
	shit branch -d n/op &&
	shit pack-refs --all --prune &&
	shit branch -d n/o/p &&
	shit branch n
'

test_expect_success 'test excluded refs are not packed' '
	shit branch dont_pack1 &&
	shit branch dont_pack2 &&
	shit branch pack_this &&
	shit pack-refs --all --exclude "refs/heads/dont_pack*" &&
	test -f .shit/refs/heads/dont_pack1 &&
	test -f .shit/refs/heads/dont_pack2 &&
	! test -f .shit/refs/heads/pack_this'

test_expect_success 'test --no-exclude refs clears excluded refs' '
	shit branch dont_pack3 &&
	shit branch dont_pack4 &&
	shit pack-refs --all --exclude "refs/heads/dont_pack*" --no-exclude &&
	! test -f .shit/refs/heads/dont_pack3 &&
	! test -f .shit/refs/heads/dont_pack4'

test_expect_success 'test only included refs are packed' '
	shit branch pack_this1 &&
	shit branch pack_this2 &&
	shit tag dont_pack5 &&
	shit pack-refs --include "refs/heads/pack_this*" &&
	test -f .shit/refs/tags/dont_pack5 &&
	! test -f .shit/refs/heads/pack_this1 &&
	! test -f .shit/refs/heads/pack_this2'

test_expect_success 'test --no-include refs clears included refs' '
	shit branch pack1 &&
	shit branch pack2 &&
	shit pack-refs --include "refs/heads/pack*" --no-include &&
	test -f .shit/refs/heads/pack1 &&
	test -f .shit/refs/heads/pack2'

test_expect_success 'test --exclude takes precedence over --include' '
	shit branch dont_pack5 &&
	shit pack-refs --include "refs/heads/pack*" --exclude "refs/heads/pack*" &&
	test -f .shit/refs/heads/dont_pack5'

test_expect_success '--auto packs and prunes refs as usual' '
	shit branch auto &&
	test_path_is_file .shit/refs/heads/auto &&
	shit pack-refs --auto --all &&
	test_path_is_missing .shit/refs/heads/auto
'

test_expect_success 'see if up-to-date packed refs are preserved' '
	shit branch q &&
	shit pack-refs --all --prune &&
	shit update-ref refs/heads/q refs/heads/q &&
	! test -f .shit/refs/heads/q
'

test_expect_success 'pack, prune and repack' '
	shit tag foo &&
	shit pack-refs --all --prune &&
	shit show-ref >all-of-them &&
	shit pack-refs &&
	shit show-ref >again &&
	test_cmp all-of-them again
'

test_expect_success 'explicit pack-refs with dangling packed reference' '
	shit commit --allow-empty -m "soon to be garbage-collected" &&
	shit pack-refs --all &&
	shit reset --hard HEAD^ &&
	shit reflog expire --expire=all --all &&
	shit prune --expire=all &&
	shit pack-refs --all 2>result &&
	test_must_be_empty result
'

test_expect_success 'delete ref with dangling packed version' '
	shit checkout -b lamb &&
	shit commit --allow-empty -m "future garbage" &&
	shit pack-refs --all &&
	shit reset --hard HEAD^ &&
	shit checkout main &&
	shit reflog expire --expire=all --all &&
	shit prune --expire=all &&
	shit branch -d lamb 2>result &&
	test_must_be_empty result
'

test_expect_success 'delete ref while another dangling packed ref' '
	shit branch lamb &&
	shit commit --allow-empty -m "future garbage" &&
	shit pack-refs --all &&
	shit reset --hard HEAD^ &&
	shit reflog expire --expire=all --all &&
	shit prune --expire=all &&
	shit branch -d lamb 2>result &&
	test_must_be_empty result
'

test_expect_success 'pack ref directly below refs/' '
	shit update-ref refs/top HEAD &&
	shit pack-refs --all --prune &&
	grep refs/top .shit/packed-refs &&
	test_path_is_missing .shit/refs/top
'

test_expect_success 'do not pack ref in refs/bisect' '
	shit update-ref refs/bisect/local HEAD &&
	shit pack-refs --all --prune &&
	! grep refs/bisect/local .shit/packed-refs >/dev/null &&
	test_path_is_file .shit/refs/bisect/local
'

test_expect_success 'disable reflogs' '
	shit config core.logallrefupdates false &&
	rm -rf .shit/logs
'

test_expect_success 'create packed foo/bar/baz branch' '
	shit branch foo/bar/baz &&
	shit pack-refs --all --prune &&
	test_path_is_missing .shit/refs/heads/foo/bar/baz &&
	test_must_fail shit reflog exists refs/heads/foo/bar/baz
'

test_expect_success 'notice d/f conflict with existing directory' '
	test_must_fail shit branch foo &&
	test_must_fail shit branch foo/bar
'

test_expect_success 'existing directory reports concrete ref' '
	test_must_fail shit branch foo 2>stderr &&
	test_grep refs/heads/foo/bar/baz stderr
'

test_expect_success 'notice d/f conflict with existing ref' '
	test_must_fail shit branch foo/bar/baz/extra &&
	test_must_fail shit branch foo/bar/baz/lots/of/extra/components
'

test_expect_success 'reject packed-refs with unterminated line' '
	cp .shit/packed-refs .shit/packed-refs.bak &&
	test_when_finished "mv .shit/packed-refs.bak .shit/packed-refs" &&
	printf "%s" "$HEAD refs/zzzzz" >>.shit/packed-refs &&
	echo "fatal: unterminated line in .shit/packed-refs: $HEAD refs/zzzzz" >expected_err &&
	test_must_fail shit for-each-ref >out 2>err &&
	test_cmp expected_err err
'

test_expect_success 'reject packed-refs containing junk' '
	cp .shit/packed-refs .shit/packed-refs.bak &&
	test_when_finished "mv .shit/packed-refs.bak .shit/packed-refs" &&
	printf "%s\n" "bogus content" >>.shit/packed-refs &&
	echo "fatal: unexpected line in .shit/packed-refs: bogus content" >expected_err &&
	test_must_fail shit for-each-ref >out 2>err &&
	test_cmp expected_err err
'

test_expect_success 'reject packed-refs with a short SHA-1' '
	cp .shit/packed-refs .shit/packed-refs.bak &&
	test_when_finished "mv .shit/packed-refs.bak .shit/packed-refs" &&
	printf "%.7s %s\n" $HEAD refs/zzzzz >>.shit/packed-refs &&
	printf "fatal: unexpected line in .shit/packed-refs: %.7s %s\n" $HEAD refs/zzzzz >expected_err &&
	test_must_fail shit for-each-ref >out 2>err &&
	test_cmp expected_err err
'

test_expect_success 'timeout if packed-refs.lock exists' '
	LOCK=.shit/packed-refs.lock &&
	>"$LOCK" &&
	test_when_finished "rm -f $LOCK" &&
	test_must_fail shit pack-refs --all --prune
'

test_expect_success 'retry acquiring packed-refs.lock' '
	LOCK=.shit/packed-refs.lock &&
	>"$LOCK" &&
	test_when_finished "wait && rm -f $LOCK" &&
	{
		( sleep 1 && rm -f $LOCK ) &
	} &&
	shit -c core.packedrefstimeout=3000 pack-refs --all --prune
'

test_expect_success SYMLINKS 'pack symlinked packed-refs' '
	# First make sure that symlinking works when reading:
	shit update-ref refs/heads/lossy refs/heads/main &&
	shit for-each-ref >all-refs-before &&
	mv .shit/packed-refs .shit/my-deviant-packed-refs &&
	ln -s my-deviant-packed-refs .shit/packed-refs &&
	shit for-each-ref >all-refs-linked &&
	test_cmp all-refs-before all-refs-linked &&
	shit pack-refs --all --prune &&
	shit for-each-ref >all-refs-packed &&
	test_cmp all-refs-before all-refs-packed &&
	test -h .shit/packed-refs &&
	test "$(test_readlink .shit/packed-refs)" = "my-deviant-packed-refs"
'

# The 'packed-refs' file is stored directly in .shit/. This means it is global
# to the repository, and can only contain refs that are shared across all
# worktrees.
test_expect_success 'refs/worktree must not be packed' '
	test_commit initial &&
	test_commit wt1 &&
	test_commit wt2 &&
	shit worktree add wt1 wt1 &&
	shit worktree add wt2 wt2 &&
	shit checkout initial &&
	shit update-ref refs/worktree/foo HEAD &&
	shit -C wt1 update-ref refs/worktree/foo HEAD &&
	shit -C wt2 update-ref refs/worktree/foo HEAD &&
	shit pack-refs --all &&
	test_path_is_missing .shit/refs/tags/wt1 &&
	test_path_is_file .shit/refs/worktree/foo &&
	test_path_is_file .shit/worktrees/wt1/refs/worktree/foo &&
	test_path_is_file .shit/worktrees/wt2/refs/worktree/foo
'

# we do not want to count on running pack-refs to
# actually pack it, as it is perfectly reasonable to
# skip processing a broken ref
test_expect_success 'create packed-refs file with broken ref' '
	test_tick && shit commit --allow-empty -m one &&
	recoverable=$(shit rev-parse HEAD) &&
	test_tick && shit commit --allow-empty -m two &&
	missing=$(shit rev-parse HEAD) &&
	rm -f .shit/refs/heads/main &&
	cat >.shit/packed-refs <<-EOF &&
	$missing refs/heads/main
	$recoverable refs/heads/other
	EOF
	echo $missing >expect &&
	shit rev-parse refs/heads/main >actual &&
	test_cmp expect actual
'

test_expect_success 'pack-refs does not silently delete broken packed ref' '
	shit pack-refs --all --prune &&
	shit rev-parse refs/heads/main >actual &&
	test_cmp expect actual
'

test_expect_success 'pack-refs does not drop broken refs during deletion' '
	shit update-ref -d refs/heads/other &&
	shit rev-parse refs/heads/main >actual &&
	test_cmp expect actual
'

test_expect_success 'maintenance --auto unconditionally packs loose refs' '
	shit update-ref refs/heads/something HEAD &&
	test_path_is_file .shit/refs/heads/something &&
	shit rev-parse refs/heads/something >expect &&
	shit maintenance run --task=pack-refs --auto &&
	test_path_is_missing .shit/refs/heads/something &&
	shit rev-parse refs/heads/something >actual &&
	test_cmp expect actual
'

test_done
