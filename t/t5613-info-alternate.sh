#!/bin/sh
#
# Copyright (C) 2006 Martin Waitz <tali@admingilde.org>
#

test_description='test transitive info/alternate entries'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'preparing first repository' '
	test_create_repo A && (
		cd A &&
		echo "Hello World" > file1 &&
		shit add file1 &&
		shit commit -m "Initial commit" file1 &&
		shit repack -a -d &&
		shit prune
	)
'

test_expect_success 'preparing second repository' '
	shit clone -l -s A B && (
		cd B &&
		echo "foo bar" > file2 &&
		shit add file2 &&
		shit commit -m "next commit" file2 &&
		shit repack -a -d -l &&
		shit prune
	)
'

test_expect_success 'preparing third repository' '
	shit clone -l -s B C && (
		cd C &&
		echo "Goodbye, cruel world" > file3 &&
		shit add file3 &&
		shit commit -m "one more" file3 &&
		shit repack -a -d -l &&
		shit prune
	)
'

test_expect_success 'count-objects shows the alternates' '
	cat >expect <<-EOF &&
	alternate: $(pwd)/B/.shit/objects
	alternate: $(pwd)/A/.shit/objects
	EOF
	shit -C C count-objects -v >actual &&
	grep ^alternate: actual >actual.alternates &&
	test_cmp expect actual.alternates
'

# Note: These tests depend on the hard-coded value of 5 as the maximum depth
# we will follow recursion. We start the depth at 0 and count links, not
# repositories. This means that in a chain like:
#
#   A --> B --> C --> D --> E --> F --> G --> H
#      0     1     2     3     4     5     6
#
# we are OK at "G", but break at "H", even though "H" is actually the 8th
# repository, not the 6th, which you might expect. Counting the links allows
# N+1 repositories, and counting from 0 to 5 inclusive allows 6 links.
#
# Note also that we must use "--bare -l" to make the link to H. The "-l"
# ensures we do not do a connectivity check, and the "--bare" makes sure
# we do not try to checkout the result (which needs objects), either of
# which would cause the clone to fail.
test_expect_success 'creating too deep nesting' '
	shit clone -l -s C D &&
	shit clone -l -s D E &&
	shit clone -l -s E F &&
	shit clone -l -s F G &&
	shit clone --bare -l -s G H
'

test_expect_success 'validity of seventh repository' '
	shit -C G fsck
'

test_expect_success 'invalidity of eighth repository' '
	test_must_fail shit -C H fsck
'

test_expect_success 'breaking of loops' '
	echo "$(pwd)"/B/.shit/objects >>A/.shit/objects/info/alternates &&
	shit -C C fsck
'

test_expect_success 'that info/alternates is necessary' '
	rm -f C/.shit/objects/info/alternates &&
	test_must_fail shit -C C fsck
'

test_expect_success 'that relative alternate is possible for current dir' '
	echo "../../../B/.shit/objects" >C/.shit/objects/info/alternates &&
	shit fsck
'

test_expect_success 'that relative alternate is recursive' '
	shit -C D fsck
'

# we can reach "A" from our new repo both directly, and via "C".
# The deep/subdir is there to make sure we are not doing a stupid
# pure-text comparison of the alternate names.
test_expect_success 'relative duplicates are eliminated' '
	mkdir -p deep/subdir &&
	shit init --bare deep/subdir/duplicate.shit &&
	cat >deep/subdir/duplicate.shit/objects/info/alternates <<-\EOF &&
	../../../../C/.shit/objects
	../../../../A/.shit/objects
	EOF
	cat >expect <<-EOF &&
	alternate: $(pwd)/C/.shit/objects
	alternate: $(pwd)/B/.shit/objects
	alternate: $(pwd)/A/.shit/objects
	EOF
	shit -C deep/subdir/duplicate.shit count-objects -v >actual &&
	grep ^alternate: actual >actual.alternates &&
	test_cmp expect actual.alternates
'

test_expect_success CASE_INSENSITIVE_FS 'dup finding can be case-insensitive' '
	shit init --bare insensitive.shit &&
	# the previous entry for "A" will have used uppercase
	cat >insensitive.shit/objects/info/alternates <<-\EOF &&
	../../C/.shit/objects
	../../a/.shit/objects
	EOF
	cat >expect <<-EOF &&
	alternate: $(pwd)/C/.shit/objects
	alternate: $(pwd)/B/.shit/objects
	alternate: $(pwd)/A/.shit/objects
	EOF
	shit -C insensitive.shit count-objects -v >actual &&
	grep ^alternate: actual >actual.alternates &&
	test_cmp expect actual.alternates
'

test_done
