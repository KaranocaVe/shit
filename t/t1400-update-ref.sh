#!/bin/sh
#
# Copyright (c) 2006 Shawn Pearce
#

test_description='Test shit update-ref and basic ref logging'
. ./test-lib.sh

Z=$ZERO_OID

m=refs/heads/main
outside=refs/foo
bare=bare-repo

create_test_commits ()
{
	prfx="$1"
	for name in A B C D E F
	do
		test_tick &&
		T=$(shit write-tree) &&
		sha1=$(echo $name | shit commit-tree $T) &&
		eval $prfx$name=$sha1
	done
}

test_expect_success setup '
	shit checkout --orphan main &&
	create_test_commits "" &&
	mkdir $bare &&
	cd $bare &&
	shit init --bare -b main &&
	create_test_commits "bare" &&
	cd -
'

test_expect_success "create $m" '
	shit update-ref $m $A &&
	test $A = $(shit show-ref -s --verify $m)
'
test_expect_success "create $m with oldvalue verification" '
	shit update-ref $m $B $A &&
	test $B = $(shit show-ref -s --verify $m)
'
test_expect_success "fail to delete $m with stale ref" '
	test_must_fail shit update-ref -d $m $A &&
	test $B = "$(shit show-ref -s --verify $m)"
'
test_expect_success "delete $m" '
	test_when_finished "shit update-ref -d $m" &&
	shit update-ref -d $m $B &&
	test_must_fail shit show-ref --verify -q $m
'

test_expect_success "delete $m without oldvalue verification" '
	test_when_finished "shit update-ref -d $m" &&
	shit update-ref $m $A &&
	test $A = $(shit show-ref -s --verify $m) &&
	shit update-ref -d $m &&
	test_must_fail shit show-ref --verify -q $m
'

test_expect_success "fail to create $n due to file/directory conflict" '
	test_when_finished "shit update-ref -d refs/heads/gu" &&
	shit update-ref refs/heads/gu $A &&
	test_must_fail shit update-ref refs/heads/gu/fixes $A
'

test_expect_success "create $m (by HEAD)" '
	shit update-ref HEAD $A &&
	test $A = $(shit show-ref -s --verify $m)
'
test_expect_success "create $m (by HEAD) with oldvalue verification" '
	shit update-ref HEAD $B $A &&
	test $B = $(shit show-ref -s --verify $m)
'
test_expect_success "fail to delete $m (by HEAD) with stale ref" '
	test_must_fail shit update-ref -d HEAD $A &&
	test $B = $(shit show-ref -s --verify $m)
'
test_expect_success "delete $m (by HEAD)" '
	test_when_finished "shit update-ref -d $m" &&
	shit update-ref -d HEAD $B &&
	test_must_fail shit show-ref --verify -q $m
'

test_expect_success "deleting current branch adds message to HEAD's log" '
	test_when_finished "shit update-ref -d $m" &&
	shit update-ref $m $A &&
	shit symbolic-ref HEAD $m &&
	shit update-ref -m delete-$m -d $m &&
	test_must_fail shit show-ref --verify -q $m &&
	test-tool ref-store main for-each-reflog-ent HEAD >actual &&
	grep "delete-$m$" actual
'

test_expect_success "deleting by HEAD adds message to HEAD's log" '
	test_when_finished "shit update-ref -d $m" &&
	shit update-ref $m $A &&
	shit symbolic-ref HEAD $m &&
	shit update-ref -m delete-by-head -d HEAD &&
	test_must_fail shit show-ref --verify -q $m &&
	test-tool ref-store main for-each-reflog-ent HEAD >actual &&
	grep "delete-by-head$" actual
'

test_expect_success 'update-ref does not create reflogs by default' '
	test_when_finished "shit update-ref -d $outside" &&
	shit update-ref $outside $A &&
	shit rev-parse $A >expect &&
	shit rev-parse $outside >actual &&
	test_cmp expect actual &&
	test_must_fail shit reflog exists $outside
'

test_expect_success 'update-ref creates reflogs with --create-reflog' '
	test_when_finished "shit update-ref -d $outside" &&
	shit update-ref --create-reflog $outside $A &&
	shit rev-parse $A >expect &&
	shit rev-parse $outside >actual &&
	test_cmp expect actual &&
	shit reflog exists $outside
'

test_expect_success 'creates no reflog in bare repository' '
	shit -C $bare update-ref $m $bareA &&
	shit -C $bare rev-parse $bareA >expect &&
	shit -C $bare rev-parse $m >actual &&
	test_cmp expect actual &&
	test_must_fail shit -C $bare reflog exists $m
'

test_expect_success 'core.logAllRefUpdates=true creates reflog in bare repository' '
	test_when_finished "shit -C $bare config --unset core.logAllRefUpdates && \
		test-tool ref-store main delete-reflog $m" &&
	shit -C $bare config core.logAllRefUpdates true &&
	shit -C $bare update-ref $m $bareB &&
	shit -C $bare rev-parse $bareB >expect &&
	shit -C $bare rev-parse $m >actual &&
	test_cmp expect actual &&
	shit -C $bare reflog exists $m
'

test_expect_success 'core.logAllRefUpdates=true does not create reflog by default' '
	test_config core.logAllRefUpdates true &&
	test_when_finished "shit update-ref -d $outside" &&
	shit update-ref $outside $A &&
	shit rev-parse $A >expect &&
	shit rev-parse $outside >actual &&
	test_cmp expect actual &&
	test_must_fail shit reflog exists $outside
'

test_expect_success 'core.logAllRefUpdates=always creates reflog by default' '
	test_config core.logAllRefUpdates always &&
	test_when_finished "shit update-ref -d $outside" &&
	shit update-ref $outside $A &&
	shit rev-parse $A >expect &&
	shit rev-parse $outside >actual &&
	test_cmp expect actual &&
	shit reflog exists $outside
'

test_expect_success 'core.logAllRefUpdates=always creates reflog for ORIG_HEAD' '
	test_config core.logAllRefUpdates always &&
	shit update-ref ORIG_HEAD $A &&
	shit reflog exists ORIG_HEAD
'

test_expect_success '--no-create-reflog overrides core.logAllRefUpdates=always' '
	test_config core.logAllRefUpdates true &&
	test_when_finished "shit update-ref -d $outside" &&
	shit update-ref --no-create-reflog $outside $A &&
	shit rev-parse $A >expect &&
	shit rev-parse $outside >actual &&
	test_cmp expect actual &&
	test_must_fail shit reflog exists $outside
'

test_expect_success "create $m (by HEAD)" '
	shit update-ref HEAD $A &&
	test $A = $(shit show-ref -s --verify $m)
'
test_expect_success 'pack refs' '
	shit pack-refs --all
'
test_expect_success "move $m (by HEAD)" '
	shit update-ref HEAD $B $A &&
	test $B = $(shit show-ref -s --verify $m)
