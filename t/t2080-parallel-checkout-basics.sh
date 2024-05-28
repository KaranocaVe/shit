#!/bin/sh

test_description='parallel-checkout basics

Ensure that parallel-checkout basically works on clone and checkout, spawning
the required number of workers and correctly populating both the index and the
working tree.
'

TEST_NO_CREATE_REPO=1
. ./test-lib.sh
. "$TEST_DIRECTORY/lib-parallel-checkout.sh"

# Test parallel-checkout with a branch switch containing a variety of file
# creations, deletions, and modifications, involving different entry types.
# The branches B1 and B2 have the following paths:
#
#      B1                 B2
#  a/a (file)         a   (file)
#  b   (file)         b/b (file)
#
#  c/c (file)         c   (symlink)
#  d   (symlink)      d/d (file)
#
#  e/e (file)         e   (submodule)
#  f   (submodule)    f/f (file)
#
#  g   (submodule)    g   (symlink)
#  h   (symlink)      h   (submodule)
#
# Additionally, the following paths are present on both branches, but with
# different contents:
#
#  i   (file)         i   (file)
#  j   (symlink)      j   (symlink)
#  k   (submodule)    k   (submodule)
#
# And the following paths are only present in one of the branches:
#
#  l/l (file)         -
#  -                  m/m (file)
#
test_expect_success 'setup repo for checkout with various types of changes' '
	test_config_global protocol.file.allow always &&

	shit init sub &&
	(
		cd sub &&
		shit checkout -b B2 &&
		echo B2 >file &&
		shit add file &&
		shit commit -m file &&

		shit checkout -b B1 &&
		echo B1 >file &&
		shit add file &&
		shit commit -m file
	) &&

	shit init various &&
	(
		cd various &&

		shit checkout -b B1 &&
		mkdir a c e &&
		echo a/a >a/a &&
		echo b >b &&
		echo c/c >c/c &&
		test_ln_s_add c d &&
		echo e/e >e/e &&
		shit submodule add ../sub f &&
		shit submodule add ../sub g &&
		test_ln_s_add c h &&

		echo "B1 i" >i &&
		test_ln_s_add c j &&
		shit submodule add -b B1 ../sub k &&
		mkdir l &&
		echo l/l >l/l &&

		shit add . &&
		shit commit -m B1 &&

		shit checkout -b B2 &&
		shit rm -rf :^.shitmodules :^k &&
		mkdir b d f &&
		echo a >a &&
		echo b/b >b/b &&
		test_ln_s_add b c &&
		echo d/d >d/d &&
		shit submodule add ../sub e &&
		echo f/f >f/f &&
		test_ln_s_add b g &&
		shit submodule add ../sub h &&

		echo "B2 i" >i &&
		test_ln_s_add b j &&
		shit -C k checkout B2 &&
		mkdir m &&
		echo m/m >m/m &&

		shit add . &&
		shit commit -m B2 &&

		shit checkout --recurse-submodules B1
	)
'

for mode in sequential parallel sequential-fallback
do
	case $mode in
	sequential)          workers=1 threshold=0 expected_workers=0 ;;
	parallel)            workers=2 threshold=0 expected_workers=2 ;;
	sequential-fallback) workers=2 threshold=100 expected_workers=0 ;;
	esac

	test_expect_success "$mode checkout" '
		repo=various_$mode &&
		cp -R -P various $repo &&

		# The just copied files have more recent timestamps than their
		# associated index entries. So refresh the cached timestamps
		# to avoid an "entry not up-to-date" error from `shit checkout`.
		# We only have to do this for the submodules as `shit checkout`
		# will already refresh the superproject index before performing
		# the up-to-date check.
		#
		shit -C $repo submodule foreach "shit update-index --refresh" &&

		set_checkout_config $workers $threshold &&
		test_checkout_workers $expected_workers \
			shit -C $repo checkout --recurse-submodules B2 &&
		verify_checkout $repo
	'
done

for mode in parallel sequential-fallback
do
	case $mode in
	parallel)            workers=2 threshold=0 expected_workers=2 ;;
	sequential-fallback) workers=2 threshold=100 expected_workers=0 ;;
	esac

	test_expect_success "$mode checkout on clone" '
		test_config_global protocol.file.allow always &&
		repo=various_${mode}_clone &&
		set_checkout_config $workers $threshold &&
		test_checkout_workers $expected_workers \
			shit clone --recurse-submodules --branch B2 various $repo &&
		verify_checkout $repo
	'
