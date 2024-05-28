#!/bin/sh

test_description='shit filter-branch'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY/lib-gpg.sh"

test_expect_success 'setup' '
	test_commit A &&
	shit_COMMITTER_DATE="@0 +0000" shit_AUTHOR_DATE="@0 +0000" &&
	test_commit --notick B &&
	shit checkout -b branch B &&
	test_commit D &&
	mkdir dir &&
	test_commit dir/D &&
	test_commit E &&
	shit checkout main &&
	test_commit C &&
	shit checkout branch &&
	shit merge C &&
	shit tag F &&
	test_commit G &&
	test_commit H
'
# * (HEAD, branch) H
# * G
# *   Merge commit 'C' into branch
# |\
# | * (main) C
# * | E
# * | dir/D
# * | D
# |/
# * B
# * A


H=$(shit rev-parse H)

test_expect_success 'rewrite identically' '
	shit filter-branch branch
'
test_expect_success 'result is really identical' '
	test $H = $(shit rev-parse HEAD)
'

test_expect_success 'rewrite bare repository identically' '
	(shit config core.bare true && cd .shit &&
	 shit filter-branch branch > filter-output 2>&1 &&
	! grep fatal filter-output)
'
shit config core.bare false
test_expect_success 'result is really identical' '
	test $H = $(shit rev-parse HEAD)
'

TRASHDIR=$(pwd)
test_expect_success 'correct shit_DIR while using -d' '
	mkdir drepo &&
	( cd drepo &&
	shit init &&
	test_commit drepo &&
	shit filter-branch -d "$TRASHDIR/dfoo" \
		--index-filter "cp \"$TRASHDIR\"/dfoo/backup-refs \"$TRASHDIR\"" \
	) &&
	grep drepo "$TRASHDIR/backup-refs"
'

test_expect_success 'tree-filter works with -d' '
	shit init drepo-tree &&
	(
		cd drepo-tree &&
		test_commit one &&
		shit filter-branch -d "$TRASHDIR/dfoo" \
			--tree-filter "echo changed >one.t" &&
		echo changed >expect &&
		shit cat-file blob HEAD:one.t >actual &&
		test_cmp expect actual &&
		test_cmp one.t actual
	)
'

test_expect_success 'Fail if commit filter fails' '
	test_must_fail shit filter-branch -f --commit-filter "exit 1" HEAD
'

test_expect_success 'rewrite, renaming a specific file' '
	shit filter-branch -f --tree-filter "mv D.t doh || :" HEAD
'

test_expect_success 'test that the file was renamed' '
	test D = "$(shit show HEAD:doh --)" &&
	! test -f D.t &&
	test -f doh &&
	test D = "$(cat doh)"
'

test_expect_success 'rewrite, renaming a specific directory' '
	shit filter-branch -f --tree-filter "mv dir diroh || :" HEAD
'

test_expect_success 'test that the directory was renamed' '
	test dir/D = "$(shit show HEAD:diroh/D.t --)" &&
	! test -d dir &&
	test -d diroh &&
	! test -d diroh/dir &&
	test -f diroh/D.t &&
	test dir/D = "$(cat diroh/D.t)"
'

V=$(shit rev-parse HEAD)

test_expect_success 'populate --state-branch' '
	shit filter-branch --state-branch state -f --tree-filter "touch file || :" HEAD
'

W=$(shit rev-parse HEAD)

test_expect_success 'using --state-branch to skip already rewritten commits' '
	test_when_finished shit reset --hard $V &&
	shit reset --hard $V &&
	shit filter-branch --state-branch state -f --tree-filter "touch file || :" HEAD &&
	test_cmp_rev $W HEAD
'

shit tag oldD HEAD~4
test_expect_success 'rewrite one branch, keeping a side branch' '
	shit branch modD oldD &&
	shit filter-branch -f --tree-filter "mv B.t boh || :" D..modD
'

test_expect_success 'common ancestor is still common (unchanged)' '
	test "$(shit merge-base modD D)" = "$(shit rev-parse B)"
'

test_expect_success 'filter subdirectory only' '
	mkdir subdir &&
	touch subdir/new &&
	shit add subdir/new &&
	test_tick &&
	shit commit -m "subdir" &&
	echo H > A.t &&
	test_tick &&
	shit commit -m "not subdir" A.t &&
	echo A > subdir/new &&
	test_tick &&
	shit commit -m "again subdir" subdir/new &&
	shit rm A.t &&
	test_tick &&
	shit commit -m "again not subdir" &&
	shit branch sub &&
	shit branch sub-earlier HEAD~2 &&
	shit filter-branch -f --subdirectory-filter subdir \
		refs/heads/sub refs/heads/sub-earlier
'

