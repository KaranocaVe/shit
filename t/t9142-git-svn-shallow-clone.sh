#!/bin/sh
#
# Copyright (c) 2009 Eric Wong
#

test_description='shit svn shallow clone'
. ./lib-shit-svn.sh

test_expect_success 'setup test repository' '
	svn_cmd mkdir -m "create standard layout" \
	  "$svnrepo"/trunk "$svnrepo"/branches "$svnrepo"/tags &&
	svn_cmd cp -m "branch off trunk" \
	  "$svnrepo"/trunk "$svnrepo"/branches/a &&
	svn_cmd co "$svnrepo"/branches/a &&
	(
		cd a &&
		> foo &&
		svn_cmd add foo &&
		svn_cmd commit -m "add foo"
	) &&
	maybe_start_httpd
'

test_expect_success 'clone trunk with "-r HEAD"' '
	shit svn clone -r HEAD "$svnrepo/trunk" g &&
	( cd g && shit rev-parse --symbolic --verify HEAD )
'

test_done
