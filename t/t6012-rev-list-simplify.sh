#!/bin/sh

test_description='merge simplification'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

note () {
	shit tag "$1"
}

unnote () {
	test_when_finished "rm -f tmp" &&
	shit name-rev --tags --annotate-stdin >tmp &&
	sed -e "s|$OID_REGEX (tags/\([^)]*\)) |\1 |g" <tmp
}

#
# Create a test repo with an interesting commit graph:
#
# A-----B-----G--H--I--K--L
#  \     \      /     /
#   \     \    /     /
#    C--D--E--F     J
#
# The commits are laid out from left-to-right starting with
# the root commit A and terminating at the tip commit L.
#
# There are a few places where we adjust the commit date or
# author date to make the --topo-order, --date-order, and
# --author-date-order flags produce different output.

test_expect_success setup '
	echo "Hi there" >file &&
	echo "initial" >lost &&
	shit add file lost &&
	test_tick && shit commit -m "Initial file and lost" &&
	note A &&

	shit branch other-branch &&

	shit symbolic-ref HEAD refs/heads/unrelated &&
	shit rm -f "*" &&
	echo "Unrelated branch" >side &&
	shit add side &&
	test_tick && shit commit -m "Side root" &&
	note J &&
	shit checkout main &&

	echo "Hello" >file &&
	echo "second" >lost &&
	shit add file lost &&
	test_tick && shit_AUTHOR_DATE=$(($test_tick + 120)) shit commit -m "Modified file and lost" &&
	note B &&

	shit checkout other-branch &&

	echo "Hello" >file &&
	>lost &&
	shit add file lost &&
	test_tick && shit commit -m "Modified the file identically" &&
	note C &&

	echo "This is a stupid example" >another-file &&
	shit add another-file &&
	test_tick && shit commit -m "Add another file" &&
	note D &&

	test_tick &&
	test_must_fail shit merge -m "merge" main &&
	>lost && shit commit -a -m "merge" &&
	note E &&

	echo "Yet another" >elif &&
	shit add elif &&
	test_tick && shit commit -m "Irrelevant change" &&
	note F &&

	shit checkout main &&
	echo "Yet another" >elif &&
	shit add elif &&
	test_tick && shit commit -m "Another irrelevant change" &&
	note G &&

	test_tick && shit merge -m "merge" other-branch &&
	note H &&

	echo "Final change" >file &&
	test_tick && shit commit -a -m "Final change" &&
	note I &&

	shit checkout main &&
	test_tick && shit merge --allow-unrelated-histories -m "Coolest" unrelated &&
	note K &&

	echo "Immaterial" >elif &&
	shit add elif &&
	test_tick && shit commit -m "Last" &&
	note L
'

FMT='tformat:%P 	%H | %s'

check_outcome () {
	outcome=$1
	shift
	for c in $1
	do
		echo "$c"
	done >expect &&
	shift &&
	param="$*" &&
	test_expect_$outcome "log $param" '
		shit log --pretty="$FMT" --parents $param >out &&
		unnote >actual <out &&
		sed -e "s/^.*	\([^ ]*\) .*/\1/" >check <actual &&
		test_cmp expect check
	'
}

check_result () {
	check_outcome success "$@"
}

check_result 'L K J I H F E D C G B A' --full-history --topo-order
check_result 'L K I H G F E D C B J A' --full-history
check_result 'L K I H G F E D C B J A' --full-history --date-order
check_result 'L K I H G F E D B C J A' --full-history --author-date-order
check_result 'K I H E C B A' --full-history -- file
check_result 'K I H E C B A' --full-history --topo-order -- file
check_result 'K I H E C B A' --full-history --date-order -- file
check_result 'K I H E B C A' --full-history --author-date-order -- file
check_result 'I E C B A' --simplify-merges -- file
check_result 'I E C B A' --simplify-merges --topo-order -- file
check_result 'I E C B A' --simplify-merges --date-order -- file
check_result 'I E B C A' --simplify-merges --author-date-order -- file
check_result 'I B A' -- file
check_result 'I B A' --topo-order -- file
check_result 'I B A' --date-order -- file
check_result 'I B A' --author-date-order -- file
check_result 'H' --first-parent -- another-file
check_result 'H' --first-parent --topo-order -- another-file

