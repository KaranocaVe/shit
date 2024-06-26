#!/bin/sh
#
# Copyright (c) 2007 Eric Wong
#

# Don't run this test by default unless the user really wants it
# I don't like the idea of taking a port and possibly leaving a
# daemon running on a users system if the test fails.
# Not all shit users will need to interact with SVN.

test_description='shit svn dcommit new files over svn:// test'

. ./lib-shit-svn.sh

require_svnserve

test_expect_success 'start tracking an empty repo' '
	svn_cmd mkdir -m "empty dir" "$svnrepo"/empty-dir &&
	echo "[general]" > "$rawsvnrepo"/conf/svnserve.conf &&
	echo anon-access = write >> "$rawsvnrepo"/conf/svnserve.conf &&
	start_svnserve &&
	shit svn init svn://127.0.0.1:$SVNSERVE_PORT &&
	shit svn fetch
	'

test_expect_success 'create files in new directory with dcommit' "
	mkdir shit-new-dir &&
	echo hello > shit-new-dir/world &&
	shit update-index --add shit-new-dir/world &&
	shit commit -m hello &&
	start_svnserve &&
	shit svn dcommit
	"

test_done
