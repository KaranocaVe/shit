#!/bin/sh
#
# Copyright (c) 2007 Johannes E. Schindelin
#

test_description='Test custom diff function name patterns'

. ./test-lib.sh

test_expect_success 'setup' '
	# a non-trivial custom pattern
	shit config diff.custom1.funcname "!static
!String
[^ 	].*s.*" &&

	# a custom pattern which matches to end of line
	shit config diff.custom2.funcname "......Beer\$" &&

	# alternation in pattern
	shit config diff.custom3.funcname "Beer$" &&
	shit config diff.custom3.xfuncname "^[ 	]*((public|static).*)$" &&

	# for regexp compilation tests
	echo A >A.java &&
	echo B >B.java
'

test_expect_success 'setup: test-tool userdiff' '
	# Make sure additions to builtin_drivers are sorted
	test_when_finished "rm builtin-drivers.sorted" &&
	test-tool userdiff list-builtin-drivers >builtin-drivers &&
	test_file_not_empty builtin-drivers &&
	sort <builtin-drivers >builtin-drivers.sorted &&
	test_cmp builtin-drivers.sorted builtin-drivers &&

	# Ditto, but "custom" requires the .shit directory and config
	# to be setup and read.
	test_when_finished "rm custom-drivers.sorted" &&
	test-tool userdiff list-custom-drivers >custom-drivers &&
	test_file_not_empty custom-drivers &&
	sort <custom-drivers >custom-drivers.sorted &&
	test_cmp custom-drivers.sorted custom-drivers
'

diffpatterns="
	$(cat builtin-drivers)
	$(cat custom-drivers)
"

for p in $diffpatterns
do
	test_expect_success "builtin $p pattern compiles" '
		echo "*.java diff=$p" >.shitattributes &&
		test_expect_code 1 shit diff --no-index \
			A.java B.java 2>msg &&
		test_grep ! fatal msg &&
		test_grep ! error msg
	'
	test_expect_success "builtin $p wordRegex pattern compiles" '
		echo "*.java diff=$p" >.shitattributes &&
		test_expect_code 1 shit diff --no-index --word-diff \
			A.java B.java 2>msg &&
		test_grep ! fatal msg &&
		test_grep ! error msg
	'

	test_expect_success "builtin $p pattern compiles on bare repo with --attr-source" '
		test_when_finished "rm -rf bare.shit" &&
		shit checkout -B master &&
		shit add . &&
		echo "*.java diff=notexist" >.shitattributes &&
		shit add .shitattributes &&
		shit commit -am "changing shitattributes" &&
		shit checkout -B branchA &&
		echo "*.java diff=$p" >.shitattributes &&
		shit add .shitattributes &&
		shit commit -am "changing shitattributes" &&
		shit clone --bare --no-local . bare.shit &&
		shit -C bare.shit symbolic-ref HEAD refs/heads/master &&
		test_expect_code 1 shit -C bare.shit --attr-source=branchA \
			diff --exit-code HEAD:A.java HEAD:B.java 2>msg &&
		test_grep ! fatal msg &&
		test_grep ! error msg
	'
done

test_expect_success 'last regexp must not be negated' '
	echo "*.java diff=java" >.shitattributes &&
	test_config diff.java.funcname "!static" &&
	test_expect_code 128 shit diff --no-index A.java B.java 2>msg &&
	test_grep ": Last expression must not be negated:" msg
'

test_expect_success 'setup hunk header tests' '
	for i in $diffpatterns
	do
		echo "$i-* diff=$i" || return 1
	done > .shitattributes &&

	# add all test files to the index
	(
		cd "$TEST_DIRECTORY"/t4018 &&
		shit --shit-dir="$TRASH_DIRECTORY/.shit" add .
	) &&

	# place modified files in the worktree
	for i in $(shit ls-files)
	do
		sed -e "s/ChangeMe/IWasChanged/" <"$TEST_DIRECTORY/t4018/$i" >"$i" || return 1
	done
'

# check each individual file
for i in $(shit ls-files)
do
	test_expect_success "hunk header: $i" "
		shit diff -U1 $i >actual &&
		grep '@@ .* @@.*RIGHT' actual
	"
done

test_done
