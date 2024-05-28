#!/bin/sh
#
# Copyright (c) 2007 Kristian Høgsberg <krh@redhat.com>
#

# FIXME: Test the various index usages, test reflog

test_description='shit commit'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY/lib-diff.sh"

author='The Real Author <someguy@his.email.org>'

test_tick

test_expect_success 'initial status' '
	echo bongo bongo >file &&
	shit add file &&
	shit status >actual &&
	test_grep "No commits yet" actual
'

test_expect_success 'fail initial amend' '
	test_must_fail shit commit --amend
'

test_expect_success 'setup: initial commit' '
	shit commit -m initial
'

test_expect_success '-m and -F do not mix' '
	shit checkout HEAD file && echo >>file && shit add file &&
	test_must_fail shit commit -m foo -m bar -F file
'

test_expect_success '-m and -C do not mix' '
	shit checkout HEAD file && echo >>file && shit add file &&
	test_must_fail shit commit -C HEAD -m illegal
'

test_expect_success 'paths and -a do not mix' '
	echo King of the bongo >file &&
	test_must_fail shit commit -m foo -a file
'

test_expect_success PERL 'can use paths with --interactive' '
	echo bong-o-bong >file &&
	# 2: update, 1:st path, that is all, 7: quit
	test_write_lines 2 1 "" 7 |
	shit commit -m foo --interactive file &&
	shit reset --hard HEAD^
'

test_expect_success 'removed files and relative paths' '
	test_when_finished "rm -rf foo" &&
	shit init foo &&
	>foo/foo.txt &&
	shit -C foo add foo.txt &&
	shit -C foo commit -m first &&
	shit -C foo rm foo.txt &&

	mkdir -p foo/bar &&
	shit -C foo/bar commit -m second ../foo.txt
'

test_expect_success 'using invalid commit with -C' '
	test_must_fail shit commit --allow-empty -C bogus
'

test_expect_success 'nothing to commit' '
	shit reset --hard &&
	test_must_fail shit commit -m initial
'

test_expect_success '--dry-run fails with nothing to commit' '
	test_must_fail shit commit -m initial --dry-run
'

test_expect_success '--short fails with nothing to commit' '
	test_must_fail shit commit -m initial --short
'

test_expect_success '--porcelain fails with nothing to commit' '
	test_must_fail shit commit -m initial --porcelain
'

test_expect_success '--long fails with nothing to commit' '
	test_must_fail shit commit -m initial --long
'

test_expect_success 'fail to commit untracked file (even with --include/--only)' '
	echo content >baz &&
	error="error: pathspec .baz. did not match any file(s) known to shit" &&

	test_must_fail shit commit -m "baz" baz 2>err &&
	test_grep -e "$error" err &&

	test_must_fail shit commit --only -m "baz" baz 2>err &&
	test_grep -e "$error" err &&

	test_must_fail shit commit --include -m "baz" baz 2>err &&
	test_grep -e "$error" err
'

test_expect_success 'setup: non-initial commit' '
	echo bongo bongo bongo >file &&
	shit commit -m next -a
'

test_expect_success '--dry-run with stuff to commit returns ok' '
	echo bongo bongo bongo >>file &&
	shit commit -m next -a --dry-run
'

test_expect_success '--short with stuff to commit returns ok' '
	echo bongo bongo bongo >>file &&
	shit commit -m next -a --short
'

test_expect_success '--porcelain with stuff to commit returns ok' '
	echo bongo bongo bongo >>file &&
	shit commit -m next -a --porcelain
'

test_expect_success '--long with stuff to commit returns ok' '
	echo bongo bongo bongo >>file &&
	shit commit -m next -a --long
'

