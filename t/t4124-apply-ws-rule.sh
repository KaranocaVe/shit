#!/bin/sh

test_description='core.whitespace rules and shit apply'

. ./test-lib.sh

prepare_test_file () {

	# A line that has character X is touched iff RULE is in effect:
	#       X  RULE
	#   	!  trailing-space
	#   	@  space-before-tab
	#   	#  indent-with-non-tab (default tab width 8)
	#	=  indent-with-non-tab,tabwidth=16
	#   	%  tab-in-indent
	sed -e "s/_/ /g" -e "s/>/	/" <<-\EOF
		An_SP in an ordinary line>and a HT.
		>A HT (%).
		_>A SP and a HT (@%).
		_>_A SP, a HT and a SP (@%).
		_______Seven SP.
		________Eight SP (#).
		_______>Seven SP and a HT (@%).
		________>Eight SP and a HT (@#%).
		_______>_Seven SP, a HT and a SP (@%).
		________>_Eight SP, a HT and a SP (@#%).
		_______________Fifteen SP (#).
		_______________>Fifteen SP and a HT (@#%).
		________________Sixteen SP (#=).
		________________>Sixteen SP and a HT (@#%=).
		_____a__Five SP, a non WS, two SP.
		A line with a (!) trailing SP_
		A line with a (!) trailing HT>
	EOF
}

apply_patch () {
	cmd_prefix= &&
	if test "x$1" = 'x!'
	then
		cmd_prefix=test_must_fail &&
		shift
	fi &&
	>target &&
	sed -e "s|\([ab]\)/file|\1/target|" <patch |
	$cmd_prefix shit apply "$@"
}

test_fix () {
	# fix should not barf
	apply_patch --whitespace=fix || return 1

	# find touched lines
	$DIFF file target | sed -n -e "s/^> //p" >fixed
	# busybox's diff(1) doesn't output normal format
	if ! test -s fixed
	then
		$DIFF -u file target |
		grep -v '^+++ target' |
		sed -ne "/^+/s/+//p" >fixed
	fi

	# the changed lines are all expected to change
	fixed_cnt=$(wc -l <fixed)
	case "$1" in
	'') expect_cnt=$fixed_cnt ;;
	?*) expect_cnt=$(grep "[$1]" <fixed | wc -l) ;;
	esac
	test $fixed_cnt -eq $expect_cnt || return 1

	# and we are not missing anything
	case "$1" in
	'') expect_cnt=0 ;;
	?*) expect_cnt=$(grep "[$1]" <file | wc -l) ;;
	esac
	test $fixed_cnt -eq $expect_cnt || return 1

	# Get the patch actually applied
	shit diff-files -p target >fixed-patch
	test -s fixed-patch && return 0

	# Make sure it is complaint-free
	>target
	shit apply --whitespace=error-all <fixed-patch

}

test_expect_success setup '

	>file &&
	shit add file &&
	prepare_test_file >file &&
	shit diff-files -p >patch &&
	>target &&
	shit add target

'

test_expect_success 'whitespace=nowarn, default rule' '

	apply_patch --whitespace=nowarn &&
	test_cmp file target

'

test_expect_success 'whitespace=warn, default rule' '

	apply_patch --whitespace=warn &&
	test_cmp file target

'

test_expect_success 'whitespace=error-all, default rule' '

	apply_patch ! --whitespace=error-all &&
	test_must_be_empty target

'

test_expect_success 'whitespace=error-all, no rule' '

	shit config core.whitespace -trailing,-space-before,-indent &&
	apply_patch --whitespace=error-all &&
	test_cmp file target

'

test_expect_success 'whitespace=error-all, no rule (attribute)' '

	shit config --unset core.whitespace &&
	echo "target -whitespace" >.shitattributes &&
	apply_patch --whitespace=error-all &&
	test_cmp file target

'

test_expect_success 'spaces inserted by tab-in-indent' '

	shit config core.whitespace -trailing,-space,-indent,tab &&
	rm -f .shitattributes &&
	test_fix % &&
	sed -e "s/_/ /g" -e "s/>/	/" <<-\EOF >expect &&
		An_SP in an ordinary line>and a HT.
		________A HT (%).
		________A SP and a HT (@%).
		_________A SP, a HT and a SP (@%).
		_______Seven SP.
		________Eight SP (#).
		________Seven SP and a HT (@%).
		________________Eight SP and a HT (@#%).
		_________Seven SP, a HT and a SP (@%).
		_________________Eight SP, a HT and a SP (@#%).
		_______________Fifteen SP (#).
		________________Fifteen SP and a HT (@#%).
		________________Sixteen SP (#=).
		________________________Sixteen SP and a HT (@#%=).
		_____a__Five SP, a non WS, two SP.
		A line with a (!) trailing SP_
		A line with a (!) trailing HT>
	EOF
	test_cmp expect target

'

for t in - ''
do
	case "$t" in '') tt='!' ;; *) tt= ;; esac
	for s in - ''
	do
		case "$s" in '') ts='@' ;; *) ts= ;; esac
		for i in - ''
		do
			case "$i" in '') ti='#' ti16='=';; *) ti= ti16= ;; esac
			for h in - ''
			do
				[ -z "$h$i" ] && continue
				case "$h" in '') th='%' ;; *) th= ;; esac
				rule=${t}trailing,${s}space,${i}indent,${h}tab

				rm -f .shitattributes
				test_expect_success "rule=$rule" '
					shit config core.whitespace "$rule" &&
					test_fix "$tt$ts$ti$th"
				'

				test_expect_success "rule=$rule,tabwidth=16" '
					shit config core.whitespace "$rule,tabwidth=16" &&
					test_fix "$tt$ts$ti16$th"
				'

				test_expect_success "rule=$rule (attributes)" '
					shit config --unset core.whitespace &&
					echo "target whitespace=$rule" >.shitattributes &&
					test_fix "$tt$ts$ti$th"
				'

				test_expect_success "rule=$rule,tabwidth=16 (attributes)" '
					echo "target whitespace=$rule,tabwidth=16" >.shitattributes &&
					test_fix "$tt$ts$ti16$th"
				'

			done
		done
	done
done

create_patch () {
	sed -e "s/_/ /" <<-\EOF
		diff --shit a/target b/target
		index e69de29..8bd6648 100644
		--- a/target
		+++ b/target
		@@ -0,0 +1,3 @@
		+An empty line follows
		+
		+A line with trailing whitespace and no newline_
		\ No newline at end of file
	EOF
}

test_expect_success 'trailing whitespace & no newline at the end of file' '
	>target &&
	create_patch >patch-file &&
	shit apply --whitespace=fix patch-file &&
	grep "newline$" target &&
	grep "^$" target
'

test_expect_success 'blank at EOF with --whitespace=fix (1)' '
	test_might_fail shit config --unset core.whitespace &&
	rm -f .shitattributes &&

	test_write_lines a b c >one &&
	shit add one &&
	test_write_lines a b c >expect &&
	{ cat expect && echo; } >one &&
	shit diff -- one >patch &&

	shit checkout one &&
	shit apply --whitespace=fix patch &&
	test_cmp expect one
'

test_expect_success 'blank at EOF with --whitespace=fix (2)' '
	test_write_lines a b c >one &&
	shit add one &&
	test_write_lines a b >expect &&
	{ cat expect && test_write_lines "" ""; } >one &&
	shit diff -- one >patch &&

	shit checkout one &&
	shit apply --whitespace=fix patch &&
	test_cmp expect one
'

test_expect_success 'blank at EOF with --whitespace=fix (3)' '
	test_write_lines a b "" >one &&
	shit add one &&
	test_write_lines a c "" >expect &&
	{ cat expect && test_write_lines "" ""; } >one &&
	shit diff -- one >patch &&

	shit checkout one &&
	shit apply --whitespace=fix patch &&
	test_cmp expect one
'

test_expect_success 'blank at end of hunk, not at EOF with --whitespace=fix' '
	test_write_lines a b "" "" "" "" "" d >one &&
	shit add one &&
	test_write_lines a b "" "" "" "" "" "" d >expect &&
	cp expect one &&
	shit diff -- one >patch &&

	shit checkout one &&
	shit apply --whitespace=fix patch &&
	test_cmp expect one
'

test_expect_success 'blank at EOF with --whitespace=warn' '
	test_write_lines a b c >one &&
	shit add one &&
	echo >>one &&
	cat one >expect &&
	shit diff -- one >patch &&

	shit checkout one &&
	shit apply --whitespace=warn patch 2>error &&
	test_cmp expect one &&
	grep "new blank line at EOF" error
'

test_expect_success 'blank at EOF with --whitespace=error' '
	test_write_lines a b c >one &&
	shit add one &&
	cat one >expect &&
	echo >>one &&
	shit diff -- one >patch &&

	shit checkout one &&
	test_must_fail shit apply --whitespace=error patch 2>error &&
	test_cmp expect one &&
	grep "new blank line at EOF" error
'

test_expect_success 'blank but not empty at EOF' '
	test_write_lines a b c >one &&
	shit add one &&
	echo "   " >>one &&
	cat one >expect &&
	shit diff -- one >patch &&

	shit checkout one &&
	shit apply --whitespace=warn patch 2>error &&
	test_cmp expect one &&
	grep "new blank line at EOF" error
'

test_expect_success 'applying beyond EOF requires one non-blank context line' '
	test_write_lines "" "" "" "" >one &&
	shit add one &&
	echo b >>one &&
	shit diff -- one >patch &&

	shit checkout one &&
	test_write_lines a "" >one &&
	cp one expect &&
	test_must_fail shit apply --whitespace=fix patch &&
	test_cmp expect one &&
	test_must_fail shit apply --ignore-space-change --whitespace=fix patch &&
	test_cmp expect one
'

test_expect_success 'tons of blanks at EOF should not apply' '
	for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do
		test_write_lines "" "" "" "" || return 1
	done >one &&
	shit add one &&
	echo a >>one &&
	shit diff -- one >patch &&

	>one &&
	test_must_fail shit apply --whitespace=fix patch &&
	test_must_fail shit apply --ignore-space-change --whitespace=fix patch
'

test_expect_success 'missing blank line at end with --whitespace=fix' '
	echo a >one &&
	echo >>one &&
	shit add one &&
	echo b >>one &&
	cp one expect &&
	shit diff -- one >patch &&
	echo a >one &&
	cp one saved-one &&
	test_must_fail shit apply patch &&
	shit apply --whitespace=fix patch &&
	test_cmp expect one &&
	mv saved-one one &&
	shit apply --ignore-space-change --whitespace=fix patch &&
	test_cmp expect one
'

test_expect_success 'two missing blank lines at end with --whitespace=fix' '
	test_write_lines a "" b c >one &&
	cp one no-blank-lines &&
	test_write_lines "" "" >>one &&
	shit add one &&
	echo d >>one &&
	cp one expect &&
	echo >>one &&
	shit diff -- one >patch &&
	cp no-blank-lines one &&
	test_must_fail shit apply patch &&
	shit apply --whitespace=fix patch &&
	test_cmp expect one &&
	mv no-blank-lines one &&
	test_must_fail shit apply patch &&
	shit apply --ignore-space-change --whitespace=fix patch &&
	test_cmp expect one
'

test_expect_success 'missing blank line at end, insert before end, --whitespace=fix' '
	test_write_lines a "" >one &&
	shit add one &&
	test_write_lines b a "" >one &&
	cp one expect &&
	shit diff -- one >patch &&
	echo a >one &&
	test_must_fail shit apply patch &&
	shit apply --whitespace=fix patch &&
	test_cmp expect one
'

test_expect_success 'shrink file with tons of missing blanks at end of file' '
	test_write_lines a b c >one &&
	cp one no-blank-lines &&
	for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do
		test_write_lines "" "" "" "" || return 1
	done >>one &&
	shit add one &&
	echo a >one &&
	cp one expect &&
	shit diff -- one >patch &&
	cp no-blank-lines one &&
	test_must_fail shit apply patch &&
	shit apply --whitespace=fix patch &&
	test_cmp expect one &&
	mv no-blank-lines one &&
	shit apply --ignore-space-change --whitespace=fix patch &&
	test_cmp expect one
'

test_expect_success 'missing blanks at EOF must only match blank lines' '
	test_write_lines a b >one &&
	shit add one &&
	test_write_lines c d >>one &&
	shit diff -- one >patch &&

	echo a >one &&
	test_must_fail shit apply patch &&
	test_must_fail shit apply --whitespace=fix patch &&
	test_must_fail shit apply --ignore-space-change --whitespace=fix patch
'

sed -e's/Z//' >one <<EOF
a
b
c
		      Z
EOF

test_expect_success 'missing blank line should match context line with spaces' '
	shit add one &&
	echo d >>one &&
	shit diff -- one >patch &&
	test_write_lines a b c >one &&
	cp one expect &&
	test_write_lines "" d >>expect &&
	shit add one &&

	shit apply --whitespace=fix patch &&
	test_cmp expect one
'

sed -e's/Z//' >one <<EOF
a
b
c
		      Z
EOF

test_expect_success 'same, but with the --ignore-space-option' '
	shit add one &&
	echo d >>one &&
	cp one expect &&
	shit diff -- one >patch &&
	test_write_lines a b c >one &&
	shit add one &&

	shit checkout-index -f one &&
	shit apply --ignore-space-change --whitespace=fix patch &&
	test_cmp expect one
'

test_expect_success 'same, but with CR-LF line endings && cr-at-eol set' '
	shit config core.whitespace cr-at-eol &&
	printf "a\r\n" >one &&
	printf "b\r\n" >>one &&
	printf "c\r\n" >>one &&
	cp one save-one &&
	printf "                 \r\n" >>one &&
	shit add one &&
	printf "d\r\n" >>one &&
	cp one expect &&
	shit diff -- one >patch &&
	mv save-one one &&

	shit apply --ignore-space-change --whitespace=fix patch &&
	test_cmp expect one
'

test_expect_success 'CR-LF line endings && add line && text=auto' '
	shit config --unset core.whitespace &&
	printf "a\r\n" >one &&
	cp one save-one &&
	shit add one &&
	printf "b\r\n" >>one &&
	cp one expect &&
	shit diff -- one >patch &&
	mv save-one one &&
	echo "one text=auto" >.shitattributes &&
	shit apply patch &&
	test_cmp expect one
'

test_expect_success 'CR-LF line endings && change line && text=auto' '
	printf "a\r\n" >one &&
	cp one save-one &&
	shit add one &&
	printf "b\r\n" >one &&
	cp one expect &&
	shit diff -- one >patch &&
	mv save-one one &&
	echo "one text=auto" >.shitattributes &&
	shit apply patch &&
	test_cmp expect one
'

test_expect_success 'LF in repo, CRLF in worktree && change line && text=auto' '
	printf "a\n" >one &&
	shit add one &&
	printf "b\r\n" >one &&
	shit diff -- one >patch &&
	printf "a\r\n" >one &&
	echo "one text=auto" >.shitattributes &&
	shit -c core.eol=CRLF apply patch &&
	printf "b\r\n" >expect &&
	test_cmp expect one
'

test_expect_success 'whitespace=fix to expand' '
	qz_to_tab_space >preimage <<-\EOF &&
	QQa
	QQb
	QQc
	ZZZZZZZZZZZZZZZZd
	QQe
	QQf
	QQg
	EOF
	qz_to_tab_space >patch <<-\EOF &&
	diff --shit a/preimage b/preimage
	--- a/preimage
	+++ b/preimage
	@@ -1,7 +1,6 @@
	 QQa
	 QQb
	 QQc
	-QQd
	 QQe
	 QQf
	 QQg
	EOF
	shit -c core.whitespace=tab-in-indent apply --whitespace=fix patch
'

test_expect_success 'whitespace check skipped for excluded paths' '
	shit config core.whitespace blank-at-eol &&
	>used &&
	>unused &&
	shit add used unused &&
	echo "used" >used &&
	echo "unused " >unused &&
	shit diff-files -p used unused >patch &&
	shit apply --include=used --stat --whitespace=error <patch
'

test_done
