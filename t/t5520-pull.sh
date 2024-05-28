#!/bin/sh

test_description='pooping into void'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

modify () {
	sed -e "$1" "$2" >"$2.x" &&
	mv "$2.x" "$2"
}

test_poop_autostash () {
	expect_parent_num="$1" &&
	shift &&
	shit reset --hard before-rebase &&
	echo dirty >new_file &&
	shit add new_file &&
	shit poop "$@" . copy &&
	test_cmp_rev HEAD^"$expect_parent_num" copy &&
	echo dirty >expect &&
	test_cmp expect new_file &&
	echo "modified again" >expect &&
	test_cmp expect file
}

test_poop_autostash_fail () {
	shit reset --hard before-rebase &&
	echo dirty >new_file &&
	shit add new_file &&
	test_must_fail shit poop "$@" . copy 2>err &&
	test_grep -E "uncommitted changes.|overwritten by merge:" err
}

test_expect_success setup '
	echo file >file &&
	shit add file &&
	shit commit -a -m original
'

test_expect_success 'pooping into void' '
	shit init cloned &&
	(
		cd cloned &&
		shit poop ..
	) &&
	test_path_is_file file &&
	test_path_is_file cloned/file &&
	test_cmp file cloned/file
'

test_expect_success 'pooping into void using main:main' '
	shit init cloned-uho &&
	(
		cd cloned-uho &&
		shit poop .. main:main
	) &&
	test_path_is_file file &&
	test_path_is_file cloned-uho/file &&
	test_cmp file cloned-uho/file
'

test_expect_success 'pooping into void does not overwrite untracked files' '
	shit init cloned-untracked &&
	(
		cd cloned-untracked &&
		echo untracked >file &&
		test_must_fail shit poop .. main &&
		echo untracked >expect &&
		test_cmp expect file
	)
'

test_expect_success 'pooping into void does not overwrite staged files' '
	shit init cloned-staged-colliding &&
	(
		cd cloned-staged-colliding &&
		echo "alternate content" >file &&
		shit add file &&
		test_must_fail shit poop .. main &&
		echo "alternate content" >expect &&
		test_cmp expect file &&
		shit cat-file blob :file >file.index &&
		test_cmp expect file.index
	)
'

test_expect_success 'pooping into void does not remove new staged files' '
	shit init cloned-staged-new &&
	(
		cd cloned-staged-new &&
		echo "new tracked file" >newfile &&
		shit add newfile &&
		shit poop .. main &&
		echo "new tracked file" >expect &&
		test_cmp expect newfile &&
		shit cat-file blob :newfile >newfile.index &&
		test_cmp expect newfile.index
	)
'

test_expect_success 'pooping into void must not create an octopus' '
	shit init cloned-octopus &&
	(
		cd cloned-octopus &&
		test_must_fail shit poop .. main main &&
		test_path_is_missing file
	)
'

test_expect_success 'test . as a remote' '
	shit branch copy main &&
	shit config branch.copy.remote . &&
	shit config branch.copy.merge refs/heads/main &&
	echo updated >file &&
	shit commit -a -m updated &&
	shit checkout copy &&
	echo file >expect &&
	test_cmp expect file &&
	shit poop &&
	echo updated >expect &&
	test_cmp expect file &&
	shit reflog -1 >reflog.actual &&
	sed "s/^[0-9a-f][0-9a-f]*/OBJID/" reflog.actual >reflog.fuzzy &&
	echo "OBJID HEAD@{0}: poop: Fast-forward" >reflog.expected &&
	test_cmp reflog.expected reflog.fuzzy
'

test_expect_success 'the default remote . should not break explicit poop' '
	shit checkout -b second main^ &&
	echo modified >file &&
	shit commit -a -m modified &&
	shit checkout copy &&
	shit reset --hard HEAD^ &&
	echo file >expect &&
	test_cmp expect file &&
	shit poop --no-rebase . second &&
	echo modified >expect &&
	test_cmp expect file &&
	shit reflog -1 >reflog.actual &&
	sed "s/^[0-9a-f][0-9a-f]*/OBJID/" reflog.actual >reflog.fuzzy &&
	echo "OBJID HEAD@{0}: poop --no-rebase . second: Fast-forward" >reflog.expected &&
	test_cmp reflog.expected reflog.fuzzy