'
test_expect_success "delete $m (by HEAD) should remove both packed and loose $m" '
	test_when_finished "shit update-ref -d $m" &&
	shit update-ref -d HEAD $B &&
	! grep "$m" .shit/packed-refs &&
	test_must_fail shit show-ref --verify -q $m
'

test_expect_success 'delete symref without dereference' '
	test_when_finished "shit update-ref -d $m" &&
	echo foo >foo.c &&
	shit add foo.c &&
	shit commit -m foo &&
	shit symbolic-ref SYMREF $m &&
	shit update-ref --no-deref -d SYMREF &&
	shit show-ref --verify -q $m &&
	test_must_fail shit show-ref --verify -q SYMREF &&
	test_must_fail shit symbolic-ref SYMREF
'

test_expect_success 'delete symref without dereference when the referred ref is packed' '
	test_when_finished "shit update-ref -d $m" &&
	echo foo >foo.c &&
	shit add foo.c &&
	shit commit -m foo &&
	shit symbolic-ref SYMREF $m &&
	shit pack-refs --all &&
	shit update-ref --no-deref -d SYMREF &&
	shit show-ref --verify -q $m &&
	test_must_fail shit show-ref --verify -q SYMREF &&
	test_must_fail shit symbolic-ref SYMREF
'

test_expect_success 'update-ref -d is not confused by self-reference' '
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF refs/heads/self" &&
	shit symbolic-ref refs/heads/self refs/heads/self &&
	shit symbolic-ref --no-recurse refs/heads/self &&
	test_must_fail shit update-ref -d refs/heads/self &&
	shit symbolic-ref --no-recurse refs/heads/self
'

test_expect_success 'update-ref --no-deref -d can delete self-reference' '
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF refs/heads/self" &&
	shit symbolic-ref refs/heads/self refs/heads/self &&
	shit symbolic-ref --no-recurse refs/heads/self &&
	shit update-ref --no-deref -d refs/heads/self &&
	test_must_fail shit show-ref --verify -q refs/heads/self
'

test_expect_success REFFILES 'update-ref --no-deref -d can delete reference to bad ref' '
	>.shit/refs/heads/bad &&
	test_when_finished "rm -f .shit/refs/heads/bad" &&
	shit symbolic-ref refs/heads/ref-to-bad refs/heads/bad &&
	test_when_finished "shit update-ref -d refs/heads/ref-to-bad" &&
	shit symbolic-ref --no-recurse refs/heads/ref-to-bad &&
	shit update-ref --no-deref -d refs/heads/ref-to-bad &&
	test_must_fail shit show-ref --verify -q refs/heads/ref-to-bad
'

test_expect_success '(not) create HEAD with old sha1' '
	test_must_fail shit update-ref HEAD $A $B
'
test_expect_success "(not) prior created .shit/$m" '
	test_when_finished "shit update-ref -d $m" &&
	test_must_fail shit show-ref --verify -q $m
'

test_expect_success 'create HEAD' '
	shit update-ref HEAD $A
'
test_expect_success '(not) change HEAD with wrong SHA1' '
	test_must_fail shit update-ref HEAD $B $Z
'
test_expect_success "(not) changed .shit/$m" '
	test_when_finished "shit update-ref -d $m" &&
	! test $B = $(shit show-ref -s --verify $m)
'

test_expect_success "clean up reflog" '
	test-tool ref-store main delete-reflog $m
'

test_expect_success "create $m (logged by touch)" '
	test_config core.logAllRefUpdates false &&
	shit_COMMITTER_DATE="2005-05-26 23:30" \
	shit update-ref --create-reflog HEAD $A -m "Initial Creation" &&
	test $A = $(shit show-ref -s --verify $m)
'
test_expect_success "update $m (logged by touch)" '
	test_config core.logAllRefUpdates false &&
	shit_COMMITTER_DATE="2005-05-26 23:31" \
	shit update-ref HEAD $B $A -m "Switch" &&
	test $B = $(shit show-ref -s --verify $m)
'
test_expect_success "set $m (logged by touch)" '
	test_config core.logAllRefUpdates false &&
	shit_COMMITTER_DATE="2005-05-26 23:41" \
	shit update-ref HEAD $A &&
	test $A = $(shit show-ref -s --verify $m)
'

cat >expect <<EOF
$Z $A $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> 1117150200 +0000	Initial Creation
$A $B $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> 1117150260 +0000	Switch
$B $A $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> 1117150860 +0000
EOF
test_expect_success "verifying $m's log (logged by touch)" '
	test_when_finished "shit update-ref -d $m && shit reflog expire --expire=all --all && rm -rf actual expect" &&
	test-tool ref-store main for-each-reflog-ent $m >actual &&
	test_cmp actual expect
'

test_expect_success "create $m (logged by config)" '
	test_config core.logAllRefUpdates true &&
	shit_COMMITTER_DATE="2005-05-26 23:32" \
	shit update-ref HEAD $A -m "Initial Creation" &&
	test $A = $(shit show-ref -s --verify $m)
'
test_expect_success "update $m (logged by config)" '
	test_config core.logAllRefUpdates true &&
	shit_COMMITTER_DATE="2005-05-26 23:33" \
	shit update-ref HEAD $B $A -m "Switch" &&
	test $B = $(shit show-ref -s --verify $m)
'
test_expect_success "set $m (logged by config)" '
	test_config core.logAllRefUpdates true &&
	shit_COMMITTER_DATE="2005-05-26 23:43" \
	shit update-ref HEAD $A &&
	test $A = $(shit show-ref -s --verify $m)
'

cat >expect <<EOF
$Z $A $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> 1117150320 +0000	Initial Creation
$A $B $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> 1117150380 +0000	Switch
$B $A $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> 1117150980 +0000
EOF
test_expect_success "verifying $m's log (logged by config)" '
	test_when_finished "shit update-ref -d $m && shit reflog expire --expire=all --all && rm -rf actual expect" &&
	test-tool ref-store main for-each-reflog-ent $m >actual &&
	test_cmp actual expect
'

test_expect_success 'set up for querying the reflog' '
	shit update-ref -d $m &&
	test-tool ref-store main delete-reflog $m &&

	shit_COMMITTER_DATE="1117150320 -0500" shit update-ref $m $C &&
	shit_COMMITTER_DATE="1117150350 -0500" shit update-ref $m $A &&
	shit_COMMITTER_DATE="1117150380 -0500" shit update-ref $m $B &&
	shit_COMMITTER_DATE="1117150680 -0500" shit update-ref $m $F &&
	shit_COMMITTER_DATE="1117150980 -0500" shit update-ref $m $E &&
	shit update-ref $m $D &&
	# Delete the last reflog entry so that the tip of m and the reflog for
	# it disagree.
	shit reflog delete $m@{0} &&

	cat >expect <<-EOF &&
	$Z $C $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> 1117150320 -0500
	$C $A $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> 1117150350 -0500
	$A $B $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> 1117150380 -0500
	$B $F $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> 1117150680 -0500
	$F $E $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> 1117150980 -0500
	EOF
	test-tool ref-store main for-each-reflog-ent $m >actual &&
	test_cmp expect actual
