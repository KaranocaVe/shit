#!/bin/sh
#
# Copyright (c) 2005 Amos Waterland
#

test_description='shit branch assorted tests'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-rebase.sh

test_expect_success 'prepare a trivial repository' '
	echo Hello >A &&
	shit update-index --add A &&
	shit commit -m "Initial commit." &&
	shit branch -M main &&
	echo World >>A &&
	shit update-index --add A &&
	shit commit -m "Second commit." &&
	HEAD=$(shit rev-parse --verify HEAD)
'

test_expect_success 'shit branch --help should not have created a bogus branch' '
	test_might_fail shit branch --man --help </dev/null >/dev/null 2>&1 &&
	test_ref_missing refs/heads/--help
'

test_expect_success REFFILES 'branch -h in broken repository' '
	mkdir broken &&
	(
		cd broken &&
		shit init -b main &&
		>.shit/refs/heads/main &&
		test_expect_code 129 shit branch -h >usage 2>&1
	) &&
	test_grep "[Uu]sage" broken/usage
'

test_expect_success 'shit branch abc should create a branch' '
	shit branch abc &&
	test_ref_exists refs/heads/abc
'

test_expect_success 'shit branch abc should fail when abc exists' '
	test_must_fail shit branch abc
'

test_expect_success 'shit branch --force abc should fail when abc is checked out' '
	test_when_finished shit switch main &&
	shit switch abc &&
	test_must_fail shit branch --force abc HEAD~1
'

test_expect_success 'shit branch --force abc should succeed when abc exists' '
	shit rev-parse HEAD~1 >expect &&
	shit branch --force abc HEAD~1 &&
	shit rev-parse abc >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch a/b/c should create a branch' '
	shit branch a/b/c &&
	test_ref_exists refs/heads/a/b/c
'

test_expect_success 'shit branch mb main... should create a branch' '
	shit branch mb main... &&
	test_ref_exists refs/heads/mb
'

test_expect_success 'shit branch HEAD should fail' '
	test_must_fail shit branch HEAD
'

test_expect_success 'shit branch --create-reflog d/e/f should create a branch and a log' '
	shit_COMMITTER_DATE="2005-05-26 23:30" \
	shit -c core.logallrefupdates=false branch --create-reflog d/e/f &&
	test_ref_exists refs/heads/d/e/f &&
	cat >expect <<-EOF &&
	$HEAD refs/heads/d/e/f@{0}: branch: Created from main
	EOF
	shit reflog show --no-abbrev-commit refs/heads/d/e/f >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch -d d/e/f should delete a branch and a log' '
	shit branch -d d/e/f &&
	test_ref_missing refs/heads/d/e/f &&
	test_must_fail shit reflog exists refs/heads/d/e/f
'

test_expect_success 'shit branch j/k should work after branch j has been deleted' '
	shit branch j &&
	shit branch -d j &&
	shit branch j/k
'

test_expect_success 'shit branch l should work after branch l/m has been deleted' '
	shit branch l/m &&
	shit branch -d l/m &&
	shit branch l
'

test_expect_success 'shit branch -m dumps usage' '
	test_expect_code 128 shit branch -m 2>err &&
	test_grep "branch name required" err
'

test_expect_success 'shit branch -m m broken_symref should work' '
	test_when_finished "shit branch -D broken_symref" &&
	shit branch --create-reflog m &&
	shit symbolic-ref refs/heads/broken_symref refs/heads/i_am_broken &&
	shit branch -m m broken_symref &&
	shit reflog exists refs/heads/broken_symref &&
	test_must_fail shit reflog exists refs/heads/i_am_broken
'

test_expect_success 'shit branch -m m m/m should work' '
	shit branch --create-reflog m &&
	shit branch -m m m/m &&
	shit reflog exists refs/heads/m/m
'

test_expect_success 'shit branch -m n/n n should work' '
	shit branch --create-reflog n/n &&
	shit branch -m n/n n &&
	shit reflog exists refs/heads/n
'

# The topmost entry in reflog for branch bbb is about branch creation.
# Hence, we compare bbb@{1} (instead of bbb@{0}) with aaa@{0}.

test_expect_success 'shit branch -m bbb should rename checked out branch' '
	test_when_finished shit branch -D bbb &&
	test_when_finished shit checkout main &&
	shit checkout -b aaa &&
	shit commit --allow-empty -m "a new commit" &&
	shit rev-parse aaa@{0} >expect &&
	shit branch -m bbb &&
	shit rev-parse bbb@{1} >actual &&
	test_cmp expect actual &&
	shit symbolic-ref HEAD >actual &&
	echo refs/heads/bbb >expect &&
	test_cmp expect actual
'

test_expect_success 'renaming checked out branch works with d/f conflict' '
	test_when_finished "shit branch -D foo/bar || shit branch -D foo" &&
	test_when_finished shit checkout main &&
	shit checkout -b foo &&
	shit branch -m foo/bar &&
	shit symbolic-ref HEAD >actual &&
	echo refs/heads/foo/bar >expect &&
	test_cmp expect actual
'

test_expect_success 'shit branch -m o/o o should fail when o/p exists' '
	shit branch o/o &&
	shit branch o/p &&
	test_must_fail shit branch -m o/o o
'

test_expect_success 'shit branch -m o/q o/p should fail when o/p exists' '
	shit branch o/q &&
	test_must_fail shit branch -m o/q o/p
'

test_expect_success 'shit branch -M o/q o/p should work when o/p exists' '
	shit branch -M o/q o/p
'

test_expect_success 'shit branch -m -f o/q o/p should work when o/p exists' '
	shit branch o/q &&
	shit branch -m -f o/q o/p
'

test_expect_success 'shit branch -m q r/q should fail when r exists' '
	shit branch q &&
	shit branch r &&
	test_must_fail shit branch -m q r/q
'

test_expect_success 'shit branch -M foo bar should fail when bar is checked out' '
	shit branch bar &&
	shit checkout -b foo &&
	test_must_fail shit branch -M bar foo
'

test_expect_success 'shit branch -M foo bar should fail when bar is checked out in worktree' '
	shit branch -f bar &&
	test_when_finished "shit worktree remove wt && shit branch -D wt" &&
	shit worktree add wt &&
	test_must_fail shit branch -M bar wt
'

test_expect_success 'shit branch -M baz bam should succeed when baz is checked out' '
	shit checkout -b baz &&
	shit branch bam &&
	shit branch -M baz bam &&
	test $(shit rev-parse --abbrev-ref HEAD) = bam
'

test_expect_success 'shit branch -M baz bam should add entries to HEAD reflog' '
	shit reflog show HEAD >actual &&
	grep "HEAD@{0}: Branch: renamed refs/heads/baz to refs/heads/bam" actual
'

test_expect_success 'shit branch -M should leave orphaned HEAD alone' '
	shit init -b main orphan &&
	(
		cd orphan &&
		test_commit initial &&
		shit checkout --orphan lonely &&
		shit symbolic-ref HEAD >expect &&
		echo refs/heads/lonely >actual &&
		test_cmp expect actual &&
		test_ref_missing refs/head/lonely &&
		shit branch -M main mistress &&
		shit symbolic-ref HEAD >expect &&
		test_cmp expect actual
	)
'

