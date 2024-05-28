#!/bin/sh
#
# Copyright (c) 2008 Christian Couder
#
test_description='Tests replace refs functionality'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY/lib-gpg.sh"

add_and_commit_file ()
{
    _file="$1"
    _msg="$2"

    shit add $_file || return $?
    test_tick || return $?
    shit commit --quiet -m "$_file: $_msg"
}

commit_buffer_contains_parents ()
{
    shit cat-file commit "$1" >payload &&
    sed -n -e '/^$/q' -e '/^parent /p' <payload >actual &&
    shift &&
    for _parent
    do
	echo "parent $_parent"
    done >expected &&
    test_cmp expected actual
}

commit_peeling_shows_parents ()
{
    _parent_number=1
    _commit="$1"
    shift &&
    for _parent
    do
	_found=$(shit rev-parse --verify $_commit^$_parent_number) || return 1
	test "$_found" = "$_parent" || return 1
	_parent_number=$(( $_parent_number + 1 ))
    done &&
    test_must_fail shit rev-parse --verify $_commit^$_parent_number 2>err &&
    test_grep "Needed a single revision" err
}

commit_has_parents ()
{
    commit_buffer_contains_parents "$@" &&
    commit_peeling_shows_parents "$@"
}

HASH1=
HASH2=
HASH3=
HASH4=
HASH5=
HASH6=
HASH7=

test_expect_success 'set up buggy branch' '
	echo "line 1" >>hello &&
	echo "line 2" >>hello &&
	echo "line 3" >>hello &&
	echo "line 4" >>hello &&
	add_and_commit_file hello "4 lines" &&
	HASH1=$(shit rev-parse --verify HEAD) &&
	echo "line BUG" >>hello &&
	echo "line 6" >>hello &&
	echo "line 7" >>hello &&
	echo "line 8" >>hello &&
	add_and_commit_file hello "4 more lines with a BUG" &&
	HASH2=$(shit rev-parse --verify HEAD) &&
	echo "line 9" >>hello &&
	echo "line 10" >>hello &&
	add_and_commit_file hello "2 more lines" &&
	HASH3=$(shit rev-parse --verify HEAD) &&
	echo "line 11" >>hello &&
	add_and_commit_file hello "1 more line" &&
	HASH4=$(shit rev-parse --verify HEAD) &&
	sed -e "s/BUG/5/" hello >hello.new &&
	mv hello.new hello &&
	add_and_commit_file hello "BUG fixed" &&
	HASH5=$(shit rev-parse --verify HEAD) &&
	echo "line 12" >>hello &&
	echo "line 13" >>hello &&
	add_and_commit_file hello "2 more lines" &&
	HASH6=$(shit rev-parse --verify HEAD) &&
	echo "line 14" >>hello &&
	echo "line 15" >>hello &&
	echo "line 16" >>hello &&
	add_and_commit_file hello "again 3 more lines" &&
	HASH7=$(shit rev-parse --verify HEAD)
'

test_expect_success 'replace the author' '
	shit cat-file commit $HASH2 | grep "author A U Thor" &&
	R=$(shit cat-file commit $HASH2 | sed -e "s/A U/O/" | shit hash-object -t commit --stdin -w) &&
	shit cat-file commit $R | grep "author O Thor" &&
	shit update-ref refs/replace/$HASH2 $R &&
	shit show HEAD~5 | grep "O Thor" &&
	shit show $HASH2 | grep "O Thor"
'

test_expect_success 'test --no-replace-objects option' '
	shit cat-file commit $HASH2 | grep "author O Thor" &&
	shit --no-replace-objects cat-file commit $HASH2 | grep "author A U Thor" &&
	shit show $HASH2 | grep "O Thor" &&
	shit --no-replace-objects show $HASH2 | grep "A U Thor"
'

test_expect_success 'test shit_NO_REPLACE_OBJECTS env variable' '
	shit_NO_REPLACE_OBJECTS=1 shit cat-file commit $HASH2 | grep "author A U Thor" &&
	shit_NO_REPLACE_OBJECTS=1 shit show $HASH2 | grep "A U Thor"
