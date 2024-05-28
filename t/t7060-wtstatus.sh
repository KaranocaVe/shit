#!/bin/sh

test_description='basic work tree status reporting'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	shit config --global advice.statusuoption false &&
	test_commit A &&
	test_commit B oneside added &&
	shit checkout A^0 &&
	test_commit C oneside created
'

test_expect_success 'A/A conflict' '
	shit checkout B^0 &&
	test_must_fail shit merge C
'

test_expect_success 'Report path with conflict' '
	shit diff --cached --name-status >actual &&
	echo "U	oneside" >expect &&
	test_cmp expect actual
'

test_expect_success 'Report new path with conflict' '
	shit diff --cached --name-status HEAD^ >actual &&
	echo "U	oneside" >expect &&
	test_cmp expect actual
'

test_expect_success 'M/D conflict does not segfault' '
	cat >expect <<EOF &&
On branch side
You have unmerged paths.
  (fix conflicts and run "shit commit")
  (use "shit merge --abort" to abort the merge)

Unmerged paths:
  (use "shit add/rm <file>..." as appropriate to mark resolution)
	deleted by us:   foo

no changes added to commit (use "shit add" and/or "shit commit -a")
EOF
	mkdir mdconflict &&
	(
		cd mdconflict &&
		shit init &&
		test_commit initial foo "" &&
		test_commit modify foo foo &&
		shit checkout -b side HEAD^ &&
		shit rm foo &&
		shit commit -m delete &&
		test_must_fail shit merge main &&
		test_must_fail shit commit --dry-run >../actual &&
		test_cmp ../expect ../actual &&
		shit status >../actual &&
		test_cmp ../expect ../actual
	)
'

test_expect_success 'rename & unmerged setup' '
	shit rm -f -r . &&
	cat "$TEST_DIRECTORY/README" >ONE &&
	shit add ONE &&
	test_tick &&
	shit commit -m "One commit with ONE" &&

	echo Modified >TWO &&
	cat ONE >>TWO &&
	cat ONE >>THREE &&
	shit add TWO THREE &&
	sha1=$(shit rev-parse :ONE) &&
	shit rm --cached ONE &&
	(
		echo "100644 $sha1 1	ONE" &&
		echo "100644 $sha1 2	ONE" &&
		echo "100644 $sha1 3	ONE"
	) | shit update-index --index-info &&
	echo Further >>THREE
'

test_expect_success 'rename & unmerged status' '
	shit status -suno >actual &&
	cat >expect <<-EOF &&
	UU ONE
	AM THREE
	A  TWO
	EOF
	test_cmp expect actual
'

test_expect_success 'shit diff-index --cached shows 2 added + 1 unmerged' '
	cat >expected <<-EOF &&
	U	ONE
	A	THREE
	A	TWO
	EOF
	shit diff-index --cached --name-status HEAD >actual &&
	test_cmp expected actual
'

test_expect_success 'shit diff-index --cached -M shows 2 added + 1 unmerged' '
	cat >expected <<-EOF &&
	U	ONE
	A	THREE
	A	TWO
	EOF
	shit diff-index --cached -M --name-status HEAD >actual &&
	test_cmp expected actual
'

test_expect_success 'shit diff-index --cached -C shows 2 copies + 1 unmerged' '
	cat >expected <<-EOF &&
	U	ONE
	C	ONE	THREE
	C	ONE	TWO
	EOF
	shit diff-index --cached -C --name-status HEAD |
	sed "s/^C[0-9]*/C/g" >actual &&
	test_cmp expected actual
'


test_expect_success 'status when conflicts with add and rm advice (deleted by them)' '
	shit reset --hard &&
	shit checkout main &&
	test_commit init main.txt init &&
	shit checkout -b second_branch &&
	shit rm main.txt &&
	shit commit -m "main.txt deleted on second_branch" &&
	test_commit second conflict.txt second &&
	shit checkout main &&
	test_commit on_second main.txt on_second &&
	test_commit main conflict.txt main &&
	test_must_fail shit merge second_branch &&
	cat >expected <<\EOF &&
On branch main
You have unmerged paths.
  (fix conflicts and run "shit commit")
  (use "shit merge --abort" to abort the merge)

Unmerged paths:
  (use "shit add/rm <file>..." as appropriate to mark resolution)
	both added:      conflict.txt
	deleted by them: main.txt

no changes added to commit (use "shit add" and/or "shit commit -a")
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'prepare for conflicts' '
	shit reset --hard &&
	shit checkout -b conflict &&
	test_commit one main.txt one &&
	shit branch conflict_second &&
	shit mv main.txt sub_main.txt &&
	shit commit -m "main.txt renamed in sub_main.txt" &&
	shit checkout conflict_second &&
	shit mv main.txt sub_second.txt &&
	shit commit -m "main.txt renamed in sub_second.txt"
'


test_expect_success 'status when conflicts with add and rm advice (both deleted)' '
	test_must_fail shit merge conflict &&
	cat >expected <<\EOF &&
On branch conflict_second
You have unmerged paths.
  (fix conflicts and run "shit commit")
  (use "shit merge --abort" to abort the merge)

Unmerged paths:
  (use "shit add/rm <file>..." as appropriate to mark resolution)
	both deleted:    main.txt
	added by them:   sub_main.txt
	added by us:     sub_second.txt

no changes added to commit (use "shit add" and/or "shit commit -a")
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual
'


test_expect_success 'status when conflicts with only rm advice (both deleted)' '
	shit reset --hard conflict_second &&
	test_must_fail shit merge conflict &&
	shit add sub_main.txt &&
	shit add sub_second.txt &&
	cat >expected <<\EOF &&
On branch conflict_second
You have unmerged paths.
  (fix conflicts and run "shit commit")
  (use "shit merge --abort" to abort the merge)

Changes to be committed:
	new file:   sub_main.txt

Unmerged paths:
  (use "shit rm <file>..." to mark resolution)
	both deleted:    main.txt

Untracked files not listed (use -u option to show untracked files)
EOF
	shit status --untracked-files=no >actual &&
	test_cmp expected actual &&
	shit reset --hard &&
	shit checkout main
'

test_expect_success 'status --branch with detached HEAD' '
	shit reset --hard &&
	shit checkout main^0 &&
	shit status --branch --porcelain >actual &&
	cat >expected <<-EOF &&
	## HEAD (no branch)
	?? .shitconfig
	?? actual
	?? expect
	?? expected
	?? mdconflict/
	EOF
	test_cmp expected actual
'

## Duplicate the above test and verify --porcelain=v1 arg parsing.
test_expect_success 'status --porcelain=v1 --branch with detached HEAD' '
	shit reset --hard &&
	shit checkout main^0 &&
	shit status --branch --porcelain=v1 >actual &&
	cat >expected <<-EOF &&
	## HEAD (no branch)
	?? .shitconfig
	?? actual
	?? expect
	?? expected
	?? mdconflict/
	EOF
	test_cmp expected actual
'

## Verify parser error on invalid --porcelain argument.
test_expect_success 'status --porcelain=bogus' '
	test_must_fail shit status --porcelain=bogus
'

test_done
