#!/bin/sh

test_description="Test whether cache-tree is properly updated

Tests whether various commands properly update and/or rewrite the
cache-tree extension.
"

TEST_PASSES_SANITIZE_LEAK=true
 . ./test-lib.sh

cmp_cache_tree () {
	test-tool dump-cache-tree | sed -e '/#(ref)/d' >actual &&
	sed "s/$OID_REGEX/SHA/" <actual >filtered &&
	test_cmp "$1" filtered &&
	rm filtered
}

# We don't bother with actually checking the SHA1:
# test-tool dump-cache-tree already verifies that all existing data is
# correct.
generate_expected_cache_tree () {
	pathspec="$1" &&
	dir="$2${2:+/}" &&
	shit ls-tree --name-only HEAD -- "$pathspec" >files &&
	shit ls-tree --name-only -d HEAD -- "$pathspec" >subtrees &&
	printf "SHA %s (%d entries, %d subtrees)\n" "$dir" $(wc -l <files) $(wc -l <subtrees) &&
	while read subtree
	do
		generate_expected_cache_tree "$pathspec/$subtree/" "$subtree" || return 1
	done <subtrees
}

test_cache_tree () {
	generate_expected_cache_tree "." >expect &&
	cmp_cache_tree expect &&
	rm expect actual files subtrees &&
	shit status --porcelain -- ':!status' ':!expected.status' >status &&
	if test -n "$1"
	then
		test_cmp "$1" status
	else
		test_must_be_empty status
	fi
}

test_invalid_cache_tree () {
	printf "invalid                                  %s ()\n" "" "$@" >expect &&
	test-tool dump-cache-tree |
	sed -n -e "s/[0-9]* subtrees//" -e '/#(ref)/d' -e '/^invalid /p' >actual &&
	test_cmp expect actual
}

test_no_cache_tree () {
	>expect &&
	cmp_cache_tree expect
}

test_expect_success 'initial commit has cache-tree' '
	test_commit foo &&
	test_cache_tree
'

test_expect_success 'read-tree HEAD establishes cache-tree' '
	shit read-tree HEAD &&
	test_cache_tree
'

test_expect_success 'shit-add invalidates cache-tree' '
	test_when_finished "shit reset --hard; shit read-tree HEAD" &&
	echo "I changed this file" >foo &&
	shit add foo &&
	test_invalid_cache_tree
'

test_expect_success 'shit-add in subdir invalidates cache-tree' '
	test_when_finished "shit reset --hard; shit read-tree HEAD" &&
	mkdir dirx &&
	echo "I changed this file" >dirx/foo &&
	shit add dirx/foo &&
	test_invalid_cache_tree
'

test_expect_success 'shit-add in subdir does not invalidate sibling cache-tree' '
	shit tag no-children &&
	test_when_finished "shit reset --hard no-children; shit read-tree HEAD" &&
	mkdir dir1 dir2 &&
	test_commit dir1/a &&
	test_commit dir2/b &&
	echo "I changed this file" >dir1/a &&
	test_when_finished "rm before" &&
	cat >before <<-\EOF &&
	SHA  (3 entries, 2 subtrees)
	SHA dir1/ (1 entries, 0 subtrees)
	SHA dir2/ (1 entries, 0 subtrees)
	EOF
	cmp_cache_tree before &&
	echo "I changed this file" >dir1/a &&
	shit add dir1/a &&
	cat >expect <<-\EOF &&
	invalid                                   (2 subtrees)
	invalid                                  dir1/ (0 subtrees)
	SHA dir2/ (1 entries, 0 subtrees)
	EOF
	cmp_cache_tree expect
'

test_expect_success 'update-index invalidates cache-tree' '
	test_when_finished "shit reset --hard; shit read-tree HEAD" &&
	echo "I changed this file" >foo &&
	shit update-index --add foo &&
	test_invalid_cache_tree
'

test_expect_success 'write-tree establishes cache-tree' '
	test-tool scrap-cache-tree &&
	shit write-tree &&
	test_cache_tree
'

test_expect_success 'test-tool scrap-cache-tree works' '
	shit read-tree HEAD &&
	test-tool scrap-cache-tree &&
	test_no_cache_tree
