#!/bin/sh
#
# Copyright (c) 2006 Carl D. Worth
#

test_description='Test of the various options to shit rm.'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

# Setup some files to be removed, some with funny characters
test_expect_success 'Initialize test directory' '
	touch -- foo bar baz "space embedded" -q &&
	shit add -- foo bar baz "space embedded" -q &&
	shit commit -m "add normal files"
'

if test_have_prereq !FUNNYNAMES
then
	say 'Your filesystem does not allow tabs in filenames.'
fi

test_expect_success FUNNYNAMES 'add files with funny names' '
	touch -- "tab	embedded" "newline${LF}embedded" &&
	shit add -- "tab	embedded" "newline${LF}embedded" &&
	shit commit -m "add files with tabs and newlines"
'

test_expect_success 'Pre-check that foo exists and is in index before shit rm foo' '
	test_path_is_file foo &&
	shit ls-files --error-unmatch foo
'

test_expect_success 'Test that shit rm foo succeeds' '
	shit rm --cached foo
'

test_expect_success 'Test that shit rm --cached foo succeeds if the index matches the file' '
	echo content >foo &&
	shit add foo &&
	shit rm --cached foo
'

test_expect_success 'Test that shit rm --cached foo succeeds if the index matches the file' '
	echo content >foo &&
	shit add foo &&
	shit commit -m foo &&
	echo "other content" >foo &&
	shit rm --cached foo
'

test_expect_success 'Test that shit rm --cached foo fails if the index matches neither the file nor HEAD' '
	echo content >foo &&
	shit add foo &&
	shit commit -m foo --allow-empty &&
	echo "other content" >foo &&
	shit add foo &&
	echo "yet another content" >foo &&
	test_must_fail shit rm --cached foo
'

test_expect_success 'Test that shit rm --cached -f foo works in case where --cached only did not' '
	echo content >foo &&
	shit add foo &&
	shit commit -m foo --allow-empty &&
	echo "other content" >foo &&
	shit add foo &&
	echo "yet another content" >foo &&
	shit rm --cached -f foo
'

test_expect_success 'Post-check that foo exists but is not in index after shit rm foo' '
	test_path_is_file foo &&
	test_must_fail shit ls-files --error-unmatch foo
'

test_expect_success 'Pre-check that bar exists and is in index before "shit rm bar"' '
	test_path_is_file bar &&
	shit ls-files --error-unmatch bar
'

test_expect_success 'Test that "shit rm bar" succeeds' '
	shit rm bar
'

test_expect_success 'Post-check that bar does not exist and is not in index after "shit rm -f bar"' '
	test_path_is_missing bar &&
	test_must_fail shit ls-files --error-unmatch bar
'

test_expect_success 'Test that "shit rm -- -q" succeeds (remove a file that looks like an option)' '
	shit rm -- -q
'

test_expect_success FUNNYNAMES 'Test that "shit rm -f" succeeds with embedded space, tab, or newline characters.' '
	shit rm -f "space embedded" "tab	embedded" "newline${LF}embedded"
'

test_expect_success SANITY 'Test that "shit rm -f" fails if its rm fails' '
	test_when_finished "chmod 775 ." &&
	chmod a-w . &&
	test_must_fail shit rm -f baz
'

test_expect_success 'When the rm in "shit rm -f" fails, it should not remove the file from the index' '
	shit ls-files --error-unmatch baz
'

test_expect_success 'Remove nonexistent file with --ignore-unmatch' '
	shit rm --ignore-unmatch nonexistent
'

test_expect_success '"rm" command printed' '
	echo frotz >test-file &&
	shit add test-file &&
	shit commit -m "add file for rm test" &&
	shit rm test-file >rm-output.raw &&
	grep "^rm " rm-output.raw >rm-output &&
	test_line_count = 1 rm-output &&
	rm -f test-file rm-output.raw rm-output &&
	shit commit -m "remove file from rm test"
'

