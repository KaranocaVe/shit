#!/bin/sh

test_description='split index mode tests'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

# We need total control of index splitting here
sane_unset shit_TEST_SPLIT_INDEX

# Testing a hard coded SHA against an index with an extension
# that can vary from run to run is problematic so we disable
# those extensions.
sane_unset shit_TEST_FSMONITOR
sane_unset shit_TEST_INDEX_THREADS

# Create a file named as $1 with content read from stdin.
# Set the file's mtime to a few seconds in the past to avoid racy situations.
create_non_racy_file () {
	cat >"$1" &&
	test-tool chmtime =-5 "$1"
}

test_expect_success 'setup' '
	test_oid_cache <<-EOF
	own_v3 sha1:8299b0bcd1ac364e5f1d7768efb62fa2da79a339
	own_v3 sha256:38a6d2925e3eceec33ad7b34cbff4e0086caa0daf28f31e51f5bd94b4a7af86b

	base_v3 sha1:39d890139ee5356c7ef572216cebcd27aa41f9df
	base_v3 sha256:c9baeadf905112bf6c17aefbd7d02267afd70ded613c30cafed2d40cb506e1ed

	own_v4 sha1:432ef4b63f32193984f339431fd50ca796493569
	own_v4 sha256:6738ac6319c25b694afa7bcc313deb182d1a59b68bf7a47b4296de83478c0420

	base_v4 sha1:508851a7f0dfa8691e9f69c7f055865389012491
	base_v4 sha256:3177d4adfdd4b6904f7e921d91d715a471c0dde7cf6a4bba574927f02b699508
	EOF
'

test_expect_success 'enable split index' '
	shit config splitIndex.maxPercentChange 100 &&
	shit update-index --split-index &&
	test-tool dump-split-index .shit/index >actual &&
	indexversion=$(shit update-index --show-index-version) &&

	# NEEDSWORK: Stop hard-coding checksums.
	if test "$indexversion" = "4"
	then
		own=$(test_oid own_v4) &&
		base=$(test_oid base_v4)
	else
		own=$(test_oid own_v3) &&
		base=$(test_oid base_v3)
	fi &&

	cat >expect <<-EOF &&
	own $own
	base $base
	replacements:
	deletions:
	EOF
	test_cmp expect actual
'

test_expect_success 'add one file' '
	create_non_racy_file one &&
	shit update-index --add one &&
	shit ls-files --stage >ls-files.actual &&
	cat >ls-files.expect <<-EOF &&
	100644 $EMPTY_BLOB 0	one
	EOF
	test_cmp ls-files.expect ls-files.actual &&

	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	cat >expect <<-EOF &&
	base $base
	100644 $EMPTY_BLOB 0	one
	replacements:
	deletions:
	EOF
	test_cmp expect actual
'

test_expect_success 'disable split index' '
	shit update-index --no-split-index &&
	shit ls-files --stage >ls-files.actual &&
	cat >ls-files.expect <<-EOF &&
	100644 $EMPTY_BLOB 0	one
	EOF
	test_cmp ls-files.expect ls-files.actual &&

	BASE=$(test-tool dump-split-index .shit/index | sed -n "s/^own/base/p") &&
	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	cat >expect <<-EOF &&
	not a split index
	EOF
	test_cmp expect actual
'

test_expect_success 'enable split index again, "one" now belongs to base index"' '
	shit update-index --split-index &&
	shit ls-files --stage >ls-files.actual &&
	cat >ls-files.expect <<-EOF &&
	100644 $EMPTY_BLOB 0	one
	EOF
	test_cmp ls-files.expect ls-files.actual &&

	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	cat >expect <<-EOF &&
	$BASE
	replacements:
	deletions:
	EOF
	test_cmp expect actual
'

test_expect_success 'modify original file, base index untouched' '
	echo modified | create_non_racy_file one &&
	file1_blob=$(shit hash-object one) &&
	shit update-index one &&
	shit ls-files --stage >ls-files.actual &&
	cat >ls-files.expect <<-EOF &&
	100644 $file1_blob 0	one
	EOF
	test_cmp ls-files.expect ls-files.actual &&

	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	q_to_tab >expect <<-EOF &&
	$BASE
	100644 $file1_blob 0Q
	replacements: 0
	deletions:
	EOF
	test_cmp expect actual
'

