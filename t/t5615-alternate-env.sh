#!/bin/sh

test_description='handling of alternates in environment variables'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

check_obj () {
	alt=$1; shift
	while read obj expect
	do
		echo "$obj" >&5 &&
		echo "$obj $expect" >&6
	done 5>input 6>expect &&
	shit_ALTERNATE_OBJECT_DIRECTORIES=$alt \
		shit "$@" cat-file --batch-check='%(objectname) %(objecttype)' \
		<input >actual &&
	test_cmp expect actual
}

test_expect_success 'create alternate repositories' '
	shit init --bare one.shit &&
	one=$(echo one | shit -C one.shit hash-object -w --stdin) &&
	shit init --bare two.shit &&
	two=$(echo two | shit -C two.shit hash-object -w --stdin)
'

test_expect_success 'objects inaccessible without alternates' '
	check_obj "" <<-EOF
	$one missing
	$two missing
	EOF
'

test_expect_success 'access alternate via absolute path' '
	check_obj "$PWD/one.shit/objects" <<-EOF
	$one blob
	$two missing
	EOF
'

test_expect_success 'access multiple alternates' '
	check_obj "$PWD/one.shit/objects:$PWD/two.shit/objects" <<-EOF
	$one blob
	$two blob
	EOF
'

# bare paths are relative from $shit_DIR
test_expect_success 'access alternate via relative path (bare)' '
	shit init --bare bare.shit &&
	check_obj "../one.shit/objects" -C bare.shit <<-EOF
	$one blob
	EOF
'

# non-bare paths are relative to top of worktree
test_expect_success 'access alternate via relative path (worktree)' '
	shit init worktree &&
	check_obj "../one.shit/objects" -C worktree <<-EOF
	$one blob
	EOF
'

# path is computed after moving to top-level of worktree
test_expect_success 'access alternate via relative path (subdir)' '
	mkdir subdir &&
	check_obj "one.shit/objects" -C subdir <<-EOF
	$one blob
	EOF
'

# set variables outside test to avoid quote insanity; the \057 is '/',
# which doesn't need quoting, but just confirms that de-quoting
# is working.
quoted='"one.shit\057objects"'
unquoted='two.shit/objects'
test_expect_success 'mix of quoted and unquoted alternates' '
	check_obj "$quoted:$unquoted" <<-EOF
	$one blob
	$two blob
	EOF
'

test_expect_success !MINGW 'broken quoting falls back to interpreting raw' '
	mv one.shit \"one.shit &&
	check_obj \"one.shit/objects <<-EOF
	$one blob
	EOF
'

test_done
