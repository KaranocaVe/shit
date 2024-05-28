#!/bin/sh

test_description='test case exclude pathspec'

. ./test-lib.sh

test_expect_success 'setup' '
	for p in file sub/file sub/sub/file sub/file2 sub/sub/sub/file sub2/file; do
		if echo $p | grep /; then
			mkdir -p $(dirname $p)
		fi &&
		: >$p &&
		shit add $p &&
		shit commit -m $p || return 1
	done &&
	shit log --oneline --format=%s >actual &&
	cat <<EOF >expect &&
sub2/file
sub/sub/sub/file
sub/file2
sub/sub/file
sub/file
file
EOF
	test_cmp expect actual
'

test_expect_success 'exclude only pathspec uses default implicit pathspec' '
	shit log --oneline --format=%s -- . ":(exclude)sub" >expect &&
	shit log --oneline --format=%s -- ":(exclude)sub" >actual &&
	test_cmp expect actual
'

test_expect_success 't_e_i() exclude sub' '
	shit log --oneline --format=%s -- . ":(exclude)sub" >actual &&
	cat <<EOF >expect &&
sub2/file
file
EOF
	test_cmp expect actual
'

test_expect_success 't_e_i() exclude sub/sub/file' '
	shit log --oneline --format=%s -- . ":(exclude)sub/sub/file" >actual &&
	cat <<EOF >expect &&
sub2/file
sub/sub/sub/file
sub/file2
sub/file
file
EOF
	test_cmp expect actual
'

test_expect_success 't_e_i() exclude sub using mnemonic' '
	shit log --oneline --format=%s -- . ":!sub" >actual &&
	cat <<EOF >expect &&
sub2/file
file
EOF
	test_cmp expect actual
'

test_expect_success 't_e_i() exclude :(icase)SUB' '
	shit log --oneline --format=%s -- . ":(exclude,icase)SUB" >actual &&
	cat <<EOF >expect &&
sub2/file
file
EOF
	test_cmp expect actual
'

test_expect_success 't_e_i() exclude sub2 from sub' '
	(
	cd sub &&
	shit log --oneline --format=%s -- :/ ":/!sub2" >actual &&
	cat <<EOF >expect &&
sub/sub/sub/file
sub/file2
sub/sub/file
sub/file
file
EOF
	test_cmp expect actual
	)
'

test_expect_success 't_e_i() exclude sub/*file' '
	shit log --oneline --format=%s -- . ":(exclude)sub/*file" >actual &&
	cat <<EOF >expect &&
sub2/file
sub/file2
file
EOF
	test_cmp expect actual
'

test_expect_success 't_e_i() exclude :(glob)sub/*/file' '
	shit log --oneline --format=%s -- . ":(exclude,glob)sub/*/file" >actual &&
	cat <<EOF >expect &&
sub2/file
sub/sub/sub/file
sub/file2
sub/file
file
EOF
	test_cmp expect actual
'

test_expect_success 'm_p_d() exclude sub' '
	shit ls-files -- . ":(exclude)sub" >actual &&
	cat <<EOF >expect &&
file
sub2/file
EOF
	test_cmp expect actual
'

test_expect_success 'm_p_d() exclude sub/sub/file' '
	shit ls-files -- . ":(exclude)sub/sub/file" >actual &&
	cat <<EOF >expect &&
file
sub/file
sub/file2
sub/sub/sub/file
sub2/file
EOF
	test_cmp expect actual
'

test_expect_success 'm_p_d() exclude sub using mnemonic' '
	shit ls-files -- . ":!sub" >actual &&
	cat <<EOF >expect &&
file
sub2/file
EOF
	test_cmp expect actual
'

test_expect_success 'm_p_d() exclude :(icase)SUB' '
	shit ls-files -- . ":(exclude,icase)SUB" >actual &&
	cat <<EOF >expect &&
file
sub2/file
EOF
	test_cmp expect actual
'

test_expect_success 'm_p_d() exclude sub2 from sub' '
	(
	cd sub &&
	shit ls-files -- :/ ":/!sub2" >actual &&
	cat <<EOF >expect &&
../file
file
file2
sub/file
sub/sub/file
EOF
	test_cmp expect actual
	)
