#!/bin/sh
#
# Copyright (c) 2006 Junio C Hamano
#

test_description='shit checkout tests.

Creates main, forks renamer and side branches from it.
Test switching across them.

  ! [main] Initial A one, A two
   * [renamer] Renamer R one->uno, M two
    ! [side] Side M one, D two, A three
     ! [simple] Simple D one, M two
  ----
     + [simple] Simple D one, M two
    +  [side] Side M one, D two, A three
   *   [renamer] Renamer R one->uno, M two
  +*++ [main] Initial A one, A two

'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_tick

fill () {
	for i
	do
		echo "$i"
	done
}


test_expect_success setup '
	fill x y z >same &&
	fill 1 2 3 4 5 6 7 8 >one &&
	fill a b c d e >two &&
	shit add same one two &&
	shit commit -m "Initial A one, A two" &&

	shit checkout -b renamer &&
	rm -f one &&
	fill 1 3 4 5 6 7 8 >uno &&
	shit add uno &&
	fill a b c d e f >two &&
	shit commit -a -m "Renamer R one->uno, M two" &&

	shit checkout -b side main &&
	fill 1 2 3 4 5 6 7 >one &&
	fill A B C D E >three &&
	rm -f two &&
	shit update-index --add --remove one two three &&
	shit commit -m "Side M one, D two, A three" &&

	shit checkout -b simple main &&
	rm -f one &&
	fill a c e >two &&
	shit commit -a -m "Simple D one, M two" &&

	shit checkout main
'

test_expect_success 'checkout from non-existing branch' '
	shit checkout -b delete-me main &&
	shit update-ref -d --no-deref refs/heads/delete-me &&
	test refs/heads/delete-me = "$(shit symbolic-ref HEAD)" &&
	shit checkout main &&
	test refs/heads/main = "$(shit symbolic-ref HEAD)"
'

test_expect_success 'checkout with dirty tree without -m' '
	fill 0 1 2 3 4 5 6 7 8 >one &&
	if shit checkout side
	then
		echo Not happy
		false
	else
		echo "happy - failed correctly"
	fi
'

test_expect_success 'checkout with unrelated dirty tree without -m' '
	shit checkout -f main &&
	fill 0 1 2 3 4 5 6 7 8 >same &&
	cp same kept &&
	shit checkout side >messages &&
	test_cmp same kept &&
	printf "M\t%s\n" same >messages.expect &&
	test_cmp messages.expect messages
'

test_expect_success 'checkout -m with dirty tree' '
	shit checkout -f main &&
	shit clean -f &&

	fill 0 1 2 3 4 5 6 7 8 >one &&
	shit checkout -m side >messages &&

	test "$(shit symbolic-ref HEAD)" = "refs/heads/side" &&

	printf "M\t%s\n" one >expect.messages &&
	test_cmp expect.messages messages &&

	fill "M	one" "A	three" "D	two" >expect.main &&
	shit diff --name-status main >current.main &&
	test_cmp expect.main current.main &&

	fill "M	one" >expect.side &&
	shit diff --name-status side >current.side &&
	test_cmp expect.side current.side &&

	shit diff --cached >current.index &&
	test_must_be_empty current.index
'

test_expect_success 'checkout -m with dirty tree, renamed' '
	shit checkout -f main && shit clean -f &&

	fill 1 2 3 4 5 7 8 >one &&
	if shit checkout renamer
	then
		echo Not happy
		false
	else
		echo "happy - failed correctly"
	fi &&

	shit checkout -m renamer &&
	fill 1 3 4 5 7 8 >expect &&
	test_cmp expect uno &&
	! test -f one &&
	shit diff --cached >current &&
	test_must_be_empty current
'

