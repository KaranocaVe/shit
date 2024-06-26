#!/bin/sh

test_description='add -i basic tests'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-terminal.sh

SP=" "

diff_cmp () {
	for x
	do
		sed  -e '/^index/s/[0-9a-f]*[1-9a-f][0-9a-f]*\.\./1234567../' \
		     -e '/^index/s/\.\.[0-9a-f]*[1-9a-f][0-9a-f]*/..9abcdef/' \
		     -e '/^index/s/ 00*\.\./ 0000000../' \
		     -e '/^index/s/\.\.00*$/..0000000/' \
		     -e '/^index/s/\.\.00* /..0000000 /' \
		     "$x" >"$x.filtered"
	done
	test_cmp "$1.filtered" "$2.filtered"
}

# This function uses a trick to manipulate the interactive add to use color:
# the `want_color()` function special-cases the situation where a pager was
# spawned and shit now wants to output colored text: to detect that situation,
# the environment variable `shit_PAGER_IN_USE` is set. However, color is
# suppressed despite that environment variable if the `TERM` variable
# indicates a dumb terminal, so we set that variable, too.

force_color () {
	# The first element of $@ may be a shell function, as a result POSIX
	# does not guarantee that "one-shot assignment" will not persist after
	# the function call. Thus, we prevent these variables from escaping
	# this function's context with this subshell.
	(
		shit_PAGER_IN_USE=true &&
		TERM=vt100 &&
		export shit_PAGER_IN_USE TERM &&
		"$@"
	)
}

test_expect_success 'warn about add.interactive.useBuiltin' '
	cat >expect <<-\EOF &&
	warning: the add.interactive.useBuiltin setting has been removed!
	See its entry in '\''shit help config'\'' for details.
	EOF
	echo "No changes." >expect.out &&

	for v in = =true =false
	do
		shit -c "add.interactive.useBuiltin$v" add -p >out 2>actual &&
		test_cmp expect.out out &&
		test_cmp expect actual || return 1
	done
'

test_expect_success 'unknown command' '
	test_when_finished "shit reset --hard; rm -f command" &&
	echo W >command &&
	shit add -N command &&
	shit diff command >expect &&
	cat >>expect <<-EOF &&
	(1/1) Stage addition [y,n,q,a,d,e,p,?]? Unknown command ${SQ}W${SQ} (use ${SQ}?${SQ} for help)
	(1/1) Stage addition [y,n,q,a,d,e,p,?]?$SP
	EOF
	shit add -p -- command <command >actual 2>&1 &&
	test_cmp expect actual
'

test_expect_success 'setup (initial)' '
	echo content >file &&
	shit add file &&
	echo more >>file &&
	echo lines >>file
'
test_expect_success 'status works (initial)' '
	shit add -i </dev/null >output &&
	grep "+1/-0 *+2/-0 file" output
'

test_expect_success 'setup expected' '
	cat >expected <<-\EOF
	new file mode 100644
	index 0000000..d95f3ad
	--- /dev/null
	+++ b/file
	@@ -0,0 +1 @@
	+content
	EOF
'

test_expect_success 'diff works (initial)' '
	test_write_lines d 1 | shit add -i >output &&
	sed -ne "/new file/,/content/p" <output >diff &&
	diff_cmp expected diff
'
test_expect_success 'revert works (initial)' '
	shit add file &&
	test_write_lines r 1 | shit add -i &&
	shit ls-files >output &&
	! grep . output
'

test_expect_success 'add untracked (multiple)' '
	test_when_finished "shit reset && rm [1-9]" &&
	touch $(test_seq 9) &&
	test_write_lines a "2-5 8-" | shit add -i -- [1-9] &&
	test_write_lines 2 3 4 5 8 9 >expected &&
	shit ls-files [1-9] >output &&
	test_cmp expected output
'

test_expect_success 'setup (commit)' '
	echo baseline >file &&
	shit add file &&
	shit commit -m commit &&
	echo content >>file &&
	shit add file &&
	echo more >>file &&
	echo lines >>file
'
test_expect_success 'status works (commit)' '
	shit add -i </dev/null >output &&
	grep "+1/-0 *+2/-0 file" output
'

test_expect_success 'update can stage deletions' '
	>to-delete &&
	shit add to-delete &&
	rm to-delete &&
	test_write_lines u t "" | shit add -i &&
	shit ls-files to-delete >output &&
	test_must_be_empty output
'

test_expect_success 'setup expected' '
	cat >expected <<-\EOF
	index 180b47c..b6f2c08 100644
	--- a/file
	+++ b/file
	@@ -1 +1,2 @@
	 baseline
	+content
	EOF
'