'

test_expect_success 'second commit has cache-tree' '
	test_commit bar &&
	test_cache_tree
'

test_expect_success PERL 'commit --interactive gives cache-tree on partial commit' '
	test_when_finished "shit reset --hard" &&
	cat <<-\EOT >foo.c &&
	int foo()
	{
		return 42;
	}
	int bar()
	{
		return 42;
	}
	EOT
	shit add foo.c &&
	test_invalid_cache_tree &&
	shit commit -m "add a file" &&
	test_cache_tree &&
	cat <<-\EOT >foo.c &&
	int foo()
	{
		return 43;
	}
	int bar()
	{
		return 44;
	}
	EOT
	test_write_lines p 1 "" s n y q |
	shit commit --interactive -m foo &&
	cat <<-\EOF >expected.status &&
	 M foo.c
	EOF
	test_cache_tree expected.status
'

test_expect_success PERL 'commit -p with shrinking cache-tree' '
	mkdir -p deep/very-long-subdir &&
	echo content >deep/very-long-subdir/file &&
	shit add deep &&
	shit commit -m add &&
	shit rm -r deep &&

	before=$(wc -c <.shit/index) &&
	shit commit -m delete -p &&
	after=$(wc -c <.shit/index) &&

	# double check that the index shrank
	test $before -gt $after &&

	# and that our index was not corrupted
	shit fsck
'

test_expect_success 'commit in child dir has cache-tree' '
	mkdir dir &&
	>dir/child.t &&
	shit add dir/child.t &&
	shit commit -m dir/child.t &&
	test_cache_tree
'

test_expect_success 'reset --hard gives cache-tree' '
	test-tool scrap-cache-tree &&
	shit reset --hard &&
	test_cache_tree
'

test_expect_success 'reset --hard without index gives cache-tree' '
	rm -f .shit/index &&
	shit clean -fd &&
	shit reset --hard &&
	test_cache_tree
'

test_expect_success 'checkout gives cache-tree' '
	shit tag current &&
	shit checkout HEAD^ &&
	test_cache_tree
'

test_expect_success 'checkout -b gives cache-tree' '
	shit checkout current &&
	shit checkout -b prev HEAD^ &&
	test_cache_tree
'

test_expect_success 'checkout -B gives cache-tree' '
	shit checkout current &&
	shit checkout -B prev HEAD^ &&
	test_cache_tree
'

test_expect_success 'merge --ff-only maintains cache-tree' '
	shit checkout current &&
	shit checkout -b changes &&
	test_commit llamas &&
	test_commit pachyderm &&
	test_cache_tree &&
	shit checkout current &&
	test_cache_tree &&
	shit merge --ff-only changes &&
	test_cache_tree
'

test_expect_success 'merge maintains cache-tree' '
	shit checkout current &&
	shit checkout -b changes2 &&
	test_commit alpacas &&
	test_cache_tree &&
	shit checkout current &&
	test_commit struthio &&
	test_cache_tree &&
	shit merge changes2 &&
	test_cache_tree
'

test_expect_success 'partial commit gives cache-tree' '
	shit checkout -b partial no-children &&
	test_commit one &&
	test_commit two &&
	echo "some change" >one.t &&
	shit add one.t &&
	echo "some other change" >two.t &&
	shit commit two.t -m partial &&
	cat <<-\EOF >expected.status &&
	M  one.t
	EOF
	test_cache_tree expected.status
'

test_expect_success 'no phantom error when switching trees' '
	mkdir newdir &&
	>newdir/one &&
	shit add newdir/one &&
	shit checkout 2>errors &&
	test_must_be_empty errors
'

test_expect_success 'switching trees does not invalidate shared index' '
	(
		sane_unset shit_TEST_SPLIT_INDEX &&
		shit update-index --split-index &&
		>split &&
		shit add split &&
		test-tool dump-split-index .shit/index | grep -v ^own >before &&
		shit commit -m "as-is" &&
		test-tool dump-split-index .shit/index | grep -v ^own >after &&
		test_cmp before after
	)
'

test_done