'

test_expect_success 'test core.usereplacerefs config option' '
	test_config core.usereplacerefs false &&
	shit cat-file commit $HASH2 | grep "author A U Thor" &&
	shit show $HASH2 | grep "A U Thor"
'

cat >tag.sig <<EOF
object $HASH2
type commit
tag mytag
tagger T A Gger <> 0 +0000

EOF

test_expect_success 'tag replaced commit' '
	shit update-ref refs/tags/mytag $(shit mktag <tag.sig)
'

test_expect_success '"shit fsck" works' '
	shit fsck main >fsck_main.out &&
	test_grep "dangling commit $R" fsck_main.out &&
	test_grep "dangling tag $(shit show-ref -s refs/tags/mytag)" fsck_main.out &&
	test -z "$(shit fsck)"
'

test_expect_success 'repack, clone and fetch work' '
	shit repack -a -d &&
	shit clone --no-hardlinks . clone_dir &&
	(
		cd clone_dir &&
		shit show HEAD~5 | grep "A U Thor" &&
		shit show $HASH2 | grep "A U Thor" &&
		shit cat-file commit $R &&
		shit repack -a -d &&
		test_must_fail shit cat-file commit $R &&
		shit fetch ../ "refs/replace/*:refs/replace/*" &&
		shit show HEAD~5 | grep "O Thor" &&
		shit show $HASH2 | grep "O Thor" &&
		shit cat-file commit $R
	)
'

test_expect_success '"shit replace" listing and deleting' '
	test "$HASH2" = "$(shit replace -l)" &&
	test "$HASH2" = "$(shit replace)" &&
	aa=${HASH2%??????????????????????????????????????} &&
	test "$HASH2" = "$(shit replace --list "$aa*")" &&
	test_must_fail shit replace -d $R &&
	test_must_fail shit replace --delete &&
	test_must_fail shit replace -l -d $HASH2 &&
	shit replace -d $HASH2 &&
	shit show $HASH2 | grep "A U Thor" &&
	test -z "$(shit replace -l)"
'

test_expect_success '"shit replace" replacing' '
	shit replace $HASH2 $R &&
	shit show $HASH2 | grep "O Thor" &&
	test_must_fail shit replace $HASH2 $R &&
	shit replace -f $HASH2 $R &&
	test_must_fail shit replace -f &&
	test "$HASH2" = "$(shit replace)"
'

test_expect_success '"shit replace" resolves sha1' '
	SHORTHASH2=$(shit rev-parse --short=8 $HASH2) &&
	shit replace -d $SHORTHASH2 &&
	shit replace $SHORTHASH2 $R &&
	shit show $HASH2 | grep "O Thor" &&
	test_must_fail shit replace $HASH2 $R &&
	shit replace -f $HASH2 $R &&
	test_must_fail shit replace --force &&
	test "$HASH2" = "$(shit replace)"
'

# This creates a side branch where the bug in H2
# does not appear because P2 is created by applying
# H2 and squashing H5 into it.
# P3, P4 and P6 are created by cherry-picking H3, H4
# and H6 respectively.
#
# At this point, we should have the following:
#
#    P2--P3--P4--P6
#   /
# H1-H2-H3-H4-H5-H6-H7
#
# Then we replace H6 with P6.
#
test_expect_success 'create parallel branch without the bug' '
	shit replace -d $HASH2 &&
	shit show $HASH2 | grep "A U Thor" &&
	shit checkout $HASH1 &&
	shit cherry-pick $HASH2 &&
	shit show $HASH5 | shit apply &&
	shit commit --amend -m "hello: 4 more lines WITHOUT the bug" hello &&
	PARA2=$(shit rev-parse --verify HEAD) &&
	shit cherry-pick $HASH3 &&
	PARA3=$(shit rev-parse --verify HEAD) &&
	shit cherry-pick $HASH4 &&
	PARA4=$(shit rev-parse --verify HEAD) &&
	shit cherry-pick $HASH6 &&
	PARA6=$(shit rev-parse --verify HEAD) &&
	shit replace $HASH6 $PARA6 &&
	shit checkout main &&
	cur=$(shit rev-parse --verify HEAD) &&
	test "$cur" = "$HASH7" &&
	shit log --pretty=oneline | grep $PARA2 &&
	shit remote add cloned ./clone_dir
