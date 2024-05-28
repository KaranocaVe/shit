#!/bin/sh

test_description='shit branch display tests'
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-terminal.sh

test_expect_success 'make commits' '
	echo content >file &&
	shit add file &&
	shit commit -m one &&
	shit branch -M main &&
	echo content >>file &&
	shit commit -a -m two
'

test_expect_success 'make branches' '
	shit branch branch-one &&
	shit branch branch-two HEAD^
'

test_expect_success 'make remote branches' '
	shit update-ref refs/remotes/origin/branch-one branch-one &&
	shit update-ref refs/remotes/origin/branch-two branch-two &&
	shit symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/branch-one
'

cat >expect <<'EOF'
  branch-one
  branch-two
* main
EOF
test_expect_success 'shit branch shows local branches' '
	shit branch >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch --list shows local branches' '
	shit branch --list >actual &&
	test_cmp expect actual
'

cat >expect <<'EOF'
  branch-one
  branch-two
EOF
test_expect_success 'shit branch --list pattern shows matching local branches' '
	shit branch --list branch* >actual &&
	test_cmp expect actual
'

cat >expect <<'EOF'
  origin/HEAD -> origin/branch-one
  origin/branch-one
  origin/branch-two
EOF
test_expect_success 'shit branch -r shows remote branches' '
	shit branch -r >actual &&
	test_cmp expect actual &&

	shit branch --remotes >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch --no-remotes is rejected' '
	test_must_fail shit branch --no-remotes 2>err &&
	grep "unknown option .no-remotes." err
'

cat >expect <<'EOF'
  branch-one
  branch-two
* main
  remotes/origin/HEAD -> origin/branch-one
  remotes/origin/branch-one
  remotes/origin/branch-two
EOF
test_expect_success 'shit branch -a shows local and remote branches' '
	shit branch -a >actual &&
	test_cmp expect actual &&

	shit branch --all >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch --no-all is rejected' '
	test_must_fail shit branch --no-all 2>err &&
	grep "unknown option .no-all." err
'

cat >expect <<'EOF'
two
one
two
EOF
test_expect_success 'shit branch -v shows branch summaries' '
	shit branch -v >tmp &&
	awk "{print \$NF}" <tmp >actual &&
	test_cmp expect actual
'

cat >expect <<'EOF'
two
one
EOF
test_expect_success 'shit branch --list -v pattern shows branch summaries' '
	shit branch --list -v branch* >tmp &&
	awk "{print \$NF}" <tmp >actual &&
	test_cmp expect actual
'
test_expect_success 'shit branch --ignore-case --list -v pattern shows branch summaries' '
	shit branch --list --ignore-case -v BRANCH* >tmp &&
	awk "{print \$NF}" <tmp >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch -v pattern does not show branch summaries' '
	test_must_fail shit branch -v branch*
'

test_expect_success 'shit branch `--show-current` shows current branch' '
	cat >expect <<-\EOF &&
	branch-two
	EOF
	shit checkout branch-two &&
	shit branch --show-current >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch `--show-current` is silent when detached HEAD' '
	shit checkout HEAD^0 &&
	shit branch --show-current >actual &&
	test_must_be_empty actual
'

test_expect_success 'shit branch `--show-current` works properly when tag exists' '
	cat >expect <<-\EOF &&
	branch-and-tag-name
	EOF
	test_when_finished "
		shit checkout branch-one
		shit branch -D branch-and-tag-name
	" &&
	shit checkout -b branch-and-tag-name &&
	test_when_finished "shit tag -d branch-and-tag-name" &&
	shit tag branch-and-tag-name &&
	shit branch --show-current >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch `--show-current` works properly with worktrees' '
	cat >expect <<-\EOF &&
	branch-one
	branch-two
	EOF
	shit checkout branch-one &&
	test_when_finished "
		shit worktree remove worktree_dir
	" &&
	shit worktree add worktree_dir branch-two &&
	{
		shit branch --show-current &&
		shit -C worktree_dir branch --show-current
	} >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch shows detached HEAD properly' '
	cat >expect <<EOF &&
