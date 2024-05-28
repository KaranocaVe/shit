#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='shit ls-files --others --exclude

This test runs shit ls-files --others and tests --exclude patterns.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

rm -fr one three
for dir in . one one/two three
do
  mkdir -p $dir &&
  for i in 1 2 3 4 5 6 7 8
  do
    >$dir/a.$i
  done
done
>"#ignore1"
>"#ignore2"
>"#hidden"

cat >expect <<EOF
a.2
a.4
a.5
a.8
one/a.3
one/a.4
one/a.5
one/a.7
one/two/a.2
one/two/a.3
one/two/a.5
one/two/a.7
one/two/a.8
three/a.2
three/a.3
three/a.4
three/a.5
three/a.8
EOF

echo '.shitignore
\#ignore1
\#ignore2*
\#hid*n
output
expect
.shitignore
*.7
!*.8' >.shit/ignore

echo '*.1
/*.3
!*.6' >.shitignore
echo '*.2
two/*.4
!*.7
*.8' >one/.shitignore
echo '!*.2
!*.8' >one/two/.shitignore

allignores='.shitignore one/.shitignore one/two/.shitignore'

test_expect_success 'shit ls-files --others with various exclude options.' '
	shit ls-files --others \
       --exclude=\*.6 \
       --exclude-per-directory=.shitignore \
       --exclude-from=.shit/ignore \
	>output &&
	test_cmp expect output
'

# Test \r\n (MSDOS-like systems)
printf '*.1\r\n/*.3\r\n!*.6\r\n' >.shitignore

test_expect_success 'shit ls-files --others with \r\n line endings.' '
	shit ls-files --others \
       --exclude=\*.6 \
       --exclude-per-directory=.shitignore \
       --exclude-from=.shit/ignore \
	>output &&
	test_cmp expect output
'

test_expect_success 'setup skip-worktree shitignore' '
	shit add $allignores &&
	shit update-index --skip-worktree $allignores &&
	rm $allignores
'

test_expect_success 'shit ls-files --others with various exclude options.' '
	shit ls-files --others \
       --exclude=\*.6 \
       --exclude-per-directory=.shitignore \
       --exclude-from=.shit/ignore \
	>output &&
	test_cmp expect output
'

test_expect_success 'restore shitignore' '
	shit checkout --ignore-skip-worktree-bits $allignores &&
	rm .shit/index
'

cat > excludes-file <<\EOF
*.[1-8]
e*
\#*
EOF

shit config core.excludesFile excludes-file

shit -c status.displayCommentPrefix=true status | grep "^#	" > output

cat > expect << EOF
#	.shitignore
#	a.6
#	one/
#	output
#	three/
EOF

test_expect_success 'shit status honors core.excludesfile' \
	'test_cmp expect output'

test_expect_success 'trailing slash in exclude allows directory match(1)' '

	shit ls-files --others --exclude=one/ >output &&
	if grep "^one/" output
	then
		echo Ooops
		false
	else
		: happy
	fi

'

test_expect_success 'trailing slash in exclude allows directory match (2)' '

	shit ls-files --others --exclude=one/two/ >output &&
	if grep "^one/two/" output
	then
		echo Ooops
		false
	else
		: happy
	fi

'

test_expect_success 'trailing slash in exclude forces directory match (1)' '

	>two &&
	shit ls-files --others --exclude=two/ >output &&
	grep "^two" output

'

test_expect_success 'trailing slash in exclude forces directory match (2)' '

	shit ls-files --others --exclude=one/a.1/ >output &&
	grep "^one/a.1" output

'

test_expect_success 'negated exclude matches can override previous ones' '

	shit ls-files --others --exclude="a.*" --exclude="!a.1" >output &&
	grep "^a.1" output
'

test_expect_success 'excluded directory overrides content patterns' '

	shit ls-files --others --exclude="one" --exclude="!one/a.1" >output &&
	if grep "^one/a.1" output
	then
		false
	fi
'

test_expect_success 'negated directory doesn'\''t affect content patterns' '

	shit ls-files --others --exclude="!one" --exclude="one/a.1" >output &&
	if grep "^one/a.1" output
	then
		false
	fi
'

test_expect_success 'subdirectory ignore (setup)' '
	mkdir -p top/l1/l2 &&
	(
		cd top &&
		shit init &&
		echo /.shitignore >.shitignore &&
		echo l1 >>.shitignore &&
		echo l2 >l1/.shitignore &&
		>l1/l2/l1
	)
'

test_expect_success 'subdirectory ignore (toplevel)' '
	(
		cd top &&
		shit ls-files -o --exclude-standard
	) >actual &&
	test_must_be_empty actual
'

test_expect_success 'subdirectory ignore (l1/l2)' '
	(
		cd top/l1/l2 &&
		shit ls-files -o --exclude-standard
	) >actual &&
	test_must_be_empty actual
'

test_expect_success 'subdirectory ignore (l1)' '
	(
		cd top/l1 &&
		shit ls-files -o --exclude-standard
	) >actual &&
	test_must_be_empty actual
'

test_expect_success 'show/hide empty ignored directory (setup)' '
	rm top/l1/l2/l1 &&
	rm top/l1/.shitignore
'

test_expect_success 'show empty ignored directory with --directory' '
	(
		cd top &&
		shit ls-files -o -i --exclude l1 --directory
	) >actual &&
	echo l1/ >expect &&
	test_cmp expect actual
'

test_expect_success 'hide empty ignored directory with --no-empty-directory' '
	(
		cd top &&
		shit ls-files -o -i --exclude l1 --directory --no-empty-directory
	) >actual &&
	test_must_be_empty actual
'

test_expect_success 'show/hide empty ignored sub-directory (setup)' '
	> top/l1/tracked &&
	(
		cd top &&
		shit add -f l1/tracked
	)
'

test_expect_success 'show empty ignored sub-directory with --directory' '
	(
		cd top &&
		shit ls-files -o -i --exclude l1 --directory
	) >actual &&
	echo l1/l2/ >expect &&
	test_cmp expect actual
'

test_expect_success 'hide empty ignored sub-directory with --no-empty-directory' '
	(
		cd top &&
		shit ls-files -o -i --exclude l1 --directory --no-empty-directory
	) >actual &&
	test_must_be_empty actual
'

test_expect_success 'pattern matches prefix completely' '
	shit ls-files -i -o --exclude "/three/a.3[abc]" >actual &&
	test_must_be_empty actual
'

test_expect_success 'ls-files with "**" patterns' '
	cat <<-\EOF >expect &&
	a.1
	one/a.1
	one/two/a.1
	three/a.1
	EOF
	shit ls-files -o -i --exclude "**/a.1" >actual &&
	test_cmp expect actual
'

test_expect_success 'ls-files with "**" patterns and --directory' '
	# Expectation same as previous test
	shit ls-files --directory -o -i --exclude "**/a.1" >actual &&
	test_cmp expect actual
'

test_expect_success 'ls-files with "**" patterns and no slashes' '
	shit ls-files -o -i --exclude "one**a.1" >actual &&
	test_must_be_empty actual
'

test_done