'

test_expect_success 'm_p_d() exclude sub/*file' '
	shit ls-files -- . ":(exclude)sub/*file" >actual &&
	cat <<EOF >expect &&
file
sub/file2
sub2/file
EOF
	test_cmp expect actual
'

test_expect_success 'm_p_d() exclude :(glob)sub/*/file' '
	shit ls-files -- . ":(exclude,glob)sub/*/file" >actual &&
	cat <<EOF >expect &&
file
sub/file
sub/file2
sub/sub/sub/file
sub2/file
EOF
	test_cmp expect actual
'

test_expect_success 'multiple exclusions' '
	shit ls-files -- ":^*/file2" ":^sub2" >actual &&
	cat <<-\EOF >expect &&
	file
	sub/file
	sub/sub/file
	sub/sub/sub/file
	EOF
	test_cmp expect actual
'

test_expect_success 't_e_i() exclude case #8' '
	test_when_finished "rm -fr case8" &&
	shit init case8 &&
	(
		cd case8 &&
		echo file >file1 &&
		echo file >file2 &&
		shit add file1 file2 &&
		shit commit -m twofiles &&
		shit grep -l file HEAD :^file2 >actual &&
		echo HEAD:file1 >expected &&
		test_cmp expected actual &&
		shit grep -l file HEAD :^file1 >actual &&
		echo HEAD:file2 >expected &&
		test_cmp expected actual
	)
'

test_expect_success 'grep --untracked PATTERN' '
	# This test is not an actual test of exclude patterns, rather it
	# is here solely to ensure that if any tests are inserted, deleted, or
	# changed above, that we still have untracked files with the expected
	# contents for the NEXT two tests.
	cat <<-\EOF >expect-grep &&
	actual
	expect
	sub/actual
	sub/expect
	EOF
	shit grep -l --untracked file -- >actual-grep &&
	test_cmp expect-grep actual-grep
'

test_expect_success 'grep --untracked PATTERN :(exclude)DIR' '
	cat <<-\EOF >expect-grep &&
	actual
	expect
	EOF
	shit grep -l --untracked file -- ":(exclude)sub" >actual-grep &&
	test_cmp expect-grep actual-grep
'

test_expect_success 'grep --untracked PATTERN :(exclude)*FILE' '
	cat <<-\EOF >expect-grep &&
	actual
	sub/actual
	EOF
	shit grep -l --untracked file -- ":(exclude)*expect" >actual-grep &&
	test_cmp expect-grep actual-grep
'

# Depending on the command, all negative pathspec needs to subtract
# either from the full tree, or from the current directory.
#
# The sample tree checked out at this point has:
# file
# sub/file
# sub/file2
# sub/sub/file
# sub/sub/sub/file
# sub2/file
#
# but there may also be some cruft that interferes with "shit clean"
# and "shit add" tests.

test_expect_success 'archive with all negative' '
	shit reset --hard &&
	shit clean -f &&
	shit -C sub archive --format=tar HEAD -- ":!sub/" >archive &&
	"$TAR" tf archive >actual &&
	cat >expect <<-\EOF &&
	file
	file2
	EOF
	test_cmp expect actual
'

test_expect_success 'add with all negative' '
	H=$(shit rev-parse HEAD) &&
	shit reset --hard $H &&
	shit clean -f &&
	test_when_finished "shit reset --hard $H" &&
	for path in file sub/file sub/sub/file sub2/file
	do
		echo smudge >>"$path" || return 1
	done &&
	shit -C sub add -- ":!sub/" &&
	shit diff --name-only --no-renames --cached >actual &&
	cat >expect <<-\EOF &&
	file
	sub/file
	sub2/file
	EOF
	test_cmp expect actual &&
	shit diff --name-only --no-renames >actual &&
	echo sub/sub/file >expect &&
	test_cmp expect actual
'

