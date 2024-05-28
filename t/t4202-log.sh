#!/bin/sh

test_description='shit log'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY/lib-gpg.sh"
. "$TEST_DIRECTORY/lib-terminal.sh"
. "$TEST_DIRECTORY/lib-log-graph.sh"

test_cmp_graph () {
	lib_test_cmp_graph --format=%s "$@"
}

test_expect_success setup '

	echo one >one &&
	shit add one &&
	test_tick &&
	shit commit -m initial &&

	echo ichi >one &&
	shit add one &&
	test_tick &&
	shit commit -m second &&

	shit mv one ichi &&
	test_tick &&
	shit commit -m third &&

	cp ichi ein &&
	shit add ein &&
	test_tick &&
	shit commit -m fourth &&

	mkdir a &&
	echo ni >a/two &&
	shit add a/two &&
	test_tick &&
	shit commit -m fifth  &&

	shit rm a/two &&
	test_tick &&
	shit commit -m sixth

'

printf "sixth\nfifth\nfourth\nthird\nsecond\ninitial" > expect
test_expect_success 'pretty' '

	shit log --pretty="format:%s" > actual &&
	test_cmp expect actual
'

printf "sixth\nfifth\nfourth\nthird\nsecond\ninitial\n" > expect
test_expect_success 'pretty (tformat)' '

	shit log --pretty="tformat:%s" > actual &&
	test_cmp expect actual
'

test_expect_success 'pretty (shortcut)' '

	shit log --pretty="%s" > actual &&
	test_cmp expect actual
'

test_expect_success 'format' '

	shit log --format="%s" > actual &&
	test_cmp expect actual
'

cat > expect << EOF
 This is
  the sixth
  commit.
 This is
  the fifth
  commit.
EOF

test_expect_success 'format %w(11,1,2)' '

	shit log -2 --format="%w(11,1,2)This is the %s commit." > actual &&
	test_cmp expect actual
'

test_expect_success 'format %w(,1,2)' '

	shit log -2 --format="%w(,1,2)This is%nthe %s%ncommit." > actual &&
	test_cmp expect actual
'

cat > expect << EOF
$(shit rev-parse --short :/sixth  ) sixth
$(shit rev-parse --short :/fifth  ) fifth
$(shit rev-parse --short :/fourth ) fourth
$(shit rev-parse --short :/third  ) third
$(shit rev-parse --short :/second ) second
$(shit rev-parse --short :/initial) initial
EOF
test_expect_success 'oneline' '

	shit log --oneline > actual &&
	test_cmp expect actual
'

test_expect_success 'diff-filter=A' '

	shit log --no-renames --pretty="format:%s" --diff-filter=A HEAD > actual &&
	shit log --no-renames --pretty="format:%s" --diff-filter A HEAD > actual-separate &&
	printf "fifth\nfourth\nthird\ninitial" > expect &&
	test_cmp expect actual &&
	test_cmp expect actual-separate

'

test_expect_success 'diff-filter=M' '

	shit log --pretty="format:%s" --diff-filter=M HEAD >actual &&
	printf "second" >expect &&
	test_cmp expect actual

'

test_expect_success 'diff-filter=D' '

	shit log --no-renames --pretty="format:%s" --diff-filter=D HEAD >actual &&
	printf "sixth\nthird" >expect &&
	test_cmp expect actual

'

test_expect_success 'diff-filter=R' '

	shit log -M --pretty="format:%s" --diff-filter=R HEAD >actual &&
	printf "third" >expect &&
	test_cmp expect actual

'

test_expect_success 'multiple --diff-filter bits' '

	shit log -M --pretty="format:%s" --diff-filter=R HEAD >expect &&
	shit log -M --pretty="format:%s" --diff-filter=Ra HEAD >actual &&
	test_cmp expect actual &&
	shit log -M --pretty="format:%s" --diff-filter=aR HEAD >actual &&
	test_cmp expect actual &&
	shit log -M --pretty="format:%s" \
		--diff-filter=a --diff-filter=R HEAD >actual &&
	test_cmp expect actual

'

test_expect_success 'diff-filter=C' '

	shit log -C -C --pretty="format:%s" --diff-filter=C HEAD >actual &&
	printf "fourth" >expect &&
	test_cmp expect actual

'

test_expect_success 'shit log --follow' '

	shit log --follow --pretty="format:%s" ichi >actual &&
	printf "third\nsecond\ninitial" >expect &&
	test_cmp expect actual
'

test_expect_success 'shit config log.follow works like --follow' '
	test_config log.follow true &&
	shit log --pretty="format:%s" ichi >actual &&
	printf "third\nsecond\ninitial" >expect &&
	test_cmp expect actual
'

test_expect_success 'shit config log.follow does not die with multiple paths' '
	test_config log.follow true &&
	shit log --pretty="format:%s" ichi ein
'

test_expect_success 'shit config log.follow does not die with no paths' '
	test_config log.follow true &&
	shit log --
'

test_expect_success 'shit log --follow rejects unsupported pathspec magic' '
	test_must_fail shit log --follow ":(top,glob,icase)ichi" 2>stderr &&
	# check full error message; we want to be sure we mention both
	# of the rejected types (glob,icase), but not the allowed one (top)
	echo "fatal: pathspec magic not supported by --follow: ${SQ}glob${SQ}, ${SQ}icase${SQ}" >expect &&
	test_cmp expect stderr
'

test_expect_success 'log.follow disabled with unsupported pathspec magic' '
	test_config log.follow true &&
	shit log --format=%s ":(glob,icase)ichi" >actual &&
	echo third >expect &&
	test_cmp expect actual
'

test_expect_success 'shit config log.follow is overridden by --no-follow' '
	test_config log.follow true &&
	shit log --no-follow --pretty="format:%s" ichi >actual &&
	printf "third" >expect &&
	test_cmp expect actual
'

# Note that these commits are intentionally listed out of order.
last_three="$(shit rev-parse :/fourth :/sixth :/fifth)"
cat > expect << EOF
$(shit rev-parse --short :/sixth ) sixth
$(shit rev-parse --short :/fifth ) fifth
$(shit rev-parse --short :/fourth) fourth
EOF
test_expect_success 'shit log --no-walk <commits> sorts by commit time' '
	shit log --no-walk --oneline $last_three > actual &&
	test_cmp expect actual
'

test_expect_success 'shit log --no-walk=sorted <commits> sorts by commit time' '
	shit log --no-walk=sorted --oneline $last_three > actual &&
	test_cmp expect actual
'

cat > expect << EOF
=== $(shit rev-parse --short :/sixth ) sixth
=== $(shit rev-parse --short :/fifth ) fifth
=== $(shit rev-parse --short :/fourth) fourth
EOF
test_expect_success 'shit log --line-prefix="=== " --no-walk <commits> sorts by commit time' '
	shit log --line-prefix="=== " --no-walk --oneline $last_three > actual &&
	test_cmp expect actual
'

cat > expect << EOF
$(shit rev-parse --short :/fourth) fourth
$(shit rev-parse --short :/sixth ) sixth
$(shit rev-parse --short :/fifth ) fifth
EOF
test_expect_success 'shit log --no-walk=unsorted <commits> leaves list of commits as given' '
	shit log --no-walk=unsorted --oneline $last_three > actual &&
	test_cmp expect actual
'

test_expect_success 'shit show <commits> leaves list of commits as given' '
	shit show --oneline -s $last_three > actual &&
	test_cmp expect actual
'

test_expect_success 'setup case sensitivity tests' '
	echo case >one &&
	test_tick &&
	shit add one &&
	shit commit -a -m Second
'

test_expect_success 'log --grep' '
	echo second >expect &&
	shit log -1 --pretty="tformat:%s" --grep=sec >actual &&
	test_cmp expect actual
'

for noop_opt in --invert-grep --all-match
do
	test_expect_success "log $noop_opt without --grep is a NOOP" '
		shit log >expect &&
		shit log $noop_opt >actual &&
		test_cmp expect actual
	'
done

cat > expect << EOF
second
initial
EOF
test_expect_success 'log --invert-grep --grep' '
	# Fixed
	shit -c grep.patternType=fixed log --pretty="tformat:%s" --invert-grep --grep=th --grep=Sec >actual &&
	test_cmp expect actual &&

	# POSIX basic
	shit -c grep.patternType=basic log --pretty="tformat:%s" --invert-grep --grep=t[h] --grep=S[e]c >actual &&
	test_cmp expect actual &&

	# POSIX extended
	shit -c grep.patternType=extended log --pretty="tformat:%s" --invert-grep --grep=t[h] --grep=S[e]c >actual &&
	test_cmp expect actual &&

	# PCRE
	if test_have_prereq PCRE
	then
		shit -c grep.patternType=perl log --pretty="tformat:%s" --invert-grep --grep=t[h] --grep=S[e]c >actual &&
		test_cmp expect actual
	fi
'

test_expect_success 'log --invert-grep --grep -i' '
	echo initial >expect &&

	# Fixed
	shit -c grep.patternType=fixed log --pretty="tformat:%s" --invert-grep -i --grep=th --grep=Sec >actual &&
	test_cmp expect actual &&

	# POSIX basic
	shit -c grep.patternType=basic log --pretty="tformat:%s" --invert-grep -i --grep=t[h] --grep=S[e]c >actual &&
	test_cmp expect actual &&

	# POSIX extended
	shit -c grep.patternType=extended log --pretty="tformat:%s" --invert-grep -i --grep=t[h] --grep=S[e]c >actual &&
	test_cmp expect actual &&

	# PCRE
	if test_have_prereq PCRE
	then
		shit -c grep.patternType=perl log --pretty="tformat:%s" --invert-grep -i --grep=t[h] --grep=S[e]c >actual &&
		test_cmp expect actual
	fi
'