test_expect_success 'diff works (commit)' '
	test_write_lines d 1 | shit add -i >output &&
	sed -ne "/^index/,/content/p" <output >diff &&
	diff_cmp expected diff
'
test_expect_success 'revert works (commit)' '
	shit add file &&
	test_write_lines r 1 | shit add -i &&
	shit add -i </dev/null >output &&
	grep "unchanged *+3/-0 file" output
'

test_expect_success 'setup expected' '
	cat >expected <<-\EOF
	EOF
'

test_expect_success 'dummy edit works' '
	test_set_editor : &&
	test_write_lines e a | shit add -p &&
	shit diff > diff &&
	diff_cmp expected diff
'

test_expect_success 'setup patch' '
	cat >patch <<-\EOF
	@@ -1,1 +1,4 @@
	 this
	+patch
	-does not
	 apply
	EOF
'

test_expect_success 'setup fake editor' '
	write_script "fake_editor.sh" <<-\EOF &&
	mv -f "$1" oldpatch &&
	mv -f patch "$1"
	EOF
	test_set_editor "$(pwd)/fake_editor.sh"
'

test_expect_success 'bad edit rejected' '
	shit reset &&
	test_write_lines e n d | shit add -p >output &&
	grep "hunk does not apply" output
'

test_expect_success 'setup patch' '
	cat >patch <<-\EOF
	this patch
	is garbage
	EOF
'

test_expect_success 'garbage edit rejected' '
	shit reset &&
	test_write_lines e n d | shit add -p >output &&
	grep "hunk does not apply" output
'

test_expect_success 'setup patch' '
	cat >patch <<-\EOF
	@@ -1,0 +1,0 @@
	 baseline
	+content
	+newcontent
	+lines
	EOF
'

test_expect_success 'setup expected' '
	cat >expected <<-\EOF
	diff --shit a/file b/file
	index b5dd6c9..f910ae9 100644
	--- a/file
	+++ b/file
	@@ -1,4 +1,4 @@
	 baseline
	 content
	-newcontent
	+more
	 lines
	EOF
'

test_expect_success 'real edit works' '
	test_write_lines e n d | shit add -p &&
	shit diff >output &&
	diff_cmp expected output
'

test_expect_success 'setup file' '
	test_write_lines a "" b "" c >file &&
	shit add file &&
	test_write_lines a "" d "" c >file
'

test_expect_success 'setup patch' '
	NULL="" &&
	cat >patch <<-EOF
	@@ -1,4 +1,4 @@
	 a
	$NULL
	-b
	+f
	$SP
	c
	EOF
'

test_expect_success 'setup expected' '
	cat >expected <<-EOF
	diff --shit a/file b/file
	index b5dd6c9..f910ae9 100644
	--- a/file
	+++ b/file
	@@ -1,5 +1,5 @@
	 a
	$SP
	-f
	+d
	$SP
	 c
	EOF
'

test_expect_success 'edit can strip spaces from empty context lines' '
	test_write_lines e n q | shit add -p 2>error &&
	test_must_be_empty error &&
	shit diff >output &&
	diff_cmp expected output
'

test_expect_success 'skip files similarly as commit -a' '
	shit reset &&
	echo file >.shitignore &&
	echo changed >file &&
	echo y | shit add -p file &&
	shit diff >output &&
	shit reset &&
	shit commit -am commit &&
	shit diff >expected &&
	diff_cmp expected output &&
	shit reset --hard HEAD^
'
rm -f .shitignore

test_expect_success FILEMODE 'patch does not affect mode' '
	shit reset --hard &&
	echo content >>file &&
	chmod +x file &&
	printf "n\\ny\\n" | shit add -p &&
	shit show :file | grep content &&
	shit diff file | grep "new mode"
'

test_expect_success FILEMODE 'stage mode but not hunk' '
	shit reset --hard &&
	echo content >>file &&
	chmod +x file &&
	printf "y\\nn\\n" | shit add -p &&
	shit diff --cached file | grep "new mode" &&
	shit diff          file | grep "+content"
'


test_expect_success FILEMODE 'stage mode and hunk' '
	shit reset --hard &&
	echo content >>file &&
	chmod +x file &&
	printf "y\\ny\\n" | shit add -p &&
	shit diff --cached file >out &&
	grep "new mode" out &&
	grep "+content" out &&
	shit diff file >out &&
	test_must_be_empty out
'

# end of tests disabled when filemode is not usable