'

ed="Thu, 26 May 2005 18:32:00 -0500"
gd="Thu, 26 May 2005 18:33:00 -0500"
ld="Thu, 26 May 2005 18:43:00 -0500"
test_expect_success 'Query "main@{May 25 2005}" (before history)' '
	test_when_finished "rm -f o e" &&
	shit rev-parse --verify "main@{May 25 2005}" >o 2>e &&
	echo "$C" >expect &&
	test_cmp expect o &&
	echo "warning: log for '\''main'\'' only goes back to $ed" >expect &&
	test_cmp expect e
'
test_expect_success 'Query main@{2005-05-25} (before history)' '
	test_when_finished "rm -f o e" &&
	shit rev-parse --verify main@{2005-05-25} >o 2>e &&
	echo "$C" >expect &&
	test_cmp expect o &&
	echo "warning: log for '\''main'\'' only goes back to $ed" >expect &&
	test_cmp expect e
'
test_expect_success 'Query "main@{May 26 2005 23:31:59}" (1 second before history)' '
	test_when_finished "rm -f o e" &&
	shit rev-parse --verify "main@{May 26 2005 23:31:59}" >o 2>e &&
	echo "$C" >expect &&
	test_cmp expect o &&
	echo "warning: log for '\''main'\'' only goes back to $ed" >expect &&
	test_cmp expect e
'
test_expect_success 'Query "main@{May 26 2005 23:32:00}" (exactly history start)' '
	test_when_finished "rm -f o e" &&
	shit rev-parse --verify "main@{May 26 2005 23:32:00}" >o 2>e &&
	echo "$C" >expect &&
	test_cmp expect o &&
	test_must_be_empty e
'
test_expect_success 'Query "main@{May 26 2005 23:32:30}" (first non-creation change)' '
	test_when_finished "rm -f o e" &&
	shit rev-parse --verify "main@{May 26 2005 23:32:30}" >o 2>e &&
	echo "$A" >expect &&
	test_cmp expect o &&
	test_must_be_empty e
'
test_expect_success 'Query "main@{2005-05-26 23:33:01}" (middle of history with gap)' '
	test_when_finished "rm -f o e" &&
	shit rev-parse --verify "main@{2005-05-26 23:33:01}" >o 2>e &&
	echo "$B" >expect &&
	test_cmp expect o
'
test_expect_success 'Query "main@{2005-05-26 23:38:00}" (middle of history)' '
	test_when_finished "rm -f o e" &&
	shit rev-parse --verify "main@{2005-05-26 23:38:00}" >o 2>e &&
	echo "$F" >expect &&
	test_cmp expect o &&
	test_must_be_empty e
'
test_expect_success 'Query "main@{2005-05-26 23:43:00}" (exact end of history)' '
	test_when_finished "rm -f o e" &&
	shit rev-parse --verify "main@{2005-05-26 23:43:00}" >o 2>e &&
	echo "$E" >expect &&
	test_cmp expect o &&
	test_must_be_empty e
'
test_expect_success 'Query "main@{2005-05-28}" (past end of history)' '
	test_when_finished "rm -f o e" &&
	shit rev-parse --verify "main@{2005-05-28}" >o 2>e &&
	echo "$D" >expect &&
	test_cmp expect o &&
	test_grep -F "warning: log for ref $m unexpectedly ended on $ld" e
'

rm -f expect
shit update-ref -d $m

test_expect_success 'query reflog with gap' '
	test_when_finished "shit update-ref -d $m" &&

	shit_COMMITTER_DATE="1117150320 -0500" shit update-ref $m $A &&
	shit_COMMITTER_DATE="1117150380 -0500" shit update-ref $m $B &&
	shit_COMMITTER_DATE="1117150480 -0500" shit update-ref $m $C &&
	shit_COMMITTER_DATE="1117150580 -0500" shit update-ref $m $D &&
	shit_COMMITTER_DATE="1117150680 -0500" shit update-ref $m $F &&
	shit reflog delete $m@{2} &&

	shit rev-parse --verify "main@{2005-05-26 23:33:01}" >actual 2>stderr &&
	echo "$B" >expect &&
	test_cmp expect actual &&
	test_grep -F "warning: log for ref $m has gap after $gd" stderr
'

test_expect_success 'creating initial files' '
	test_when_finished rm -f M &&
	echo TEST >F &&
	shit add F &&
	shit_AUTHOR_DATE="2005-05-26 23:30" \
	shit_COMMITTER_DATE="2005-05-26 23:30" shit commit -m add -a &&
	h_TEST=$(shit rev-parse --verify HEAD) &&
	echo The other day this did not work. >M &&
	echo And then Bob told me how to fix it. >>M &&
	echo OTHER >F &&
	shit_AUTHOR_DATE="2005-05-26 23:41" \
	shit_COMMITTER_DATE="2005-05-26 23:41" shit commit -F M -a &&
	h_OTHER=$(shit rev-parse --verify HEAD) &&
	shit_AUTHOR_DATE="2005-05-26 23:44" \
	shit_COMMITTER_DATE="2005-05-26 23:44" shit commit --amend &&
	h_FIXED=$(shit rev-parse --verify HEAD) &&
	echo Merged initial commit and a later commit. >M &&
	echo $h_TEST >.shit/MERGE_HEAD &&
	shit_AUTHOR_DATE="2005-05-26 23:45" \
	shit_COMMITTER_DATE="2005-05-26 23:45" shit commit -F M &&
	h_MERGED=$(shit rev-parse --verify HEAD)
'

cat >expect <<EOF
$Z $h_TEST $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> 1117150200 +0000	commit (initial): add
$h_TEST $h_OTHER $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> 1117150860 +0000	commit: The other day this did not work.
$h_OTHER $h_FIXED $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> 1117151040 +0000	commit (amend): The other day this did not work.
$h_FIXED $h_MERGED $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> 1117151100 +0000	commit (merge): Merged initial commit and a later commit.
EOF
test_expect_success 'shit commit logged updates' '
	test-tool ref-store main for-each-reflog-ent $m >actual &&
	test_cmp expect actual
'
unset h_TEST h_OTHER h_FIXED h_MERGED

test_expect_success 'shit cat-file blob main:F (expect OTHER)' '
	test OTHER = $(shit cat-file blob main:F)
'
test_expect_success 'shit cat-file blob main@{2005-05-26 23:30}:F (expect TEST)' '
	test TEST = $(shit cat-file blob "main@{2005-05-26 23:30}:F")
