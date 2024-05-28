#!/bin/sh
#
# Copyright (c) 2007 Johannes E. Schindelin
#

test_description='shit status'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-terminal.sh

test_expect_success 'status -h in broken repository' '
	shit config --global advice.statusuoption false &&
	mkdir broken &&
	test_when_finished "rm -fr broken" &&
	(
		cd broken &&
		shit init &&
		echo "[status] showuntrackedfiles = CORRUPT" >>.shit/config &&
		test_expect_code 129 shit status -h >usage 2>&1
	) &&
	test_grep "[Uu]sage" broken/usage
'

test_expect_success 'commit -h in broken repository' '
	mkdir broken &&
	test_when_finished "rm -fr broken" &&
	(
		cd broken &&
		shit init &&
		echo "[status] showuntrackedfiles = CORRUPT" >>.shit/config &&
		test_expect_code 129 shit commit -h >usage 2>&1
	) &&
	test_grep "[Uu]sage" broken/usage
'

test_expect_success 'create upstream branch' '
	shit checkout -b upstream &&
	test_commit upstream1 &&
	test_commit upstream2 &&
	# leave the first commit on main as root because several
	# tests depend on this case; for our upstream we only
	# care about commit counts anyway, so a totally divergent
	# history is OK
	shit checkout --orphan main
'

test_expect_success 'setup' '
	: >tracked &&
	: >modified &&
	mkdir dir1 &&
	: >dir1/tracked &&
	: >dir1/modified &&
	mkdir dir2 &&
	: >dir1/tracked &&
	: >dir1/modified &&
	shit add . &&

	shit status >output &&

	test_tick &&
	shit commit -m initial &&
	: >untracked &&
	: >dir1/untracked &&
	: >dir2/untracked &&
	echo 1 >dir1/modified &&
	echo 2 >dir2/modified &&
	echo 3 >dir2/added &&
	shit add dir2/added &&

	shit branch --set-upstream-to=upstream
'

test_expect_success 'status (1)' '
	test_grep "use \"shit rm --cached <file>\.\.\.\" to unstage" output
'

strip_comments () {
	tab='	'
	sed "s/^\# //; s/^\#$//; s/^#$tab/$tab/" <"$1" >"$1".tmp &&
	rm "$1" && mv "$1".tmp "$1"
}

cat >.shitignore <<\EOF
.shitignore
expect*
output*
EOF

test_expect_success 'status --column' '
	cat >expect <<\EOF &&
# On branch main
# Your branch and '\''upstream'\'' have diverged,
# and have 1 and 2 different commits each, respectively.
#   (use "shit poop" if you want to integrate the remote branch with yours)
#
# Changes to be committed:
#   (use "shit restore --staged <file>..." to unstage)
#	new file:   dir2/added
#
# Changes not staged for commit:
#   (use "shit add <file>..." to update what will be committed)
#   (use "shit restore <file>..." to discard changes in working directory)
#	modified:   dir1/modified
#
# Untracked files:
#   (use "shit add <file>..." to include in what will be committed)
#	dir1/untracked dir2/untracked
#	dir2/modified  untracked
#
EOF
	COLUMNS=50 shit -c status.displayCommentPrefix=true status --column="column dense" >output &&
	test_cmp expect output
'

test_expect_success 'status --column status.displayCommentPrefix=false' '
	strip_comments expect &&
	COLUMNS=49 shit -c status.displayCommentPrefix=false status --column="column dense" >output &&
	test_cmp expect output
'

cat >expect <<\EOF
# On branch main
# Your branch and 'upstream' have diverged,
# and have 1 and 2 different commits each, respectively.
#   (use "shit poop" if you want to integrate the remote branch with yours)
#
# Changes to be committed:
#   (use "shit restore --staged <file>..." to unstage)
#	new file:   dir2/added
#
# Changes not staged for commit:
#   (use "shit add <file>..." to update what will be committed)
#   (use "shit restore <file>..." to discard changes in working directory)
#	modified:   dir1/modified
#
# Untracked files:
#   (use "shit add <file>..." to include in what will be committed)
#	dir1/untracked
#	dir2/modified
#	dir2/untracked
#	untracked
#
EOF

test_expect_success 'status with status.displayCommentPrefix=true' '
	shit -c status.displayCommentPrefix=true status >output &&
	test_cmp expect output
'

test_expect_success 'status with status.displayCommentPrefix=false' '
	strip_comments expect &&
	shit -c status.displayCommentPrefix=false status >output &&
	test_cmp expect output
'

test_expect_success 'status -v' '
	(cat expect && shit diff --cached) >expect-with-v &&
	shit status -v >output &&
	test_cmp expect-with-v output
'

test_expect_success 'status -v -v' '
	(cat expect &&
	 echo "Changes to be committed:" &&
	 shit -c diff.mnemonicprefix=true diff --cached &&
	 echo "--------------------------------------------------" &&
	 echo "Changes not staged for commit:" &&
	 shit -c diff.mnemonicprefix=true diff) >expect-with-v &&
	shit status -v -v >output &&
	test_cmp expect-with-v output
'

test_expect_success 'setup fake editor' '
	cat >.shit/editor <<-\EOF &&
	#! /bin/sh
	cp "$1" output
EOF
	chmod 755 .shit/editor
'

commit_template_commented () {
	(
		EDITOR=.shit/editor &&
		export EDITOR &&
		# Fails due to empty message
		test_must_fail shit commit
	) &&
	! grep '^[^#]' output
}