test_expect_success 'different prompts for mode change/deleted' '
	shit reset --hard &&
	>file &&
	>deleted &&
	shit add --chmod=+x file deleted &&
	echo changed >file &&
	rm deleted &&
	test_write_lines n n n |
	shit -c core.filemode=true add -p >actual &&
	sed -n "s/^\(([0-9/]*) Stage .*?\).*/\1/p" actual >actual.filtered &&
	cat >expect <<-\EOF &&
	(1/1) Stage deletion [y,n,q,a,d,p,?]?
	(1/2) Stage mode change [y,n,q,a,d,j,J,g,/,p,?]?
	(2/2) Stage this hunk [y,n,q,a,d,K,g,/,e,p,?]?
	EOF
	test_cmp expect actual.filtered
'

test_expect_success 'correct message when there is nothing to do' '
	shit reset --hard &&
	shit add -p >out &&
	test_grep "No changes" out &&
	printf "\\0123" >binary &&
	shit add binary &&
	printf "\\0abc" >binary &&
	shit add -p >out &&
	test_grep "Only binary files changed" out
'

test_expect_success 'setup again' '
	shit reset --hard &&
	test_chmod +x file &&
	echo content >>file &&
	test_write_lines A B C D>file2 &&
	shit add file2
'

# Write the patch file with a new line at the top and bottom
test_expect_success 'setup patch' '
	cat >patch <<-\EOF
	index 180b47c..b6f2c08 100644
	--- a/file
	+++ b/file
	@@ -1,2 +1,4 @@
	+firstline
	 baseline
	 content
	+lastline
	\ No newline at end of file
	diff --shit a/file2 b/file2
	index 8422d40..35b930a 100644
	--- a/file2
	+++ b/file2
	@@ -1,4 +1,5 @@
	-A
	+Z
	 B
	+Y
	 C
	-D
	+X
	EOF
'

# Expected output, diff is similar to the patch but w/ diff at the top
test_expect_success 'setup expected' '
	echo diff --shit a/file b/file >expected &&
	sed -e "/^index 180b47c/s/ 100644/ 100755/" \
	    -e /1,5/s//1,4/ \
	    -e /Y/d patch >>expected &&
	cat >expected-output <<-\EOF
	--- a/file
	+++ b/file
	@@ -1,2 +1,4 @@
	+firstline
	 baseline
	 content
	+lastline
	\ No newline at end of file
	@@ -1,2 +1,3 @@
	+firstline
	 baseline
	 content
	@@ -1,2 +2,3 @@
	 baseline
	 content
	+lastline
	\ No newline at end of file
	--- a/file2
	+++ b/file2
	@@ -1,4 +1,5 @@
	-A
	+Z
	 B
	+Y
	 C
	-D
	+X
	@@ -1,2 +1,2 @@
	-A
	+Z
	 B
	@@ -2,2 +2,3 @@
	 B
	+Y
	 C
	@@ -3,2 +4,2 @@
	 C
	-D
	+X
	EOF
'

# Test splitting the first patch, then adding both
test_expect_success 'add first line works' '
	shit commit -am "clear local changes" &&
	shit apply patch &&
	test_write_lines s y y s y n y | shit add -p 2>error >raw-output &&
	sed -n -e "s/^([1-9]\/[1-9]) Stage this hunk[^@]*\(@@ .*\)/\1/" \
	       -e "/^[-+@ \\\\]"/p raw-output >output &&
	test_must_be_empty error &&
	shit diff --cached >diff &&
	diff_cmp expected diff &&
	test_cmp expected-output output
'

test_expect_success 'setup expected' '
	cat >expected <<-\EOF
	diff --shit a/non-empty b/non-empty
	deleted file mode 100644
	index d95f3ad..0000000
	--- a/non-empty
	+++ /dev/null
	@@ -1 +0,0 @@
	-content
	EOF
'

test_expect_success 'deleting a non-empty file' '
	shit reset --hard &&
	echo content >non-empty &&
	shit add non-empty &&
	shit commit -m non-empty &&
	rm non-empty &&
	echo y | shit add -p non-empty &&
	shit diff --cached >diff &&
	diff_cmp expected diff
'

test_expect_success 'setup expected' '
	cat >expected <<-\EOF
	diff --shit a/empty b/empty
	deleted file mode 100644
	index e69de29..0000000
	EOF
'

test_expect_success 'deleting an empty file' '
	shit reset --hard &&
	> empty &&
	shit add empty &&
	shit commit -m empty &&
	rm empty &&
	echo y | shit add -p empty &&
	shit diff --cached >diff &&
	diff_cmp expected diff
'

test_expect_success 'adding an empty file' '
	shit init added &&
	(
		cd added &&
		test_commit initial &&
		>empty &&
		shit add empty &&
		test_tick &&
		shit commit -m empty &&
		shit tag added-file &&
		shit reset --hard HEAD^ &&
		test_path_is_missing empty &&

		echo y | shit checkout -p added-file -- >actual &&
		test_path_is_file empty &&
		test_grep "Apply addition to index and worktree" actual
	)
