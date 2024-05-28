#!/bin/sh
#
# Copyright (c) 2006 Johannes E. Schindelin
#

test_description='shit rerere

! [fifth] version1
 ! [first] first
  ! [fourth] version1
   ! [main] initial
    ! [second] prefer first over second
     ! [third] version2
------
     + [third] version2
+      [fifth] version1
  +    [fourth] version1
+ +  + [third^] third
    -  [second] prefer first over second
 +  +  [first] first
    +  [second^] second
++++++ [main] initial
'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '
	cat >a1 <<-\EOF &&
	Some title
	==========
	Whether '\''tis nobler in the mind to suffer
	The slings and arrows of outrageous fortune,
	Or to take arms against a sea of troubles,
	And by opposing end them? To die: to sleep;
	No more; and by a sleep to say we end
	The heart-ache and the thousand natural shocks
	That flesh is heir to, '\''tis a consummation
	Devoutly to be wish'\''d.
	EOF

	shit add a1 &&
	test_tick &&
	shit commit -q -a -m initial &&

	cat >>a1 <<-\EOF &&
	Some title
	==========
	To die, to sleep;
	To sleep: perchance to dream: ay, there'\''s the rub;
	For in that sleep of death what dreams may come
	When we have shuffled off this mortal coil,
	Must give us pause: there'\''s the respect
	That makes calamity of so long life;
	EOF

	shit checkout -b first &&
	test_tick &&
	shit commit -q -a -m first &&

	shit checkout -b second main &&
	shit show first:a1 |
	sed -e "s/To die, t/To die! T/" -e "s/Some title/Some Title/" >a1 &&
	echo "* END *" >>a1 &&
	test_tick &&
	shit commit -q -a -m second
'

test_expect_success 'nothing recorded without rerere' '
	rm -rf .shit/rr-cache &&
	shit config rerere.enabled false &&
	test_must_fail shit merge first &&
	! test -d .shit/rr-cache
'

test_expect_success 'activate rerere, old style (conflicting merge)' '
	shit reset --hard &&
	mkdir .shit/rr-cache &&
	test_might_fail shit config --unset rerere.enabled &&
	test_must_fail shit merge first &&

	sha1=$(perl -pe "s/	.*//" .shit/MERGE_RR) &&
	rr=.shit/rr-cache/$sha1 &&
	grep "^=======\$" $rr/preimage &&
	! test -f $rr/postimage &&
	! test -f $rr/thisimage
'

test_expect_success 'rerere.enabled works, too' '
	rm -rf .shit/rr-cache &&
	shit config rerere.enabled true &&
	shit reset --hard &&
	test_must_fail shit merge first &&

	sha1=$(perl -pe "s/	.*//" .shit/MERGE_RR) &&
	rr=.shit/rr-cache/$sha1 &&
	grep ^=======$ $rr/preimage
'

test_expect_success 'set up rr-cache' '
	rm -rf .shit/rr-cache &&
	shit config rerere.enabled true &&
	shit reset --hard &&
	test_must_fail shit merge first &&
	sha1=$(perl -pe "s/	.*//" .shit/MERGE_RR) &&
	rr=.shit/rr-cache/$sha1
'

test_expect_success 'rr-cache looks sane' '
	# no postimage or thisimage yet
	! test -f $rr/postimage &&
	! test -f $rr/thisimage &&

	# preimage has right number of lines
	cnt=$(sed -ne "/^<<<<<<</,/^>>>>>>>/p" $rr/preimage | wc -l) &&
	echo $cnt &&
	test $cnt = 13
'

test_expect_success 'rerere diff' '
	shit show first:a1 >a1 &&
	cat >expect <<-\EOF &&
	--- a/a1
	+++ b/a1
	@@ -1,4 +1,4 @@
	-Some Title
	+Some title
	 ==========
	 Whether '\''tis nobler in the mind to suffer
	 The slings and arrows of outrageous fortune,
	@@ -8,21 +8,11 @@
	 The heart-ache and the thousand natural shocks
	 That flesh is heir to, '\''tis a consummation
	 Devoutly to be wish'\''d.
	-<<<<<<<
	-Some Title
	-==========
	-To die! To sleep;
	-=======
	 Some title
	 ==========
	 To die, to sleep;
	->>>>>>>
	 To sleep: perchance to dream: ay, there'\''s the rub;
	 For in that sleep of death what dreams may come
	 When we have shuffled off this mortal coil,
	 Must give us pause: there'\''s the respect
	 That makes calamity of so long life;
	-<<<<<<<
	-=======
	-* END *
	->>>>>>>
	EOF
	shit rerere diff >out &&
	test_cmp expect out