test_expect_success '"rm" command suppressed with --quiet' '
	echo frotz >test-file &&
	shit add test-file &&
	shit commit -m "add file for rm --quiet test" &&
	shit rm --quiet test-file >rm-output &&
	test_must_be_empty rm-output &&
	rm -f test-file rm-output &&
	shit commit -m "remove file from rm --quiet test"
'

# Now, failure cases.
test_expect_success 'Re-add foo and baz' '
	shit add foo baz &&
	shit ls-files --error-unmatch foo baz
'

test_expect_success 'Modify foo -- rm should refuse' '
	echo >>foo &&
	test_must_fail shit rm foo baz &&
	test_path_is_file foo &&
	test_path_is_file baz &&
	shit ls-files --error-unmatch foo baz
'

test_expect_success 'Modified foo -- rm -f should work' '
	shit rm -f foo baz &&
	test_path_is_missing foo &&
	test_path_is_missing baz &&
	test_must_fail shit ls-files --error-unmatch foo &&
	test_must_fail shit ls-files --error-unmatch bar
'

test_expect_success 'Re-add foo and baz for HEAD tests' '
	echo frotz >foo &&
	shit checkout HEAD -- baz &&
	shit add foo baz &&
	shit ls-files --error-unmatch foo baz
'

test_expect_success 'foo is different in index from HEAD -- rm should refuse' '
	test_must_fail shit rm foo baz &&
	test_path_is_file foo &&
	test_path_is_file baz &&
	shit ls-files --error-unmatch foo baz
'

test_expect_success 'but with -f it should work.' '
	shit rm -f foo baz &&
	test_path_is_missing foo &&
	test_path_is_missing baz &&
	test_must_fail shit ls-files --error-unmatch foo &&
	test_must_fail shit ls-files --error-unmatch baz
'

test_expect_success 'refuse to remove cached empty file with modifications' '
	>empty &&
	shit add empty &&
	echo content >empty &&
	test_must_fail shit rm --cached empty
'

test_expect_success 'remove intent-to-add file without --force' '
	echo content >intent-to-add &&
	shit add -N intent-to-add &&
	shit rm --cached intent-to-add
'

test_expect_success 'Recursive test setup' '
	mkdir -p frotz &&
	echo qfwfq >frotz/nitfol &&
	shit add frotz &&
	shit commit -m "subdir test"
'

test_expect_success 'Recursive without -r fails' '
	test_must_fail shit rm frotz &&
	test_path_is_dir frotz &&
	test_path_is_file frotz/nitfol
'

test_expect_success 'Recursive with -r but dirty' '
	echo qfwfq >>frotz/nitfol &&
	test_must_fail shit rm -r frotz &&
	test_path_is_dir frotz &&
	test_path_is_file frotz/nitfol
'

test_expect_success 'Recursive with -r -f' '
	shit rm -f -r frotz &&
	test_path_is_missing frotz/nitfol &&
	test_path_is_missing frotz
'

test_expect_success 'Remove nonexistent file returns nonzero exit status' '
	test_must_fail shit rm nonexistent
'

test_expect_success 'Call "rm" from outside the work tree' '
	mkdir repo &&
	(
		cd repo &&
		shit init &&
		echo something >somefile &&
		shit add somefile &&
		shit commit -m "add a file" &&
		(
			cd .. &&
			shit --shit-dir=repo/.shit --work-tree=repo rm somefile
		) &&
		test_must_fail shit ls-files --error-unmatch somefile
	)
'

test_expect_success 'refresh index before checking if it is up-to-date' '
	shit reset --hard &&
	test-tool chmtime -86400 frotz/nitfol &&
	shit rm frotz/nitfol &&
	test_path_is_missing frotz/nitfol
'

choke_shit_rm_setup() {
	shit reset -q --hard &&
	test_when_finished "rm -f .shit/index.lock && shit reset -q --hard" &&
	i=0 &&
	hash=$(test_oid deadbeef) &&
	while test $i -lt 12000
	do
		echo "100644 $hash 0	some-file-$i"
		i=$(( $i + 1 ))
	done | shit update-index --index-info
}