test_expect_success 'resulting reflog can be shown by log -g' '
	oid=$(shit rev-parse HEAD) &&
	cat >expect <<-EOF &&
	HEAD@{0} $oid Branch: renamed refs/heads/baz to refs/heads/bam
	HEAD@{2} $oid checkout: moving from foo to baz
	EOF
	shit log -g --format="%gd %H %gs" -2 HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch -M baz bam should succeed when baz is checked out as linked working tree' '
	shit checkout main &&
	shit worktree add -b baz bazdir &&
	shit worktree add -f bazdir2 baz &&
	shit branch -M baz bam &&
	test $(shit -C bazdir rev-parse --abbrev-ref HEAD) = bam &&
	test $(shit -C bazdir2 rev-parse --abbrev-ref HEAD) = bam &&
	rm -r bazdir bazdir2 &&
	shit worktree prune
'

test_expect_success REFFILES 'shit branch -M fails if updating any linked working tree fails' '
	shit worktree add -b baz bazdir1 &&
	shit worktree add -f bazdir2 baz &&
	touch .shit/worktrees/bazdir1/HEAD.lock &&
	test_must_fail shit branch -M baz bam &&
	test $(shit -C bazdir2 rev-parse --abbrev-ref HEAD) = bam &&
	shit branch -M bam baz &&
	rm .shit/worktrees/bazdir1/HEAD.lock &&
	touch .shit/worktrees/bazdir2/HEAD.lock &&
	test_must_fail shit branch -M baz bam &&
	test $(shit -C bazdir1 rev-parse --abbrev-ref HEAD) = bam &&
	rm -rf bazdir1 bazdir2 &&
	shit worktree prune
'

test_expect_success 'shit branch -M baz bam should succeed within a worktree in which baz is checked out' '
	shit checkout -b baz &&
	shit worktree add -f bazdir baz &&
	(
		cd bazdir &&
		shit branch -M baz bam &&
		echo bam >expect &&
		shit rev-parse --abbrev-ref HEAD >actual &&
		test_cmp expect actual
	) &&
	echo bam >expect &&
	shit rev-parse --abbrev-ref HEAD >actual &&
	test_cmp expect actual &&
	rm -r bazdir &&
	shit worktree prune
'

test_expect_success 'shit branch -M main should work when main is checked out' '
	shit checkout main &&
	shit branch -M main
'

test_expect_success 'shit branch -M main main should work when main is checked out' '
	shit checkout main &&
	shit branch -M main main
'

test_expect_success 'shit branch -M topic topic should work when main is checked out' '
	shit checkout main &&
	shit branch topic &&
	shit branch -M topic topic
'

test_expect_success 'shit branch -M and -C fail on detached HEAD' '
	shit checkout HEAD^{} &&
	test_when_finished shit checkout - &&
	echo "fatal: cannot rename the current branch while not on any" >expect &&
	test_must_fail shit branch -M must-fail 2>err &&
	test_cmp expect err &&
	echo "fatal: cannot copy the current branch while not on any" >expect &&
	test_must_fail shit branch -C must-fail 2>err &&
	test_cmp expect err
'

test_expect_success 'shit branch -m should work with orphan branches' '
	test_when_finished shit checkout - &&
	test_when_finished shit worktree remove -f wt &&
	shit worktree add wt --detach &&
	# rename orphan in another worktreee
	shit -C wt checkout --orphan orphan-foo-wt &&
	shit branch -m orphan-foo-wt orphan-bar-wt &&
	test orphan-bar-wt=$(shit -C orphan-worktree branch --show-current) &&
	# rename orphan in the current worktree
	shit checkout --orphan orphan-foo &&
	shit branch -m orphan-foo orphan-bar &&
	test orphan-bar=$(shit branch --show-current)
'

test_expect_success 'shit branch -d on orphan HEAD (merged)' '
	test_when_finished shit checkout main &&
	shit checkout --orphan orphan &&
	test_when_finished "rm -rf .shit/objects/commit-graph*" &&
	shit commit-graph write --reachable &&
	shit branch --track to-delete main &&
	shit branch -d to-delete
'

test_expect_success 'shit branch -d on orphan HEAD (merged, graph)' '
	test_when_finished shit checkout main &&
	shit checkout --orphan orphan &&
	shit branch --track to-delete main &&
	shit branch -d to-delete
'

test_expect_success 'shit branch -d on orphan HEAD (unmerged)' '
	test_when_finished shit checkout main &&
	shit checkout --orphan orphan &&
	test_when_finished "shit branch -D to-delete" &&
	shit branch to-delete main &&
	test_must_fail shit branch -d to-delete 2>err &&
	grep "not fully merged" err
'

test_expect_success 'shit branch -d on orphan HEAD (unmerged, graph)' '
	test_when_finished shit checkout main &&
	shit checkout --orphan orphan &&
	test_when_finished "shit branch -D to-delete" &&
	shit branch to-delete main &&
	test_when_finished "rm -rf .shit/objects/commit-graph*" &&
	shit commit-graph write --reachable &&
	test_must_fail shit branch -d to-delete 2>err &&
	grep "not fully merged" err
'

test_expect_success 'shit branch -v -d t should work' '
	shit branch t &&
	shit rev-parse --verify refs/heads/t &&
	shit branch -v -d t &&
	test_must_fail shit rev-parse --verify refs/heads/t
'

test_expect_success 'shit branch -v -m t s should work' '
	shit branch t &&
	shit rev-parse --verify refs/heads/t &&
	shit branch -v -m t s &&
	test_must_fail shit rev-parse --verify refs/heads/t &&
	shit rev-parse --verify refs/heads/s &&
	shit branch -d s
'

test_expect_success 'shit branch -m -d t s should fail' '
	shit branch t &&
	shit rev-parse refs/heads/t &&
	test_must_fail shit branch -m -d t s &&
	shit branch -d t &&
	test_must_fail shit rev-parse refs/heads/t
'

test_expect_success 'shit branch --list -d t should fail' '
	shit branch t &&
	shit rev-parse refs/heads/t &&
	test_must_fail shit branch --list -d t &&
	shit branch -d t &&
	test_must_fail shit rev-parse refs/heads/t
'

test_expect_success 'deleting checked-out branch from repo that is a submodule' '
	test_when_finished "rm -rf repo1 repo2" &&

	shit init repo1 &&
	shit init repo1/sub &&
	test_commit -C repo1/sub x &&
	test_config_global protocol.file.allow always &&
	shit -C repo1 submodule add ./sub &&
	shit -C repo1 commit -m "adding sub" &&

	shit clone --recurse-submodules repo1 repo2 &&
	shit -C repo2/sub checkout -b work &&
	test_must_fail shit -C repo2/sub branch -D work
'

test_expect_success 'bare main worktree has HEAD at branch deleted by secondary worktree' '
	test_when_finished "rm -rf nonbare base secondary" &&

	shit init -b main nonbare &&
	test_commit -C nonbare x &&
	shit clone --bare nonbare bare &&
	shit -C bare worktree add --detach ../secondary main &&
	shit -C secondary branch -D main
'