'

test_expect_success 'rerere status' '
	echo a1 >expect &&
	shit rerere status >out &&
	test_cmp expect out
'

test_expect_success 'first postimage wins' '
	shit show first:a1 | sed "s/To die: t/To die! T/" >expect &&

	shit commit -q -a -m "prefer first over second" &&
	test -f $rr/postimage &&

	oldmtimepost=$(test-tool chmtime --get -60 $rr/postimage) &&

	shit checkout -b third main &&
	shit show second^:a1 | sed "s/To die: t/To die! T/" >a1 &&
	shit commit -q -a -m third &&

	test_must_fail shit merge first &&
	# rerere kicked in
	! grep "^=======\$" a1 &&
	test_cmp expect a1
'

test_expect_success 'rerere updates postimage timestamp' '
	newmtimepost=$(test-tool chmtime --get $rr/postimage) &&
	test $oldmtimepost -lt $newmtimepost
'

test_expect_success 'rerere clear' '
	mv $rr/postimage .shit/post-saved &&
	echo "$sha1	a1" | perl -pe "y/\012/\000/" >.shit/MERGE_RR &&
	shit rerere clear &&
	! test -d $rr
'

test_expect_success 'leftover directory' '
	shit reset --hard &&
	mkdir -p $rr &&
	test_must_fail shit merge first &&
	test -f $rr/preimage
'

test_expect_success 'missing preimage' '
	shit reset --hard &&
	mkdir -p $rr &&
	cp .shit/post-saved $rr/postimage &&
	test_must_fail shit merge first &&
	test -f $rr/preimage
'

test_expect_success 'set up for garbage collection tests' '
	mkdir -p $rr &&
	echo Hello >$rr/preimage &&
	echo World >$rr/postimage &&

	sha2=$(test_oid deadbeef) &&
	rr2=.shit/rr-cache/$sha2 &&
	mkdir $rr2 &&
	echo Hello >$rr2/preimage &&

	almost_15_days_ago=$((60-15*86400)) &&
	just_over_15_days_ago=$((-1-15*86400)) &&
	almost_60_days_ago=$((60-60*86400)) &&
	just_over_60_days_ago=$((-1-60*86400)) &&

	test-tool chmtime =$just_over_60_days_ago $rr/preimage &&
	test-tool chmtime =$almost_60_days_ago $rr/postimage &&
	test-tool chmtime =$almost_15_days_ago $rr2/preimage
'

test_expect_success 'gc preserves young or recently used records' '
	shit rerere gc &&
	test -f $rr/preimage &&
	test -f $rr2/preimage
'

test_expect_success 'old records rest in peace' '
	test-tool chmtime =$just_over_60_days_ago $rr/postimage &&
	test-tool chmtime =$just_over_15_days_ago $rr2/preimage &&
	shit rerere gc &&
	! test -f $rr/preimage &&
	! test -f $rr2/preimage
'

rerere_gc_custom_expiry_test () {
	five_days="$1" right_now="$2"
	test_expect_success "rerere gc with custom expiry ($five_days, $right_now)" '
		rm -fr .shit/rr-cache &&
		rr=.shit/rr-cache/$ZERO_OID &&
		mkdir -p "$rr" &&
		>"$rr/preimage" &&
		>"$rr/postimage" &&

		two_days_ago=$((-2*86400)) &&
		test-tool chmtime =$two_days_ago "$rr/preimage" &&
		test-tool chmtime =$two_days_ago "$rr/postimage" &&

		find .shit/rr-cache -type f | sort >original &&

		shit -c "gc.rerereresolved=$five_days" \
		    -c "gc.rerereunresolved=$five_days" rerere gc &&
		find .shit/rr-cache -type f | sort >actual &&
		test_cmp original actual &&

		shit -c "gc.rerereresolved=$five_days" \
		    -c "gc.rerereunresolved=$right_now" rerere gc &&
		find .shit/rr-cache -type f | sort >actual &&
		test_cmp original actual &&

		shit -c "gc.rerereresolved=$right_now" \
		    -c "gc.rerereunresolved=$right_now" rerere gc &&
		find .shit/rr-cache -type f | sort >actual &&
		test_must_be_empty actual
	'
}

rerere_gc_custom_expiry_test 5 0

rerere_gc_custom_expiry_test 5.days.ago now