test_expect_success 'choking "shit rm" should not let it die with cruft (induce SIGPIPE)' '
	choke_shit_rm_setup &&
	# shit command is intentionally placed upstream of pipe to induce SIGPIPE
	shit rm -n "some-file-*" | : &&
	test_path_is_missing .shit/index.lock
'


test_expect_success !MINGW 'choking "shit rm" should not let it die with cruft (induce and check SIGPIPE)' '
	choke_shit_rm_setup &&
	OUT=$( ((trap "" PIPE && shit rm -n "some-file-*"; echo $? 1>&3) | :) 3>&1 ) &&
	test_match_signal 13 "$OUT" &&
	test_path_is_missing .shit/index.lock
'

test_expect_success 'Resolving by removal is not a warning-worthy event' '
	shit reset -q --hard &&
	test_when_finished "rm -f .shit/index.lock msg && shit reset -q --hard" &&
	blob=$(echo blob | shit hash-object -w --stdin) &&
	printf "100644 $blob %d\tblob\n" 1 2 3 | shit update-index --index-info &&
	shit rm blob >msg 2>&1 &&
	test_grep ! "needs merge" msg &&
	test_must_fail shit ls-files -s --error-unmatch blob
'

test_expect_success 'rm removes subdirectories recursively' '
	mkdir -p dir/subdir/subsubdir &&
	echo content >dir/subdir/subsubdir/file &&
	shit add dir/subdir/subsubdir/file &&
	shit rm -f dir/subdir/subsubdir/file &&
	test_path_is_missing dir
'

cat >expect <<EOF
M  .shitmodules
D  submod
EOF

cat >expect.modified <<EOF
 M submod
EOF

cat >expect.modified_inside <<EOF
 m submod
EOF

cat >expect.modified_untracked <<EOF
 ? submod
EOF

cat >expect.cached <<EOF
D  submod
EOF

cat >expect.both_deleted<<EOF
D  .shitmodules
D  submod
EOF

test_expect_success 'rm removes empty submodules from work tree' '
	mkdir submod &&
	hash=$(shit rev-parse HEAD) &&
	shit update-index --add --cacheinfo 160000 "$hash" submod &&
	shit config -f .shitmodules submodule.sub.url ./. &&
	shit config -f .shitmodules submodule.sub.path submod &&
	shit submodule init &&
	shit add .shitmodules &&
	shit commit -m "add submodule" &&
	shit rm submod &&
	test_path_is_missing submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual &&
	test_must_fail shit config -f .shitmodules submodule.sub.url &&
	test_must_fail shit config -f .shitmodules submodule.sub.path
'

test_expect_success 'rm removes removed submodule from index and .shitmodules' '
	shit reset --hard &&
	shit -c protocol.file.allow=always submodule update &&
	rm -rf submod &&
	shit rm submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual &&
	test_must_fail shit config -f .shitmodules submodule.sub.url &&
	test_must_fail shit config -f .shitmodules submodule.sub.path
'

test_expect_success 'rm removes work tree of unmodified submodules' '
	shit reset --hard &&
	shit submodule update &&
	shit rm submod &&
	test_path_is_missing submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual &&
	test_must_fail shit config -f .shitmodules submodule.sub.url &&
	test_must_fail shit config -f .shitmodules submodule.sub.path
'

test_expect_success 'rm removes a submodule with a trailing /' '
	shit reset --hard &&
	shit submodule update &&
	shit rm submod/ &&
	test_path_is_missing submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual
'

test_expect_success 'rm fails when given a file with a trailing /' '
	test_must_fail shit rm empty/
'

test_expect_success 'rm succeeds when given a directory with a trailing /' '
	shit rm -r frotz/
'

test_expect_success 'rm of a populated submodule with different HEAD fails unless forced' '
	shit reset --hard &&
	shit submodule update &&
	shit -C submod checkout HEAD^ &&
	test_must_fail shit rm submod &&
	test_path_is_dir submod &&
	test_path_is_file submod/.shit &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect.modified actual &&
	shit rm -f submod &&
	test_path_is_missing submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual &&
	test_must_fail shit config -f .shitmodules submodule.sub.url &&
	test_must_fail shit config -f .shitmodules submodule.sub.path