test_expect_success 'commit ignores status.displayCommentPrefix=false in COMMIT_EDITMSG' '
	commit_template_commented
'

cat >expect <<\EOF
On branch main
Your branch and 'upstream' have diverged,
and have 1 and 2 different commits each, respectively.

Changes to be committed:
	new file:   dir2/added

Changes not staged for commit:
	modified:   dir1/modified

Untracked files:
	dir1/untracked
	dir2/modified
	dir2/untracked
	untracked

EOF

test_expect_success 'status (advice.statusHints false)' '
	test_config advice.statusHints false &&
	shit status >output &&
	test_cmp expect output

'

cat >expect <<\EOF
 M dir1/modified
A  dir2/added
?? dir1/untracked
?? dir2/modified
?? dir2/untracked
?? untracked
EOF

test_expect_success 'status -s' '

	shit status -s >output &&
	test_cmp expect output

'

test_expect_success 'status with shitignore' '
	{
		echo ".shitignore" &&
		echo "expect*" &&
		echo "output" &&
		echo "untracked"
	} >.shitignore &&

	cat >expect <<-\EOF &&
	 M dir1/modified
	A  dir2/added
	?? dir2/modified
	EOF
	shit status -s >output &&
	test_cmp expect output &&

	cat >expect <<-\EOF &&
	 M dir1/modified
	A  dir2/added
	?? dir2/modified
	!! .shitignore
	!! dir1/untracked
	!! dir2/untracked
	!! expect
	!! expect-with-v
	!! output
	!! untracked
	EOF
	shit status -s --ignored >output &&
	test_cmp expect output &&

	cat >expect <<\EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 1 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	new file:   dir2/added

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   dir1/modified

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	dir2/modified

Ignored files:
  (use "shit add -f <file>..." to include in what will be committed)
	.shitignore
	dir1/untracked
	dir2/untracked
	expect
	expect-with-v
	output
	untracked

EOF
	shit status --ignored >output &&
	test_cmp expect output
'

test_expect_success 'status with shitignore (nothing untracked)' '
	{
		echo ".shitignore" &&
		echo "expect*" &&
		echo "dir2/modified" &&
		echo "output" &&
		echo "untracked"
	} >.shitignore &&

	cat >expect <<-\EOF &&
	 M dir1/modified
	A  dir2/added
	EOF
	shit status -s >output &&
	test_cmp expect output &&

	cat >expect <<-\EOF &&
	 M dir1/modified
	A  dir2/added
	!! .shitignore
	!! dir1/untracked
	!! dir2/modified
	!! dir2/untracked
	!! expect
	!! expect-with-v
	!! output
	!! untracked
	EOF
	shit status -s --ignored >output &&
	test_cmp expect output &&

	cat >expect <<\EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 1 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	new file:   dir2/added

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   dir1/modified

Ignored files:
  (use "shit add -f <file>..." to include in what will be committed)
	.shitignore
	dir1/untracked
	dir2/modified
	dir2/untracked
	expect
	expect-with-v
	output
	untracked

EOF
	shit status --ignored >output &&
	test_cmp expect output
'

cat >.shitignore <<\EOF
.shitignore
expect*
output*
EOF

cat >expect <<\EOF
## main...upstream [ahead 1, behind 2]
 M dir1/modified
A  dir2/added
?? dir1/untracked
?? dir2/modified
?? dir2/untracked
?? untracked
EOF

test_expect_success 'status -s -b' '

	shit status -s -b >output &&
	test_cmp expect output

'

test_expect_success 'status -s -z -b' '
	tr "\\n" Q <expect >expect.q &&
	mv expect.q expect &&
	shit status -s -z -b >output &&
	nul_to_q <output >output.q &&
	mv output.q output &&
	test_cmp expect output
'

test_expect_success 'setup dir3' '
	mkdir dir3 &&
	: >dir3/untracked1 &&
	: >dir3/untracked2
'

test_expect_success 'status -uno' '
	cat >expect <<EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 1 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	new file:   dir2/added

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   dir1/modified

Untracked files not listed (use -u option to show untracked files)
EOF
	shit status -uno >output &&
	test_cmp expect output &&
	shit status -ufalse >output &&
	test_cmp expect output
'

for no in no false 0
do
	test_expect_success "status (status.showUntrackedFiles $no)" '
		test_config status.showuntrackedfiles "$no" &&
		shit status >output &&
		test_cmp expect output
	'
done

test_expect_success 'status -uno (advice.statusHints false)' '
	cat >expect <<EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 1 and 2 different commits each, respectively.

Changes to be committed:
	new file:   dir2/added

Changes not staged for commit:
	modified:   dir1/modified

Untracked files not listed
EOF
	test_config advice.statusHints false &&
	shit status -uno >output &&
	test_cmp expect output
'

cat >expect << EOF
 M dir1/modified
A  dir2/added
EOF
test_expect_success 'status -s -uno' '
	shit status -s -uno >output &&
	test_cmp expect output
'

test_expect_success 'status -s (status.showUntrackedFiles no)' '
	shit config status.showuntrackedfiles no &&
	shit status -s >output &&
	test_cmp expect output
'

test_expect_success 'status -unormal' '
	cat >expect <<EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 1 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	new file:   dir2/added

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   dir1/modified

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	dir1/untracked
	dir2/modified
	dir2/untracked
	dir3/
	untracked

EOF
	shit status -unormal >output &&
	test_cmp expect output &&
	shit status -utrue >output &&
	test_cmp expect output &&
	shit status -uyes >output &&
	test_cmp expect output