'

test_expect_success 'split hunk setup' '
	shit reset --hard &&
	test_write_lines 10 20 30 40 50 60 >test &&
	shit add test &&
	test_tick &&
	shit commit -m test &&

	test_write_lines 10 15 20 21 22 23 24 30 40 50 60 >test
'

test_expect_success 'goto hunk' '
	test_when_finished "shit reset" &&
	tr _ " " >expect <<-EOF &&
	(2/2) Stage this hunk [y,n,q,a,d,K,g,/,e,p,?]? + 1:  -1,2 +1,3          +15
	_ 2:  -2,4 +3,8          +21
	go to which hunk? @@ -1,2 +1,3 @@
	_10
	+15
	_20
	(1/2) Stage this hunk [y,n,q,a,d,j,J,g,/,e,p,?]?_
	EOF
	test_write_lines s y g 1 | shit add -p >actual &&
	tail -n 7 <actual >actual.trimmed &&
	test_cmp expect actual.trimmed
'

test_expect_success 'navigate to hunk via regex' '
	test_when_finished "shit reset" &&
	tr _ " " >expect <<-EOF &&
	(2/2) Stage this hunk [y,n,q,a,d,K,g,/,e,p,?]? @@ -1,2 +1,3 @@
	_10
	+15
	_20
	(1/2) Stage this hunk [y,n,q,a,d,j,J,g,/,e,p,?]?_
	EOF
	test_write_lines s y /1,2 | shit add -p >actual &&
	tail -n 5 <actual >actual.trimmed &&
	test_cmp expect actual.trimmed
'

test_expect_success 'split hunk "add -p (edit)"' '
	# Split, say Edit and do nothing.  Then:
	#
	# 1. Broken version results in a patch that does not apply and
	# only takes [y/n] (edit again) so the first q is discarded
	# and then n attempts to discard the edit. Repeat q enough
	# times to get out.
	#
	# 2. Correct version applies the (not)edited version, and asks
	#    about the next hunk, against which we say q and program
	#    exits.
	printf "%s\n" s e     q n q q |
	EDITOR=: shit add -p &&
	shit diff >actual &&
	! grep "^+15" actual
'

test_expect_success 'split hunk "add -p (no, yes, edit)"' '
	test_write_lines 5 10 20 21 30 31 40 50 60 >test &&
	shit reset &&
	# test sequence is s(plit), n(o), y(es), e(dit)
	# q n q q is there to make sure we exit at the end.
	printf "%s\n" s n y e   q n q q |
	EDITOR=: shit add -p 2>error &&
	test_must_be_empty error &&
	shit diff >actual &&
	! grep "^+31" actual
'

test_expect_success 'split hunk with incomplete line at end' '
	shit reset --hard &&
	printf "missing LF" >>test &&
	shit add test &&
	test_write_lines before 10 20 30 40 50 60 70 >test &&
	shit grep --cached missing &&
	test_write_lines s n y q | shit add -p &&
	test_must_fail shit grep --cached missing &&
	shit grep before &&
	test_must_fail shit grep --cached before
'

test_expect_success 'edit, adding lines to the first hunk' '
	test_write_lines 10 11 20 30 40 50 51 60 >test &&
	shit reset &&
	tr _ " " >patch <<-EOF &&
	@@ -1,5 +1,6 @@
	_10
	+11
	+12
	_20
	+21
	+22
	_30
	EOF
	# test sequence is s(plit), e(dit), n(o)
	# q n q q is there to make sure we exit at the end.
	printf "%s\n" s e n   q n q q |
	EDITOR=./fake_editor.sh shit add -p 2>error &&
	test_must_be_empty error &&
	shit diff --cached >actual &&
	grep "^+22" actual
'

test_expect_success 'patch mode ignores unmerged entries' '
	shit reset --hard &&
	test_commit conflict &&
	test_commit non-conflict &&
	shit checkout -b side &&
	test_commit side conflict.t &&
	shit checkout main &&
	test_commit main conflict.t &&
	test_must_fail shit merge side &&
	echo changed >non-conflict.t &&
	echo y | shit add -p >output &&
	! grep a/conflict.t output &&
	cat >expected <<-\EOF &&
	* Unmerged path conflict.t
	diff --shit a/non-conflict.t b/non-conflict.t
	index f766221..5ea2ed4 100644
	--- a/non-conflict.t
	+++ b/non-conflict.t
	@@ -1 +1 @@
	-non-conflict
	+changed
	EOF
	shit diff --cached >diff &&
	diff_cmp expected diff
