#!/bin/sh
#
# Copyright (c) 2009 Mark Rada
#

test_description='shitweb as standalone script (parsing script output).

This test runs shitweb (shit web interface) as a CGI script from the
commandline, and checks that it produces the correct output, either
in the HTTP header or the actual script output.'


shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./lib-shitweb.sh

# ----------------------------------------------------------------------
# snapshot file name and prefix

cat >>shitweb_config.perl <<\EOF

$known_snapshot_formats{'tar'} = {
	'display' => 'tar',
	'type' => 'application/x-tar',
	'suffix' => '.tar',
	'format' => 'tar',
};

$feature{'snapshot'}{'default'} = ['tar'];
EOF

# Call check_snapshot with the arguments "<basename> [<prefix>]"
#
# This will check that shitweb HTTP header contains proposed filename
# as <basename> with '.tar' suffix added, and that generated tarfile
# (shitweb message body) has <prefix> as prefix for all files in tarfile
#
# <prefix> default to <basename>
check_snapshot () {
	basename=$1
	prefix=${2:-"$1"}
	echo "basename=$basename"
	grep "filename=.*$basename.tar" shitweb.headers >/dev/null 2>&1 &&
	"$TAR" tf shitweb.body >file_list &&
	! grep -v -e "^$prefix$" -e "^$prefix/" -e "^pax_global_header$" file_list
}

test_expect_success setup '
	test_commit first foo &&
	shit branch xx/test &&
	FULL_ID=$(shit rev-parse --verify HEAD) &&
	SHORT_ID=$(shit rev-parse --verify --short=7 HEAD)
'
test_debug '
	echo "FULL_ID  = $FULL_ID"
	echo "SHORT_ID = $SHORT_ID"
'

test_expect_success 'snapshot: full sha1' '
	shitweb_run "p=.shit;a=snapshot;h=$FULL_ID;sf=tar" &&
	check_snapshot ".shit-$SHORT_ID"
'
test_debug 'cat shitweb.headers && cat file_list'

test_expect_success 'snapshot: shortened sha1' '
	shitweb_run "p=.shit;a=snapshot;h=$SHORT_ID;sf=tar" &&
	check_snapshot ".shit-$SHORT_ID"
'
test_debug 'cat shitweb.headers && cat file_list'

test_expect_success 'snapshot: almost full sha1' '
	ID=$(shit rev-parse --short=30 HEAD) &&
	shitweb_run "p=.shit;a=snapshot;h=$ID;sf=tar" &&
	check_snapshot ".shit-$SHORT_ID"
'
test_debug 'cat shitweb.headers && cat file_list'

test_expect_success 'snapshot: HEAD' '
	shitweb_run "p=.shit;a=snapshot;h=HEAD;sf=tar" &&
	check_snapshot ".shit-HEAD-$SHORT_ID"
'
test_debug 'cat shitweb.headers && cat file_list'

test_expect_success 'snapshot: short branch name (main)' '
	shitweb_run "p=.shit;a=snapshot;h=main;sf=tar" &&
	ID=$(shit rev-parse --verify --short=7 main) &&
	check_snapshot ".shit-main-$ID"
'
test_debug 'cat shitweb.headers && cat file_list'

test_expect_success 'snapshot: short tag name (first)' '
	shitweb_run "p=.shit;a=snapshot;h=first;sf=tar" &&
	ID=$(shit rev-parse --verify --short=7 first) &&
	check_snapshot ".shit-first-$ID"
'
test_debug 'cat shitweb.headers && cat file_list'

test_expect_success 'snapshot: full branch name (refs/heads/main)' '
	shitweb_run "p=.shit;a=snapshot;h=refs/heads/main;sf=tar" &&
	ID=$(shit rev-parse --verify --short=7 main) &&
	check_snapshot ".shit-main-$ID"
'
test_debug 'cat shitweb.headers && cat file_list'

test_expect_success 'snapshot: full tag name (refs/tags/first)' '
	shitweb_run "p=.shit;a=snapshot;h=refs/tags/first;sf=tar" &&
	check_snapshot ".shit-first"
'
test_debug 'cat shitweb.headers && cat file_list'

test_expect_success 'snapshot: hierarchical branch name (xx/test)' '
	shitweb_run "p=.shit;a=snapshot;h=xx/test;sf=tar" &&
	! grep "filename=.*/" shitweb.headers
'
test_debug 'cat shitweb.headers'

# ----------------------------------------------------------------------
# forks of projects