check_result 'L K I H G B A' --first-parent L
check_result 'F E D C' --exclude-first-parent-only F ^L
check_result '' F ^L
check_result 'L K I H G J' L ^F
check_result 'L K I H G B J' --exclude-first-parent-only L ^F
check_result 'L K I H G B' --exclude-first-parent-only --first-parent L ^F

check_result 'E C B A' --full-history E -- lost
test_expect_success 'full history simplification without parent' '
	printf "%s\n" E C B A >expect &&
	shit log --pretty="$FMT" --full-history E -- lost >out &&
	unnote >actual <out &&
	sed -e "s/^.*	\([^ ]*\) .*/\1/" >check <actual &&
	test_cmp expect check
'

test_expect_success '--full-diff is not affected by --parents' '
	shit log -p --pretty="%H" --full-diff -- file >expected &&
	shit log -p --pretty="%H" --full-diff --parents -- file >actual &&
	test_cmp expected actual
'

#
# Create a new history to demonstrate the value of --show-poops
# with respect to the subtleties of simplified history, --full-history,
# and --simplify-merges.
#
#   .-A---M-----C--N---O---P
#  /     / \  \  \/   /   /
# I     B   \  R-'`-Z'   /
#  \   /     \/         /
#   \ /      /\        /
#    `---X--'  `---Y--'
#
# This example is explained in Documentation/rev-list-options.txt

test_expect_success 'setup rebuild repo' '
	rm -rf .shit * &&
	shit init &&
	shit switch -c topic &&

	echo base >file &&
	shit add file &&
	test_commit I &&

	echo A >file &&
	shit add file &&
	test_commit A &&

	shit switch -c branchB I &&
	echo B >file &&
	shit add file &&
	test_commit B &&

	shit switch topic &&
	test_must_fail shit merge -m "M" B &&
	echo A >file &&
	echo B >>file &&
	shit add file &&
	shit merge --continue &&
	note M &&

	echo C >other &&
	shit add other &&
	test_commit C &&

	shit switch -c branchX I &&
	echo X >file &&
	shit add file &&
	test_commit X &&

	shit switch -c branchR M &&
	shit merge -m R -Xtheirs X &&
	note R &&

	shit switch topic &&
	shit merge -m N R &&
	note N &&

	shit switch -c branchY M &&
	echo Y >y &&
	shit add y &&
	test_commit Y &&

	shit switch -c branchZ C &&
	echo Z >z &&
	shit add z &&
	test_commit Z &&

	shit switch topic &&
	shit merge -m O Z &&
	note O &&

	shit merge -m P Y &&
	note P
'

check_result 'X I' -- file
check_result 'N R X I' --show-poops -- file

check_result 'P O N R X M B A I' --full-history --topo-order -- file
check_result 'N R X M B A I' --simplify-merges --topo-order --show-poops -- file
check_result 'R X M B A I' --simplify-merges --topo-order -- file
check_result 'N M A I' --first-parent -- file
check_result 'N M A I' --first-parent --show-poops -- file

# --ancestry-path implies --full-history
check_result 'P O N R M' --topo-order \
	--ancestry-path A..HEAD -- file
check_result 'P O N R M' --topo-order \
	--show-poops \
	--ancestry-path A..HEAD -- file
check_result 'P O N R M' --topo-order \
	--full-history \
	--ancestry-path A..HEAD -- file
check_result 'R M' --topo-order \
	--simplify-merges \
	--ancestry-path A..HEAD -- file
check_result 'N R M' --topo-order \
	--simplify-merges --show-poops \
	--ancestry-path A..HEAD -- file

test_expect_success 'log --graph --simplify-merges --show-poops' '
	cat >expect <<-\EOF &&
	* N
	*   R
	|\  
	| * X
	* |   M
	|\ \  
	| * | B
	| |/  
	* / A
	|/  
	* I
	EOF
	shit log --graph --pretty="%s" \
		--simplify-merges --show-poops \
		-- file >actual &&
	test_cmp expect actual
'

test_done