* (HEAD detached at $(shit rev-parse --short HEAD^0))
  branch-one
  branch-two
  main
EOF
	shit checkout HEAD^0 &&
	shit branch >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch shows detached HEAD properly after checkout --detach' '
	shit checkout main &&
	cat >expect <<EOF &&
* (HEAD detached at $(shit rev-parse --short HEAD^0))
  branch-one
  branch-two
  main
EOF
	shit checkout --detach &&
	shit branch >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch shows detached HEAD properly after moving' '
	cat >expect <<EOF &&
* (HEAD detached from $(shit rev-parse --short HEAD))
  branch-one
  branch-two
  main
EOF
	shit reset --hard HEAD^1 &&
	shit branch >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch shows detached HEAD properly from tag' '
	cat >expect <<EOF &&
* (HEAD detached at fromtag)
  branch-one
  branch-two
  main
EOF
	shit tag fromtag main &&
	shit checkout fromtag &&
	shit branch >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch shows detached HEAD properly after moving from tag' '
	cat >expect <<EOF &&
* (HEAD detached from fromtag)
  branch-one
  branch-two
  main
EOF
	shit reset --hard HEAD^1 &&
	shit branch >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch `--sort=[-]objectsize` option' '
	cat >expect <<-\EOF &&
	* (HEAD detached from fromtag)
	  branch-two
	  branch-one
	  main
	EOF
	shit branch --sort=objectsize >actual &&
	test_cmp expect actual &&

	cat >expect <<-\EOF &&
	* (HEAD detached from fromtag)
	  branch-one
	  main
	  branch-two
	EOF
	shit branch --sort=-objectsize >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch `--sort=[-]type` option' '
	cat >expect <<-\EOF &&
	* (HEAD detached from fromtag)
	  branch-one
	  branch-two
	  main
	EOF
	shit branch --sort=type >actual &&
	test_cmp expect actual &&

	cat >expect <<-\EOF &&
	* (HEAD detached from fromtag)
	  branch-one
	  branch-two
	  main
	EOF
	shit branch --sort=-type >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch `--sort=[-]version:refname` option' '
	cat >expect <<-\EOF &&
	* (HEAD detached from fromtag)
	  branch-one
	  branch-two
	  main
	EOF
	shit branch --sort=version:refname >actual &&
	test_cmp expect actual &&

	cat >expect <<-\EOF &&
	* (HEAD detached from fromtag)
	  main
	  branch-two
	  branch-one
	EOF
	shit branch --sort=-version:refname >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch --points-at option' '
	cat >expect <<-\EOF &&
	  branch-one
	  main
	EOF
	shit branch --points-at=branch-one >actual &&
	test_cmp expect actual
'

test_expect_success 'ambiguous branch/tag not marked' '
	shit tag ambiguous &&
	shit branch ambiguous &&
	echo "  ambiguous" >expect &&
	shit branch --list ambiguous >actual &&
	test_cmp expect actual
'

test_expect_success 'local-branch symrefs shortened properly' '
	shit symbolic-ref refs/heads/ref-to-branch refs/heads/branch-one &&
	shit symbolic-ref refs/heads/ref-to-remote refs/remotes/origin/branch-one &&
	cat >expect <<-\EOF &&
	  ref-to-branch -> branch-one
	  ref-to-remote -> origin/branch-one
	EOF
	shit branch >actual.raw &&
	grep ref-to <actual.raw >actual &&
	test_cmp expect actual
'

test_expect_success 'sort branches, ignore case' '
	(
		shit init -b main sort-icase &&
		cd sort-icase &&
		test_commit initial &&
		shit branch branch-one &&
		shit branch BRANCH-two &&
		shit branch --list | awk "{print \$NF}" >actual &&
		cat >expected <<-\EOF &&
		BRANCH-two
		branch-one
		main
		EOF
		test_cmp expected actual &&
		shit branch --list -i | awk "{print \$NF}" >actual &&
		cat >expected <<-\EOF &&
		branch-one
		BRANCH-two
		main
		EOF
		test_cmp expected actual
	)
