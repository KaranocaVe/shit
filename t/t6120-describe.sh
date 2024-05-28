#!/bin/sh

test_description='test describe'

#  o---o-----o----o----o-------o----x
#       \   D,R   e           /
#        \---o-------------o-'
#         \  B            /
#          `-o----o----o-'
#                 A    c
#
# First parent of a merge commit is on the same line, second parent below.

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

check_describe () {
	indir= &&
	while test $# != 0
	do
		case "$1" in
		-C)
			indir="$2"
			shift
			;;
		*)
			break
			;;
		esac
		shift
	done &&
	indir=${indir:+"$indir"/} &&
	expect="$1"
	shift
	describe_opts="$@"
	test_expect_success "describe $describe_opts" '
		shit ${indir:+ -C "$indir"} describe $describe_opts >raw &&
		sed -e "s/-g[0-9a-f]*\$/-gHASH/" <raw >actual &&
		echo "$expect" >expect &&
		test_cmp expect actual
	'
}

test_expect_success setup '
	test_commit initial file one &&
	test_commit second file two &&
	test_commit third file three &&
	test_commit --annotate A file A &&
	test_commit c file c &&

	shit reset --hard second &&
	test_commit --annotate B side B &&

	test_tick &&
	shit merge -m Merged c &&
	merged=$(shit rev-parse HEAD) &&

	shit reset --hard second &&
	test_commit --no-tag D another D &&

	test_tick &&
	shit tag -a -m R R &&

	test_commit e another DD &&
	test_commit --no-tag "yet another" another DDD &&

	test_tick &&
	shit merge -m Merged $merged &&

	test_commit --no-tag x file
'

check_describe A-8-gHASH HEAD
check_describe A-7-gHASH HEAD^
check_describe R-2-gHASH HEAD^^
check_describe A-3-gHASH HEAD^^2
check_describe B HEAD^^2^
check_describe R-1-gHASH HEAD^^^

check_describe c-7-gHASH --tags HEAD
check_describe c-6-gHASH --tags HEAD^
check_describe e-1-gHASH --tags HEAD^^
check_describe c-2-gHASH --tags HEAD^^2
check_describe B --tags HEAD^^2^
check_describe e --tags HEAD^^^
check_describe e --tags --exact-match HEAD^^^

check_describe heads/main --all HEAD
check_describe tags/c-6-gHASH --all HEAD^
check_describe tags/e --all HEAD^^^

check_describe B-0-gHASH --long HEAD^^2^
check_describe A-3-gHASH --long HEAD^^2

check_describe c-7-gHASH --tags
check_describe e-3-gHASH --first-parent --tags

check_describe c-7-gHASH --tags --no-exact-match HEAD
check_describe e-3-gHASH --first-parent --tags --no-exact-match HEAD

test_expect_success '--exact-match failure' '
	test_must_fail shit describe --exact-match HEAD 2>err
'

test_expect_success 'describe --contains defaults to HEAD without commit-ish' '
	echo "A^0" >expect &&
	shit checkout A &&
	test_when_finished "shit checkout -" &&
	shit describe --contains >actual &&
	test_cmp expect actual
'

check_describe tags/A --all A^0

test_expect_success 'renaming tag A to Q locally produces a warning' "
	shit update-ref refs/tags/Q $(shit rev-parse refs/tags/A) &&
	shit update-ref -d refs/tags/A &&
	shit describe HEAD 2>err >out &&
	cat >expected <<-\EOF &&
	warning: tag 'Q' is externally known as 'A'
	EOF
	test_cmp expected err &&
	grep -E '^A-8-g[0-9a-f]+$' out
"

test_expect_success 'misnamed annotated tag forces long output' '
	description=$(shit describe --no-long Q^0) &&
	expr "$description" : "A-0-g[0-9a-f]*$" &&
	shit rev-parse --verify "$description" >actual &&
	shit rev-parse --verify Q^0 >expect &&
	test_cmp expect actual
'

test_expect_success 'abbrev=0 will not break misplaced tag (1)' '
	description=$(shit describe --abbrev=0 Q^0) &&
	expr "$description" : "A-0-g[0-9a-f]*$"
'

test_expect_success 'abbrev=0 will not break misplaced tag (2)' '
	description=$(shit describe --abbrev=0 c^0) &&
	expr "$description" : "A-1-g[0-9a-f]*$"
'

