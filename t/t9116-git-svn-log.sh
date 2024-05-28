#!/bin/sh
#
# Copyright (c) 2007 Eric Wong
#

test_description='shit svn log tests'

. ./lib-shit-svn.sh

test_expect_success 'setup repository and import' '
	mkdir import &&
	(
		cd import &&
		for i in trunk branches/a branches/b tags/0.1 tags/0.2 tags/0.3
		do
			mkdir -p $i &&
			echo hello >>$i/README ||
			exit 1
		done &&
		svn_cmd import -m test . "$svnrepo"
	) &&
	shit svn init "$svnrepo" -T trunk -b branches -t tags &&
	shit svn fetch &&
	shit reset --hard origin/trunk &&
	echo bye >> README &&
	shit commit -a -m bye &&
	shit svn dcommit &&
	shit reset --hard origin/a &&
	echo why >> FEEDME &&
	shit update-index --add FEEDME &&
	shit commit -m feedme &&
	shit svn dcommit &&
	shit reset --hard origin/trunk &&
	echo aye >> README &&
	shit commit -a -m aye &&
	shit svn dcommit &&
	shit reset --hard origin/b &&
	echo spy >> README &&
	shit commit -a -m spy &&
	echo try >> README &&
	shit commit -a -m try &&
	shit svn dcommit
	'

test_expect_success 'run log' "
	shit reset --hard origin/a &&
	shit svn log -r2 origin/trunk >out &&
	grep ^r2 out &&
	shit svn log -r4 origin/trunk >out &&
	grep ^r4 out &&
	shit svn log -r3 >out &&
	grep ^r3 out
	"

test_expect_success 'run log against a from trunk' "
	shit reset --hard origin/trunk &&
	shit svn log -r3 origin/a >out &&
	grep ^r3 out
	"

printf 'r1 \nr2 \nr4 \n' > expected-range-r1-r2-r4

test_expect_success 'test ascending revision range' "
	shit reset --hard origin/trunk &&
	shit svn log -r 1:4 | grep '^r[0-9]' | cut -d'|' -f1 | test_cmp expected-range-r1-r2-r4 -
	"

test_expect_success 'test ascending revision range with --show-commit' "
	shit reset --hard origin/trunk &&
	shit svn log --show-commit -r 1:4 | grep '^r[0-9]' | cut -d'|' -f1 | test_cmp expected-range-r1-r2-r4 -
	"

test_expect_success 'test ascending revision range with --show-commit (sha1)' "
	shit svn find-rev r1 >expected-range-r1-r2-r4-sha1 &&
	shit svn find-rev r2 >>expected-range-r1-r2-r4-sha1 &&
	shit svn find-rev r4 >>expected-range-r1-r2-r4-sha1 &&
	shit reset --hard origin/trunk &&
	shit svn log --show-commit -r 1:4 | grep '^r[0-9]' | cut -d'|' -f2 >out &&
	shit rev-parse \$(cat out) >actual &&
	test_cmp expected-range-r1-r2-r4-sha1 actual
	"

printf 'r4 \nr2 \nr1 \n' > expected-range-r4-r2-r1

test_expect_success 'test descending revision range' "
	shit reset --hard origin/trunk &&
	shit svn log -r 4:1 | grep '^r[0-9]' | cut -d'|' -f1 | test_cmp expected-range-r4-r2-r1 -
	"

printf 'r1 \nr2 \n' > expected-range-r1-r2

test_expect_success 'test ascending revision range with unreachable revision' "
	shit reset --hard origin/trunk &&
	shit svn log -r 1:3 | grep '^r[0-9]' | cut -d'|' -f1 | test_cmp expected-range-r1-r2 -
	"

printf 'r2 \nr1 \n' > expected-range-r2-r1

test_expect_success 'test descending revision range with unreachable revision' "
	shit reset --hard origin/trunk &&
	shit svn log -r 3:1 | grep '^r[0-9]' | cut -d'|' -f1 | test_cmp expected-range-r2-r1 -
	"

printf 'r2 \n' > expected-range-r2

test_expect_success 'test ascending revision range with unreachable upper boundary revision and 1 commit' "
	shit reset --hard origin/trunk &&
	shit svn log -r 2:3 | grep '^r[0-9]' | cut -d'|' -f1 | test_cmp expected-range-r2 -
	"

test_expect_success 'test descending revision range with unreachable upper boundary revision and 1 commit' "
	shit reset --hard origin/trunk &&
	shit svn log -r 3:2 | grep '^r[0-9]' | cut -d'|' -f1 | test_cmp expected-range-r2 -
	"

printf 'r4 \n' > expected-range-r4

test_expect_success 'test ascending revision range with unreachable lower boundary revision and 1 commit' "
	shit reset --hard origin/trunk &&
	shit svn log -r 3:4 | grep '^r[0-9]' | cut -d'|' -f1 | test_cmp expected-range-r4 -
	"

test_expect_success 'test descending revision range with unreachable lower boundary revision and 1 commit' "
	shit reset --hard origin/trunk &&
	shit svn log -r 4:3 | grep '^r[0-9]' | cut -d'|' -f1 | test_cmp expected-range-r4 -
	"

printf -- '------------------------------------------------------------------------\n' > expected-separator

test_expect_success 'test ascending revision range with unreachable boundary revisions and no commits' "
	shit reset --hard origin/trunk &&
	shit svn log -r 5:6 | test_cmp expected-separator -
	"

test_expect_success 'test descending revision range with unreachable boundary revisions and no commits' "
	shit reset --hard origin/trunk &&
	shit svn log -r 6:5 | test_cmp expected-separator -
	"

test_expect_success 'test ascending revision range with unreachable boundary revisions and 1 commit' "
	shit reset --hard origin/trunk &&
	shit svn log -r 3:5 | grep '^r[0-9]' | cut -d'|' -f1 | test_cmp expected-range-r4 -
	"

test_expect_success 'test descending revision range with unreachable boundary revisions and 1 commit' "
	shit reset --hard origin/trunk &&
	shit svn log -r 5:3 | grep '^r[0-9]' | cut -d'|' -f1 | test_cmp expected-range-r4 -
	"

test_done