test_expect_success 'subdirectory filter result looks okay' '
	test 2 = $(shit rev-list sub | wc -l) &&
	shit show sub:new &&
	test_must_fail shit show sub:subdir &&
	shit show sub-earlier:new &&
	test_must_fail shit show sub-earlier:subdir
'

test_expect_success 'more setup' '
	shit checkout main &&
	mkdir subdir &&
	echo A > subdir/new &&
	shit add subdir/new &&
	test_tick &&
	shit commit -m "subdir on main" subdir/new &&
	shit rm A.t &&
	test_tick &&
	shit commit -m "again subdir on main" &&
	shit merge branch
'

test_expect_success 'use index-filter to move into a subdirectory' '
	shit branch directorymoved &&
	shit filter-branch -f --index-filter \
		 "shit ls-files -s | sed \"s-	-&newsubdir/-\" |
	          shit_INDEX_FILE=\$shit_INDEX_FILE.new \
			shit update-index --index-info &&
		  mv \"\$shit_INDEX_FILE.new\" \"\$shit_INDEX_FILE\"" directorymoved &&
	shit diff --exit-code HEAD directorymoved:newsubdir
'

test_expect_success 'stops when msg filter fails' '
	old=$(shit rev-parse HEAD) &&
	test_must_fail shit filter-branch -f --msg-filter false HEAD &&
	test $old = $(shit rev-parse HEAD) &&
	rm -rf .shit-rewrite
'

test_expect_success 'author information is preserved' '
	: > i &&
	shit add i &&
	test_tick &&
	shit_AUTHOR_NAME="B V Uips" shit commit -m bvuips &&
	shit branch preserved-author &&
	(sane_unset shit_AUTHOR_NAME &&
	 shit filter-branch -f --msg-filter "cat; \
			test \$shit_COMMIT != $(shit rev-parse main) || \
			echo Hallo" \
		preserved-author) &&
	shit rev-list --author="B V Uips" preserved-author >actual &&
	test_line_count = 1 actual
'

test_expect_success "remove a certain author's commits" '
	echo i > i &&
	test_tick &&
	shit commit -m i i &&
	shit branch removed-author &&
	shit filter-branch -f --commit-filter "\
		if [ \"\$shit_AUTHOR_NAME\" = \"B V Uips\" ];\
		then\
			skip_commit \"\$@\";
		else\
			shit commit-tree \"\$@\";\
		fi" removed-author &&
	cnt1=$(shit rev-list main | wc -l) &&
	cnt2=$(shit rev-list removed-author | wc -l) &&
	test $cnt1 -eq $(($cnt2 + 1)) &&
	shit rev-list --author="B V Uips" removed-author >actual &&
	test_line_count = 0 actual
'

test_expect_success 'barf on invalid name' '
	test_must_fail shit filter-branch -f main xy-problem &&
	test_must_fail shit filter-branch -f HEAD^
'