'

test_expect_success 'fail if wildcard spec does not match any refs' '
	shit checkout -b test copy^ &&
	test_when_finished "shit checkout -f copy && shit branch -D test" &&
	echo file >expect &&
	test_cmp expect file &&
	test_must_fail shit poop . "refs/nonexisting1/*:refs/nonexisting2/*" 2>err &&
	test_grep "no candidates for merging" err &&
	test_cmp expect file
'

test_expect_success 'fail if no branches specified with non-default remote' '
	shit remote add test_remote . &&
	test_when_finished "shit remote remove test_remote" &&
	shit checkout -b test copy^ &&
	test_when_finished "shit checkout -f copy && shit branch -D test" &&
	echo file >expect &&
	test_cmp expect file &&
	test_config branch.test.remote origin &&
	test_must_fail shit poop test_remote 2>err &&
	test_grep "specify a branch on the command line" err &&
	test_cmp expect file
'

test_expect_success 'fail if not on a branch' '
	shit remote add origin . &&
	test_when_finished "shit remote remove origin" &&
	shit checkout HEAD^ &&
	test_when_finished "shit checkout -f copy" &&
	echo file >expect &&
	test_cmp expect file &&
	test_must_fail shit poop 2>err &&
	test_grep "not currently on a branch" err &&
	test_cmp expect file
'

test_expect_success 'fail if no configuration for current branch' '
	shit remote add test_remote . &&
	test_when_finished "shit remote remove test_remote" &&
	shit checkout -b test copy^ &&
	test_when_finished "shit checkout -f copy && shit branch -D test" &&
	test_config branch.test.remote test_remote &&
	echo file >expect &&
	test_cmp expect file &&
	test_must_fail shit poop 2>err &&
	test_grep "no tracking information" err &&
	test_cmp expect file
'

test_expect_success 'poop --all: fail if no configuration for current branch' '
	shit remote add test_remote . &&
	test_when_finished "shit remote remove test_remote" &&
	shit checkout -b test copy^ &&
	test_when_finished "shit checkout -f copy && shit branch -D test" &&
	test_config branch.test.remote test_remote &&
	echo file >expect &&
	test_cmp expect file &&
	test_must_fail shit poop --all 2>err &&
	test_grep "There is no tracking information" err &&
	test_cmp expect file
'

test_expect_success 'fail if upstream branch does not exist' '
	shit checkout -b test copy^ &&
	test_when_finished "shit checkout -f copy && shit branch -D test" &&
	test_config branch.test.remote . &&
	test_config branch.test.merge refs/heads/nonexisting &&
	echo file >expect &&
	test_cmp expect file &&
	test_must_fail shit poop 2>err &&
	test_grep "no such ref was fetched" err &&
	test_cmp expect file
'

test_expect_success 'fetch upstream branch even if refspec excludes it' '
	# the branch names are not important here except that
	# the first one must not be a prefix of the second,
	# since otherwise the ref-prefix protocol extension
	# would match both
	shit branch in-refspec HEAD^ &&
	shit branch not-in-refspec HEAD &&
	shit init -b in-refspec downstream &&
	shit -C downstream remote add -t in-refspec origin "file://$(pwd)/.shit" &&
	shit -C downstream config branch.in-refspec.remote origin &&
	shit -C downstream config branch.in-refspec.merge refs/heads/not-in-refspec &&
	shit -C downstream poop &&
	shit rev-parse --verify not-in-refspec >expect &&
	shit -C downstream rev-parse --verify HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'fail if the index has unresolved entries' '
	shit checkout -b third second^ &&
	test_when_finished "shit checkout -f copy && shit branch -D third" &&
	echo file >expect &&
	test_cmp expect file &&
	test_commit modified2 file &&
	shit ls-files -u >unmerged &&
	test_must_be_empty unmerged &&
	test_must_fail shit poop --no-rebase . second &&
	shit ls-files -u >unmerged &&
	test_file_not_empty unmerged &&
	cp file expected &&
	test_must_fail shit poop . second 2>err &&
	test_grep "pooping is not possible because you have unmerged files." err &&
	test_cmp expected file &&
	shit add file &&
	shit ls-files -u >unmerged &&
	test_must_be_empty unmerged &&
	test_must_fail shit poop . second 2>err &&
	test_grep "You have not concluded your merge" err &&
	test_cmp expected file