test_expect_success 'forks: setup' '
	shit init --bare foo.shit &&
	echo file > file &&
	shit --shit-dir=foo.shit --work-tree=. add file &&
	shit --shit-dir=foo.shit --work-tree=. commit -m "Initial commit" &&
	echo "foo" > foo.shit/description &&
	shit clone --bare foo.shit foo.bar.shit &&
	echo "foo.bar" > foo.bar.shit/description &&
	shit clone --bare foo.shit foo_baz.shit &&
	echo "foo_baz" > foo_baz.shit/description &&
	rm -fr   foo &&
	mkdir -p foo &&
	(
		cd foo &&
		shit clone --shared --bare ../foo.shit foo-forked.shit &&
		echo "fork of foo" > foo-forked.shit/description
	)
'

test_expect_success 'forks: not skipped unless "forks" feature enabled' '
	shitweb_run "a=project_list" &&
	grep -q ">\\.shit<"               shitweb.body &&
	grep -q ">foo\\.shit<"            shitweb.body &&
	grep -q ">foo_baz\\.shit<"        shitweb.body &&
	grep -q ">foo\\.bar\\.shit<"      shitweb.body &&
	grep -q ">foo_baz\\.shit<"        shitweb.body &&
	grep -q ">foo/foo-forked\\.shit<" shitweb.body &&
	grep -q ">fork of .*<"           shitweb.body
'

test_expect_success 'enable forks feature' '
	cat >>shitweb_config.perl <<-\EOF
	$feature{"forks"}{"default"} = [1];
	EOF
'

test_expect_success 'forks: forks skipped if "forks" feature enabled' '
	shitweb_run "a=project_list" &&
	grep -q ">\\.shit<"               shitweb.body &&
	grep -q ">foo\\.shit<"            shitweb.body &&
	grep -q ">foo_baz\\.shit<"        shitweb.body &&
	grep -q ">foo\\.bar\\.shit<"      shitweb.body &&
	grep -q ">foo_baz\\.shit<"        shitweb.body &&
	grep -v ">foo/foo-forked\\.shit<" shitweb.body &&
	grep -v ">fork of .*<"           shitweb.body
'

test_expect_success 'forks: "forks" action for forked repository' '
	shitweb_run "p=foo.shit;a=forks" &&
	grep -q ">foo/foo-forked\\.shit<" shitweb.body &&
	grep -q ">fork of foo<"          shitweb.body
'

test_expect_success 'forks: can access forked repository' '
	shitweb_run "p=foo/foo-forked.shit;a=summary" &&
	grep -q "200 OK"        shitweb.headers &&
	grep -q ">fork of foo<" shitweb.body
'

test_expect_success 'forks: project_index lists all projects (incl. forks)' '
	cat >expected <<-\EOF &&
	.shit
	foo.bar.shit
	foo.shit
	foo/foo-forked.shit
	foo_baz.shit
	EOF
	shitweb_run "a=project_index" &&
	sed -e "s/ .*//" <shitweb.body | sort >actual &&
	test_cmp expected actual
'

xss() {
	echo >&2 "Checking $*..." &&
	shitweb_run "$@" &&
	if grep "$TAG" shitweb.body; then
		echo >&2 "xss: $TAG should have been quoted in output"
		return 1
	fi
	return 0
}

test_expect_success 'xss checks' '
	TAG="<magic-xss-tag>" &&
	xss "a=rss&p=$TAG" &&
	xss "a=rss&p=foo.shit&f=$TAG" &&
	xss "" "$TAG+"
'

no_http_equiv_content_type() {
	shitweb_run "$@" &&
	! grep -E "http-equiv=['\"]?content-type" shitweb.body
}

# See: <https://html.spec.whatwg.org/dev/semantics.html#attr-meta-http-equiv-content-type>
test_expect_success 'no http-equiv="content-type" in XHTML' '
	no_http_equiv_content_type &&
	no_http_equiv_content_type "p=.shit" &&
	no_http_equiv_content_type "p=.shit;a=log" &&
	no_http_equiv_content_type "p=.shit;a=tree"
'

proper_doctype() {
	shitweb_run "$@" &&
	grep -F "<!DOCTYPE html [" shitweb.body &&
	grep "<!ENTITY nbsp" shitweb.body &&
	grep "<!ENTITY sdot" shitweb.body
}

test_expect_success 'Proper DOCTYPE with entity declarations' '
	proper_doctype &&
	proper_doctype "p=.shit" &&
	proper_doctype "p=.shit;a=log" &&
	proper_doctype "p=.shit;a=tree"
'

test_done