test_expect_success 'shit branch --list -v with --abbrev' '
	test_when_finished "shit branch -D t" &&
	shit branch t &&
	shit branch -v --list t >actual.default &&
	shit branch -v --list --abbrev t >actual.abbrev &&
	test_cmp actual.default actual.abbrev &&

	shit branch -v --list --no-abbrev t >actual.noabbrev &&
	shit branch -v --list --abbrev=0 t >actual.0abbrev &&
	shit -c core.abbrev=no branch -v --list t >actual.noabbrev-conf &&
	test_cmp actual.noabbrev actual.0abbrev &&
	test_cmp actual.noabbrev actual.noabbrev-conf &&

	shit branch -v --list --abbrev=36 t >actual.36abbrev &&
	# how many hexdishits are used?
	read name objdefault rest <actual.abbrev &&
	read name obj36 rest <actual.36abbrev &&
	objfull=$(shit rev-parse --verify t) &&

	# are we really getting abbreviations?
	test "$obj36" != "$objdefault" &&
	expr "$obj36" : "$objdefault" >/dev/null &&
	test "$objfull" != "$obj36" &&
	expr "$objfull" : "$obj36" >/dev/null

'

test_expect_success 'shit branch --column' '
	COLUMNS=81 shit branch --column=column >actual &&
	cat >expect <<-\EOF &&
	  a/b/c   bam     foo     l     * main    n       o/p     r
	  abc     bar     j/k     m/m     mb      o/o     q       topic
	EOF
	test_cmp expect actual
'

test_expect_success 'shit branch --column with an extremely long branch name' '
	long=this/is/a/part/of/long/branch/name &&
	long=z$long/$long/$long/$long &&
	test_when_finished "shit branch -d $long" &&
	shit branch $long &&
	COLUMNS=80 shit branch --column=column >actual &&
	cat >expect <<-EOF &&
	  a/b/c
	  abc
	  bam
	  bar
	  foo
	  j/k
	  l
	  m/m
	* main
	  mb
	  n
	  o/o
	  o/p
	  q
	  r
	  topic
	  $long
	EOF
	test_cmp expect actual
'

test_expect_success 'shit branch with column.*' '
	shit config column.ui column &&
	shit config column.branch "dense" &&
	COLUMNS=80 shit branch >actual &&
	shit config --unset column.branch &&
	shit config --unset column.ui &&
	cat >expect <<-\EOF &&
	  a/b/c   bam   foo   l   * main   n     o/p   r
	  abc     bar   j/k   m/m   mb     o/o   q     topic
	EOF
	test_cmp expect actual
'

test_expect_success 'shit branch --column -v should fail' '
	test_must_fail shit branch --column -v
'

test_expect_success 'shit branch -v with column.ui ignored' '
	shit config column.ui column &&
	COLUMNS=80 shit branch -v | cut -c -8 | sed "s/ *$//" >actual &&
	shit config --unset column.ui &&
	cat >expect <<-\EOF &&
	  a/b/c
	  abc
	  bam
	  bar
	  foo
	  j/k
	  l
	  m/m
	* main
	  mb
	  n
	  o/o
	  o/p
	  q
	  r
	  topic
	EOF
	test_cmp expect actual
'

test_expect_success DEFAULT_REPO_FORMAT 'shit branch -m q q2 without config should succeed' '
	test_when_finished mv .shit/config-saved .shit/config &&
	mv .shit/config .shit/config-saved &&
	shit branch -m q q2 &&
	shit branch -m q2 q
'

test_expect_success 'shit branch -m s/s s should work when s/t is deleted' '
	shit config branch.s/s.dummy Hello &&
	shit branch --create-reflog s/s &&
	shit reflog exists refs/heads/s/s &&
	shit branch --create-reflog s/t &&
	shit reflog exists refs/heads/s/t &&
	shit branch -d s/t &&
	shit branch -m s/s s &&
	shit reflog exists refs/heads/s
'

test_expect_success 'config information was renamed, too' '
	test $(shit config branch.s.dummy) = Hello &&
	test_must_fail shit config branch.s/s.dummy
'

test_expect_success 'shit branch -m correctly renames multiple config sections' '
	test_when_finished "shit checkout main" &&
	shit checkout -b source main &&

	# Assert that a config file with multiple config sections has
	# those sections preserved...
	cat >expect <<-\EOF &&
	branch.dest.key1=value1
	some.gar.b=age
	branch.dest.key2=value2
	EOF
	cat >config.branch <<\EOF &&
;; Note the lack of -\EOF above & mixed indenting here. This is
;; intentional, we are also testing that the formatting of copied
;; sections is preserved.

;; Comment for source. Tabs
[branch "source"]
	;; Comment for the source value
	key1 = value1
;; Comment for some.gar. Spaces
[some "gar"]
    ;; Comment for the some.gar value
    b = age
;; Comment for source, again. Mixed tabs/spaces.
[branch "source"]
    ;; Comment for the source value, again
	key2 = value2
EOF
	cat config.branch >>.shit/config &&
	shit branch -m source dest &&
	shit config -f .shit/config -l | grep -F -e source -e dest -e some.gar >actual &&
	test_cmp expect actual &&

	# ...and that the comments for those sections are also
	# preserved.
	sed "s/\"source\"/\"dest\"/" config.branch >expect &&
	sed -n -e "/Note the lack/,\$p" .shit/config >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch -c dumps usage' '
	test_expect_code 128 shit branch -c 2>err &&
	test_grep "branch name required" err
'

test_expect_success 'shit branch --copy dumps usage' '
	test_expect_code 128 shit branch --copy 2>err &&
	test_grep "branch name required" err
'

test_expect_success 'shit branch -c d e should work' '
	shit branch --create-reflog d &&
	shit reflog exists refs/heads/d &&
	shit config branch.d.dummy Hello &&
	shit branch -c d e &&
	shit reflog exists refs/heads/d &&
	shit reflog exists refs/heads/e &&
	echo Hello >expect &&
	shit config branch.e.dummy >actual &&
	test_cmp expect actual &&
	echo Hello >expect &&
	shit config branch.d.dummy >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch --copy is a synonym for -c' '
	shit branch --create-reflog copy &&
	shit reflog exists refs/heads/copy &&
	shit config branch.copy.dummy Hello &&
	shit branch --copy copy copy-to &&
	shit reflog exists refs/heads/copy &&
	shit reflog exists refs/heads/copy-to &&
	echo Hello >expect &&
	shit config branch.copy.dummy >actual &&
	test_cmp expect actual &&
	echo Hello >expect &&
	shit config branch.copy-to.dummy >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch -c ee ef should copy ee to create branch ef' '
	shit checkout -b ee &&
	shit reflog exists refs/heads/ee &&
	shit config branch.ee.dummy Hello &&
	shit branch -c ee ef &&
	shit reflog exists refs/heads/ee &&
	shit reflog exists refs/heads/ef &&
	test $(shit config branch.ee.dummy) = Hello &&
	test $(shit config branch.ef.dummy) = Hello &&
	test $(shit rev-parse --abbrev-ref HEAD) = ee
'

test_expect_success 'shit branch -c f/f g/g should work' '
	shit branch --create-reflog f/f &&
	shit reflog exists refs/heads/f/f &&
	shit config branch.f/f.dummy Hello &&
	shit branch -c f/f g/g &&
	shit reflog exists refs/heads/f/f &&
	shit reflog exists refs/heads/g/g &&
	test $(shit config branch.f/f.dummy) = Hello &&
	test $(shit config branch.g/g.dummy) = Hello