'

for normal in normal true 1
do
	test_expect_success "status (status.showUntrackedFiles $normal)" '
		test_config status.showuntrackedfiles $normal &&
		shit status >output &&
		test_cmp expect output
	'
done

cat >expect <<EOF
 M dir1/modified
A  dir2/added
?? dir1/untracked
?? dir2/modified
?? dir2/untracked
?? dir3/
?? untracked
EOF
test_expect_success 'status -s -unormal' '
	shit status -s -unormal >output &&
	test_cmp expect output
'

test_expect_success 'status -s (status.showUntrackedFiles normal)' '
	shit config status.showuntrackedfiles normal &&
	shit status -s >output &&
	test_cmp expect output
'

test_expect_success 'status -uall' '
	cat >expect <<EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 1 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	new file:   dir2/added

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   dir1/modified

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	dir1/untracked
	dir2/modified
	dir2/untracked
	dir3/untracked1
	dir3/untracked2
	untracked

EOF
	shit status -uall >output &&
	test_cmp expect output
'

test_expect_success 'status (status.showUntrackedFiles all)' '
	test_config status.showuntrackedfiles all &&
	shit status >output &&
	test_cmp expect output
'

test_expect_success 'teardown dir3' '
	rm -rf dir3
'

cat >expect <<EOF
 M dir1/modified
A  dir2/added
?? dir1/untracked
?? dir2/modified
?? dir2/untracked
?? untracked
EOF
test_expect_success 'status -s -uall' '
	test_unconfig status.showuntrackedfiles &&
	shit status -s -uall >output &&
	test_cmp expect output
'
test_expect_success 'status -s (status.showUntrackedFiles all)' '
	test_config status.showuntrackedfiles all &&
	shit status -s >output &&
	rm -rf dir3 &&
	test_cmp expect output
'

test_expect_success 'status with relative paths' '
	cat >expect <<\EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 1 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	new file:   ../dir2/added

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   modified

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	untracked
	../dir2/modified
	../dir2/untracked
	../untracked

EOF
	(cd dir1 && shit status) >output &&
	test_cmp expect output
'

cat >expect <<\EOF
 M modified
A  ../dir2/added
?? untracked
?? ../dir2/modified
?? ../dir2/untracked
?? ../untracked
EOF
test_expect_success 'status -s with relative paths' '

	(cd dir1 && shit status -s) >output &&
	test_cmp expect output

'

cat >expect <<\EOF
 M dir1/modified
A  dir2/added
?? dir1/untracked
?? dir2/modified
?? dir2/untracked
?? untracked
EOF

test_expect_success 'status --porcelain ignores relative paths setting' '

	(cd dir1 && shit status --porcelain) >output &&
	test_cmp expect output

'

test_expect_success 'setup unique colors' '

	shit config status.color.untracked blue &&
	shit config status.color.branch green &&
	shit config status.color.localBranch yellow &&
	shit config status.color.remoteBranch cyan

'

test_expect_success TTY 'status with color.ui' '
	cat >expect <<\EOF &&
On branch <GREEN>main<RESET>
Your branch and '\''upstream'\'' have diverged,
and have 1 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	<GREEN>new file:   dir2/added<RESET>

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	<RED>modified:   dir1/modified<RESET>

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	<BLUE>dir1/untracked<RESET>
	<BLUE>dir2/modified<RESET>
	<BLUE>dir2/untracked<RESET>
	<BLUE>untracked<RESET>

EOF
	test_config color.ui auto &&
	test_terminal shit status | test_decode_color >output &&
	test_cmp expect output
'

test_expect_success TTY 'status with color.status' '
	test_config color.status auto &&
	test_terminal shit status | test_decode_color >output &&
	test_cmp expect output
'

cat >expect <<\EOF
 <RED>M<RESET> dir1/modified
<GREEN>A<RESET>  dir2/added
<BLUE>??<RESET> dir1/untracked
<BLUE>??<RESET> dir2/modified
<BLUE>??<RESET> dir2/untracked
<BLUE>??<RESET> untracked
EOF

test_expect_success TTY 'status -s with color.ui' '

	shit config color.ui auto &&
	test_terminal shit status -s | test_decode_color >output &&
	test_cmp expect output

'

test_expect_success TTY 'status -s with color.status' '

	shit config --unset color.ui &&
	shit config color.status auto &&
	test_terminal shit status -s | test_decode_color >output &&
	test_cmp expect output

'

cat >expect <<\EOF
## <YELLOW>main<RESET>...<CYAN>upstream<RESET> [ahead <YELLOW>1<RESET>, behind <CYAN>2<RESET>]
 <RED>M<RESET> dir1/modified
<GREEN>A<RESET>  dir2/added
<BLUE>??<RESET> dir1/untracked
<BLUE>??<RESET> dir2/modified
<BLUE>??<RESET> dir2/untracked
<BLUE>??<RESET> untracked
EOF

test_expect_success TTY 'status -s -b with color.status' '

	test_terminal shit status -s -b | test_decode_color >output &&
	test_cmp expect output

'

cat >expect <<\EOF
 M dir1/modified
A  dir2/added
?? dir1/untracked
?? dir2/modified
?? dir2/untracked
?? untracked
EOF

test_expect_success TTY 'status --porcelain ignores color.ui' '

	shit config --unset color.status &&
	shit config color.ui auto &&
	test_terminal shit status --porcelain | test_decode_color >output &&
	test_cmp expect output