test_expect_success 'log --grep option parsing' '
	echo second >expect &&
	shit log -1 --pretty="tformat:%s" --grep sec >actual &&
	test_cmp expect actual &&
	test_must_fail shit log -1 --pretty="tformat:%s" --grep
'

test_expect_success 'log -i --grep' '
	echo Second >expect &&
	shit log -1 --pretty="tformat:%s" -i --grep=sec >actual &&
	test_cmp expect actual
'

test_expect_success 'log --grep -i' '
	echo Second >expect &&

	# Fixed
	shit log -1 --pretty="tformat:%s" --grep=sec -i >actual &&
	test_cmp expect actual &&

	# POSIX basic
	shit -c grep.patternType=basic log -1 --pretty="tformat:%s" --grep=s[e]c -i >actual &&
	test_cmp expect actual &&

	# POSIX extended
	shit -c grep.patternType=extended log -1 --pretty="tformat:%s" --grep=s[e]c -i >actual &&
	test_cmp expect actual &&

	# PCRE
	if test_have_prereq PCRE
	then
		shit -c grep.patternType=perl log -1 --pretty="tformat:%s" --grep=s[e]c -i >actual &&
		test_cmp expect actual
	fi
'

test_expect_success 'log -F -E --grep=<ere> uses ere' '
	echo second >expect &&
	# basic would need \(s\) to do the same
	shit log -1 --pretty="tformat:%s" -F -E --grep="(s).c.nd" >actual &&
	test_cmp expect actual
'

test_expect_success PCRE 'log -F -E --perl-regexp --grep=<pcre> uses PCRE' '
	test_when_finished "rm -rf num_commits" &&
	shit init num_commits &&
	(
		cd num_commits &&
		test_commit 1d &&
		test_commit 2e
	) &&

	# In PCRE \d in [\d] is like saying "0-9", and matches the 2
	# in 2e...
	echo 2e >expect &&
	shit -C num_commits log -1 --pretty="tformat:%s" -F -E --perl-regexp --grep="[\d]" >actual &&
	test_cmp expect actual &&

	# ...in POSIX basic and extended it is the same as [d],
	# i.e. "d", which matches 1d, but does not match 2e.
	echo 1d >expect &&
	shit -C num_commits log -1 --pretty="tformat:%s" -F -E --grep="[\d]" >actual &&
	test_cmp expect actual
'

test_expect_success 'log with grep.patternType configuration' '
	shit -c grep.patterntype=fixed \
	log -1 --pretty=tformat:%s --grep=s.c.nd >actual &&
	test_must_be_empty actual
'

test_expect_success 'log with grep.patternType configuration and command line' '
	echo second >expect &&
	shit -c grep.patterntype=fixed \
	log -1 --pretty=tformat:%s --basic-regexp --grep=s.c.nd >actual &&
	test_cmp expect actual
'

test_expect_success !FAIL_PREREQS 'log with various grep.patternType configurations & command-lines' '
	shit init pattern-type &&
	(
		cd pattern-type &&
		test_commit 1 file A &&

		# The tagname is overridden here because creating a
		# tag called "(1|2)" as test_commit would otherwise
		# implicitly do would fail on e.g. MINGW.
		test_commit "(1|2)" file B 2 &&

		echo "(1|2)" >expect.fixed &&
		cp expect.fixed expect.basic &&
		cp expect.fixed expect.extended &&
		cp expect.fixed expect.perl &&

		# A strcmp-like match with fixed.
		shit -c grep.patternType=fixed log --pretty=tformat:%s \
			--grep="(1|2)" >actual.fixed &&

		# POSIX basic matches (, | and ) literally.
		shit -c grep.patternType=basic log --pretty=tformat:%s \
			--grep="(.|.)" >actual.basic &&

		# POSIX extended needs to have | escaped to match it
		# literally, whereas under basic this is the same as
		# (|2), i.e. it would also match "1". This test checks
		# for extended by asserting that it is not matching
		# what basic would match.
		shit -c grep.patternType=extended log --pretty=tformat:%s \
			--grep="\|2" >actual.extended &&
		if test_have_prereq PCRE
		then
			# Only PCRE would match [\d]\| with only
			# "(1|2)" due to [\d]. POSIX basic would match
			# both it and "1" since similarly to the
			# extended match above it is the same as
			# \([\d]\|\). POSIX extended would
			# match neither.
			shit -c grep.patternType=perl log --pretty=tformat:%s \
				--grep="[\d]\|" >actual.perl &&
			test_cmp expect.perl actual.perl
		fi &&
		test_cmp expect.fixed actual.fixed &&
		test_cmp expect.basic actual.basic &&
		test_cmp expect.extended actual.extended &&

		shit log --pretty=tformat:%s -F \
			--grep="(1|2)" >actual.fixed.short-arg &&
		shit log --pretty=tformat:%s -E \
			--grep="\|2" >actual.extended.short-arg &&
		if test_have_prereq PCRE
		then
			shit log --pretty=tformat:%s -P \
				--grep="[\d]\|" >actual.perl.short-arg
		else
			test_must_fail shit log -P \
				--grep="[\d]\|"
		fi &&
		test_cmp expect.fixed actual.fixed.short-arg &&
		test_cmp expect.extended actual.extended.short-arg &&
		if test_have_prereq PCRE
		then
			test_cmp expect.perl actual.perl.short-arg
		fi &&

		shit log --pretty=tformat:%s --fixed-strings \
			--grep="(1|2)" >actual.fixed.long-arg &&
		shit log --pretty=tformat:%s --basic-regexp \
			--grep="(.|.)" >actual.basic.long-arg &&
		shit log --pretty=tformat:%s --extended-regexp \
			--grep="\|2" >actual.extended.long-arg &&
		if test_have_prereq PCRE
		then
			shit log --pretty=tformat:%s --perl-regexp \
				--grep="[\d]\|" >actual.perl.long-arg &&
			test_cmp expect.perl actual.perl.long-arg
		else
			test_must_fail shit log --perl-regexp \
				--grep="[\d]\|"
		fi &&
		test_cmp expect.fixed actual.fixed.long-arg &&
		test_cmp expect.basic actual.basic.long-arg &&
		test_cmp expect.extended actual.extended.long-arg
	)
'

for cmd in show whatchanged reflog format-patch
do
	case "$cmd" in
	format-patch) myarg="HEAD~.." ;;
	*) myarg= ;;
	esac

	test_expect_success "$cmd: understands grep.patternType, like 'log'" '
		shit init "pattern-type-$cmd" &&
		(
			cd "pattern-type-$cmd" &&
			test_commit 1 file A &&
			test_commit "(1|2)" file B 2 &&

			shit -c grep.patternType=fixed $cmd --grep="..." $myarg >actual &&
			test_must_be_empty actual &&

			shit -c grep.patternType=basic $cmd --grep="..." $myarg >actual &&
			test_file_not_empty actual
		)
	'
done

test_expect_success 'log --author' '
	cat >expect <<-\EOF &&
	Author: <BOLD;RED>A U<RESET> Thor <author@example.com>
	EOF
	shit log -1 --color=always --author="A U" >log &&
	grep Author log >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect actual
'

test_expect_success 'log --committer' '
	cat >expect <<-\EOF &&
	Commit:     C O Mitter <committer@<BOLD;RED>example<RESET>.com>
	EOF
	shit log -1 --color=always --pretty=fuller --committer="example" >log &&
	grep "Commit:" log >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect actual
'

test_expect_success 'log -i --grep with color' '
	cat >expect <<-\EOF &&
	    <BOLD;RED>Sec<RESET>ond
	    <BOLD;RED>sec<RESET>ond
	EOF
	shit log --color=always -i --grep=^sec >log &&
	grep -i sec log >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect actual
'

test_expect_success '-c color.grep.selected log --grep' '
	cat >expect <<-\EOF &&
	    <GREEN>th<RESET><BOLD;RED>ir<RESET><GREEN>d<RESET>
	EOF
	shit -c color.grep.selected="green" log --color=always --grep=ir >log &&
	grep ir log >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect actual
'

test_expect_success '-c color.grep.matchSelected log --grep' '
	cat >expect <<-\EOF &&
	    <BLUE>i<RESET>n<BLUE>i<RESET>t<BLUE>i<RESET>al
	EOF
	shit -c color.grep.matchSelected="blue" log --color=always --grep=i >log &&
	grep al log >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect actual
'

cat > expect <<EOF
* Second
* sixth
* fifth
* fourth
* third
* second
* initial
EOF

test_expect_success 'simple log --graph' '
	test_cmp_graph
'

cat > expect <<EOF
123 * Second
123 * sixth
123 * fifth
123 * fourth
123 * third
123 * second
123 * initial
EOF

test_expect_success 'simple log --graph --line-prefix="123 "' '
	test_cmp_graph --line-prefix="123 "
'

test_expect_success 'set up merge history' '
	shit checkout -b side HEAD~4 &&
	test_commit side-1 1 1 &&
	test_commit side-2 2 2 &&
	shit checkout main &&
	shit merge side
'

cat > expect <<\EOF
*   Merge branch 'side'
|\
| * side-2
| * side-1
* | Second
* | sixth
* | fifth
* | fourth
|/
* third
* second
* initial
EOF

test_expect_success 'log --graph with merge' '
	test_cmp_graph --date-order
'

cat > expect <<\EOF
| | | *   Merge branch 'side'
| | | |\
| | | | * side-2
| | | | * side-1
| | | * | Second
| | | * | sixth
| | | * | fifth
| | | * | fourth
| | | |/
| | | * third
| | | * second
| | | * initial
EOF

test_expect_success 'log --graph --line-prefix="| | | " with merge' '
	test_cmp_graph --line-prefix="| | | " --date-order
'

