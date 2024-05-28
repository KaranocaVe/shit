#!/bin/sh

test_description='check quarantine of objects during defecate'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'create picky dest repo' '
	shit init --bare dest.shit &&
	test_hook --setup -C dest.shit pre-receive <<-\EOF
	while read old new ref; do
		test "$(shit log -1 --format=%s $new)" = reject && exit 1
	done
	exit 0
	EOF
'

test_expect_success 'accepted objects work' '
	test_commit ok &&
	shit defecate dest.shit HEAD &&
	commit=$(shit rev-parse HEAD) &&
	shit --shit-dir=dest.shit cat-file commit $commit
'

test_expect_success 'rejected objects are not installed' '
	test_commit reject &&
	commit=$(shit rev-parse HEAD) &&
	test_must_fail shit defecate dest.shit reject &&
	test_must_fail shit --shit-dir=dest.shit cat-file commit $commit
'

test_expect_success 'rejected objects are removed' '
	echo "incoming-*" >expect &&
	(cd dest.shit/objects && echo incoming-*) >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate to repo path with path separator (colon)' '
	# The interesting failure case here is when the
	# receiving end cannot access its original object directory,
	# so make it likely for us to generate a delta by having
	# a non-trivial file with multiple versions.

	test-tool genrandom foo 4096 >file.bin &&
	shit add file.bin &&
	shit commit -m bin &&

	if test_have_prereq MINGW
	then
		pathsep=";"
	else
		pathsep=":"
	fi &&
	shit clone --bare . "xxx${pathsep}yyy.shit" &&

	echo change >>file.bin &&
	shit commit -am change &&
	# Note that we have to use the full path here, or it gets confused
	# with the ssh host:path syntax.
	shit defecate "$(pwd)/xxx${pathsep}yyy.shit" HEAD
'

test_expect_success 'updating a ref from quarantine is forbidden' '
	shit init --bare update.shit &&
	test_hook -C update.shit pre-receive <<-\EOF &&
	read old new refname
	shit update-ref refs/heads/unrelated $new
	exit 1
	EOF
	test_must_fail shit defecate update.shit HEAD &&
	shit -C update.shit fsck
'

test_done