'

test_expect_success 'rm --cached leaves work tree of populated submodules and .shitmodules alone' '
	shit reset --hard &&
	shit submodule update &&
	shit rm --cached submod &&
	test_path_is_dir submod &&
	test_path_is_file submod/.shit &&
	shit status -s -uno >actual &&
	test_cmp expect.cached actual &&
	shit config -f .shitmodules submodule.sub.url &&
	shit config -f .shitmodules submodule.sub.path
'

test_expect_success 'rm --dry-run does not touch the submodule or .shitmodules' '
	shit reset --hard &&
	shit submodule update &&
	shit rm -n submod &&
	test_path_is_file submod/.shit &&
	shit diff-index --exit-code HEAD
'

test_expect_success 'rm does not complain when no .shitmodules file is found' '
	shit reset --hard &&
	shit submodule update &&
	shit rm .shitmodules &&
	shit rm submod >actual 2>actual.err &&
	test_must_be_empty actual.err &&
	test_path_is_missing submod &&
	test_path_is_missing submod/.shit &&
	shit status -s -uno >actual &&
	test_cmp expect.both_deleted actual
'

test_expect_success 'rm will error out on a modified .shitmodules file unless staged' '
	shit reset --hard &&
	shit submodule update &&
	shit config -f .shitmodules foo.bar true &&
	test_must_fail shit rm submod >actual 2>actual.err &&
	test_file_not_empty actual.err &&
	test_path_is_dir submod &&
	test_path_is_file submod/.shit &&
	shit diff-files --quiet -- submod &&
	shit add .shitmodules &&
	shit rm submod >actual 2>actual.err &&
	test_must_be_empty actual.err &&
	test_path_is_missing submod &&
	test_path_is_missing submod/.shit &&
	shit status -s -uno >actual &&
	test_cmp expect actual
'
test_expect_success 'rm will not error out on .shitmodules file with zero stat data' '
	shit reset --hard &&
	shit submodule update &&
	shit read-tree HEAD &&
	shit rm submod &&
	test_path_is_missing submod
'

test_expect_success 'rm issues a warning when section is not found in .shitmodules' '
	shit reset --hard &&
	shit submodule update &&
	shit config -f .shitmodules --remove-section submodule.sub &&
	shit add .shitmodules &&
	echo "warning: Could not find section in .shitmodules where path=submod" >expect.err &&
	shit rm submod >actual 2>actual.err &&
	test_cmp expect.err actual.err &&
	test_path_is_missing submod &&
	test_path_is_missing submod/.shit &&
	shit status -s -uno >actual &&
	test_cmp expect actual
'

test_expect_success 'rm of a populated submodule with modifications fails unless forced' '
	shit reset --hard &&
	shit submodule update &&
	echo X >submod/empty &&
	test_must_fail shit rm submod &&
	test_path_is_dir submod &&
	test_path_is_file submod/.shit &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect.modified_inside actual &&
	shit rm -f submod &&
	test_path_is_missing submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual
'

test_expect_success 'rm of a populated submodule with untracked files fails unless forced' '
	shit reset --hard &&
	shit submodule update &&
	echo X >submod/untracked &&
	test_must_fail shit rm submod &&
	test_path_is_dir submod &&
	test_path_is_file submod/.shit &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect.modified_untracked actual &&
	shit rm -f submod &&
	test_path_is_missing submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual
'

test_expect_success 'setup submodule conflict' '
	shit reset --hard &&
	shit submodule update &&
	shit checkout -b branch1 &&
	echo 1 >nitfol &&
	shit add nitfol &&
	shit commit -m "added nitfol 1" &&
	shit checkout -b branch2 main &&
	echo 2 >nitfol &&
	shit add nitfol &&
	shit commit -m "added nitfol 2" &&
	shit checkout -b conflict1 main &&
	shit -C submod fetch &&
	shit -C submod checkout branch1 &&
	shit add submod &&
	shit commit -m "submod 1" &&
	shit checkout -b conflict2 main &&
	shit -C submod checkout branch2 &&
	shit add submod &&
	shit commit -m "submod 2"