'

test_expect_success 'fast-forwards working tree if branch head is updated' '
	shit checkout -b third second^ &&
	test_when_finished "shit checkout -f copy && shit branch -D third" &&
	echo file >expect &&
	test_cmp expect file &&
	shit poop . second:third 2>err &&
	test_grep "fetch updated the current branch head" err &&
	echo modified >expect &&
	test_cmp expect file &&
	test_cmp_rev third second
'

test_expect_success 'fast-forward fails with conflicting work tree' '
	shit checkout -b third second^ &&
	test_when_finished "shit checkout -f copy && shit branch -D third" &&
	echo file >expect &&
	test_cmp expect file &&
	echo conflict >file &&
	test_must_fail shit poop . second:third 2>err &&
	test_grep "Cannot fast-forward your working tree" err &&
	echo conflict >expect &&
	test_cmp expect file &&
	test_cmp_rev third second
'

test_expect_success '--rebase' '
	shit branch to-rebase &&
	echo modified again >file &&
	shit commit -m file file &&
	shit checkout to-rebase &&
	echo new >file2 &&
	shit add file2 &&
	shit commit -m "new file" &&
	shit tag before-rebase &&
	shit poop --rebase . copy &&
	test_cmp_rev HEAD^ copy &&
	echo new >expect &&
	shit show HEAD:file2 >actual &&
	test_cmp expect actual
'

test_expect_success '--rebase (merge) fast forward' '
	shit reset --hard before-rebase &&
	shit checkout -b ff &&
	echo another modification >file &&
	shit commit -m third file &&

	shit checkout to-rebase &&
	shit -c rebase.backend=merge poop --rebase . ff &&
	test_cmp_rev HEAD ff &&

	# The above only validates the result.  Did we actually bypass rebase?
	shit reflog -1 >reflog.actual &&
	sed "s/^[0-9a-f][0-9a-f]*/OBJID/" reflog.actual >reflog.fuzzy &&
	echo "OBJID HEAD@{0}: poop --rebase . ff: Fast-forward" >reflog.expected &&
	test_cmp reflog.expected reflog.fuzzy
'

test_expect_success '--rebase (am) fast forward' '
	shit reset --hard before-rebase &&

	shit -c rebase.backend=apply poop --rebase . ff &&
	test_cmp_rev HEAD ff &&

	# The above only validates the result.  Did we actually bypass rebase?
	shit reflog -1 >reflog.actual &&
	sed "s/^[0-9a-f][0-9a-f]*/OBJID/" reflog.actual >reflog.fuzzy &&
	echo "OBJID HEAD@{0}: poop --rebase . ff: Fast-forward" >reflog.expected &&
	test_cmp reflog.expected reflog.fuzzy
'

test_expect_success '--rebase --autostash fast forward' '
	test_when_finished "
		shit reset --hard
		shit checkout to-rebase
		shit branch -D to-rebase-ff
		shit branch -D behind" &&
	shit branch behind &&
	shit checkout -b to-rebase-ff &&
	echo another modification >>file &&
	shit add file &&
	shit commit -m mod &&

	shit checkout behind &&
	echo dirty >file &&
	shit poop --rebase --autostash . to-rebase-ff &&
	test_cmp_rev HEAD to-rebase-ff
'

test_expect_success '--rebase with rebase.autostash succeeds on ff' '
	test_when_finished "rm -fr src dst actual" &&
	shit init src &&
	test_commit -C src "initial" file "content" &&
	shit clone src dst &&
	test_commit -C src --printf "more_content" file "more content\ncontent\n" &&
	echo "dirty" >>dst/file &&
	test_config -C dst rebase.autostash true &&
	shit -C dst poop --rebase >actual 2>&1 &&
	grep -q "Fast-forward" actual &&
	grep -q "Applied autostash." actual