test_expect_success 'setup: file2 added differently in two branches' '
	shit reset --hard &&

	shit checkout -b fourth &&
	echo Hallo >file2 &&
	shit add file2 &&
	test_tick &&
	shit commit -m version1 &&

	shit checkout third &&
	echo Bello >file2 &&
	shit add file2 &&
	test_tick &&
	shit commit -m version2 &&

	test_must_fail shit merge fourth &&
	echo Cello >file2 &&
	shit add file2 &&
	shit commit -m resolution
'

test_expect_success 'resolution was recorded properly' '
	echo Cello >expected &&

	shit reset --hard HEAD~2 &&
	shit checkout -b fifth &&

	echo Hallo >file3 &&
	shit add file3 &&
	test_tick &&
	shit commit -m version1 &&

	shit checkout third &&
	echo Bello >file3 &&
	shit add file3 &&
	test_tick &&
	shit commit -m version2 &&
	shit tag version2 &&

	test_must_fail shit merge fifth &&
	test_cmp expected file3 &&
	test_must_fail shit update-index --refresh
'

test_expect_success 'rerere.autoupdate' '
	shit config rerere.autoupdate true &&
	shit reset --hard &&
	shit checkout version2 &&
	test_must_fail shit merge fifth &&
	shit update-index --refresh
'

test_expect_success 'merge --rerere-autoupdate' '
	test_might_fail shit config --unset rerere.autoupdate &&
	shit reset --hard &&
	shit checkout version2 &&
	test_must_fail shit merge --rerere-autoupdate fifth &&
	shit update-index --refresh
'

test_expect_success 'merge --no-rerere-autoupdate' '
	headblob=$(shit rev-parse version2:file3) &&
	mergeblob=$(shit rev-parse fifth:file3) &&
	cat >expected <<-EOF &&
	100644 $headblob 2	file3
	100644 $mergeblob 3	file3
	EOF

	shit config rerere.autoupdate true &&
	shit reset --hard &&
	shit checkout version2 &&
	test_must_fail shit merge --no-rerere-autoupdate fifth &&
	shit ls-files -u >actual &&
	test_cmp expected actual
'

test_expect_success 'set up an unresolved merge' '
	headblob=$(shit rev-parse version2:file3) &&
	mergeblob=$(shit rev-parse fifth:file3) &&
	cat >expected.unresolved <<-EOF &&
	100644 $headblob 2	file3
	100644 $mergeblob 3	file3
	EOF

	test_might_fail shit config --unset rerere.autoupdate &&
	shit reset --hard &&
	shit checkout version2 &&
	ancestor=$(shit merge-base version2 fifth) &&
	test_must_fail shit merge-recursive "$ancestor" -- HEAD fifth &&

	shit ls-files --stage >failedmerge &&
	cp file3 file3.conflict &&

	shit ls-files -u >actual &&
	test_cmp expected.unresolved actual
'

test_expect_success 'explicit rerere' '
	test_might_fail shit config --unset rerere.autoupdate &&
	shit rm -fr --cached . &&
	shit update-index --index-info <failedmerge &&
	cp file3.conflict file3 &&
	test_must_fail shit update-index --refresh -q &&

	shit rerere &&
	shit ls-files -u >actual &&
	test_cmp expected.unresolved actual
'

test_expect_success 'explicit rerere with autoupdate' '
	shit config rerere.autoupdate true &&
	shit rm -fr --cached . &&
	shit update-index --index-info <failedmerge &&
	cp file3.conflict file3 &&
	test_must_fail shit update-index --refresh -q &&

	shit rerere &&
	shit update-index --refresh
'

test_expect_success 'explicit rerere --rerere-autoupdate overrides' '
	shit config rerere.autoupdate false &&
	shit rm -fr --cached . &&
	shit update-index --index-info <failedmerge &&
	cp file3.conflict file3 &&
	shit rerere &&
	shit ls-files -u >actual1 &&

	shit rm -fr --cached . &&
	shit update-index --index-info <failedmerge &&
	cp file3.conflict file3 &&
	shit rerere --rerere-autoupdate &&
	shit update-index --refresh &&

	shit rm -fr --cached . &&
	shit update-index --index-info <failedmerge &&
	cp file3.conflict file3 &&
	shit rerere --rerere-autoupdate --no-rerere-autoupdate &&
	shit ls-files -u >actual2 &&

	shit rm -fr --cached . &&
	shit update-index --index-info <failedmerge &&
	cp file3.conflict file3 &&
	shit rerere --rerere-autoupdate --no-rerere-autoupdate --rerere-autoupdate &&
	shit update-index --refresh &&

	test_cmp expected.unresolved actual1 &&
	test_cmp expected.unresolved actual2