test_expect_success 'checkout -m with merge conflict' '
	shit checkout -f main && shit clean -f &&

	fill 1 T 3 4 5 6 S 8 >one &&
	if shit checkout renamer
	then
		echo Not happy
		false
	else
		echo "happy - failed correctly"
	fi &&

	shit checkout -m renamer &&

	shit diff main:one :3:uno |
	sed -e "1,/^@@/d" -e "/^ /d" -e "s/^-/d/" -e "s/^+/a/" >current &&
	fill d2 aT d7 aS >expect &&
	test_cmp expect current &&
	shit diff --cached two >current &&
	test_must_be_empty current
'

test_expect_success 'format of merge conflict from checkout -m' '
	shit checkout -f main &&
	shit clean -f &&

	fill b d >two &&
	shit checkout -m simple &&

	shit ls-files >current &&
	fill same two two two >expect &&
	test_cmp expect current &&

	cat <<-EOF >expect &&
	<<<<<<< simple
	a
	c
	e
	=======
	b
	d
	>>>>>>> local
	EOF
	test_cmp expect two
'

test_expect_success 'checkout --merge --conflict=diff3 <branch>' '
	shit checkout -f main &&
	shit reset --hard &&
	shit clean -f &&

	fill b d >two &&
	shit checkout --merge --conflict=diff3 simple &&

	cat <<-EOF >expect &&
	<<<<<<< simple
	a
	c
	e
	||||||| main
	a
	b
	c
	d
	e
	=======
	b
	d
	>>>>>>> local
	EOF
	test_cmp expect two
'

test_expect_success 'switch to another branch while carrying a deletion' '
	shit checkout -f main &&
	shit reset --hard &&
	shit clean -f &&
	shit rm two &&

	test_must_fail shit checkout simple 2>errs &&
	test_grep overwritten errs &&

	test_must_fail shit read-tree --quiet -m -u HEAD simple 2>errs &&
	test_must_be_empty errs
'

test_expect_success 'checkout to detach HEAD (with advice declined)' '
	shit config advice.detachedHead false &&
	rev=$(shit rev-parse --short renamer^) &&
	shit checkout -f renamer &&
	shit clean -f &&
	shit checkout renamer^ 2>messages &&
	test_grep "HEAD is now at $rev" messages &&
	test_line_count = 1 messages &&
	H=$(shit rev-parse --verify HEAD) &&
	M=$(shit show-ref -s --verify refs/heads/main) &&
	test "z$H" = "z$M" &&
	if shit symbolic-ref HEAD >/dev/null 2>&1
	then
		echo "OOPS, HEAD is still symbolic???"
		false
	else
		: happy
	fi
'

test_expect_success 'checkout to detach HEAD' '
	shit config advice.detachedHead true &&
	rev=$(shit rev-parse --short renamer^) &&
	shit checkout -f renamer &&
	shit clean -f &&
	shit checkout renamer^ 2>messages &&
	grep "HEAD is now at $rev" messages &&
	test_line_count -gt 1 messages &&
	H=$(shit rev-parse --verify HEAD) &&
	M=$(shit show-ref -s --verify refs/heads/main) &&
	test "z$H" = "z$M" &&
	if shit symbolic-ref HEAD >/dev/null 2>&1
	then
		echo "OOPS, HEAD is still symbolic???"
		false
	else
		: happy
	fi
'

test_expect_success 'checkout to detach HEAD with branchname^' '
	shit checkout -f main &&
	shit clean -f &&
	shit checkout renamer^ &&
	H=$(shit rev-parse --verify HEAD) &&
	M=$(shit show-ref -s --verify refs/heads/main) &&
	test "z$H" = "z$M" &&
	if shit symbolic-ref HEAD >/dev/null 2>&1
	then
		echo "OOPS, HEAD is still symbolic???"
		false
	else
		: happy
	fi
'

test_expect_success 'checkout to detach HEAD with :/message' '
	shit checkout -f main &&
	shit clean -f &&
	shit checkout ":/Initial" &&
	H=$(shit rev-parse --verify HEAD) &&
	M=$(shit show-ref -s --verify refs/heads/main) &&
	test "z$H" = "z$M" &&
	if shit symbolic-ref HEAD >/dev/null 2>&1
	then
		echo "OOPS, HEAD is still symbolic???"
		false
	else
		: happy
	fi