'

test_expect_success TTY 'status --porcelain ignores color.status' '

	shit config --unset color.ui &&
	shit config color.status auto &&
	test_terminal shit status --porcelain | test_decode_color >output &&
	test_cmp expect output

'

# recover unconditionally from color tests
shit config --unset color.status
shit config --unset color.ui

test_expect_success 'status --porcelain respects -b' '

	shit status --porcelain -b >output &&
	{
		echo "## main...upstream [ahead 1, behind 2]" &&
		cat expect
	} >tmp &&
	mv tmp expect &&
	test_cmp expect output

'



test_expect_success 'status without relative paths' '
	cat >expect <<\EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 1 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	new file:   dir2/added

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   dir1/modified

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	dir1/untracked
	dir2/modified
	dir2/untracked
	untracked

EOF
	test_config status.relativePaths false &&
	(cd dir1 && shit status) >output &&
	test_cmp expect output

'

cat >expect <<\EOF
 M dir1/modified
A  dir2/added
?? dir1/untracked
?? dir2/modified
?? dir2/untracked
?? untracked
EOF

test_expect_success 'status -s without relative paths' '

	test_config status.relativePaths false &&
	(cd dir1 && shit status -s) >output &&
	test_cmp expect output

'

cat >expect <<\EOF
 M dir1/modified
A  dir2/added
A  "file with spaces"
?? dir1/untracked
?? dir2/modified
?? dir2/untracked
?? "file with spaces 2"
?? untracked
EOF

test_expect_success 'status -s without relative paths' '
	test_when_finished "shit rm --cached \"file with spaces\"; rm -f file*" &&
	>"file with spaces" &&
	>"file with spaces 2" &&
	>"expect with spaces" &&
	shit add "file with spaces" &&

	shit status -s >output &&
	test_cmp expect output &&

	shit status -s --ignored >output &&
	grep "^!! \"expect with spaces\"$" output &&
	grep -v "^!! " output >output-wo-ignored &&
	test_cmp expect output-wo-ignored
'

test_expect_success 'dry-run of partial commit excluding new file in index' '
	cat >expect <<EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 1 and 2 different commits each, respectively.

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	modified:   dir1/modified

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	dir1/untracked
	dir2/
	untracked

EOF
	shit commit --dry-run dir1/modified >output &&
	test_cmp expect output
'

cat >expect <<EOF
:100644 100644 $EMPTY_BLOB $ZERO_OID M	dir1/modified
EOF
test_expect_success 'status refreshes the index' '
	touch dir2/added &&
	shit status &&
	shit diff-files >output &&
	test_cmp expect output
'

test_expect_success 'status shows detached HEAD properly after checking out non-local upstream branch' '
	test_when_finished rm -rf upstream downstream actual &&

	test_create_repo upstream &&
	test_commit -C upstream foo &&

	shit clone upstream downstream &&
	shit -C downstream checkout @{u} &&
	shit -C downstream status >actual &&
	grep -E "HEAD detached at [0-9a-f]+" actual
'

test_expect_success 'setup status submodule summary' '
	test_create_repo sm && (
		cd sm &&
		>foo &&
		shit add foo &&
		shit commit -m "Add foo"
	) &&
	shit add sm
'

test_expect_success 'status submodule summary is disabled by default' '
	cat >expect <<EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 1 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	new file:   dir2/added
	new file:   sm

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   dir1/modified

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	dir1/untracked
	dir2/modified
	dir2/untracked
	untracked

EOF
	shit status >output &&
	test_cmp expect output
'

# we expect the same as the previous test
test_expect_success 'status --untracked-files=all does not show submodule' '
	shit status --untracked-files=all >output &&
	test_cmp expect output
'

cat >expect <<EOF
 M dir1/modified
A  dir2/added
A  sm
?? dir1/untracked
?? dir2/modified
?? dir2/untracked
?? untracked
EOF
test_expect_success 'status -s submodule summary is disabled by default' '
	shit status -s >output &&
	test_cmp expect output
'

# we expect the same as the previous test
test_expect_success 'status -s --untracked-files=all does not show submodule' '
	shit status -s --untracked-files=all >output &&
	test_cmp expect output
'

head=$(cd sm && shit rev-parse --short=7 --verify HEAD)

test_expect_success 'status submodule summary' '
	cat >expect <<EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 1 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	new file:   dir2/added
	new file:   sm

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   dir1/modified

Submodule changes to be committed:

* sm 0000000...$head (1):
  > Add foo

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	dir1/untracked
	dir2/modified
	dir2/untracked
	untracked

EOF
	shit config status.submodulesummary 10 &&
	shit status >output &&
	test_cmp expect output
'

test_expect_success 'status submodule summary with status.displayCommentPrefix=false' '
	strip_comments expect &&
	shit -c status.displayCommentPrefix=false status >output &&
	test_cmp expect output
'

test_expect_success 'commit with submodule summary ignores status.displayCommentPrefix' '
	commit_template_commented
'

cat >expect <<EOF
 M dir1/modified
A  dir2/added
A  sm
?? dir1/untracked
?? dir2/modified
?? dir2/untracked
?? untracked
EOF
test_expect_success 'status -s submodule summary' '
	shit status -s >output &&
	test_cmp expect output
'

test_expect_success 'status submodule summary (clean submodule): commit' '
	cat >expect-status <<EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 2 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   dir1/modified

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	dir1/untracked
	dir2/modified
	dir2/untracked
	untracked