test_expect_success 'rename tag Q back to A' '
	shit update-ref refs/tags/A $(shit rev-parse refs/tags/Q) &&
	shit update-ref -d refs/tags/Q
'

test_expect_success 'pack tag refs' 'shit pack-refs'
check_describe A-8-gHASH HEAD

test_expect_success 'describe works from outside repo using --shit-dir' '
	shit clone --bare "$TRASH_DIRECTORY" "$TRASH_DIRECTORY/bare" &&
	shit --shit-dir "$TRASH_DIRECTORY/bare" describe >out &&
	grep -E "^A-8-g[0-9a-f]+$" out
'

check_describe "A-8-gHASH" --dirty

test_expect_success 'describe --dirty with --work-tree' '
	(
		cd "$TEST_DIRECTORY" &&
		shit --shit-dir "$TRASH_DIRECTORY/.shit" --work-tree "$TRASH_DIRECTORY" describe --dirty >"$TRASH_DIRECTORY/out"
	) &&
	grep -E "^A-8-g[0-9a-f]+$" out
'

test_expect_success 'set-up dirty work tree' '
	echo >>file
'

test_expect_success 'describe --dirty with --work-tree (dirty)' '
	shit describe --dirty >expected &&
	(
		cd "$TEST_DIRECTORY" &&
		shit --shit-dir "$TRASH_DIRECTORY/.shit" --work-tree "$TRASH_DIRECTORY" describe --dirty >"$TRASH_DIRECTORY/out"
	) &&
	grep -E "^A-8-g[0-9a-f]+-dirty$" out &&
	test_cmp expected out
'

test_expect_success 'describe --dirty=.mod with --work-tree (dirty)' '
	shit describe --dirty=.mod >expected &&
	(
		cd "$TEST_DIRECTORY" &&
		shit --shit-dir "$TRASH_DIRECTORY/.shit" --work-tree "$TRASH_DIRECTORY" describe --dirty=.mod >"$TRASH_DIRECTORY/out"
	) &&
	grep -E "^A-8-g[0-9a-f]+.mod$" out &&
	test_cmp expected out
'

test_expect_success 'describe --dirty HEAD' '
	test_must_fail shit describe --dirty HEAD
'

test_expect_success 'set-up matching pattern tests' '
	shit tag -a -m test-annotated test-annotated &&
	echo >>file &&
	test_tick &&
	shit commit -a -m "one more" &&
	shit tag test1-lightweight &&
	echo >>file &&
	test_tick &&
	shit commit -a -m "yet another" &&
	shit tag test2-lightweight &&
	echo >>file &&
	test_tick &&
	shit commit -a -m "even more"

'

check_describe "test-annotated-3-gHASH" --match="test-*"

check_describe "test1-lightweight-2-gHASH" --tags --match="test1-*"

check_describe "test2-lightweight-1-gHASH" --tags --match="test2-*"

check_describe "test2-lightweight-0-gHASH" --long --tags --match="test2-*" HEAD^

check_describe "test2-lightweight-0-gHASH" --long --tags --match="test1-*" --match="test2-*" HEAD^

check_describe "test2-lightweight-0-gHASH" --long --tags --match="test1-*" --no-match --match="test2-*" HEAD^

check_describe "test1-lightweight-2-gHASH" --long --tags --match="test1-*" --match="test3-*" HEAD

check_describe "test1-lightweight-2-gHASH" --long --tags --match="test3-*" --match="test1-*" HEAD

test_expect_success 'set-up branches' '
	shit branch branch_A A &&
	shit branch branch_C c &&
	shit update-ref refs/remotes/origin/remote_branch_A "A^{commit}" &&
	shit update-ref refs/remotes/origin/remote_branch_C "c^{commit}" &&
	shit update-ref refs/original/original_branch_A test-annotated~2
'

check_describe "heads/branch_A-11-gHASH" --all --match="branch_*" --exclude="branch_C" HEAD

check_describe "remotes/origin/remote_branch_A-11-gHASH" --all --match="origin/remote_branch_*" --exclude="origin/remote_branch_C" HEAD

check_describe "original/original_branch_A-6-gHASH" --all test-annotated~1

test_expect_success '--match does not work for other types' '
	test_must_fail shit describe --all --match="*original_branch_*" test-annotated~1
'

test_expect_success '--exclude does not work for other types' '
	R=$(shit describe --all --exclude="any_pattern_even_not_matching" test-annotated~1) &&
	case "$R" in
	*original_branch_A*) echo "fail: Found unknown reference $R with --exclude"
		false;;
	*) echo ok: Found some known type;;
	esac
