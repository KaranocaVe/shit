#!/bin/sh
#
# Copyright (c) 2009 Robert Zeh

test_description='shit svn creates empty directories, calls shit gc, makes sure they are still empty'
. ./lib-shit-svn.sh

test_expect_success 'initialize repo' '
	for i in a b c d d/e d/e/f "weird file name"
	do
		svn_cmd mkdir -m "mkdir $i" "$svnrepo"/"$i" || return 1
	done
'

test_expect_success 'clone' 'shit svn clone "$svnrepo" cloned'

test_expect_success 'shit svn gc runs' '
	(
		cd cloned &&
		shit svn gc
	)
'

test_expect_success 'shit svn mkdirs recreates empty directories after shit svn gc' '
	(
		cd cloned &&
		rm -r * &&
		shit svn mkdirs &&
		for i in a b c d d/e d/e/f "weird file name"
		do
			if ! test -d "$i"
			then
				echo >&2 "$i does not exist" &&
				exit 1
			fi
		done
	)
'

test_done