'

test_expect_success 'index is refreshed after applying patch' '
	shit reset --hard &&
	echo content >test &&
	printf y | shit add -p &&
	shit diff-files --exit-code
'

test_expect_success 'diffs can be colorized' '
	shit reset --hard &&

	echo content >test &&
	printf y >y &&
	force_color shit add -p >output 2>&1 <y &&
	shit diff-files --exit-code &&

	# We do not want to depend on the exact coloring scheme
	# shit uses for diffs, so just check that we saw some kind of color.
	grep "$(printf "\\033")" output
'

test_expect_success 'colors can be overridden' '
	shit reset --hard &&
	test_when_finished "shit rm -f color-test" &&
	test_write_lines context old more-context >color-test &&
	shit add color-test &&
	test_write_lines context new more-context another-one >color-test &&

	echo trigger an error message >input &&
	force_color shit \
		-c color.interactive.error=blue \
		add -i 2>err.raw <input &&
	test_decode_color <err.raw >err &&
	grep "<BLUE>Huh (trigger)?<RESET>" err &&

	test_write_lines help quit >input &&
	force_color shit \
		-c color.interactive.header=red \
		-c color.interactive.help=green \
		-c color.interactive.prompt=yellow \
		add -i >actual.raw <input &&
	test_decode_color <actual.raw >actual &&
	cat >expect <<-\EOF &&
	<RED>           staged     unstaged path<RESET>
	  1:        +3/-0        +2/-1 color-test

	<RED>*** Commands ***<RESET>
	  1: <YELLOW>s<RESET>tatus	  2: <YELLOW>u<RESET>pdate	  3: <YELLOW>r<RESET>evert	  4: <YELLOW>a<RESET>dd untracked
	  5: <YELLOW>p<RESET>atch	  6: <YELLOW>d<RESET>iff	  7: <YELLOW>q<RESET>uit	  8: <YELLOW>h<RESET>elp
	<YELLOW>What now<RESET>> <GREEN>status        - show paths with changes<RESET>
	<GREEN>update        - add working tree state to the staged set of changes<RESET>
	<GREEN>revert        - revert staged set of changes back to the HEAD version<RESET>
	<GREEN>patch         - pick hunks and update selectively<RESET>
	<GREEN>diff          - view diff between HEAD and index<RESET>
	<GREEN>add untracked - add contents of untracked files to the staged set of changes<RESET>
	<RED>*** Commands ***<RESET>
	  1: <YELLOW>s<RESET>tatus	  2: <YELLOW>u<RESET>pdate	  3: <YELLOW>r<RESET>evert	  4: <YELLOW>a<RESET>dd untracked
	  5: <YELLOW>p<RESET>atch	  6: <YELLOW>d<RESET>iff	  7: <YELLOW>q<RESET>uit	  8: <YELLOW>h<RESET>elp
	<YELLOW>What now<RESET>> Bye.
	EOF
	test_cmp expect actual &&

	: exercise recolor_hunk by editing and then look at the hunk again &&
	test_write_lines s e K q >input &&
	force_color shit \
		-c color.interactive.prompt=yellow \
		-c color.diff.meta=italic \
		-c color.diff.frag=magenta \
		-c color.diff.context=cyan \
		-c color.diff.old=bold \
		-c color.diff.new=blue \
		-c core.editor=touch \
		add -p >actual.raw <input &&
	test_decode_color <actual.raw >actual.decoded &&
	sed "s/index [0-9a-f]*\\.\\.[0-9a-f]* 100644/<INDEX-LINE>/" <actual.decoded >actual &&
	cat >expect <<-\EOF &&
	<ITALIC>diff --shit a/color-test b/color-test<RESET>
	<ITALIC><INDEX-LINE><RESET>
	<ITALIC>--- a/color-test<RESET>
	<ITALIC>+++ b/color-test<RESET>
	<MAGENTA>@@ -1,3 +1,4 @@<RESET>
	<CYAN> context<RESET>
	<BOLD>-old<RESET>
	<BLUE>+<RESET><BLUE>new<RESET>
	<CYAN> more-context<RESET>
	<BLUE>+<RESET><BLUE>another-one<RESET>
	<YELLOW>(1/1) Stage this hunk [y,n,q,a,d,s,e,p,?]? <RESET><BOLD>Split into 2 hunks.<RESET>
	<MAGENTA>@@ -1,3 +1,3 @@<RESET>
	<CYAN> context<RESET>
	<BOLD>-old<RESET>
	<BLUE>+<RESET><BLUE>new<RESET>
	<CYAN> more-context<RESET>
	<YELLOW>(1/2) Stage this hunk [y,n,q,a,d,j,J,g,/,e,p,?]? <RESET><MAGENTA>@@ -3 +3,2 @@<RESET>
	<CYAN> more-context<RESET>
	<BLUE>+<RESET><BLUE>another-one<RESET>
	<YELLOW>(2/2) Stage this hunk [y,n,q,a,d,K,g,/,e,p,?]? <RESET><MAGENTA>@@ -1,3 +1,3 @@<RESET>
	<CYAN> context<RESET>
	<BOLD>-old<RESET>
	<BLUE>+new<RESET>
	<CYAN> more-context<RESET>
	<YELLOW>(1/2) Stage this hunk [y,n,q,a,d,j,J,g,/,e,p,?]? <RESET>
	EOF
	test_cmp expect actual