'

test_expect_success 'shit branch -c m2 m2 should work' '
	shit branch --create-reflog m2 &&
	shit reflog exists refs/heads/m2 &&
	shit config branch.m2.dummy Hello &&
	shit branch -c m2 m2 &&
	shit reflog exists refs/heads/m2 &&
	test $(shit config branch.m2.dummy) = Hello
'

test_expect_success 'shit branch -c zz zz/zz should fail' '
	shit branch --create-reflog zz &&
	shit reflog exists refs/heads/zz &&
	test_must_fail shit branch -c zz zz/zz
'

test_expect_success 'shit branch -c b/b b should fail' '
	shit branch --create-reflog b/b &&
	test_must_fail shit branch -c b/b b
'

test_expect_success 'shit branch -C o/q o/p should work when o/p exists' '
	shit branch --create-reflog o/q &&
	shit reflog exists refs/heads/o/q &&
	shit reflog exists refs/heads/o/p &&
	shit branch -C o/q o/p
'

test_expect_success 'shit branch -c -f o/q o/p should work when o/p exists' '
	shit reflog exists refs/heads/o/q &&
	shit reflog exists refs/heads/o/p &&
	shit branch -c -f o/q o/p
'

test_expect_success 'shit branch -c qq rr/qq should fail when rr exists' '
	shit branch qq &&
	shit branch rr &&
	test_must_fail shit branch -c qq rr/qq
'

test_expect_success 'shit branch -C b1 b2 should fail when b2 is checked out' '
	shit branch b1 &&
	shit checkout -b b2 &&
	test_must_fail shit branch -C b1 b2
'

test_expect_success 'shit branch -C c1 c2 should succeed when c1 is checked out' '
	shit checkout -b c1 &&
	shit branch c2 &&
	shit branch -C c1 c2 &&
	test $(shit rev-parse --abbrev-ref HEAD) = c1
'

test_expect_success 'shit branch -C c1 c2 should never touch HEAD' '
	msg="Branch: copied refs/heads/c1 to refs/heads/c2" &&
	shit reflog HEAD >actual &&
	! grep "$msg$" actual
'

test_expect_success 'shit branch -C main should work when main is checked out' '
	shit checkout main &&
	shit branch -C main
'

test_expect_success 'shit branch -C main main should work when main is checked out' '
	shit checkout main &&
	shit branch -C main main
'

test_expect_success 'shit branch -C main5 main5 should work when main is checked out' '
	shit checkout main &&
	shit branch main5 &&
	shit branch -C main5 main5
'

test_expect_success 'shit branch -C ab cd should overwrite existing config for cd' '
	shit branch --create-reflog cd &&
	shit reflog exists refs/heads/cd &&
	shit config branch.cd.dummy CD &&
	shit branch --create-reflog ab &&
	shit reflog exists refs/heads/ab &&
	shit config branch.ab.dummy AB &&
	shit branch -C ab cd &&
	shit reflog exists refs/heads/ab &&
	shit reflog exists refs/heads/cd &&
	test $(shit config branch.ab.dummy) = AB &&
	test $(shit config branch.cd.dummy) = AB
'

test_expect_success 'shit branch -c correctly copies multiple config sections' '
	FOO=1 &&
	export FOO &&
	test_when_finished "shit checkout main" &&
	shit checkout -b source2 main &&

	# Assert that a config file with multiple config sections has
	# those sections preserved...
	cat >expect <<-\EOF &&
	branch.source2.key1=value1
	branch.dest2.key1=value1
	more.gar.b=age
	branch.source2.key2=value2
	branch.dest2.key2=value2
	EOF
	cat >config.branch <<\EOF &&
;; Note the lack of -\EOF above & mixed indenting here. This is
;; intentional, we are also testing that the formatting of copied
;; sections is preserved.

;; Comment for source2. Tabs
[branch "source2"]
	;; Comment for the source2 value
	key1 = value1
;; Comment for more.gar. Spaces
[more "gar"]
    ;; Comment for the more.gar value
    b = age
;; Comment for source2, again. Mixed tabs/spaces.
[branch "source2"]
    ;; Comment for the source2 value, again
	key2 = value2
EOF
	cat config.branch >>.shit/config &&
	shit branch -c source2 dest2 &&
	shit config -f .shit/config -l | grep -F -e source2 -e dest2 -e more.gar >actual &&
	test_cmp expect actual &&

	# ...and that the comments and formatting for those sections
	# is also preserved.
	cat >expect <<\EOF &&
;; Comment for source2. Tabs
[branch "source2"]
	;; Comment for the source2 value
	key1 = value1
;; Comment for more.gar. Spaces
[branch "dest2"]
	;; Comment for the source2 value
	key1 = value1
;; Comment for more.gar. Spaces
[more "gar"]
    ;; Comment for the more.gar value
    b = age
;; Comment for source2, again. Mixed tabs/spaces.
[branch "source2"]
    ;; Comment for the source2 value, again
	key2 = value2
[branch "dest2"]
    ;; Comment for the source2 value, again
	key2 = value2
EOF
	sed -n -e "/Comment for source2/,\$p" .shit/config >actual &&
	test_cmp expect actual
'

test_expect_success 'deleting a symref' '
	shit branch target &&
	shit symbolic-ref refs/heads/symref refs/heads/target &&
	echo "Deleted branch symref (was refs/heads/target)." >expect &&
	shit branch -d symref >actual &&
	test_ref_exists refs/heads/target &&
	test_ref_missing refs/heads/symref &&
	test_cmp expect actual
'

test_expect_success 'deleting a dangling symref' '
	shit symbolic-ref refs/heads/dangling-symref nowhere &&
	shit symbolic-ref --no-recurse refs/heads/dangling-symref &&
	echo "Deleted branch dangling-symref (was nowhere)." >expect &&
	shit branch -d dangling-symref >actual &&
	test_ref_missing refs/heads/dangling-symref &&
	test_cmp expect actual
'

test_expect_success 'deleting a self-referential symref' '
	shit symbolic-ref refs/heads/self-reference refs/heads/self-reference &&
	test_ref_exists refs/heads/self-reference &&
	echo "Deleted branch self-reference (was refs/heads/self-reference)." >expect &&
	shit branch -d self-reference >actual &&
	test_ref_missing refs/heads/self-reference &&
	test_cmp expect actual
'

test_expect_success 'renaming a symref is not allowed' '
	shit symbolic-ref refs/heads/topic refs/heads/main &&
	test_must_fail shit branch -m topic new-topic &&
	shit symbolic-ref refs/heads/topic &&
	test_ref_exists refs/heads/main &&
	test_ref_missing refs/heads/new-topic
'

test_expect_success 'test tracking setup via --track' '
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --track my1 local/main &&
	test $(shit config branch.my1.remote) = local &&
	test $(shit config branch.my1.merge) = refs/heads/main
'

test_expect_success 'test tracking setup (non-wildcard, matching)' '
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/main:refs/remotes/local/main &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --track my4 local/main &&
	test $(shit config branch.my4.remote) = local &&
	test $(shit config branch.my4.merge) = refs/heads/main
'

test_expect_success 'tracking setup fails on non-matching refspec' '
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit config remote.local.fetch refs/heads/s:refs/remotes/local/s &&
	test_must_fail shit branch --track my5 local/main &&
	test_must_fail shit config branch.my5.remote &&
	test_must_fail shit config branch.my5.merge