'

test_expect_success 'rerere --no-no-rerere-autoupdate' '
	shit rm -fr --cached . &&
	shit update-index --index-info <failedmerge &&
	cp file3.conflict file3 &&
	test_must_fail shit rerere --no-no-rerere-autoupdate 2>err &&
	test_grep [Uu]sage err &&
	test_must_fail shit update-index --refresh
'

test_expect_success 'rerere -h' '
	test_must_fail shit rerere -h >help &&
	test_grep [Uu]sage help
'

concat_insert () {
	last=$1
	shift
	cat early && printf "%s\n" "$@" && cat late "$last"
}

count_pre_post () {
	find .shit/rr-cache/ -type f -name "preimage*" >actual &&
	test_line_count = "$1" actual &&
	find .shit/rr-cache/ -type f -name "postimage*" >actual &&
	test_line_count = "$2" actual
}

merge_conflict_resolve () {
	shit reset --hard &&
	test_must_fail shit merge six.1 &&
	# Resolution is to replace 7 with 6.1 and 6.2 (i.e. take both)
	concat_insert short 6.1 6.2 >file1 &&
	concat_insert long 6.1 6.2 >file2
}

test_expect_success 'multiple identical conflicts' '
	rm -fr .shit/rr-cache &&
	mkdir .shit/rr-cache &&
	shit reset --hard &&

	test_seq 1 6 >early &&
	>late &&
	test_seq 11 15 >short &&
	test_seq 111 120 >long &&
	concat_insert short >file1 &&
	concat_insert long >file2 &&
	shit add file1 file2 &&
	shit commit -m base &&
	shit tag base &&
	shit checkout -b six.1 &&
	concat_insert short 6.1 >file1 &&
	concat_insert long 6.1 >file2 &&
	shit add file1 file2 &&
	shit commit -m 6.1 &&
	shit checkout -b six.2 HEAD^ &&
	concat_insert short 6.2 >file1 &&
	concat_insert long 6.2 >file2 &&
	shit add file1 file2 &&
	shit commit -m 6.2 &&

	# At this point, six.1 and six.2
	# - derive from common ancestor that has two files
	#   1...6 7 11..15 (file1) and 1...6 7 111..120 (file2)
	# - six.1 replaces these 7s with 6.1
	# - six.2 replaces these 7s with 6.2

	merge_conflict_resolve &&

	# Check that rerere knows that file1 and file2 have conflicts

	printf "%s\n" file1 file2 >expect &&
	shit ls-files -u | sed -e "s/^.*	//" | sort -u >actual &&
	test_cmp expect actual &&

	shit rerere status | sort >actual &&
	test_cmp expect actual &&

	shit rerere remaining >actual &&
	test_cmp expect actual &&

	count_pre_post 2 0 &&

	# Pretend that the conflicts were made quite some time ago
	test-tool chmtime -172800 $(find .shit/rr-cache/ -type f) &&

	# Unresolved entries have not expired yet
	shit -c gc.rerereresolved=5 -c gc.rerereunresolved=5 rerere gc &&
	count_pre_post 2 0 &&

	# Unresolved entries have expired
	shit -c gc.rerereresolved=5 -c gc.rerereunresolved=1 rerere gc &&
	count_pre_post 0 0 &&

	# Recreate the conflicted state
	merge_conflict_resolve &&
	count_pre_post 2 0 &&

	# Clear it
	shit rerere clear &&
	count_pre_post 0 0 &&

	# Recreate the conflicted state
	merge_conflict_resolve &&
	count_pre_post 2 0 &&

	# We resolved file1 and file2
	shit rerere &&
	shit rerere remaining >actual &&
	test_must_be_empty actual &&

	# We must have recorded both of them
	count_pre_post 2 2 &&

	# Now we should be able to resolve them both
	shit reset --hard &&
	test_must_fail shit merge six.1 &&
	shit rerere &&

	shit rerere remaining >actual &&
	test_must_be_empty actual &&

	concat_insert short 6.1 6.2 >file1.expect &&
	concat_insert long 6.1 6.2 >file2.expect &&
	test_cmp file1.expect file1 &&
	test_cmp file2.expect file2 &&

	# Forget resolution for file2
	shit rerere forget file2 &&
	echo file2 >expect &&
	shit rerere status >actual &&
	test_cmp expect actual &&
	count_pre_post 2 1 &&

	# file2 already has correct resolution, so record it again
	shit rerere &&

	# Pretend that the resolutions are old again
	test-tool chmtime -172800 $(find .shit/rr-cache/ -type f) &&

	# Resolved entries have not expired yet
	shit -c gc.rerereresolved=5 -c gc.rerereunresolved=5 rerere gc &&

	count_pre_post 2 2 &&

	# Resolved entries have expired
	shit -c gc.rerereresolved=1 -c gc.rerereunresolved=5 rerere gc &&
	count_pre_post 0 0
