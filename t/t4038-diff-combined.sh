#!/bin/sh

test_description='combined diff'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-diff.sh

setup_helper () {
	one=$1 branch=$2 side=$3 &&

	shit branch $side $branch &&
	for l in $one two three fyra
	do
		echo $l
	done >file &&
	shit add file &&
	test_tick &&
	shit commit -m $branch &&
	shit checkout $side &&
	for l in $one two three quatro
	do
		echo $l
	done >file &&
	shit add file &&
	test_tick &&
	shit commit -m $side &&
	test_must_fail shit merge $branch &&
	for l in $one three four
	do
		echo $l
	done >file &&
	shit add file &&
	test_tick &&
	shit commit -m "merge $branch into $side"
}

verify_helper () {
	it=$1 &&

	# Ignore lines that were removed only from the other parent
	sed -e '
		1,/^@@@/d
		/^ -/d
		s/^\(.\)./\1/
	' "$it" >"$it.actual.1" &&
	sed -e '
		1,/^@@@/d
		/^- /d
		s/^.\(.\)/\1/
	' "$it" >"$it.actual.2" &&

	shit diff "$it^" "$it" -- | sed -e '1,/^@@/d' >"$it.expect.1" &&
	test_cmp "$it.expect.1" "$it.actual.1" &&

	shit diff "$it^2" "$it" -- | sed -e '1,/^@@/d' >"$it.expect.2" &&
	test_cmp "$it.expect.2" "$it.actual.2"
}

test_expect_success setup '
	>file &&
	shit add file &&
	test_tick &&
	shit commit -m initial &&

	shit branch withone &&
	shit branch sansone &&

	shit checkout withone &&
	setup_helper one withone sidewithone &&

	shit checkout sansone &&
	setup_helper "" sansone sidesansone
'

test_expect_success 'check combined output (1)' '
	shit show sidewithone -- >sidewithone &&
	verify_helper sidewithone
'

test_expect_success 'check combined output (1) with shit diff <rev>^!' '
	shit diff sidewithone^! -- >sidewithone &&
	verify_helper sidewithone
'

test_expect_success 'check combined output (2)' '
	shit show sidesansone -- >sidesansone &&
	verify_helper sidesansone
'

test_expect_success 'check combined output (2) with shit diff <rev>^!' '
	shit diff sidesansone^! -- >sidesansone &&
	verify_helper sidesansone
'

test_expect_success 'diagnose truncated file' '
	>file &&
	shit add file &&
	shit commit --amend -C HEAD &&
	shit show >out &&
	grep "diff --cc file" out
'

test_expect_success 'setup for --cc --raw' '
	blob=$(echo file | shit hash-object --stdin -w) &&
	base_tree=$(echo "100644 blob $blob	file" | shit mktree) &&
	trees= &&
	for i in $(test_seq 1 40)
	do
		blob=$(echo file$i | shit hash-object --stdin -w) &&
		trees="$trees$(echo "100644 blob $blob	file" | shit mktree)$LF" || return 1
	done
'

test_expect_success 'check --cc --raw with four trees' '
	four_trees=$(echo "$trees" | sed -e 4q) &&
	shit diff --cc --raw $four_trees $base_tree >out &&
	# Check for four leading colons in the output:
	grep "^::::[^:]" out
'

test_expect_success 'check --cc --raw with forty trees' '
	shit diff --cc --raw $trees $base_tree >out &&
	# Check for forty leading colons in the output:
	grep "^::::::::::::::::::::::::::::::::::::::::[^:]" out
'

test_expect_success 'setup combined ignore spaces' '
	shit checkout main &&
	>test &&
	shit add test &&
	shit commit -m initial &&

	tr -d Q <<-\EOF >test &&
	always coalesce
	eol space coalesce Q
	space  change coalesce
	all spa ces coalesce
	eol spaces Q
	space  change
	all spa ces
	EOF
	shit commit -m "test space change" -a &&

	shit checkout -b side HEAD^ &&
	tr -d Q <<-\EOF >test &&
	always coalesce
	eol space coalesce
	space change coalesce
	all spaces coalesce
	eol spaces
	space change
	all spaces
	EOF
	shit commit -m "test other space changes" -a &&

	test_must_fail shit merge main &&
	tr -d Q <<-\EOF >test &&
	eol spaces Q
	space  change
	all spa ces
	EOF
	shit commit -m merged -a