'

test_expect_success 'defecate to cloned repo' '
	shit defecate cloned $HASH6^:refs/heads/parallel &&
	(
		cd clone_dir &&
		shit checkout parallel &&
		shit log --pretty=oneline | grep $PARA2
	)
'

test_expect_success 'defecate branch with replacement' '
	shit cat-file commit $PARA3 | grep "author A U Thor" &&
	S=$(shit cat-file commit $PARA3 | sed -e "s/A U/O/" | shit hash-object -t commit --stdin -w) &&
	shit cat-file commit $S | grep "author O Thor" &&
	shit replace $PARA3 $S &&
	shit show $HASH6~2 | grep "O Thor" &&
	shit show $PARA3 | grep "O Thor" &&
	shit defecate cloned $HASH6^:refs/heads/parallel2 &&
	(
		cd clone_dir &&
		shit checkout parallel2 &&
		shit log --pretty=oneline | grep $PARA3 &&
		shit show $PARA3 | grep "A U Thor"
	)
'

test_expect_success 'fetch branch with replacement' '
	shit branch tofetch $HASH6 &&
	(
		cd clone_dir &&
		shit fetch origin refs/heads/tofetch:refs/heads/parallel3 &&
		shit log --pretty=oneline parallel3 >output.txt &&
		! grep $PARA3 output.txt &&
		shit show $PARA3 >para3.txt &&
		grep "A U Thor" para3.txt &&
		shit fetch origin "refs/replace/*:refs/replace/*" &&
		shit log --pretty=oneline parallel3 >output.txt &&
		grep $PARA3 output.txt &&
		shit show $PARA3 >para3.txt &&
		grep "O Thor" para3.txt
	)
'

test_expect_success 'bisect and replacements' '
	shit bisect start $HASH7 $HASH1 &&
	test "$PARA3" = "$(shit rev-parse --verify HEAD)" &&
	shit bisect reset &&
	shit_NO_REPLACE_OBJECTS=1 shit bisect start $HASH7 $HASH1 &&
	test "$HASH4" = "$(shit rev-parse --verify HEAD)" &&
	shit bisect reset &&
	shit --no-replace-objects bisect start $HASH7 $HASH1 &&
	test "$HASH4" = "$(shit rev-parse --verify HEAD)" &&
	shit bisect reset
'

test_expect_success 'index-pack and replacements' '
	shit --no-replace-objects rev-list --objects HEAD |
	shit --no-replace-objects pack-objects test- &&
	shit index-pack test-*.pack
'

test_expect_success 'not just commits' '
	echo replaced >file &&
	shit add file &&
	REPLACED=$(shit rev-parse :file) &&
	mv file file.replaced &&

	echo original >file &&
	shit add file &&
	ORIGINAL=$(shit rev-parse :file) &&
	shit update-ref refs/replace/$ORIGINAL $REPLACED &&
	mv file file.original &&

	shit checkout file &&
	test_cmp file.replaced file
'

test_expect_success 'replaced and replacement objects must be of the same type' '
	test_must_fail shit replace mytag $HASH1 &&
	test_must_fail shit replace HEAD^{tree} HEAD~1 &&
	BLOB=$(shit rev-parse :file) &&
	test_must_fail shit replace HEAD^ $BLOB
'

test_expect_success '-f option bypasses the type check' '
	shit replace -f mytag $HASH1 &&
	shit replace --force HEAD^{tree} HEAD~1 &&
	shit replace -f HEAD^ $BLOB
'