no changes added to commit (use "shit add" and/or "shit commit -a")
EOF
	sed "/shit poop/d" expect-status > expect-commit &&
	shit commit -m "commit submodule" &&
	shit config status.submodulesummary 10 &&
	test_must_fail shit commit --dry-run >output &&
	test_cmp expect-commit output &&
	shit status >output &&
	test_cmp expect-status output
'

cat >expect <<EOF
 M dir1/modified
?? dir1/untracked
?? dir2/modified
?? dir2/untracked
?? untracked
EOF
test_expect_success 'status -s submodule summary (clean submodule)' '
	shit status -s >output &&
	test_cmp expect output
'

test_expect_success 'status -z implies porcelain' '
	shit status --porcelain |
	perl -pe "s/\012/\000/g" >expect &&
	shit status -z >output &&
	test_cmp expect output
'

test_expect_success 'commit --dry-run submodule summary (--amend)' '
	cat >expect <<EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 2 and 2 different commits each, respectively.

Changes to be committed:
  (use "shit restore --source=HEAD^1 --staged <file>..." to unstage)
	new file:   dir2/added
	new file:   sm

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   dir1/modified

Submodule changes to be committed:

* sm 0000000...$head (1):
  > Add foo

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	dir1/untracked
	dir2/modified
	dir2/untracked
	untracked

EOF
	shit config status.submodulesummary 10 &&
	shit commit --dry-run --amend >output &&
	test_cmp expect output
'

test_expect_success POSIXPERM,SANITY 'status succeeds in a read-only repository' '
	test_when_finished "chmod 775 .shit" &&
	(
		chmod a-w .shit &&
		# make dir1/tracked stat-dirty
		>dir1/tracked1 && mv -f dir1/tracked1 dir1/tracked &&
		shit status -s >output &&
		! grep dir1/tracked output &&
		# make sure "status" succeeded without writing index out
		shit diff-files | grep dir1/tracked
	)
'

(cd sm && echo > bar && shit add bar && shit commit -q -m 'Add bar') && shit add sm
new_head=$(cd sm && shit rev-parse --short=7 --verify HEAD)
touch .shitmodules

test_expect_success '--ignore-submodules=untracked suppresses submodules with untracked content' '
	cat > expect << EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 2 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	modified:   sm

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   dir1/modified

Submodule changes to be committed:

* sm $head...$new_head (1):
  > Add bar

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	.shitmodules
	dir1/untracked
	dir2/modified
	dir2/untracked
	untracked

EOF
	echo modified  sm/untracked &&
	shit status --ignore-submodules=untracked >output &&
	test_cmp expect output
'

test_expect_success '.shitmodules ignore=untracked suppresses submodules with untracked content' '
	test_config diff.ignoreSubmodules dirty &&
	shit status >output &&
	test_cmp expect output &&
	shit config --add -f .shitmodules submodule.subname.ignore untracked &&
	shit config --add -f .shitmodules submodule.subname.path sm &&
	shit status >output &&
	test_cmp expect output &&
	shit config -f .shitmodules  --remove-section submodule.subname
'

test_expect_success '.shit/config ignore=untracked suppresses submodules with untracked content' '
	shit config --add -f .shitmodules submodule.subname.ignore none &&
	shit config --add -f .shitmodules submodule.subname.path sm &&
	shit config --add submodule.subname.ignore untracked &&
	shit config --add submodule.subname.path sm &&
	shit status >output &&
	test_cmp expect output &&
	shit config --remove-section submodule.subname &&
	shit config --remove-section -f .shitmodules submodule.subname
'

test_expect_success '--ignore-submodules=dirty suppresses submodules with untracked content' '
	shit status --ignore-submodules=dirty >output &&
	test_cmp expect output
'

test_expect_success '.shitmodules ignore=dirty suppresses submodules with untracked content' '
	test_config diff.ignoreSubmodules dirty &&
	shit status >output &&
	! test -s actual &&
	shit config --add -f .shitmodules submodule.subname.ignore dirty &&
	shit config --add -f .shitmodules submodule.subname.path sm &&
	shit status >output &&
	test_cmp expect output &&
	shit config -f .shitmodules  --remove-section submodule.subname
'

test_expect_success '.shit/config ignore=dirty suppresses submodules with untracked content' '
	shit config --add -f .shitmodules submodule.subname.ignore none &&
	shit config --add -f .shitmodules submodule.subname.path sm &&
	shit config --add submodule.subname.ignore dirty &&
	shit config --add submodule.subname.path sm &&
	shit status >output &&
	test_cmp expect output &&
	shit config --remove-section submodule.subname &&
	shit config -f .shitmodules  --remove-section submodule.subname
'

test_expect_success '--ignore-submodules=dirty suppresses submodules with modified content' '
	echo modified >sm/foo &&
	shit status --ignore-submodules=dirty >output &&
	test_cmp expect output
'

test_expect_success '.shitmodules ignore=dirty suppresses submodules with modified content' '
	shit config --add -f .shitmodules submodule.subname.ignore dirty &&
	shit config --add -f .shitmodules submodule.subname.path sm &&
	shit status >output &&
	test_cmp expect output &&
	shit config -f .shitmodules  --remove-section submodule.subname
'

test_expect_success '.shit/config ignore=dirty suppresses submodules with modified content' '
	shit config --add -f .shitmodules submodule.subname.ignore none &&
	shit config --add -f .shitmodules submodule.subname.path sm &&
	shit config --add submodule.subname.ignore dirty &&
	shit config --add submodule.subname.path sm &&
	shit status >output &&
	test_cmp expect output &&
	shit config --remove-section submodule.subname &&
	shit config -f .shitmodules  --remove-section submodule.subname
