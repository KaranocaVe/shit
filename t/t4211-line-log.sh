#!/bin/sh

test_description='test log -L'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup (import history)' '
	shit fast-import < "$TEST_DIRECTORY"/t4211/history.export &&
	shit reset --hard
'

test_expect_success 'basic command line parsing' '
	# This may fail due to "no such path a.c in commit", or
	# "-L is incompatible with pathspec", depending on the
	# order the error is checked.  Either is acceptable.
	test_must_fail shit log -L1,1:a.c -- a.c &&

	# -L requires there is no pathspec
	test_must_fail shit log -L1,1:b.c -- b.c 2>error &&
	test_grep "cannot be used with pathspec" error &&

	# This would fail because --follow wants a single path, but
	# we may fail due to incompatibility between -L/--follow in
	# the future.  Either is acceptable.
	test_must_fail shit log -L1,1:b.c --follow &&
	test_must_fail shit log --follow -L1,1:b.c &&

	# This would fail because -L wants no pathspec, but
	# we may fail due to incompatibility between -L/--follow in
	# the future.  Either is acceptable.
	test_must_fail shit log --follow -L1,1:b.c -- b.c
'

canned_test_1 () {
	test_expect_$1 "$2" "
		shit log $2 >actual &&
		test_cmp \"\$TEST_DIRECTORY\"/t4211/$(test_oid algo)/expect.$3 actual
	"
}

canned_test () {
	canned_test_1 success "$@"
}
canned_test_failure () {
	canned_test_1 failure "$@"
}

test_bad_opts () {
	test_expect_success "invalid args: $1" "
		test_must_fail shit log $1 2>errors &&
		test_grep '$2' errors
	"
}

canned_test "-L 4,12:a.c simple" simple-f
canned_test "-L 4,+9:a.c simple" simple-f
canned_test "-L '/long f/,/^}/:a.c' simple" simple-f
canned_test "-L :f:a.c simple" simple-f-to-main

canned_test "-L '/main/,/^}/:a.c' simple" simple-main
canned_test "-L :main:a.c simple" simple-main-to-end

canned_test "-L 1,+4:a.c simple" beginning-of-file

canned_test "-L 20:a.c simple" end-of-file

canned_test "-L '/long f/',/^}/:a.c -L /main/,/^}/:a.c simple" two-ranges
canned_test "-L 24,+1:a.c simple" vanishes-early

canned_test "-M -L '/long f/,/^}/:b.c' move-support" move-support-f
canned_test "-M -L ':f:b.c' parallel-change" parallel-change-f-to-main

canned_test "-L 4,12:a.c -L :main:a.c simple" multiple
canned_test "-L 4,18:a.c -L ^:main:a.c simple" multiple-overlapping
canned_test "-L :main:a.c -L 4,18:a.c simple" multiple-overlapping
canned_test "-L 4:a.c -L 8,12:a.c simple" multiple-superset
canned_test "-L 8,12:a.c -L 4:a.c simple" multiple-superset

test_bad_opts "-L" "switch.*requires a value"
test_bad_opts "-L b.c" "argument not .start,end:file"
test_bad_opts "-L 1:" "argument not .start,end:file"
test_bad_opts "-L 1:nonexistent" "There is no path"
test_bad_opts "-L 1:simple" "There is no path"
test_bad_opts "-L '/foo:b.c'" "argument not .start,end:file"
test_bad_opts "-L 1000:b.c" "has only.*lines"
test_bad_opts "-L :b.c" "argument not .start,end:file"
test_bad_opts "-L :foo:b.c" "no match"

test_expect_success '-L X (X == nlines)' '
	n=$(wc -l <b.c) &&
	shit log -L $n:b.c
'

test_expect_success '-L X (X == nlines + 1)' '
	n=$(expr $(wc -l <b.c) + 1) &&
	test_must_fail shit log -L $n:b.c
'

test_expect_success '-L X (X == nlines + 2)' '
	n=$(expr $(wc -l <b.c) + 2) &&
	test_must_fail shit log -L $n:b.c
'

test_expect_success '-L ,Y (Y == nlines)' '
	n=$(printf "%d" $(wc -l <b.c)) &&
	shit log -L ,$n:b.c
'

test_expect_success '-L ,Y (Y == nlines + 1)' '
	n=$(expr $(wc -l <b.c) + 1) &&
	shit log -L ,$n:b.c
