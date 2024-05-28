#!/bin/sh
#
# Portions copyright (c) 2007, 2009 Sam Vilain
# Portions copyright (c) 2011 Bryan Jacobs
#

test_description='shit-svn svn mergeinfo propagation'

. ./lib-shit-svn.sh

test_expect_success 'load svn dump' "
	svnadmin load -q '$rawsvnrepo' \
	  < '$TEST_DIRECTORY/t9161/branches.dump' &&
	shit svn init --minimize-url -R svnmerge \
	  -T trunk -b branches '$svnrepo' &&
	shit svn fetch --all
	"

test_expect_success 'propagate merge information' '
	shit config svn.defecatemergeinfo yes &&
	shit checkout origin/svnb1 &&
	shit merge --no-ff origin/svnb2 &&
	shit svn dcommit
	'

test_expect_success 'check svn:mergeinfo' '
	mergeinfo=$(svn_cmd propget svn:mergeinfo "$svnrepo"/branches/svnb1) &&
	test "$mergeinfo" = "/branches/svnb2:3,8"
	'

test_expect_success 'merge another branch' '
	shit merge --no-ff origin/svnb3 &&
	shit svn dcommit
	'

test_expect_success 'check primary parent mergeinfo respected' '
	mergeinfo=$(svn_cmd propget svn:mergeinfo "$svnrepo"/branches/svnb1) &&
	test "$mergeinfo" = "/branches/svnb2:3,8
/branches/svnb3:4,9"
	'

test_expect_success 'merge existing merge' '
	shit merge --no-ff origin/svnb4 &&
	shit svn dcommit
	'

test_expect_success "check both parents' mergeinfo respected" '
	mergeinfo=$(svn_cmd propget svn:mergeinfo "$svnrepo"/branches/svnb1) &&
	test "$mergeinfo" = "/branches/svnb2:3,8
/branches/svnb3:4,9
/branches/svnb4:5-6,10-12
/branches/svnb5:6,11"
	'

test_expect_success 'make further commits to branch' '
	shit checkout origin/svnb2 &&
	touch newb2file &&
	shit add newb2file &&
	shit commit -m "later b2 commit" &&
	touch newb2file-2 &&
	shit add newb2file-2 &&
	shit commit -m "later b2 commit 2" &&
	shit svn dcommit
	'

test_expect_success 'second forward merge' '
	shit checkout origin/svnb1 &&
	shit merge --no-ff origin/svnb2 &&
	shit svn dcommit
	'

test_expect_success 'check new mergeinfo added' '
	mergeinfo=$(svn_cmd propget svn:mergeinfo "$svnrepo"/branches/svnb1) &&
	test "$mergeinfo" = "/branches/svnb2:3,8,16-17
/branches/svnb3:4,9
/branches/svnb4:5-6,10-12
/branches/svnb5:6,11"
	'

test_expect_success 'reintegration merge' '
	shit checkout origin/svnb4 &&
	shit merge --no-ff origin/svnb1 &&
	shit svn dcommit
	'

test_expect_success 'check reintegration mergeinfo' '
	mergeinfo=$(svn_cmd propget svn:mergeinfo "$svnrepo"/branches/svnb4) &&
	test "$mergeinfo" = "/branches/svnb1:2-4,7-9,13-18
/branches/svnb2:3,8,16-17
/branches/svnb3:4,9
/branches/svnb5:6,11"
	'

test_expect_success 'dcommit a merge at the top of a stack' '
	shit checkout origin/svnb1 &&
	touch anotherfile &&
	shit add anotherfile &&
	shit commit -m "a commit" &&
	shit merge origin/svnb4 &&
	shit svn dcommit
	'

test_done