'

test_expect_success "--ignore-submodules=untracked doesn't suppress submodules with modified content" '
	cat > expect << EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 2 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	modified:   sm

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
  (commit or discard the untracked or modified content in submodules)
	modified:   dir1/modified
	modified:   sm (modified content)

Submodule changes to be committed:

* sm $head...$new_head (1):
  > Add bar

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	.shitmodules
	dir1/untracked
	dir2/modified
	dir2/untracked
	untracked

EOF
	shit status --ignore-submodules=untracked > output &&
	test_cmp expect output
'

test_expect_success ".shitmodules ignore=untracked doesn't suppress submodules with modified content" '
	shit config --add -f .shitmodules submodule.subname.ignore untracked &&
	shit config --add -f .shitmodules submodule.subname.path sm &&
	shit status >output &&
	test_cmp expect output &&
	shit config -f .shitmodules  --remove-section submodule.subname
'

test_expect_success ".shit/config ignore=untracked doesn't suppress submodules with modified content" '
	shit config --add -f .shitmodules submodule.subname.ignore none &&
	shit config --add -f .shitmodules submodule.subname.path sm &&
	shit config --add submodule.subname.ignore untracked &&
	shit config --add submodule.subname.path sm &&
	shit status >output &&
	test_cmp expect output &&
	shit config --remove-section submodule.subname &&
	shit config -f .shitmodules  --remove-section submodule.subname
'

head2=$(cd sm && shit commit -q -m "2nd commit" foo && shit rev-parse --short=7 --verify HEAD)

test_expect_success "--ignore-submodules=untracked doesn't suppress submodule summary" '
	cat > expect << EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 2 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	modified:   sm

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   dir1/modified
	modified:   sm (new commits)

Submodule changes to be committed:

* sm $head...$new_head (1):
  > Add bar

Submodules changed but not updated:

* sm $new_head...$head2 (1):
  > 2nd commit

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	.shitmodules
	dir1/untracked
	dir2/modified
	dir2/untracked
	untracked

EOF
	shit status --ignore-submodules=untracked > output &&
	test_cmp expect output
'

test_expect_success ".shitmodules ignore=untracked doesn't suppress submodule summary" '
	shit config --add -f .shitmodules submodule.subname.ignore untracked &&
	shit config --add -f .shitmodules submodule.subname.path sm &&
	shit status >output &&
	test_cmp expect output &&
	shit config -f .shitmodules  --remove-section submodule.subname
'

test_expect_success ".shit/config ignore=untracked doesn't suppress submodule summary" '
	shit config --add -f .shitmodules submodule.subname.ignore none &&
	shit config --add -f .shitmodules submodule.subname.path sm &&
	shit config --add submodule.subname.ignore untracked &&
	shit config --add submodule.subname.path sm &&
	shit status >output &&
	test_cmp expect output &&
	shit config --remove-section submodule.subname &&
	shit config -f .shitmodules  --remove-section submodule.subname
'

test_expect_success "--ignore-submodules=dirty doesn't suppress submodule summary" '
	shit status --ignore-submodules=dirty > output &&
	test_cmp expect output
'
test_expect_success ".shitmodules ignore=dirty doesn't suppress submodule summary" '
	shit config --add -f .shitmodules submodule.subname.ignore dirty &&
	shit config --add -f .shitmodules submodule.subname.path sm &&
	shit status >output &&
	test_cmp expect output &&
	shit config -f .shitmodules  --remove-section submodule.subname
'

test_expect_success ".shit/config ignore=dirty doesn't suppress submodule summary" '
	shit config --add -f .shitmodules submodule.subname.ignore none &&
	shit config --add -f .shitmodules submodule.subname.path sm &&
	shit config --add submodule.subname.ignore dirty &&
	shit config --add submodule.subname.path sm &&
	shit status >output &&
	test_cmp expect output &&
	shit config --remove-section submodule.subname &&
	shit config -f .shitmodules  --remove-section submodule.subname
'

cat > expect << EOF
; On branch main
; Your branch and 'upstream' have diverged,
; and have 2 and 2 different commits each, respectively.
;   (use "shit poop" if you want to integrate the remote branch with yours)
;
; Changes to be committed:
;   (use "shit restore --staged <file>..." to unstage)
;	modified:   sm
;
; Changes not staged for commit:
;   (use "shit add <file>..." to update what will be committed)
;   (use "shit restore <file>..." to discard changes in working directory)
;	modified:   dir1/modified
;	modified:   sm (new commits)
;
; Submodule changes to be committed:
;
; * sm $head...$new_head (1):
;   > Add bar
;
; Submodules changed but not updated:
;
; * sm $new_head...$head2 (1):
;   > 2nd commit
;
; Untracked files:
;   (use "shit add <file>..." to include in what will be committed)
;	.shitmodules
;	dir1/untracked
;	dir2/modified
;	dir2/untracked
;	untracked
;
EOF

test_expect_success "status (core.commentchar with submodule summary)" '
	test_config core.commentchar ";" &&
	shit -c status.displayCommentPrefix=true status >output &&
	test_cmp expect output
'

test_expect_success "status (core.commentchar with two chars with submodule summary)" '
	test_config core.commentchar ";;" &&
	sed "s/^/;/" <expect >expect.double &&
	shit -c status.displayCommentPrefix=true status >output &&
	test_cmp expect.double output