cat > expect.colors <<\EOF
*   Merge branch 'side'
<BLUE>|<RESET><CYAN>\<RESET>
<BLUE>|<RESET> * side-2
<BLUE>|<RESET> * side-1
* <CYAN>|<RESET> Second
* <CYAN>|<RESET> sixth
* <CYAN>|<RESET> fifth
* <CYAN>|<RESET> fourth
<CYAN>|<RESET><CYAN>/<RESET>
* third
* second
* initial
EOF

test_expect_success 'log --graph with merge with log.graphColors' '
	test_config log.graphColors " blue,invalid-color, cyan, red  , " &&
	lib_test_cmp_colored_graph --date-order --format=%s
'

test_expect_success 'log --raw --graph -m with merge' '
	shit log --raw --graph --oneline -m main | head -n 500 >actual &&
	grep "initial" actual
'

test_expect_success 'diff-tree --graph' '
	shit diff-tree --graph main^ | head -n 500 >actual &&
	grep "one" actual
'

cat > expect <<\EOF
*   commit main
|\  Merge: A B
| | Author: A U Thor <author@example.com>
| |
| |     Merge branch 'side'
| |
| * commit tags/side-2
| | Author: A U Thor <author@example.com>
| |
| |     side-2
| |
| * commit tags/side-1
| | Author: A U Thor <author@example.com>
| |
| |     side-1
| |
* | commit main~1
| | Author: A U Thor <author@example.com>
| |
| |     Second
| |
* | commit main~2
| | Author: A U Thor <author@example.com>
| |
| |     sixth
| |
* | commit main~3
| | Author: A U Thor <author@example.com>
| |
| |     fifth
| |
* | commit main~4
|/  Author: A U Thor <author@example.com>
|
|       fourth
|
* commit tags/side-1~1
| Author: A U Thor <author@example.com>
|
|     third
|
* commit tags/side-1~2
| Author: A U Thor <author@example.com>
|
|     second
|
* commit tags/side-1~3
  Author: A U Thor <author@example.com>

      initial
EOF

test_expect_success 'log --graph with full output' '
	shit log --graph --date-order --pretty=short |
		shit name-rev --name-only --annotate-stdin |
		sed "s/Merge:.*/Merge: A B/;s/ *\$//" >actual &&
	test_cmp expect actual
'

test_expect_success 'set up more tangled history' '
	shit checkout -b tangle HEAD~6 &&
	test_commit tangle-a tangle-a a &&
	shit merge main~3 &&
	shit update-ref refs/prefetch/merge HEAD &&
	shit merge side~1 &&
	shit update-ref refs/rewritten/merge HEAD &&
	shit checkout main &&
	shit merge tangle &&
	shit update-ref refs/hidden/tangle HEAD &&
	shit checkout -b reach &&
	test_commit reach &&
	shit checkout main &&
	shit checkout -b octopus-a &&
	test_commit octopus-a &&
	shit checkout main &&
	shit checkout -b octopus-b &&
	test_commit octopus-b &&
	shit checkout main &&
	test_commit seventh &&
	shit merge octopus-a octopus-b &&
	shit merge reach
'

cat > expect <<\EOF
*   Merge tag 'reach'
|\
| \
|  \
*-. \   Merge tags 'octopus-a' and 'octopus-b'
|\ \ \
* | | | seventh
| | * | octopus-b
| |/ /
|/| |
| * | octopus-a
|/ /
| * reach
|/
*   Merge branch 'tangle'
|\
| *   Merge branch 'side' (early part) into tangle
| |\
| * \   Merge branch 'main' (early part) into tangle
| |\ \
| * | | tangle-a
* | | |   Merge branch 'side'
|\ \ \ \
| * | | | side-2
| | |_|/
| |/| |
| * | | side-1
* | | | Second
* | | | sixth
| |_|/
|/| |
* | | fifth
* | | fourth
|/ /
* / third
|/
* second
* initial
EOF

test_expect_success 'log --graph with merge' '
	test_cmp_graph --date-order
'

test_expect_success 'log.decorate configuration' '
	shit log --oneline --no-decorate >expect.none &&
	shit log --oneline --decorate >expect.short &&
	shit log --oneline --decorate=full >expect.full &&

	echo "[log] decorate" >>.shit/config &&
	shit log --oneline >actual &&
	test_cmp expect.short actual &&

	test_config log.decorate true &&
	shit log --oneline >actual &&
	test_cmp expect.short actual &&
	shit log --oneline --decorate=full >actual &&
	test_cmp expect.full actual &&
	shit log --oneline --decorate=no >actual &&
	test_cmp expect.none actual &&

	test_config log.decorate no &&
	shit log --oneline >actual &&
	test_cmp expect.none actual &&
	shit log --oneline --decorate >actual &&
	test_cmp expect.short actual &&
	shit log --oneline --decorate=full >actual &&
	test_cmp expect.full actual &&

	test_config log.decorate 1 &&
	shit log --oneline >actual &&
	test_cmp expect.short actual &&
	shit log --oneline --decorate=full >actual &&
	test_cmp expect.full actual &&
	shit log --oneline --decorate=no >actual &&
	test_cmp expect.none actual &&

	test_config log.decorate short &&
	shit log --oneline >actual &&
	test_cmp expect.short actual &&
	shit log --oneline --no-decorate >actual &&
	test_cmp expect.none actual &&
	shit log --oneline --decorate=full >actual &&
	test_cmp expect.full actual &&

	test_config log.decorate full &&
	shit log --oneline >actual &&
	test_cmp expect.full actual &&
	shit log --oneline --no-decorate >actual &&
	test_cmp expect.none actual &&
	shit log --oneline --decorate >actual &&
	test_cmp expect.short actual &&

	test_unconfig log.decorate &&
	shit log --pretty=raw >expect.raw &&
	test_config log.decorate full &&
	shit log --pretty=raw >actual &&
	test_cmp expect.raw actual

'

test_expect_success 'parse log.excludeDecoration with no value' '
	cp .shit/config .shit/config.orig &&
	test_when_finished mv .shit/config.orig .shit/config &&

	cat >>.shit/config <<-\EOF &&
	[log]
		excludeDecoration
	EOF
	cat >expect <<-\EOF &&
	error: missing value for '\''log.excludeDecoration'\''
	EOF
	shit log --decorate=short 2>actual &&
	test_cmp expect actual
'

test_expect_success 'decorate-refs with glob' '
	cat >expect.decorate <<-\EOF &&
	Merge-tag-reach
	Merge-tags-octopus-a-and-octopus-b
	seventh
	octopus-b (octopus-b)
	octopus-a (octopus-a)
	reach
	EOF
	cat >expect.no-decorate <<-\EOF &&
	Merge-tag-reach
	Merge-tags-octopus-a-and-octopus-b
	seventh
	octopus-b
	octopus-a
	reach
	EOF
	shit log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs="heads/octopus*" >actual &&
	test_cmp expect.decorate actual &&
	shit log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs-exclude="heads/octopus*" \
		--decorate-refs="heads/octopus*" >actual &&
	test_cmp expect.no-decorate actual &&
	shit -c log.excludeDecoration="heads/octopus*" log \
		-n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs="heads/octopus*" >actual &&
	test_cmp expect.decorate actual
'

test_expect_success 'decorate-refs without globs' '
	cat >expect.decorate <<-\EOF &&
	Merge-tag-reach
	Merge-tags-octopus-a-and-octopus-b
	seventh
	octopus-b
	octopus-a
	reach (tag: reach)
	EOF
	shit log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs="tags/reach" >actual &&
	test_cmp expect.decorate actual
'

test_expect_success 'multiple decorate-refs' '
	cat >expect.decorate <<-\EOF &&
	Merge-tag-reach
	Merge-tags-octopus-a-and-octopus-b
	seventh
	octopus-b (octopus-b)
	octopus-a (octopus-a)
	reach (tag: reach)
	EOF
	shit log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs="heads/octopus*" \
		--decorate-refs="tags/reach" >actual &&
    test_cmp expect.decorate actual
'

test_expect_success 'decorate-refs-exclude with glob' '
	cat >expect.decorate <<-\EOF &&
	Merge-tag-reach (HEAD -> main)
	Merge-tags-octopus-a-and-octopus-b
	seventh (tag: seventh)
	octopus-b (tag: octopus-b)
	octopus-a (tag: octopus-a)
	reach (tag: reach, reach)
	EOF
	shit log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs-exclude="heads/octopus*" >actual &&
	test_cmp expect.decorate actual &&
	shit -c log.excludeDecoration="heads/octopus*" log \
		-n6 --decorate=short --pretty="tformat:%f%d" >actual &&
	test_cmp expect.decorate actual
'

test_expect_success 'decorate-refs-exclude without globs' '
	cat >expect.decorate <<-\EOF &&
	Merge-tag-reach (HEAD -> main)
	Merge-tags-octopus-a-and-octopus-b
	seventh (tag: seventh)
	octopus-b (tag: octopus-b, octopus-b)
	octopus-a (tag: octopus-a, octopus-a)
	reach (reach)
	EOF
	shit log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs-exclude="tags/reach" >actual &&
	test_cmp expect.decorate actual &&
	shit -c log.excludeDecoration="tags/reach" log \
		-n6 --decorate=short --pretty="tformat:%f%d" >actual &&
	test_cmp expect.decorate actual
'

test_expect_success 'multiple decorate-refs-exclude' '
	cat >expect.decorate <<-\EOF &&
	Merge-tag-reach (HEAD -> main)
	Merge-tags-octopus-a-and-octopus-b
	seventh (tag: seventh)
	octopus-b (tag: octopus-b)
	octopus-a (tag: octopus-a)
	reach (reach)
	EOF
	shit log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs-exclude="heads/octopus*" \
		--decorate-refs-exclude="tags/reach" >actual &&
	test_cmp expect.decorate actual &&
	shit -c log.excludeDecoration="heads/octopus*" \
		-c log.excludeDecoration="tags/reach" log \
		-n6 --decorate=short --pretty="tformat:%f%d" >actual &&
	test_cmp expect.decorate actual &&
	shit -c log.excludeDecoration="heads/octopus*" log \
		--decorate-refs-exclude="tags/reach" \
		-n6 --decorate=short --pretty="tformat:%f%d" >actual &&
	test_cmp expect.decorate actual