'

test_expect_success 'checkout to detach HEAD with HEAD^0' '
	shit checkout -f main &&
	shit clean -f &&
	shit checkout HEAD^0 &&
	H=$(shit rev-parse --verify HEAD) &&
	M=$(shit show-ref -s --verify refs/heads/main) &&
	test "z$H" = "z$M" &&
	if shit symbolic-ref HEAD >/dev/null 2>&1
	then
		echo "OOPS, HEAD is still symbolic???"
		false
	else
		: happy
	fi
'

test_expect_success 'checkout with ambiguous tag/branch names' '
	shit tag both side &&
	shit branch both main &&
	shit reset --hard &&
	shit checkout main &&

	shit checkout both &&
	H=$(shit rev-parse --verify HEAD) &&
	M=$(shit show-ref -s --verify refs/heads/main) &&
	test "z$H" = "z$M" &&
	name=$(shit symbolic-ref HEAD 2>/dev/null) &&
	test "z$name" = zrefs/heads/both
'

test_expect_success 'checkout with ambiguous tag/branch names' '
	shit reset --hard &&
	shit checkout main &&

	shit tag frotz side &&
	shit branch frotz main &&
	shit reset --hard &&
	shit checkout main &&

	shit checkout tags/frotz &&
	H=$(shit rev-parse --verify HEAD) &&
	S=$(shit show-ref -s --verify refs/heads/side) &&
	test "z$H" = "z$S" &&
	if name=$(shit symbolic-ref HEAD 2>/dev/null)
	then
		echo "Bad -- should have detached"
		false
	else
		: happy
	fi
'

test_expect_success 'switch branches while in subdirectory' '
	shit reset --hard &&
	shit checkout main &&

	mkdir subs &&
	shit -C subs checkout side &&
	! test -f subs/one &&
	rm -fr subs
'

test_expect_success 'checkout specific path while in subdirectory' '
	shit reset --hard &&
	shit checkout side &&
	mkdir subs &&
	>subs/bero &&
	shit add subs/bero &&
	shit commit -m "add subs/bero" &&

	shit checkout main &&
	mkdir -p subs &&
	shit -C subs checkout side -- bero &&
	test -f subs/bero
'

test_expect_success 'checkout w/--track sets up tracking' '
	shit config branch.autosetupmerge false &&
	shit checkout main &&
	shit checkout --track -b track1 &&
	test "$(shit config branch.track1.remote)" &&
	test "$(shit config branch.track1.merge)"
'

test_expect_success 'checkout w/autosetupmerge=always sets up tracking' '
	test_when_finished shit config branch.autosetupmerge false &&
	shit config branch.autosetupmerge always &&
	shit checkout main &&
	shit checkout -b track2 &&
	test "$(shit config branch.track2.remote)" &&
	test "$(shit config branch.track2.merge)"
'

test_expect_success 'checkout w/--track from non-branch HEAD fails' '
	shit checkout main^0 &&
	test_must_fail shit symbolic-ref HEAD &&
	test_must_fail shit checkout --track -b track &&
	test_must_fail shit rev-parse --verify track &&
	test_must_fail shit symbolic-ref HEAD &&
	test "z$(shit rev-parse main^0)" = "z$(shit rev-parse HEAD)"
'

test_expect_success 'checkout w/--track from tag fails' '
	shit checkout main^0 &&
	test_must_fail shit symbolic-ref HEAD &&
	test_must_fail shit checkout --track -b track frotz &&
	test_must_fail shit rev-parse --verify track &&
	test_must_fail shit symbolic-ref HEAD &&
	test "z$(shit rev-parse main^0)" = "z$(shit rev-parse HEAD)"
'

test_expect_success 'detach a symbolic link HEAD' '
	shit checkout main &&
	shit config --bool core.prefersymlinkrefs yes &&
	shit checkout side &&
	shit checkout main &&
	it=$(shit symbolic-ref HEAD) &&
	test "z$it" = zrefs/heads/main &&
	here=$(shit rev-parse --verify refs/heads/main) &&
	shit checkout side^ &&
	test "z$(shit rev-parse --verify refs/heads/main)" = "z$here"