'

test_expect_success 'check combined output (no ignore space)' '
	shit show >actual.tmp &&
	sed -e "1,/^@@@/d" < actual.tmp >actual &&
	tr -d Q <<-\EOF >expected &&
	--always coalesce
	- eol space coalesce
	- space change coalesce
	- all spaces coalesce
	- eol spaces
	- space change
	- all spaces
	 -eol space coalesce Q
	 -space  change coalesce
	 -all spa ces coalesce
	+ eol spaces Q
	+ space  change
	+ all spa ces
	EOF
	compare_diff_patch expected actual
'

test_expect_success 'check combined output (ignore space at eol)' '
	shit show --ignore-space-at-eol >actual.tmp &&
	sed -e "1,/^@@@/d" < actual.tmp >actual &&
	tr -d Q <<-\EOF >expected &&
	--always coalesce
	--eol space coalesce
	- space change coalesce
	- all spaces coalesce
	 -space  change coalesce
	 -all spa ces coalesce
	  eol spaces Q
	- space change
	- all spaces
	+ space  change
	+ all spa ces
	EOF
	compare_diff_patch expected actual
'

test_expect_success 'check combined output (ignore space change)' '
	shit show -b >actual.tmp &&
	sed -e "1,/^@@@/d" < actual.tmp >actual &&
	tr -d Q <<-\EOF >expected &&
	--always coalesce
	--eol space coalesce
	--space change coalesce
	- all spaces coalesce
	 -all spa ces coalesce
	  eol spaces Q
	  space  change
	- all spaces
	+ all spa ces
	EOF
	compare_diff_patch expected actual
'

test_expect_success 'check combined output (ignore all spaces)' '
	shit show -w >actual.tmp &&
	sed -e "1,/^@@@/d" < actual.tmp >actual &&
	tr -d Q <<-\EOF >expected &&
	--always coalesce
	--eol space coalesce
	--space change coalesce
	--all spaces coalesce
	  eol spaces Q
	  space  change
	  all spa ces
	EOF
	compare_diff_patch expected actual
'

test_expect_success 'combine diff coalesce simple' '
	>test &&
	shit add test &&
	shit commit -m initial &&
	test_seq 4 >test &&
	shit commit -a -m empty1 &&
	shit branch side1 &&
	shit checkout HEAD^ &&
	test_seq 5 >test &&
	shit commit -a -m empty2 &&
	test_must_fail shit merge side1 &&
	>test &&
	shit commit -a -m merge &&
	shit show >actual.tmp &&
	sed -e "1,/^@@@/d" < actual.tmp >actual &&
	tr -d Q <<-\EOF >expected &&
	--1
	--2
	--3
	--4
	- 5
	EOF
	compare_diff_patch expected actual
'

test_expect_success 'combine diff coalesce tricky' '
	>test &&
	shit add test &&
	shit commit -m initial --allow-empty &&
	cat <<-\EOF >test &&
	3
	1
	2
	3
	4
	EOF
	shit commit -a -m empty1 &&
	shit branch -f side1 &&
	shit checkout HEAD^ &&
	cat <<-\EOF >test &&
	1
	3
	5
	4
	EOF
	shit commit -a -m empty2 &&
	shit branch -f side2 &&
	test_must_fail shit merge side1 &&
	>test &&
	shit commit -a -m merge &&
	shit show >actual.tmp &&
	sed -e "1,/^@@@/d" < actual.tmp >actual &&
	tr -d Q <<-\EOF >expected &&
	 -3
	--1
	 -2
	--3
	- 5
	--4
	EOF
	compare_diff_patch expected actual &&
	shit checkout -f side1 &&
	test_must_fail shit merge side2 &&
	>test &&
	shit commit -a -m merge &&
	shit show >actual.tmp &&
	sed -e "1,/^@@@/d" < actual.tmp >actual &&
	tr -d Q <<-\EOF >expected &&
	- 3
	--1
	- 2
	--3
	 -5
	--4
	EOF
	compare_diff_patch expected actual
