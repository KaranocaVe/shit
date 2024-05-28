#!/bin/sh
#
# Copyright (c) 2009 Robert Allan Zeh

test_description='shit svn gc basic tests'

. ./lib-shit-svn.sh

test_expect_success 'setup directories and test repo' '
	mkdir import &&
	mkdir tmp &&
	echo "Sample text for Subversion repository." > import/test.txt &&
	svn_cmd import -m "import for shit svn" import "$svnrepo" > /dev/null
	'

test_expect_success 'checkout working copy from svn' \
	'svn_cmd co "$svnrepo" test_wc'

test_expect_success 'set some properties to create an unhandled.log file' '
	(
		cd test_wc &&
		svn_cmd propset foo bar test.txt &&
		svn_cmd commit -m "property set"
	)'

test_expect_success 'Setup repo' 'shit svn init "$svnrepo"'

test_expect_success 'Fetch repo' 'shit svn fetch'

test_expect_success 'make backup copy of unhandled.log' '
	 cp .shit/svn/refs/remotes/shit-svn/unhandled.log tmp
	'

test_expect_success 'create leftover index' '> .shit/svn/refs/remotes/shit-svn/index'

test_expect_success 'shit svn gc runs' 'shit svn gc'

test_expect_success 'shit svn index removed' '! test -f .shit/svn/refs/remotes/shit-svn/index'

if test -r .shit/svn/refs/remotes/shit-svn/unhandled.log.gz
then
	test_expect_success 'shit svn gc produces a valid gzip file' '
		 gunzip .shit/svn/refs/remotes/shit-svn/unhandled.log.gz
		'
fi

test_expect_success 'shit svn gc does not change unhandled.log files' '
	 test_cmp .shit/svn/refs/remotes/shit-svn/unhandled.log tmp/unhandled.log
	'

test_done