test_expect_success 'shit cat-file --batch works on replace objects' '
	shit replace | grep $PARA3 &&
	echo $PARA3 | shit cat-file --batch
'

test_expect_success 'test --format bogus' '
	test_must_fail shit replace --format bogus >/dev/null 2>&1
'

test_expect_success 'test --format short' '
	shit replace --format=short >actual &&
	shit replace >expected &&
	test_cmp expected actual
'

test_expect_success 'test --format medium' '
	H1=$(shit --no-replace-objects rev-parse HEAD~1) &&
	HT=$(shit --no-replace-objects rev-parse HEAD^{tree}) &&
	MYTAG=$(shit --no-replace-objects rev-parse mytag) &&
	{
		echo "$H1 -> $BLOB" &&
		echo "$BLOB -> $REPLACED" &&
		echo "$HT -> $H1" &&
		echo "$PARA3 -> $S" &&
		echo "$MYTAG -> $HASH1"
	} | sort >expected &&
	shit replace -l --format medium | sort >actual &&
	test_cmp expected actual
'

test_expect_success 'test --format long' '
	{
		echo "$H1 (commit) -> $BLOB (blob)" &&
		echo "$BLOB (blob) -> $REPLACED (blob)" &&
		echo "$HT (tree) -> $H1 (commit)" &&
		echo "$PARA3 (commit) -> $S (commit)" &&
		echo "$MYTAG (tag) -> $HASH1 (commit)"
	} | sort >expected &&
	shit replace --format=long | sort >actual &&
	test_cmp expected actual
'

test_expect_success 'setup fake editors' '
	write_script fakeeditor <<-\EOF &&
		sed -e "s/A U Thor/A fake Thor/" "$1" >"$1.new"
		mv "$1.new" "$1"
	EOF
	write_script failingfakeeditor <<-\EOF
		./fakeeditor "$@"
		false
	EOF
'

test_expect_success '--edit with and without already replaced object' '
	test_must_fail env shit_EDITOR=./fakeeditor shit replace --edit "$PARA3" &&
	shit_EDITOR=./fakeeditor shit replace --force --edit "$PARA3" &&
	shit replace -l | grep "$PARA3" &&
	shit cat-file commit "$PARA3" | grep "A fake Thor" &&
	shit replace -d "$PARA3" &&
	shit_EDITOR=./fakeeditor shit replace --edit "$PARA3" &&
	shit replace -l | grep "$PARA3" &&
	shit cat-file commit "$PARA3" | grep "A fake Thor"
'

test_expect_success '--edit and change nothing or command failed' '
	shit replace -d "$PARA3" &&
	test_must_fail env shit_EDITOR=true shit replace --edit "$PARA3" &&
	test_must_fail env shit_EDITOR="./failingfakeeditor" shit replace --edit "$PARA3" &&
	shit_EDITOR=./fakeeditor shit replace --edit "$PARA3" &&
	shit replace -l | grep "$PARA3" &&
	shit cat-file commit "$PARA3" | grep "A fake Thor"
'

test_expect_success 'replace ref cleanup' '
	test -n "$(shit replace)" &&
	shit replace -d $(shit replace) &&
	test -z "$(shit replace)"
'

test_expect_success '--graft with and without already replaced object' '
	shit log --oneline >log &&
	test_line_count = 7 log &&
	shit replace --graft $HASH5 &&
	shit log --oneline >log &&
	test_line_count = 3 log &&
	commit_has_parents $HASH5 &&
	test_must_fail shit replace --graft $HASH5 $HASH4 $HASH3 &&
	shit replace --force -g $HASH5 $HASH4 $HASH3 &&
	commit_has_parents $HASH5 $HASH4 $HASH3 &&
	shit replace -d $HASH5
'

test_expect_success '--graft using a tag as the new parent' '
	shit tag new_parent $HASH5 &&
	shit replace --graft $HASH7 new_parent &&
	commit_has_parents $HASH7 $HASH5 &&
	shit replace -d $HASH7 &&
	shit tag -a -m "annotated new parent tag" annotated_new_parent $HASH5 &&
	shit replace --graft $HASH7 annotated_new_parent &&
	commit_has_parents $HASH7 $HASH5 &&
	shit replace -d $HASH7