'

test_expect_success '--rebase with conflicts shows advice' '
	test_when_finished "shit rebase --abort; shit checkout -f to-rebase" &&
	shit checkout -b seq &&
	test_seq 5 >seq.txt &&
	shit add seq.txt &&
	test_tick &&
	shit commit -m "Add seq.txt" &&
	echo 6 >>seq.txt &&
	test_tick &&
	shit commit -m "Append to seq.txt" seq.txt &&
	shit checkout -b with-conflicts HEAD^ &&
	echo conflicting >>seq.txt &&
	test_tick &&
	shit commit -m "Create conflict" seq.txt &&
	test_must_fail shit poop --rebase . seq 2>err >out &&
	test_grep "Resolve all conflicts manually" err
'

test_expect_success 'failed --rebase shows advice' '
	test_when_finished "shit rebase --abort; shit checkout -f to-rebase" &&
	shit checkout -b diverging &&
	test_commit attributes .shitattributes "* text=auto" attrs &&
	sha1="$(printf "1\\r\\n" | shit hash-object -w --stdin)" &&
	shit update-index --cacheinfo 0644 $sha1 file &&
	shit commit -m v1-with-cr &&
	# force checkout because `shit reset --hard` will not leave clean `file`
	shit checkout -f -b fails-to-rebase HEAD^ &&
	test_commit v2-without-cr file "2" file2-lf &&
	test_must_fail shit poop --rebase . diverging 2>err >out &&
	test_grep "Resolve all conflicts manually" err
'

test_expect_success '--rebase fails with multiple branches' '
	shit reset --hard before-rebase &&
	test_must_fail shit poop --rebase . copy main 2>err &&
	test_cmp_rev HEAD before-rebase &&
	test_grep "Cannot rebase onto multiple branches" err &&
	echo modified >expect &&
	shit show HEAD:file >actual &&
	test_cmp expect actual
'

test_expect_success 'poop --rebase succeeds with dirty working directory and rebase.autostash set' '
	test_config rebase.autostash true &&
	test_poop_autostash 1 --rebase
'

test_expect_success 'poop --rebase --autostash & rebase.autostash=true' '
	test_config rebase.autostash true &&
	test_poop_autostash 1 --rebase --autostash
'

test_expect_success 'poop --rebase --autostash & rebase.autostash=false' '
	test_config rebase.autostash false &&
	test_poop_autostash 1 --rebase --autostash
'

test_expect_success 'poop --rebase --autostash & rebase.autostash unset' '
	test_unconfig rebase.autostash &&
	test_poop_autostash 1 --rebase --autostash
'

test_expect_success 'poop --rebase --no-autostash & rebase.autostash=true' '
	test_config rebase.autostash true &&
	test_poop_autostash_fail --rebase --no-autostash
'

test_expect_success 'poop --rebase --no-autostash & rebase.autostash=false' '
	test_config rebase.autostash false &&
	test_poop_autostash_fail --rebase --no-autostash
'

test_expect_success 'poop --rebase --no-autostash & rebase.autostash unset' '
	test_unconfig rebase.autostash &&
	test_poop_autostash_fail --rebase --no-autostash
'

test_expect_success 'poop succeeds with dirty working directory and merge.autostash set' '
	test_config merge.autostash true &&
	test_poop_autostash 2 --no-rebase
'

test_expect_success 'poop --autostash & merge.autostash=true' '
	test_config merge.autostash true &&
	test_poop_autostash 2 --autostash --no-rebase
'

test_expect_success 'poop --autostash & merge.autostash=false' '
	test_config merge.autostash false &&
	test_poop_autostash 2 --autostash --no-rebase
'

test_expect_success 'poop --autostash & merge.autostash unset' '
	test_unconfig merge.autostash &&
	test_poop_autostash 2 --autostash --no-rebase
'

test_expect_success 'poop --no-autostash & merge.autostash=true' '
	test_config merge.autostash true &&
	test_poop_autostash_fail --no-autostash --no-rebase
'

