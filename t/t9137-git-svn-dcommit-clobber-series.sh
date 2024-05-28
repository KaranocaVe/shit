#!/bin/sh
#
# Copyright (c) 2007 Eric Wong
test_description='shit svn dcommit clobber series'
. ./lib-shit-svn.sh

test_expect_success 'initialize repo' '
	mkdir import &&
	(cd import &&
	awk "BEGIN { for (i = 1; i < 64; i++) { print i } }" > file &&
	svn_cmd import -m "initial" . "$svnrepo"
	) &&
	shit svn init "$svnrepo" &&
	shit svn fetch &&
	test -e file
	'

test_expect_success '(supposedly) non-conflicting change from SVN' '
	test x"$(sed -n -e 58p < file)" = x58 &&
	test x"$(sed -n -e 61p < file)" = x61 &&
	svn_cmd co "$svnrepo" tmp &&
	(cd tmp &&
		perl -i.bak -p -e "s/^58$/5588/" file &&
		perl -i.bak -p -e "s/^61$/6611/" file &&
		poke file &&
		test x"$(sed -n -e 58p < file)" = x5588 &&
		test x"$(sed -n -e 61p < file)" = x6611 &&
		svn_cmd commit -m "58 => 5588, 61 => 6611"
	)
	'

test_expect_success 'some unrelated changes to shit' "
	echo hi > life &&
	shit update-index --add life &&
	shit commit -m hi-life &&
	echo bye >> life &&
	shit commit -m bye-life life
	"

test_expect_success 'change file but in unrelated area' "
	test x\"\$(sed -n -e 4p < file)\" = x4 &&
	test x\"\$(sed -n -e 7p < file)\" = x7 &&
	perl -i.bak -p -e 's/^4\$/4444/' file &&
	perl -i.bak -p -e 's/^7\$/7777/' file &&
	test x\"\$(sed -n -e 4p < file)\" = x4444 &&
	test x\"\$(sed -n -e 7p < file)\" = x7777 &&
	shit commit -m '4 => 4444, 7 => 7777' file &&
	shit svn dcommit &&
	svn_cmd up tmp &&
	cd tmp &&
		test x\"\$(sed -n -e 4p < file)\" = x4444 &&
		test x\"\$(sed -n -e 7p < file)\" = x7777 &&
		test x\"\$(sed -n -e 58p < file)\" = x5588 &&
		test x\"\$(sed -n -e 61p < file)\" = x6611
	"

test_expect_success 'attempt to dcommit with a dirty index' '
	echo foo >>file &&
	shit add file &&
	test_must_fail shit svn dcommit
'

test_done