for opt in "" "-o" "--only"
do
	test_expect_success 'exclude additional staged changes when given pathspec' '
		echo content >>file &&
		echo content >>baz &&
		shit add baz &&
		shit commit $opt -m "file" file &&

		shit diff --name-only >actual &&
		test_must_be_empty actual &&

		test_write_lines baz >expect &&
		shit diff --name-only --cached >actual &&
		test_cmp expect actual &&

		test_write_lines file >expect &&
		shit diff --name-only HEAD^ HEAD >actual &&
		test_cmp expect actual
	'
done

test_expect_success '-i/--include includes staged changes' '
	echo content >>file &&
	echo content >>baz &&
	shit add file &&

	# baz is in the index, therefore, it will be committed
	shit commit --include -m "file and baz" baz  &&

	shit diff --name-only HEAD >remaining &&
	test_must_be_empty remaining &&

	test_write_lines baz file >expect &&
	shit diff --name-only HEAD^ HEAD >actual &&
	test_cmp expect actual
'

test_expect_success '--include and --only do not mix' '
	test_when_finished "shit reset --hard" &&
	echo content >>file &&
	echo content >>baz &&
	test_must_fail shit commit --include --only -m "file baz" file baz 2>actual &&
	test_grep -e "fatal: options .-i/--include. and .-o/--only. cannot be used together" actual
'

test_expect_success 'commit message from non-existing file' '
	echo more bongo: bongo bongo bongo bongo >file &&
	test_must_fail shit commit -F gah -a
'

test_expect_success 'empty commit message' '
	# Empty except stray tabs and spaces on a few lines.
	sed -e "s/@//g" >msg <<-\EOF &&
		@		@
		@@
		@  @
		@Signed-off-by: hula@
	EOF
	test_must_fail shit commit -F msg -a
'

test_expect_success 'template "emptyness" check does not kick in with -F' '
	shit checkout HEAD file && echo >>file && shit add file &&
	shit commit -t file -F file
'

test_expect_success 'template "emptyness" check' '
	shit checkout HEAD file && echo >>file && shit add file &&
	test_must_fail shit commit -t file 2>err &&
	test_grep "did not edit" err
'

test_expect_success 'setup: commit message from file' '
	shit checkout HEAD file && echo >>file && shit add file &&
	echo this is the commit message, coming from a file >msg &&
	shit commit -F msg -a
'

test_expect_success 'amend commit' '
	cat >editor <<-\EOF &&
	#!/bin/sh
	sed -e "s/a file/an amend commit/g" <"$1" >"$1-"
	mv "$1-" "$1"
	EOF
	chmod 755 editor &&
	EDITOR=./editor shit commit --amend
'

test_expect_success 'amend --only ignores staged contents' '
	cp file file.expect &&
	echo changed >file &&
	shit add file &&
	shit commit --no-edit --amend --only &&
	shit cat-file blob HEAD:file >file.actual &&
	test_cmp file.expect file.actual &&
	shit diff --exit-code
'

test_expect_success 'allow-empty --only ignores staged contents' '
	echo changed-again >file &&
	shit add file &&
	shit commit --allow-empty --only -m "empty" &&
	shit cat-file blob HEAD:file >file.actual &&
	test_cmp file.expect file.actual &&
	shit diff --exit-code
'

test_expect_success 'set up editor' '
	cat >editor <<-\EOF &&
	#!/bin/sh
	sed -e "s/unamended/amended/g" <"$1" >"$1-"
	mv "$1-" "$1"
	EOF
	chmod 755 editor
'

test_expect_success 'amend without launching editor' '
	echo unamended >expect &&
	shit commit --allow-empty -m "unamended" &&
	echo needs more bongo >file &&
	shit add file &&
	EDITOR=./editor shit commit --no-edit --amend &&
	shit diff --exit-code HEAD -- file &&
	shit diff-tree -s --format=%s HEAD >msg &&
	test_cmp expect msg
'

test_expect_success '--amend --edit' '
	echo amended >expect &&
	shit commit --allow-empty -m "unamended" &&
	echo bongo again >file &&
	shit add file &&
	EDITOR=./editor shit commit --edit --amend &&
	shit diff-tree -s --format=%s HEAD >msg &&
	test_cmp expect msg