test_expect_success '"map" works in commit filter' '
	shit filter-branch -f --commit-filter "\
		parent=\$(shit rev-parse \$shit_COMMIT^) &&
		mapped=\$(map \$parent) &&
		actual=\$(echo \"\$@\" | sed \"s/^.*-p //\") &&
		test \$mapped = \$actual &&
		shit commit-tree \"\$@\";" main~2..main &&
	shit rev-parse --verify main
'

test_expect_success 'Name needing quotes' '

	shit checkout -b rerere A &&
	mkdir foo &&
	name="れれれ" &&
	>foo/$name &&
	shit add foo &&
	shit commit -m "Adding a file" &&
	shit filter-branch --tree-filter "rm -fr foo" &&
	test_must_fail shit ls-files --error-unmatch "foo/$name" &&
	test $(shit rev-parse --verify rerere) != $(shit rev-parse --verify A)

'

test_expect_success 'Subdirectory filter with disappearing trees' '
	shit reset --hard &&
	shit checkout main &&

	mkdir foo &&
	touch foo/bar &&
	shit add foo &&
	test_tick &&
	shit commit -m "Adding foo" &&

	shit rm -r foo &&
	test_tick &&
	shit commit -m "Removing foo" &&

	mkdir foo &&
	touch foo/bar &&
	shit add foo &&
	test_tick &&
	shit commit -m "Re-adding foo" &&

	shit filter-branch -f --subdirectory-filter foo &&
	shit rev-list main >actual &&
	test_line_count = 3 actual
'

test_expect_success 'Tag name filtering retains tag message' '
	shit tag -m atag T &&
	shit cat-file tag T > expect &&
	shit filter-branch -f --tag-name-filter cat &&
	shit cat-file tag T > actual &&
	test_cmp expect actual
'

faux_gpg_tag='object XXXXXX
type commit
tag S
tagger T A Gger <tagger@example.com> 1206026339 -0500

This is a faux gpg signed tag.
-----BEGIN PGP SIGNATURE-----
Version: FauxGPG v0.0.0 (FAUX/Linux)

gdsfoewhxu/6l06f1kxyxhKdZkrcbaiOMtkJUA9ITAc1mlamh0ooasxkH1XwMbYQ
acmwXaWET20H0GeAGP+7vow=
=agpO
-----END PGP SIGNATURE-----
'
test_expect_success 'Tag name filtering strips gpg signature' '
	sha1=$(shit rev-parse HEAD) &&
	sha1t=$(echo "$faux_gpg_tag" | sed -e s/XXXXXX/$sha1/ | shit mktag) &&
	shit update-ref "refs/tags/S" "$sha1t" &&
	echo "$faux_gpg_tag" | sed -e s/XXXXXX/$sha1/ | head -n 6 > expect &&
	shit filter-branch -f --tag-name-filter cat &&
	shit cat-file tag S > actual &&
	test_cmp expect actual
'

test_expect_success GPG 'Filtering retains message of gpg signed commit' '
	mkdir gpg &&
	touch gpg/foo &&
	shit add gpg &&
	test_tick &&
	shit commit -S -m "Adding gpg" &&

	shit log -1 --format="%s" > expect &&
	shit filter-branch -f --msg-filter "cat" &&
	shit log -1 --format="%s" > actual &&
	test_cmp expect actual
'

test_expect_success 'Tag name filtering allows slashes in tag names' '
	shit tag -m tag-with-slash X/1 &&
	shit cat-file tag X/1 | sed -e s,X/1,X/2, > expect &&
	shit filter-branch -f --tag-name-filter "echo X/2" &&
	shit cat-file tag X/2 > actual &&
	test_cmp expect actual
'
test_expect_success 'setup --prune-empty comparisons' '
	shit checkout --orphan main-no-a &&
	shit rm -rf . &&
	unset test_tick &&
	test_tick &&
	shit_COMMITTER_DATE="@0 +0000" shit_AUTHOR_DATE="@0 +0000" &&
	test_commit --notick B B.t B Bx &&
	shit checkout -b branch-no-a Bx &&
	test_commit D D.t D Dx &&
	mkdir dir &&
	test_commit dir/D dir/D.t dir/D dir/Dx &&
	test_commit E E.t E Ex &&
	shit checkout main-no-a &&
	test_commit C C.t C Cx &&
	shit checkout branch-no-a &&
	shit merge Cx -m "Merge tag '\''C'\'' into branch" &&
	shit tag Fx &&
	test_commit G G.t G Gx &&
	test_commit H H.t H Hx &&
	shit checkout branch
'

test_expect_success 'Prune empty commits' '
	shit rev-list HEAD > expect &&
	test_commit to_remove &&
	shit filter-branch -f --index-filter "shit update-index --remove to_remove.t" --prune-empty HEAD &&
	shit rev-list HEAD > actual &&
	test_cmp expect actual
'

test_expect_success 'prune empty collapsed merges' '
	test_config merge.ff false &&
	shit rev-list HEAD >expect &&
	test_commit to_remove_2 &&
	shit reset --hard HEAD^ &&
	test_merge non-ff to_remove_2 &&
	shit filter-branch -f --index-filter "shit update-index --remove to_remove_2.t" --prune-empty HEAD &&
	shit rev-list HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'prune empty works even without index/tree filters' '
	shit rev-list HEAD >expect &&
	shit commit --allow-empty -m empty &&
	shit filter-branch -f --prune-empty HEAD &&
	shit rev-list HEAD >actual &&
	test_cmp expect actual
'

test_expect_success '--prune-empty is able to prune root commit' '
	shit rev-list branch-no-a >expect &&
	shit branch testing H &&
	shit filter-branch -f --prune-empty --index-filter "shit update-index --remove A.t" testing &&
	shit rev-list testing >actual &&
	shit branch -D testing &&
	test_cmp expect actual
'

test_expect_success '--prune-empty is able to prune entire branch' '
	shit branch prune-entire B &&
	shit filter-branch -f --prune-empty --index-filter "shit update-index --remove A.t B.t" prune-entire &&
	test_must_fail shit rev-parse refs/heads/prune-entire &&
	test_must_fail shit reflog exists refs/heads/prune-entire
'

test_expect_success '--remap-to-ancestor with filename filters' '
	shit checkout main &&
	shit reset --hard A &&
	test_commit add-foo foo 1 &&
	shit branch moved-foo &&
	test_commit add-bar bar a &&
	shit branch invariant &&
	orig_invariant=$(shit rev-parse invariant) &&
	shit branch moved-bar &&
	test_commit change-foo foo 2 &&
	shit filter-branch -f --remap-to-ancestor \
		moved-foo moved-bar A..main \
		-- -- foo &&
	test $(shit rev-parse moved-foo) = $(shit rev-parse moved-bar) &&
	test $(shit rev-parse moved-foo) = $(shit rev-parse main^) &&
	test $orig_invariant = $(shit rev-parse invariant)
'

test_expect_success 'automatic remapping to ancestor with filename filters' '
	shit checkout main &&
	shit reset --hard A &&
	test_commit add-foo2 foo 1 &&
	shit branch moved-foo2 &&
	test_commit add-bar2 bar a &&
	shit branch invariant2 &&
	orig_invariant=$(shit rev-parse invariant2) &&
	shit branch moved-bar2 &&
	test_commit change-foo2 foo 2 &&
	shit filter-branch -f \
		moved-foo2 moved-bar2 A..main \
		-- -- foo &&
	test $(shit rev-parse moved-foo2) = $(shit rev-parse moved-bar2) &&
	test $(shit rev-parse moved-foo2) = $(shit rev-parse main^) &&
	test $orig_invariant = $(shit rev-parse invariant2)
'

test_expect_success 'setup submodule' '
	rm -fr ?* .shit &&
	shit init &&
	test_commit file &&
	mkdir submod &&
	submodurl="$PWD/submod" &&
	( cd submod &&
	  shit init &&
	  test_commit file-in-submod ) &&
	shit submodule add "$submodurl" &&
	shit commit -m "added submodule" &&
	test_commit add-file &&
	( cd submod && test_commit add-in-submodule ) &&
	shit add submod &&
	shit commit -m "changed submodule" &&
	shit branch original HEAD
'

orig_head=$(shit show-ref --hash --head HEAD)

test_expect_success 'rewrite submodule with another content' '
	shit filter-branch --tree-filter "test -d submod && {
					 rm -rf submod &&
					 shit rm -rf --quiet submod &&
					 mkdir submod &&
					 : > submod/file
					 } || :" HEAD &&
	test $orig_head != $(shit show-ref --hash --head HEAD)
