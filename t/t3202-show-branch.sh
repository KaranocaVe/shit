#!/bin/sh

test_description='test show-branch'

. ./test-lib.sh

test_expect_success 'error descriptions on empty repository' '
	current=$(shit branch --show-current) &&
	cat >expect <<-EOF &&
	error: no commit on branch '\''$current'\'' yet
	EOF
	test_must_fail shit branch --edit-description 2>actual &&
	test_cmp expect actual &&
	test_must_fail shit branch --edit-description $current 2>actual &&
	test_cmp expect actual
'

test_expect_success 'fatal descriptions on empty repository' '
	current=$(shit branch --show-current) &&
	cat >expect <<-EOF &&
	fatal: no commit on branch '\''$current'\'' yet
	EOF
	test_must_fail shit branch --set-upstream-to=non-existent 2>actual &&
	test_cmp expect actual &&
	test_must_fail shit branch -c new-branch 2>actual &&
	test_cmp expect actual
'

test_expect_success 'setup' '
	test_commit initial &&
	for i in $(test_seq 1 10)
	do
		shit checkout -b branch$i initial &&
		test_commit --no-tag branch$i || return 1
	done &&
	shit for-each-ref \
		--sort=version:refname \
		--format="%(refname:strip=2)" \
		"refs/heads/branch*" >branches.sorted &&
	sed "s/^> //" >expect <<-\EOF
	> ! [branch1] branch1
	>  ! [branch2] branch2
	>   ! [branch3] branch3
	>    ! [branch4] branch4
	>     ! [branch5] branch5
	>      ! [branch6] branch6
	>       ! [branch7] branch7
	>        ! [branch8] branch8
	>         ! [branch9] branch9
	>          * [branch10] branch10
	> ----------
	>          * [branch10] branch10
	>         +  [branch9] branch9
	>        +   [branch8] branch8
	>       +    [branch7] branch7
	>      +     [branch6] branch6
	>     +      [branch5] branch5
	>    +       [branch4] branch4
	>   +        [branch3] branch3
	>  +         [branch2] branch2
	> +          [branch1] branch1
	> +++++++++* [branch10^] initial
	EOF
'

test_expect_success 'show-branch with more than 8 branches' '
	shit show-branch $(cat branches.sorted) >actual &&
	test_cmp expect actual
'

test_expect_success 'show-branch with showbranch.default' '
	for branch in $(cat branches.sorted)
	do
		test_config showbranch.default $branch --add || return 1
	done &&
	shit show-branch >actual &&
	test_cmp expect actual
'

test_expect_success 'show-branch --color output' '
	sed "s/^> //" >expect <<-\EOF &&
	> <RED>!<RESET> [branch1] branch1
	>  <GREEN>!<RESET> [branch2] branch2
	>   <YELLOW>!<RESET> [branch3] branch3
	>    <BLUE>!<RESET> [branch4] branch4
	>     <MAGENTA>!<RESET> [branch5] branch5
	>      <CYAN>!<RESET> [branch6] branch6
	>       <BOLD;RED>!<RESET> [branch7] branch7
	>        <BOLD;GREEN>!<RESET> [branch8] branch8
	>         <BOLD;YELLOW>!<RESET> [branch9] branch9
	>          <BOLD;BLUE>*<RESET> [branch10] branch10
	> ----------
	>          <BOLD;BLUE>*<RESET> [branch10] branch10
	>         <BOLD;YELLOW>+<RESET>  [branch9] branch9
	>        <BOLD;GREEN>+<RESET>   [branch8] branch8
	>       <BOLD;RED>+<RESET>    [branch7] branch7
	>      <CYAN>+<RESET>     [branch6] branch6
	>     <MAGENTA>+<RESET>      [branch5] branch5
	>    <BLUE>+<RESET>       [branch4] branch4
	>   <YELLOW>+<RESET>        [branch3] branch3
	>  <GREEN>+<RESET>         [branch2] branch2
	> <RED>+<RESET>          [branch1] branch1
	> <RED>+<RESET><GREEN>+<RESET><YELLOW>+<RESET><BLUE>+<RESET><MAGENTA>+<RESET><CYAN>+<RESET><BOLD;RED>+<RESET><BOLD;GREEN>+<RESET><BOLD;YELLOW>+<RESET><BOLD;BLUE>*<RESET> [branch10^] initial
	EOF
	shit show-branch --color=always $(cat branches.sorted) >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect actual
'

test_expect_success 'show branch --remotes' '
	cat >expect.err <<-\EOF &&
	No revs to be shown.
	EOF
	shit show-branch -r 2>actual.err >actual.out &&
	test_cmp expect.err actual.err &&
	test_must_be_empty actual.out
'

test_expect_success 'show-branch --sparse' '
	test_when_finished "shit checkout branch10 && shit branch -D branchA" &&
	shit checkout -b branchA branch10 &&
	shit merge -s ours -m "merge 1 and 10 to make A" branch1 &&
	shit commit --allow-empty -m "another" &&

	shit show-branch --sparse >out &&
	grep "merge 1 and 10 to make A" out &&

	shit show-branch >out &&
	! grep "merge 1 and 10 to make A" out &&

	shit show-branch --no-sparse >out &&
	! grep "merge 1 and 10 to make A" out
