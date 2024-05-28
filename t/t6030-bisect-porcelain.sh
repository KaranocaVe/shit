#!/bin/sh
#
# Copyright (c) 2007 Christian Couder
#
test_description='Tests shit bisect functionality'

exec </dev/null

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

add_line_into_file()
{
    _line=$1
    _file=$2

    if [ -f "$_file" ]; then
        echo "$_line" >> $_file || return $?
        MSG="Add <$_line> into <$_file>."
    else
        echo "$_line" > $_file || return $?
        shit add $_file || return $?
        MSG="Create file <$_file> with <$_line> inside."
    fi

    test_tick
    shit commit --quiet -m "$MSG" $_file
}

HASH1=
HASH2=
HASH3=
HASH4=

test_bisect_usage () {
	local code="$1" &&
	shift &&
	cat >expect &&
	test_expect_code $code "$@" >out 2>actual &&
	test_must_be_empty out &&
	test_cmp expect actual
}

test_expect_success 'bisect usage' "
	test_bisect_usage 1 shit bisect reset extra1 extra2 <<-\EOF &&
	error: 'shit bisect reset' requires either no argument or a commit
	EOF
	test_bisect_usage 1 shit bisect terms extra1 extra2 <<-\EOF &&
	error: 'shit bisect terms' requires 0 or 1 argument
	EOF
	test_bisect_usage 1 shit bisect next extra1 <<-\EOF &&
	error: 'shit bisect next' requires 0 arguments
	EOF
	test_bisect_usage 1 shit bisect log extra1 <<-\EOF &&
	error: We are not bisecting.
	EOF
	test_bisect_usage 1 shit bisect replay <<-\EOF &&
	error: no logfile given
	EOF
	test_bisect_usage 1 shit bisect run <<-\EOF
	error: 'shit bisect run' failed: no command provided.
	EOF
"

test_expect_success 'set up basic repo with 1 file (hello) and 4 commits' '
     add_line_into_file "1: Hello World" hello &&
     HASH1=$(shit rev-parse --verify HEAD) &&
     add_line_into_file "2: A new day for shit" hello &&
     HASH2=$(shit rev-parse --verify HEAD) &&
     add_line_into_file "3: Another new day for shit" hello &&
     HASH3=$(shit rev-parse --verify HEAD) &&
     add_line_into_file "4: Ciao for now" hello &&
     HASH4=$(shit rev-parse --verify HEAD)
'

test_expect_success 'bisect starts with only one bad' '
	shit bisect reset &&
	shit bisect start &&
	shit bisect bad $HASH4 &&
	shit bisect next
'

test_expect_success 'bisect does not start with only one good' '
	shit bisect reset &&
	shit bisect start &&
	shit bisect good $HASH1 &&
	test_must_fail shit bisect next
'

test_expect_success 'bisect start with one bad and good' '
	shit bisect reset &&
	shit bisect start &&
	shit bisect good $HASH1 &&
	shit bisect bad $HASH4 &&
	shit bisect next
'