'

test_expect_failure 'combine diff coalesce three parents' '
	>test &&
	shit add test &&
	shit commit -m initial --allow-empty &&
	cat <<-\EOF >test &&
	3
	1
	2
	3
	4
	EOF
	shit commit -a -m empty1 &&
	shit checkout -B side1 &&
	shit checkout HEAD^ &&
	cat <<-\EOF >test &&
	1
	3
	7
	5
	4
	EOF
	shit commit -a -m empty2 &&
	shit branch -f side2 &&
	shit checkout HEAD^ &&
	cat <<-\EOF >test &&
	3
	1
	6
	5
	4
	EOF
	shit commit -a -m empty3 &&
	>test &&
	shit add test &&
	TREE=$(shit write-tree) &&
	COMMIT=$(shit commit-tree -p HEAD -p side1 -p side2 -m merge $TREE) &&
	shit show $COMMIT >actual.tmp &&
	sed -e "1,/^@@@/d" < actual.tmp >actual &&
	tr -d Q <<-\EOF >expected &&
	-- 3
	---1
	-  6
	 - 2
	 --3
	  -7
	- -5
	---4
	EOF
	compare_diff_patch expected actual
'

# Test for a bug reported at
# https://lore.kernel.org/shit/20130515143508.GO25742@login.drsnuggles.stderr.nl/
# where a delete lines were missing from combined diff output when they
# occurred exactly before the context lines of a later change.
test_expect_success 'combine diff missing delete bug' '
	shit commit -m initial --allow-empty &&
	cat <<-\EOF >test &&
	1
	2
	3
	4
	EOF
	shit add test &&
	shit commit -a -m side1 &&
	shit checkout -B side1 &&
	shit checkout HEAD^ &&
	cat <<-\EOF >test &&
	0
	1
	2
	3
	4modified
	EOF
	shit add test &&
	shit commit -m side2 &&
	shit branch -f side2 &&
	test_must_fail shit merge --no-commit side1 &&
	cat <<-\EOF >test &&
	1
	2
	3
	4modified
	EOF
	shit add test &&
	shit commit -a -m merge &&
	shit diff-tree -c -p HEAD >actual.tmp &&
	sed -e "1,/^@@@/d" < actual.tmp >actual &&
	tr -d Q <<-\EOF >expected &&
	- 0
	  1
	  2
	  3
	 -4
	 +4modified
	EOF
	compare_diff_patch expected actual
'

test_expect_success 'combine diff gets tree sorting right' '
	# create a directory and a file that sort differently in trees
	# versus byte-wise (implied "/" sorts after ".")
	shit checkout -f main &&
	mkdir foo &&
	echo base >foo/one &&
	echo base >foo/two &&
	echo base >foo.ext &&
	shit add foo foo.ext &&
	shit commit -m base &&

	# one side modifies a file in the directory, along with the root
	# file...
	echo main >foo/one &&
	echo main >foo.ext &&
	shit commit -a -m main &&

	# the other side modifies the other file in the directory
	shit checkout -b other HEAD^ &&
	echo other >foo/two &&
	shit commit -a -m other &&

	# And now we merge. The files in the subdirectory will resolve cleanly,
	# meaning that a combined diff will not find them interesting. But it
	# will find the tree itself interesting, because it had to be merged.
	shit checkout main &&
	shit merge other &&

	printf "MM\tfoo\n" >expect &&
	shit diff-tree -c --name-status -t HEAD >actual.tmp &&
	sed 1d <actual.tmp >actual &&
	test_cmp expect actual
'