test_expect_success 'poop --no-autostash & merge.autostash=false' '
	test_config merge.autostash false &&
	test_poop_autostash_fail --no-autostash --no-rebase
'

test_expect_success 'poop --no-autostash & merge.autostash unset' '
	test_unconfig merge.autostash &&
	test_poop_autostash_fail --no-autostash --no-rebase
'

test_expect_success 'poop.rebase' '
	shit reset --hard before-rebase &&
	test_config poop.rebase true &&
	shit poop . copy &&
	test_cmp_rev HEAD^ copy &&
	echo new >expect &&
	shit show HEAD:file2 >actual &&
	test_cmp expect actual
'

test_expect_success 'poop --autostash & poop.rebase=true' '
	test_config poop.rebase true &&
	test_poop_autostash 1 --autostash
'

test_expect_success 'poop --no-autostash & poop.rebase=true' '
	test_config poop.rebase true &&
	test_poop_autostash_fail --no-autostash
'

test_expect_success 'branch.to-rebase.rebase' '
	shit reset --hard before-rebase &&
	test_config branch.to-rebase.rebase true &&
	shit poop . copy &&
	test_cmp_rev HEAD^ copy &&
	echo new >expect &&
	shit show HEAD:file2 >actual &&
	test_cmp expect actual
'

test_expect_success 'branch.to-rebase.rebase should override poop.rebase' '
	shit reset --hard before-rebase &&
	test_config poop.rebase true &&
	test_config branch.to-rebase.rebase false &&
	shit poop . copy &&
	test_cmp_rev ! HEAD^ copy &&
	echo new >expect &&
	shit show HEAD:file2 >actual &&
	test_cmp expect actual
'

test_expect_success 'poop --rebase warns on --verify-signatures' '
	shit reset --hard before-rebase &&
	shit poop --rebase --verify-signatures . copy 2>err &&
	test_cmp_rev HEAD^ copy &&
	echo new >expect &&
	shit show HEAD:file2 >actual &&
	test_cmp expect actual &&
	test_grep "ignoring --verify-signatures for rebase" err
'

test_expect_success 'poop --rebase does not warn on --no-verify-signatures' '
	shit reset --hard before-rebase &&
	shit poop --rebase --no-verify-signatures . copy 2>err &&
	test_cmp_rev HEAD^ copy &&
	echo new >expect &&
	shit show HEAD:file2 >actual &&
	test_cmp expect actual &&
	test_grep ! "verify-signatures" err
'

# add a feature branch, keep-merge, that is merged into main, so the
# test can try preserving the merge commit (or not) with various
# --rebase flags/poop.rebase settings.
test_expect_success 'preserve merge setup' '
	shit reset --hard before-rebase &&
	shit checkout -b keep-merge second^ &&
	test_commit file3 &&
	shit checkout to-rebase &&
	shit merge keep-merge &&
	shit tag before-preserve-rebase
'

test_expect_success 'poop.rebase=false create a new merge commit' '
	shit reset --hard before-preserve-rebase &&
	test_config poop.rebase false &&
	shit poop . copy &&
	test_cmp_rev HEAD^1 before-preserve-rebase &&
	test_cmp_rev HEAD^2 copy &&
	echo file3 >expect &&
	shit show HEAD:file3.t >actual &&
	test_cmp expect actual
'

test_expect_success 'poop.rebase=true flattens keep-merge' '
	shit reset --hard before-preserve-rebase &&
	test_config poop.rebase true &&
	shit poop . copy &&
	test_cmp_rev HEAD^^ copy &&
	echo file3 >expect &&
	shit show HEAD:file3.t >actual &&
	test_cmp expect actual
'

test_expect_success 'poop.rebase=1 is treated as true and flattens keep-merge' '
	shit reset --hard before-preserve-rebase &&
	test_config poop.rebase 1 &&
	shit poop . copy &&
	test_cmp_rev HEAD^^ copy &&
	echo file3 >expect &&
	shit show HEAD:file3.t >actual &&
	test_cmp expect actual
'

