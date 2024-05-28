#!/bin/sh
# Copyright (c) 2007 Eric Wong
test_description='shit svn globbing refspecs'
. ./lib-shit-svn.sh

cat > expect.end <<EOF
the end
hi
start a new branch
initial
EOF

test_expect_success 'test refspec globbing' '
	mkdir -p trunk/src/a trunk/src/b trunk/doc &&
	echo "hello world" > trunk/src/a/readme &&
	echo "goodbye world" > trunk/src/b/readme &&
	svn_cmd import -m "initial" trunk "$svnrepo"/trunk &&
	svn_cmd co "$svnrepo" tmp &&
	(
		cd tmp &&
		mkdir branches branches/v1 tags &&
		svn_cmd add branches tags &&
		svn_cmd cp trunk branches/v1/start &&
		svn_cmd commit -m "start a new branch" &&
		svn_cmd up &&
		echo "hi" >> branches/v1/start/src/b/readme &&
		poke branches/v1/start/src/b/readme &&
		echo "hey" >> branches/v1/start/src/a/readme &&
		poke branches/v1/start/src/a/readme &&
		svn_cmd commit -m "hi" &&
		svn_cmd up &&
		svn_cmd cp branches/v1/start tags/end &&
		echo "bye" >> tags/end/src/b/readme &&
		poke tags/end/src/b/readme &&
		echo "aye" >> tags/end/src/a/readme &&
		poke tags/end/src/a/readme &&
		svn_cmd commit -m "the end" &&
		echo "byebye" >> tags/end/src/b/readme &&
		poke tags/end/src/b/readme &&
		svn_cmd commit -m "nothing to see here"
	) &&
	shit config --add svn-remote.svn.url "$svnrepo" &&
	shit config --add svn-remote.svn.fetch \
	                 "trunk/src/a:refs/remotes/trunk" &&
	shit config --add svn-remote.svn.branches \
	                 "branches/*/*/src/a:refs/remotes/branches/*/*" &&
	shit config --add svn-remote.svn.tags\
	                 "tags/*/src/a:refs/remotes/tags/*" &&
	shit svn multi-fetch &&
	shit log --pretty=oneline refs/remotes/tags/end >actual &&
	cut -d" " -f2- actual >output.end &&
	test_cmp expect.end output.end &&
	test "$(shit rev-parse refs/remotes/tags/end~1)" = \
		"$(shit rev-parse refs/remotes/branches/v1/start)" &&
	test "$(shit rev-parse refs/remotes/branches/v1/start~2)" = \
		"$(shit rev-parse refs/remotes/trunk)" &&
	test_must_fail shit rev-parse refs/remotes/tags/end@3
	'

echo try to try > expect.two
echo nothing to see here >> expect.two
cat expect.end >> expect.two

test_expect_success 'test left-hand-side only globbing' '
	shit config --add svn-remote.two.url "$svnrepo" &&
	shit config --add svn-remote.two.fetch trunk:refs/remotes/two/trunk &&
	shit config --add svn-remote.two.branches \
	                 "branches/*/*:refs/remotes/two/branches/*/*" &&
	shit config --add svn-remote.two.tags \
	                 "tags/*:refs/remotes/two/tags/*" &&
	(
		cd tmp &&
		echo "try try" >> tags/end/src/b/readme &&
		poke tags/end/src/b/readme &&
		svn_cmd commit -m "try to try"
	) &&
	shit svn fetch two &&
	shit rev-list refs/remotes/two/tags/end >actual &&
	test_line_count = 6 actual &&
	shit rev-list refs/remotes/two/branches/v1/start >actual &&
	test_line_count = 3 actual &&
	test $(shit rev-parse refs/remotes/two/branches/v1/start~2) = \
	     $(shit rev-parse refs/remotes/two/trunk) &&
	test $(shit rev-parse refs/remotes/two/tags/end~3) = \
	     $(shit rev-parse refs/remotes/two/branches/v1/start) &&
	shit log --pretty=oneline refs/remotes/two/tags/end >actual &&
	cut -d" " -f2- actual >output.two &&
	test_cmp expect.two output.two
	'
cat > expect.four <<EOF
adios
adding more
Changed 2 in v2/start
Another versioned branch
initial
EOF

test_expect_success 'test another branch' '
	(
		cd tmp &&
		mkdir branches/v2 &&
		svn_cmd add branches/v2 &&
		svn_cmd cp trunk branches/v2/start &&
		svn_cmd commit -m "Another versioned branch" &&
		svn_cmd up &&
		echo "hello" >> branches/v2/start/src/b/readme &&
		poke branches/v2/start/src/b/readme &&
		echo "howdy" >> branches/v2/start/src/a/readme &&
		poke branches/v2/start/src/a/readme &&
		svn_cmd commit -m "Changed 2 in v2/start" &&
		svn_cmd up &&
		svn_cmd cp branches/v2/start tags/next &&
		echo "bye" >> tags/next/src/b/readme &&
		poke tags/next/src/b/readme &&
		echo "aye" >> tags/next/src/a/readme &&
		poke tags/next/src/a/readme &&
		svn_cmd commit -m "adding more" &&
		echo "byebye" >> tags/next/src/b/readme &&
		poke tags/next/src/b/readme &&
		svn_cmd commit -m "adios"
	) &&
	shit config --add svn-remote.four.url "$svnrepo" &&
	shit config --add svn-remote.four.fetch trunk:refs/remotes/four/trunk &&
	shit config --add svn-remote.four.branches \
	                 "branches/*/*:refs/remotes/four/branches/*/*" &&
	shit config --add svn-remote.four.tags \
	                 "tags/*:refs/remotes/four/tags/*" &&
	shit svn fetch four &&
	shit rev-list refs/remotes/four/tags/next >actual &&
	test_line_count = 5 actual &&
	shit rev-list refs/remotes/four/branches/v2/start >actual &&
	test_line_count = 3 actual &&
	test $(shit rev-parse refs/remotes/four/branches/v2/start~2) = \
	     $(shit rev-parse refs/remotes/four/trunk) &&
	test $(shit rev-parse refs/remotes/four/tags/next~2) = \
	     $(shit rev-parse refs/remotes/four/branches/v2/start) &&
	shit log --pretty=oneline refs/remotes/four/tags/next >actual &&
	cut -d" " -f2- actual >output.four &&
	test_cmp expect.four output.four
	'

test_expect_success 'prepare test disallow multiple globs' "
cat >expect.three <<EOF
Only one set of wildcards (e.g. '*' or '*/*/*') is supported: branches/*/t/*

EOF
	"

test_expect_success 'test disallow multiple globs' '
	shit config --add svn-remote.three.url "$svnrepo" &&
	shit config --add svn-remote.three.fetch \
	                 trunk:refs/remotes/three/trunk &&
	shit config --add svn-remote.three.branches \
	                 "branches/*/t/*:refs/remotes/three/branches/*/*" &&
	shit config --add svn-remote.three.tags \
	                 "tags/*:refs/remotes/three/tags/*" &&
	(
		cd tmp &&
		echo "try try" >> tags/end/src/b/readme &&
		poke tags/end/src/b/readme &&
		svn_cmd commit -m "try to try"
	) &&
	test_must_fail shit svn fetch three 2> stderr.three &&
	test_cmp expect.three stderr.three
	'

test_done
