#!/bin/sh

test_description='shit svn dcommit CRLF'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./lib-shit-svn.sh

test_expect_success 'setup commit repository' '
	svn_cmd mkdir -m "$test_description" "$svnrepo/dir" &&
	shit svn clone "$svnrepo" work &&
	(
		cd work &&
		echo foo >>foo &&
		shit update-index --add foo &&
		printf "a\\r\\n\\r\\nb\\r\\nc\\r\\n" >cmt &&
		p=$(shit rev-parse HEAD) &&
		t=$(shit write-tree) &&
		cmt=$(shit commit-tree -p $p $t <cmt) &&
		shit update-ref refs/heads/main $cmt &&
		shit cat-file commit HEAD | tail -n4 >out &&
		test_cmp cmt out &&
		shit svn dcommit &&
		printf "a\\n\\nb\\nc\\n" >exp &&
		shit cat-file commit HEAD | sed -ne 6,9p >out &&
		test_cmp exp out
	)
'

test_done