'

test_expect_success 'shit branch --format option' '
	cat >expect <<-\EOF &&
	Refname is (HEAD detached from fromtag)
	Refname is refs/heads/ambiguous
	Refname is refs/heads/branch-one
	Refname is refs/heads/branch-two
	Refname is refs/heads/main
	Refname is refs/heads/ref-to-branch
	Refname is refs/heads/ref-to-remote
	EOF
	shit branch --format="Refname is %(refname)" >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch --format with ahead-behind' '
	cat >expect <<-\EOF &&
	(HEAD detached from fromtag) 0 0
	refs/heads/ambiguous 0 0
	refs/heads/branch-one 1 0
	refs/heads/branch-two 0 0
	refs/heads/main 1 0
	refs/heads/ref-to-branch 1 0
	refs/heads/ref-to-remote 1 0
	EOF
	shit branch --format="%(refname) %(ahead-behind:HEAD)" >actual &&
	test_cmp expect actual
'

test_expect_success 'shit branch with --format=%(rest) must fail' '
	test_must_fail shit branch --format="%(rest)" >actual
'

test_expect_success 'shit branch --format --omit-empty' '
	cat >expect <<-\EOF &&
	Refname is (HEAD detached from fromtag)
	Refname is refs/heads/ambiguous
	Refname is refs/heads/branch-one
	Refname is refs/heads/branch-two

	Refname is refs/heads/ref-to-branch
	Refname is refs/heads/ref-to-remote
	EOF
	shit branch --format="%(if:notequals=refs/heads/main)%(refname)%(then)Refname is %(refname)%(end)" >actual &&
	test_cmp expect actual &&
	cat >expect <<-\EOF &&
	Refname is (HEAD detached from fromtag)
	Refname is refs/heads/ambiguous
	Refname is refs/heads/branch-one
	Refname is refs/heads/branch-two
	Refname is refs/heads/ref-to-branch
	Refname is refs/heads/ref-to-remote
	EOF
	shit branch --omit-empty --format="%(if:notequals=refs/heads/main)%(refname)%(then)Refname is %(refname)%(end)" >actual &&
	test_cmp expect actual
'

test_expect_success 'worktree colors correct' '
	cat >expect <<-EOF &&
	* <GREEN>(HEAD detached from fromtag)<RESET>
	  ambiguous<RESET>
	  branch-one<RESET>
	+ <CYAN>branch-two<RESET>
	  main<RESET>
	  ref-to-branch<RESET> -> branch-one
	  ref-to-remote<RESET> -> origin/branch-one
	EOF
	shit worktree add worktree_dir branch-two &&
	shit branch --color >actual.raw &&
	rm -r worktree_dir &&
	shit worktree prune &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect actual
'

test_expect_success "set up color tests" '
	echo "<RED>main<RESET>" >expect.color &&
	echo "main" >expect.bare &&
	color_args="--format=%(color:red)%(refname:short) --list main"
'

test_expect_success '%(color) omitted without tty' '
	TERM=vt100 shit branch $color_args >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect.bare actual
'

test_expect_success TTY '%(color) present with tty' '
	test_terminal shit branch $color_args >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect.color actual
'

test_expect_success '--color overrides auto-color' '
	shit branch --color $color_args >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect.color actual
'

test_expect_success 'verbose output lists worktree path' '
	one=$(shit rev-parse --short HEAD) &&
	two=$(shit rev-parse --short main) &&
	cat >expect <<-EOF &&
	* (HEAD detached from fromtag) $one one
	  ambiguous                    $one one
	  branch-one                   $two two
	+ branch-two                   $one ($(pwd)/worktree_dir) one
	  main                         $two two
	  ref-to-branch                $two two
	  ref-to-remote                $two two
	EOF
	shit worktree add worktree_dir branch-two &&
	shit branch -vv >actual &&
	rm -r worktree_dir &&
	shit worktree prune &&
	test_cmp expect actual
'

test_done