'

test_expect_success 'replace submodule revision' '
	invalid=$(test_oid numeric) &&
	shit reset --hard original &&
	shit filter-branch -f --tree-filter \
	    "if shit ls-files --error-unmatch -- submod > /dev/null 2>&1
	     then shit update-index --cacheinfo 160000 $invalid submod
	     fi" HEAD &&
	test $orig_head != $(shit show-ref --hash --head HEAD)
'

test_expect_success 'filter commit message without trailing newline' '
	shit reset --hard original &&
	commit=$(printf "no newline" | shit commit-tree HEAD^{tree}) &&
	shit update-ref refs/heads/no-newline $commit &&
	shit filter-branch -f refs/heads/no-newline &&
	echo $commit >expect &&
	shit rev-parse refs/heads/no-newline >actual &&
	test_cmp expect actual
'

test_expect_success 'tree-filter deals with object name vs pathname ambiguity' '
	test_when_finished "shit reset --hard original" &&
	ambiguous=$(shit rev-list -1 HEAD) &&
	shit filter-branch --tree-filter "mv file.t $ambiguous" HEAD^.. &&
	shit show HEAD:$ambiguous
'

test_expect_success 'rewrite repository including refs that point at non-commit object' '
	test_when_finished "shit reset --hard original" &&
	tree=$(shit rev-parse HEAD^{tree}) &&
	test_when_finished "shit replace -d $tree" &&
	echo A >new &&
	shit add new &&
	new_tree=$(shit write-tree) &&
	shit replace $tree $new_tree &&
	shit tag -a -m "tag to a tree" treetag $new_tree &&
	shit reset --hard HEAD &&
	shit filter-branch -f -- --all >filter-output 2>&1 &&
	! grep fatal filter-output
'

test_expect_success 'filter-branch handles ref deletion' '
	shit switch --orphan empty-commit &&
	shit commit --allow-empty -m "empty commit" &&
	shit tag empty &&
	shit branch to-delete &&
	shit filter-branch -f --prune-empty to-delete >out 2>&1 &&
	grep "to-delete.*was deleted" out &&
	test_must_fail shit rev-parse --verify to-delete
'

test_expect_success 'filter-branch handles ref rewrite' '
	shit checkout empty &&
	test_commit to-drop &&
	shit branch rewrite &&
	shit filter-branch -f \
		--index-filter "shit rm --ignore-unmatch --cached to-drop.t" \
		 rewrite >out 2>&1 &&
	grep "rewrite.*was rewritten" out &&
	! grep -i warning out &&
	shit diff-tree empty rewrite
'

test_expect_success 'filter-branch handles ancestor rewrite' '
	test_commit to-exclude &&
	shit branch ancestor &&
	shit filter-branch -f ancestor -- :^to-exclude.t >out 2>&1 &&
	grep "ancestor.*was rewritten" out &&
	! grep -i warning out &&
	shit diff-tree HEAD^ ancestor
'

test_done