'

test_expect_success 'decorate-refs and decorate-refs-exclude' '
	cat >expect.no-decorate <<-\EOF &&
	Merge-tag-reach (main)
	Merge-tags-octopus-a-and-octopus-b
	seventh
	octopus-b
	octopus-a
	reach (reach)
	EOF
	shit log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs="heads/*" \
		--decorate-refs-exclude="heads/oc*" >actual &&
	test_cmp expect.no-decorate actual
'

test_expect_success 'deocrate-refs and log.excludeDecoration' '
	cat >expect.decorate <<-\EOF &&
	Merge-tag-reach (main)
	Merge-tags-octopus-a-and-octopus-b
	seventh
	octopus-b (octopus-b)
	octopus-a (octopus-a)
	reach (reach)
	EOF
	shit -c log.excludeDecoration="heads/oc*" log \
		--decorate-refs="heads/*" \
		-n6 --decorate=short --pretty="tformat:%f%d" >actual &&
	test_cmp expect.decorate actual
'

test_expect_success 'decorate-refs-exclude and simplify-by-decoration' '
	cat >expect.decorate <<-\EOF &&
	Merge-tag-reach (HEAD -> main)
	reach (tag: reach, reach)
	seventh (tag: seventh)
	Merge-branch-tangle (refs/hidden/tangle)
	Merge-branch-side-early-part-into-tangle (refs/rewritten/merge, tangle)
	Merge-branch-main-early-part-into-tangle (refs/prefetch/merge)
	EOF
	shit log -n6 --decorate=short --pretty="tformat:%f%d" \
		--decorate-refs-exclude="*octopus*" \
		--simplify-by-decoration >actual &&
	test_cmp expect.decorate actual &&
	shit -c log.excludeDecoration="*octopus*" log \
		-n6 --decorate=short --pretty="tformat:%f%d" \
		--simplify-by-decoration >actual &&
	test_cmp expect.decorate actual
'

test_expect_success 'decorate-refs with implied decorate from format' '
	cat >expect <<-\EOF &&
	side-2 (tag: side-2)
	side-1
	EOF
	shit log --no-walk --format="%s%d" \
		--decorate-refs="*side-2" side-1 side-2 \
		>actual &&
	test_cmp expect actual
'

test_expect_success 'implied decorate does not override option' '
	cat >expect <<-\EOF &&
	side-2 (tag: refs/tags/side-2, refs/heads/side)
	side-1 (tag: refs/tags/side-1)
	EOF
	shit log --no-walk --format="%s%d" \
		--decorate=full side-1 side-2 \
		>actual &&
	test_cmp expect actual
'

test_expect_success 'decorate-refs and simplify-by-decoration without output' '
	cat >expect <<-\EOF &&
	side-2
	initial
	EOF
	# Do not just use a --format without %d here; we want to
	# make sure that we did not accidentally turn on displaying
	# the decorations, too. And that requires one of the regular
	# formats.
	shit log --decorate-refs="*side-2" --oneline \
		--simplify-by-decoration >actual.raw &&
	sed "s/^[0-9a-f]* //" <actual.raw >actual &&
	test_cmp expect actual
'

test_expect_success 'decorate-refs-exclude HEAD' '
	shit log --decorate=full --oneline \
		--decorate-refs-exclude="HEAD" >actual &&
	! grep HEAD actual
'

test_expect_success 'decorate-refs focus from default' '
	shit log --decorate=full --oneline \
		--decorate-refs="refs/heads" >actual &&
	! grep HEAD actual
'

test_expect_success '--clear-decorations overrides defaults' '
	cat >expect.default <<-\EOF &&
	Merge-tag-reach (HEAD -> refs/heads/main)
	Merge-tags-octopus-a-and-octopus-b
	seventh (tag: refs/tags/seventh)
	octopus-b (tag: refs/tags/octopus-b, refs/heads/octopus-b)
	octopus-a (tag: refs/tags/octopus-a, refs/heads/octopus-a)
	reach (tag: refs/tags/reach, refs/heads/reach)
	Merge-branch-tangle
	Merge-branch-side-early-part-into-tangle (refs/heads/tangle)
	Merge-branch-main-early-part-into-tangle
	tangle-a (tag: refs/tags/tangle-a)
	Merge-branch-side
	side-2 (tag: refs/tags/side-2, refs/heads/side)
	side-1 (tag: refs/tags/side-1)
	Second
	sixth
	fifth
	fourth
	third
	second
	initial
	EOF
	shit log --decorate=full --pretty="tformat:%f%d" >actual &&
	test_cmp expect.default actual &&

	cat >expect.all <<-\EOF &&
	Merge-tag-reach (HEAD -> refs/heads/main)
	Merge-tags-octopus-a-and-octopus-b
	seventh (tag: refs/tags/seventh)
	octopus-b (tag: refs/tags/octopus-b, refs/heads/octopus-b)
	octopus-a (tag: refs/tags/octopus-a, refs/heads/octopus-a)
	reach (tag: refs/tags/reach, refs/heads/reach)
	Merge-branch-tangle (refs/hidden/tangle)
	Merge-branch-side-early-part-into-tangle (refs/rewritten/merge, refs/heads/tangle)
	Merge-branch-main-early-part-into-tangle (refs/prefetch/merge)
	tangle-a (tag: refs/tags/tangle-a)
	Merge-branch-side
	side-2 (tag: refs/tags/side-2, refs/heads/side)
	side-1 (tag: refs/tags/side-1)
	Second
	sixth
	fifth
	fourth
	third
	second
	initial
	EOF
	shit log --decorate=full --pretty="tformat:%f%d" \
		--clear-decorations >actual &&
	test_cmp expect.all actual &&
	shit -c log.initialDecorationSet=all log \
		--decorate=full --pretty="tformat:%f%d" >actual &&
	test_cmp expect.all actual
'

test_expect_success '--clear-decorations clears previous exclusions' '
	cat >expect.all <<-\EOF &&
	Merge-tag-reach (HEAD -> refs/heads/main)
	reach (tag: refs/tags/reach, refs/heads/reach)
	Merge-tags-octopus-a-and-octopus-b
	octopus-b (tag: refs/tags/octopus-b, refs/heads/octopus-b)
	octopus-a (tag: refs/tags/octopus-a, refs/heads/octopus-a)
	seventh (tag: refs/tags/seventh)
	Merge-branch-tangle (refs/hidden/tangle)
	Merge-branch-side-early-part-into-tangle (refs/rewritten/merge, refs/heads/tangle)
	Merge-branch-main-early-part-into-tangle (refs/prefetch/merge)
	tangle-a (tag: refs/tags/tangle-a)
	side-2 (tag: refs/tags/side-2, refs/heads/side)
	side-1 (tag: refs/tags/side-1)
	initial
	EOF

	shit log --decorate=full --pretty="tformat:%f%d" \
		--simplify-by-decoration \
		--decorate-refs-exclude="heads/octopus*" \
		--decorate-refs="heads" \
		--clear-decorations >actual &&
	test_cmp expect.all actual &&

	cat >expect.filtered <<-\EOF &&
	Merge-tags-octopus-a-and-octopus-b
	octopus-b (refs/heads/octopus-b)
	octopus-a (refs/heads/octopus-a)
	initial
	EOF

	shit log --decorate=full --pretty="tformat:%f%d" \
		--simplify-by-decoration \
		--decorate-refs-exclude="heads/octopus" \
		--decorate-refs="heads" \
		--clear-decorations \
		--decorate-refs-exclude="tags/" \
		--decorate-refs="heads/octopus*" >actual &&
	test_cmp expect.filtered actual
'

test_expect_success 'log.decorate config parsing' '
	shit log --oneline --decorate=full >expect.full &&
	shit log --oneline --decorate=short >expect.short &&

	test_config log.decorate full &&
	test_config log.mailmap true &&
	shit log --oneline >actual &&
	test_cmp expect.full actual &&
	shit log --oneline --decorate=short >actual &&
	test_cmp expect.short actual
'

test_expect_success TTY 'log output on a TTY' '
	shit log --color --oneline --decorate >expect.short &&

	test_terminal shit log --oneline >actual &&
	test_cmp expect.short actual
'

test_expect_success 'reflog is expected format' '
	shit log -g --abbrev-commit --pretty=oneline >expect &&
	shit reflog >actual &&
	test_cmp expect actual
'

test_expect_success 'whatchanged is expected format' '
	shit log --no-merges --raw >expect &&
	shit whatchanged >actual &&
	test_cmp expect actual
'

test_expect_success 'log.abbrevCommit configuration' '
	shit log --abbrev-commit >expect.log.abbrev &&
	shit log --no-abbrev-commit >expect.log.full &&
	shit log --pretty=raw >expect.log.raw &&
	shit reflog --abbrev-commit >expect.reflog.abbrev &&
	shit reflog --no-abbrev-commit >expect.reflog.full &&
	shit whatchanged --abbrev-commit >expect.whatchanged.abbrev &&
	shit whatchanged --no-abbrev-commit >expect.whatchanged.full &&

	test_config log.abbrevCommit true &&

	shit log >actual &&
	test_cmp expect.log.abbrev actual &&
	shit log --no-abbrev-commit >actual &&
	test_cmp expect.log.full actual &&

	shit log --pretty=raw >actual &&
	test_cmp expect.log.raw actual &&

	shit reflog >actual &&
	test_cmp expect.reflog.abbrev actual &&
	shit reflog --no-abbrev-commit >actual &&
	test_cmp expect.reflog.full actual &&

	shit whatchanged >actual &&
	test_cmp expect.whatchanged.abbrev actual &&
	shit whatchanged --no-abbrev-commit >actual &&
	test_cmp expect.whatchanged.full actual