test_expect_success 'bisect fails if given any junk instead of revs' '
	shit bisect reset &&
	test_must_fail shit bisect start foo $HASH1 -- &&
	test_must_fail shit bisect start $HASH4 $HASH1 bar -- &&
	test -z "$(shit for-each-ref "refs/bisect/*")" &&
	test -z "$(ls .shit/BISECT_* 2>/dev/null)" &&
	shit bisect start &&
	test_must_fail shit bisect good foo $HASH1 &&
	test_must_fail shit bisect good $HASH1 bar &&
	test_must_fail shit bisect bad frotz &&
	test_must_fail shit bisect bad $HASH3 $HASH4 &&
	test_must_fail shit bisect skip bar $HASH3 &&
	test_must_fail shit bisect skip $HASH1 foo &&
	test -z "$(shit for-each-ref "refs/bisect/*")" &&
	shit bisect good $HASH1 &&
	shit bisect bad $HASH4
'

test_expect_success 'bisect start without -- takes unknown arg as pathspec' '
	shit bisect reset &&
	shit bisect start foo bar &&
	grep foo ".shit/BISECT_NAMES" &&
	grep bar ".shit/BISECT_NAMES"
'

test_expect_success 'bisect reset: back in a branch checked out also elsewhere' '
	echo "shared" > branch.expect &&
	test_bisect_reset() {
		shit -C $1 bisect start &&
		shit -C $1 bisect good $HASH1 &&
		shit -C $1 bisect bad $HASH3 &&
		shit -C $1 bisect reset &&
		shit -C $1 branch --show-current > branch.output &&
		cmp branch.expect branch.output
	} &&
	test_when_finished "
		shit worktree remove wt1 &&
		shit worktree remove wt2 &&
		shit branch -d shared
	" &&
	shit worktree add wt1 -b shared &&
	shit worktree add wt2 -f shared &&
	# we test in both worktrees to ensure that works
	# as expected with "first" and "next" worktrees
	test_bisect_reset wt1 &&
	test_bisect_reset wt2
'

test_expect_success 'bisect reset: back in the main branch' '
	shit bisect reset &&
	echo "* main" > branch.expect &&
	shit branch > branch.output &&
	cmp branch.expect branch.output
'

test_expect_success 'bisect reset: back in another branch' '
	shit checkout -b other &&
	shit bisect start &&
	shit bisect good $HASH1 &&
	shit bisect bad $HASH3 &&
	shit bisect reset &&
	echo "  main" > branch.expect &&
	echo "* other" >> branch.expect &&
	shit branch > branch.output &&
	cmp branch.expect branch.output
'

test_expect_success 'bisect reset when not bisecting' '
	shit bisect reset &&
	shit branch > branch.output &&
	cmp branch.expect branch.output
'

test_expect_success 'bisect reset cleans up even when not bisecting' '
	echo garbage >.shit/BISECT_LOG &&
	shit bisect reset &&
	test_path_is_missing .shit/BISECT_LOG
'

test_expect_success 'bisect reset removes packed refs' '
	shit bisect reset &&
	shit bisect start &&
	shit bisect good $HASH1 &&
	shit bisect bad $HASH3 &&
	shit pack-refs --all --prune &&
	shit bisect next &&
	shit bisect reset &&
	test -z "$(shit for-each-ref "refs/bisect/*")" &&
	test -z "$(shit for-each-ref "refs/heads/bisect")"
'

test_expect_success 'bisect reset removes bisect state after --no-checkout' '
	shit bisect reset &&
	shit bisect start --no-checkout &&
	shit bisect good $HASH1 &&
	shit bisect bad $HASH3 &&
	shit bisect next &&
	shit bisect reset &&
	test -z "$(shit for-each-ref "refs/bisect/*")" &&
	test -z "$(shit for-each-ref "refs/heads/bisect")" &&
	test -z "$(shit for-each-ref "BISECT_HEAD")"
'

test_expect_success 'bisect start: back in good branch' '
	shit branch > branch.output &&
	grep "* other" branch.output > /dev/null &&
	shit bisect start $HASH4 $HASH1 -- &&
	shit bisect good &&
	shit bisect start $HASH4 $HASH1 -- &&
	shit bisect bad &&
	shit bisect reset &&
	shit branch > branch.output &&
	grep "* other" branch.output > /dev/null
'

test_expect_success 'bisect start: no ".shit/BISECT_START" created if junk rev' '
	shit bisect reset &&
	test_must_fail shit bisect start $HASH4 foo -- &&
	shit branch > branch.output &&
	grep "* other" branch.output > /dev/null &&
	test_path_is_missing .shit/BISECT_START
'

test_expect_success 'bisect start: existing ".shit/BISECT_START" not modified if junk rev' '
	shit bisect start $HASH4 $HASH1 -- &&
	shit bisect good &&
	cp .shit/BISECT_START saved &&
	test_must_fail shit bisect start $HASH4 foo -- &&
	shit branch > branch.output &&
	test_grep "* (no branch, bisect started on other)" branch.output > /dev/null &&
	test_cmp saved .shit/BISECT_START
'
test_expect_success 'bisect start: no ".shit/BISECT_START" if mistaken rev' '
	shit bisect start $HASH4 $HASH1 -- &&
	shit bisect good &&
	test_must_fail shit bisect start $HASH1 $HASH4 -- &&
	shit branch > branch.output &&
	grep "* other" branch.output > /dev/null &&
	test_path_is_missing .shit/BISECT_START
'

test_expect_success 'bisect start: no ".shit/BISECT_START" if checkout error' '
	echo "temp stuff" > hello &&
	test_must_fail shit bisect start $HASH4 $HASH1 -- &&
	shit branch &&
	shit branch > branch.output &&
	grep "* other" branch.output > /dev/null &&
	test_path_is_missing .shit/BISECT_START &&
	test -z "$(shit for-each-ref "refs/bisect/*")" &&
	shit checkout HEAD hello
'

# $HASH1 is good, $HASH4 is bad, we skip $HASH3
# but $HASH2 is bad,
# so we should find $HASH2 as the first bad commit
test_expect_success 'bisect skip: successful result' '
	test_when_finished shit bisect reset &&
	shit bisect reset &&
	shit bisect start $HASH4 $HASH1 &&
	shit bisect skip &&
	shit bisect bad > my_bisect_log.txt &&
	grep "$HASH2 is the first bad commit" my_bisect_log.txt
'

# $HASH1 is good, $HASH4 is bad, we skip $HASH3 and $HASH2
# so we should not be able to tell the first bad commit
# among $HASH2, $HASH3 and $HASH4
test_expect_success 'bisect skip: cannot tell between 3 commits' '
	test_when_finished shit bisect reset &&
	shit bisect start $HASH4 $HASH1 &&
	shit bisect skip &&
	test_expect_code 2 shit bisect skip >my_bisect_log.txt &&
	grep "first bad commit could be any of" my_bisect_log.txt &&
	! grep $HASH1 my_bisect_log.txt &&
	grep $HASH2 my_bisect_log.txt &&
	grep $HASH3 my_bisect_log.txt &&
	grep $HASH4 my_bisect_log.txt
'

# $HASH1 is good, $HASH4 is bad, we skip $HASH3
# but $HASH2 is good,
# so we should not be able to tell the first bad commit
# among $HASH3 and $HASH4
test_expect_success 'bisect skip: cannot tell between 2 commits' '
	test_when_finished shit bisect reset &&
	shit bisect start $HASH4 $HASH1 &&
	shit bisect skip &&
	test_expect_code 2 shit bisect good >my_bisect_log.txt &&
	grep "first bad commit could be any of" my_bisect_log.txt &&
	! grep $HASH1 my_bisect_log.txt &&
	! grep $HASH2 my_bisect_log.txt &&
	grep $HASH3 my_bisect_log.txt &&
	grep $HASH4 my_bisect_log.txt
'

# $HASH1 is good, $HASH4 is both skipped and bad, we skip $HASH3
# and $HASH2 is good,
# so we should not be able to tell the first bad commit
# among $HASH3 and $HASH4
test_expect_success 'bisect skip: with commit both bad and skipped' '
	test_when_finished shit bisect reset &&
	shit bisect start &&
	shit bisect skip &&
	shit bisect bad &&
	shit bisect good $HASH1 &&
	shit bisect skip &&
	test_expect_code 2 shit bisect good >my_bisect_log.txt &&
	grep "first bad commit could be any of" my_bisect_log.txt &&
	! grep $HASH1 my_bisect_log.txt &&
	! grep $HASH2 my_bisect_log.txt &&
	grep $HASH3 my_bisect_log.txt &&
	grep $HASH4 my_bisect_log.txt
'

test_bisect_run_args () {
	test_when_finished "rm -f run.sh actual" &&
	>actual &&
	cat >expect.args &&
	cat <&6 >expect.out &&
	cat <&7 >expect.err &&
	write_script run.sh <<-\EOF &&
	while test $# != 0
	do
		echo "<$1>" &&
		shift
	done >actual.args
	EOF

	test_when_finished "shit bisect reset" &&
	shit bisect start &&
	shit bisect good $HASH1 &&
	shit bisect bad $HASH4 &&
	shit bisect run ./run.sh $@ >actual.out.raw 2>actual.err &&
	# Prune just the log output
	sed -n \
		-e '/^Author:/d' \
		-e '/^Date:/d' \
		-e '/^$/d' \
		-e '/^commit /d' \
		-e '/^ /d' \
		-e 'p' \
		<actual.out.raw >actual.out &&
	test_cmp expect.out actual.out &&
	test_cmp expect.err actual.err &&
	test_cmp expect.args actual.args
}

test_expect_success 'shit bisect run: args, stdout and stderr with no arguments' "
	test_bisect_run_args <<-'EOF_ARGS' 6<<-EOF_OUT 7<<-'EOF_ERR'
	EOF_ARGS
	running './run.sh'
	$HASH4 is the first bad commit
	bisect found first bad commit
	EOF_OUT
	EOF_ERR
"

test_expect_success 'shit bisect run: args, stdout and stderr: "--" argument' "
	test_bisect_run_args -- <<-'EOF_ARGS' 6<<-EOF_OUT 7<<-'EOF_ERR'
	<-->
	EOF_ARGS
	running './run.sh' '--'
	$HASH4 is the first bad commit
	bisect found first bad commit
	EOF_OUT
	EOF_ERR
"

test_expect_success 'shit bisect run: args, stdout and stderr: "--log foo --no-log bar" arguments' "
	test_bisect_run_args --log foo --no-log bar <<-'EOF_ARGS' 6<<-EOF_OUT 7<<-'EOF_ERR'
	<--log>
	<foo>
	<--no-log>
	<bar>
	EOF_ARGS
	running './run.sh' '--log' 'foo' '--no-log' 'bar'
	$HASH4 is the first bad commit
	bisect found first bad commit
	EOF_OUT
	EOF_ERR
"

test_expect_success 'shit bisect run: args, stdout and stderr: "--bisect-start" argument' "
	test_bisect_run_args --bisect-start <<-'EOF_ARGS' 6<<-EOF_OUT 7<<-'EOF_ERR'
	<--bisect-start>
	EOF_ARGS
	running './run.sh' '--bisect-start'
	$HASH4 is the first bad commit
	bisect found first bad commit
	EOF_OUT
	EOF_ERR
"

test_expect_success 'shit bisect run: negative exit code' "
	write_script fail.sh <<-'EOF' &&
	exit 255
	EOF
	cat <<-'EOF' >expect &&
	bisect run failed: exit code -1 from './fail.sh' is < 0 or >= 128
	EOF
	test_when_finished 'shit bisect reset' &&
	shit bisect start &&
	shit bisect good $HASH1 &&
	shit bisect bad $HASH4 &&
	! shit bisect run ./fail.sh 2>err &&
	sed -En 's/.*(bisect.*code) (-?[0-9]+) (from.*)/\1 -1 \3/p' err >actual &&
	test_cmp expect actual
"

test_expect_success 'shit bisect run: unable to verify on good' "
	write_script fail.sh <<-'EOF' &&
	head=\$(shit rev-parse --verify HEAD)
	good=\$(shit rev-parse --verify $HASH1)
	if test "\$head" = "\$good"
	then
		exit 255
	else
		exit 127
	fi
	EOF
	cat <<-'EOF' >expect &&
	unable to verify './fail.sh' on good revision
	EOF
	test_when_finished 'shit bisect reset' &&
	shit bisect start &&
	shit bisect good $HASH1 &&
	shit bisect bad $HASH4 &&
	! shit bisect run ./fail.sh 2>err &&
	sed -n 's/.*\(unable to verify.*\)/\1/p' err >actual &&
	test_cmp expect actual
"

# We want to automatically find the commit that
# added "Another" into hello.
test_expect_success '"shit bisect run" simple case' '
	write_script test_script.sh <<-\EOF &&
	! grep Another hello >/dev/null
	EOF
	shit bisect start &&
	shit bisect good $HASH1 &&
	shit bisect bad $HASH4 &&
	shit bisect run ./test_script.sh >my_bisect_log.txt &&
	grep "$HASH3 is the first bad commit" my_bisect_log.txt &&
	shit bisect reset
'

# We want to make sure no arguments has been eaten
test_expect_success '"shit bisect run" simple case' '
	shit bisect start &&
	shit bisect good $HASH1 &&
	shit bisect bad $HASH4 &&
	shit bisect run printf "%s %s\n" reset --bisect-skip >my_bisect_log.txt &&
	grep -e "reset --bisect-skip" my_bisect_log.txt &&
	shit bisect reset
'

# We want to automatically find the commit that
# added "Ciao" into hello.
test_expect_success '"shit bisect run" with more complex "shit bisect start"' '
	write_script test_script.sh <<-\EOF &&
	! grep Ciao hello >/dev/null
	EOF
	shit bisect start $HASH4 $HASH1 &&
	shit bisect run ./test_script.sh >my_bisect_log.txt &&
	grep "$HASH4 is the first bad commit" my_bisect_log.txt &&
	shit bisect reset
'

test_expect_success 'bisect run accepts exit code 126 as bad' '
	test_when_finished "shit bisect reset" &&
	write_script test_script.sh <<-\EOF &&
	! grep Another hello || exit 126 >/dev/null
	EOF
	shit bisect start &&
	shit bisect good $HASH1 &&
	shit bisect bad $HASH4 &&
	shit bisect run ./test_script.sh >my_bisect_log.txt &&
	grep "$HASH3 is the first bad commit" my_bisect_log.txt
'

test_expect_success POSIXPERM 'bisect run fails with non-executable test script' '
	test_when_finished "shit bisect reset" &&
	>not-executable.sh &&
	chmod -x not-executable.sh &&
	shit bisect start &&
	shit bisect good $HASH1 &&
	shit bisect bad $HASH4 &&
	test_must_fail shit bisect run ./not-executable.sh >my_bisect_log.txt &&
	! grep "is the first bad commit" my_bisect_log.txt
'

test_expect_success 'bisect run accepts exit code 127 as bad' '
	test_when_finished "shit bisect reset" &&
	write_script test_script.sh <<-\EOF &&
	! grep Another hello || exit 127 >/dev/null
	EOF
	shit bisect start &&
	shit bisect good $HASH1 &&
	shit bisect bad $HASH4 &&
	shit bisect run ./test_script.sh >my_bisect_log.txt &&
	grep "$HASH3 is the first bad commit" my_bisect_log.txt
'

test_expect_success 'bisect run fails with missing test script' '
	test_when_finished "shit bisect reset" &&
	rm -f does-not-exist.sh &&
	shit bisect start &&
	shit bisect good $HASH1 &&
	shit bisect bad $HASH4 &&
	test_must_fail shit bisect run ./does-not-exist.sh >my_bisect_log.txt &&
	! grep "is the first bad commit" my_bisect_log.txt
'

# $HASH1 is good, $HASH5 is bad, we skip $HASH3
# but $HASH4 is good,
# so we should find $HASH5 as the first bad commit
HASH5=
test_expect_success 'bisect skip: add line and then a new test' '
	add_line_into_file "5: Another new line." hello &&
	HASH5=$(shit rev-parse --verify HEAD) &&
	shit bisect start $HASH5 $HASH1 &&
	shit bisect skip &&
	shit bisect good > my_bisect_log.txt &&
	grep "$HASH5 is the first bad commit" my_bisect_log.txt &&
	shit bisect log > log_to_replay.txt &&
	shit bisect reset
'

test_expect_success 'bisect skip and bisect replay' '
	shit bisect replay log_to_replay.txt > my_bisect_log.txt &&
	grep "$HASH5 is the first bad commit" my_bisect_log.txt &&
	shit bisect reset
'

HASH6=
test_expect_success 'bisect run & skip: cannot tell between 2' '
	add_line_into_file "6: Yet a line." hello &&
	HASH6=$(shit rev-parse --verify HEAD) &&
	write_script test_script.sh <<-\EOF &&
	sed -ne \$p hello | grep Ciao >/dev/null && exit 125
	! grep line hello >/dev/null
	EOF
	shit bisect start $HASH6 $HASH1 &&
	test_expect_code 2 shit bisect run ./test_script.sh >my_bisect_log.txt &&
	grep "first bad commit could be any of" my_bisect_log.txt &&
	! grep $HASH3 my_bisect_log.txt &&
	! grep $HASH6 my_bisect_log.txt &&
	grep $HASH4 my_bisect_log.txt &&
	grep $HASH5 my_bisect_log.txt
'

HASH7=
test_expect_success 'bisect run & skip: find first bad' '
	shit bisect reset &&
	add_line_into_file "7: Should be the last line." hello &&
	HASH7=$(shit rev-parse --verify HEAD) &&
	write_script test_script.sh <<-\EOF &&
	sed -ne \$p hello | grep Ciao >/dev/null && exit 125
	sed -ne \$p hello | grep day >/dev/null && exit 125
	! grep Yet hello >/dev/null
	EOF
	shit bisect start $HASH7 $HASH1 &&
	shit bisect run ./test_script.sh >my_bisect_log.txt &&
	grep "$HASH6 is the first bad commit" my_bisect_log.txt
'

test_expect_success 'bisect skip only one range' '
	shit bisect reset &&
	shit bisect start $HASH7 $HASH1 &&
	shit bisect skip $HASH1..$HASH5 &&
	test "$HASH6" = "$(shit rev-parse --verify HEAD)" &&
	test_must_fail shit bisect bad > my_bisect_log.txt &&
	grep "first bad commit could be any of" my_bisect_log.txt
'

test_expect_success 'bisect skip many ranges' '
	shit bisect start $HASH7 $HASH1 &&
	test "$HASH4" = "$(shit rev-parse --verify HEAD)" &&
	shit bisect skip $HASH2 $HASH2.. ..$HASH5 &&
	test "$HASH6" = "$(shit rev-parse --verify HEAD)" &&
	test_must_fail shit bisect bad > my_bisect_log.txt &&
	grep "first bad commit could be any of" my_bisect_log.txt
'

test_expect_success 'bisect starting with a detached HEAD' '
	shit bisect reset &&
	shit checkout main^ &&
	HEAD=$(shit rev-parse --verify HEAD) &&
	shit bisect start &&
	test $HEAD = $(cat .shit/BISECT_START) &&
	shit bisect reset &&
	test $HEAD = $(shit rev-parse --verify HEAD)
'

test_expect_success 'bisect errors out if bad and good are mistaken' '
	shit bisect reset &&
	test_must_fail shit bisect start $HASH2 $HASH4 2> rev_list_error &&
	test_grep "mistook good and bad" rev_list_error &&
	shit bisect reset
'

test_expect_success 'bisect does not create a "bisect" branch' '
	shit bisect reset &&
	shit bisect start $HASH7 $HASH1 &&
	shit branch bisect &&
	rev_hash4=$(shit rev-parse --verify HEAD) &&
	test "$rev_hash4" = "$HASH4" &&
	shit branch -D bisect &&
	shit bisect good &&
	shit branch bisect &&
	rev_hash6=$(shit rev-parse --verify HEAD) &&
	test "$rev_hash6" = "$HASH6" &&
	shit bisect good > my_bisect_log.txt &&
	grep "$HASH7 is the first bad commit" my_bisect_log.txt &&
	shit bisect reset &&
	rev_hash6=$(shit rev-parse --verify bisect) &&
	test "$rev_hash6" = "$HASH6" &&
	shit branch -D bisect
'

# This creates a "side" branch to test "siblings" cases.
#
# H1-H2-H3-H4-H5-H6-H7  <--other
#            \
#             S5-S6-S7  <--side
#
test_expect_success 'side branch creation' '
	shit bisect reset &&
	shit checkout -b side $HASH4 &&
	add_line_into_file "5(side): first line on a side branch" hello2 &&
	SIDE_HASH5=$(shit rev-parse --verify HEAD) &&
	add_line_into_file "6(side): second line on a side branch" hello2 &&
	SIDE_HASH6=$(shit rev-parse --verify HEAD) &&
	add_line_into_file "7(side): third line on a side branch" hello2 &&
	SIDE_HASH7=$(shit rev-parse --verify HEAD)
'

test_expect_success 'good merge base when good and bad are siblings' '
	shit bisect start "$HASH7" "$SIDE_HASH7" > my_bisect_log.txt &&
	test_grep "merge base must be tested" my_bisect_log.txt &&
	grep $HASH4 my_bisect_log.txt &&
	shit bisect good > my_bisect_log.txt &&
	! grep "merge base must be tested" my_bisect_log.txt &&
	grep $HASH6 my_bisect_log.txt &&
	shit bisect reset
'
test_expect_success 'skipped merge base when good and bad are siblings' '
	shit bisect start "$SIDE_HASH7" "$HASH7" > my_bisect_log.txt &&
	test_grep "merge base must be tested" my_bisect_log.txt &&
	grep $HASH4 my_bisect_log.txt &&
	shit bisect skip > my_bisect_log.txt 2>&1 &&
	grep "warning" my_bisect_log.txt &&
	grep $SIDE_HASH6 my_bisect_log.txt &&
	shit bisect reset
'

test_expect_success 'bad merge base when good and bad are siblings' '
	shit bisect start "$HASH7" HEAD > my_bisect_log.txt &&
	test_grep "merge base must be tested" my_bisect_log.txt &&
	grep $HASH4 my_bisect_log.txt &&
	test_must_fail shit bisect bad > my_bisect_log.txt 2>&1 &&
	test_grep "merge base $HASH4 is bad" my_bisect_log.txt &&
	test_grep "fixed between $HASH4 and \[$SIDE_HASH7\]" my_bisect_log.txt &&
	shit bisect reset
'

# This creates a few more commits (A and B) to test "siblings" cases
# when a good and a bad rev have many merge bases.
#
# We should have the following:
#
# H1-H2-H3-H4-H5-H6-H7
#            \  \     \
#             S5-A     \
#              \        \
#               S6-S7----B
#
# And there A and B have 2 merge bases (S5 and H5) that should be
# reported by "shit merge-base --all A B".
#
test_expect_success 'many merge bases creation' '
	shit checkout "$SIDE_HASH5" &&
	shit merge -m "merge HASH5 and SIDE_HASH5" "$HASH5" &&
	A_HASH=$(shit rev-parse --verify HEAD) &&
	shit checkout side &&
	shit merge -m "merge HASH7 and SIDE_HASH7" "$HASH7" &&
	B_HASH=$(shit rev-parse --verify HEAD) &&
	shit merge-base --all "$A_HASH" "$B_HASH" > merge_bases.txt &&
	test_line_count = 2 merge_bases.txt &&
	grep "$HASH5" merge_bases.txt &&
	grep "$SIDE_HASH5" merge_bases.txt
'

# We want to automatically find the merge that
# added "line" into hello.
test_expect_success '"shit bisect run --first-parent" simple case' '
	shit rev-list --first-parent $B_HASH ^$HASH4 >first_parent_chain.txt &&
	write_script test_script.sh <<-\EOF &&
	grep $(shit rev-parse HEAD) first_parent_chain.txt || exit -1
	! grep line hello >/dev/null
	EOF
	shit bisect start --first-parent &&
	test_path_is_file ".shit/BISECT_FIRST_PARENT" &&
	shit bisect good $HASH4 &&
	shit bisect bad $B_HASH &&
	shit bisect run ./test_script.sh >my_bisect_log.txt &&
	grep "$B_HASH is the first bad commit" my_bisect_log.txt &&
	shit bisect reset &&
	test_path_is_missing .shit/BISECT_FIRST_PARENT
'

test_expect_success 'good merge bases when good and bad are siblings' '
	shit bisect start "$B_HASH" "$A_HASH" > my_bisect_log.txt &&
	test_grep "merge base must be tested" my_bisect_log.txt &&
	shit bisect good > my_bisect_log2.txt &&
	test_grep "merge base must be tested" my_bisect_log2.txt &&
	{
		{
			grep "$SIDE_HASH5" my_bisect_log.txt &&
			grep "$HASH5" my_bisect_log2.txt
		} || {
			grep "$SIDE_HASH5" my_bisect_log2.txt &&
			grep "$HASH5" my_bisect_log.txt
		}
	} &&
	shit bisect reset
'

test_expect_success 'optimized merge base checks' '
	shit bisect start "$HASH7" "$SIDE_HASH7" > my_bisect_log.txt &&
	test_grep "merge base must be tested" my_bisect_log.txt &&
	grep "$HASH4" my_bisect_log.txt &&
	shit bisect good > my_bisect_log2.txt &&
	test -f ".shit/BISECT_ANCESTORS_OK" &&
	test "$HASH6" = $(shit rev-parse --verify HEAD) &&
	shit bisect bad &&
	shit bisect good "$A_HASH" > my_bisect_log4.txt &&
	test_grep "merge base must be tested" my_bisect_log4.txt &&
	test_path_is_missing ".shit/BISECT_ANCESTORS_OK"
'

# This creates another side branch called "parallel" with some files
# in some directories, to test bisecting with paths.
#
# We should have the following:
#
#    P1-P2-P3-P4-P5-P6-P7
#   /        /        /
# H1-H2-H3-H4-H5-H6-H7
#            \  \     \
#             S5-A     \
#              \        \
#               S6-S7----B
#
test_expect_success '"parallel" side branch creation' '
	shit bisect reset &&
	shit checkout -b parallel $HASH1 &&
	mkdir dir1 dir2 &&
	add_line_into_file "1(para): line 1 on parallel branch" dir1/file1 &&
	PARA_HASH1=$(shit rev-parse --verify HEAD) &&
	add_line_into_file "2(para): line 2 on parallel branch" dir2/file2 &&
	PARA_HASH2=$(shit rev-parse --verify HEAD) &&
	add_line_into_file "3(para): line 3 on parallel branch" dir2/file3 &&
	PARA_HASH3=$(shit rev-parse --verify HEAD) &&
	shit merge -m "merge HASH4 and PARA_HASH3" "$HASH4" &&
	PARA_HASH4=$(shit rev-parse --verify HEAD) &&
	add_line_into_file "5(para): add line on parallel branch" dir1/file1 &&
	PARA_HASH5=$(shit rev-parse --verify HEAD) &&
	add_line_into_file "6(para): add line on parallel branch" dir2/file2 &&
	PARA_HASH6=$(shit rev-parse --verify HEAD) &&
	shit merge -m "merge HASH7 and PARA_HASH6" "$HASH7" &&
	PARA_HASH7=$(shit rev-parse --verify HEAD)
'

test_expect_success 'restricting bisection on one dir' '
	shit bisect reset &&
	shit bisect start HEAD $HASH1 -- dir1 &&
	para1=$(shit rev-parse --verify HEAD) &&
	test "$para1" = "$PARA_HASH1" &&
	shit bisect bad > my_bisect_log.txt &&
	grep "$PARA_HASH1 is the first bad commit" my_bisect_log.txt
'

test_expect_success 'restricting bisection on one dir and a file' '
	shit bisect reset &&
	shit bisect start HEAD $HASH1 -- dir1 hello &&
	para4=$(shit rev-parse --verify HEAD) &&
	test "$para4" = "$PARA_HASH4" &&
	shit bisect bad &&
	hash3=$(shit rev-parse --verify HEAD) &&
	test "$hash3" = "$HASH3" &&
	shit bisect good &&
	hash4=$(shit rev-parse --verify HEAD) &&
	test "$hash4" = "$HASH4" &&
	shit bisect good &&
	para1=$(shit rev-parse --verify HEAD) &&
	test "$para1" = "$PARA_HASH1" &&
	shit bisect good > my_bisect_log.txt &&
	grep "$PARA_HASH4 is the first bad commit" my_bisect_log.txt
'

test_expect_success 'skipping away from skipped commit' '
	shit bisect start $PARA_HASH7 $HASH1 &&
	para4=$(shit rev-parse --verify HEAD) &&
	test "$para4" = "$PARA_HASH4" &&
        shit bisect skip &&
	hash7=$(shit rev-parse --verify HEAD) &&
	test "$hash7" = "$HASH7" &&
        shit bisect skip &&
	para3=$(shit rev-parse --verify HEAD) &&
	test "$para3" = "$PARA_HASH3"
'

test_expect_success 'erroring out when using bad path arguments' '
	test_must_fail shit bisect start $PARA_HASH7 $HASH1 -- foobar 2> error.txt &&
	test_grep "bad path arguments" error.txt
'

test_expect_success 'test bisection on bare repo - --no-checkout specified' '
	shit clone --bare . bare.nocheckout &&
	(
		cd bare.nocheckout &&
		shit bisect start --no-checkout &&
		shit bisect good $HASH1 &&
		shit bisect bad $HASH4 &&
		shit bisect run eval \
			"test \$(shit rev-list BISECT_HEAD ^$HASH2 --max-count=1 | wc -l) = 0" \
			>../nocheckout.log
	) &&
	grep "$HASH3 is the first bad commit" nocheckout.log
'


test_expect_success 'test bisection on bare repo - --no-checkout defaulted' '
	shit clone --bare . bare.defaulted &&
	(
		cd bare.defaulted &&
		shit bisect start &&
		shit bisect good $HASH1 &&
		shit bisect bad $HASH4 &&
		shit bisect run eval \
			"test \$(shit rev-list BISECT_HEAD ^$HASH2 --max-count=1 | wc -l) = 0" \
			>../defaulted.log
	) &&
	grep "$HASH3 is the first bad commit" defaulted.log
'

#
# This creates a broken branch which cannot be checked out because
# the tree created has been deleted.
#
# H1-H2-H3-H4-H5-H6-H7  <--other
#            \
#             S5-S6'-S7'-S8'-S9  <--broken
#
# Commits marked with ' have a missing tree.
#
test_expect_success 'broken branch creation' '
	shit bisect reset &&
	shit checkout -b broken $HASH4 &&
	shit tag BROKEN_HASH4 $HASH4 &&
	add_line_into_file "5(broken): first line on a broken branch" hello2 &&
	shit tag BROKEN_HASH5 &&
	mkdir missing &&
	:> missing/MISSING &&
	shit add missing/MISSING &&
	shit commit -m "6(broken): Added file that will be deleted" &&
	shit tag BROKEN_HASH6 &&
	deleted=$(shit rev-parse --verify HEAD:missing) &&
	add_line_into_file "7(broken): second line on a broken branch" hello2 &&
	shit tag BROKEN_HASH7 &&
	add_line_into_file "8(broken): third line on a broken branch" hello2 &&
	shit tag BROKEN_HASH8 &&
	shit rm missing/MISSING &&
	shit commit -m "9(broken): Remove missing file" &&
	shit tag BROKEN_HASH9 &&
	rm .shit/objects/$(test_oid_to_path $deleted)
'

echo "" > expected.ok
cat > expected.missing-tree.default <<EOF
fatal: unable to read tree ($deleted)
EOF

test_expect_success 'bisect fails if tree is broken on start commit' '
	shit bisect reset &&
	test_must_fail shit bisect start BROKEN_HASH7 BROKEN_HASH4 2>error.txt &&
	test_cmp expected.missing-tree.default error.txt
'

test_expect_success 'bisect fails if tree is broken on trial commit' '
	shit bisect reset &&
	test_must_fail shit bisect start BROKEN_HASH9 BROKEN_HASH4 2>error.txt &&
	shit reset --hard broken &&
	shit checkout broken &&
	test_cmp expected.missing-tree.default error.txt
'

check_same()
{
	echo "Checking $1 is the same as $2" &&
	test_cmp_rev "$1" "$2"
}

test_expect_success 'bisect: --no-checkout - start commit bad' '
	shit bisect reset &&
	shit bisect start BROKEN_HASH7 BROKEN_HASH4 --no-checkout &&
	check_same BROKEN_HASH6 BISECT_HEAD &&
	shit bisect reset
'

test_expect_success 'bisect: --no-checkout - trial commit bad' '
	shit bisect reset &&
	shit bisect start broken BROKEN_HASH4 --no-checkout &&
	check_same BROKEN_HASH6 BISECT_HEAD &&
	shit bisect reset
'

test_expect_success 'bisect: --no-checkout - target before breakage' '
	shit bisect reset &&
	shit bisect start broken BROKEN_HASH4 --no-checkout &&
	check_same BROKEN_HASH6 BISECT_HEAD &&
	shit bisect bad BISECT_HEAD &&
	check_same BROKEN_HASH5 BISECT_HEAD &&
	shit bisect bad BISECT_HEAD &&
	check_same BROKEN_HASH5 bisect/bad &&
	shit bisect reset
'

test_expect_success 'bisect: --no-checkout - target in breakage' '
	shit bisect reset &&
	shit bisect start broken BROKEN_HASH4 --no-checkout &&
	check_same BROKEN_HASH6 BISECT_HEAD &&
	shit bisect bad BISECT_HEAD &&
	check_same BROKEN_HASH5 BISECT_HEAD &&
	test_must_fail shit bisect good BISECT_HEAD &&
	check_same BROKEN_HASH6 bisect/bad &&
	shit bisect reset
'

test_expect_success 'bisect: --no-checkout - target after breakage' '
	shit bisect reset &&
	shit bisect start broken BROKEN_HASH4 --no-checkout &&
	check_same BROKEN_HASH6 BISECT_HEAD &&
	shit bisect good BISECT_HEAD &&
	check_same BROKEN_HASH8 BISECT_HEAD &&
	test_must_fail shit bisect good BISECT_HEAD &&
	check_same BROKEN_HASH9 bisect/bad &&
	shit bisect reset
'

test_expect_success 'bisect: demonstrate identification of damage boundary' "
	shit bisect reset &&
	shit checkout broken &&
	shit bisect start broken main --no-checkout &&
	test_must_fail shit bisect run \"\$SHELL_PATH\" -c '
		GOOD=\$(shit for-each-ref \"--format=%(objectname)\" refs/bisect/good-*) &&
		shit rev-list --objects BISECT_HEAD --not \$GOOD >tmp.\$\$ &&
		shit pack-objects --stdout >/dev/null < tmp.\$\$
		rc=\$?
		rm -f tmp.\$\$
		test \$rc = 0' &&
	check_same BROKEN_HASH6 bisect/bad &&
	shit bisect reset
"

cat > expected.bisect-log <<EOF
# bad: [$HASH4] Add <4: Ciao for now> into <hello>.
# good: [$HASH2] Add <2: A new day for shit> into <hello>.
shit bisect start '$HASH4' '$HASH2'
# good: [$HASH3] Add <3: Another new day for shit> into <hello>.
shit bisect good $HASH3
# first bad commit: [$HASH4] Add <4: Ciao for now> into <hello>.
EOF

test_expect_success 'bisect log: successful result' '
	shit bisect reset &&
	shit bisect start $HASH4 $HASH2 &&
	shit bisect good &&
	shit bisect log >bisect-log.txt &&
	test_cmp expected.bisect-log bisect-log.txt &&
	shit bisect reset
'

cat > expected.bisect-skip-log <<EOF
# bad: [$HASH4] Add <4: Ciao for now> into <hello>.
# good: [$HASH2] Add <2: A new day for shit> into <hello>.
shit bisect start '$HASH4' '$HASH2'
# skip: [$HASH3] Add <3: Another new day for shit> into <hello>.
shit bisect skip $HASH3
# only skipped commits left to test
# possible first bad commit: [$HASH4] Add <4: Ciao for now> into <hello>.
# possible first bad commit: [$HASH3] Add <3: Another new day for shit> into <hello>.
EOF

test_expect_success 'bisect log: only skip commits left' '
	shit bisect reset &&
	shit bisect start $HASH4 $HASH2 &&
	test_must_fail shit bisect skip &&
	shit bisect log >bisect-skip-log.txt &&
	test_cmp expected.bisect-skip-log bisect-skip-log.txt &&
	shit bisect reset
'

test_expect_success '"shit bisect bad HEAD" behaves as "shit bisect bad"' '
	shit checkout parallel &&
	shit bisect start HEAD $HASH1 &&
	shit bisect good HEAD &&
	shit bisect bad HEAD &&
	test "$HASH6" = $(shit rev-parse --verify HEAD) &&
	shit bisect reset
'

test_expect_success 'bisect starts with only one new' '
	shit bisect reset &&
	shit bisect start &&
	shit bisect new $HASH4 &&
	shit bisect next
'

test_expect_success 'bisect does not start with only one old' '
	shit bisect reset &&
	shit bisect start &&
	shit bisect old $HASH1 &&
	test_must_fail shit bisect next
'

test_expect_success 'bisect start with one new and old' '
	shit bisect reset &&
	shit bisect start &&
	shit bisect old $HASH1 &&
	shit bisect new $HASH4 &&
	shit bisect new &&
	shit bisect new >bisect_result &&
	grep "$HASH2 is the first new commit" bisect_result &&
	shit bisect log >log_to_replay.txt &&
	shit bisect reset
'

test_expect_success 'bisect replay with old and new' '
	shit bisect replay log_to_replay.txt >bisect_result &&
	grep "$HASH2 is the first new commit" bisect_result &&
	shit bisect reset
'

test_expect_success 'bisect replay with CRLF log' '
	append_cr <log_to_replay.txt >log_to_replay_crlf.txt &&
	shit bisect replay log_to_replay_crlf.txt >bisect_result_crlf &&
	grep "$HASH2 is the first new commit" bisect_result_crlf &&
	shit bisect reset
'

test_expect_success 'bisect cannot mix old/new and good/bad' '
	shit bisect start &&
	shit bisect bad $HASH4 &&
	test_must_fail shit bisect old $HASH1
'

test_expect_success 'bisect terms needs 0 or 1 argument' '
	shit bisect reset &&
	test_must_fail shit bisect terms only-one &&
	test_must_fail shit bisect terms 1 2 &&
	test_must_fail shit bisect terms 2>actual &&
	echo "error: no terms defined" >expected &&
	test_cmp expected actual
'

test_expect_success 'bisect terms shows good/bad after start' '
	shit bisect reset &&
	shit bisect start HEAD $HASH1 &&
	shit bisect terms --term-good >actual &&
	echo good >expected &&
	test_cmp expected actual &&
	shit bisect terms --term-bad >actual &&
	echo bad >expected &&
	test_cmp expected actual
'

test_expect_success 'bisect start with one term1 and term2' '
	shit bisect reset &&
	shit bisect start --term-old term2 --term-new term1 &&
	shit bisect term2 $HASH1 &&
	shit bisect term1 $HASH4 &&
	shit bisect term1 &&
	shit bisect term1 >bisect_result &&
	grep "$HASH2 is the first term1 commit" bisect_result &&
	shit bisect log >log_to_replay.txt &&
	shit bisect reset
'

test_expect_success 'bogus command does not start bisect' '
	shit bisect reset &&
	test_must_fail shit bisect --bisect-terms 1 2 2>out &&
	! grep "You need to start" out &&
	test_must_fail shit bisect --bisect-terms 2>out &&
	! grep "You need to start" out &&
	grep "shit bisect.*visualize" out &&
	shit bisect reset
'

test_expect_success 'bisect replay with term1 and term2' '
	shit bisect replay log_to_replay.txt >bisect_result &&
	grep "$HASH2 is the first term1 commit" bisect_result &&
	shit bisect reset
'

test_expect_success 'bisect start term1 term2' '
	shit bisect reset &&
	shit bisect start --term-new term1 --term-old term2 $HASH4 $HASH1 &&
	shit bisect term1 &&
	shit bisect term1 >bisect_result &&
	grep "$HASH2 is the first term1 commit" bisect_result &&
	shit bisect log >log_to_replay.txt &&
	shit bisect reset
'

test_expect_success 'bisect cannot mix terms' '
	shit bisect reset &&
	shit bisect start --term-good term1 --term-bad term2 $HASH4 $HASH1 &&
	test_must_fail shit bisect a &&
	test_must_fail shit bisect b &&
	test_must_fail shit bisect bad &&
	test_must_fail shit bisect good &&
	test_must_fail shit bisect new &&
	test_must_fail shit bisect old
'

test_expect_success 'bisect terms rejects invalid terms' '
	shit bisect reset &&
	test_must_fail shit bisect start --term-good &&
	test_must_fail shit bisect start --term-good invalid..term &&
	test_must_fail shit bisect start --term-bad &&
	test_must_fail shit bisect terms --term-bad invalid..term &&
	test_must_fail shit bisect terms --term-good bad &&
	test_must_fail shit bisect terms --term-good old &&
	test_must_fail shit bisect terms --term-good skip &&
	test_must_fail shit bisect terms --term-good reset &&
	test_path_is_missing .shit/BISECT_TERMS
'

test_expect_success 'bisect start --term-* does store terms' '
	shit bisect reset &&
	shit bisect start --term-bad=one --term-good=two &&
	shit bisect terms >actual &&
	cat <<-EOF >expected &&
	Your current terms are two for the old state
	and one for the new state.
	EOF
	test_cmp expected actual &&
	shit bisect terms --term-bad >actual &&
	echo one >expected &&
	test_cmp expected actual &&
	shit bisect terms --term-good >actual &&
	echo two >expected &&
	test_cmp expected actual
'

test_expect_success 'bisect start takes options and revs in any order' '
	shit bisect reset &&
	shit bisect start --term-good one $HASH4 \
		--term-good two --term-bad bad-term \
		$HASH1 --term-good three -- &&
	(shit bisect terms --term-bad && shit bisect terms --term-good) >actual &&
	printf "%s\n%s\n" bad-term three >expected &&
	test_cmp expected actual
'

# Bisect is started with --term-new and --term-old arguments,
# then skip. The HEAD should be changed.
test_expect_success 'bisect skip works with --term*' '
	shit bisect reset &&
	shit bisect start --term-new=fixed --term-old=unfixed HEAD $HASH1 &&
	hash_skipped_from=$(shit rev-parse --verify HEAD) &&
	shit bisect skip &&
	hash_skipped_to=$(shit rev-parse --verify HEAD) &&
	test "$hash_skipped_from" != "$hash_skipped_to"
'

test_expect_success 'shit bisect reset cleans bisection state properly' '
	shit bisect reset &&
	shit bisect start &&
	shit bisect good $HASH1 &&
	shit bisect bad $HASH4 &&
	shit bisect reset &&
	test -z "$(shit for-each-ref "refs/bisect/*")" &&
	test_ref_missing BISECT_EXPECTED_REV &&
	test_path_is_missing ".shit/BISECT_ANCESTORS_OK" &&
	test_path_is_missing ".shit/BISECT_LOG" &&
	test_path_is_missing ".shit/BISECT_RUN" &&
	test_path_is_missing ".shit/BISECT_TERMS" &&
	test_path_is_missing ".shit/BISECT_HEAD" &&
	test_path_is_missing ".shit/BISECT_START"
'

test_expect_success 'bisect handles annotated tags' '
	test_commit commit-one &&
	shit tag -m foo tag-one &&
	test_commit commit-two &&
	shit tag -m foo tag-two &&
	shit bisect start &&
	shit bisect good tag-one &&
	shit bisect bad tag-two >output &&
	bad=$(shit rev-parse --verify tag-two^{commit}) &&
	grep "$bad is the first bad commit" output
'

test_expect_success 'bisect run fails with exit code equals or greater than 128' '
	write_script test_script.sh <<-\EOF &&
	exit 128
	EOF
	test_must_fail shit bisect run ./test_script.sh &&
	write_script test_script.sh <<-\EOF &&
	exit 255
	EOF
	test_must_fail shit bisect run ./test_script.sh
'

test_expect_success 'bisect visualize with a filename with dash and space' '
	echo "My test line" >>"./-hello 2" &&
	shit add -- "./-hello 2" &&
	shit commit --quiet -m "Add test line" -- "./-hello 2" &&
	shit bisect visualize -p -- "-hello 2"
'

test_expect_success 'bisect state output with multiple good commits' '
	shit bisect reset &&
	shit bisect start >output &&
	grep "waiting for both good and bad commits" output &&
	shit bisect log >output &&
	grep "waiting for both good and bad commits" output &&
	shit bisect good "$HASH1" >output &&
	grep "waiting for bad commit, 1 good commit known" output &&
	shit bisect log >output &&
	grep "waiting for bad commit, 1 good commit known" output &&
	shit bisect good "$HASH2" >output &&
	grep "waiting for bad commit, 2 good commits known" output &&
	shit bisect log >output &&
	grep "waiting for bad commit, 2 good commits known" output
'

test_expect_success 'bisect state output with bad commit' '
	shit bisect reset &&
	shit bisect start >output &&
	grep "waiting for both good and bad commits" output &&
	shit bisect log >output &&
	grep "waiting for both good and bad commits" output &&
	shit bisect bad "$HASH4" >output &&
	grep -F "waiting for good commit(s), bad commit known" output &&
	shit bisect log >output &&
	grep -F "waiting for good commit(s), bad commit known" output
'

test_expect_success 'verify correct error message' '
	shit bisect reset &&
	shit bisect start $HASH4 $HASH1 &&
	write_script test_script.sh <<-\EOF &&
	rm .shit/BISECT*
	EOF
	test_must_fail shit bisect run ./test_script.sh 2>error &&
	grep "shit bisect good.*exited with error code" error
'

test_done
