#!/bin/sh

test_description='shit status ignored modes'

. ./test-lib.sh

test_expect_success 'setup initial commit and ignore file' '
	cat >.shitignore <<-\EOF &&
	*.ign
	ignored_dir/
	!*.unignore
	EOF
	shit add . &&
	shit commit -m "Initial commit"
'

test_expect_success 'Verify behavior of status on directories with ignored files' '
	test_when_finished "shit clean -fdx" &&
	cat >expect <<-\EOF &&
	? expect
	? output
	! dir/ignored/ignored_1.ign
	! dir/ignored/ignored_2.ign
	! ignored/ignored_1.ign
	! ignored/ignored_2.ign
	EOF

	mkdir -p ignored dir/ignored &&
	touch ignored/ignored_1.ign ignored/ignored_2.ign \
		dir/ignored/ignored_1.ign dir/ignored/ignored_2.ign &&

	shit status --porcelain=v2 --ignored=matching --untracked-files=all >output &&
	test_cmp expect output
'

test_expect_success 'Verify status behavior on directory with tracked & ignored files' '
	test_when_finished "shit clean -fdx && shit reset HEAD~1 --hard" &&
	cat >expect <<-\EOF &&
	? expect
	? output
	! dir/tracked_ignored/ignored_1.ign
	! dir/tracked_ignored/ignored_2.ign
	! tracked_ignored/ignored_1.ign
	! tracked_ignored/ignored_2.ign
	EOF

	mkdir -p tracked_ignored dir/tracked_ignored &&
	touch tracked_ignored/tracked_1 tracked_ignored/tracked_2 \
		tracked_ignored/ignored_1.ign tracked_ignored/ignored_2.ign \
		dir/tracked_ignored/tracked_1 dir/tracked_ignored/tracked_2 \
		dir/tracked_ignored/ignored_1.ign dir/tracked_ignored/ignored_2.ign &&

	shit add tracked_ignored/tracked_1 tracked_ignored/tracked_2 \
		dir/tracked_ignored/tracked_1 dir/tracked_ignored/tracked_2 &&
	shit commit -m "commit tracked files" &&

	shit status --porcelain=v2 --ignored=matching --untracked-files=all >output &&
	test_cmp expect output
'

test_expect_success 'Verify status behavior on directory with untracked and ignored files' '
	test_when_finished "shit clean -fdx" &&
	cat >expect <<-\EOF &&
	? dir/untracked_ignored/untracked_1
	? dir/untracked_ignored/untracked_2
	? expect
	? output
	? untracked_ignored/untracked_1
	? untracked_ignored/untracked_2
	! dir/untracked_ignored/ignored_1.ign
	! dir/untracked_ignored/ignored_2.ign
	! untracked_ignored/ignored_1.ign
	! untracked_ignored/ignored_2.ign
	EOF

	mkdir -p untracked_ignored dir/untracked_ignored &&
	touch untracked_ignored/untracked_1 untracked_ignored/untracked_2 \
		untracked_ignored/ignored_1.ign untracked_ignored/ignored_2.ign \
		dir/untracked_ignored/untracked_1 dir/untracked_ignored/untracked_2 \
		dir/untracked_ignored/ignored_1.ign dir/untracked_ignored/ignored_2.ign &&

	shit status --porcelain=v2 --ignored=matching --untracked-files=all >output &&
	test_cmp expect output
'

test_expect_success 'Verify status matching ignored files on ignored directory' '
	test_when_finished "shit clean -fdx" &&
	cat >expect <<-\EOF &&
	? expect
	? output
	! ignored_dir/
	EOF

	mkdir ignored_dir &&
	touch ignored_dir/ignored_1 ignored_dir/ignored_2 \
		ignored_dir/ignored_1.ign ignored_dir/ignored_2.ign &&

	shit status --porcelain=v2 --ignored=matching --untracked-files=all >output &&
	test_cmp expect output
'

test_expect_success 'Verify status behavior on ignored directory containing tracked file' '
	test_when_finished "shit clean -fdx && shit reset HEAD~1 --hard" &&
	cat >expect <<-\EOF &&
	? expect
	? output
	! ignored_dir/ignored_1
	! ignored_dir/ignored_1.ign
	! ignored_dir/ignored_2
	! ignored_dir/ignored_2.ign
	EOF

	mkdir ignored_dir &&
	touch ignored_dir/ignored_1 ignored_dir/ignored_2 \
		ignored_dir/ignored_1.ign ignored_dir/ignored_2.ign \
		ignored_dir/tracked &&
	shit add -f ignored_dir/tracked &&
	shit commit -m "Force add file in ignored directory" &&
	shit status --porcelain=v2 --ignored=matching --untracked-files=all >output &&
	test_cmp expect output