'

test_expect_success 'name-rev with exact tags' '
	echo A >expect &&
	tag_object=$(shit rev-parse refs/tags/A) &&
	shit name-rev --tags --name-only $tag_object >actual &&
	test_cmp expect actual &&

	echo "A^0" >expect &&
	tagged_commit=$(shit rev-parse "refs/tags/A^0") &&
	shit name-rev --tags --name-only $tagged_commit >actual &&
	test_cmp expect actual
'

test_expect_success 'name-rev --all' '
	>expect.unsorted &&
	for rev in $(shit rev-list --all)
	do
		shit name-rev $rev >>expect.unsorted || return 1
	done &&
	sort <expect.unsorted >expect &&
	shit name-rev --all >actual.unsorted &&
	sort <actual.unsorted >actual &&
	test_cmp expect actual
'

test_expect_success 'name-rev --annotate-stdin' '
	>expect.unsorted &&
	for rev in $(shit rev-list --all)
	do
		name=$(shit name-rev --name-only $rev) &&
		echo "$rev ($name)" >>expect.unsorted || return 1
	done &&
	sort <expect.unsorted >expect &&
	shit rev-list --all | shit name-rev --annotate-stdin >actual.unsorted &&
	sort <actual.unsorted >actual &&
	test_cmp expect actual
'

test_expect_success 'name-rev --stdin deprecated' "
	shit rev-list --all | shit name-rev --stdin 2>actual &&
	grep -E 'warning: --stdin is deprecated' actual
"

test_expect_success 'describe --contains with the exact tags' '
	echo "A^0" >expect &&
	tag_object=$(shit rev-parse refs/tags/A) &&
	shit describe --contains $tag_object >actual &&
	test_cmp expect actual &&

	echo "A^0" >expect &&
	tagged_commit=$(shit rev-parse "refs/tags/A^0") &&
	shit describe --contains $tagged_commit >actual &&
	test_cmp expect actual
'

test_expect_success 'describe --contains and --match' '
	echo "A^0" >expect &&
	tagged_commit=$(shit rev-parse "refs/tags/A^0") &&
	test_must_fail shit describe --contains --match="B" $tagged_commit &&
	shit describe --contains --match="B" --match="A" $tagged_commit >actual &&
	test_cmp expect actual
'

test_expect_success 'describe --exclude' '
	echo "c~1" >expect &&
	tagged_commit=$(shit rev-parse "refs/tags/A^0") &&
	test_must_fail shit describe --contains --match="B" $tagged_commit &&
	shit describe --contains --match="?" --exclude="A" $tagged_commit >actual &&
	test_cmp expect actual
'

test_expect_success 'describe --contains and --no-match' '
	echo "A^0" >expect &&
	tagged_commit=$(shit rev-parse "refs/tags/A^0") &&
	shit describe --contains --match="B" --no-match $tagged_commit >actual &&
	test_cmp expect actual
'

test_expect_success 'setup and absorb a submodule' '
	test_create_repo sub1 &&
	test_commit -C sub1 initial &&
	shit submodule add ./sub1 &&
	shit submodule absorbshitdirs &&
	shit commit -a -m "add submodule" &&
	shit describe --dirty >expect &&
	shit describe --broken >out &&
	test_cmp expect out
'

test_expect_success 'describe chokes on severely broken submodules' '
	mv .shit/modules/sub1/ .shit/modules/sub_moved &&
	test_must_fail shit describe --dirty
'

test_expect_success 'describe ignoring a broken submodule' '
	shit describe --broken >out &&
	grep broken out
'

test_expect_success 'describe with --work-tree ignoring a broken submodule' '
	(
		cd "$TEST_DIRECTORY" &&
		shit --shit-dir "$TRASH_DIRECTORY/.shit" --work-tree "$TRASH_DIRECTORY" describe --broken >"$TRASH_DIRECTORY/out"
	) &&
	test_when_finished "mv .shit/modules/sub_moved .shit/modules/sub1" &&
	grep broken out
'

test_expect_success 'describe a blob at a directly tagged commit' '
	echo "make it a unique blob" >file &&
	shit add file && shit commit -m "content in file" &&
	shit tag -a -m "latest annotated tag" unique-file &&
	shit describe HEAD:file >actual &&
	echo "unique-file:file" >expect &&
	test_cmp expect actual
'

