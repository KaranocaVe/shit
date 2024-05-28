#!/bin/sh
#
# Copyright (c) 2007 Sam Vilain
#

test_description='shit-svn svk merge tickets'

. ./lib-shit-svn.sh

test_expect_success 'load svk depot' "
	svnadmin load -q '$rawsvnrepo' \
	  < '$TEST_DIRECTORY/t9150/svk-merge.dump' &&
	shit svn init --minimize-url -R svkmerge \
	  --rewrite-root=http://svn.example.org \
	  -T trunk -b branches '$svnrepo' &&
	shit svn fetch --all
	"

uuid=b48289b2-9c08-4d72-af37-0358a40b9c15

test_expect_success 'svk merges were represented coming in' "
	[ $(shit cat-file commit HEAD | grep parent | wc -l) -eq 2 ]
	"

test_done