'

cat >expect.conflict <<EOF
UU submod
EOF

test_expect_success 'rm removes work tree of unmodified conflicted submodule' '
	shit checkout conflict1 &&
	shit reset --hard &&
	shit submodule update &&
	test_must_fail shit merge conflict2 &&
	shit rm submod &&
	test_path_is_missing submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual
'

test_expect_success 'rm of a conflicted populated submodule with different HEAD fails unless forced' '
	shit checkout conflict1 &&
	shit reset --hard &&
	shit submodule update &&
	shit -C submod checkout HEAD^ &&
	test_must_fail shit merge conflict2 &&
	test_must_fail shit rm submod &&
	test_path_is_dir submod &&
	test_path_is_file submod/.shit &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect.conflict actual &&
	shit rm -f submod &&
	test_path_is_missing submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual &&
	test_must_fail shit config -f .shitmodules submodule.sub.url &&
	test_must_fail shit config -f .shitmodules submodule.sub.path
'

test_expect_success 'rm of a conflicted populated submodule with modifications fails unless forced' '
	shit checkout conflict1 &&
	shit reset --hard &&
	shit submodule update &&
	echo X >submod/empty &&
	test_must_fail shit merge conflict2 &&
	test_must_fail shit rm submod &&
	test_path_is_dir submod &&
	test_path_is_file submod/.shit &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect.conflict actual &&
	shit rm -f submod &&
	test_path_is_missing submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual &&
	test_must_fail shit config -f .shitmodules submodule.sub.url &&
	test_must_fail shit config -f .shitmodules submodule.sub.path
'

test_expect_success 'rm of a conflicted populated submodule with untracked files fails unless forced' '
	shit checkout conflict1 &&
	shit reset --hard &&
	shit submodule update &&
	echo X >submod/untracked &&
	test_must_fail shit merge conflict2 &&
	test_must_fail shit rm submod &&
	test_path_is_dir submod &&
	test_path_is_file submod/.shit &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect.conflict actual &&
	shit rm -f submod &&
	test_path_is_missing submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual
'

test_expect_success 'rm of a conflicted populated submodule with a .shit directory fails even when forced' '
	shit checkout conflict1 &&
	shit reset --hard &&
	shit submodule update &&
	(
		cd submod &&
		rm .shit &&
		cp -R ../.shit/modules/sub .shit &&
		shit_WORK_TREE=. shit config --unset core.worktree
	) &&
	test_must_fail shit merge conflict2 &&
	test_must_fail shit rm submod &&
	test_path_is_dir submod &&
	test_path_is_dir submod/.shit &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect.conflict actual &&
	test_must_fail shit rm -f submod &&
	test_path_is_dir submod &&
	test_path_is_dir submod/.shit &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect.conflict actual &&
	shit merge --abort &&
	rm -rf submod
'

test_expect_success 'rm of a conflicted unpopulated submodule succeeds' '
	shit checkout conflict1 &&
	shit reset --hard &&
	test_must_fail shit merge conflict2 &&
	shit rm submod &&
	test_path_is_missing submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual
'

test_expect_success 'rm of a populated submodule with a .shit directory migrates shit dir' '
	shit checkout -f main &&
	shit reset --hard &&
	shit submodule update &&
	(
		cd submod &&
		rm .shit &&
		cp -R ../.shit/modules/sub .shit &&
		shit_WORK_TREE=. shit config --unset core.worktree &&
		rm -r ../.shit/modules/sub
	) &&
	shit rm submod 2>output.err &&
	test_path_is_missing submod &&
	test_path_is_missing submod/.shit &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_file_not_empty actual &&
	test_grep Migrating output.err
'

cat >expect.deepmodified <<EOF
 M submod/subsubmod
EOF