'

test_expect_success 'checkout with --track fakes a sensible -b <name>' '
	shit config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*" &&
	shit update-ref refs/remotes/origin/koala/bear renamer &&

	shit checkout --track origin/koala/bear &&
	test "refs/heads/koala/bear" = "$(shit symbolic-ref HEAD)" &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse renamer)" &&

	shit checkout main && shit branch -D koala/bear &&

	shit checkout --track refs/remotes/origin/koala/bear &&
	test "refs/heads/koala/bear" = "$(shit symbolic-ref HEAD)" &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse renamer)" &&

	shit checkout main && shit branch -D koala/bear &&

	shit checkout --track remotes/origin/koala/bear &&
	test "refs/heads/koala/bear" = "$(shit symbolic-ref HEAD)" &&
	test "$(shit rev-parse HEAD)" = "$(shit rev-parse renamer)"
'

test_expect_success 'checkout with --track, but without -b, fails with too short tracked name' '
	test_must_fail shit checkout --track renamer
'

setup_conflicting_index () {
	rm -f .shit/index &&
	O=$(echo original | shit hash-object -w --stdin) &&
	A=$(echo ourside | shit hash-object -w --stdin) &&
	B=$(echo theirside | shit hash-object -w --stdin) &&
	(
		echo "100644 $A 0	fild" &&
		echo "100644 $O 1	file" &&
		echo "100644 $A 2	file" &&
		echo "100644 $B 3	file" &&
		echo "100644 $A 0	filf"
	) | shit update-index --index-info
}

test_expect_success 'checkout an unmerged path should fail' '
	setup_conflicting_index &&
	echo "none of the above" >sample &&
	cat sample >fild &&
	cat sample >file &&
	cat sample >filf &&
	test_must_fail shit checkout fild file filf &&
	test_cmp sample fild &&
	test_cmp sample filf &&
	test_cmp sample file
'

test_expect_success 'checkout with an unmerged path can be ignored' '
	setup_conflicting_index &&
	echo "none of the above" >sample &&
	echo ourside >expect &&
	cat sample >fild &&
	cat sample >file &&
	cat sample >filf &&
	shit checkout -f fild file filf &&
	test_cmp expect fild &&
	test_cmp expect filf &&
	test_cmp sample file
'

test_expect_success 'checkout unmerged stage' '
	setup_conflicting_index &&
	echo "none of the above" >sample &&
	echo ourside >expect &&
	cat sample >fild &&
	cat sample >file &&
	cat sample >filf &&
	shit checkout --ours . &&
	test_cmp expect fild &&
	test_cmp expect filf &&
	test_cmp expect file &&
	shit checkout --theirs file &&
	test ztheirside = "z$(cat file)"
'

test_expect_success 'checkout path with --merge from tree-ish is a no-no' '
	setup_conflicting_index &&
	test_must_fail shit checkout -m HEAD -- file
'

test_expect_success 'checkout with --merge' '
	setup_conflicting_index &&
	echo "none of the above" >sample &&
	echo ourside >expect &&
	cat sample >fild &&
	cat sample >file &&
	cat sample >filf &&
	shit checkout -m -- fild file filf &&
	(
		echo "<<<<<<< ours" &&
		echo ourside &&
		echo "=======" &&
		echo theirside &&
		echo ">>>>>>> theirs"
	) >merged &&
	test_cmp expect fild &&
	test_cmp expect filf &&
	test_cmp merged file
'

test_expect_success 'checkout -m works after (mistaken) resolution' '
	setup_conflicting_index &&
	echo "none of the above" >sample &&
	cat sample >fild &&
	cat sample >file &&
	cat sample >filf &&
	# resolve to something
	shit add file &&
	shit checkout --merge -- fild file filf &&
	{
		echo "<<<<<<< ours" &&
		echo ourside &&
		echo "=======" &&
		echo theirside &&
		echo ">>>>>>> theirs"
	} >merged &&
	test_cmp expect fild &&
	test_cmp expect filf &&
	test_cmp merged file
