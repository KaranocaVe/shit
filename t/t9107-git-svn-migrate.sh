#!/bin/sh
# Copyright (c) 2006 Eric Wong
test_description='shit svn metadata migrations from previous versions'
. ./lib-shit-svn.sh

test_expect_success 'setup old-looking metadata' '
	cp "$shit_DIR"/config "$shit_DIR"/config-old-shit-svn &&
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
	shit svn init "$svnrepo" &&
	shit svn fetch &&
	rm -rf "$shit_DIR"/svn &&
	shit update-ref refs/heads/shit-svn-HEAD refs/remotes/shit-svn &&
	shit update-ref refs/heads/svn-HEAD refs/remotes/shit-svn &&
	shit update-ref -d refs/remotes/shit-svn refs/remotes/shit-svn
	'

test_expect_success 'shit-svn-HEAD is a real HEAD' '
	shit rev-parse --verify refs/heads/shit-svn-HEAD^0
'

svnrepo_escaped=$(echo $svnrepo | sed 's/ /%20/g')

test_expect_success 'initialize old-style (v0) shit svn layout' '
	mkdir -p "$shit_DIR"/shit-svn/info "$shit_DIR"/svn/info &&
	echo "$svnrepo" > "$shit_DIR"/shit-svn/info/url &&
	echo "$svnrepo" > "$shit_DIR"/svn/info/url &&
	shit svn migrate &&
	! test -d "$shit_DIR"/shit-svn &&
	shit rev-parse --verify refs/remotes/shit-svn^0 &&
	shit rev-parse --verify refs/remotes/svn^0 &&
	test "$(shit config --get svn-remote.svn.url)" = "$svnrepo_escaped" &&
	test $(shit config --get svn-remote.svn.fetch) = \
		":refs/remotes/shit-svn"
	'

test_expect_success 'initialize a multi-repository repo' '
	shit svn init "$svnrepo" -T trunk -t tags -b branches &&
	shit config --get-all svn-remote.svn.fetch > fetch.out &&
	grep "^trunk:refs/remotes/origin/trunk$" fetch.out &&
	test -n "$(shit config --get svn-remote.svn.branches \
		    "^branches/\*:refs/remotes/origin/\*$")" &&
	test -n "$(shit config --get svn-remote.svn.tags \
		    "^tags/\*:refs/remotes/origin/tags/\*$")" &&
	shit config --unset svn-remote.svn.branches \
	                        "^branches/\*:refs/remotes/origin/\*$" &&
	shit config --unset svn-remote.svn.tags \
	                        "^tags/\*:refs/remotes/origin/tags/\*$" &&
	shit config --add svn-remote.svn.fetch "branches/a:refs/remotes/origin/a" &&
	shit config --add svn-remote.svn.fetch "branches/b:refs/remotes/origin/b" &&
	for i in tags/0.1 tags/0.2 tags/0.3
	do
		shit config --add svn-remote.svn.fetch \
			$i:refs/remotes/origin/$i || return 1
	done &&
	shit config --get-all svn-remote.svn.fetch > fetch.out &&
	grep "^trunk:refs/remotes/origin/trunk$" fetch.out &&
	grep "^branches/a:refs/remotes/origin/a$" fetch.out &&
	grep "^branches/b:refs/remotes/origin/b$" fetch.out &&
	grep "^tags/0\.1:refs/remotes/origin/tags/0\.1$" fetch.out &&
	grep "^tags/0\.2:refs/remotes/origin/tags/0\.2$" fetch.out &&
	grep "^tags/0\.3:refs/remotes/origin/tags/0\.3$" fetch.out &&
	grep "^:refs/remotes/shit-svn" fetch.out
	'

# refs should all be different, but the trees should all be the same:
test_expect_success 'multi-fetch works on partial urls + paths' '
	refs="trunk a b tags/0.1 tags/0.2 tags/0.3" &&
	shit svn multi-fetch &&
	for i in $refs
	do
		shit rev-parse --verify refs/remotes/origin/$i^0 || return 1;
	done >refs.out &&
	test -z "$(sort <refs.out | uniq -d)" &&
	for i in $refs
	do
		for j in $refs
		do
			shit diff --exit-code refs/remotes/origin/$i \
					     refs/remotes/origin/$j ||
				return 1
		done
	done
'

test_expect_success 'migrate --minimize on old inited layout' '
	shit config --unset-all svn-remote.svn.fetch &&
	shit config --unset-all svn-remote.svn.url &&
	rm -rf "$shit_DIR"/svn &&
	for i in $(cat fetch.out)
	do
		path=${i%%:*} &&
		ref=${i#*:} &&
		if test "$ref" = "${ref#refs/remotes/}"; then continue; fi &&
		if test -n "$path"; then path="/$path"; fi &&
		mkdir -p "$shit_DIR"/svn/$ref/info/ &&
		echo "$svnrepo"$path >"$shit_DIR"/svn/$ref/info/url ||
		return 1
	done &&
	shit svn migrate --minimize &&
	test -z "$(shit config -l | grep "^svn-remote\.shit-svn\.")" &&
	shit config --get-all svn-remote.svn.fetch > fetch.out &&
	grep "^trunk:refs/remotes/origin/trunk$" fetch.out &&
	grep "^branches/a:refs/remotes/origin/a$" fetch.out &&
	grep "^branches/b:refs/remotes/origin/b$" fetch.out &&
	grep "^tags/0\.1:refs/remotes/origin/tags/0\.1$" fetch.out &&
	grep "^tags/0\.2:refs/remotes/origin/tags/0\.2$" fetch.out &&
	grep "^tags/0\.3:refs/remotes/origin/tags/0\.3$" fetch.out &&
	grep "^:refs/remotes/shit-svn" fetch.out
	'

test_expect_success  ".rev_db auto-converted to .rev_map.UUID" '
	shit svn fetch -i trunk &&
	test -z "$(ls "$shit_DIR"/svn/refs/remotes/origin/trunk/.rev_db.* 2>/dev/null)" &&
	expect="$(ls "$shit_DIR"/svn/refs/remotes/origin/trunk/.rev_map.*)" &&
	test -n "$expect" &&
	rev_db="$(echo $expect | sed -e "s,_map,_db,")" &&
	convert_to_rev_db "$expect" "$rev_db" &&
	rm -f "$expect" &&
	test -f "$rev_db" &&
	shit svn fetch -i trunk &&
	test -z "$(ls "$shit_DIR"/svn/refs/remotes/origin/trunk/.rev_db.* 2>/dev/null)" &&
	test ! -e "$shit_DIR"/svn/refs/remotes/origin/trunk/.rev_db &&
	test -f "$expect"
	'

test_done