'

test_expect_success '-L ,Y (Y == nlines + 2)' '
	n=$(expr $(wc -l <b.c) + 2) &&
	shit log -L ,$n:b.c
'

test_expect_success '-L with --first-parent and a merge' '
	shit checkout parallel-change &&
	shit log --first-parent -L 1,1:b.c
'

test_expect_success '-L with --output' '
	shit checkout parallel-change &&
	shit log --output=log -L :main:b.c >output &&
	test_must_be_empty output &&
	test_line_count = 70 log
'

test_expect_success 'range_set_union' '
	test_seq 500 > c.c &&
	shit add c.c &&
	shit commit -m "many lines" &&
	test_seq 1000 > c.c &&
	shit add c.c &&
	shit commit -m "modify many lines" &&
	shit log $(for x in $(test_seq 200); do echo -L $((2*x)),+1:c.c || return 1; done)
'

test_expect_success '-s shows only line-log commits' '
	shit log --format="commit %s" -L1,24:b.c >expect.raw &&
	grep ^commit expect.raw >expect &&
	shit log --format="commit %s" -L1,24:b.c -s >actual &&
	test_cmp expect actual
'

test_expect_success '-p shows the default patch output' '
	shit log -L1,24:b.c >expect &&
	shit log -L1,24:b.c -p >actual &&
	test_cmp expect actual
'

test_expect_success '--raw is forbidden' '
	test_must_fail shit log -L1,24:b.c --raw
'

test_expect_success 'setup for checking fancy rename following' '
	shit checkout --orphan moves-start &&
	shit reset --hard &&

	printf "%s\n"    12 13 14 15      b c d e   >file-1 &&
	printf "%s\n"    22 23 24 25      B C D E   >file-2 &&
	shit add file-1 file-2 &&
	test_tick &&
	shit commit -m "Add file-1 and file-2" &&
	oid_add_f1_f2=$(shit rev-parse --short HEAD) &&

	shit checkout -b moves-main &&
	printf "%s\n" 11 12 13 14 15      b c d e   >file-1 &&
	shit commit -a -m "Modify file-1 on main" &&
	oid_mod_f1_main=$(shit rev-parse --short HEAD) &&

	printf "%s\n" 21 22 23 24 25      B C D E   >file-2 &&
	shit commit -a -m "Modify file-2 on main #1" &&
	oid_mod_f2_main_1=$(shit rev-parse --short HEAD) &&

	shit mv file-1 renamed-1 &&
	shit commit -m "Rename file-1 to renamed-1 on main" &&

	printf "%s\n" 11 12 13 14 15      b c d e f >renamed-1 &&
	shit commit -a -m "Modify renamed-1 on main" &&
	oid_mod_r1_main=$(shit rev-parse --short HEAD) &&

	printf "%s\n" 21 22 23 24 25      B C D E F >file-2 &&
	shit commit -a -m "Modify file-2 on main #2" &&
	oid_mod_f2_main_2=$(shit rev-parse --short HEAD) &&

	shit checkout -b moves-side moves-start &&
	printf "%s\n"    12 13 14 15 16   b c d e   >file-1 &&
	shit commit -a -m "Modify file-1 on side #1" &&
	oid_mod_f1_side_1=$(shit rev-parse --short HEAD) &&

	printf "%s\n"    22 23 24 25 26   B C D E   >file-2 &&
	shit commit -a -m "Modify file-2 on side" &&
	oid_mod_f2_side=$(shit rev-parse --short HEAD) &&

	shit mv file-2 renamed-2 &&
	shit commit -m "Rename file-2 to renamed-2 on side" &&

	printf "%s\n"    12 13 14 15 16 a b c d e   >file-1 &&
	shit commit -a -m "Modify file-1 on side #2" &&
	oid_mod_f1_side_2=$(shit rev-parse --short HEAD) &&

	printf "%s\n"    22 23 24 25 26 A B C D E   >renamed-2 &&
	shit commit -a -m "Modify renamed-2 on side" &&
	oid_mod_r2_side=$(shit rev-parse --short HEAD) &&

	shit checkout moves-main &&
	shit merge moves-side &&
	oid_merge=$(shit rev-parse --short HEAD)
'