'

test_expect_success 'brackets appear without color' '
	shit reset --hard &&
	test_when_finished "shit rm -f bracket-test" &&
	test_write_lines context old more-context >bracket-test &&
	shit add bracket-test &&
	test_write_lines context new more-context another-one >bracket-test &&

	test_write_lines quit >input &&
	shit add -i >actual <input &&

	sed "s/^|//" >expect <<-\EOF &&
	|           staged     unstaged path
	|  1:        +3/-0        +2/-1 bracket-test
	|
	|*** Commands ***
	|  1: [s]tatus	  2: [u]pdate	  3: [r]evert	  4: [a]dd untracked
	|  5: [p]atch	  6: [d]iff	  7: [q]uit	  8: [h]elp
	|What now> Bye.
	EOF

	test_cmp expect actual
'

test_expect_success 'colors can be skipped with color.ui=false' '
	shit reset --hard &&
	test_when_finished "shit rm -f color-test" &&
	test_write_lines context old more-context >color-test &&
	shit add color-test &&
	test_write_lines context new more-context another-one >color-test &&

	test_write_lines help quit >input &&
	force_color shit \
		-c color.ui=false \
		add -i >actual.raw <input &&
	test_decode_color <actual.raw >actual &&
	test_cmp actual.raw actual
'

test_expect_success 'colorized diffs respect diff.wsErrorHighlight' '
	shit reset --hard &&

	echo "old " >test &&
	shit add test &&
	echo "new " >test &&

	printf y >y &&
	force_color shit -c diff.wsErrorHighlight=all add -p >output.raw 2>&1 <y &&
	test_decode_color <output.raw >output &&
	grep "old<" output
'

test_expect_success 'diffFilter filters diff' '
	shit reset --hard &&

	echo content >test &&
	test_config interactive.diffFilter "sed s/^/foo:/" &&
	printf y >y &&
	force_color shit add -p >output 2>&1 <y &&

	# avoid depending on the exact coloring or content of the prompts,
	# and just make sure we saw our diff prefixed
	grep foo:.*content output
'

test_expect_success 'detect bogus diffFilter output' '
	shit reset --hard &&

	echo content >test &&
	test_config interactive.diffFilter "sed 6d" &&
	printf y >y &&
	force_color test_must_fail shit add -p <y >output 2>&1 &&
	grep "mismatched output" output
'

test_expect_success 'handle iffy colored hunk headers' '
	shit reset --hard &&

	echo content >test &&
	printf n >n &&
	force_color shit -c interactive.diffFilter="sed s/.*@@.*/XX/" \
		add -p >output 2>&1 <n &&
	grep "^XX$" output
'

test_expect_success 'handle very large filtered diff' '
	shit reset --hard &&
	# The specific number here is not important, but it must
	# be large enough that the output of "shit diff --color"
	# fills up the pipe buffer. 10,000 results in ~200k of
	# colored output.
	test_seq 10000 >test &&
	test_config interactive.diffFilter cat &&
	printf y >y &&
	force_color shit add -p >output 2>&1 <y &&
	shit diff-files --exit-code -- test
'

test_expect_success 'diff.algorithm is passed to `shit diff-files`' '
	shit reset --hard &&

	>file &&
	shit add file &&
	echo changed >file &&
	test_must_fail shit -c diff.algorithm=bogus add -p 2>err &&
	test_grep "error: option diff-algorithm accepts " err
'

test_expect_success 'patch-mode via -i prompts for files' '
	shit reset --hard &&

	echo one >file &&
	echo two >test &&
	shit add -i <<-\EOF &&
	patch
	test

	y
	quit
	EOF

	echo test >expect &&
	shit diff --cached --name-only >actual &&
	diff_cmp expect actual
'