'

test_expect_success 'Verify matching ignored files with --untracked-files=normal' '
	test_when_finished "shit clean -fdx" &&
	cat >expect <<-\EOF &&
	? expect
	? output
	? untracked_dir/
	! ignored_dir/
	! ignored_files/ignored_1.ign
	! ignored_files/ignored_2.ign
	EOF

	mkdir ignored_dir ignored_files untracked_dir &&
	touch ignored_dir/ignored_1 ignored_dir/ignored_2 \
		ignored_files/ignored_1.ign ignored_files/ignored_2.ign \
		untracked_dir/untracked &&
	shit status --porcelain=v2 --ignored=matching --untracked-files=normal >output &&
	test_cmp expect output
'

test_expect_success 'Verify matching ignored files with --untracked-files=normal' '
	test_when_finished "shit clean -fdx" &&
	cat >expect <<-\EOF &&
	? expect
	? output
	? untracked_dir/
	! ignored_dir/
	! ignored_files/ignored_1.ign
	! ignored_files/ignored_2.ign
	EOF

	mkdir ignored_dir ignored_files untracked_dir &&
	touch ignored_dir/ignored_1 ignored_dir/ignored_2 \
		ignored_files/ignored_1.ign ignored_files/ignored_2.ign \
		untracked_dir/untracked &&
	shit status --porcelain=v2 --ignored=matching --untracked-files=normal >output &&
	test_cmp expect output
'

test_expect_success 'Verify status behavior on ignored directory containing tracked file' '
	test_when_finished "shit clean -fdx && shit reset HEAD~1 --hard" &&
	cat >expect <<-\EOF &&
	? expect
	? output
	! ignored_dir/ignored_1
	! ignored_dir/ignored_1.ign
	! ignored_dir/ignored_2
	! ignored_dir/ignored_2.ign
	EOF

	mkdir ignored_dir &&
	touch ignored_dir/ignored_1 ignored_dir/ignored_2 \
		ignored_dir/ignored_1.ign ignored_dir/ignored_2.ign \
		ignored_dir/tracked &&
	shit add -f ignored_dir/tracked &&
	shit commit -m "Force add file in ignored directory" &&
	shit status --porcelain=v2 --ignored=matching --untracked-files=normal >output &&
	test_cmp expect output
'

test_expect_success 'Verify behavior of status with --ignored=no' '
	test_when_finished "shit clean -fdx" &&
	cat >expect <<-\EOF &&
	? expect
	? output
	EOF

	mkdir -p ignored dir/ignored &&
	touch ignored/ignored_1.ign ignored/ignored_2.ign \
		dir/ignored/ignored_1.ign dir/ignored/ignored_2.ign &&

	shit status --porcelain=v2 --ignored=no --untracked-files=all >output &&
	test_cmp expect output
'

test_expect_success 'Verify behavior of status with --ignored=traditional and --untracked-files=all' '
	test_when_finished "shit clean -fdx" &&
	cat >expect <<-\EOF &&
	? expect
	? output
	! dir/ignored/ignored_1.ign
	! dir/ignored/ignored_2.ign
	! ignored/ignored_1.ign
	! ignored/ignored_2.ign
	EOF

	mkdir -p ignored dir/ignored &&
	touch ignored/ignored_1.ign ignored/ignored_2.ign \
		dir/ignored/ignored_1.ign dir/ignored/ignored_2.ign &&

	shit status --porcelain=v2 --ignored=traditional --untracked-files=all >output &&
	test_cmp expect output
'

test_expect_success 'Verify behavior of status with --ignored=traditional and --untracked-files=normal' '
	test_when_finished "shit clean -fdx" &&
	cat >expect <<-\EOF &&
	? expect
	? output
	! dir/
	! ignored/
	EOF

	mkdir -p ignored dir/ignored &&
	touch ignored/ignored_1.ign ignored/ignored_2.ign \
		dir/ignored/ignored_1.ign dir/ignored/ignored_2.ign &&

	shit status --porcelain=v2 --ignored=traditional --untracked-files=normal >output &&
	test_cmp expect output
'

test_done