'

test_expect_success 'setup show branch --list' '
	sed "s/^> //" >expect <<-\EOF
	>   [branch1] branch1
	>   [branch2] branch2
	>   [branch3] branch3
	>   [branch4] branch4
	>   [branch5] branch5
	>   [branch6] branch6
	>   [branch7] branch7
	>   [branch8] branch8
	>   [branch9] branch9
	> * [branch10] branch10
	EOF
'

test_expect_success 'show branch --list' '
	shit show-branch --list $(cat branches.sorted) >actual &&
	test_cmp expect actual
'

test_expect_success 'show branch --list has no --color output' '
	shit show-branch --color=always --list $(cat branches.sorted) >actual &&
	test_cmp expect actual
'

test_expect_success 'show branch --merge-base with one argument' '
	for branch in $(cat branches.sorted)
	do
		shit rev-parse $branch >expect &&
		shit show-branch --merge-base $branch >actual &&
		test_cmp expect actual || return 1
	done
'

test_expect_success 'show branch --merge-base with two arguments' '
	for branch in $(cat branches.sorted)
	do
		shit rev-parse initial >expect &&
		shit show-branch --merge-base initial $branch >actual &&
		test_cmp expect actual || return 1
	done
'

test_expect_success 'show branch --merge-base with N arguments' '
	shit rev-parse initial >expect &&
	shit show-branch --merge-base $(cat branches.sorted) >actual &&
	test_cmp expect actual &&

	shit merge-base $(cat branches.sorted) >actual &&
	test_cmp expect actual
'

# incompatible options
while read combo
do
	test_expect_success "show-branch $combo (should fail)" '
		test_must_fail shit show-branch $combo 2>error &&
		grep -e "cannot be used together" -e "usage:" error
	'
done <<\EOF
--all --reflog
--merge-base --reflog
--list --merge-base
--reflog --current
EOF

# unnegatable options
for opt in topo-order date-order reflog
do
	test_expect_success "show-branch --no-$opt (should fail)" '
		test_must_fail shit show-branch --no-$opt 2>err &&
		grep "unknown option .no-$opt." err
	'
done

test_expect_success 'error descriptions on non-existent branch' '
	cat >expect <<-EOF &&
	error: no branch named '\''non-existent'\''
	EOF
	test_must_fail shit branch --edit-description non-existent 2>actual &&
	test_cmp expect actual
'

test_expect_success 'fatal descriptions on non-existent branch' '
	cat >expect <<-EOF &&
	fatal: branch '\''non-existent'\'' does not exist
	EOF
	test_must_fail shit branch --set-upstream-to=non-existent non-existent 2>actual &&
	test_cmp expect actual &&

	cat >expect <<-EOF &&
	fatal: no branch named '\''non-existent'\''
	EOF
	test_must_fail shit branch -c non-existent new-branch 2>actual &&
	test_cmp expect actual &&
	test_must_fail shit branch -m non-existent new-branch 2>actual &&
	test_cmp expect actual
'

test_expect_success 'error descriptions on orphan branch' '
	test_when_finished shit worktree remove -f wt &&
	shit worktree add wt --detach &&
	shit -C wt checkout --orphan orphan-branch &&
	test_branch_op_in_wt() {
		test_orphan_error() {
			test_must_fail shit $* 2>actual &&
			test_grep "no commit on branch .orphan-branch. yet$" actual
		} &&
		test_orphan_error -C wt branch $1 $2 &&                # implicit branch
		test_orphan_error -C wt branch $1 orphan-branch $2 &&  # explicit branch
		test_orphan_error branch $1 orphan-branch $2           # different worktree
	} &&
	test_branch_op_in_wt --edit-description &&
	test_branch_op_in_wt --set-upstream-to=ne &&
	test_branch_op_in_wt -c new-branch
'

test_expect_success 'setup reflogs' '
	test_commit base &&
	shit checkout -b branch &&
	test_commit one &&
	shit reset --hard HEAD^ &&
	test_commit two &&
	test_commit three
'

test_expect_success '--reflog shows reflog entries' '
	cat >expect <<-\EOF &&
	! [branch@{0}] (0 seconds ago) commit: three
	 ! [branch@{1}] (60 seconds ago) commit: two
	  ! [branch@{2}] (2 minutes ago) reset: moving to HEAD^
	   ! [branch@{3}] (2 minutes ago) commit: one
	----
	+    [branch@{0}] three
	++   [branch@{1}] two
	   + [branch@{3}] one
	++++ [branch@{2}] base
	EOF
	# the output always contains relative timestamps; use
	# a known time to get deterministic results
	shit_TEST_DATE_NOW=$test_tick \
	shit show-branch --reflog branch >actual &&
	test_cmp expect actual
'

test_expect_success '--reflog handles missing reflog' '
	shit reflog expire --expire=now branch &&
	shit show-branch --reflog branch >actual &&
	test_must_be_empty actual
'

test_done
