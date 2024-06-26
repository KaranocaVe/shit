#!/bin/sh
#
# Copyright (c) 2007 Eric Wong
#

test_description='shit svn tracking removed top-level path'
. ./lib-shit-svn.sh

test_expect_success 'make history for tracking' '
	mkdir import &&
	mkdir import/trunk &&
	echo hello >> import/trunk/README &&
	svn_cmd import -m initial import "$svnrepo" &&
	rm -rf import &&
	svn_cmd co "$svnrepo"/trunk trunk &&
	echo bye bye >> trunk/README &&
	svn_cmd rm -m "gone" "$svnrepo"/trunk &&
	rm -rf trunk &&
	mkdir trunk &&
	echo "new" > trunk/FOLLOWME &&
	svn_cmd import -m "new trunk" trunk "$svnrepo"/trunk
'

test_expect_success 'clone repo with shit' '
	shit svn clone -s "$svnrepo" x &&
	test_path_is_file x/FOLLOWME &&
	test_path_is_missing x/README
'

test_expect_success 'make sure r2 still has old file' '
	(
		cd x &&
		test -n "$(shit svn find-rev r1)" &&
		shit reset --hard "$(shit svn find-rev r1)" &&
		test_path_is_file README &&
		test_path_is_missing FOLLOWME &&
		test -z "$(shit svn find-rev r2)"
	)
'

test_done