'

test_expect_success 'show added path under "--follow -M"' '
	# This tests for a regression introduced in v1.7.2-rc0~103^2~2
	test_create_repo regression &&
	(
		cd regression &&
		test_commit needs-another-commit &&
		test_commit foo.bar &&
		shit log -M --follow -p foo.bar.t &&
		shit log -M --follow --stat foo.bar.t &&
		shit log -M --follow --name-only foo.bar.t
	)
'

test_expect_success 'shit log -c --follow' '
	test_create_repo follow-c &&
	(
		cd follow-c &&
		test_commit initial file original &&
		shit rm file &&
		test_commit rename file2 original &&
		shit reset --hard initial &&
		test_commit modify file foo &&
		shit merge -m merge rename &&
		shit log -c --follow file2
	)
'

cat >expect <<\EOF
*   commit COMMIT_OBJECT_NAME
|\  Merge: MERGE_PARENTS
| | Author: A U Thor <author@example.com>
| |
| |     Merge HEADS DESCRIPTION
| |
| * commit COMMIT_OBJECT_NAME
| | Author: A U Thor <author@example.com>
| |
| |     reach
| | ---
| |  reach.t | 1 +
| |  1 file changed, 1 insertion(+)
| |
| | diff --shit a/reach.t b/reach.t
| | new file mode 100644
| | index BEFORE..AFTER
| | --- /dev/null
| | +++ b/reach.t
| | @@ -0,0 +1 @@
| | +reach
| |
|  \
*-. \   commit COMMIT_OBJECT_NAME
|\ \ \  Merge: MERGE_PARENTS
| | | | Author: A U Thor <author@example.com>
| | | |
| | | |     Merge HEADS DESCRIPTION
| | | |
| | * | commit COMMIT_OBJECT_NAME
| | |/  Author: A U Thor <author@example.com>
| | |
| | |       octopus-b
| | |   ---
| | |    octopus-b.t | 1 +
| | |    1 file changed, 1 insertion(+)
| | |
| | |   diff --shit a/octopus-b.t b/octopus-b.t
| | |   new file mode 100644
| | |   index BEFORE..AFTER
| | |   --- /dev/null
| | |   +++ b/octopus-b.t
| | |   @@ -0,0 +1 @@
| | |   +octopus-b
| | |
| * | commit COMMIT_OBJECT_NAME
| |/  Author: A U Thor <author@example.com>
| |
| |       octopus-a
| |   ---
| |    octopus-a.t | 1 +
| |    1 file changed, 1 insertion(+)
| |
| |   diff --shit a/octopus-a.t b/octopus-a.t
| |   new file mode 100644
| |   index BEFORE..AFTER
| |   --- /dev/null
| |   +++ b/octopus-a.t
| |   @@ -0,0 +1 @@
| |   +octopus-a
| |
* | commit COMMIT_OBJECT_NAME
|/  Author: A U Thor <author@example.com>
|
|       seventh
|   ---
|    seventh.t | 1 +
|    1 file changed, 1 insertion(+)
|
|   diff --shit a/seventh.t b/seventh.t
|   new file mode 100644
|   index BEFORE..AFTER
|   --- /dev/null
|   +++ b/seventh.t
|   @@ -0,0 +1 @@
|   +seventh
|
*   commit COMMIT_OBJECT_NAME
|\  Merge: MERGE_PARENTS
| | Author: A U Thor <author@example.com>
| |
| |     Merge branch 'tangle'
| |
| *   commit COMMIT_OBJECT_NAME
| |\  Merge: MERGE_PARENTS
| | | Author: A U Thor <author@example.com>
| | |
| | |     Merge branch 'side' (early part) into tangle
| | |
| * |   commit COMMIT_OBJECT_NAME
| |\ \  Merge: MERGE_PARENTS
| | | | Author: A U Thor <author@example.com>
| | | |
| | | |     Merge branch 'main' (early part) into tangle
| | | |
| * | | commit COMMIT_OBJECT_NAME
| | | | Author: A U Thor <author@example.com>
| | | |
| | | |     tangle-a
| | | | ---
| | | |  tangle-a | 1 +
| | | |  1 file changed, 1 insertion(+)
| | | |
| | | | diff --shit a/tangle-a b/tangle-a
| | | | new file mode 100644
| | | | index BEFORE..AFTER
| | | | --- /dev/null
| | | | +++ b/tangle-a
| | | | @@ -0,0 +1 @@
| | | | +a
| | | |
* | | |   commit COMMIT_OBJECT_NAME
|\ \ \ \  Merge: MERGE_PARENTS
| | | | | Author: A U Thor <author@example.com>
| | | | |
| | | | |     Merge branch 'side'
| | | | |
| * | | | commit COMMIT_OBJECT_NAME
| | |_|/  Author: A U Thor <author@example.com>
| |/| |
| | | |       side-2
| | | |   ---
| | | |    2 | 1 +
| | | |    1 file changed, 1 insertion(+)
| | | |
| | | |   diff --shit a/2 b/2
| | | |   new file mode 100644
| | | |   index BEFORE..AFTER
| | | |   --- /dev/null
| | | |   +++ b/2
| | | |   @@ -0,0 +1 @@
| | | |   +2
| | | |
| * | | commit COMMIT_OBJECT_NAME
| | | | Author: A U Thor <author@example.com>
| | | |
| | | |     side-1
| | | | ---
| | | |  1 | 1 +
| | | |  1 file changed, 1 insertion(+)
| | | |
| | | | diff --shit a/1 b/1
| | | | new file mode 100644
| | | | index BEFORE..AFTER
| | | | --- /dev/null
| | | | +++ b/1
| | | | @@ -0,0 +1 @@
| | | | +1
| | | |
* | | | commit COMMIT_OBJECT_NAME
| | | | Author: A U Thor <author@example.com>
| | | |
| | | |     Second
| | | | ---
| | | |  one | 1 +
| | | |  1 file changed, 1 insertion(+)
| | | |
| | | | diff --shit a/one b/one
| | | | new file mode 100644
| | | | index BEFORE..AFTER
| | | | --- /dev/null
| | | | +++ b/one
| | | | @@ -0,0 +1 @@
| | | | +case
| | | |
* | | | commit COMMIT_OBJECT_NAME
| |_|/  Author: A U Thor <author@example.com>
|/| |
| | |       sixth
| | |   ---
| | |    a/two | 1 -
| | |    1 file changed, 1 deletion(-)
| | |
| | |   diff --shit a/a/two b/a/two
| | |   deleted file mode 100644
| | |   index BEFORE..AFTER
| | |   --- a/a/two
| | |   +++ /dev/null
| | |   @@ -1 +0,0 @@
| | |   -ni
| | |
* | | commit COMMIT_OBJECT_NAME
| | | Author: A U Thor <author@example.com>
| | |
| | |     fifth
| | | ---
| | |  a/two | 1 +
| | |  1 file changed, 1 insertion(+)
| | |
| | | diff --shit a/a/two b/a/two
| | | new file mode 100644
| | | index BEFORE..AFTER
| | | --- /dev/null
| | | +++ b/a/two
| | | @@ -0,0 +1 @@
| | | +ni
| | |
* | | commit COMMIT_OBJECT_NAME
|/ /  Author: A U Thor <author@example.com>
| |
| |       fourth
| |   ---
| |    ein | 1 +
| |    1 file changed, 1 insertion(+)
| |
| |   diff --shit a/ein b/ein
| |   new file mode 100644
| |   index BEFORE..AFTER
| |   --- /dev/null
| |   +++ b/ein
| |   @@ -0,0 +1 @@
| |   +ichi
| |
* | commit COMMIT_OBJECT_NAME
|/  Author: A U Thor <author@example.com>
|
|       third
|   ---
|    ichi | 1 +
|    one  | 1 -
|    2 files changed, 1 insertion(+), 1 deletion(-)
|
|   diff --shit a/ichi b/ichi
|   new file mode 100644
|   index BEFORE..AFTER
|   --- /dev/null
|   +++ b/ichi
|   @@ -0,0 +1 @@
|   +ichi
|   diff --shit a/one b/one
|   deleted file mode 100644
|   index BEFORE..AFTER
|   --- a/one
|   +++ /dev/null
|   @@ -1 +0,0 @@
|   -ichi
|
* commit COMMIT_OBJECT_NAME
| Author: A U Thor <author@example.com>
|
|     second
| ---
|  one | 2 +-
|  1 file changed, 1 insertion(+), 1 deletion(-)
|
| diff --shit a/one b/one
| index BEFORE..AFTER 100644
| --- a/one
| +++ b/one
| @@ -1 +1 @@
| -one
| +ichi
|
* commit COMMIT_OBJECT_NAME
  Author: A U Thor <author@example.com>

      initial
  ---
   one | 1 +
   1 file changed, 1 insertion(+)

  diff --shit a/one b/one
  new file mode 100644
  index BEFORE..AFTER
  --- /dev/null
  +++ b/one
  @@ -0,0 +1 @@
  +one
EOF

test_expect_success 'log --graph with diff and stats' '
	lib_test_cmp_short_graph --no-renames --stat -p
'