'

test_expect_success '--amend --edit of empty message' '
	cat >replace <<-\EOF &&
	#!/bin/sh
	echo "amended" >"$1"
	EOF
	chmod 755 replace &&
	shit commit --allow-empty --allow-empty-message -m "" &&
	echo more bongo >file &&
	shit add file &&
	EDITOR=./replace shit commit --edit --amend &&
	shit diff-tree -s --format=%s HEAD >msg &&
	./replace expect &&
	test_cmp expect msg
'

test_expect_success '--amend to set message to empty' '
	echo bata >file &&
	shit add file &&
	shit commit -m "unamended" &&
	shit commit --amend --allow-empty-message -m "" &&
	shit diff-tree -s --format=%s HEAD >msg &&
	echo "" >expect &&
	test_cmp expect msg
'

test_expect_success '--amend to set empty message needs --allow-empty-message' '
	echo conga >file &&
	shit add file &&
	shit commit -m "unamended" &&
	test_must_fail shit commit --amend -m "" &&
	shit diff-tree -s --format=%s HEAD >msg &&
	echo "unamended" >expect &&
	test_cmp expect msg
'

test_expect_success '-m --edit' '
	echo amended >expect &&
	shit commit --allow-empty -m buffer &&
	echo bongo bongo >file &&
	shit add file &&
	EDITOR=./editor shit commit -m unamended --edit &&
	shit diff-tree -s  --format=%s HEAD >msg &&
	test_cmp expect msg
'

test_expect_success '-m and -F do not mix' '
	echo enough with the bongos >file &&
	test_must_fail shit commit -F msg -m amending .
'

test_expect_success 'using message from other commit' '
	shit commit -C HEAD^ .
'

test_expect_success 'editing message from other commit' '
	cat >editor <<-\EOF &&
	#!/bin/sh
	sed -e "s/amend/older/g"  <"$1" >"$1-"
	mv "$1-" "$1"
	EOF
	chmod 755 editor &&
	echo hula hula >file &&
	EDITOR=./editor shit commit -c HEAD^ -a
'

test_expect_success 'message from stdin' '
	echo silly new contents >file &&
	echo commit message from stdin |
	shit commit -F - -a
'

test_expect_success 'overriding author from command line' '
	echo gak >file &&
	shit commit -m author \
		--author "Rubber Duck <rduck@convoy.org>" -a >output 2>&1 &&
	grep Rubber.Duck output
'

test_expect_success PERL 'interactive add' '
	echo 7 | test_must_fail shit commit --interactive >out &&
	grep "What now" out
'

test_expect_success PERL "commit --interactive doesn't change index if editor aborts" '
	echo zoo >file &&
	test_must_fail shit diff --exit-code >diff1 &&
	test_write_lines u "*" q |
	(
		EDITOR=: &&
		export EDITOR &&
		test_must_fail shit commit --interactive
	) &&
	shit diff >diff2 &&
	compare_diff_patch diff1 diff2
'

test_expect_success 'editor not invoked if -F is given' '
	cat >editor <<-\EOF &&
	#!/bin/sh
	sed -e s/good/bad/g <"$1" >"$1-"
	mv "$1-" "$1"
	EOF
	chmod 755 editor &&

	echo A good commit message. >msg &&
	echo moo >file &&

	EDITOR=./editor shit commit -a -F msg &&
	shit show -s --pretty=format:%s >subject &&
	grep -q good subject &&

	echo quack >file &&
	echo Another good message. |
	EDITOR=./editor shit commit -a -F - &&
	shit show -s --pretty=format:%s >subject &&
	grep -q good subject
'

test_expect_success 'partial commit that involves removal (1)' '

	shit rm --cached file &&
	mv file elif &&
	shit add elif &&
	shit commit -m "Partial: add elif" elif &&
	shit diff-tree --name-status HEAD^ HEAD >current &&
	echo "A	elif" >expected &&
	test_cmp expected current