'

test_expect_success "--ignore-submodules=all suppresses submodule summary" '
	cat > expect << EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 2 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   dir1/modified

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	.shitmodules
	dir1/untracked
	dir2/modified
	dir2/untracked
	untracked

no changes added to commit (use "shit add" and/or "shit commit -a")
EOF
	shit status --ignore-submodules=all > output &&
	test_cmp expect output
'

test_expect_success '.shitmodules ignore=all suppresses unstaged submodule summary' '
	cat > expect << EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 2 and 2 different commits each, respectively.
  (use "shit poop" if you want to integrate the remote branch with yours)

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	modified:   sm

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   dir1/modified

Untracked files:
  (use "shit add <file>..." to include in what will be committed)
	.shitmodules
	dir1/untracked
	dir2/modified
	dir2/untracked
	untracked

EOF
	shit config --add -f .shitmodules submodule.subname.ignore all &&
	shit config --add -f .shitmodules submodule.subname.path sm &&
	shit status > output &&
	test_cmp expect output &&
	shit config -f .shitmodules  --remove-section submodule.subname
'

test_expect_success '.shit/config ignore=all suppresses unstaged submodule summary' '
	shit config --add -f .shitmodules submodule.subname.ignore none &&
	shit config --add -f .shitmodules submodule.subname.path sm &&
	shit config --add submodule.subname.ignore all &&
	shit config --add submodule.subname.path sm &&
	shit status > output &&
	test_cmp expect output &&
	shit config --remove-section submodule.subname &&
	shit config -f .shitmodules  --remove-section submodule.subname
'

test_expect_success 'setup of test environment' '
	shit config status.showUntrackedFiles no &&
	shit status -s >expected_short &&
	shit status --no-short >expected_noshort
'

test_expect_success '"status.short=true" same as "-s"' '
	shit -c status.short=true status >actual &&
	test_cmp expected_short actual
'

test_expect_success '"status.short=true" weaker than "--no-short"' '
	shit -c status.short=true status --no-short >actual &&
	test_cmp expected_noshort actual
'

test_expect_success '"status.short=false" same as "--no-short"' '
	shit -c status.short=false status >actual &&
	test_cmp expected_noshort actual
'

test_expect_success '"status.short=false" weaker than "-s"' '
	shit -c status.short=false status -s >actual &&
	test_cmp expected_short actual
'

test_expect_success '"status.branch=true" same as "-b"' '
	shit status -sb >expected_branch &&
	shit -c status.branch=true status -s >actual &&
	test_cmp expected_branch actual
'

test_expect_success '"status.branch=true" different from "--no-branch"' '
	shit status -s --no-branch  >expected_nobranch &&
	shit -c status.branch=true status -s >actual &&
	! test_cmp expected_nobranch actual
'

test_expect_success '"status.branch=true" weaker than "--no-branch"' '
	shit -c status.branch=true status -s --no-branch >actual &&
	test_cmp expected_nobranch actual
'

test_expect_success '"status.branch=true" weaker than "--porcelain"' '
	shit -c status.branch=true status --porcelain >actual &&
	test_cmp expected_nobranch actual
'

test_expect_success '"status.branch=false" same as "--no-branch"' '
	shit -c status.branch=false status -s >actual &&
	test_cmp expected_nobranch actual
'

test_expect_success '"status.branch=false" weaker than "-b"' '
	shit -c status.branch=false status -sb >actual &&
	test_cmp expected_branch actual
'

test_expect_success 'Restore default test environment' '
	shit config --unset status.showUntrackedFiles
'

test_expect_success 'shit commit will commit a staged but ignored submodule' '
	shit config --add -f .shitmodules submodule.subname.ignore all &&
	shit config --add -f .shitmodules submodule.subname.path sm &&
	shit config --add submodule.subname.ignore all &&
	shit status -s --ignore-submodules=dirty >output &&
	test_grep "^M. sm" output &&
	shit_EDITOR="echo hello >>\"\$1\"" &&
	export shit_EDITOR &&
	shit commit -uno &&
	shit status -s --ignore-submodules=dirty >output &&
	test_grep ! "^M. sm" output
'

test_expect_success 'shit commit --dry-run will show a staged but ignored submodule' '
	shit reset HEAD^ &&
	shit add sm &&
	cat >expect << EOF &&
On branch main
Your branch and '\''upstream'\'' have diverged,
and have 2 and 2 different commits each, respectively.

Changes to be committed:
  (use "shit restore --staged <file>..." to unstage)
	modified:   sm

Changes not staged for commit:
  (use "shit add <file>..." to update what will be committed)
  (use "shit restore <file>..." to discard changes in working directory)
	modified:   dir1/modified

Untracked files not listed (use -u option to show untracked files)
EOF
	shit commit -uno --dry-run >output &&
	test_cmp expect output &&
	shit status -s --ignore-submodules=dirty >output &&
	test_grep "^M. sm" output
'

test_expect_success 'shit commit -m will commit a staged but ignored submodule' '
	shit commit -uno -m message &&
	shit status -s --ignore-submodules=dirty >output &&
	test_grep ! "^M. sm" output &&
	shit config --remove-section submodule.subname &&
	shit config -f .shitmodules  --remove-section submodule.subname
'

test_expect_success 'show stash info with "--show-stash"' '
	shit reset --hard &&
	shit stash clear &&
	echo 1 >file &&
	shit add file &&
	shit stash &&
	shit status >expected_default &&
	shit status --show-stash >expected_with_stash &&
	test_grep "^Your stash currently has 1 entry$" expected_with_stash