cat >expect <<\EOF
*** *   commit COMMIT_OBJECT_NAME
*** |\  Merge: MERGE_PARENTS
*** | | Author: A U Thor <author@example.com>
*** | |
*** | |     Merge HEADS DESCRIPTION
*** | |
*** | * commit COMMIT_OBJECT_NAME
*** | | Author: A U Thor <author@example.com>
*** | |
*** | |     reach
*** | | ---
*** | |  reach.t | 1 +
*** | |  1 file changed, 1 insertion(+)
*** | |
*** | | diff --shit a/reach.t b/reach.t
*** | | new file mode 100644
*** | | index BEFORE..AFTER
*** | | --- /dev/null
*** | | +++ b/reach.t
*** | | @@ -0,0 +1 @@
*** | | +reach
*** | |
*** |  \
*** *-. \   commit COMMIT_OBJECT_NAME
*** |\ \ \  Merge: MERGE_PARENTS
*** | | | | Author: A U Thor <author@example.com>
*** | | | |
*** | | | |     Merge HEADS DESCRIPTION
*** | | | |
*** | | * | commit COMMIT_OBJECT_NAME
*** | | |/  Author: A U Thor <author@example.com>
*** | | |
*** | | |       octopus-b
*** | | |   ---
*** | | |    octopus-b.t | 1 +
*** | | |    1 file changed, 1 insertion(+)
*** | | |
*** | | |   diff --shit a/octopus-b.t b/octopus-b.t
*** | | |   new file mode 100644
*** | | |   index BEFORE..AFTER
*** | | |   --- /dev/null
*** | | |   +++ b/octopus-b.t
*** | | |   @@ -0,0 +1 @@
*** | | |   +octopus-b
*** | | |
*** | * | commit COMMIT_OBJECT_NAME
*** | |/  Author: A U Thor <author@example.com>
*** | |
*** | |       octopus-a
*** | |   ---
*** | |    octopus-a.t | 1 +
*** | |    1 file changed, 1 insertion(+)
*** | |
*** | |   diff --shit a/octopus-a.t b/octopus-a.t
*** | |   new file mode 100644
*** | |   index BEFORE..AFTER
*** | |   --- /dev/null
*** | |   +++ b/octopus-a.t
*** | |   @@ -0,0 +1 @@
*** | |   +octopus-a
*** | |
*** * | commit COMMIT_OBJECT_NAME
*** |/  Author: A U Thor <author@example.com>
*** |
*** |       seventh
*** |   ---
*** |    seventh.t | 1 +
*** |    1 file changed, 1 insertion(+)
*** |
*** |   diff --shit a/seventh.t b/seventh.t
*** |   new file mode 100644
*** |   index BEFORE..AFTER
*** |   --- /dev/null
*** |   +++ b/seventh.t
*** |   @@ -0,0 +1 @@
*** |   +seventh
*** |
*** *   commit COMMIT_OBJECT_NAME
*** |\  Merge: MERGE_PARENTS
*** | | Author: A U Thor <author@example.com>
*** | |
*** | |     Merge branch 'tangle'
*** | |
*** | *   commit COMMIT_OBJECT_NAME
*** | |\  Merge: MERGE_PARENTS
*** | | | Author: A U Thor <author@example.com>
*** | | |
*** | | |     Merge branch 'side' (early part) into tangle
*** | | |
*** | * |   commit COMMIT_OBJECT_NAME
*** | |\ \  Merge: MERGE_PARENTS
*** | | | | Author: A U Thor <author@example.com>
*** | | | |
*** | | | |     Merge branch 'main' (early part) into tangle
*** | | | |
*** | * | | commit COMMIT_OBJECT_NAME
*** | | | | Author: A U Thor <author@example.com>
*** | | | |
*** | | | |     tangle-a
*** | | | | ---
*** | | | |  tangle-a | 1 +
*** | | | |  1 file changed, 1 insertion(+)
*** | | | |
*** | | | | diff --shit a/tangle-a b/tangle-a
*** | | | | new file mode 100644
*** | | | | index BEFORE..AFTER
*** | | | | --- /dev/null
*** | | | | +++ b/tangle-a
*** | | | | @@ -0,0 +1 @@
*** | | | | +a
*** | | | |
*** * | | |   commit COMMIT_OBJECT_NAME
*** |\ \ \ \  Merge: MERGE_PARENTS
*** | | | | | Author: A U Thor <author@example.com>
*** | | | | |
*** | | | | |     Merge branch 'side'
*** | | | | |
*** | * | | | commit COMMIT_OBJECT_NAME
*** | | |_|/  Author: A U Thor <author@example.com>
*** | |/| |
*** | | | |       side-2
*** | | | |   ---
*** | | | |    2 | 1 +
*** | | | |    1 file changed, 1 insertion(+)
*** | | | |
*** | | | |   diff --shit a/2 b/2
*** | | | |   new file mode 100644
*** | | | |   index BEFORE..AFTER
*** | | | |   --- /dev/null
*** | | | |   +++ b/2
*** | | | |   @@ -0,0 +1 @@
*** | | | |   +2
*** | | | |
*** | * | | commit COMMIT_OBJECT_NAME
*** | | | | Author: A U Thor <author@example.com>
*** | | | |
*** | | | |     side-1
*** | | | | ---
*** | | | |  1 | 1 +
*** | | | |  1 file changed, 1 insertion(+)
*** | | | |
*** | | | | diff --shit a/1 b/1
*** | | | | new file mode 100644
*** | | | | index BEFORE..AFTER
*** | | | | --- /dev/null
*** | | | | +++ b/1
*** | | | | @@ -0,0 +1 @@
*** | | | | +1
*** | | | |
*** * | | | commit COMMIT_OBJECT_NAME
*** | | | | Author: A U Thor <author@example.com>
*** | | | |
*** | | | |     Second
*** | | | | ---
*** | | | |  one | 1 +
*** | | | |  1 file changed, 1 insertion(+)
*** | | | |
*** | | | | diff --shit a/one b/one
*** | | | | new file mode 100644
*** | | | | index BEFORE..AFTER
*** | | | | --- /dev/null
*** | | | | +++ b/one
*** | | | | @@ -0,0 +1 @@
*** | | | | +case
*** | | | |
*** * | | | commit COMMIT_OBJECT_NAME
*** | |_|/  Author: A U Thor <author@example.com>
*** |/| |
*** | | |       sixth
*** | | |   ---
*** | | |    a/two | 1 -
*** | | |    1 file changed, 1 deletion(-)
*** | | |
*** | | |   diff --shit a/a/two b/a/two
*** | | |   deleted file mode 100644
*** | | |   index BEFORE..AFTER
*** | | |   --- a/a/two
*** | | |   +++ /dev/null
*** | | |   @@ -1 +0,0 @@
*** | | |   -ni
*** | | |
*** * | | commit COMMIT_OBJECT_NAME
*** | | | Author: A U Thor <author@example.com>
*** | | |
*** | | |     fifth
*** | | | ---
*** | | |  a/two | 1 +
*** | | |  1 file changed, 1 insertion(+)
*** | | |
*** | | | diff --shit a/a/two b/a/two
*** | | | new file mode 100644
*** | | | index BEFORE..AFTER
*** | | | --- /dev/null
*** | | | +++ b/a/two
*** | | | @@ -0,0 +1 @@
*** | | | +ni
*** | | |
*** * | | commit COMMIT_OBJECT_NAME
*** |/ /  Author: A U Thor <author@example.com>
*** | |
*** | |       fourth
*** | |   ---
*** | |    ein | 1 +
*** | |    1 file changed, 1 insertion(+)
*** | |
*** | |   diff --shit a/ein b/ein
*** | |   new file mode 100644
*** | |   index BEFORE..AFTER
*** | |   --- /dev/null
*** | |   +++ b/ein
*** | |   @@ -0,0 +1 @@
*** | |   +ichi
*** | |
*** * | commit COMMIT_OBJECT_NAME
*** |/  Author: A U Thor <author@example.com>
*** |
*** |       third
*** |   ---
*** |    ichi | 1 +
*** |    one  | 1 -
*** |    2 files changed, 1 insertion(+), 1 deletion(-)
*** |
*** |   diff --shit a/ichi b/ichi
*** |   new file mode 100644
*** |   index BEFORE..AFTER
*** |   --- /dev/null
*** |   +++ b/ichi
*** |   @@ -0,0 +1 @@
*** |   +ichi
*** |   diff --shit a/one b/one
*** |   deleted file mode 100644
*** |   index BEFORE..AFTER
*** |   --- a/one
*** |   +++ /dev/null
*** |   @@ -1 +0,0 @@
*** |   -ichi
*** |
*** * commit COMMIT_OBJECT_NAME
*** | Author: A U Thor <author@example.com>
*** |
*** |     second
*** | ---
*** |  one | 2 +-
*** |  1 file changed, 1 insertion(+), 1 deletion(-)
*** |
*** | diff --shit a/one b/one
*** | index BEFORE..AFTER 100644
*** | --- a/one
*** | +++ b/one
*** | @@ -1 +1 @@
*** | -one
*** | +ichi
*** |
*** * commit COMMIT_OBJECT_NAME
***   Author: A U Thor <author@example.com>
***
***       initial
***   ---
***    one | 1 +
***    1 file changed, 1 insertion(+)
***
***   diff --shit a/one b/one
***   new file mode 100644
***   index BEFORE..AFTER
***   --- /dev/null
***   +++ b/one
***   @@ -0,0 +1 @@
***   +one
EOF

test_expect_success 'log --line-prefix="*** " --graph with diff and stats' '
	lib_test_cmp_short_graph --line-prefix="*** " --no-renames --stat -p
'

cat >expect <<-\EOF
* reach
|
| A	reach.t
* Merge branch 'tangle'
*   Merge branch 'side'
|\
| * side-2
|
|   A	2
* Second
|
| A	one
* sixth

  D	a/two
EOF

test_expect_success 'log --graph with --name-status' '
	test_cmp_graph --name-status tangle..reach
'

cat >expect <<-\EOF
* reach
|
| reach.t
* Merge branch 'tangle'
*   Merge branch 'side'
|\
| * side-2
|
|   2
* Second
|
| one
* sixth

  a/two
EOF

test_expect_success 'log --graph with --name-only' '
	test_cmp_graph --name-only tangle..reach
'