'

test_expect_success 'partial commit that involves removal (2)' '

	shit commit -m "Partial: remove file" file &&
	shit diff-tree --name-status HEAD^ HEAD >current &&
	echo "D	file" >expected &&
	test_cmp expected current

'

test_expect_success 'partial commit that involves removal (3)' '

	shit rm --cached elif &&
	echo elif >elif &&
	shit commit -m "Partial: modify elif" elif &&
	shit diff-tree --name-status HEAD^ HEAD >current &&
	echo "M	elif" >expected &&
	test_cmp expected current

'

test_expect_success 'amend commit to fix author' '

	oldtick=$shit_AUTHOR_DATE &&
	test_tick &&
	shit reset --hard &&
	shit cat-file -p HEAD >commit &&
	sed -e "s/author.*/author $author $oldtick/" \
		-e "s/^\(committer.*> \).*$/\1$shit_COMMITTER_DATE/" \
		commit >expected &&
	shit commit --amend --author="$author" &&
	shit cat-file -p HEAD >current &&
	test_cmp expected current

'

test_expect_success 'amend commit to fix date' '

	test_tick &&
	newtick=$shit_AUTHOR_DATE &&
	shit reset --hard &&
	shit cat-file -p HEAD >commit &&
	sed -e "s/author.*/author $author $newtick/" \
		-e "s/^\(committer.*> \).*$/\1$shit_COMMITTER_DATE/" \
		commit >expected &&
	shit commit --amend --date="$newtick" &&
	shit cat-file -p HEAD >current &&
	test_cmp expected current

'

test_expect_success 'amend commit to add signoff' '

	test_commit "msg" file content &&
	shit commit --amend --signoff &&
	test_commit_message HEAD <<-EOF
	msg

	Signed-off-by: $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL>
	EOF
'

test_expect_success 'amend does not add signoff if it already exists' '

	test_commit --signoff "tenor" file newcontent &&
	shit commit --amend --signoff &&
	test_commit_message HEAD <<-EOF
	tenor

	Signed-off-by: $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL>
	EOF
'

test_expect_success 'commit mentions forced date in output' '
	shit commit --amend --date=2010-01-02T03:04:05 >output &&
	grep "Date: *Sat Jan 2 03:04:05 2010" output
'

test_expect_success 'commit complains about completely bogus dates' '
	test_must_fail shit commit --amend --date=seventeen
'

test_expect_success 'commit --date allows approxidate' '
	shit commit --amend \
		--date="midnight the 12th of october, anno domini 1979" &&
	echo "Fri Oct 12 00:00:00 1979 +0000" >expect &&
	shit log -1 --format=%ad >actual &&
	test_cmp expect actual
'

test_expect_success 'sign off (1)' '

	echo 1 >positive &&
	shit add positive &&
	shit commit -s -m "thank you" &&
	shit cat-file commit HEAD >commit &&
	sed -e "1,/^\$/d" commit >actual &&
	(
		echo thank you &&
		echo &&
		shit var shit_COMMITTER_IDENT >ident &&
		sed -e "s/>.*/>/" -e "s/^/Signed-off-by: /" ident
	) >expected &&
	test_cmp expected actual

'

test_expect_success 'sign off (2)' '

	echo 2 >positive &&
	shit add positive &&
	existing="Signed-off-by: Watch This <watchthis@example.com>" &&
	shit commit -s -m "thank you

$existing" &&
	shit cat-file commit HEAD >commit &&
	sed -e "1,/^\$/d" commit >actual &&
	(
		echo thank you &&
		echo &&
		echo $existing &&
		shit var shit_COMMITTER_IDENT >ident &&
		sed -e "s/>.*/>/" -e "s/^/Signed-off-by: /" ident
	) >expected &&
	test_cmp expected actual

'