'
test_expect_success 'shit cat-file blob main@{2005-05-26 23:42}:F (expect OTHER)' '
	test OTHER = $(shit cat-file blob "main@{2005-05-26 23:42}:F")
'

# Test adding and deleting pseudorefs

test_expect_success 'given old value for missing pseudoref, do not create' '
	test_must_fail shit update-ref PSEUDOREF $A $B 2>err &&
	test_must_fail shit rev-parse PSEUDOREF &&
	test_grep "unable to resolve reference" err
'

test_expect_success 'create pseudoref' '
	shit update-ref PSEUDOREF $A &&
	test $A = $(shit show-ref -s --verify PSEUDOREF)
'

test_expect_success 'overwrite pseudoref with no old value given' '
	shit update-ref PSEUDOREF $B &&
	test $B = $(shit show-ref -s --verify PSEUDOREF)
'

test_expect_success 'overwrite pseudoref with correct old value' '
	shit update-ref PSEUDOREF $C $B &&
	test $C = $(shit show-ref -s --verify PSEUDOREF)
'

test_expect_success 'do not overwrite pseudoref with wrong old value' '
	test_must_fail shit update-ref PSEUDOREF $D $E 2>err &&
	test $C = $(shit show-ref -s --verify PSEUDOREF) &&
	test_grep "cannot lock ref.*expected" err
'

test_expect_success 'delete pseudoref' '
	shit update-ref -d PSEUDOREF &&
	test_must_fail shit show-ref -s --verify PSEUDOREF
'

test_expect_success 'do not delete pseudoref with wrong old value' '
	shit update-ref PSEUDOREF $A &&
	test_must_fail shit update-ref -d PSEUDOREF $B 2>err &&
	test $A = $(shit show-ref -s --verify PSEUDOREF) &&
	test_grep "cannot lock ref.*expected" err
'

test_expect_success 'delete pseudoref with correct old value' '
	shit update-ref -d PSEUDOREF $A &&
	test_must_fail shit show-ref -s --verify PSEUDOREF
'

test_expect_success 'create pseudoref with old OID zero' '
	shit update-ref PSEUDOREF $A $Z &&
	test $A = $(shit show-ref -s --verify PSEUDOREF)
'

test_expect_success 'do not overwrite pseudoref with old OID zero' '
	test_when_finished shit update-ref -d PSEUDOREF &&
	test_must_fail shit update-ref PSEUDOREF $B $Z 2>err &&
	test $A = $(shit show-ref -s --verify PSEUDOREF) &&
	test_grep "already exists" err
'

# Test --stdin

a=refs/heads/a
b=refs/heads/b
c=refs/heads/c
E='""'
F='%s\0'
pws='path with space'

test_expect_success 'stdin test setup' '
	echo "$pws" >"$pws" &&
	shit add -- "$pws" &&
	shit commit -m "$pws"
'

test_expect_success '-z fails without --stdin' '
	test_must_fail shit update-ref -z $m $m $m 2>err &&
	test_grep "usage: shit update-ref" err
'

test_expect_success 'stdin works with no input' '
	>stdin &&
	shit update-ref --stdin <stdin &&
	shit rev-parse --verify -q $m
'

test_expect_success 'stdin fails on empty line' '
	echo "" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: empty command in input" err
'

test_expect_success 'stdin fails on only whitespace' '
	echo " " >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: whitespace before command:  " err
'

test_expect_success 'stdin fails on leading whitespace' '
	echo " create $a $m" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: whitespace before command:  create $a $m" err
'

test_expect_success 'stdin fails on unknown command' '
	echo "unknown $a" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: unknown command: unknown $a" err
'

test_expect_success 'stdin fails on unbalanced quotes' '
	echo "create $a \"main" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: badly quoted argument: \\\"main" err
'

test_expect_success 'stdin fails on invalid escape' '
	echo "create $a \"ma\zn\"" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: badly quoted argument: \\\"ma\\\\zn\\\"" err
'

test_expect_success 'stdin fails on junk after quoted argument' '
	echo "create \"$a\"main" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: unexpected character after quoted argument: \\\"$a\\\"main" err
'

test_expect_success 'stdin fails create with no ref' '
	echo "create " >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: create: missing <ref>" err
'

test_expect_success 'stdin fails create with no new value' '
	echo "create $a" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: create $a: missing <new-oid>" err
'

test_expect_success 'stdin fails create with too many arguments' '
	echo "create $a $m $m" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: create $a: extra input:  $m" err
'

test_expect_success 'stdin fails update with no ref' '
	echo "update " >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: update: missing <ref>" err
'

test_expect_success 'stdin fails update with no new value' '
	echo "update $a" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: update $a: missing <new-oid>" err
'

test_expect_success 'stdin fails update with too many arguments' '
	echo "update $a $m $m $m" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: update $a: extra input:  $m" err
'

test_expect_success 'stdin fails delete with no ref' '
	echo "delete " >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: delete: missing <ref>" err
'

test_expect_success 'stdin fails delete with too many arguments' '
	echo "delete $a $m $m" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: delete $a: extra input:  $m" err
'

test_expect_success 'stdin fails verify with too many arguments' '
	echo "verify $a $m $m" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: verify $a: extra input:  $m" err
'

test_expect_success 'stdin fails option with unknown name' '
	echo "option unknown" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: option unknown: unknown" err
'

test_expect_success 'stdin fails with duplicate refs' '
	cat >stdin <<-EOF &&
	create $a $m
	create $b $m
	create $a $m
	EOF
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	test_grep "fatal: multiple updates for ref '"'"'$a'"'"' not allowed" err
'

test_expect_success 'stdin create ref works' '
	echo "create $a $m" >stdin &&
	shit update-ref --stdin <stdin &&
	shit rev-parse $m >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin does not create reflogs by default' '
	test_when_finished "shit update-ref -d $outside" &&
	echo "create $outside $m" >stdin &&
	shit update-ref --stdin <stdin &&
	shit rev-parse $m >expect &&
	shit rev-parse $outside >actual &&
	test_cmp expect actual &&
	test_must_fail shit reflog exists $outside
'

test_expect_success 'stdin creates reflogs with --create-reflog' '
	test_when_finished "shit update-ref -d $outside" &&
	echo "create $outside $m" >stdin &&
	shit update-ref --create-reflog --stdin <stdin &&
	shit rev-parse $m >expect &&
	shit rev-parse $outside >actual &&
	test_cmp expect actual &&
	shit reflog exists $outside
'

test_expect_success 'stdin succeeds with quoted argument' '
	shit update-ref -d $a &&
	echo "create $a \"$m\"" >stdin &&
	shit update-ref --stdin <stdin &&
	shit rev-parse $m >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin succeeds with escaped character' '
	shit update-ref -d $a &&
	echo "create $a \"ma\\151n\"" >stdin &&
	shit update-ref --stdin <stdin &&
	shit rev-parse $m >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin update ref creates with zero old value' '
	echo "update $b $m $Z" >stdin &&
	shit update-ref --stdin <stdin &&
	shit rev-parse $m >expect &&
	shit rev-parse $b >actual &&
	test_cmp expect actual &&
	shit update-ref -d $b