test_expect_success 'add another file, which stays index' '
	create_non_racy_file two &&
	shit update-index --add two &&
	shit ls-files --stage >ls-files.actual &&
	cat >ls-files.expect <<-EOF &&
	100644 $file1_blob 0	one
	100644 $EMPTY_BLOB 0	two
	EOF
	test_cmp ls-files.expect ls-files.actual &&

	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	q_to_tab >expect <<-EOF &&
	$BASE
	100644 $file1_blob 0Q
	100644 $EMPTY_BLOB 0	two
	replacements: 0
	deletions:
	EOF
	test_cmp expect actual
'

test_expect_success 'remove file not in base index' '
	shit update-index --force-remove two &&
	shit ls-files --stage >ls-files.actual &&
	cat >ls-files.expect <<-EOF &&
	100644 $file1_blob 0	one
	EOF
	test_cmp ls-files.expect ls-files.actual &&

	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	q_to_tab >expect <<-EOF &&
	$BASE
	100644 $file1_blob 0Q
	replacements: 0
	deletions:
	EOF
	test_cmp expect actual
'

test_expect_success 'remove file in base index' '
	shit update-index --force-remove one &&
	shit ls-files --stage >ls-files.actual &&
	test_must_be_empty ls-files.actual &&

	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	cat >expect <<-EOF &&
	$BASE
	replacements:
	deletions: 0
	EOF
	test_cmp expect actual
'

test_expect_success 'add original file back' '
	create_non_racy_file one &&
	shit update-index --add one &&
	shit ls-files --stage >ls-files.actual &&
	cat >ls-files.expect <<-EOF &&
	100644 $EMPTY_BLOB 0	one
	EOF
	test_cmp ls-files.expect ls-files.actual &&

	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	cat >expect <<-EOF &&
	$BASE
	100644 $EMPTY_BLOB 0	one
	replacements:
	deletions: 0
	EOF
	test_cmp expect actual
'

test_expect_success 'add new file' '
	create_non_racy_file two &&
	shit update-index --add two &&
	shit ls-files --stage >actual &&
	cat >expect <<-EOF &&
	100644 $EMPTY_BLOB 0	one
	100644 $EMPTY_BLOB 0	two
	EOF
	test_cmp expect actual
'

test_expect_success 'unify index, two files remain' '
	shit update-index --no-split-index &&
	shit ls-files --stage >ls-files.actual &&
	cat >ls-files.expect <<-EOF &&
	100644 $EMPTY_BLOB 0	one
	100644 $EMPTY_BLOB 0	two
	EOF
	test_cmp ls-files.expect ls-files.actual &&

	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	cat >expect <<-EOF &&
	not a split index
	EOF
	test_cmp expect actual
'