test_expect_success 'signoff gap' '

	echo 3 >positive &&
	shit add positive &&
	alt="Alt-RFC-822-Header: Value" &&
	shit commit -s -m "welcome

$alt" &&
	shit cat-file commit HEAD >commit &&
	sed -e "1,/^\$/d" commit >actual &&
	(
		echo welcome &&
		echo &&
		echo $alt &&
		shit var shit_COMMITTER_IDENT >ident &&
		sed -e "s/>.*/>/" -e "s/^/Signed-off-by: /" ident
	) >expected &&
	test_cmp expected actual
'

test_expect_success 'signoff gap 2' '

	echo 4 >positive &&
	shit add positive &&
	alt="fixed: 34" &&
	shit commit -s -m "welcome

We have now
$alt" &&
	shit cat-file commit HEAD >commit &&
	sed -e "1,/^\$/d" commit >actual &&
	(
		echo welcome &&
		echo &&
		echo We have now &&
		echo $alt &&
		echo &&
		shit var shit_COMMITTER_IDENT >ident &&
		sed -e "s/>.*/>/" -e "s/^/Signed-off-by: /" ident
	) >expected &&
	test_cmp expected actual
'

test_expect_success 'signoff respects trailer config' '

	echo 5 >positive &&
	shit add positive &&
	shit commit -s -m "subject

non-trailer line
Myfooter: x" &&
	shit cat-file commit HEAD >commit &&
	sed -e "1,/^\$/d" commit >actual &&
	(
		echo subject &&
		echo &&
		echo non-trailer line &&
		echo Myfooter: x &&
		echo &&
		echo "Signed-off-by: $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL>"
	) >expected &&
	test_cmp expected actual &&

	echo 6 >positive &&
	shit add positive &&
	shit -c "trailer.Myfooter.ifexists=add" commit -s -m "subject

non-trailer line
Myfooter: x" &&
	shit cat-file commit HEAD >commit &&
	sed -e "1,/^\$/d" commit >actual &&
	(
		echo subject &&
		echo &&
		echo non-trailer line &&
		echo Myfooter: x &&
		echo "Signed-off-by: $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL>"
	) >expected &&
	test_cmp expected actual
'

test_expect_success 'signoff not confused by ---' '
	cat >expected <<-EOF &&
		subject

		body
		---
		these dashes confuse the parser!

		Signed-off-by: $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL>
	EOF
	# should be a noop, since we already signed
	shit commit --allow-empty --signoff -F expected &&
	shit log -1 --pretty=format:%B >actual &&
	test_cmp expected actual
'

test_expect_success 'multiple -m' '

	>negative &&
	shit add negative &&
	shit commit -m "one" -m "two" -m "three" &&
	shit cat-file commit HEAD >commit &&
	sed -e "1,/^\$/d" commit >actual &&
	(
		echo one &&
		echo &&
		echo two &&
		echo &&
		echo three
	) >expected &&
	test_cmp expected actual

'

test_expect_success 'amend commit to fix author' '

	oldtick=$shit_AUTHOR_DATE &&
	test_tick &&
	shit reset --hard &&
	shit cat-file -p HEAD >commit &&
	sed -e "s/author.*/author $author $oldtick/" \
		-e "s/^\(committer.*> \).*$/\1$shit_COMMITTER_DATE/" \
		commit >expected &&
	shit commit --amend --author="$author" &&
	shit cat-file -p HEAD >current &&
	test_cmp expected current

'

test_expect_success 'shit commit <file> with dirty index' '
	echo tacocat >elif &&
	echo tehlulz >chz &&
	shit add chz &&
	shit commit elif -m "tacocat is a palindrome" &&
	shit show --stat >stat &&
	grep elif stat &&
	shit diff --cached >diff &&
	grep chz diff
'

test_expect_success 'same tree (single parent)' '

	shit reset --hard &&
	test_must_fail shit commit -m empty

'