'

test_expect_success 'stdin update ref creates with empty old value' '
	echo "update $b $m $E" >stdin &&
	shit update-ref --stdin <stdin &&
	shit rev-parse $m >expect &&
	shit rev-parse $b >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin create ref works with path with space to blob' '
	echo "create refs/blobs/pws \"$m:$pws\"" >stdin &&
	shit update-ref --stdin <stdin &&
	shit rev-parse "$m:$pws" >expect &&
	shit rev-parse refs/blobs/pws >actual &&
	test_cmp expect actual &&
	shit update-ref -d refs/blobs/pws
'

test_expect_success 'stdin update ref fails with wrong old value' '
	echo "update $c $m $m~1" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: cannot lock ref '"'"'$c'"'"'" err &&
	test_must_fail shit rev-parse --verify -q $c
'

test_expect_success 'stdin update ref fails with bad old value' '
	echo "update $c $m does-not-exist" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: update $c: invalid <old-oid>: does-not-exist" err &&
	test_must_fail shit rev-parse --verify -q $c
'

test_expect_success 'stdin create ref fails with bad new value' '
	echo "create $c does-not-exist" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: create $c: invalid <new-oid>: does-not-exist" err &&
	test_must_fail shit rev-parse --verify -q $c
'

test_expect_success 'stdin create ref fails with zero new value' '
	echo "create $c " >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: create $c: zero <new-oid>" err &&
	test_must_fail shit rev-parse --verify -q $c
'

test_expect_success 'stdin update ref works with right old value' '
	echo "update $b $m~1 $m" >stdin &&
	shit update-ref --stdin <stdin &&
	shit rev-parse $m~1 >expect &&
	shit rev-parse $b >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin delete ref fails with wrong old value' '
	echo "delete $a $m~1" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: cannot lock ref '"'"'$a'"'"'" err &&
	shit rev-parse $m >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin delete ref fails with zero old value' '
	echo "delete $a " >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: delete $a: zero <old-oid>" err &&
	shit rev-parse $m >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin update symref works option no-deref' '
	shit symbolic-ref TESTSYMREF $b &&
	cat >stdin <<-EOF &&
	option no-deref
	update TESTSYMREF $a $b
	EOF
	shit update-ref --stdin <stdin &&
	shit rev-parse TESTSYMREF >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual &&
	shit rev-parse $m~1 >expect &&
	shit rev-parse $b >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin delete symref works option no-deref' '
	shit symbolic-ref TESTSYMREF $b &&
	cat >stdin <<-EOF &&
	option no-deref
	delete TESTSYMREF $b
	EOF
	shit update-ref --stdin <stdin &&
	test_must_fail shit rev-parse --verify -q TESTSYMREF &&
	shit rev-parse $m~1 >expect &&
	shit rev-parse $b >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin update symref works flag --no-deref' '
	shit symbolic-ref TESTSYMREFONE $b &&
	shit symbolic-ref TESTSYMREFTWO $b &&
	cat >stdin <<-EOF &&
	update TESTSYMREFONE $a $b
	update TESTSYMREFTWO $a $b
	EOF
	shit update-ref --no-deref --stdin <stdin &&
	shit rev-parse TESTSYMREFONE TESTSYMREFTWO >expect &&
	shit rev-parse $a $a >actual &&
	test_cmp expect actual &&
	shit rev-parse $m~1 >expect &&
	shit rev-parse $b >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin delete symref works flag --no-deref' '
	shit symbolic-ref TESTSYMREFONE $b &&
	shit symbolic-ref TESTSYMREFTWO $b &&
	cat >stdin <<-EOF &&
	delete TESTSYMREFONE $b
	delete TESTSYMREFTWO $b
	EOF
	shit update-ref --no-deref --stdin <stdin &&
	test_must_fail shit rev-parse --verify -q TESTSYMREFONE &&
	test_must_fail shit rev-parse --verify -q TESTSYMREFTWO &&
	shit rev-parse $m~1 >expect &&
	shit rev-parse $b >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin delete ref works with right old value' '
	echo "delete $b $m~1" >stdin &&
	shit update-ref --stdin <stdin &&
	test_must_fail shit rev-parse --verify -q $b
'

test_expect_success 'stdin update/create/verify combination works' '
	cat >stdin <<-EOF &&
	update $a $m
	create $b $m
	verify $c
	EOF
	shit update-ref --stdin <stdin &&
	shit rev-parse $m >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual &&
	shit rev-parse $b >actual &&
	test_cmp expect actual &&
	test_must_fail shit rev-parse --verify -q $c
'

test_expect_success 'stdin verify succeeds for correct value' '
	shit rev-parse $m >expect &&
	echo "verify $m $m" >stdin &&
	shit update-ref --stdin <stdin &&
	shit rev-parse $m >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin verify succeeds for missing reference' '
	echo "verify refs/heads/missing $Z" >stdin &&
	shit update-ref --stdin <stdin &&
	test_must_fail shit rev-parse --verify -q refs/heads/missing
'

test_expect_success 'stdin verify treats no value as missing' '
	echo "verify refs/heads/missing" >stdin &&
	shit update-ref --stdin <stdin &&
	test_must_fail shit rev-parse --verify -q refs/heads/missing
'

test_expect_success 'stdin verify fails for wrong value' '
	shit rev-parse $m >expect &&
	echo "verify $m $m~1" >stdin &&
	test_must_fail shit update-ref --stdin <stdin &&
	shit rev-parse $m >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin verify fails for mistaken null value' '
	shit rev-parse $m >expect &&
	echo "verify $m $Z" >stdin &&
	test_must_fail shit update-ref --stdin <stdin &&
	shit rev-parse $m >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin verify fails for mistaken empty value' '
	M=$(shit rev-parse $m) &&
	test_when_finished "shit update-ref $m $M" &&
	shit rev-parse $m >expect &&
	echo "verify $m" >stdin &&
	test_must_fail shit update-ref --stdin <stdin &&
	shit rev-parse $m >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin update refs works with identity updates' '
	cat >stdin <<-EOF &&
	update $a $m $m
	update $b $m $m
	update $c $Z $E
	EOF
	shit update-ref --stdin <stdin &&
	shit rev-parse $m >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual &&
	shit rev-parse $b >actual &&
	test_cmp expect actual &&
	test_must_fail shit rev-parse --verify -q $c
'