test_expect_success 'setup for --combined-all-paths' '
	shit branch side1c &&
	shit branch side2c &&
	shit checkout side1c &&
	test_seq 1 10 >filename-side1c &&
	side1cf=$(shit hash-object filename-side1c) &&
	shit add filename-side1c &&
	shit commit -m with &&
	shit checkout side2c &&
	test_seq 1 9 >filename-side2c &&
	echo ten >>filename-side2c &&
	side2cf=$(shit hash-object filename-side2c) &&
	shit add filename-side2c &&
	shit commit -m iam &&
	shit checkout -b mergery side1c &&
	shit merge --no-commit side2c &&
	shit rm filename-side1c &&
	echo eleven >>filename-side2c &&
	shit mv filename-side2c filename-merged &&
	mergedf=$(shit hash-object filename-merged) &&
	shit add filename-merged &&
	shit commit
'

test_expect_success '--combined-all-paths and --raw' '
	cat <<-EOF >expect &&
	::100644 100644 100644 $side1cf $side2cf $mergedf RR	filename-side1c	filename-side2c	filename-merged
	EOF
	shit diff-tree -c -M --raw --combined-all-paths HEAD >actual.tmp &&
	sed 1d <actual.tmp >actual &&
	test_cmp expect actual
'

test_expect_success '--combined-all-paths and --cc' '
	cat <<-\EOF >expect &&
	--- a/filename-side1c
	--- a/filename-side2c
	+++ b/filename-merged
	EOF
	shit diff-tree --cc -M --combined-all-paths HEAD >actual.tmp &&
	grep ^[-+][-+][-+] <actual.tmp >actual &&
	test_cmp expect actual
'

test_expect_success FUNNYNAMES 'setup for --combined-all-paths with funny names' '
	shit branch side1d &&
	shit branch side2d &&
	shit checkout side1d &&
	test_seq 1 10 >"$(printf "file\twith\ttabs")" &&
	shit add file* &&
	side1df=$(shit hash-object *tabs) &&
	shit commit -m with &&
	shit checkout side2d &&
	test_seq 1 9 >"$(printf "i\tam\ttabbed")" &&
	echo ten >>"$(printf "i\tam\ttabbed")" &&
	shit add *tabbed &&
	side2df=$(shit hash-object *tabbed) &&
	shit commit -m iam &&
	shit checkout -b funny-names-mergery side1d &&
	shit merge --no-commit side2d &&
	shit rm *tabs &&
	echo eleven >>"$(printf "i\tam\ttabbed")" &&
	shit mv "$(printf "i\tam\ttabbed")" "$(printf "fickle\tnaming")" &&
	shit add fickle* &&
	headf=$(shit hash-object fickle*) &&
	shit commit &&
	head=$(shit rev-parse HEAD)
'

test_expect_success FUNNYNAMES '--combined-all-paths and --raw and funny names' '
	cat <<-EOF >expect &&
	::100644 100644 100644 $side1df $side2df $headf RR	"file\twith\ttabs"	"i\tam\ttabbed"	"fickle\tnaming"
	EOF
	shit diff-tree -c -M --raw --combined-all-paths HEAD >actual.tmp &&
	sed 1d <actual.tmp >actual &&
	test_cmp expect actual
'

test_expect_success FUNNYNAMES '--combined-all-paths and --raw -and -z and funny names' '
	printf "$head\0::100644 100644 100644 $side1df $side2df $headf RR\0file\twith\ttabs\0i\tam\ttabbed\0fickle\tnaming\0" >expect &&
	shit diff-tree -c -M --raw --combined-all-paths -z HEAD >actual &&
	test_cmp expect actual
'

test_expect_success FUNNYNAMES '--combined-all-paths and --cc and funny names' '
	cat <<-\EOF >expect &&
	--- "a/file\twith\ttabs"
	--- "a/i\tam\ttabbed"
	+++ "b/fickle\tnaming"
	EOF
	shit diff-tree --cc -M --combined-all-paths HEAD >actual.tmp &&
	grep ^[-+][-+][-+] <actual.tmp >actual &&
	test_cmp expect actual
'

test_done