test_expect_success 'add -p with all negative' '
	H=$(shit rev-parse HEAD) &&
	shit reset --hard $H &&
	shit clean -f &&
	test_when_finished "shit reset --hard $H" &&
	for path in file sub/file sub/sub/file sub2/file
	do
		echo smudge >>"$path" || return 1
	done &&
	yes | shit -C sub add -p -- ":!sub/" &&
	shit diff --name-only --no-renames --cached >actual &&
	cat >expect <<-\EOF &&
	file
	sub/file
	sub2/file
	EOF
	test_cmp expect actual &&
	shit diff --name-only --no-renames >actual &&
	echo sub/sub/file >expect &&
	test_cmp expect actual
'

test_expect_success 'clean with all negative' '
	H=$(shit rev-parse HEAD) &&
	shit reset --hard $H &&
	test_when_finished "shit reset --hard $H && shit clean -f" &&
	shit clean -f &&
	for path in file9 sub/file9 sub/sub/file9 sub2/file9
	do
		echo cruft >"$path" || return 1
	done &&
	shit -C sub clean -f -- ":!sub" &&
	test_path_is_file file9 &&
	test_path_is_missing sub/file9 &&
	test_path_is_file sub/sub/file9 &&
	test_path_is_file sub2/file9
'

test_expect_success 'commit with all negative' '
	H=$(shit rev-parse HEAD) &&
	shit reset --hard $H &&
	test_when_finished "shit reset --hard $H" &&
	for path in file sub/file sub/sub/file sub2/file
	do
		echo smudge >>"$path" || return 1
	done &&
	shit -C sub commit -m sample -- ":!sub/" &&
	shit diff --name-only --no-renames HEAD^ HEAD >actual &&
	cat >expect <<-\EOF &&
	file
	sub/file
	sub2/file
	EOF
	test_cmp expect actual &&
	shit diff --name-only --no-renames HEAD >actual &&
	echo sub/sub/file >expect &&
	test_cmp expect actual
'

test_expect_success 'reset with all negative' '
	H=$(shit rev-parse HEAD) &&
	shit reset --hard $H &&
	test_when_finished "shit reset --hard $H" &&
	for path in file sub/file sub/sub/file sub2/file
	do
		echo smudge >>"$path" &&
		shit add "$path" || return 1
	done &&
	shit -C sub reset --quiet -- ":!sub/" &&
	shit diff --name-only --no-renames --cached >actual &&
	echo sub/sub/file >expect &&
	test_cmp expect actual
'

test_expect_success 'grep with all negative' '
	H=$(shit rev-parse HEAD) &&
	shit reset --hard $H &&
	test_when_finished "shit reset --hard $H" &&
	for path in file sub/file sub/sub/file sub2/file
	do
		echo "needle $path" >>"$path" || return 1
	done &&
	shit -C sub grep -h needle -- ":!sub/" >actual &&
	cat >expect <<-\EOF &&
	needle sub/file
	EOF
	test_cmp expect actual
'

test_expect_success 'ls-files with all negative' '
	shit reset --hard &&
	shit -C sub ls-files -- ":!sub/" >actual &&
	cat >expect <<-\EOF &&
	file
	file2
	EOF
	test_cmp expect actual
'

test_expect_success 'rm with all negative' '
	shit reset --hard &&
	test_when_finished "shit reset --hard" &&
	shit -C sub rm -r --cached -- ":!sub/" >actual &&
	shit diff --name-only --no-renames --diff-filter=D --cached >actual &&
	cat >expect <<-\EOF &&
	sub/file
	sub/file2
	EOF
	test_cmp expect actual
'

test_expect_success 'stash with all negative' '
	H=$(shit rev-parse HEAD) &&
	shit reset --hard $H &&
	test_when_finished "shit reset --hard $H" &&
	for path in file sub/file sub/sub/file sub2/file
	do
		echo smudge >>"$path" || return 1
	done &&
	shit -C sub stash defecate -m sample -- ":!sub/" &&
	shit diff --name-only --no-renames HEAD >actual &&
	echo sub/sub/file >expect &&
	test_cmp expect actual &&
	shit stash show --name-only >actual &&
	cat >expect <<-\EOF &&
	file
	sub/file
	sub2/file
	EOF
	test_cmp expect actual
'

test_done
