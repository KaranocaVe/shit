#!/bin/sh
#
# Copyright (c) 2009 Vitaly Shukela
# Copyright (c) 2009 Eric Wong
#

test_description='shit svn property tests'
. ./lib-shit-svn.sh

test_expect_success 'setup test repository' '
	svn_cmd co "$svnrepo" s &&
	(
		cd s &&
		mkdir qqq www &&
		echo test_qqq > qqq/test_qqq.txt &&
		echo test_www > www/test_www.txt &&
		svn_cmd add qqq &&
		svn_cmd add www &&
		svn_cmd commit -m "create some files" &&
		svn_cmd up &&
		echo hi >> www/test_www.txt &&
		svn_cmd commit -m "modify www/test_www.txt" &&
		svn_cmd up
	)
'

test_expect_success 'clone an SVN repository with ignored www directory' '
	shit svn clone --ignore-paths="^www" "$svnrepo" g &&
	echo test_qqq > expect &&
	for i in g/*/*.txt; do cat $i >> expect2 || return 1; done &&
	test_cmp expect expect2
'

test_expect_success 'init+fetch an SVN repository with ignored www directory' '
	shit svn init "$svnrepo" c &&
	( cd c && shit svn fetch --ignore-paths="^www" ) &&
	rm expect2 &&
	echo test_qqq > expect &&
	for i in c/*/*.txt; do cat $i >> expect2 || return 1; done &&
	test_cmp expect expect2
'

test_expect_success 'verify ignore-paths config saved by clone' '
	(
	    cd g &&
	    shit config --get svn-remote.svn.ignore-paths | grep www
	)
'

test_expect_success 'SVN-side change outside of www' '
	(
		cd s &&
		echo b >> qqq/test_qqq.txt &&
		svn_cmd commit -m "SVN-side change outside of www" &&
		svn_cmd up &&
		svn_cmd log -v | grep "SVN-side change outside of www"
	)
'

test_expect_success 'update shit svn-cloned repo (config ignore)' '
	(
		cd g &&
		shit svn rebase &&
		printf "test_qqq\nb\n" > expect &&
		for i in */*.txt; do cat $i >> expect2 || exit 1; done &&
		test_cmp expect2 expect &&
		rm expect expect2
	)
'

test_expect_success 'update shit svn-cloned repo (option ignore)' '
	(
		cd c &&
		shit svn rebase --ignore-paths="^www" &&
		printf "test_qqq\nb\n" > expect &&
		for i in */*.txt; do cat $i >> expect2 || exit 1; done &&
		test_cmp expect2 expect &&
		rm expect expect2
	)
'

test_expect_success 'SVN-side change inside of ignored www' '
	(
		cd s &&
		echo zaq >> www/test_www.txt &&
		svn_cmd commit -m "SVN-side change inside of www/test_www.txt" &&
		svn_cmd up &&
		svn_cmd log -v | grep -F "SVN-side change inside of www/test_www.txt"
	)
'

test_expect_success 'update shit svn-cloned repo (config ignore)' '
	(
		cd g &&
		shit svn rebase &&
		printf "test_qqq\nb\n" > expect &&
		for i in */*.txt; do cat $i >> expect2 || exit 1; done &&
		test_cmp expect2 expect &&
		rm expect expect2
	)
'

test_expect_success 'update shit svn-cloned repo (option ignore)' '
	(
		cd c &&
		shit svn rebase --ignore-paths="^www" &&
		printf "test_qqq\nb\n" > expect &&
		for i in */*.txt; do cat $i >> expect2 || exit 1; done &&
		test_cmp expect2 expect &&
		rm expect expect2
	)
'

test_expect_success 'SVN-side change in and out of ignored www' '
	(
		cd s &&
		echo cvf >> www/test_www.txt &&
		echo ygg >> qqq/test_qqq.txt &&
		svn_cmd commit -m "SVN-side change in and out of ignored www" &&
		svn_cmd up &&
		svn_cmd log -v | grep "SVN-side change in and out of ignored www"
	)
'

test_expect_success 'update shit svn-cloned repo again (config ignore)' '
	(
		cd g &&
		shit svn rebase &&
		printf "test_qqq\nb\nygg\n" > expect &&
		for i in */*.txt; do cat $i >> expect2 || exit 1; done &&
		test_cmp expect2 expect &&
		rm expect expect2
	)
'

test_expect_success 'update shit svn-cloned repo again (option ignore)' '
	(
		cd c &&
		shit svn rebase --ignore-paths="^www" &&
		printf "test_qqq\nb\nygg\n" > expect &&
		for i in */*.txt; do cat $i >> expect2 || exit 1; done &&
		test_cmp expect2 expect &&
		rm expect expect2
	)
'

test_done