test_expect_success 'setup subsubmodule' '
	test_config_global protocol.file.allow always &&
	shit reset --hard &&
	shit submodule update &&
	(
		cd submod &&
		hash=$(shit rev-parse HEAD) &&
		shit update-index --add --cacheinfo 160000 "$hash" subsubmod &&
		shit config -f .shitmodules submodule.sub.url ../. &&
		shit config -f .shitmodules submodule.sub.path subsubmod &&
		shit submodule init &&
		shit add .shitmodules &&
		shit commit -m "add subsubmodule" &&
		shit submodule update subsubmod
	) &&
	shit commit -a -m "added deep submodule"
'

test_expect_success 'rm recursively removes work tree of unmodified submodules' '
	shit rm submod &&
	test_path_is_missing submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual
'

test_expect_success 'rm of a populated nested submodule with different nested HEAD fails unless forced' '
	shit reset --hard &&
	shit submodule update --recursive &&
	shit -C submod/subsubmod checkout HEAD^ &&
	test_must_fail shit rm submod &&
	test_path_is_dir submod &&
	test_path_is_file submod/.shit &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect.modified_inside actual &&
	shit rm -f submod &&
	test_path_is_missing submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual
'

test_expect_success 'rm of a populated nested submodule with nested modifications fails unless forced' '
	shit reset --hard &&
	shit submodule update --recursive &&
	echo X >submod/subsubmod/empty &&
	test_must_fail shit rm submod &&
	test_path_is_dir submod &&
	test_path_is_file submod/.shit &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect.modified_inside actual &&
	shit rm -f submod &&
	test_path_is_missing submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual
'

test_expect_success 'rm of a populated nested submodule with nested untracked files fails unless forced' '
	shit reset --hard &&
	shit submodule update --recursive &&
	echo X >submod/subsubmod/untracked &&
	test_must_fail shit rm submod &&
	test_path_is_dir submod &&
	test_path_is_file submod/.shit &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect.modified_untracked actual &&
	shit rm -f submod &&
	test_path_is_missing submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_cmp expect actual
'

test_expect_success "rm absorbs submodule's nested .shit directory" '
	shit reset --hard &&
	shit submodule update --recursive &&
	(
		cd submod/subsubmod &&
		rm .shit &&
		mv ../../.shit/modules/sub/modules/sub .shit &&
		shit_WORK_TREE=. shit config --unset core.worktree
	) &&
	shit rm submod 2>output.err &&
	test_path_is_missing submod &&
	test_path_is_missing submod/subsubmod/.shit &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_file_not_empty actual &&
	test_grep Migrating output.err
'

test_expect_success 'checking out a commit after submodule removal needs manual updates' '
	shit commit -m "submodule removal" submod .shitmodules &&
	shit checkout HEAD^ &&
	shit submodule update &&
	shit checkout -q HEAD^ &&
	shit checkout -q main 2>actual &&
	test_grep "^warning: unable to rmdir '\''submod'\'':" actual &&
	shit status -s submod >actual &&
	echo "?? submod/" >expected &&
	test_cmp expected actual &&
	rm -rf submod &&
	shit status -s -uno --ignore-submodules=none >actual &&
	test_must_be_empty actual
'

test_expect_success 'rm of d/f when d has become a non-directory' '
	rm -rf d &&
	mkdir d &&
	>d/f &&
	shit add d &&
	rm -rf d &&
	>d &&
	shit rm d/f &&
	test_must_fail shit rev-parse --verify :d/f &&
	test_path_is_file d
'

test_expect_success SYMLINKS 'rm of d/f when d has become a dangling symlink' '
	rm -rf d &&
	mkdir d &&
	>d/f &&
	shit add d &&
	rm -rf d &&
	ln -s nonexistent d &&
	shit rm d/f &&
	test_must_fail shit rev-parse --verify :d/f &&
	test -h d &&
	test_path_is_missing d
'

test_expect_success 'rm of file when it has become a directory' '
	rm -rf d &&
	>d &&
	shit add d &&
	rm -f d &&
	mkdir d &&
	>d/f &&
	test_must_fail shit rm d &&
	shit rev-parse --verify :d &&
	test_path_is_file d/f