test_expect_success 'stdin update refs fails with wrong old value' '
	shit update-ref $c $m &&
	cat >stdin <<-EOF &&
	update $a $m $m
	update $b $m $m
	update $c  ''
	EOF
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: cannot lock ref '"'"'$c'"'"'" err &&
	shit rev-parse $m >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual &&
	shit rev-parse $b >actual &&
	test_cmp expect actual &&
	shit rev-parse $c >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin delete refs works with packed and loose refs' '
	shit pack-refs --all &&
	shit update-ref $c $m~1 &&
	cat >stdin <<-EOF &&
	delete $a $m
	update $b $Z $m
	update $c $E $m~1
	EOF
	shit update-ref --stdin <stdin &&
	test_must_fail shit rev-parse --verify -q $a &&
	test_must_fail shit rev-parse --verify -q $b &&
	test_must_fail shit rev-parse --verify -q $c
'

test_expect_success 'stdin -z works on empty input' '
	>stdin &&
	shit update-ref -z --stdin <stdin &&
	shit rev-parse --verify -q $m
'

test_expect_success 'stdin -z fails on empty line' '
	echo "" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: whitespace before command: " err
'

test_expect_success 'stdin -z fails on empty command' '
	printf $F "" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: empty command in input" err
'

test_expect_success 'stdin -z fails on only whitespace' '
	printf $F " " >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: whitespace before command:  " err
'

test_expect_success 'stdin -z fails on leading whitespace' '
	printf $F " create $a" "$m" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: whitespace before command:  create $a" err
'

test_expect_success 'stdin -z fails on unknown command' '
	printf $F "unknown $a" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: unknown command: unknown $a" err
'

test_expect_success 'stdin -z fails create with no ref' '
	printf $F "create " >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: create: missing <ref>" err
'

test_expect_success 'stdin -z fails create with no new value' '
	printf $F "create $a" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: create $a: unexpected end of input when reading <new-oid>" err
'

test_expect_success 'stdin -z fails create with too many arguments' '
	printf $F "create $a" "$m" "$m" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: unknown command: $m" err
'

test_expect_success 'stdin -z fails update with no ref' '
	printf $F "update " >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: update: missing <ref>" err
'

test_expect_success 'stdin -z fails update with too few args' '
	printf $F "update $a" "$m" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: update $a: unexpected end of input when reading <old-oid>" err
'

test_expect_success 'stdin -z emits warning with empty new value' '
	shit update-ref $a $m &&
	printf $F "update $a" "" "" >stdin &&
	shit update-ref -z --stdin <stdin 2>err &&
	grep "warning: update $a: missing <new-oid>, treating as zero" err &&
	test_must_fail shit rev-parse --verify -q $a
'

test_expect_success 'stdin -z fails update with no new value' '
	printf $F "update $a" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: update $a: unexpected end of input when reading <new-oid>" err
'

test_expect_success 'stdin -z fails update with no old value' '
	printf $F "update $a" "$m" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: update $a: unexpected end of input when reading <old-oid>" err
'

test_expect_success 'stdin -z fails update with too many arguments' '
	printf $F "update $a" "$m" "$m" "$m" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: unknown command: $m" err
'

test_expect_success 'stdin -z fails delete with no ref' '
	printf $F "delete " >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: delete: missing <ref>" err
'

test_expect_success 'stdin -z fails delete with no old value' '
	printf $F "delete $a" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: delete $a: unexpected end of input when reading <old-oid>" err
'

test_expect_success 'stdin -z fails delete with too many arguments' '
	printf $F "delete $a" "$m" "$m" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: unknown command: $m" err
'

test_expect_success 'stdin -z fails verify with too many arguments' '
	printf $F "verify $a" "$m" "$m" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: unknown command: $m" err
'

test_expect_success 'stdin -z fails verify with no old value' '
	printf $F "verify $a" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: verify $a: unexpected end of input when reading <old-oid>" err
'

test_expect_success 'stdin -z fails option with unknown name' '
	printf $F "option unknown" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: option unknown: unknown" err
'

test_expect_success 'stdin -z fails with duplicate refs' '
	printf $F "create $a" "$m" "create $b" "$m" "create $a" "$m" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	test_grep "fatal: multiple updates for ref '"'"'$a'"'"' not allowed" err
'

test_expect_success 'stdin -z create ref works' '
	printf $F "create $a" "$m" >stdin &&
	shit update-ref -z --stdin <stdin &&
	shit rev-parse $m >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin -z update ref creates with zero old value' '
	printf $F "update $b" "$m" "$Z" >stdin &&
	shit update-ref -z --stdin <stdin &&
	shit rev-parse $m >expect &&
	shit rev-parse $b >actual &&
	test_cmp expect actual &&
	shit update-ref -d $b
'

test_expect_success 'stdin -z update ref creates with empty old value' '
	printf $F "update $b" "$m" "" >stdin &&
	shit update-ref -z --stdin <stdin &&
	shit rev-parse $m >expect &&
	shit rev-parse $b >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin -z create ref works with path with space to blob' '
	printf $F "create refs/blobs/pws" "$m:$pws" >stdin &&
	shit update-ref -z --stdin <stdin &&
	shit rev-parse "$m:$pws" >expect &&
	shit rev-parse refs/blobs/pws >actual &&
	test_cmp expect actual &&
	shit update-ref -d refs/blobs/pws
'

test_expect_success 'stdin -z update ref fails with wrong old value' '
	printf $F "update $c" "$m" "$m~1" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: cannot lock ref '"'"'$c'"'"'" err &&
	test_must_fail shit rev-parse --verify -q $c
'

test_expect_success 'stdin -z update ref fails with bad old value' '
	printf $F "update $c" "$m" "does-not-exist" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: update $c: invalid <old-oid>: does-not-exist" err &&
	test_must_fail shit rev-parse --verify -q $c
'

test_expect_success 'stdin -z create ref fails when ref exists' '
	shit update-ref $c $m &&
	shit rev-parse "$c" >expect &&
	printf $F "create $c" "$m~1" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: cannot lock ref '"'"'$c'"'"'" err &&
	shit rev-parse "$c" >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin -z create ref fails with bad new value' '
	shit update-ref -d "$c" &&
	printf $F "create $c" "does-not-exist" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: create $c: invalid <new-oid>: does-not-exist" err &&
	test_must_fail shit rev-parse --verify -q $c
'

test_expect_success 'stdin -z create ref fails with empty new value' '
	printf $F "create $c" "" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: create $c: missing <new-oid>" err &&
	test_must_fail shit rev-parse --verify -q $c
'