test_expect_success 'fancy rename following #1' '
	cat >expect <<-EOF &&
	$oid_merge Merge branch '\''moves-side'\'' into moves-main
	$oid_mod_f1_side_2 Modify file-1 on side #2
	$oid_mod_f1_side_1 Modify file-1 on side #1
	$oid_mod_r1_main Modify renamed-1 on main
	$oid_mod_f1_main Modify file-1 on main
	$oid_add_f1_f2 Add file-1 and file-2
	EOF
	shit log -L1:renamed-1 --oneline --no-patch >actual &&
	test_cmp expect actual
'

test_expect_success 'fancy rename following #2' '
	cat >expect <<-EOF &&
	$oid_merge Merge branch '\''moves-side'\'' into moves-main
	$oid_mod_r2_side Modify renamed-2 on side
	$oid_mod_f2_side Modify file-2 on side
	$oid_mod_f2_main_2 Modify file-2 on main #2
	$oid_mod_f2_main_1 Modify file-2 on main #1
	$oid_add_f1_f2 Add file-1 and file-2
	EOF
	shit log -L1:renamed-2 --oneline --no-patch >actual &&
	test_cmp expect actual
'

# Create the following linear history, where each commit does what its
# subject line promises:
#
#   * 66c6410 Modify func2() in file.c
#   * 50834e5 Modify other-file
#   * fe5851c Modify func1() in file.c
#   * 8c7c7dd Add other-file
#   * d5f4417 Add func1() and func2() in file.c
test_expect_success 'setup for checking line-log and parent oids' '
	shit checkout --orphan parent-oids &&
	shit reset --hard &&

	cat >file.c <<-\EOF &&
	int func1()
	{
	    return F1;
	}

	int func2()
	{
	    return F2;
	}
	EOF
	shit add file.c &&
	test_tick &&
	first_tick=$test_tick &&
	shit commit -m "Add func1() and func2() in file.c" &&

	echo 1 >other-file &&
	shit add other-file &&
	test_tick &&
	shit commit -m "Add other-file" &&

	sed -e "s/F1/F1 + 1/" file.c >tmp &&
	mv tmp file.c &&
	shit commit -a -m "Modify func1() in file.c" &&

	echo 2 >other-file &&
	shit commit -a -m "Modify other-file" &&

	sed -e "s/F2/F2 + 2/" file.c >tmp &&
	mv tmp file.c &&
	shit commit -a -m "Modify func2() in file.c" &&

	head_oid=$(shit rev-parse --short HEAD) &&
	prev_oid=$(shit rev-parse --short HEAD^) &&
	root_oid=$(shit rev-parse --short HEAD~4)
'

# Parent oid should be from immediate parent.
test_expect_success 'parent oids without parent rewriting' '
	cat >expect <<-EOF &&
	$head_oid $prev_oid Modify func2() in file.c
	$root_oid  Add func1() and func2() in file.c
	EOF
	shit log --format="%h %p %s" --no-patch -L:func2:file.c >actual &&
	test_cmp expect actual
'

# Parent oid should be from the most recent ancestor touching func2(),
# i.e. in this case from the root commit.
test_expect_success 'parent oids with parent rewriting' '
	cat >expect <<-EOF &&
	$head_oid $root_oid Modify func2() in file.c
	$root_oid  Add func1() and func2() in file.c
	EOF
	shit log --format="%h %p %s" --no-patch -L:func2:file.c --parents >actual &&
	test_cmp expect actual
'

test_expect_success 'line-log with --before' '
	echo $root_oid >expect &&
	shit log --format=%h --no-patch -L:func2:file.c --before=$first_tick >actual &&
	test_cmp expect actual
'

test_expect_success 'setup tests for zero-width regular expressions' '
	cat >expect <<-EOF
	Modify func1() in file.c
	Add func1() and func2() in file.c
	EOF
'

test_expect_success 'zero-width regex $ matches any function name' '
	shit log --format="%s" --no-patch "-L:$:file.c" >actual &&
	test_cmp expect actual
'

test_expect_success 'zero-width regex ^ matches any function name' '
	shit log --format="%s" --no-patch "-L:^:file.c" >actual &&
	test_cmp expect actual
'

test_expect_success 'zero-width regex .* matches any function name' '
	shit log --format="%s" --no-patch "-L:.*:file.c" >actual &&
	test_cmp expect actual
'

test_done