test_expect_success 'add -p handles globs' '
	shit reset --hard &&

	mkdir -p subdir &&
	echo base >one.c &&
	echo base >subdir/two.c &&
	shit add "*.c" &&
	shit commit -m base &&

	echo change >one.c &&
	echo change >subdir/two.c &&
	shit add -p "*.c" <<-\EOF &&
	y
	y
	EOF

	cat >expect <<-\EOF &&
	one.c
	subdir/two.c
	EOF
	shit diff --cached --name-only >actual &&
	test_cmp expect actual
'

test_expect_success 'add -p handles relative paths' '
	shit reset --hard &&

	echo base >relpath.c &&
	shit add "*.c" &&
	shit commit -m relpath &&

	echo change >relpath.c &&
	mkdir -p subdir &&
	shit -C subdir add -p .. 2>error <<-\EOF &&
	y
	EOF

	test_must_be_empty error &&

	cat >expect <<-\EOF &&
	relpath.c
	EOF
	shit diff --cached --name-only >actual &&
	test_cmp expect actual
'

test_expect_success 'add -p does not expand argument lists' '
	shit reset --hard &&

	echo content >not-changed &&
	shit add not-changed &&
	shit commit -m "add not-changed file" &&

	echo change >file &&
	shit_TRACE=$(pwd)/trace.out shit add -p . <<-\EOF &&
	y
	EOF

	# we know that "file" must be mentioned since we actually
	# update it, but we want to be sure that our "." pathspec
	# was not expanded into the argument list of any command.
	# So look only for "not-changed".
	! grep -E "^trace: (built-in|exec|run_command): .*not-changed" trace.out
'

test_expect_success 'hunk-editing handles custom comment char' '
	shit reset --hard &&
	echo change >>file &&
	test_config core.commentChar "\$" &&
	echo e | shit_EDITOR=true shit add -p &&
	shit diff --exit-code
'

test_expect_success 'add -p works even with color.ui=always' '
	shit reset --hard &&
	echo change >>file &&
	test_config color.ui always &&
	echo y | shit add -p &&
	echo file >expect &&
	shit diff --cached --name-only >actual &&
	test_cmp expect actual
'

test_expect_success 'setup different kinds of dirty submodules' '
	test_create_repo for-submodules &&
	(
		cd for-submodules &&
		test_commit initial &&
		test_create_repo dirty-head &&
		(
			cd dirty-head &&
			test_commit initial
		) &&
		cp -R dirty-head dirty-otherwise &&
		cp -R dirty-head dirty-both-ways &&
		shit add dirty-head &&
		shit add dirty-otherwise dirty-both-ways &&
		shit commit -m initial &&

		cd dirty-head &&
		test_commit updated &&
		cd ../dirty-both-ways &&
		test_commit updated &&
		echo dirty >>initial &&
		: >untracked &&
		cd ../dirty-otherwise &&
		echo dirty >>initial &&
		: >untracked
	) &&
	shit -C for-submodules diff-files --name-only >actual &&
	cat >expected <<-\EOF &&
	dirty-both-ways
	dirty-head
	EOF
	test_cmp expected actual &&
	shit -C for-submodules diff-files --name-only --ignore-submodules=none >actual &&
	cat >expected <<-\EOF &&
	dirty-both-ways
	dirty-head
	dirty-otherwise
	EOF
	test_cmp expected actual &&
	shit -C for-submodules diff-files --name-only --ignore-submodules=dirty >actual &&
	cat >expected <<-\EOF &&
	dirty-both-ways
	dirty-head
	EOF
	test_cmp expected actual
'

test_expect_success 'status ignores dirty submodules (except HEAD)' '
	shit -C for-submodules add -i </dev/null >output &&
	grep dirty-head output &&
	grep dirty-both-ways output &&
	! grep dirty-otherwise output
'

test_expect_success 'handle submodules' '
	echo 123 >>for-submodules/dirty-otherwise/initial.t &&

	force_color shit -C for-submodules add -p dirty-otherwise >output 2>&1 &&
	grep "No changes" output &&

	force_color shit -C for-submodules add -p dirty-head >output 2>&1 <y &&
	shit -C for-submodules ls-files --stage dirty-head >actual &&
	rev="$(shit -C for-submodules/dirty-head rev-parse HEAD)" &&
	grep "$rev" actual
'

test_expect_success 'set up pathological context' '
	shit reset --hard &&
	test_write_lines a a a a a a a a a a a >a &&
	shit add a &&
	shit commit -m a &&
	test_write_lines c b a a a a a a a b a a a a >a &&
	test_write_lines     a a a a a a a b a a a a >expected-1 &&
	test_write_lines   b a a a a a a a b a a a a >expected-2 &&
	# check editing can cope with missing header and deleted context lines
	# as well as changes to other lines
	test_write_lines +b " a" >patch