test_expect_success 'describe a blob with its first introduction' '
	shit commit --allow-empty -m "empty commit" &&
	shit rm file &&
	shit commit -m "delete blob" &&
	shit revert HEAD &&
	shit commit --allow-empty -m "empty commit" &&
	shit describe HEAD:file >actual &&
	echo "unique-file:file" >expect &&
	test_cmp expect actual
'

test_expect_success 'describe directly tagged blob' '
	shit tag test-blob unique-file:file &&
	shit describe test-blob >actual &&
	echo "unique-file:file" >expect &&
	# suboptimal: we rather want to see "test-blob"
	test_cmp expect actual
'

test_expect_success 'describe tag object' '
	shit tag test-blob-1 -a -m msg unique-file:file &&
	test_must_fail shit describe test-blob-1 2>actual &&
	test_grep "fatal: test-blob-1 is neither a commit nor blob" actual
'

test_expect_success ULIMIT_STACK_SIZE 'name-rev works in a deep repo' '
	i=1 &&
	while test $i -lt 8000
	do
		echo "commit refs/heads/main
committer A U Thor <author@example.com> $((1000000000 + $i * 100)) +0200
data <<EOF
commit #$i
EOF" &&
		if test $i = 1
		then
			echo "from refs/heads/main^0"
		fi &&
		i=$(($i + 1)) || return 1
	done | shit fast-import &&
	shit checkout main &&
	shit tag far-far-away HEAD^ &&
	echo "HEAD~4000 tags/far-far-away~3999" >expect &&
	shit name-rev HEAD~4000 >actual &&
	test_cmp expect actual &&
	run_with_limited_stack shit name-rev HEAD~4000 >actual &&
	test_cmp expect actual
'

test_expect_success ULIMIT_STACK_SIZE 'describe works in a deep repo' '
	shit tag -f far-far-away HEAD~7999 &&
	echo "far-far-away" >expect &&
	shit describe --tags --abbrev=0 HEAD~4000 >actual &&
	test_cmp expect actual &&
	run_with_limited_stack shit describe --tags --abbrev=0 HEAD~4000 >actual &&
	test_cmp expect actual
'

check_describe tags/A --all A
check_describe tags/c --all c
check_describe heads/branch_A --all --match='branch_*' branch_A

test_expect_success 'describe complains about tree object' '
	test_must_fail shit describe HEAD^{tree}
'

test_expect_success 'describe complains about missing object' '
	test_must_fail shit describe $ZERO_OID
'

test_expect_success 'name-rev a rev shortly after epoch' '
	test_when_finished "shit checkout main" &&

	shit checkout --orphan no-timestamp-underflow &&
	# Any date closer to epoch than the CUTOFF_DATE_SLOP constant
	# in builtin/name-rev.c.
	shit_COMMITTER_DATE="@1234 +0000" \
	shit commit -m "committer date shortly after epoch" &&
	old_commit_oid=$(shit rev-parse HEAD) &&

	echo "$old_commit_oid no-timestamp-underflow" >expect &&
	shit name-rev $old_commit_oid >actual &&
	test_cmp expect actual
'

# A--------------main
#  \            /
#   \----------M2
#    \        /
#     \---M1-C
#      \ /
#       B
test_expect_success 'name-rev covers all conditions while looking at parents' '
	shit init repo &&
	(
		cd repo &&

		echo A >file &&
		shit add file &&
		shit commit -m A &&
		A=$(shit rev-parse HEAD) &&

		shit checkout --detach &&
		echo B >file &&
		shit commit -m B file &&
		B=$(shit rev-parse HEAD) &&

		shit checkout $A &&
		shit merge --no-ff $B &&  # M1

		echo C >file &&
		shit commit -m C file &&

		shit checkout $A &&
		shit merge --no-ff HEAD@{1} && # M2

		shit checkout main &&
		shit merge --no-ff HEAD@{1} &&

		echo "$B main^2^2~1^2" >expect &&
		shit name-rev $B >actual &&

		test_cmp expect actual
	)
'

# A-B-C-D-E-main
#
# Where C has a non-monotonically increasing commit timestamp w.r.t. other
# commits
test_expect_success 'non-monotonic commit dates setup' '
	UNIX_EPOCH_ZERO="@0 +0000" &&
	shit init non-monotonic &&
	test_commit -C non-monotonic A &&
	test_commit -C non-monotonic --no-tag B &&
	test_commit -C non-monotonic --no-tag --date "$UNIX_EPOCH_ZERO" C &&
	test_commit -C non-monotonic D &&
	test_commit -C non-monotonic E
