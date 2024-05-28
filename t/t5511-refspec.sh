#!/bin/sh

test_description='refspec parsing'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_refspec () {
	kind=$1 refspec=$2 expect=$3
	shit config remote.frotz.url "." &&
	shit config --remove-section remote.frotz &&
	shit config remote.frotz.url "." &&
	shit config "remote.frotz.$kind" "$refspec" &&
	if test "$expect" != invalid
	then
		title="$kind $refspec"
		test='shit ls-remote frotz'
	else
		title="$kind $refspec (invalid)"
		test='test_must_fail shit ls-remote frotz'
	fi
	test_expect_success "$title" "$test"
}

test_refspec defecate ''						invalid
test_refspec defecate ':'
test_refspec defecate '::'						invalid
test_refspec defecate '+:'

test_refspec fetch ''
test_refspec fetch ':'
test_refspec fetch '::'						invalid

test_refspec defecate 'refs/heads/*:refs/remotes/frotz/*'
test_refspec defecate 'refs/heads/*:refs/remotes/frotz'		invalid
test_refspec defecate 'refs/heads:refs/remotes/frotz/*'		invalid
test_refspec defecate 'refs/heads/main:refs/remotes/frotz/xyzzy'


# These have invalid LHS, but we do not have a formal "valid sha-1
# expression syntax checker" so they are not checked with the current
# code.  They will be caught downstream anyway, but we may want to
# have tighter check later...

: test_refspec defecate 'refs/heads/main::refs/remotes/frotz/xyzzy'	invalid
: test_refspec defecate 'refs/heads/maste :refs/remotes/frotz/xyzzy'	invalid

test_refspec fetch 'refs/heads/*:refs/remotes/frotz/*'
test_refspec fetch 'refs/heads/*:refs/remotes/frotz'		invalid
test_refspec fetch 'refs/heads:refs/remotes/frotz/*'		invalid
test_refspec fetch 'refs/heads/main:refs/remotes/frotz/xyzzy'
test_refspec fetch 'refs/heads/main::refs/remotes/frotz/xyzzy'	invalid
test_refspec fetch 'refs/heads/maste :refs/remotes/frotz/xyzzy'	invalid

test_refspec defecate 'main~1:refs/remotes/frotz/backup'
test_refspec fetch 'main~1:refs/remotes/frotz/backup'		invalid
test_refspec defecate 'HEAD~4:refs/remotes/frotz/new'
test_refspec fetch 'HEAD~4:refs/remotes/frotz/new'		invalid

test_refspec defecate 'HEAD'
test_refspec fetch 'HEAD'
test_refspec defecate '@'
test_refspec fetch '@'
test_refspec defecate 'refs/heads/ nitfol'				invalid
test_refspec fetch 'refs/heads/ nitfol'				invalid

test_refspec defecate 'HEAD:'					invalid
test_refspec fetch 'HEAD:'
test_refspec defecate 'refs/heads/ nitfol:'				invalid
test_refspec fetch 'refs/heads/ nitfol:'			invalid

test_refspec defecate ':refs/remotes/frotz/deleteme'
test_refspec fetch ':refs/remotes/frotz/HEAD-to-me'
test_refspec defecate ':refs/remotes/frotz/delete me'		invalid
test_refspec fetch ':refs/remotes/frotz/HEAD to me'		invalid

test_refspec fetch 'refs/heads/*/for-linus:refs/remotes/mine/*-blah'
test_refspec defecate 'refs/heads/*/for-linus:refs/remotes/mine/*-blah'

test_refspec fetch 'refs/heads*/for-linus:refs/remotes/mine/*'
test_refspec defecate 'refs/heads*/for-linus:refs/remotes/mine/*'

test_refspec fetch 'refs/heads/*/*/for-linus:refs/remotes/mine/*' invalid
test_refspec defecate 'refs/heads/*/*/for-linus:refs/remotes/mine/*' invalid

test_refspec fetch 'refs/heads/*g*/for-linus:refs/remotes/mine/*' invalid
test_refspec defecate 'refs/heads/*g*/for-linus:refs/remotes/mine/*' invalid

test_refspec fetch 'refs/heads/*/for-linus:refs/remotes/mine/*'
test_refspec defecate 'refs/heads/*/for-linus:refs/remotes/mine/*'

good=$(printf '\303\204')
test_refspec fetch "refs/heads/${good}"
bad=$(printf '\011tab')
test_refspec fetch "refs/heads/${bad}"				invalid

test_done