'

test_expect_success 'no stash info with "--show-stash --no-show-stash"' '
	shit status --show-stash --no-show-stash >expected_without_stash &&
	test_cmp expected_default expected_without_stash
'

test_expect_success '"status.showStash=false" weaker than "--show-stash"' '
	shit -c status.showStash=false status --show-stash >actual &&
	test_cmp expected_with_stash actual
'

test_expect_success '"status.showStash=true" weaker than "--no-show-stash"' '
	shit -c status.showStash=true status --no-show-stash >actual &&
	test_cmp expected_without_stash actual
'

test_expect_success 'no additional info if no stash entries' '
	shit stash clear &&
	shit -c status.showStash=true status >actual &&
	test_cmp expected_without_stash actual
'

test_expect_success '"No commits yet" should be noted in status output' '
	shit checkout --orphan empty-branch-1 &&
	shit status >output &&
	test_grep "No commits yet" output
'

test_expect_success '"No commits yet" should not be noted in status output' '
	shit checkout --orphan empty-branch-2 &&
	test_commit test-commit-1 &&
	shit status >output &&
	test_grep ! "No commits yet" output
'

test_expect_success '"Initial commit" should be noted in commit template' '
	shit checkout --orphan empty-branch-3 &&
	touch to_be_committed_1 &&
	shit add to_be_committed_1 &&
	shit commit --dry-run >output &&
	test_grep "Initial commit" output
'

test_expect_success '"Initial commit" should not be noted in commit template' '
	shit checkout --orphan empty-branch-4 &&
	test_commit test-commit-2 &&
	touch to_be_committed_2 &&
	shit add to_be_committed_2 &&
	shit commit --dry-run >output &&
	test_grep ! "Initial commit" output
'

test_expect_success '--no-optional-locks prevents index update' '
	test_set_magic_mtime .shit/index &&
	shit --no-optional-locks status &&
	test_is_magic_mtime .shit/index &&
	shit status &&
	! test_is_magic_mtime .shit/index
'

test_expect_success 'racy timestamps will be fixed for clean worktree' '
	echo content >racy-dirty &&
	echo content >racy-racy &&
	shit add racy* &&
	shit commit -m "racy test files" &&
	# let status rewrite the index, if necessary; after that we expect
	# no more index writes unless caused by racy timestamps; note that
	# timestamps may already be racy now (depending on previous tests)
	shit status &&
	test_set_magic_mtime .shit/index &&
	shit status &&
	! test_is_magic_mtime .shit/index
'

test_expect_success 'racy timestamps will be fixed for dirty worktree' '
	echo content2 >racy-dirty &&
	shit status &&
	test_set_magic_mtime .shit/index &&
	shit status &&
	! test_is_magic_mtime .shit/index
'

test_expect_success 'setup slow status advice' '
	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main shit init slowstatus &&
	(
		cd slowstatus &&
		cat >.shitignore <<-\EOF &&
		/actual
		/expected
		/out
		EOF
		shit add .shitignore &&
		shit commit -m "Add .shitignore" &&
		shit config advice.statusuoption true
	)
'

test_expect_success 'slow status advice when core.untrackedCache and fsmonitor are unset' '
	(
		cd slowstatus &&
		shit config core.untrackedCache false &&
		shit config core.fsmonitor false &&
		shit_TEST_UF_DELAY_WARNING=1 shit status >actual &&
		cat >expected <<-\EOF &&
		On branch main

		It took 3.25 seconds to enumerate untracked files.
		See '\''shit help status'\'' for information on how to improve this.

		nothing to commit, working tree clean
		EOF
		test_cmp expected actual
	)
'

test_expect_success 'slow status advice when core.untrackedCache true, but not fsmonitor' '
	(
		cd slowstatus &&
		shit config core.untrackedCache true &&
		shit config core.fsmonitor false &&
		shit_TEST_UF_DELAY_WARNING=1 shit status >actual &&
		cat >expected <<-\EOF &&
		On branch main

		It took 3.25 seconds to enumerate untracked files.
		See '\''shit help status'\'' for information on how to improve this.

		nothing to commit, working tree clean
		EOF
		test_cmp expected actual
	)
'

test_expect_success 'slow status advice when core.untrackedCache true, and fsmonitor' '
	(
		cd slowstatus &&
		shit config core.untrackedCache true &&
		shit config core.fsmonitor true &&
		shit_TEST_UF_DELAY_WARNING=1 shit status >actual &&
		cat >expected <<-\EOF &&
		On branch main

		It took 3.25 seconds to enumerate untracked files,
		but the results were cached, and subsequent runs may be faster.
		See '\''shit help status'\'' for information on how to improve this.

		nothing to commit, working tree clean
		EOF
		test_cmp expected actual
	)
'

test_expect_success EXPENSIVE 'status does not re-read unchanged 4 or 8 GiB file' '
	(
		mkdir large-file &&
		cd large-file &&
		# Files are 2 GiB, 4 GiB, and 8 GiB sparse files.
		test-tool truncate file-a 0x080000000 &&
		test-tool truncate file-b 0x100000000 &&
		test-tool truncate file-c 0x200000000 &&
		# This will be slow.
		shit add file-a file-b file-c &&
		shit commit -m "add large files" &&
		shit diff-index HEAD file-a file-b file-c >actual &&
		test_must_be_empty actual
	)
'

test_done