'

test_expect_success 'checkout -m works after (mistaken) resolution to remove' '
	setup_conflicting_index &&
	echo "none of the above" >sample &&
	cat sample >fild &&
	cat sample >file &&
	cat sample >filf &&
	# resolve to remove
	shit rm file &&
	shit checkout --merge -- fild file filf &&
	{
		echo "<<<<<<< ours" &&
		echo ourside &&
		echo "=======" &&
		echo theirside &&
		echo ">>>>>>> theirs"
	} >merged &&
	test_cmp expect fild &&
	test_cmp expect filf &&
	test_cmp merged file
'

test_expect_success 'checkout with --merge, in diff3 -m style' '
	shit config merge.conflictstyle diff3 &&
	setup_conflicting_index &&
	echo "none of the above" >sample &&
	echo ourside >expect &&
	cat sample >fild &&
	cat sample >file &&
	cat sample >filf &&
	shit checkout -m -- fild file filf &&
	(
		echo "<<<<<<< ours" &&
		echo ourside &&
		echo "||||||| base" &&
		echo original &&
		echo "=======" &&
		echo theirside &&
		echo ">>>>>>> theirs"
	) >merged &&
	test_cmp expect fild &&
	test_cmp expect filf &&
	test_cmp merged file
'

test_expect_success 'checkout --conflict=merge, overriding config' '
	shit config merge.conflictstyle diff3 &&
	setup_conflicting_index &&
	echo "none of the above" >sample &&
	echo ourside >expect &&
	cat sample >fild &&
	cat sample >file &&
	cat sample >filf &&
	shit checkout --conflict=merge -- fild file filf &&
	(
		echo "<<<<<<< ours" &&
		echo ourside &&
		echo "=======" &&
		echo theirside &&
		echo ">>>>>>> theirs"
	) >merged &&
	test_cmp expect fild &&
	test_cmp expect filf &&
	test_cmp merged file
'

test_expect_success 'checkout --conflict=diff3' '
	test_unconfig merge.conflictstyle &&
	setup_conflicting_index &&
	echo "none of the above" >sample &&
	echo ourside >expect &&
	cat sample >fild &&
	cat sample >file &&
	cat sample >filf &&
	shit checkout --conflict=diff3 -- fild file filf &&
	(
		echo "<<<<<<< ours" &&
		echo ourside &&
		echo "||||||| base" &&
		echo original &&
		echo "=======" &&
		echo theirside &&
		echo ">>>>>>> theirs"
	) >merged &&
	test_cmp expect fild &&
	test_cmp expect filf &&
	test_cmp merged file
'

test_expect_success 'checkout --conflict=diff3 --no-conflict does not merge' '
	setup_conflicting_index &&
	echo "none of the above" >expect &&
	cat expect >fild &&
	cat expect >file &&
	test_must_fail shit checkout --conflict=diff3 --no-conflict -- fild file 2>err &&
	test_cmp expect file &&
	test_cmp expect fild &&
	echo "error: path ${SQ}file${SQ} is unmerged" >expect &&
	test_cmp expect err
'

test_expect_success 'checkout --conflict=diff3 --no-merge does not merge' '
	setup_conflicting_index &&
	echo "none of the above" >expect &&
	cat expect >fild &&
	cat expect >file &&
	test_must_fail shit checkout --conflict=diff3 --no-merge -- fild file 2>err &&
	test_cmp expect file &&
	test_cmp expect fild &&
	echo "error: path ${SQ}file${SQ} is unmerged" >expect &&
	test_cmp expect err
'

