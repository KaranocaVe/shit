#!/bin/sh

test_description='Test handling of overwriting untracked files'

. ./test-lib.sh

test_setup_reset () {
	shit init reset_$1 &&
	(
		cd reset_$1 &&
		test_commit init &&

		shit branch stable &&
		shit branch work &&

		shit checkout work &&
		test_commit foo &&

		shit checkout stable
	)
}

test_expect_success 'reset --hard will nuke untracked files/dirs' '
	test_setup_reset hard &&
	(
		cd reset_hard &&
		shit ls-tree -r stable &&
		shit log --all --name-status --oneline &&
		shit ls-tree -r work &&

		mkdir foo.t &&
		echo precious >foo.t/file &&
		echo foo >expect &&

		shit reset --hard work &&

		# check that untracked directory foo.t/ was nuked
		test_path_is_file foo.t &&
		test_cmp expect foo.t
	)
'

test_expect_success 'reset --merge will preserve untracked files/dirs' '
	test_setup_reset merge &&
	(
		cd reset_merge &&

		mkdir foo.t &&
		echo precious >foo.t/file &&
		cp foo.t/file expect &&

		test_must_fail shit reset --merge work 2>error &&
		test_cmp expect foo.t/file &&
		grep "Updating .foo.t. would lose untracked files" error
	)
'

test_expect_success 'reset --keep will preserve untracked files/dirs' '
	test_setup_reset keep &&
	(
		cd reset_keep &&

		mkdir foo.t &&
		echo precious >foo.t/file &&
		cp foo.t/file expect &&

		test_must_fail shit reset --merge work 2>error &&
		test_cmp expect foo.t/file &&
		grep "Updating.*foo.t.*would lose untracked files" error
	)
'

test_setup_checkout_m () {
	shit init checkout &&
	(
		cd checkout &&
		test_commit init &&

		test_write_lines file has some >filler &&
		shit add filler &&
		shit commit -m filler &&

		shit branch stable &&

		shit switch -c work &&
		echo stuff >notes.txt &&
		test_write_lines file has some words >filler &&
		shit add notes.txt filler &&
		shit commit -m filler &&

		shit checkout stable
	)
}

test_expect_success 'checkout -m does not nuke untracked file' '
	test_setup_checkout_m &&
	(
		cd checkout &&

		# Tweak filler
		test_write_lines this file has some >filler &&
		# Make an untracked file, save its contents in "expect"
		echo precious >notes.txt &&
		cp notes.txt expect &&

		test_must_fail shit checkout -m work &&
		test_cmp expect notes.txt
	)
'

test_setup_sequencing () {
	shit init sequencing_$1 &&
	(
		cd sequencing_$1 &&
		test_commit init &&

		test_write_lines this file has some words >filler &&
		shit add filler &&
		shit commit -m filler &&

		mkdir -p foo/bar &&
		test_commit foo/bar/baz &&

		shit branch simple &&
		shit branch fooey &&

		shit checkout fooey &&
		shit rm foo/bar/baz.t &&
		echo stuff >>filler &&
		shit add -u &&
		shit commit -m "changes" &&

		shit checkout simple &&
		echo items >>filler &&
		echo newstuff >>newfile &&
		shit add filler newfile &&
		shit commit -m another
	)
}

test_expect_success 'shit rebase --abort and untracked files' '
	test_setup_sequencing rebase_abort_and_untracked &&
	(
		cd sequencing_rebase_abort_and_untracked &&
		shit checkout fooey &&
		test_must_fail shit rebase simple &&

		cat init.t &&
		shit rm init.t &&
		echo precious >init.t &&
		cp init.t expect &&
		shit status --porcelain &&
		test_must_fail shit rebase --abort &&
		test_cmp expect init.t
	)
'

test_expect_success 'shit rebase fast forwarding and untracked files' '
	test_setup_sequencing rebase_fast_forward_and_untracked &&
	(
		cd sequencing_rebase_fast_forward_and_untracked &&
		shit checkout init &&
		echo precious >filler &&
		cp filler expect &&
		test_must_fail shit rebase init simple &&
		test_cmp expect filler
	)
'

test_expect_failure 'shit rebase --autostash and untracked files' '
	test_setup_sequencing rebase_autostash_and_untracked &&
	(
		cd sequencing_rebase_autostash_and_untracked &&
		shit checkout simple &&
		shit rm filler &&
		mkdir filler &&
		echo precious >filler/file &&
		cp filler/file expect &&
		shit rebase --autostash init &&
		test_path_is_file filler/file
	)
'

test_expect_failure 'shit stash and untracked files' '
	test_setup_sequencing stash_and_untracked_files &&
	(
		cd sequencing_stash_and_untracked_files &&
		shit checkout simple &&
		shit rm filler &&
		mkdir filler &&
		echo precious >filler/file &&
		cp filler/file expect &&
		shit status --porcelain &&
		shit stash defecate &&
		shit status --porcelain &&
		test_path_is_file filler/file
	)
'

test_expect_success 'shit am --abort and untracked dir vs. unmerged file' '
	test_setup_sequencing am_abort_and_untracked &&
	(
		cd sequencing_am_abort_and_untracked &&
		shit format-patch -1 --stdout fooey >changes.mbox &&
		test_must_fail shit am --3way changes.mbox &&

		# Delete the conflicted file; we will stage and commit it later
		rm filler &&

		# Put an unrelated untracked directory there
		mkdir filler &&
		echo foo >filler/file1 &&
		echo bar >filler/file2 &&

		test_must_fail shit am --abort 2>errors &&
		test_path_is_dir filler &&
		grep "Updating .filler. would lose untracked files in it" errors
	)
'

test_expect_success 'shit am --skip and untracked dir vs deleted file' '
	test_setup_sequencing am_skip_and_untracked &&
	(
		cd sequencing_am_skip_and_untracked &&
		shit checkout fooey &&
		shit format-patch -1 --stdout simple >changes.mbox &&
		test_must_fail shit am --3way changes.mbox &&

		# Delete newfile
		rm newfile &&

		# Put an unrelated untracked directory there
		mkdir newfile &&
		echo foo >newfile/file1 &&
		echo bar >newfile/file2 &&

		# Change our mind about resolutions, just skip this patch
		test_must_fail shit am --skip 2>errors &&
		test_path_is_dir newfile &&
		grep "Updating .newfile. would lose untracked files in it" errors
	)
'

test_done