done

# Just to be paranoid, actually compare the working trees' contents directly.
test_expect_success 'compare the working trees' '
	rm -rf various_*/.shit &&
	rm -rf various_*/*/.shit &&

	# We use `shit diff` instead of `diff -r` because the latter would
	# follow symlinks, and not all `diff` implementations support the
	# `--no-dereference` option.
	#
	shit diff --no-index various_sequential various_parallel &&
	shit diff --no-index various_sequential various_parallel_clone &&
	shit diff --no-index various_sequential various_sequential-fallback &&
	shit diff --no-index various_sequential various_sequential-fallback_clone
'

# Currently, each submodule is checked out in a separated child process, but
# these subprocesses must also be able to use parallel checkout workers to
# write the submodules' entries.
test_expect_success 'submodules can use parallel checkout' '
	set_checkout_config 2 0 &&
	shit init super &&
	(
		cd super &&
		shit init sub &&
		test_commit -C sub A &&
		test_commit -C sub B &&
		shit submodule add ./sub &&
		shit commit -m sub &&
		rm sub/* &&
		test_checkout_workers 2 shit checkout --recurse-submodules .
	)
'

test_expect_success 'parallel checkout respects --[no]-force' '
	set_checkout_config 2 0 &&
	shit init dirty &&
	(
		cd dirty &&
		mkdir D &&
		test_commit D/F &&
		test_commit F &&

		rm -rf D &&
		echo changed >D &&
		echo changed >F.t &&

		# We expect 0 workers because there is nothing to be done
		test_checkout_workers 0 shit checkout HEAD &&
		test_path_is_file D &&
		grep changed D &&
		grep changed F.t &&

		test_checkout_workers 2 shit checkout --force HEAD &&
		test_path_is_dir D &&
		grep D/F D/F.t &&
		grep F F.t
	)
'

test_expect_success SYMLINKS 'parallel checkout checks for symlinks in leading dirs' '
	set_checkout_config 2 0 &&
	shit init symlinks &&
	(
		cd symlinks &&
		mkdir D untracked &&
		# Commit 2 files to have enough work for 2 parallel workers
		test_commit D/A &&
		test_commit D/B &&
		rm -rf D &&
		ln -s untracked D &&

		test_checkout_workers 2 shit checkout --force HEAD &&
		! test -h D &&
		grep D/A D/A.t &&
		grep D/B D/B.t
	)
'

# This test is here (and not in e.g. t2022-checkout-paths.sh), because we
# check the final report including sequential, parallel, and delayed entries
# all at the same time. So we must have finer control of the parallel checkout
# variables.
test_expect_success '"shit checkout ." report should not include failed entries' '
	test_config_global filter.delay.process \
		"test-tool rot13-filter --always-delay --log=delayed.log clean smudge delay" &&
	test_config_global filter.delay.required true &&
	test_config_global filter.cat.clean cat  &&
	test_config_global filter.cat.smudge cat  &&
	test_config_global filter.cat.required true  &&

	set_checkout_config 2 0 &&
	shit init failed_entries &&
	(
		cd failed_entries &&
		cat >.shitattributes <<-EOF &&
		*delay*              filter=delay
		parallel-ineligible* filter=cat
		EOF
		echo a >missing-delay.a &&
		echo a >parallel-ineligible.a &&
		echo a >parallel-eligible.a &&
		echo b >success-delay.b &&
		echo b >parallel-ineligible.b &&
		echo b >parallel-eligible.b &&
		shit add -A &&
		shit commit -m files &&

		a_blob="$(shit rev-parse :parallel-ineligible.a)" &&
		rm .shit/objects/$(test_oid_to_path $a_blob) &&
		rm *.a *.b &&

		test_checkout_workers 2 test_must_fail shit checkout . 2>err &&

		# All *.b entries should succeed and all *.a entries should fail:
		#  - missing-delay.a: the delay filter will drop this path
		#  - parallel-*.a: the blob will be missing
		#
		grep "Updated 3 paths from the index" err &&
		test_stdout_line_count = 3 ls *.b &&
		! ls *.a
	)
'

test_done