test_expect_success 'same tree (single parent) --allow-empty' '

	shit commit --allow-empty -m "forced empty" &&
	shit cat-file commit HEAD >commit &&
	grep forced commit

'

test_expect_success 'same tree (merge and amend merge)' '

	shit checkout -b side HEAD^ &&
	echo zero >zero &&
	shit add zero &&
	shit commit -m "add zero" &&
	shit checkout main &&

	shit merge -s ours side -m "empty ok" &&
	shit diff HEAD^ HEAD >actual &&
	test_must_be_empty actual &&

	shit commit --amend -m "empty really ok" &&
	shit diff HEAD^ HEAD >actual &&
	test_must_be_empty actual

'

test_expect_success 'amend using the message from another commit' '

	shit reset --hard &&
	test_tick &&
	shit commit --allow-empty -m "old commit" &&
	old=$(shit rev-parse --verify HEAD) &&
	test_tick &&
	shit commit --allow-empty -m "new commit" &&
	new=$(shit rev-parse --verify HEAD) &&
	test_tick &&
	shit commit --allow-empty --amend -C "$old" &&
	shit show --pretty="format:%ad %s" "$old" >expected &&
	shit show --pretty="format:%ad %s" HEAD >actual &&
	test_cmp expected actual

'

test_expect_success 'amend using the message from a commit named with tag' '

	shit reset --hard &&
	test_tick &&
	shit commit --allow-empty -m "old commit" &&
	old=$(shit rev-parse --verify HEAD) &&
	shit tag -a -m "tag on old" tagged-old HEAD &&
	test_tick &&
	shit commit --allow-empty -m "new commit" &&
	new=$(shit rev-parse --verify HEAD) &&
	test_tick &&
	shit commit --allow-empty --amend -C tagged-old &&
	shit show --pretty="format:%ad %s" "$old" >expected &&
	shit show --pretty="format:%ad %s" HEAD >actual &&
	test_cmp expected actual

'

test_expect_success 'amend can copy notes' '

	shit config notes.rewrite.amend true &&
	shit config notes.rewriteRef "refs/notes/*" &&
	test_commit foo &&
	shit notes add -m"a note" &&
	test_tick &&
	shit commit --amend -m"new foo" &&
	test "$(shit notes show)" = "a note"

'

test_expect_success 'commit a file whose name is a dash' '
	shit reset --hard &&
	test_write_lines 1 2 3 4 5 >./- &&
	shit add ./- &&
	test_tick &&
	shit commit -m "add dash" >output </dev/null &&
	test_grep " changed, 5 insertions" output
'

test_expect_success '--only works on to-be-born branch' '
	# This test relies on having something in the index, as it
	# would not otherwise actually prove much.  So check this.
	test -n "$(shit ls-files)" &&
	shit checkout --orphan orphan &&
	echo foo >newfile &&
	shit add newfile &&
	shit commit --only newfile -m"--only on unborn branch" &&
	echo newfile >expected &&
	shit ls-tree -r --name-only HEAD >actual &&
	test_cmp expected actual
'

test_expect_success '--dry-run with conflicts fixed from a merge' '
	# setup two branches with conflicting information
	# in the same file, resolve the conflict,
	# call commit with --dry-run
	echo "Initial contents, unimportant" >test-file &&
	shit add test-file &&
	shit commit -m "Initial commit" &&
	echo "commit-1-state" >test-file &&
	shit commit -m "commit 1" -i test-file &&
	shit tag commit-1 &&
	shit checkout -b branch-2 HEAD^1 &&
	echo "commit-2-state" >test-file &&
	shit commit -m "commit 2" -i test-file &&
	test_must_fail shit merge --no-commit commit-1 &&
	echo "commit-2-state" >test-file &&
	shit add test-file &&
	shit commit --dry-run &&
	shit commit -m "conflicts fixed from merge."
'

test_expect_success '--dry-run --short' '
	>test-file &&
	shit add test-file &&
	shit commit --dry-run --short
'

test_done