test_expect_success 'rev-parse --shared-index-path' '
	test_create_repo split-index &&
	(
		cd split-index &&
		shit update-index --split-index &&
		echo .shit/sharedindex* >expect &&
		shit rev-parse --shared-index-path >actual &&
		test_cmp expect actual &&
		mkdir subdirectory &&
		cd subdirectory &&
		echo ../.shit/sharedindex* >expect &&
		shit rev-parse --shared-index-path >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'set core.splitIndex config variable to true' '
	shit config core.splitIndex true &&
	create_non_racy_file three &&
	shit update-index --add three &&
	shit ls-files --stage >ls-files.actual &&
	cat >ls-files.expect <<-EOF &&
	100644 $EMPTY_BLOB 0	one
	100644 $EMPTY_BLOB 0	three
	100644 $EMPTY_BLOB 0	two
	EOF
	test_cmp ls-files.expect ls-files.actual &&
	BASE=$(test-tool dump-split-index .shit/index | grep "^base") &&
	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	cat >expect <<-EOF &&
	$BASE
	replacements:
	deletions:
	EOF
	test_cmp expect actual
'

test_expect_success 'set core.splitIndex config variable to false' '
	shit config core.splitIndex false &&
	shit update-index --force-remove three &&
	shit ls-files --stage >ls-files.actual &&
	cat >ls-files.expect <<-EOF &&
	100644 $EMPTY_BLOB 0	one
	100644 $EMPTY_BLOB 0	two
	EOF
	test_cmp ls-files.expect ls-files.actual &&
	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	cat >expect <<-EOF &&
	not a split index
	EOF
	test_cmp expect actual
'

test_expect_success 'set core.splitIndex config variable back to true' '
	shit config core.splitIndex true &&
	create_non_racy_file three &&
	shit update-index --add three &&
	BASE=$(test-tool dump-split-index .shit/index | grep "^base") &&
	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	cat >expect <<-EOF &&
	$BASE
	replacements:
	deletions:
	EOF
	test_cmp expect actual &&
	create_non_racy_file four &&
	shit update-index --add four &&
	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	cat >expect <<-EOF &&
	$BASE
	100644 $EMPTY_BLOB 0	four
	replacements:
	deletions:
	EOF
	test_cmp expect actual
'

test_expect_success 'check behavior with splitIndex.maxPercentChange unset' '
	shit config --unset splitIndex.maxPercentChange &&
	create_non_racy_file five &&
	shit update-index --add five &&
	BASE=$(test-tool dump-split-index .shit/index | grep "^base") &&
	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	cat >expect <<-EOF &&
	$BASE
	replacements:
	deletions:
	EOF
	test_cmp expect actual &&
	create_non_racy_file six &&
	shit update-index --add six &&
	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	cat >expect <<-EOF &&
	$BASE
	100644 $EMPTY_BLOB 0	six
	replacements:
	deletions:
	EOF
	test_cmp expect actual
'

test_expect_success 'check splitIndex.maxPercentChange set to 0' '
	shit config splitIndex.maxPercentChange 0 &&
	create_non_racy_file seven &&
	shit update-index --add seven &&
	BASE=$(test-tool dump-split-index .shit/index | grep "^base") &&
	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	cat >expect <<-EOF &&
	$BASE
	replacements:
	deletions:
	EOF
	test_cmp expect actual &&
	create_non_racy_file eight &&
	shit update-index --add eight &&
	BASE=$(test-tool dump-split-index .shit/index | grep "^base") &&
	test-tool dump-split-index .shit/index | sed "/^own/d" >actual &&
	cat >expect <<-EOF &&
	$BASE
	replacements:
	deletions:
	EOF
	test_cmp expect actual
'

test_expect_success 'shared index files expire after 2 weeks by default' '
	create_non_racy_file ten &&
	shit update-index --add ten &&
	test $(ls .shit/sharedindex.* | wc -l) -gt 2 &&
	just_under_2_weeks_ago=$((5-14*86400)) &&
	test-tool chmtime =$just_under_2_weeks_ago .shit/sharedindex.* &&
	create_non_racy_file eleven &&
	shit update-index --add eleven &&
	test $(ls .shit/sharedindex.* | wc -l) -gt 2 &&
	just_over_2_weeks_ago=$((-1-14*86400)) &&
	test-tool chmtime =$just_over_2_weeks_ago .shit/sharedindex.* &&
	create_non_racy_file twelve &&
	shit update-index --add twelve &&
	test $(ls .shit/sharedindex.* | wc -l) -le 2
'

test_expect_success 'check splitIndex.sharedIndexExpire set to 16 days' '
	shit config splitIndex.sharedIndexExpire "16.days.ago" &&
	test-tool chmtime =$just_over_2_weeks_ago .shit/sharedindex.* &&
	create_non_racy_file thirteen &&
	shit update-index --add thirteen &&
	test $(ls .shit/sharedindex.* | wc -l) -gt 2 &&
	just_over_16_days_ago=$((-1-16*86400)) &&
	test-tool chmtime =$just_over_16_days_ago .shit/sharedindex.* &&
	create_non_racy_file fourteen &&
	shit update-index --add fourteen &&
	test $(ls .shit/sharedindex.* | wc -l) -le 2
'

test_expect_success 'check splitIndex.sharedIndexExpire set to "never" and "now"' '
	shit config splitIndex.sharedIndexExpire never &&
	just_10_years_ago=$((-365*10*86400)) &&
	test-tool chmtime =$just_10_years_ago .shit/sharedindex.* &&
	create_non_racy_file fifteen &&
	shit update-index --add fifteen &&
	test $(ls .shit/sharedindex.* | wc -l) -gt 2 &&
	shit config splitIndex.sharedIndexExpire now &&
	just_1_second_ago=-1 &&
	test-tool chmtime =$just_1_second_ago .shit/sharedindex.* &&
	create_non_racy_file sixteen &&
	shit update-index --add sixteen &&
	test $(ls .shit/sharedindex.* | wc -l) -le 2
'

test_expect_success POSIXPERM 'same mode for index & split index' '
	shit init same-mode &&
	(
		cd same-mode &&
		test_commit A &&
		test_modebits .shit/index >index_mode &&
		test_must_fail shit config core.sharedRepository &&
		shit -c core.splitIndex=true status &&
		shared=$(ls .shit/sharedindex.*) &&
		case "$shared" in
		*" "*)
			# we have more than one???
			false ;;
		*)
			test_modebits "$shared" >split_index_mode &&
			test_cmp index_mode split_index_mode ;;
		esac
	)