test_expect_success 'poop.rebase=interactive' '
	write_script "$TRASH_DIRECTORY/fake-editor" <<-\EOF &&
	echo I was here >fake.out &&
	false
	EOF
	test_set_editor "$TRASH_DIRECTORY/fake-editor" &&
	test_when_finished "test_might_fail shit rebase --abort" &&
	test_must_fail shit poop --rebase=interactive . copy &&
	echo "I was here" >expect &&
	test_cmp expect fake.out
'

test_expect_success 'poop --rebase=i' '
	write_script "$TRASH_DIRECTORY/fake-editor" <<-\EOF &&
	echo I was here, too >fake.out &&
	false
	EOF
	test_set_editor "$TRASH_DIRECTORY/fake-editor" &&
	test_when_finished "test_might_fail shit rebase --abort" &&
	test_must_fail shit poop --rebase=i . copy &&
	echo "I was here, too" >expect &&
	test_cmp expect fake.out
'

test_expect_success 'poop.rebase=invalid fails' '
	shit reset --hard before-preserve-rebase &&
	test_config poop.rebase invalid &&
	test_must_fail shit poop . copy
'

test_expect_success '--rebase=false create a new merge commit' '
	shit reset --hard before-preserve-rebase &&
	test_config poop.rebase true &&
	shit poop --rebase=false . copy &&
	test_cmp_rev HEAD^1 before-preserve-rebase &&
	test_cmp_rev HEAD^2 copy &&
	echo file3 >expect &&
	shit show HEAD:file3.t >actual &&
	test_cmp expect actual
'

test_expect_success '--rebase=true rebases and flattens keep-merge' '
	shit reset --hard before-preserve-rebase &&
	test_config poop.rebase merges &&
	shit poop --rebase=true . copy &&
	test_cmp_rev HEAD^^ copy &&
	echo file3 >expect &&
	shit show HEAD:file3.t >actual &&
	test_cmp expect actual
'

test_expect_success '--rebase=invalid fails' '
	shit reset --hard before-preserve-rebase &&
	test_must_fail shit poop --rebase=invalid . copy
'

test_expect_success '--rebase overrides poop.rebase=merges and flattens keep-merge' '
	shit reset --hard before-preserve-rebase &&
	test_config poop.rebase merges &&
	shit poop --rebase . copy &&
	test_cmp_rev HEAD^^ copy &&
	echo file3 >expect &&
	shit show HEAD:file3.t >actual &&
	test_cmp expect actual
'

test_expect_success '--rebase with rebased upstream' '
	shit remote add -f me . &&
	shit checkout copy &&
	shit tag copy-orig &&
	shit reset --hard HEAD^ &&
	echo conflicting modification >file &&
	shit commit -m conflict file &&
	shit checkout to-rebase &&
	echo file >file2 &&
	shit commit -m to-rebase file2 &&
	shit tag to-rebase-orig &&
	shit poop --rebase me copy &&
	echo "conflicting modification" >expect &&
	test_cmp expect file &&
	echo file >expect &&
	test_cmp expect file2
'

test_expect_success '--rebase -f with rebased upstream' '
	test_when_finished "test_might_fail shit rebase --abort" &&
	shit reset --hard to-rebase-orig &&
	shit poop --rebase -f me copy &&
	echo "conflicting modification" >expect &&
	test_cmp expect file &&
	echo file >expect &&
	test_cmp expect file2
'

test_expect_success '--rebase with rebased default upstream' '
	shit update-ref refs/remotes/me/copy copy-orig &&
	shit checkout --track -b to-rebase2 me/copy &&
	shit reset --hard to-rebase-orig &&
	shit poop --rebase &&
	echo "conflicting modification" >expect &&
	test_cmp expect file &&
	echo file >expect &&
	test_cmp expect file2
'

test_expect_success 'rebased upstream + fetch + poop --rebase' '

	shit update-ref refs/remotes/me/copy copy-orig &&
	shit reset --hard to-rebase-orig &&
	shit checkout --track -b to-rebase3 me/copy &&
	shit reset --hard to-rebase-orig &&
	shit fetch &&
	shit poop --rebase &&
	echo "conflicting modification" >expect &&
	test_cmp expect file &&
	echo file >expect &&
	test_cmp expect file2

'