'

test_expect_success 'rerere with unexpected conflict markers does not crash' '
	shit reset --hard &&

	shit checkout -b branch-1 main &&
	echo "bar" >test &&
	shit add test &&
	shit commit -q -m two &&

	shit reset --hard &&
	shit checkout -b branch-2 main &&
	echo "foo" >test &&
	shit add test &&
	shit commit -q -a -m one &&

	test_must_fail shit merge branch-1 &&
	echo "<<<<<<< a" >test &&
	shit rerere &&

	shit rerere clear
'

test_expect_success 'rerere with inner conflict markers' '
	shit reset --hard &&

	shit checkout -b A main &&
	echo "bar" >test &&
	shit add test &&
	shit commit -q -m two &&
	echo "baz" >test &&
	shit add test &&
	shit commit -q -m three &&

	shit reset --hard &&
	shit checkout -b B main &&
	echo "foo" >test &&
	shit add test &&
	shit commit -q -a -m one &&

	test_must_fail shit merge A~ &&
	shit add test &&
	shit commit -q -m "will solve conflicts later" &&
	test_must_fail shit merge A &&

	echo "resolved" >test &&
	shit add test &&
	shit commit -q -m "solved conflict" &&

	echo "resolved" >expect &&

	shit reset --hard HEAD~~ &&
	test_must_fail shit merge A~ &&
	shit add test &&
	shit commit -q -m "will solve conflicts later" &&
	test_must_fail shit merge A &&
	cat test >actual &&
	test_cmp expect actual &&

	shit add test &&
	shit commit -m "rerere solved conflict" &&
	shit reset --hard HEAD~ &&
	test_must_fail shit merge A &&
	cat test >actual &&
	test_cmp expect actual
'

test_expect_success 'setup simple stage 1 handling' '
	test_create_repo stage_1_handling &&
	(
		cd stage_1_handling &&

		test_seq 1 10 >original &&
		shit add original &&
		shit commit -m original &&

		shit checkout -b A main &&
		shit mv original A &&
		shit commit -m "rename to A" &&

		shit checkout -b B main &&
		shit mv original B &&
		shit commit -m "rename to B"
	)
'

test_expect_success 'test simple stage 1 handling' '
	(
		cd stage_1_handling &&

		shit config rerere.enabled true &&
		shit checkout A^0 &&
		test_must_fail shit merge B^0
	)
'

test_expect_success 'rerere does not crash with missing preimage' '
	shit config rerere.enabled true &&

	echo bar >test &&
	shit add test &&
	shit commit -m "one" &&
	shit branch rerere_no_crash &&

	echo foo >>test &&
	shit add test &&
	shit commit -m "two" &&

	shit checkout rerere_no_crash &&
	echo "bar" >>test &&
	shit add test &&
	shit commit -m "three" &&

	test_must_fail shit rebase main &&
	rm .shit/rr-cache/*/preimage &&
	shit rebase --abort
'

test_expect_success 'rerere does not crash with unmatched conflict marker' '
	shit config rerere.enabled true &&

	echo bar >test &&
	shit add test &&
	shit commit -m "one" &&
	shit branch rerere_no_preimage &&

	cat >test <<-EOF &&
	test
	bar
	foobar
	EOF
	shit add test &&
	shit commit -m "two" &&

	shit checkout rerere_no_preimage &&
	echo "bar" >>test &&
	shit add test &&
	shit commit -m "three" &&

	cat >test <<-EOF &&
	foobar
	bar
	bar
	EOF
	shit add test &&
	shit commit -m "four" &&

	test_must_fail shit rebase main &&
	cat >test <<-EOF &&
	test
	bar
	<<<<<<< HEAD
	foobar
	bar
	EOF
	shit add test &&
	test_must_fail shit rebase --continue
'

test_done