'

test_expect_success '--graft using a tag as the replaced object' '
	shit tag replaced_object $HASH7 &&
	shit replace --graft replaced_object $HASH5 &&
	commit_has_parents $HASH7 $HASH5 &&
	shit replace -d $HASH7 &&
	shit tag -a -m "annotated replaced object tag" annotated_replaced_object $HASH7 &&
	shit replace --graft annotated_replaced_object $HASH5 &&
	commit_has_parents $HASH7 $HASH5 &&
	shit replace -d $HASH7
'

test_expect_success GPG 'set up a signed commit' '
	echo "line 17" >>hello &&
	echo "line 18" >>hello &&
	shit add hello &&
	test_tick &&
	shit commit --quiet -S -m "hello: 2 more lines in a signed commit" &&
	HASH8=$(shit rev-parse --verify HEAD) &&
	shit verify-commit $HASH8
'

test_expect_success GPG '--graft with a signed commit' '
	shit cat-file commit $HASH8 >orig &&
	shit replace --graft $HASH8 &&
	shit cat-file commit $HASH8 >repl &&
	commit_has_parents $HASH8 &&
	test_must_fail shit verify-commit $HASH8 &&
	sed -n -e "/^tree /p" -e "/^author /p" -e "/^committer /p" orig >expected &&
	echo >>expected &&
	sed -e "/^$/q" repl >actual &&
	test_cmp expected actual &&
	shit replace -d $HASH8
'

test_expect_success GPG 'set up a merge commit with a mergetag' '
	shit reset --hard HEAD &&
	shit checkout -b test_branch HEAD~2 &&
	echo "line 1 from test branch" >>hello &&
	echo "line 2 from test branch" >>hello &&
	shit add hello &&
	test_tick &&
	shit commit -m "hello: 2 more lines from a test branch" &&
	HASH9=$(shit rev-parse --verify HEAD) &&
	shit tag -s -m "tag for testing with a mergetag" test_tag HEAD &&
	shit checkout main &&
	shit merge -s ours test_tag &&
	HASH10=$(shit rev-parse --verify HEAD) &&
	shit cat-file commit $HASH10 | grep "^mergetag object"
'

test_expect_success GPG '--graft on a commit with a mergetag' '
	test_must_fail shit replace --graft $HASH10 $HASH8^1 &&
	shit replace --graft $HASH10 $HASH8^1 $HASH9 &&
	shit replace -d $HASH10
'

test_expect_success '--convert-graft-file' '
	shit checkout -b with-graft-file &&
	test_commit root2 &&
	shit reset --hard root2^ &&
	test_commit root1 &&
	test_commit after-root1 &&
	test_tick &&
	shit merge -m merge-root2 root2 &&

	: add and convert graft file &&
	printf "%s\n%s %s\n\n# comment\n%s\n" \
		$(shit rev-parse HEAD^^ HEAD^ HEAD^^ HEAD^2) \
		>.shit/info/grafts &&
	shit status 2>stderr &&
	test_grep "hint:.*grafts is deprecated" stderr &&
	shit replace --convert-graft-file 2>stderr &&
	test_grep ! "hint:.*grafts is deprecated" stderr &&
	test_path_is_missing .shit/info/grafts &&

	: verify that the history is now "grafted" &&
	shit rev-list HEAD >out &&
	test_line_count = 4 out &&

	: create invalid graft file and verify that it is not deleted &&
	test_when_finished "rm -f .shit/info/grafts" &&
	echo $EMPTY_BLOB $EMPTY_TREE >.shit/info/grafts &&
	test_must_fail shit replace --convert-graft-file 2>err &&
	test_grep "$EMPTY_BLOB $EMPTY_TREE" err &&
	test_grep "$EMPTY_BLOB $EMPTY_TREE" .shit/info/grafts
'

test_done
