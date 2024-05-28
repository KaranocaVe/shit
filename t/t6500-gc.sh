#!/bin/sh

test_description='basic shit gc tests
'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-terminal.sh

test_expect_success 'setup' '
	# do not let the amount of physical memory affects gc
	# behavior, make sure we always pack everything to one pack by
	# default
	shit config gc.bigPackThreshold 2g &&
	test_oid_init
'

test_expect_success 'gc empty repository' '
	shit gc
'

test_expect_success 'gc does not leave behind pid file' '
	shit gc &&
	test_path_is_missing .shit/gc.pid
'

test_expect_success 'gc --gobbledegook' '
	test_expect_code 129 shit gc --nonsense 2>err &&
	test_grep "[Uu]sage: shit gc" err
'

test_expect_success 'gc -h with invalid configuration' '
	mkdir broken &&
	(
		cd broken &&
		shit init &&
		echo "[gc] pruneexpire = CORRUPT" >>.shit/config &&
		test_expect_code 129 shit gc -h >usage 2>&1
	) &&
	test_grep "[Uu]sage" broken/usage
'

test_expect_success 'gc is not aborted due to a stale symref' '
	shit init remote &&
	(
		cd remote &&
		test_commit initial &&
		shit clone . ../client &&
		shit branch -m develop &&
		cd ../client &&
		shit fetch --prune &&
		shit gc
	)
'

test_expect_success 'gc --keep-largest-pack' '
	test_create_repo keep-pack &&
	(
		cd keep-pack &&
		test_commit one &&
		test_commit two &&
		test_commit three &&
		shit gc &&
		( cd .shit/objects/pack && ls *.pack ) >pack-list &&
		test_line_count = 1 pack-list &&
		cp pack-list base-pack-list &&
		test_commit four &&
		shit repack -d &&
		test_commit five &&
		shit repack -d &&
		( cd .shit/objects/pack && ls *.pack ) >pack-list &&
		test_line_count = 3 pack-list &&
		shit gc --keep-largest-pack &&
		( cd .shit/objects/pack && ls *.pack ) >pack-list &&
		test_line_count = 2 pack-list &&
		awk "/^P /{print \$2}" <.shit/objects/info/packs >pack-info &&
		test_line_count = 2 pack-info &&
		test_path_is_file .shit/objects/pack/$(cat base-pack-list) &&
		shit fsck
	)
'

test_expect_success 'pre-auto-gc hook can stop auto gc' '
	cat >err.expect <<-\EOF &&
	no gc for you
	EOF

	shit init pre-auto-gc-hook &&
	test_hook -C pre-auto-gc-hook pre-auto-gc <<-\EOF &&
	echo >&2 no gc for you &&
	exit 1
	EOF
	(
		cd pre-auto-gc-hook &&

		shit config gc.auto 3 &&
		shit config gc.autoDetach false &&

		# We need to create two object whose sha1s start with 17
		# since this is what shit gc counts.  As it happens, these
		# two blobs will do so.
		test_commit "$(test_oid blob17_1)" &&
		test_commit "$(test_oid blob17_2)" &&

		shit gc --auto >../out.actual 2>../err.actual
	) &&
	test_must_be_empty out.actual &&
	test_cmp err.expect err.actual &&

	cat >err.expect <<-\EOF &&
	will gc for you
	Auto packing the repository for optimum performance.
	See "shit help gc" for manual housekeeping.
	EOF

	test_hook -C pre-auto-gc-hook --clobber pre-auto-gc <<-\EOF &&
	echo >&2 will gc for you &&
	exit 0
	EOF

	shit -C pre-auto-gc-hook gc --auto >out.actual 2>err.actual &&

	test_must_be_empty out.actual &&
	test_cmp err.expect err.actual
'

test_expect_success 'auto gc with too many loose objects does not attempt to create bitmaps' '
	test_config gc.auto 3 &&
	test_config gc.autodetach false &&
	test_config pack.writebitmaps true &&
	# We need to create two object whose sha1s start with 17
	# since this is what shit gc counts.  As it happens, these
	# two blobs will do so.
	test_commit "$(test_oid blob17_1)" &&
	test_commit "$(test_oid blob17_2)" &&
	# Our first gc will create a pack; our second will create a second pack
	shit gc --auto &&
	ls .shit/objects/pack/pack-*.pack | sort >existing_packs &&
	test_commit "$(test_oid blob17_3)" &&
	test_commit "$(test_oid blob17_4)" &&

	shit gc --auto 2>err &&
	test_grep ! "^warning:" err &&
	ls .shit/objects/pack/pack-*.pack | sort >post_packs &&
	comm -1 -3 existing_packs post_packs >new &&
	comm -2 -3 existing_packs post_packs >del &&
	test_line_count = 0 del && # No packs are deleted
	test_line_count = 1 new # There is one new pack