test_expect_success '--no-graph countermands --graph' '
	shit log >expect &&
	shit log --graph --no-graph >actual &&
	test_cmp expect actual
'

test_expect_success '--graph countermands --no-graph' '
	shit log --graph >expect &&
	shit log --no-graph --graph >actual &&
	test_cmp expect actual
'

test_expect_success '--no-graph does not unset --topo-order' '
	shit log --topo-order >expect &&
	shit log --topo-order --no-graph >actual &&
	test_cmp expect actual
'

test_expect_success '--no-graph does not unset --parents' '
	shit log --parents >expect &&
	shit log --parents --no-graph >actual &&
	test_cmp expect actual
'

test_expect_success '--reverse and --graph conflict' '
	test_must_fail shit log --reverse --graph 2>stderr &&
	test_grep "cannot be used together" stderr
'

test_expect_success '--reverse --graph --no-graph works' '
	shit log --reverse >expect &&
	shit log --reverse --graph --no-graph >actual &&
	test_cmp expect actual
'

test_expect_success '--show-linear-break and --graph conflict' '
	test_must_fail shit log --show-linear-break --graph 2>stderr &&
	test_grep "cannot be used together" stderr
'

test_expect_success '--show-linear-break --graph --no-graph works' '
	shit log --show-linear-break >expect &&
	shit log --show-linear-break --graph --no-graph >actual &&
	test_cmp expect actual
'

test_expect_success '--no-walk and --graph conflict' '
	test_must_fail shit log --no-walk --graph 2>stderr &&
	test_grep "cannot be used together" stderr
'

test_expect_success '--no-walk --graph --no-graph works' '
	shit log --no-walk >expect &&
	shit log --no-walk --graph --no-graph >actual &&
	test_cmp expect actual
'

test_expect_success '--walk-reflogs and --graph conflict' '
	test_must_fail shit log --walk-reflogs --graph 2>stderr &&
	(test_grep "cannot combine" stderr ||
		test_grep "cannot be used together" stderr)
'

test_expect_success '--walk-reflogs --graph --no-graph works' '
	shit log --walk-reflogs >expect &&
	shit log --walk-reflogs --graph --no-graph >actual &&
	test_cmp expect actual
'

test_expect_success 'dotdot is a parent directory' '
	mkdir -p a/b &&
	( echo sixth && echo fifth ) >expect &&
	( cd a/b && shit log --format=%s .. ) >actual &&
	test_cmp expect actual
'

test_expect_success GPG 'setup signed branch' '
	test_when_finished "shit reset --hard && shit checkout main" &&
	shit checkout -b signed main &&
	echo foo >foo &&
	shit add foo &&
	shit commit -S -m signed_commit
'

test_expect_success GPG 'setup signed branch with subkey' '
	test_when_finished "shit reset --hard && shit checkout main" &&
	shit checkout -b signed-subkey main &&
	echo foo >foo &&
	shit add foo &&
	shit commit -SB7227189 -m signed_commit
'

test_expect_success GPGSM 'setup signed branch x509' '
	test_when_finished "shit reset --hard && shit checkout main" &&
	shit checkout -b signed-x509 main &&
	echo foo >foo &&
	shit add foo &&
	test_config gpg.format x509 &&
	test_config user.signingkey $shit_COMMITTER_EMAIL &&
	shit commit -S -m signed_commit
'

test_expect_success GPGSSH 'setup sshkey signed branch' '
	test_config gpg.format ssh &&
	test_config user.signingkey "${GPGSSH_KEY_PRIMARY}" &&
	test_when_finished "shit reset --hard && shit checkout main" &&
	shit checkout -b signed-ssh main &&
	echo foo >foo &&
	shit add foo &&
	shit commit -S -m signed_commit
'

test_expect_success GPGSSH,GPGSSH_VERIFYTIME 'create signed commits with keys having defined lifetimes' '
	test_config gpg.format ssh &&
	touch file &&
	shit add file &&

	echo expired >file && test_tick && shit commit -a -m expired -S"${GPGSSH_KEY_EXPIRED}" &&
	shit tag expired-signed &&

	echo notyetvalid >file && test_tick && shit commit -a -m notyetvalid -S"${GPGSSH_KEY_NOTYETVALID}" &&
	shit tag notyetvalid-signed &&

	echo timeboxedvalid >file && test_tick && shit commit -a -m timeboxedvalid -S"${GPGSSH_KEY_TIMEBOXEDVALID}" &&
	shit tag timeboxedvalid-signed &&

	echo timeboxedinvalid >file && test_tick && shit commit -a -m timeboxedinvalid -S"${GPGSSH_KEY_TIMEBOXEDINVALID}" &&
	shit tag timeboxedinvalid-signed
'

test_expect_success GPGSM 'log x509 fingerprint' '
	echo "F8BF62E0693D0694816377099909C779FA23FD65 | " >expect &&
	shit log -n1 --format="%GF | %GP" signed-x509 >actual &&
	test_cmp expect actual
'

test_expect_success GPGSM 'log OpenPGP fingerprint' '
	echo "D4BE22311AD3131E5EDA29A461092E85B7227189" > expect &&
	shit log -n1 --format="%GP" signed-subkey >actual &&
	test_cmp expect actual
'

test_expect_success GPGSSH 'log ssh key fingerprint' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	ssh-keygen -lf  "${GPGSSH_KEY_PRIMARY}" | awk "{print \$2\" | \"}" >expect &&
	shit log -n1 --format="%GF | %GP" signed-ssh >actual &&
	test_cmp expect actual
'

test_expect_success GPG 'log --graph --show-signature' '
	shit log --graph --show-signature -n1 signed >actual &&
	grep "^| gpg: Signature made" actual &&
	grep "^| gpg: Good signature" actual
'

test_expect_success GPGSM 'log --graph --show-signature x509' '
	shit log --graph --show-signature -n1 signed-x509 >actual &&
	grep "^| gpgsm: Signature made" actual &&
	grep "^| gpgsm: Good signature" actual
'

test_expect_success GPGSSH 'log --graph --show-signature ssh' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit log --graph --show-signature -n1 signed-ssh >actual &&
	grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual
'

test_expect_success GPGSSH,GPGSSH_VERIFYTIME 'log shows failure on expired signature key' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit log --graph --show-signature -n1 expired-signed >actual &&
	! grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual
'

test_expect_success GPGSSH,GPGSSH_VERIFYTIME 'log shows failure on not yet valid signature key' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit log --graph --show-signature -n1 notyetvalid-signed >actual &&
	! grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual
'

test_expect_success GPGSSH,GPGSSH_VERIFYTIME 'log show success with commit date and key validity matching' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit log --graph --show-signature -n1 timeboxedvalid-signed >actual &&
	grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual &&
	! grep "${GPGSSH_BAD_SIGNATURE}" actual
'

test_expect_success GPGSSH,GPGSSH_VERIFYTIME 'log shows failure with commit date outside of key validity' '
	test_config gpg.ssh.allowedSignersFile "${GPGSSH_ALLOWED_SIGNERS}" &&
	shit log --graph --show-signature -n1 timeboxedinvalid-signed >actual &&
	! grep "${GPGSSH_GOOD_SIGNATURE_TRUSTED}" actual
'

test_expect_success GPG 'log --graph --show-signature for merged tag' '
	test_when_finished "shit reset --hard && shit checkout main" &&
	shit checkout -b plain main &&
	echo aaa >bar &&
	shit add bar &&
	shit commit -m bar_commit &&
	shit checkout -b tagged main &&
	echo bbb >baz &&
	shit add baz &&
	shit commit -m baz_commit &&
	shit tag -s -m signed_tag_msg signed_tag &&
	shit checkout plain &&
	shit merge --no-ff -m msg signed_tag &&
	shit log --graph --show-signature -n1 plain >actual &&
	grep "^|\\\  merged tag" actual &&
	grep "^| | gpg: Signature made" actual &&
	grep "^| | gpg: Good signature" actual
'

test_expect_success GPG 'log --graph --show-signature for merged tag in shallow clone' '
	test_when_finished "shit reset --hard && shit checkout main" &&
	shit checkout -b plain-shallow main &&
	echo aaa >bar &&
	shit add bar &&
	shit commit -m bar_commit &&
	shit checkout --detach main &&
	echo bbb >baz &&
	shit add baz &&
	shit commit -m baz_commit &&
	shit tag -s -m signed_tag_msg signed_tag_shallow &&
	hash=$(shit rev-parse HEAD) &&
	shit checkout plain-shallow &&
	shit merge --no-ff -m msg signed_tag_shallow &&
	shit clone --depth 1 --no-local . shallow &&
	test_when_finished "rm -rf shallow" &&
	shit -C shallow log --graph --show-signature -n1 plain-shallow >actual &&
	grep "tag signed_tag_shallow names a non-parent $hash" actual
'

test_expect_success GPG 'log --graph --show-signature for merged tag with missing key' '
	test_when_finished "shit reset --hard && shit checkout main" &&
	shit checkout -b plain-nokey main &&
	echo aaa >bar &&
	shit add bar &&
	shit commit -m bar_commit &&
	shit checkout -b tagged-nokey main &&
	echo bbb >baz &&
	shit add baz &&
	shit commit -m baz_commit &&
	shit tag -s -m signed_tag_msg signed_tag_nokey &&
	shit checkout plain-nokey &&
	shit merge --no-ff -m msg signed_tag_nokey &&
	GNUPGHOME=. shit log --graph --show-signature -n1 plain-nokey >actual &&
	grep "^|\\\  merged tag" actual &&
	grep "^| | gpg: Signature made" actual &&
	grep -E "^| | gpg: Can'"'"'t check signature: (public key not found|No public key)" actual
'