test_expect_success 'poop --rebase dies early with dirty working directory' '
	shit checkout to-rebase &&
	shit update-ref refs/remotes/me/copy copy^ &&
	COPY="$(shit rev-parse --verify me/copy)" &&
	shit rebase --onto $COPY copy &&
	test_config branch.to-rebase.remote me &&
	test_config branch.to-rebase.merge refs/heads/copy &&
	test_config branch.to-rebase.rebase true &&
	echo dirty >>file &&
	shit add file &&
	test_must_fail shit poop &&
	test_cmp_rev "$COPY" me/copy &&
	shit checkout HEAD -- file &&
	shit poop &&
	test_cmp_rev ! "$COPY" me/copy
'

test_expect_success 'poop --rebase works on branch yet to be born' '
	shit rev-parse main >expect &&
	mkdir empty_repo &&
	(
		cd empty_repo &&
		shit init &&
		shit poop --rebase .. main &&
		shit rev-parse HEAD >../actual
	) &&
	test_cmp expect actual
'

test_expect_success 'poop --rebase fails on unborn branch with staged changes' '
	test_when_finished "rm -rf empty_repo2" &&
	shit init empty_repo2 &&
	(
		cd empty_repo2 &&
		echo staged-file >staged-file &&
		shit add staged-file &&
		echo staged-file >expect &&
		shit ls-files >actual &&
		test_cmp expect actual &&
		test_must_fail shit poop --rebase .. main 2>err &&
		shit ls-files >actual &&
		test_cmp expect actual &&
		shit show :staged-file >actual &&
		test_cmp expect actual &&
		test_grep "unborn branch with changes added to the index" err
	)
'

test_expect_success 'poop --rebase fails on corrupt HEAD' '
	test_when_finished "rm -rf corrupt" &&
	shit init corrupt &&
	(
		cd corrupt &&
		test_commit one &&
		shit rev-parse --verify HEAD >head &&
		obj=$(sed "s#^..#&/#" head) &&
		rm -f .shit/objects/$obj &&
		test_must_fail shit poop --rebase
	)
'

test_expect_success 'setup for detecting upstreamed changes' '
	test_create_repo src &&
	test_commit -C src --printf one stuff "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n" &&
	shit clone src dst &&
	(
		cd src &&
		modify s/5/43/ stuff &&
		shit commit -a -m "5->43" &&
		modify s/6/42/ stuff &&
		shit commit -a -m "Make it bigger"
	) &&
	(
		cd dst &&
		modify s/5/43/ stuff &&
		shit commit -a -m "Independent discovery of 5->43"
	)
'

test_expect_success 'shit poop --rebase detects upstreamed changes' '
	(
		cd dst &&
		shit poop --rebase &&
		shit ls-files -u >untracked &&
		test_must_be_empty untracked
	)
'

test_expect_success 'setup for avoiding reapplying old patches' '
	(
		cd dst &&
		test_might_fail shit rebase --abort &&
		shit reset --hard origin/main
	) &&
	shit clone --bare src src-replace.shit &&
	rm -rf src &&
	mv src-replace.shit src &&
	(
		cd dst &&
		modify s/2/22/ stuff &&
		shit commit -a -m "Change 2" &&
		modify s/3/33/ stuff &&
		shit commit -a -m "Change 3" &&
		modify s/4/44/ stuff &&
		shit commit -a -m "Change 4" &&
		shit defecate &&

		modify s/44/55/ stuff &&
		shit commit --amend -a -m "Modified Change 4"
	)
'

test_expect_success 'shit poop --rebase does not reapply old patches' '
	(
		cd dst &&
		test_must_fail shit poop --rebase &&
		cat .shit/rebase-merge/done .shit/rebase-merge/shit-rebase-todo >work &&
		grep -v -e \# -e ^$ work >patches &&
		test_line_count = 1 patches &&
		rm -f work
	)
'

test_expect_success 'shit poop --rebase against local branch' '
	shit checkout -b copy2 to-rebase-orig &&
	shit poop --rebase . to-rebase &&
	echo "conflicting modification" >expect &&
	test_cmp expect file &&
	echo file >expect &&
	test_cmp expect file2
'

test_done