test_expect_success 'stdin -z update ref works with right old value' '
	printf $F "update $b" "$m~1" "$m" >stdin &&
	shit update-ref -z --stdin <stdin &&
	shit rev-parse $m~1 >expect &&
	shit rev-parse $b >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin -z delete ref fails with wrong old value' '
	printf $F "delete $a" "$m~1" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: cannot lock ref '"'"'$a'"'"'" err &&
	shit rev-parse $m >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin -z delete ref fails with zero old value' '
	printf $F "delete $a" "$Z" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: delete $a: zero <old-oid>" err &&
	shit rev-parse $m >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin -z update symref works option no-deref' '
	shit symbolic-ref TESTSYMREF $b &&
	printf $F "option no-deref" "update TESTSYMREF" "$a" "$b" >stdin &&
	shit update-ref -z --stdin <stdin &&
	shit rev-parse TESTSYMREF >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual &&
	shit rev-parse $m~1 >expect &&
	shit rev-parse $b >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin -z delete symref works option no-deref' '
	shit symbolic-ref TESTSYMREF $b &&
	printf $F "option no-deref" "delete TESTSYMREF" "$b" >stdin &&
	shit update-ref -z --stdin <stdin &&
	test_must_fail shit rev-parse --verify -q TESTSYMREF &&
	shit rev-parse $m~1 >expect &&
	shit rev-parse $b >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin -z delete ref works with right old value' '
	printf $F "delete $b" "$m~1" >stdin &&
	shit update-ref -z --stdin <stdin &&
	test_must_fail shit rev-parse --verify -q $b
'

test_expect_success 'stdin -z update/create/verify combination works' '
	printf $F "update $a" "$m" "" "create $b" "$m" "verify $c" "" >stdin &&
	shit update-ref -z --stdin <stdin &&
	shit rev-parse $m >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual &&
	shit rev-parse $b >actual &&
	test_cmp expect actual &&
	test_must_fail shit rev-parse --verify -q $c
'

test_expect_success 'stdin -z verify succeeds for correct value' '
	shit rev-parse $m >expect &&
	printf $F "verify $m" "$m" >stdin &&
	shit update-ref -z --stdin <stdin &&
	shit rev-parse $m >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin -z verify succeeds for missing reference' '
	printf $F "verify refs/heads/missing" "$Z" >stdin &&
	shit update-ref -z --stdin <stdin &&
	test_must_fail shit rev-parse --verify -q refs/heads/missing
'

test_expect_success 'stdin -z verify treats no value as missing' '
	printf $F "verify refs/heads/missing" "" >stdin &&
	shit update-ref -z --stdin <stdin &&
	test_must_fail shit rev-parse --verify -q refs/heads/missing
'

test_expect_success 'stdin -z verify fails for wrong value' '
	shit rev-parse $m >expect &&
	printf $F "verify $m" "$m~1" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin &&
	shit rev-parse $m >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin -z verify fails for mistaken null value' '
	shit rev-parse $m >expect &&
	printf $F "verify $m" "$Z" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin &&
	shit rev-parse $m >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin -z verify fails for mistaken empty value' '
	M=$(shit rev-parse $m) &&
	test_when_finished "shit update-ref $m $M" &&
	shit rev-parse $m >expect &&
	printf $F "verify $m" "" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin &&
	shit rev-parse $m >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin -z update refs works with identity updates' '
	printf $F "update $a" "$m" "$m" "update $b" "$m" "$m" "update $c" "$Z" "" >stdin &&
	shit update-ref -z --stdin <stdin &&
	shit rev-parse $m >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual &&
	shit rev-parse $b >actual &&
	test_cmp expect actual &&
	test_must_fail shit rev-parse --verify -q $c
'

test_expect_success 'stdin -z update refs fails with wrong old value' '
	shit update-ref $c $m &&
	printf $F "update $a" "$m" "$m" "update $b" "$m" "$m" "update $c" "$m" "$Z" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: cannot lock ref '"'"'$c'"'"'" err &&
	shit rev-parse $m >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual &&
	shit rev-parse $b >actual &&
	test_cmp expect actual &&
	shit rev-parse $c >actual &&
	test_cmp expect actual
'

test_expect_success 'stdin -z delete refs works with packed and loose refs' '
	shit pack-refs --all &&
	shit update-ref $c $m~1 &&
	printf $F "delete $a" "$m" "update $b" "$Z" "$m" "update $c" "" "$m~1" >stdin &&
	shit update-ref -z --stdin <stdin &&
	test_must_fail shit rev-parse --verify -q $a &&
	test_must_fail shit rev-parse --verify -q $b &&
	test_must_fail shit rev-parse --verify -q $c
'

test_expect_success 'fails with duplicate HEAD update' '
	shit branch target1 $A &&
	shit checkout target1 &&
	cat >stdin <<-EOF &&
	update refs/heads/target1 $C
	option no-deref
	update HEAD $B
	EOF
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	test_grep "fatal: multiple updates for '\''HEAD'\'' (including one via its referent .refs/heads/target1.) are not allowed" err &&
	echo "refs/heads/target1" >expect &&
	shit symbolic-ref HEAD >actual &&
	test_cmp expect actual &&
	echo "$A" >expect &&
	shit rev-parse refs/heads/target1 >actual &&
	test_cmp expect actual
'

test_expect_success 'fails with duplicate ref update via symref' '
	shit branch target2 $A &&
	shit symbolic-ref refs/heads/symref2 refs/heads/target2 &&
	cat >stdin <<-EOF &&
	update refs/heads/target2 $C
	update refs/heads/symref2 $B
	EOF
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	test_grep "fatal: multiple updates for '\''refs/heads/target2'\'' (including one via symref .refs/heads/symref2.) are not allowed" err &&
	echo "refs/heads/target2" >expect &&
	shit symbolic-ref refs/heads/symref2 >actual &&
	test_cmp expect actual &&
	echo "$A" >expect &&
	shit rev-parse refs/heads/target2 >actual &&
	test_cmp expect actual
'

test_expect_success ULIMIT_FILE_DESCRIPTORS 'large transaction creating branches does not burst open file limit' '
(
	for i in $(test_seq 33)
	do
		echo "create refs/heads/$i HEAD" || exit 1
	done >large_input &&
	run_with_limited_open_files shit update-ref --stdin <large_input &&
	shit rev-parse --verify -q refs/heads/33
)
'

test_expect_success ULIMIT_FILE_DESCRIPTORS 'large transaction deleting branches does not burst open file limit' '
(
	for i in $(test_seq 33)
	do
		echo "delete refs/heads/$i HEAD" || exit 1
	done >large_input &&
	run_with_limited_open_files shit update-ref --stdin <large_input &&
	test_must_fail shit rev-parse --verify -q refs/heads/33
)
'

test_expect_success 'handle per-worktree refs in refs/bisect' '
	shit commit --allow-empty -m "initial commit" &&
	shit worktree add -b branch worktree &&
	(
		cd worktree &&
		shit commit --allow-empty -m "test commit"  &&
		shit for-each-ref >for-each-ref.out &&
		! grep refs/bisect for-each-ref.out &&
		shit update-ref refs/bisect/something HEAD &&
		shit rev-parse refs/bisect/something >../worktree-head &&
		shit for-each-ref | grep refs/bisect/something
	) &&
	shit show-ref >actual &&
	! grep 'refs/bisect' actual &&
	test_must_fail shit rev-parse refs/bisect/something &&
	shit update-ref refs/bisect/something HEAD &&
	shit rev-parse refs/bisect/something >main-head &&
	! test_cmp main-head worktree-head
