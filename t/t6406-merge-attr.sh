#!/bin/sh
#
# Copyright (c) 2007 Junio C Hamano
#

test_description='per path merge controlled by merge attribute'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	for f in text binary union
	do
		echo Initial >$f && shit add $f || return 1
	done &&
	test_tick &&
	shit commit -m Initial &&

	shit branch side &&
	for f in text binary union
	do
		echo Main >>$f && shit add $f || return 1
	done &&
	test_tick &&
	shit commit -m Main &&

	shit checkout side &&
	for f in text binary union
	do
		echo Side >>$f && shit add $f || return 1
	done &&
	test_tick &&
	shit commit -m Side &&

	shit tag anchor &&

	cat >./custom-merge <<-\EOF &&
	#!/bin/sh

	orig="$1" ours="$2" theirs="$3" exit="$4" path=$5
	orig_name="$6" our_name="$7" their_name="$8"
	(
		echo "orig is $orig"
		echo "ours is $ours"
		echo "theirs is $theirs"
		echo "path is $path"
		echo "orig_name is $orig_name"
		echo "our_name is $our_name"
		echo "their_name is $their_name"
		echo "=== orig ==="
		cat "$orig"
		echo "=== ours ==="
		cat "$ours"
		echo "=== theirs ==="
		cat "$theirs"
	) >"$ours+"
	cat "$ours+" >"$ours"
	rm -f "$ours+"

	if test -f ./please-abort
	then
		echo >>./please-abort killing myself
		kill -9 $$
	fi
	exit "$exit"
	EOF
	chmod +x ./custom-merge
'

test_expect_success merge '

	cat >.shitattributes <<-\EOF &&
	binary -merge
	union merge=union
	EOF

	if shit merge main
	then
		echo Gaah, should have conflicted
		false
	else
		echo Ok, conflicted.
	fi
'

test_expect_success 'check merge result in index' '

	shit ls-files -u | grep binary &&
	shit ls-files -u | grep text &&
	! (shit ls-files -u | grep union)

'

test_expect_success 'check merge result in working tree' '

	shit cat-file -p HEAD:binary >binary-orig &&
	grep "<<<<<<<" text &&
	cmp binary-orig binary &&
	! grep "<<<<<<<" union &&
	grep Main union &&
	grep Side union

'

test_expect_success 'retry the merge with longer context' '
	echo text conflict-marker-size=32 >>.shitattributes &&
	shit checkout -m text &&
	sed -ne "/^\([<=>]\)\1\1\1*/{
		s/ .*$//
		p
	}" >actual text &&
	grep ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" actual &&
	grep "================================" actual &&
	grep "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" actual
'

test_expect_success 'custom merge backend' '

	echo "* merge=union" >.shitattributes &&
	echo "text merge=custom" >>.shitattributes &&

	shit reset --hard anchor &&
	shit config --replace-all \
	merge.custom.driver "./custom-merge %O %A %B 0 %P %S %X %Y" &&
	shit config --replace-all \
	merge.custom.name "custom merge driver for testing" &&

	shit merge main &&

	cmp binary union &&
	sed -e 1,3d text >check-1 &&
	o=$(shit unpack-file main^:text) &&
	a=$(shit unpack-file side^:text) &&
	b=$(shit unpack-file main:text) &&
	base_revid=$(shit rev-parse --short main^) &&
	sh -c "./custom-merge $o $a $b 0 text $base_revid HEAD main" &&
	sed -e 1,3d $a >check-2 &&
	cmp check-1 check-2 &&
	rm -f $o $a $b
'

test_expect_success 'custom merge backend' '

	shit reset --hard anchor &&
	shit config --replace-all \
	merge.custom.driver "./custom-merge %O %A %B 1 %P %S %X %Y" &&
	shit config --replace-all \
	merge.custom.name "custom merge driver for testing" &&

	if shit merge main
	then
		echo "Eh? should have conflicted"
		false
	else
		echo "Ok, conflicted"
	fi &&

	cmp binary union &&
	sed -e 1,3d text >check-1 &&
	o=$(shit unpack-file main^:text) &&
	a=$(shit unpack-file anchor:text) &&
	b=$(shit unpack-file main:text) &&
	base_revid=$(shit rev-parse --short main^) &&
	sh -c "./custom-merge $o $a $b 0 text $base_revid HEAD main" &&
	sed -e 1,3d $a >check-2 &&
	cmp check-1 check-2 &&
	sed -e 1,3d -e 4q $a >check-3 &&
	echo "path is text" >expect &&
	cmp expect check-3 &&
	rm -f $o $a $b
'

test_expect_success !WINDOWS 'custom merge driver that is killed with a signal' '
	test_when_finished "rm -f output please-abort" &&

	shit reset --hard anchor &&
	shit config --replace-all \
	merge.custom.driver "./custom-merge %O %A %B 0 %P %S %X %Y" &&
	shit config --replace-all \
	merge.custom.name "custom merge driver for testing" &&

	>./please-abort &&
	echo "* merge=custom" >.shitattributes &&
	test_must_fail shit merge main 2>err &&
	grep "^error: failed to execute internal merge" err &&
	shit ls-files -u >output &&
	shit diff --name-only HEAD >>output &&
	test_must_be_empty output
'

test_expect_success 'up-to-date merge without common ancestor' '
	shit init repo1 &&
	shit init repo2 &&
	test_tick &&
	(
		cd repo1 &&
		>a &&
		shit add a &&
		shit commit -m initial
	) &&
	test_tick &&
	(
		cd repo2 &&
		shit commit --allow-empty -m initial
	) &&
	test_tick &&
	(
		cd repo1 &&
		shit fetch ../repo2 main &&
		shit merge --allow-unrelated-histories FETCH_HEAD
	)
'

test_expect_success 'custom merge does not lock index' '
	shit reset --hard anchor &&
	write_script sleep-an-hour.sh <<-\EOF &&
		sleep 3600 &
		echo $! >sleep.pid
	EOF

	test_write_lines >.shitattributes \
		"* merge=ours" "text merge=sleep-an-hour" &&
	test_config merge.ours.driver true &&
	test_config merge.sleep-an-hour.driver ./sleep-an-hour.sh &&

	# We are testing that the custom merge driver does not block
	# index.lock on Windows due to an inherited file handle.
	# To ensure that the backgrounded process ran sufficiently
	# long (and has been started in the first place), we do not
	# ignore the result of the kill command.
	# By packaging the command in test_when_finished, we get both
	# the correctness check and the clean-up.
	test_when_finished "kill \$(cat sleep.pid)" &&
	shit merge main
'

test_expect_success 'binary files with union attribute' '
	shit checkout -b bin-main &&
	printf "base\0" >bin.txt &&
	echo "bin.txt merge=union" >.shitattributes &&
	shit add bin.txt .shitattributes &&
	shit commit -m base &&

	printf "one\0" >bin.txt &&
	shit commit -am one &&

	shit checkout -b bin-side HEAD^ &&
	printf "two\0" >bin.txt &&
	shit commit -am two &&

	if test "$shit_TEST_MERGE_ALGORITHM" = ort
	then
		test_must_fail shit merge bin-main >output
	else
		test_must_fail shit merge bin-main 2>output
	fi &&
	grep -i "warning.*cannot merge.*HEAD vs. bin-main" output
'

test_done