'

test_expect_success 'test tracking setup via config' '
	shit config branch.autosetupmerge true &&
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch my3 local/main &&
	test $(shit config branch.my3.remote) = local &&
	test $(shit config branch.my3.merge) = refs/heads/main
'

test_expect_success 'test overriding tracking setup via --no-track' '
	shit config branch.autosetupmerge true &&
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --no-track my2 local/main &&
	shit config branch.autosetupmerge false &&
	! test "$(shit config branch.my2.remote)" = local &&
	! test "$(shit config branch.my2.merge)" = refs/heads/main
'

test_expect_success 'no tracking without .fetch entries' '
	shit config branch.autosetupmerge true &&
	shit branch my6 s &&
	shit config branch.autosetupmerge false &&
	test -z "$(shit config branch.my6.remote)" &&
	test -z "$(shit config branch.my6.merge)"
'

test_expect_success 'test tracking setup via --track but deeper' '
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/o/o || shit fetch local) &&
	shit branch --track my7 local/o/o &&
	test "$(shit config branch.my7.remote)" = local &&
	test "$(shit config branch.my7.merge)" = refs/heads/o/o
'

test_expect_success 'test deleting branch deletes branch config' '
	shit branch -d my7 &&
	test -z "$(shit config branch.my7.remote)" &&
	test -z "$(shit config branch.my7.merge)"
'

test_expect_success 'test deleting branch without config' '
	shit branch my7 s &&
	sha1=$(shit rev-parse my7 | cut -c 1-7) &&
	echo "Deleted branch my7 (was $sha1)." >expect &&
	shit branch -d my7 >actual 2>&1 &&
	test_cmp expect actual
'

test_expect_success 'deleting currently checked out branch fails' '
	shit worktree add -b my7 my7 &&
	test_must_fail shit -C my7 branch -d my7 &&
	test_must_fail shit branch -d my7 2>actual &&
	grep "^error: cannot delete branch .my7. used by worktree at " actual &&
	rm -r my7 &&
	shit worktree prune
'

test_expect_success 'deleting in-use branch fails' '
	shit worktree add my7 &&
	test_commit -C my7 bt7 &&
	shit -C my7 bisect start HEAD HEAD~2 &&
	test_must_fail shit -C my7 branch -d my7 &&
	test_must_fail shit branch -d my7 2>actual &&
	grep "^error: cannot delete branch .my7. used by worktree at " actual &&
	rm -r my7 &&
	shit worktree prune
'

test_expect_success 'test --track without .fetch entries' '
	shit branch --track my8 &&
	test "$(shit config branch.my8.remote)" &&
	test "$(shit config branch.my8.merge)"
'

test_expect_success 'branch from non-branch HEAD w/autosetupmerge=always' '
	shit config branch.autosetupmerge always &&
	shit branch my9 HEAD^ &&
	shit config branch.autosetupmerge false
'

test_expect_success 'branch from non-branch HEAD w/--track causes failure' '
	test_must_fail shit branch --track my10 HEAD^
'

test_expect_success 'branch from tag w/--track causes failure' '
	shit tag foobar &&
	test_must_fail shit branch --track my11 foobar
'