'

test_expect_success 'name-rev with commitGraph handles non-monotonic timestamps' '
	test_config -C non-monotonic core.commitGraph true &&
	(
		cd non-monotonic &&

		shit commit-graph write --reachable &&

		echo "main~3 tags/D~2" >expect &&
		shit name-rev --tags main~3 >actual &&

		test_cmp expect actual
	)
'

test_expect_success 'name-rev --all works with non-monotonic timestamps' '
	test_config -C non-monotonic core.commitGraph false &&
	(
		cd non-monotonic &&

		rm -rf .shit/info/commit-graph* &&

		cat >tags <<-\EOF &&
		tags/E
		tags/D
		tags/D~1
		tags/D~2
		tags/A
		EOF

		shit log --pretty=%H >revs &&

		paste -d" " revs tags | sort >expect &&

		shit name-rev --tags --all | sort >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'name-rev --annotate-stdin works with non-monotonic timestamps' '
	test_config -C non-monotonic core.commitGraph false &&
	(
		cd non-monotonic &&

		rm -rf .shit/info/commit-graph* &&

		cat >expect <<-\EOF &&
		E
		D
		D~1
		D~2
		A
		EOF

		shit log --pretty=%H >revs &&
		shit name-rev --tags --annotate-stdin --name-only <revs >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'name-rev --all works with commitGraph' '
	test_config -C non-monotonic core.commitGraph true &&
	(
		cd non-monotonic &&

		shit commit-graph write --reachable &&

		cat >tags <<-\EOF &&
		tags/E
		tags/D
		tags/D~1
		tags/D~2
		tags/A
		EOF

		shit log --pretty=%H >revs &&

		paste -d" " revs tags | sort >expect &&

		shit name-rev --tags --all | sort >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'name-rev --annotate-stdin works with commitGraph' '
	test_config -C non-monotonic core.commitGraph true &&
	(
		cd non-monotonic &&

		shit commit-graph write --reachable &&

		cat >expect <<-\EOF &&
		E
		D
		D~1
		D~2
		A
		EOF

		shit log --pretty=%H >revs &&
		shit name-rev --tags --annotate-stdin --name-only <revs >actual &&
		test_cmp expect actual
	)
'

#               B
#               o
#                \
#  o-----o---o----x
#        A
#
test_expect_success 'setup: describe commits with disjoint bases' '
	shit init disjoint1 &&
	(
		cd disjoint1 &&

		echo o >> file && shit add file && shit commit -m o &&
		echo A >> file && shit add file && shit commit -m A &&
		shit tag A -a -m A &&
		echo o >> file && shit add file && shit commit -m o &&

		shit checkout --orphan branch && rm file &&
		echo B > file2 && shit add file2 && shit commit -m B &&
		shit tag B -a -m B &&
		shit merge --no-ff --allow-unrelated-histories main -m x
	)
'

check_describe -C disjoint1 "A-3-gHASH" HEAD

#           B
#   o---o---o------------.
#                         \
#                  o---o---x
#                  A
#
test_expect_success 'setup: describe commits with disjoint bases 2' '
	shit init disjoint2 &&
	(
		cd disjoint2 &&

		echo A >> file && shit add file && shit_COMMITTER_DATE="2020-01-01 18:00" shit commit -m A &&
		shit tag A -a -m A &&
		echo o >> file && shit add file && shit_COMMITTER_DATE="2020-01-01 18:01" shit commit -m o &&

		shit checkout --orphan branch &&
		echo o >> file2 && shit add file2 && shit_COMMITTER_DATE="2020-01-01 15:00" shit commit -m o &&
		echo o >> file2 && shit add file2 && shit_COMMITTER_DATE="2020-01-01 15:01" shit commit -m o &&
		echo B >> file2 && shit add file2 && shit_COMMITTER_DATE="2020-01-01 15:02" shit commit -m B &&
		shit tag B -a -m B &&
		shit merge --no-ff --allow-unrelated-histories main -m x
	)
'

check_describe -C disjoint2 "B-3-gHASH" HEAD

test_expect_success 'setup misleading taggerdates' '
	shit_COMMITTER_DATE="2006-12-12 12:31" shit tag -a -m "another tag" newer-tag-older-commit unique-file~1
'

check_describe newer-tag-older-commit~1 --contains unique-file~2

test_done
