#!/bin/sh
#
# Copyright (c) 2011 Frédéric Heitzmann

test_description='shit svn dcommit --interactive series'

. ./lib-shit-svn.sh

test_expect_success 'initialize repo' '
	svn_cmd mkdir -m"mkdir test-interactive" "$svnrepo/test-interactive" &&
	shit svn clone "$svnrepo/test-interactive" test-interactive &&
	cd test-interactive &&
	touch foo && shit add foo && shit commit -m"foo: first commit" &&
	shit svn dcommit
	'

test_expect_success 'answers: y [\n] yes' '
	(
		echo "change #1" >> foo && shit commit -a -m"change #1" &&
		echo "change #2" >> foo && shit commit -a -m"change #2" &&
		echo "change #3" >> foo && shit commit -a -m"change #3" &&
		( echo "y

y" | shit_SVN_NOTTY=1 shit svn dcommit --interactive ) &&
		test $(shit rev-parse HEAD) = $(shit rev-parse remotes/shit-svn)
	)
	'

test_expect_success 'answers: yes yes no' '
	(
		echo "change #1" >> foo && shit commit -a -m"change #1" &&
		echo "change #2" >> foo && shit commit -a -m"change #2" &&
		echo "change #3" >> foo && shit commit -a -m"change #3" &&
		( echo "yes
yes
no" | shit_SVN_NOTTY=1 shit svn dcommit --interactive ) &&
		test $(shit rev-parse HEAD^^^) = $(shit rev-parse remotes/shit-svn) &&
		shit reset --hard remotes/shit-svn
	)
	'

test_expect_success 'answers: yes quit' '
	(
		echo "change #1" >> foo && shit commit -a -m"change #1" &&
		echo "change #2" >> foo && shit commit -a -m"change #2" &&
		echo "change #3" >> foo && shit commit -a -m"change #3" &&
		( echo "yes
quit" | shit_SVN_NOTTY=1 shit svn dcommit --interactive ) &&
		test $(shit rev-parse HEAD^^^) = $(shit rev-parse remotes/shit-svn) &&
		shit reset --hard remotes/shit-svn
	)
	'

test_expect_success 'answers: all' '
	(
		echo "change #1" >> foo && shit commit -a -m"change #1" &&
		echo "change #2" >> foo && shit commit -a -m"change #2" &&
		echo "change #3" >> foo && shit commit -a -m"change #3" &&
		( echo "all" | shit_SVN_NOTTY=1 shit svn dcommit --interactive ) &&
		test $(shit rev-parse HEAD) = $(shit rev-parse remotes/shit-svn) &&
		shit reset --hard remotes/shit-svn
	)
	'

test_done