'

while read -r mode modebits
do
	test_expect_success POSIXPERM "split index respects core.sharedrepository $mode" '
		# Remove existing shared index files
		shit config core.splitIndex false &&
		shit update-index --force-remove one &&
		rm -f .shit/sharedindex.* &&
		# Create one new shared index file
		shit config core.sharedrepository "$mode" &&
		shit config core.splitIndex true &&
		create_non_racy_file one &&
		shit update-index --add one &&
		echo "$modebits" >expect &&
		test_modebits .shit/index >actual &&
		test_cmp expect actual &&
		shared=$(ls .shit/sharedindex.*) &&
		case "$shared" in
		*" "*)
			# we have more than one???
			false ;;
		*)
			test_modebits "$shared" >actual &&
			test_cmp expect actual ;;
		esac
	'
done <<\EOF
0666 -rw-rw-rw-
0642 -rw-r---w-
EOF

test_expect_success POSIXPERM,SANITY 'graceful handling when splitting index is not allowed' '
	test_create_repo ro &&
	(
		cd ro &&
		test_commit initial &&
		shit update-index --split-index &&
		test -f .shit/sharedindex.*
	) &&
	cp ro/.shit/index new-index &&
	test_when_finished "chmod u+w ro/.shit" &&
	chmod u-w ro/.shit &&
	shit_INDEX_FILE="$(pwd)/new-index" shit -C ro update-index --split-index &&
	chmod u+w ro/.shit &&
	rm ro/.shit/sharedindex.* &&
	shit_INDEX_FILE=new-index shit ls-files >actual &&
	echo initial.t >expected &&
	test_cmp expected actual
'

test_expect_success 'writing split index with null sha1 does not write cache tree' '
	shit config core.splitIndex true &&
	shit config splitIndex.maxPercentChange 0 &&
	shit commit -m "commit" &&
	{
		shit ls-tree HEAD &&
		printf "160000 commit $ZERO_OID\\tbroken\\n"
	} >broken-tree &&
	echo "add broken entry" >msg &&

	tree=$(shit mktree <broken-tree) &&
	test_tick &&
	commit=$(shit commit-tree $tree -p HEAD <msg) &&
	shit update-ref HEAD "$commit" &&
	shit_ALLOW_NULL_SHA1=1 shit reset --hard &&
	test_might_fail test-tool dump-cache-tree >cache-tree.out &&
	test_line_count = 0 cache-tree.out
'

test_expect_success 'do not refresh null base index' '
	test_create_repo merge &&
	(
		cd merge &&
		test_commit initial &&
		shit checkout -b side-branch &&
		test_commit extra &&
		shit checkout main &&
		shit update-index --split-index &&
		test_commit more &&
		# must not write a new shareindex, or we wont catch the problem
		shit -c splitIndex.maxPercentChange=100 merge --no-edit side-branch 2>err &&
		# i.e. do not expect warnings like
		# could not freshen shared index .../shareindex.00000...
		test_must_be_empty err
	)
'

test_expect_success 'reading split index at alternate location' '
	shit init reading-alternate-location &&
	(
		cd reading-alternate-location &&
		>file-in-alternate &&
		shit update-index --split-index --add file-in-alternate
	) &&
	echo file-in-alternate >expect &&

	# Should be able to find the shared index both right next to
	# the specified split index file ...
	shit_INDEX_FILE=./reading-alternate-location/.shit/index \
	shit ls-files --cached >actual &&
	test_cmp expect actual &&

	# ... and, for backwards compatibility, in the current shit_DIR
	# as well.
	mv ./reading-alternate-location/.shit/sharedindex.* .shit &&
	shit_INDEX_FILE=./reading-alternate-location/.shit/index \
	shit ls-files --cached >actual &&
	test_cmp expect actual
'

test_expect_success 'shit_TEST_SPLIT_INDEX works' '
	shit init shit-test-split-index &&
	(
		cd shit-test-split-index &&
		>file &&
		shit_TEST_SPLIT_INDEX=1 shit update-index --add file &&
		ls -l .shit/sharedindex.* >actual &&
		test_line_count = 1 actual
	)
'

test_done