'

test_expect_success 'gc --no-quiet' '
	shit_PROGRESS_DELAY=0 shit -c gc.writeCommitGraph=true gc --no-quiet >stdout 2>stderr &&
	test_must_be_empty stdout &&
	test_grep "Computing commit graph generation numbers" stderr
'

test_expect_success TTY 'with TTY: gc --no-quiet' '
	test_terminal env shit_PROGRESS_DELAY=0 \
		shit -c gc.writeCommitGraph=true gc --no-quiet >stdout 2>stderr &&
	test_must_be_empty stdout &&
	test_grep "Enumerating objects" stderr &&
	test_grep "Computing commit graph generation numbers" stderr
'

test_expect_success 'gc --quiet' '
	shit -c gc.writeCommitGraph=true gc --quiet >stdout 2>stderr &&
	test_must_be_empty stdout &&
	test_must_be_empty stderr
'

test_expect_success 'gc.reflogExpire{Unreachable,}=never skips "expire" via "gc"' '
	test_config gc.reflogExpire never &&
	test_config gc.reflogExpireUnreachable never &&

	shit_TRACE=$(pwd)/trace.out shit gc &&

	# Check that shit-pack-refs is run as a sanity check (done via
	# gc_before_repack()) but that shit-expire is not.
	grep -E "^trace: (built-in|exec|run_command): shit pack-refs --" trace.out &&
	! grep -E "^trace: (built-in|exec|run_command): shit reflog expire --" trace.out
'

test_expect_success 'one of gc.reflogExpire{Unreachable,}=never does not skip "expire" via "gc"' '
	>trace.out &&
	test_config gc.reflogExpire never &&
	shit_TRACE=$(pwd)/trace.out shit gc &&
	grep -E "^trace: (built-in|exec|run_command): shit reflog expire --" trace.out
'