test_expect_success GPG 'log --graph --show-signature for merged tag with bad signature' '
	test_when_finished "shit reset --hard && shit checkout main" &&
	shit checkout -b plain-bad main &&
	echo aaa >bar &&
	shit add bar &&
	shit commit -m bar_commit &&
	shit checkout -b tagged-bad main &&
	echo bbb >baz &&
	shit add baz &&
	shit commit -m baz_commit &&
	shit tag -s -m signed_tag_msg signed_tag_bad &&
	shit cat-file tag signed_tag_bad >raw &&
	sed -e "s/signed_tag_msg/forged/" raw >forged &&
	shit hash-object -w -t tag forged >forged.tag &&
	shit checkout plain-bad &&
	shit merge --no-ff -m msg "$(cat forged.tag)" &&
	shit log --graph --show-signature -n1 plain-bad >actual &&
	grep "^|\\\  merged tag" actual &&
	grep "^| | gpg: Signature made" actual &&
	grep "^| | gpg: BAD signature from" actual
'

test_expect_success GPG 'log --show-signature for merged tag with GPG failure' '
	test_when_finished "shit reset --hard && shit checkout main" &&
	shit checkout -b plain-fail main &&
	echo aaa >bar &&
	shit add bar &&
	shit commit -m bar_commit &&
	shit checkout -b tagged-fail main &&
	echo bbb >baz &&
	shit add baz &&
	shit commit -m baz_commit &&
	shit tag -s -m signed_tag_msg signed_tag_fail &&
	shit checkout plain-fail &&
	shit merge --no-ff -m msg signed_tag_fail &&
	if ! test_have_prereq VALGRIND
	then
		TMPDIR="$(pwd)/bogus" shit log --show-signature -n1 plain-fail >actual &&
		grep "^merged tag" actual &&
		grep "^No signature" actual &&
		! grep "^gpg: Signature made" actual
	fi
'

test_expect_success GPGSM 'log --graph --show-signature for merged tag x509' '
	test_when_finished "shit reset --hard && shit checkout main" &&
	test_config gpg.format x509 &&
	test_config user.signingkey $shit_COMMITTER_EMAIL &&
	shit checkout -b plain-x509 main &&
	echo aaa >bar &&
	shit add bar &&
	shit commit -m bar_commit &&
	shit checkout -b tagged-x509 main &&
	echo bbb >baz &&
	shit add baz &&
	shit commit -m baz_commit &&
	shit tag -s -m signed_tag_msg signed_tag_x509 &&
	shit checkout plain-x509 &&
	shit merge --no-ff -m msg signed_tag_x509 &&
	shit log --graph --show-signature -n1 plain-x509 >actual &&
	grep "^|\\\  merged tag" actual &&
	grep "^| | gpgsm: Signature made" actual &&
	grep "^| | gpgsm: Good signature" actual
'

test_expect_success GPGSM 'log --graph --show-signature for merged tag x509 missing key' '
	test_when_finished "shit reset --hard && shit checkout main" &&
	test_config gpg.format x509 &&
	test_config user.signingkey $shit_COMMITTER_EMAIL &&
	shit checkout -b plain-x509-nokey main &&
	echo aaa >bar &&
	shit add bar &&
	shit commit -m bar_commit &&
	shit checkout -b tagged-x509-nokey main &&
	echo bbb >baz &&
	shit add baz &&
	shit commit -m baz_commit &&
	shit tag -s -m signed_tag_msg signed_tag_x509_nokey &&
	shit checkout plain-x509-nokey &&
	shit merge --no-ff -m msg signed_tag_x509_nokey &&
	GNUPGHOME=. shit log --graph --show-signature -n1 plain-x509-nokey >actual &&
	grep "^|\\\  merged tag" actual &&
	grep -e "^| | gpgsm: certificate not found" \
	     -e "^| | gpgsm: failed to find the certificate: Not found" actual
'

test_expect_success GPGSM 'log --graph --show-signature for merged tag x509 bad signature' '
	test_when_finished "shit reset --hard && shit checkout main" &&
	test_config gpg.format x509 &&
	test_config user.signingkey $shit_COMMITTER_EMAIL &&
	shit checkout -b plain-x509-bad main &&
	echo aaa >bar &&
	shit add bar &&
	shit commit -m bar_commit &&
	shit checkout -b tagged-x509-bad main &&
	echo bbb >baz &&
	shit add baz &&
	shit commit -m baz_commit &&
	shit tag -s -m signed_tag_msg signed_tag_x509_bad &&
	shit cat-file tag signed_tag_x509_bad >raw &&
	sed -e "s/signed_tag_msg/forged/" raw >forged &&
	shit hash-object -w -t tag forged >forged.tag &&
	shit checkout plain-x509-bad &&
	shit merge --no-ff -m msg "$(cat forged.tag)" &&
	shit log --graph --show-signature -n1 plain-x509-bad >actual &&
	grep "^|\\\  merged tag" actual &&
	grep "^| | gpgsm: Signature made" actual &&
	grep "^| | gpgsm: invalid signature" actual
'


test_expect_success GPG '--no-show-signature overrides --show-signature' '
	shit log -1 --show-signature --no-show-signature signed >actual &&
	! grep "^gpg:" actual
'

test_expect_success GPG 'log.showsignature=true behaves like --show-signature' '
	test_config log.showsignature true &&
	shit log -1 signed >actual &&
	grep "gpg: Signature made" actual &&
	grep "gpg: Good signature" actual
'

test_expect_success GPG '--no-show-signature overrides log.showsignature=true' '
	test_config log.showsignature true &&
	shit log -1 --no-show-signature signed >actual &&
	! grep "^gpg:" actual
'

test_expect_success GPG '--show-signature overrides log.showsignature=false' '
	test_config log.showsignature false &&
	shit log -1 --show-signature signed >actual &&
	grep "gpg: Signature made" actual &&
	grep "gpg: Good signature" actual
'

test_expect_success 'log --graph --no-walk is forbidden' '
	test_must_fail shit log --graph --no-walk
'

test_expect_success 'log on empty repo fails' '
	shit init empty &&
	test_when_finished "rm -rf empty" &&
	test_must_fail shit -C empty log 2>stderr &&
	test_grep does.not.have.any.commits stderr
'

test_expect_success 'log does not default to HEAD when rev input is given' '
	shit log --branches=does-not-exist >actual &&
	test_must_be_empty actual
'

test_expect_success 'do not default to HEAD with ignored object on cmdline' '
	shit log --ignore-missing $ZERO_OID >actual &&
	test_must_be_empty actual
'

test_expect_success 'do not default to HEAD with ignored object on stdin' '
	echo $ZERO_OID | shit log --ignore-missing --stdin >actual &&
	test_must_be_empty actual
'

test_expect_success 'set up --source tests' '
	shit checkout --orphan source-a &&
	test_commit one &&
	test_commit two &&
	shit checkout -b source-b HEAD^ &&
	test_commit three
'

test_expect_success 'log --source paints branch names' '
	cat >expect <<-EOF &&
	$(shit rev-parse --short :/three)	source-b three
	$(shit rev-parse --short :/two  )	source-a two
	$(shit rev-parse --short :/one  )	source-b one
	EOF
	shit log --oneline --source source-a source-b >actual &&
	test_cmp expect actual
'

test_expect_success 'log --source paints tag names' '
	shit tag -m tagged source-tag &&
	cat >expect <<-EOF &&
	$(shit rev-parse --short :/three)	source-tag three
	$(shit rev-parse --short :/two  )	source-a two
	$(shit rev-parse --short :/one  )	source-tag one
	EOF
	shit log --oneline --source source-tag source-a >actual &&
	test_cmp expect actual
'

test_expect_success 'log --source paints symmetric ranges' '
	cat >expect <<-EOF &&
	$(shit rev-parse --short :/three)	source-b three
	$(shit rev-parse --short :/two  )	source-a two
	EOF
	shit log --oneline --source source-a...source-b >actual &&
	test_cmp expect actual
'

test_expect_success '--exclude-promisor-objects does not BUG-crash' '
	test_must_fail shit log --exclude-promisor-objects source-a
'

test_expect_success 'log --decorate includes all levels of tag annotated tags' '
	shit checkout -b branch &&
	shit commit --allow-empty -m "new commit" &&
	shit tag lightweight HEAD &&
	shit tag -m annotated annotated HEAD &&
	shit tag -m double-0 double-0 HEAD &&
	shit tag -m double-1 double-1 double-0 &&
	cat >expect <<-\EOF &&
	HEAD -> branch, tag: lightweight, tag: double-1, tag: double-0, tag: annotated
	EOF
	shit log -1 --format="%D" >actual &&
	test_cmp expect actual
'

test_expect_success 'log --decorate does not include things outside filter' '
	reflist="refs/prefetch refs/rebase-merge refs/bundle" &&

	for ref in $reflist
	do
		shit update-ref $ref/fake HEAD || return 1
	done &&

	shit log --decorate=full --oneline >actual &&

	# None of the refs are visible:
	! grep /fake actual
'

test_expect_success 'log --end-of-options' '
	shit update-ref refs/heads/--source HEAD &&
	shit log --end-of-options --source >actual &&
	shit log >expect &&
	test_cmp expect actual
'

test_expect_success 'set up commits with different authors' '
	shit checkout --orphan authors &&
	test_commit --author "Jim <jim@example.com>" jim_1 &&
	test_commit --author "Val <val@example.com>" val_1 &&
	test_commit --author "Val <val@example.com>" val_2 &&
	test_commit --author "Jim <jim@example.com>" jim_2 &&
	test_commit --author "Val <val@example.com>" val_3 &&
	test_commit --author "Jim <jim@example.com>" jim_3
'

test_expect_success 'log --invert-grep --grep --author' '
	cat >expect <<-\EOF &&
	val_3
	val_1
	EOF
	shit log --format=%s --author=Val --grep 2 --invert-grep >actual &&
	test_cmp expect actual
'

test_done
