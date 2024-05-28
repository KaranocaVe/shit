#!/bin/sh

test_description='test refspec written by clone-command'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '
	# Make two branches, "main" and "side"
	echo one >file &&
	shit add file &&
	shit commit -m one &&
	echo two >file &&
	shit commit -a -m two &&
	shit tag two &&
	echo three >file &&
	shit commit -a -m three &&
	shit checkout -b side &&
	echo four >file &&
	shit commit -a -m four &&
	shit checkout main &&
	shit tag five &&

	# default clone
	shit clone . dir_all &&

	# default clone --no-tags
	shit clone --no-tags . dir_all_no_tags &&

	# default --single that follows HEAD=main
	shit clone --single-branch . dir_main &&

	# default --single that follows HEAD=main with no tags
	shit clone --single-branch --no-tags . dir_main_no_tags &&

	# default --single that follows HEAD=side
	shit checkout side &&
	shit clone --single-branch . dir_side &&

	# explicit --single that follows side
	shit checkout main &&
	shit clone --single-branch --branch side . dir_side2 &&

	# default --single with --mirror
	shit clone --single-branch --mirror . dir_mirror &&

	# default --single with --branch and --mirror
	shit clone --single-branch --mirror --branch side . dir_mirror_side &&

	# --single that does not know what branch to follow
	shit checkout two^ &&
	shit clone --single-branch . dir_detached &&

	# explicit --single with tag
	shit clone --single-branch --branch two . dir_tag &&

	# explicit --single with tag and --no-tags
	shit clone --single-branch --no-tags --branch two . dir_tag_no_tags &&

	# advance both "main" and "side" branches
	shit checkout side &&
	echo five >file &&
	shit commit -a -m five &&
	shit checkout main &&
	echo six >file &&
	shit commit -a -m six &&

	# update tag
	shit tag -d two && shit tag two
'

test_expect_success 'by default all branches will be kept updated' '
	(
		cd dir_all &&
		shit fetch &&
		shit for-each-ref refs/remotes/origin >refs &&
		sed -e "/HEAD$/d" \
		    -e "s|/remotes/origin/|/heads/|" refs >../actual
	) &&
	# follow both main and side
	shit for-each-ref refs/heads >expect &&
	test_cmp expect actual
'

test_expect_success 'by default no tags will be kept updated' '
	(
		cd dir_all &&
		shit fetch &&
		shit for-each-ref refs/tags >../actual
	) &&
	shit for-each-ref refs/tags >expect &&
	! test_cmp expect actual &&
	test_line_count = 2 actual
'

test_expect_success 'clone with --no-tags' '
	(
		cd dir_all_no_tags &&
		grep tagOpt .shit/config &&
		shit fetch &&
		shit for-each-ref refs/tags >../actual
	) &&
	test_must_be_empty actual
'

test_expect_success '--single-branch while HEAD pointing at main' '
	(
		cd dir_main &&
		shit fetch --force &&
		shit for-each-ref refs/remotes/origin >refs &&
		sed -e "/HEAD$/d" \
		    -e "s|/remotes/origin/|/heads/|" refs >../actual
	) &&
	# only follow main
	shit for-each-ref refs/heads/main >expect &&
	# get & check latest tags
	test_cmp expect actual &&
	(
		cd dir_main &&
		shit fetch --tags --force &&
		shit for-each-ref refs/tags >../actual
	) &&
	shit for-each-ref refs/tags >expect &&
	test_cmp expect actual &&
	test_line_count = 2 actual
'

test_expect_success '--single-branch while HEAD pointing at main and --no-tags' '
	(
		cd dir_main_no_tags &&
		shit fetch &&
		shit for-each-ref refs/remotes/origin >refs &&
		sed -e "/HEAD$/d" \
		    -e "s|/remotes/origin/|/heads/|" refs >../actual
	) &&
	# only follow main
	shit for-each-ref refs/heads/main >expect &&
	test_cmp expect actual &&
	# get tags (noop)
	(
		cd dir_main_no_tags &&
		shit fetch &&
		shit for-each-ref refs/tags >../actual
	) &&
	test_must_be_empty actual &&
	test_line_count = 0 actual &&
	# get tags with --tags overrides tagOpt
	(
		cd dir_main_no_tags &&
		shit fetch --tags &&
		shit for-each-ref refs/tags >../actual
	) &&
	shit for-each-ref refs/tags >expect &&
	test_cmp expect actual &&
	test_line_count = 2 actual
'

test_expect_success '--single-branch while HEAD pointing at side' '
	(
		cd dir_side &&
		shit fetch &&
		shit for-each-ref refs/remotes/origin >refs &&
		sed -e "/HEAD$/d" \
		    -e "s|/remotes/origin/|/heads/|" refs >../actual
	) &&
	# only follow side
	shit for-each-ref refs/heads/side >expect &&
	test_cmp expect actual
'

test_expect_success '--single-branch with explicit --branch side' '
	(
		cd dir_side2 &&
		shit fetch &&
		shit for-each-ref refs/remotes/origin >refs &&
		sed -e "/HEAD$/d" \
		    -e "s|/remotes/origin/|/heads/|" refs >../actual
	) &&
	# only follow side
	shit for-each-ref refs/heads/side >expect &&
	test_cmp expect actual
'

test_expect_success '--single-branch with explicit --branch with tag fetches updated tag' '
	(
		cd dir_tag &&
		shit fetch &&
		shit for-each-ref refs/tags >../actual
	) &&
	shit for-each-ref refs/tags >expect &&
	test_cmp expect actual
'

test_expect_success '--single-branch with explicit --branch with tag fetches updated tag despite --no-tags' '
	(
		cd dir_tag_no_tags &&
		shit fetch &&
		shit for-each-ref refs/tags >../actual
	) &&
	shit for-each-ref refs/tags/two >expect &&
	test_cmp expect actual &&
	test_line_count = 1 actual
'

test_expect_success '--single-branch with --mirror' '
	(
		cd dir_mirror &&
		shit fetch &&
		shit for-each-ref refs > ../actual
	) &&
	shit for-each-ref refs >expect &&
	test_cmp expect actual
'

test_expect_success '--single-branch with explicit --branch and --mirror' '
	(
		cd dir_mirror_side &&
		shit fetch &&
		shit for-each-ref refs > ../actual
	) &&
	shit for-each-ref refs >expect &&
	test_cmp expect actual
'

test_expect_success '--single-branch with detached' '
	(
		cd dir_detached &&
		shit fetch &&
		shit for-each-ref refs/remotes/origin >refs &&
		sed -e "/HEAD$/d" \
		    -e "s|/remotes/origin/|/heads/|" refs >../actual
	) &&
	# nothing
	test_must_be_empty actual
'

test_done