'

test_expect_success 'add -p works with pathological context lines' '
	shit reset &&
	printf "%s\n" n y |
	shit add -p &&
	shit cat-file blob :a >actual &&
	test_cmp expected-1 actual
'

test_expect_success 'add -p patch editing works with pathological context lines' '
	shit reset &&
	# n q q below is in case edit fails
	printf "%s\n" e y    n q q |
	shit add -p &&
	shit cat-file blob :a >actual &&
	test_cmp expected-2 actual
'

test_expect_success 'checkout -p works with pathological context lines' '
	test_write_lines a a a a a a >a &&
	shit add a &&
	test_write_lines a b a b a b a b a b a >a &&
	test_write_lines s n n y q | shit checkout -p &&
	test_write_lines a b a b a a b a b a >expect &&
	test_cmp expect a
'

# This should be called from a subshell as it sets a temporary editor
setup_new_file() {
	write_script new-file-editor.sh <<-\EOF &&
	sed /^#/d "$1" >patch &&
	sed /^+c/d patch >"$1"
	EOF
	test_set_editor "$(pwd)/new-file-editor.sh" &&
	test_write_lines a b c d e f >new-file &&
	test_write_lines a b d e f >new-file-expect &&
	test_write_lines "@@ -0,0 +1,6 @@" +a +b +c +d +e +f >patch-expect
}

test_expect_success 'add -N followed by add -p patch editing' '
	shit reset --hard &&
	(
		setup_new_file &&
		shit add -N new-file &&
		test_write_lines e n q | shit add -p &&
		shit cat-file blob :new-file >actual &&
		test_cmp new-file-expect actual &&
		test_cmp patch-expect patch
	)
'

test_expect_success 'checkout -p patch editing of added file' '
	shit reset --hard &&
	(
		setup_new_file &&
		shit add new-file &&
		shit commit -m "add new file" &&
		shit rm new-file &&
		shit commit -m "remove new file" &&
		test_write_lines e n q | shit checkout -p HEAD^ &&
		test_cmp new-file-expect new-file &&
		test_cmp patch-expect patch
	)
'

test_expect_success 'show help from add--helper' '
	shit reset --hard &&
	cat >expect <<-EOF &&

	<BOLD>*** Commands ***<RESET>
	  1: <BOLD;BLUE>s<RESET>tatus	  2: <BOLD;BLUE>u<RESET>pdate	  3: <BOLD;BLUE>r<RESET>evert	  4: <BOLD;BLUE>a<RESET>dd untracked
	  5: <BOLD;BLUE>p<RESET>atch	  6: <BOLD;BLUE>d<RESET>iff	  7: <BOLD;BLUE>q<RESET>uit	  8: <BOLD;BLUE>h<RESET>elp
	<BOLD;BLUE>What now<RESET>> <BOLD;RED>status        - show paths with changes<RESET>
	<BOLD;RED>update        - add working tree state to the staged set of changes<RESET>
	<BOLD;RED>revert        - revert staged set of changes back to the HEAD version<RESET>
	<BOLD;RED>patch         - pick hunks and update selectively<RESET>
	<BOLD;RED>diff          - view diff between HEAD and index<RESET>
	<BOLD;RED>add untracked - add contents of untracked files to the staged set of changes<RESET>
	<BOLD>*** Commands ***<RESET>
	  1: <BOLD;BLUE>s<RESET>tatus	  2: <BOLD;BLUE>u<RESET>pdate	  3: <BOLD;BLUE>r<RESET>evert	  4: <BOLD;BLUE>a<RESET>dd untracked
	  5: <BOLD;BLUE>p<RESET>atch	  6: <BOLD;BLUE>d<RESET>iff	  7: <BOLD;BLUE>q<RESET>uit	  8: <BOLD;BLUE>h<RESET>elp
	<BOLD;BLUE>What now<RESET>>$SP
	Bye.
	EOF
	test_write_lines h | force_color shit add -i >actual.colored &&
	test_decode_color <actual.colored >actual &&
	test_cmp expect actual
'

test_expect_success 'reset -p with unmerged files' '
	test_when_finished "shit checkout --force main" &&
	test_commit one conflict &&
	shit checkout -B side HEAD^ &&
	test_commit two conflict &&
	test_must_fail shit merge one &&

	# this is a noop with only an unmerged entry
	shit reset -p &&

	# add files that sort before and after unmerged entry
	echo a >a &&
	echo z >z &&
	shit add a z &&

	# confirm that we can reset those files
	printf "%s\n" y y | shit reset -p &&
	shit diff-index --cached --diff-filter=u HEAD >staged &&
	test_must_be_empty staged
'

test_done