'

test_expect_success 'transaction handles empty commit' '
	cat >stdin <<-EOF &&
	start
	prepare
	commit
	EOF
	shit update-ref --stdin <stdin >actual &&
	printf "%s: ok\n" start prepare commit >expect &&
	test_cmp expect actual
'

test_expect_success 'transaction handles empty commit with missing prepare' '
	cat >stdin <<-EOF &&
	start
	commit
	EOF
	shit update-ref --stdin <stdin >actual &&
	printf "%s: ok\n" start commit >expect &&
	test_cmp expect actual
'

test_expect_success 'transaction handles sole commit' '
	cat >stdin <<-EOF &&
	commit
	EOF
	shit update-ref --stdin <stdin >actual &&
	printf "%s: ok\n" commit >expect &&
	test_cmp expect actual
'

test_expect_success 'transaction handles empty abort' '
	cat >stdin <<-EOF &&
	start
	prepare
	abort
	EOF
	shit update-ref --stdin <stdin >actual &&
	printf "%s: ok\n" start prepare abort >expect &&
	test_cmp expect actual
'

test_expect_success 'transaction exits on multiple aborts' '
	cat >stdin <<-EOF &&
	abort
	abort
	EOF
	test_must_fail shit update-ref --stdin <stdin >actual 2>err &&
	printf "%s: ok\n" abort >expect &&
	test_cmp expect actual &&
	grep "fatal: transaction is closed" err
'

test_expect_success 'transaction exits on start after prepare' '
	cat >stdin <<-EOF &&
	prepare
	start
	EOF
	test_must_fail shit update-ref --stdin <stdin 2>err >actual &&
	printf "%s: ok\n" prepare >expect &&
	test_cmp expect actual &&
	grep "fatal: prepared transactions can only be closed" err
'

test_expect_success 'transaction handles empty abort with missing prepare' '
	cat >stdin <<-EOF &&
	start
	abort
	EOF
	shit update-ref --stdin <stdin >actual &&
	printf "%s: ok\n" start abort >expect &&
	test_cmp expect actual
'

test_expect_success 'transaction handles sole abort' '
	cat >stdin <<-EOF &&
	abort
	EOF
	shit update-ref --stdin <stdin >actual &&
	printf "%s: ok\n" abort >expect &&
	test_cmp expect actual
'

test_expect_success 'transaction can handle commit' '
	cat >stdin <<-EOF &&
	start
	create $a HEAD
	commit
	EOF
	shit update-ref --stdin <stdin >actual &&
	printf "%s: ok\n" start commit >expect &&
	test_cmp expect actual &&
	shit rev-parse HEAD >expect &&
	shit rev-parse $a >actual &&
	test_cmp expect actual
'

test_expect_success 'transaction can handle abort' '
	cat >stdin <<-EOF &&
	start
	create $b HEAD
	abort
	EOF
	shit update-ref --stdin <stdin >actual &&
	printf "%s: ok\n" start abort >expect &&
	test_cmp expect actual &&
	test_must_fail shit show-ref --verify -q $b
'

test_expect_success 'transaction aborts by default' '
	cat >stdin <<-EOF &&
	start
	create $b HEAD
	EOF
	shit update-ref --stdin <stdin >actual &&
	printf "%s: ok\n" start >expect &&
	test_cmp expect actual &&
	test_must_fail shit show-ref --verify -q $b
'

test_expect_success 'transaction with prepare aborts by default' '
	cat >stdin <<-EOF &&
	start
	create $b HEAD
	prepare
	EOF
	shit update-ref --stdin <stdin >actual &&
	printf "%s: ok\n" start prepare >expect &&
	test_cmp expect actual &&
	test_must_fail shit show-ref --verify -q $b
'

test_expect_success 'transaction can commit multiple times' '
	cat >stdin <<-EOF &&
	start
	create refs/heads/branch-1 $A
	commit
	start
	create refs/heads/branch-2 $B
	commit
	EOF
	shit update-ref --stdin <stdin >actual &&
	printf "%s: ok\n" start commit start commit >expect &&
	test_cmp expect actual &&
	echo "$A" >expect &&
	shit rev-parse refs/heads/branch-1 >actual &&
	test_cmp expect actual &&
	echo "$B" >expect &&
	shit rev-parse refs/heads/branch-2 >actual &&
	test_cmp expect actual
'

test_expect_success 'transaction can create and delete' '
	cat >stdin <<-EOF &&
	start
	create refs/heads/create-and-delete $A
	commit
	start
	delete refs/heads/create-and-delete $A
	commit
	EOF
	shit update-ref --stdin <stdin >actual &&
	printf "%s: ok\n" start commit start commit >expect &&
	test_cmp expect actual &&
	test_must_fail shit show-ref --verify refs/heads/create-and-delete
'

test_expect_success 'transaction can commit after abort' '
	cat >stdin <<-EOF &&
	start
	create refs/heads/abort $A
	abort
	start
	create refs/heads/abort $A
	commit
	EOF
	shit update-ref --stdin <stdin >actual &&
	printf "%s: ok\n" start abort start commit >expect &&
	echo "$A" >expect &&
	shit rev-parse refs/heads/abort >actual &&
	test_cmp expect actual
'

test_expect_success 'transaction cannot restart ongoing transaction' '
	cat >stdin <<-EOF &&
	start
	create refs/heads/restart $A
	start
	commit
	EOF
	test_must_fail shit update-ref --stdin <stdin >actual &&
	printf "%s: ok\n" start >expect &&
	test_cmp expect actual &&
	test_must_fail shit show-ref --verify refs/heads/restart
'

test_expect_success PIPE 'transaction flushes status updates' '
	mkfifo in out &&
	(shit update-ref --stdin <in >out &) &&

	exec 9>in &&
	exec 8<out &&
	test_when_finished "exec 9>&-" &&
	test_when_finished "exec 8<&-" &&

	echo "start" >&9 &&
	echo "start: ok" >expected &&
	read line <&8 &&
	echo "$line" >actual &&
	test_cmp expected actual &&

	echo "create refs/heads/flush $A" >&9 &&

	echo prepare >&9 &&
	echo "prepare: ok" >expected &&
	read line <&8 &&
	echo "$line" >actual &&
	test_cmp expected actual &&

	# This must now fail given that we have locked the ref.
	test_must_fail shit update-ref refs/heads/flush $B 2>stderr &&
	grep "fatal: update_ref failed for ref ${SQ}refs/heads/flush${SQ}: cannot lock ref" stderr &&

	echo commit >&9 &&
	echo "commit: ok" >expected &&
	read line <&8 &&
	echo "$line" >actual &&
	test_cmp expected actual
'

test_done