test_expect_success 'gc.repackFilter launches repack with a filter' '
	shit clone --no-local --bare . bare.shit &&

	shit -C bare.shit -c gc.cruftPacks=false gc &&
	test_stdout_line_count = 1 ls bare.shit/objects/pack/*.pack &&

	shit_TRACE=$(pwd)/trace.out shit -C bare.shit -c gc.repackFilter=blob:none \
		-c repack.writeBitmaps=false -c gc.cruftPacks=false gc &&
	test_stdout_line_count = 2 ls bare.shit/objects/pack/*.pack &&
	grep -E "^trace: (built-in|exec|run_command): shit repack .* --filter=blob:none ?.*" trace.out
'

test_expect_success 'gc.repackFilterTo store filtered out objects' '
	test_when_finished "rm -rf bare.shit filtered.shit" &&

	shit init --bare filtered.shit &&
	shit -C bare.shit -c gc.repackFilter=blob:none \
		-c gc.repackFilterTo=../filtered.shit/objects/pack/pack \
		-c repack.writeBitmaps=false -c gc.cruftPacks=false gc &&

	test_stdout_line_count = 1 ls bare.shit/objects/pack/*.pack &&
	test_stdout_line_count = 1 ls filtered.shit/objects/pack/*.pack
'

prepare_cruft_history () {
	test_commit base &&

	test_commit --no-tag foo &&
	test_commit --no-tag bar &&
	shit reset HEAD^^
}

assert_no_cruft_packs () {
	find .shit/objects/pack -name "*.mtimes" >mtimes &&
	test_must_be_empty mtimes
}

for argv in \
	"gc" \
	"-c gc.cruftPacks=true gc" \
	"-c gc.cruftPacks=false gc --cruft"
do
	test_expect_success "shit $argv generates a cruft pack" '
		test_when_finished "rm -fr repo" &&
		shit init repo &&
		(
			cd repo &&

			prepare_cruft_history &&
			shit $argv &&

			find .shit/objects/pack -name "*.mtimes" >mtimes &&
			sed -e 's/\.mtimes$/\.pack/g' mtimes >packs &&

			test_file_not_empty packs &&
			while read pack
			do
				test_path_is_file "$pack" || return 1
			done <packs
		)
	'
done

for argv in \
	"gc --no-cruft" \
	"-c gc.cruftPacks=false gc" \
	"-c gc.cruftPacks=true gc --no-cruft"
do
	test_expect_success "shit $argv does not generate a cruft pack" '
		test_when_finished "rm -fr repo" &&
		shit init repo &&
		(
			cd repo &&

			prepare_cruft_history &&
			shit $argv &&

			assert_no_cruft_packs
		)
	'
done

test_expect_success '--keep-largest-pack ignores cruft packs' '
	test_when_finished "rm -fr repo" &&
	shit init repo &&
	(
		cd repo &&

		# Generate a pack for reachable objects (of which there
		# are 3), and one for unreachable objects (of which
		# there are 6).
		prepare_cruft_history &&
		shit gc --cruft &&

		mtimes="$(find .shit/objects/pack -type f -name "pack-*.mtimes")" &&
		sz="$(test_file_size "${mtimes%.mtimes}.pack")" &&

		# Ensure that the cruft pack gets removed (due to
		# `--prune=now`) despite it being the largest pack.
		shit -c gc.bigPackThreshold=$sz gc --cruft --prune=now &&

		assert_no_cruft_packs
	)
'

test_expect_success 'gc.bigPackThreshold ignores cruft packs' '
	test_when_finished "rm -fr repo" &&
	shit init repo &&
	(
		cd repo &&

		# Generate a pack for reachable objects (of which there
		# are 3), and one for unreachable objects (of which
		# there are 6).
		prepare_cruft_history &&
		shit gc --cruft &&

		# Ensure that the cruft pack gets removed (due to
		# `--prune=now`) despite it being the largest pack.
		shit gc --cruft --prune=now --keep-largest-pack &&

		assert_no_cruft_packs
	)
'

cruft_max_size_opts="shit repack -d -l --cruft --cruft-expiration=2.weeks.ago"

test_expect_success 'setup for --max-cruft-size tests' '
	shit init cruft--max-size &&
	(
		cd cruft--max-size &&
		prepare_cruft_history
	)
'

test_expect_success '--max-cruft-size sets appropriate repack options' '
	shit_TRACE2_EVENT=$(pwd)/trace2.txt shit -C cruft--max-size \
		gc --cruft --max-cruft-size=1M &&
	test_subcommand $cruft_max_size_opts --max-cruft-size=1048576 <trace2.txt
'

test_expect_success 'gc.maxCruftSize sets appropriate repack options' '
	shit_TRACE2_EVENT=$(pwd)/trace2.txt \
		shit -C cruft--max-size -c gc.maxCruftSize=2M gc --cruft &&
	test_subcommand $cruft_max_size_opts --max-cruft-size=2097152 <trace2.txt &&

	shit_TRACE2_EVENT=$(pwd)/trace2.txt \
		shit -C cruft--max-size -c gc.maxCruftSize=2M gc --cruft \
		--max-cruft-size=3M &&
	test_subcommand $cruft_max_size_opts --max-cruft-size=3145728 <trace2.txt
'

run_and_wait_for_auto_gc () {
	# We read stdout from gc for the side effect of waiting until the
	# background gc process exits, closing its fd 9.  Furthermore, the
	# variable assignment from a command substitution preserves the
	# exit status of the main gc process.
	# Note: this fd trickery doesn't work on Windows, but there is no
	# need to, because on Win the auto gc always runs in the foreground.
	doesnt_matter=$(shit gc --auto 9>&1)
}

test_expect_success 'background auto gc does not run if gc.log is present and recent but does if it is old' '
	test_commit foo &&
	test_commit bar &&
	shit repack &&
	test_config gc.autopacklimit 1 &&
	test_config gc.autodetach true &&
	echo fleem >.shit/gc.log &&
	shit gc --auto 2>err &&
	test_grep "^warning:" err &&
	test_config gc.logexpiry 5.days &&
	test-tool chmtime =-345600 .shit/gc.log &&
	shit gc --auto &&
	test_config gc.logexpiry 2.days &&
	run_and_wait_for_auto_gc &&
	ls .shit/objects/pack/pack-*.pack >packs &&
	test_line_count = 1 packs
'

test_expect_success 'background auto gc respects lock for all operations' '
	# make sure we run a background auto-gc
	test_commit make-pack &&
	shit repack &&
	test_config gc.autopacklimit 1 &&
	test_config gc.autodetach true &&

	# create a ref whose loose presence we can use to detect a pack-refs run
	shit update-ref refs/heads/should-be-loose HEAD &&
	(ls -1 .shit/refs/heads .shit/reftable >expect || true) &&

	# now fake a concurrent gc that holds the lock; we can use our
	# shell pid so that it looks valid.
	hostname=$(hostname || echo unknown) &&
	shell_pid=$$ &&
	if test_have_prereq MINGW && test -f /proc/$shell_pid/winpid
	then
		# In shit for Windows, Bash (actually, the MSYS2 runtime) has a
		# different idea of PIDs than shit.exe (actually Windows). Use
		# the Windows PID in this case.
		shell_pid=$(cat /proc/$shell_pid/winpid)
	fi &&
	printf "%d %s" "$shell_pid" "$hostname" >.shit/gc.pid &&

	# our gc should exit zero without doing anything
	run_and_wait_for_auto_gc &&
	(ls -1 .shit/refs/heads .shit/reftable >actual || true) &&
	test_cmp expect actual
'

# DO NOT leave a detached auto gc process running near the end of the
# test script: it can run long enough in the background to racily
# interfere with the cleanup in 'test_done'.

test_done