test_expect_success 'simple tracking works when remote branch name matches' '
	test_when_finished "rm -rf otherserver" &&
	shit init otherserver &&
	test_commit -C otherserver my_commit 1 &&
	shit -C otherserver branch feature &&
	test_config branch.autosetupmerge simple &&
	test_config remote.otherserver.url otherserver &&
	test_config remote.otherserver.fetch refs/heads/*:refs/remotes/otherserver/* &&
	shit fetch otherserver &&
	shit branch feature otherserver/feature &&
	test_cmp_config otherserver branch.feature.remote &&
	test_cmp_config refs/heads/feature branch.feature.merge
'

test_expect_success 'simple tracking skips when remote branch name does not match' '
	test_config branch.autosetupmerge simple &&
	test_config remote.local.url . &&
	test_config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	shit fetch local &&
	shit branch my-other local/main &&
	test_cmp_config "" --default "" branch.my-other.remote &&
	test_cmp_config "" --default "" branch.my-other.merge
'

test_expect_success 'simple tracking skips when remote ref is not a branch' '
	test_config branch.autosetupmerge simple &&
	test_config remote.localtags.url . &&
	test_config remote.localtags.fetch refs/tags/*:refs/remotes/localtags/* &&
	shit tag mytag12 main &&
	shit fetch localtags &&
	shit branch mytag12 localtags/mytag12 &&
	test_cmp_config "" --default "" branch.mytag12.remote &&
	test_cmp_config "" --default "" branch.mytag12.merge
'

test_expect_success '--set-upstream-to fails on multiple branches' '
	echo "fatal: too many arguments to set new upstream" >expect &&
	test_must_fail shit branch --set-upstream-to main a b c 2>err &&
	test_cmp expect err
'

test_expect_success '--set-upstream-to fails on detached HEAD' '
	shit checkout HEAD^{} &&
	test_when_finished shit checkout - &&
	echo "fatal: could not set upstream of HEAD to main when it does not point to any branch" >expect &&
	test_must_fail shit branch --set-upstream-to main 2>err &&
	test_cmp expect err
'

test_expect_success '--set-upstream-to fails on a missing dst branch' '
	echo "fatal: branch '"'"'does-not-exist'"'"' does not exist" >expect &&
	test_must_fail shit branch --set-upstream-to main does-not-exist 2>err &&
	test_cmp expect err
'

test_expect_success '--set-upstream-to fails on a missing src branch' '
	test_must_fail shit branch --set-upstream-to does-not-exist main 2>err &&
	test_grep "the requested upstream branch '"'"'does-not-exist'"'"' does not exist" err
'

test_expect_success '--set-upstream-to fails on a non-ref' '
	echo "fatal: cannot set up tracking information; starting point '"'"'HEAD^{}'"'"' is not a branch" >expect &&
	test_must_fail shit branch --set-upstream-to HEAD^{} 2>err &&
	test_cmp expect err
'

test_expect_success '--set-upstream-to fails on locked config' '
	test_when_finished "rm -f .shit/config.lock" &&
	>.shit/config.lock &&
	shit branch locked &&
	test_must_fail shit branch --set-upstream-to locked 2>err &&
	test_grep "could not lock config file .shit/config" err
'

test_expect_success 'use --set-upstream-to modify HEAD' '
	test_config branch.main.remote foo &&
	test_config branch.main.merge foo &&
	shit branch my12 &&
	shit branch --set-upstream-to my12 &&
	test "$(shit config branch.main.remote)" = "." &&
	test "$(shit config branch.main.merge)" = "refs/heads/my12"
'

test_expect_success 'use --set-upstream-to modify a particular branch' '
	shit branch my13 &&
	shit branch --set-upstream-to main my13 &&
	test_when_finished "shit branch --unset-upstream my13" &&
	test "$(shit config branch.my13.remote)" = "." &&
	test "$(shit config branch.my13.merge)" = "refs/heads/main"
'

test_expect_success '--unset-upstream should fail if given a non-existent branch' '
	echo "fatal: branch '"'"'i-dont-exist'"'"' has no upstream information" >expect &&
	test_must_fail shit branch --unset-upstream i-dont-exist 2>err &&
	test_cmp expect err
'

test_expect_success '--unset-upstream should fail if config is locked' '
	test_when_finished "rm -f .shit/config.lock" &&
	shit branch --set-upstream-to locked &&
	>.shit/config.lock &&
	test_must_fail shit branch --unset-upstream 2>err &&
	test_grep "could not lock config file .shit/config" err
'

test_expect_success 'test --unset-upstream on HEAD' '
	shit branch my14 &&
	test_config branch.main.remote foo &&
	test_config branch.main.merge foo &&
	shit branch --set-upstream-to my14 &&
	shit branch --unset-upstream &&
	test_must_fail shit config branch.main.remote &&
	test_must_fail shit config branch.main.merge &&
	# fail for a branch without upstream set
	echo "fatal: branch '"'"'main'"'"' has no upstream information" >expect &&
	test_must_fail shit branch --unset-upstream 2>err &&
	test_cmp expect err
'

test_expect_success '--unset-upstream should fail on multiple branches' '
	echo "fatal: too many arguments to unset upstream" >expect &&
	test_must_fail shit branch --unset-upstream a b c 2>err &&
	test_cmp expect err
'

test_expect_success '--unset-upstream should fail on detached HEAD' '
	shit checkout HEAD^{} &&
	test_when_finished shit checkout - &&
	echo "fatal: could not unset upstream of HEAD when it does not point to any branch" >expect &&
	test_must_fail shit branch --unset-upstream 2>err &&
	test_cmp expect err
'

test_expect_success 'test --unset-upstream on a particular branch' '
	shit branch my15 &&
	shit branch --set-upstream-to main my14 &&
	shit branch --unset-upstream my14 &&
	test_must_fail shit config branch.my14.remote &&
	test_must_fail shit config branch.my14.merge
'

test_expect_success 'disabled option --set-upstream fails' '
	test_must_fail shit branch --set-upstream origin/main
'

test_expect_success '--set-upstream-to notices an error to set branch as own upstream' "
	shit branch --set-upstream-to refs/heads/my13 my13 2>actual &&
	cat >expect <<-\EOF &&
	warning: not setting branch 'my13' as its own upstream
	EOF
	test_expect_code 1 shit config branch.my13.remote &&
	test_expect_code 1 shit config branch.my13.merge &&
	test_cmp expect actual
"

test_expect_success 'shit checkout -b g/h/i -l should create a branch and a log' '
	test_when_finished shit checkout main &&
	shit_COMMITTER_DATE="2005-05-26 23:30" \
	shit checkout -b g/h/i -l main &&
	test_ref_exists refs/heads/g/h/i &&
	cat >expect <<-EOF &&
	$HEAD refs/heads/g/h/i@{0}: branch: Created from main
	EOF
	shit reflog show --no-abbrev-commit refs/heads/g/h/i >actual &&
	test_cmp expect actual
'

test_expect_success 'checkout -b makes reflog by default' '
	shit checkout main &&
	shit config --unset core.logAllRefUpdates &&
	shit checkout -b alpha &&
	shit rev-parse --verify alpha@{0}
'

test_expect_success 'checkout -b does not make reflog when core.logAllRefUpdates = false' '
	shit checkout main &&
	shit config core.logAllRefUpdates false &&
	shit checkout -b beta &&
	test_must_fail shit rev-parse --verify beta@{0}
'

test_expect_success 'checkout -b with -l makes reflog when core.logAllRefUpdates = false' '
	shit checkout main &&
	shit checkout -lb gamma &&
	shit config --unset core.logAllRefUpdates &&
	shit rev-parse --verify gamma@{0}
'

test_expect_success 'avoid ambiguous track and advise' '
	shit config branch.autosetupmerge true &&
	shit config remote.ambi1.url lalala &&
	shit config remote.ambi1.fetch refs/heads/lalala:refs/heads/main &&
	shit config remote.ambi2.url lilili &&
	shit config remote.ambi2.fetch refs/heads/lilili:refs/heads/main &&
	cat <<-EOF >expected &&
	fatal: not tracking: ambiguous information for ref '\''refs/heads/main'\''
	hint: There are multiple remotes whose fetch refspecs map to the remote
	hint: tracking ref '\''refs/heads/main'\'':
	hint:   ambi1
	hint:   ambi2
	hint:
	hint: This is typically a configuration error.
	hint:
	hint: To support setting up tracking branches, ensure that
	hint: different remotes'\'' fetch refspecs map into different
	hint: tracking namespaces.
	EOF
	test_must_fail shit branch all1 main 2>actual &&
	test_cmp expected actual &&
	test -z "$(shit config branch.all1.merge)"
'

test_expect_success 'autosetuprebase local on a tracked local branch' '
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	shit config branch.autosetuprebase local &&
	(shit show-ref -q refs/remotes/local/o || shit fetch local) &&
	shit branch mybase &&
	shit branch --track myr1 mybase &&
	test "$(shit config branch.myr1.remote)" = . &&
	test "$(shit config branch.myr1.merge)" = refs/heads/mybase &&
	test "$(shit config branch.myr1.rebase)" = true
'

test_expect_success 'autosetuprebase always on a tracked local branch' '
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	shit config branch.autosetuprebase always &&
	(shit show-ref -q refs/remotes/local/o || shit fetch local) &&
	shit branch mybase2 &&
	shit branch --track myr2 mybase &&
	test "$(shit config branch.myr2.remote)" = . &&
	test "$(shit config branch.myr2.merge)" = refs/heads/mybase &&
	test "$(shit config branch.myr2.rebase)" = true
'

test_expect_success 'autosetuprebase remote on a tracked local branch' '
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	shit config branch.autosetuprebase remote &&
	(shit show-ref -q refs/remotes/local/o || shit fetch local) &&
	shit branch mybase3 &&
	shit branch --track myr3 mybase2 &&
	test "$(shit config branch.myr3.remote)" = . &&
	test "$(shit config branch.myr3.merge)" = refs/heads/mybase2 &&
	! test "$(shit config branch.myr3.rebase)" = true
'

test_expect_success 'autosetuprebase never on a tracked local branch' '
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	shit config branch.autosetuprebase never &&
	(shit show-ref -q refs/remotes/local/o || shit fetch local) &&
	shit branch mybase4 &&
	shit branch --track myr4 mybase2 &&
	test "$(shit config branch.myr4.remote)" = . &&
	test "$(shit config branch.myr4.merge)" = refs/heads/mybase2 &&
	! test "$(shit config branch.myr4.rebase)" = true
'

test_expect_success 'autosetuprebase local on a tracked remote branch' '
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	shit config branch.autosetuprebase local &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --track myr5 local/main &&
	test "$(shit config branch.myr5.remote)" = local &&
	test "$(shit config branch.myr5.merge)" = refs/heads/main &&
	! test "$(shit config branch.myr5.rebase)" = true
'

test_expect_success 'autosetuprebase never on a tracked remote branch' '
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	shit config branch.autosetuprebase never &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --track myr6 local/main &&
	test "$(shit config branch.myr6.remote)" = local &&
	test "$(shit config branch.myr6.merge)" = refs/heads/main &&
	! test "$(shit config branch.myr6.rebase)" = true
'

test_expect_success 'autosetuprebase remote on a tracked remote branch' '
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	shit config branch.autosetuprebase remote &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --track myr7 local/main &&
	test "$(shit config branch.myr7.remote)" = local &&
	test "$(shit config branch.myr7.merge)" = refs/heads/main &&
	test "$(shit config branch.myr7.rebase)" = true
'

test_expect_success 'autosetuprebase always on a tracked remote branch' '
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	shit config branch.autosetuprebase remote &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --track myr8 local/main &&
	test "$(shit config branch.myr8.remote)" = local &&
	test "$(shit config branch.myr8.merge)" = refs/heads/main &&
	test "$(shit config branch.myr8.rebase)" = true
'

test_expect_success 'autosetuprebase unconfigured on a tracked remote branch' '
	shit config --unset branch.autosetuprebase &&
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --track myr9 local/main &&
	test "$(shit config branch.myr9.remote)" = local &&
	test "$(shit config branch.myr9.merge)" = refs/heads/main &&
	test "z$(shit config branch.myr9.rebase)" = z
'

test_expect_success 'autosetuprebase unconfigured on a tracked local branch' '
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/o || shit fetch local) &&
	shit branch mybase10 &&
	shit branch --track myr10 mybase2 &&
	test "$(shit config branch.myr10.remote)" = . &&
	test "$(shit config branch.myr10.merge)" = refs/heads/mybase2 &&
	test "z$(shit config branch.myr10.rebase)" = z
'

test_expect_success 'autosetuprebase unconfigured on untracked local branch' '
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --no-track myr11 mybase2 &&
	test "z$(shit config branch.myr11.remote)" = z &&
	test "z$(shit config branch.myr11.merge)" = z &&
	test "z$(shit config branch.myr11.rebase)" = z
'

test_expect_success 'autosetuprebase unconfigured on untracked remote branch' '
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --no-track myr12 local/main &&
	test "z$(shit config branch.myr12.remote)" = z &&
	test "z$(shit config branch.myr12.merge)" = z &&
	test "z$(shit config branch.myr12.rebase)" = z
'

test_expect_success 'autosetuprebase never on an untracked local branch' '
	shit config branch.autosetuprebase never &&
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --no-track myr13 mybase2 &&
	test "z$(shit config branch.myr13.remote)" = z &&
	test "z$(shit config branch.myr13.merge)" = z &&
	test "z$(shit config branch.myr13.rebase)" = z
'

test_expect_success 'autosetuprebase local on an untracked local branch' '
	shit config branch.autosetuprebase local &&
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --no-track myr14 mybase2 &&
	test "z$(shit config branch.myr14.remote)" = z &&
	test "z$(shit config branch.myr14.merge)" = z &&
	test "z$(shit config branch.myr14.rebase)" = z
'

test_expect_success 'autosetuprebase remote on an untracked local branch' '
	shit config branch.autosetuprebase remote &&
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --no-track myr15 mybase2 &&
	test "z$(shit config branch.myr15.remote)" = z &&
	test "z$(shit config branch.myr15.merge)" = z &&
	test "z$(shit config branch.myr15.rebase)" = z
'

test_expect_success 'autosetuprebase always on an untracked local branch' '
	shit config branch.autosetuprebase always &&
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --no-track myr16 mybase2 &&
	test "z$(shit config branch.myr16.remote)" = z &&
	test "z$(shit config branch.myr16.merge)" = z &&
	test "z$(shit config branch.myr16.rebase)" = z
'

test_expect_success 'autosetuprebase never on an untracked remote branch' '
	shit config branch.autosetuprebase never &&
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --no-track myr17 local/main &&
	test "z$(shit config branch.myr17.remote)" = z &&
	test "z$(shit config branch.myr17.merge)" = z &&
	test "z$(shit config branch.myr17.rebase)" = z
'

test_expect_success 'autosetuprebase local on an untracked remote branch' '
	shit config branch.autosetuprebase local &&
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --no-track myr18 local/main &&
	test "z$(shit config branch.myr18.remote)" = z &&
	test "z$(shit config branch.myr18.merge)" = z &&
	test "z$(shit config branch.myr18.rebase)" = z
'

test_expect_success 'autosetuprebase remote on an untracked remote branch' '
	shit config branch.autosetuprebase remote &&
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --no-track myr19 local/main &&
	test "z$(shit config branch.myr19.remote)" = z &&
	test "z$(shit config branch.myr19.merge)" = z &&
	test "z$(shit config branch.myr19.rebase)" = z
'

test_expect_success 'autosetuprebase always on an untracked remote branch' '
	shit config branch.autosetuprebase always &&
	shit config remote.local.url . &&
	shit config remote.local.fetch refs/heads/*:refs/remotes/local/* &&
	(shit show-ref -q refs/remotes/local/main || shit fetch local) &&
	shit branch --no-track myr20 local/main &&
	test "z$(shit config branch.myr20.remote)" = z &&
	test "z$(shit config branch.myr20.merge)" = z &&
	test "z$(shit config branch.myr20.rebase)" = z
'

test_expect_success 'autosetuprebase always on detached HEAD' '
	shit config branch.autosetupmerge always &&
	test_when_finished shit checkout main &&
	shit checkout HEAD^0 &&
	shit branch my11 &&
	test -z "$(shit config branch.my11.remote)" &&
	test -z "$(shit config branch.my11.merge)"
'

test_expect_success 'detect misconfigured autosetuprebase (bad value)' '
	shit config branch.autosetuprebase garbage &&
	test_must_fail shit branch
'

test_expect_success 'detect misconfigured autosetuprebase (no value)' '
	shit config --unset branch.autosetuprebase &&
	echo "[branch] autosetuprebase" >>.shit/config &&
	test_must_fail shit branch &&
	shit config --unset branch.autosetuprebase
'

test_expect_success 'attempt to delete a branch without base and unmerged to HEAD' '
	shit checkout my9 &&
	shit config --unset branch.my8.merge &&
	test_must_fail shit branch -d my8
'

test_expect_success 'attempt to delete a branch merged to its base' '
	# we are on my9 which is the initial commit; traditionally
	# we would not have allowed deleting my8 that is not merged
	# to my9, but it is set to track main that already has my8
	shit config branch.my8.merge refs/heads/main &&
	shit branch -d my8
'

test_expect_success 'attempt to delete a branch merged to its base' '
	shit checkout main &&
	echo Third >>A &&
	shit commit -m "Third commit" A &&
	shit branch -t my10 my9 &&
	shit branch -f my10 HEAD^ &&
	# we are on main which is at the third commit, and my10
	# is behind us, so traditionally we would have allowed deleting
	# it; but my10 is set to track my9 that is further behind.
	test_must_fail shit branch -d my10
'

test_expect_success 'branch --delete --force removes dangling branch' '
	shit checkout main &&
	test_commit unstable &&
	hash=$(shit rev-parse HEAD) &&
	objpath=$(echo $hash | sed -e "s|^..|.shit/objects/&/|") &&
	shit branch --no-track dangling &&
	mv $objpath $objpath.x &&
	test_when_finished "mv $objpath.x $objpath" &&
	shit branch --delete --force dangling &&
	shit for-each-ref refs/heads/dangling >actual &&
	test_must_be_empty actual
'

test_expect_success 'use --edit-description' '
	EDITOR=: shit branch --edit-description &&
	test_expect_code 1 shit config branch.main.description &&

	write_script editor <<-\EOF &&
		echo "New contents" >"$1"
	EOF
	EDITOR=./editor shit branch --edit-description &&
		write_script editor <<-\EOF &&
		shit stripspace -s <"$1" >"EDITOR_OUTPUT"
	EOF
	EDITOR=./editor shit branch --edit-description &&
	echo "New contents" >expect &&
	test_cmp expect EDITOR_OUTPUT
'

test_expect_success 'detect typo in branch name when using --edit-description' '
	write_script editor <<-\EOF &&
		echo "New contents" >"$1"
	EOF
	test_must_fail env EDITOR=./editor shit branch --edit-description no-such-branch
'

test_expect_success 'refuse --edit-description on unborn branch for now' '
	test_when_finished "shit checkout main" &&
	write_script editor <<-\EOF &&
		echo "New contents" >"$1"
	EOF
	shit checkout --orphan unborn &&
	test_must_fail env EDITOR=./editor shit branch --edit-description
'

test_expect_success '--merged catches invalid object names' '
	test_must_fail shit branch --merged 0000000000000000000000000000000000000000
'

test_expect_success '--list during rebase' '
	test_when_finished "reset_rebase" &&
	shit checkout main &&
	FAKE_LINES="1 edit 2" &&
	export FAKE_LINES &&
	set_fake_editor &&
	shit rebase -i HEAD~2 &&
	shit branch --list >actual &&
	test_grep "rebasing main" actual
'

test_expect_success '--list during rebase from detached HEAD' '
	test_when_finished "reset_rebase && shit checkout main" &&
	shit checkout main^0 &&
	oid=$(shit rev-parse --short HEAD) &&
	FAKE_LINES="1 edit 2" &&
	export FAKE_LINES &&
	set_fake_editor &&
	shit rebase -i HEAD~2 &&
	shit branch --list >actual &&
	test_grep "rebasing detached HEAD $oid" actual
'

test_expect_success 'tracking with unexpected .fetch refspec' '
	rm -rf a b c d &&
	shit init -b main a &&
	(
		cd a &&
		test_commit a
	) &&
	shit init -b main b &&
	(
		cd b &&
		test_commit b
	) &&
	shit init -b main c &&
	(
		cd c &&
		test_commit c &&
		shit remote add a ../a &&
		shit remote add b ../b &&
		shit fetch --all
	) &&
	shit init -b main d &&
	(
		cd d &&
		shit remote add c ../c &&
		shit config remote.c.fetch "+refs/remotes/*:refs/remotes/*" &&
		shit fetch c &&
		shit branch --track local/a/main remotes/a/main &&
		test "$(shit config branch.local/a/main.remote)" = "c" &&
		test "$(shit config branch.local/a/main.merge)" = "refs/remotes/a/main" &&
		shit rev-parse --verify a >expect &&
		shit rev-parse --verify local/a/main >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'configured committerdate sort' '
	shit init -b main sort &&
	test_config -C sort branch.sort "committerdate" &&

	(
		cd sort &&
		test_commit initial &&
		shit checkout -b a &&
		test_commit a &&
		shit checkout -b c &&
		test_commit c &&
		shit checkout -b b &&
		test_commit b &&
		shit branch >actual &&
		cat >expect <<-\EOF &&
		  main
		  a
		  c
		* b
		EOF
		test_cmp expect actual
	)
'

test_expect_success 'option override configured sort' '
	test_config -C sort branch.sort "committerdate" &&

	(
		cd sort &&
		shit branch --sort=refname >actual &&
		cat >expect <<-\EOF &&
		  a
		* b
		  c
		  main
		EOF
		test_cmp expect actual
	)
'

test_expect_success '--no-sort cancels config sort keys' '
	test_config -C sort branch.sort "-refname" &&

	(
		cd sort &&

		# objecttype is identical for all of them, so sort falls back on
		# default (ascending refname)
		shit branch \
			--no-sort \
			--sort="objecttype" >actual &&
		cat >expect <<-\EOF &&
		  a
		* b
		  c
		  main
		EOF
		test_cmp expect actual
	)

'

test_expect_success '--no-sort cancels command line sort keys' '
	(
		cd sort &&

		# objecttype is identical for all of them, so sort falls back on
		# default (ascending refname)
		shit branch \
			--sort="-refname" \
			--no-sort \
			--sort="objecttype" >actual &&
		cat >expect <<-\EOF &&
		  a
		* b
		  c
		  main
		EOF
		test_cmp expect actual
	)
'

test_expect_success '--no-sort without subsequent --sort prints expected branches' '
	(
		cd sort &&

		# Sort the results with `sort` for a consistent comparison
		# against expected
		shit branch --no-sort | sort >actual &&
		cat >expect <<-\EOF &&
		  a
		  c
		  main
		* b
		EOF
		test_cmp expect actual
	)
'

test_expect_success 'invalid sort parameter in configuration' '
	test_config -C sort branch.sort "v:notvalid" &&

	(
		cd sort &&

		# this works in the "listing" mode, so bad sort key
		# is a dying offence.
		test_must_fail shit branch &&

		# these do not need to use sorting, and should all
		# succeed
		shit branch newone main &&
		shit branch -c newone newerone &&
		shit branch -m newone newestone &&
		shit branch -d newerone newestone
	)
'

test_expect_success 'tracking info copied with --track=inherit' '
	shit branch --track=inherit foo2 my1 &&
	test_cmp_config local branch.foo2.remote &&
	test_cmp_config refs/heads/main branch.foo2.merge
'

test_expect_success 'tracking info copied with autoSetupMerge=inherit' '
	test_unconfig branch.autoSetupMerge &&
	# default config does not copy tracking info
	shit branch foo-no-inherit my1 &&
	test_cmp_config "" --default "" branch.foo-no-inherit.remote &&
	test_cmp_config "" --default "" branch.foo-no-inherit.merge &&
	# with autoSetupMerge=inherit, we copy tracking info from my1
	test_config branch.autoSetupMerge inherit &&
	shit branch foo3 my1 &&
	test_cmp_config local branch.foo3.remote &&
	test_cmp_config refs/heads/main branch.foo3.merge &&
	# no tracking info to inherit from main
	shit branch main2 main &&
	test_cmp_config "" --default "" branch.main2.remote &&
	test_cmp_config "" --default "" branch.main2.merge
'

test_expect_success '--track overrides branch.autoSetupMerge' '
	test_config branch.autoSetupMerge inherit &&
	shit branch --track=direct foo4 my1 &&
	test_cmp_config . branch.foo4.remote &&
	test_cmp_config refs/heads/my1 branch.foo4.merge &&
	shit branch --no-track foo5 my1 &&
	test_cmp_config "" --default "" branch.foo5.remote &&
	test_cmp_config "" --default "" branch.foo5.merge
'

test_expect_success 'errors if given a bad branch name' '
	cat <<-\EOF >expect &&
	fatal: '\''foo..bar'\'' is not a valid branch name
	hint: See `man shit check-ref-format`
	hint: Disable this message with "shit config advice.refSyntax false"
	EOF
	test_must_fail shit branch foo..bar >actual 2>&1 &&
	test_cmp expect actual
'

test_done