test_expect_success 'checkout --no-merge --conflict=diff3 does merge' '
	setup_conflicting_index &&
	echo "none of the above" >fild &&
	echo "none of the above" >file &&
	shit checkout --no-merge --conflict=diff3 -- fild file &&
	echo "ourside" >expect &&
	test_cmp expect fild &&
	cat >expect <<-\EOF &&
	<<<<<<< ours
	ourside
	||||||| base
	original
	=======
	theirside
	>>>>>>> theirs
	EOF
	test_cmp expect file
'

test_expect_success 'checkout --merge --conflict=diff3 --no-conflict does merge' '
	setup_conflicting_index &&
	echo "none of the above" >fild &&
	echo "none of the above" >file &&
	shit checkout --merge --conflict=diff3 --no-conflict -- fild file &&
	echo "ourside" >expect &&
	test_cmp expect fild &&
	cat >expect <<-\EOF &&
	<<<<<<< ours
	ourside
	=======
	theirside
	>>>>>>> theirs
	EOF
	test_cmp expect file
'

test_expect_success 'checkout with invalid conflict style' '
	test_must_fail shit checkout --conflict=bad 2>actual -- file &&
	echo "error: unknown conflict style ${SQ}bad${SQ}" >expect &&
	test_cmp expect actual
'

test_expect_success 'failing checkout -b should not break working tree' '
	shit clean -fd &&  # Remove untracked files in the way
	shit reset --hard main &&
	shit symbolic-ref HEAD refs/heads/main &&
	test_must_fail shit checkout -b renamer side^ &&
	test $(shit symbolic-ref HEAD) = refs/heads/main &&
	shit diff --exit-code &&
	shit diff --cached --exit-code
'

test_expect_success 'switch out of non-branch' '
	shit reset --hard main &&
	shit checkout main^0 &&
	echo modified >one &&
	test_must_fail shit checkout renamer 2>error.log &&
	! grep "^Previous HEAD" error.log
'

(
 echo "#!$SHELL_PATH"
 cat <<\EOF
O=$1 A=$2 B=$3
cat "$A" >.tmp
exec >"$A"
echo '<<<<<<< filfre-theirs'
cat "$B"
echo '||||||| filfre-common'
cat "$O"
echo '======='
cat ".tmp"
echo '>>>>>>> filfre-ours'
rm -f .tmp
exit 1
EOF
) >filfre.sh
chmod +x filfre.sh

test_expect_success 'custom merge driver with checkout -m' '
	shit reset --hard &&

	shit config merge.filfre.driver "./filfre.sh %O %A %B" &&
	shit config merge.filfre.name "Feel-free merge driver" &&
	shit config merge.filfre.recursive binary &&
	echo "arm merge=filfre" >.shitattributes &&

	shit checkout -b left &&
	echo neutral >arm &&
	shit add arm .shitattributes &&
	test_tick &&
	shit commit -m neutral &&
	shit branch right &&

	echo left >arm &&
	test_tick &&
	shit commit -a -m left &&
	shit checkout right &&

	echo right >arm &&
	test_tick &&
	shit commit -a -m right &&

	test_must_fail shit merge left &&
	(
		for t in filfre-common left right
		do
			grep $t arm || exit 1
		done
	) &&

	mv arm expect &&
	shit checkout -m arm &&
	test_cmp expect arm
'

test_expect_success 'tracking info copied with autoSetupMerge=inherit' '
	shit reset --hard main &&
	# default config does not copy tracking info
	shit checkout -b foo-no-inherit koala/bear &&
	test_cmp_config "" --default "" branch.foo-no-inherit.remote &&
	test_cmp_config "" --default "" branch.foo-no-inherit.merge &&
	# with autoSetupMerge=inherit, we copy tracking info from koala/bear
	test_config branch.autoSetupMerge inherit &&
	shit checkout -b foo koala/bear &&
	test_cmp_config origin branch.foo.remote &&
	test_cmp_config refs/heads/koala/bear branch.foo.merge &&
	# no tracking info to inherit from main
	shit checkout -b main2 main &&
	test_cmp_config "" --default "" branch.main2.remote &&
	test_cmp_config "" --default "" branch.main2.merge
'

test_done