'

test_expect_success SYMLINKS 'rm across a symlinked leading path (no index)' '
	rm -rf d e &&
	mkdir e &&
	echo content >e/f &&
	ln -s e d &&
	shit add -A e d &&
	shit commit -m "symlink d to e, e/f exists" &&
	test_must_fail shit rm d/f &&
	shit rev-parse --verify :d &&
	shit rev-parse --verify :e/f &&
	test -h d &&
	test_path_is_file e/f
'

test_expect_failure SYMLINKS 'rm across a symlinked leading path (w/ index)' '
	rm -rf d e &&
	mkdir d &&
	echo content >d/f &&
	shit add -A e d &&
	shit commit -m "d/f exists" &&
	mv d e &&
	ln -s e d &&
	test_must_fail shit rm d/f &&
	shit rev-parse --verify :d/f &&
	test -h d &&
	test_path_is_file e/f
'

test_expect_success 'setup for testing rm messages' '
	>bar.txt &&
	>foo.txt &&
	shit add bar.txt foo.txt
'

test_expect_success 'rm files with different staged content' '
	cat >expect <<-\EOF &&
	error: the following files have staged content different from both the
	file and the HEAD:
	    bar.txt
	    foo.txt
	(use -f to force removal)
	EOF
	echo content1 >foo.txt &&
	echo content1 >bar.txt &&
	test_must_fail shit rm foo.txt bar.txt 2>actual &&
	test_cmp expect actual
'

test_expect_success 'rm files with different staged content without hints' '
	cat >expect <<-\EOF &&
	error: the following files have staged content different from both the
	file and the HEAD:
	    bar.txt
	    foo.txt
	EOF
	echo content2 >foo.txt &&
	echo content2 >bar.txt &&
	test_must_fail shit -c advice.rmhints=false rm foo.txt bar.txt 2>actual &&
	test_cmp expect actual
'

test_expect_success 'rm file with local modification' '
	cat >expect <<-\EOF &&
	error: the following file has local modifications:
	    foo.txt
	(use --cached to keep the file, or -f to force removal)
	EOF
	shit commit -m "testing rm 3" &&
	echo content3 >foo.txt &&
	test_must_fail shit rm foo.txt 2>actual &&
	test_cmp expect actual
'

test_expect_success 'rm file with local modification without hints' '
	cat >expect <<-\EOF &&
	error: the following file has local modifications:
	    bar.txt
	EOF
	echo content4 >bar.txt &&
	test_must_fail shit -c advice.rmhints=false rm bar.txt 2>actual &&
	test_cmp expect actual
'

test_expect_success 'rm file with changes in the index' '
	cat >expect <<-\EOF &&
	error: the following file has changes staged in the index:
	    foo.txt
	(use --cached to keep the file, or -f to force removal)
	EOF
	shit reset --hard &&
	echo content5 >foo.txt &&
	shit add foo.txt &&
	test_must_fail shit rm foo.txt 2>actual &&
	test_cmp expect actual
'

test_expect_success 'rm file with changes in the index without hints' '
	cat >expect <<-\EOF &&
	error: the following file has changes staged in the index:
	    foo.txt
	EOF
	test_must_fail shit -c advice.rmhints=false rm foo.txt 2>actual &&
	test_cmp expect actual
'

test_expect_success 'rm files with two different errors' '
	cat >expect <<-\EOF &&
	error: the following file has staged content different from both the
	file and the HEAD:
	    foo1.txt
	(use -f to force removal)
	error: the following file has changes staged in the index:
	    bar1.txt
	(use --cached to keep the file, or -f to force removal)
	EOF
	echo content >foo1.txt &&
	shit add foo1.txt &&
	echo content6 >foo1.txt &&
	echo content6 >bar1.txt &&
	shit add bar1.txt &&
	test_must_fail shit rm bar1.txt foo1.txt 2>actual &&
	test_cmp expect actual
'

test_expect_success 'rm empty string should fail' '
	test_must_fail shit rm -rf ""
'

test_done
