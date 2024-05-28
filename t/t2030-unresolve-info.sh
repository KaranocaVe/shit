#!/bin/sh

test_description='undoing resolution'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

check_resolve_undo () {
	msg=$1
	shift
	while case $# in
	0)	break ;;
	1|2|3)	die "Bug in check-resolve-undo test" ;;
	esac
	do
		path=$1
		shift
		for stage in 1 2 3
		do
			sha1=$1
			shift
			case "$sha1" in
			'') continue ;;
			esac
			sha1=$(shit rev-parse --verify "$sha1")
			printf "100644 %s %s\t%s\n" $sha1 $stage $path
		done
	done >"$msg.expect" &&
	shit ls-files --resolve-undo >"$msg.actual" &&
	test_cmp "$msg.expect" "$msg.actual"
}

prime_resolve_undo () {
	shit reset --hard &&
	shit checkout second^0 &&
	test_tick &&
	test_must_fail shit merge third^0 &&
	check_resolve_undo empty &&

	# how should the conflict be resolved?
	case "$1" in
	remove)
		rm -f file/le && shit rm fi/le
		;;
	*) # modify
		echo different >fi/le && shit add fi/le
		;;
	esac
	check_resolve_undo recorded fi/le initial:fi/le second:fi/le third:fi/le
}

test_expect_success setup '
	mkdir fi &&
	printf "a\0a" >binary &&
	shit add binary &&
	test_commit initial fi/le first &&
	shit branch side &&
	shit branch another &&
	printf "a\0b" >binary &&
	shit add binary &&
	test_commit second fi/le second &&
	shit checkout side &&
	test_commit third fi/le third &&
	shit branch add-add &&
	shit checkout another &&
	test_commit fourth fi/le fourth &&
	shit checkout add-add &&
	test_commit fifth add-differently &&
	shit checkout main
'

test_expect_success 'add records switch clears' '
	prime_resolve_undo &&
	test_tick &&
	shit commit -m merged &&
	echo committing keeps &&
	check_resolve_undo kept fi/le initial:fi/le second:fi/le third:fi/le &&
	shit checkout second^0 &&
	echo switching clears &&
	check_resolve_undo cleared
'

test_expect_success 'rm records reset clears' '
	prime_resolve_undo &&
	test_tick &&
	shit commit -m merged &&
	echo committing keeps &&
	check_resolve_undo kept fi/le initial:fi/le second:fi/le third:fi/le &&

	echo merge clears upfront &&
	test_must_fail shit merge fourth^0 &&
	check_resolve_undo nuked &&

	shit rm -f fi/le &&
	echo resolving records &&
	check_resolve_undo recorded fi/le initial:fi/le HEAD:fi/le fourth:fi/le &&

	shit reset --hard &&
	echo resetting discards &&
	check_resolve_undo discarded
'

test_expect_success 'plumbing clears' '
	prime_resolve_undo &&
	test_tick &&
	shit commit -m merged &&
	echo committing keeps &&
	check_resolve_undo kept fi/le initial:fi/le second:fi/le third:fi/le &&

	echo plumbing clear &&
	shit update-index --clear-resolve-undo &&
	check_resolve_undo cleared
'

test_expect_success 'add records checkout -m undoes' '
	prime_resolve_undo &&
	shit diff HEAD &&
	shit checkout --conflict=merge fi/le &&
	echo checkout used the record and removed it &&
	check_resolve_undo removed &&
	echo the index and the work tree is unmerged again &&
	shit diff >actual &&
	grep "^++<<<<<<<" actual
'

test_expect_success 'unmerge with plumbing' '
	prime_resolve_undo &&
	shit update-index --unresolve fi/le &&
	shit ls-files --resolve-undo fi/le >actual &&
	test_must_be_empty actual &&
	shit ls-files -u >actual &&
	test_line_count = 3 actual
'

test_expect_success 'unmerge can be done even after committing' '
	prime_resolve_undo &&
	shit commit -m "record to nuke MERGE_HEAD" &&
	shit update-index --unresolve fi/le &&
	shit ls-files --resolve-undo fi/le >actual &&
	test_must_be_empty actual &&
	shit ls-files -u >actual &&
	test_line_count = 3 actual
'

test_expect_success 'unmerge removal' '
	prime_resolve_undo remove &&
	shit update-index --unresolve fi/le &&
	shit ls-files --resolve-undo fi/le >actual &&
	test_must_be_empty actual &&
	shit ls-files -u >actual &&
	test_line_count = 3 actual
'

test_expect_success 'unmerge removal after committing' '
	prime_resolve_undo remove &&
	shit commit -m "record to nuke MERGE_HEAD" &&
	shit update-index --unresolve fi/le &&
	shit ls-files --resolve-undo fi/le >actual &&
	test_must_be_empty actual &&
	shit ls-files -u >actual &&
	test_line_count = 3 actual
'

test_expect_success 'rerere and rerere forget' '
	mkdir .shit/rr-cache &&
	prime_resolve_undo &&
	echo record the resolution &&
	shit rerere &&
	rerere_id=$(cd .shit/rr-cache && echo */postimage) &&
	rerere_id=${rerere_id%/postimage} &&
	test -f .shit/rr-cache/$rerere_id/postimage &&
	shit checkout -m fi/le &&
	echo resurrect the conflict &&
	grep "^=======" fi/le &&
	echo reresolve the conflict &&
	shit rerere &&
	test "z$(cat fi/le)" = zdifferent &&
	echo register the resolution again &&
	shit add fi/le &&
	check_resolve_undo kept fi/le initial:fi/le second:fi/le third:fi/le &&
	test -z "$(shit ls-files -u)" &&
	shit rerere forget fi/le &&
	! test -f .shit/rr-cache/$rerere_id/postimage &&
	tr "\0" "\n" <.shit/MERGE_RR >actual &&
	echo "$rerere_id	fi/le" >expect &&
	test_cmp expect actual
'

test_expect_success 'rerere and rerere forget (subdirectory)' '
	rm -fr .shit/rr-cache &&
	mkdir .shit/rr-cache &&
	prime_resolve_undo &&
	echo record the resolution &&
	(cd fi && shit rerere) &&
	rerere_id=$(cd .shit/rr-cache && echo */postimage) &&
	rerere_id=${rerere_id%/postimage} &&
	test -f .shit/rr-cache/$rerere_id/postimage &&
	(cd fi && shit checkout -m le) &&
	echo resurrect the conflict &&
	grep "^=======" fi/le &&
	echo reresolve the conflict &&
	(cd fi && shit rerere) &&
	test "z$(cat fi/le)" = zdifferent &&
	echo register the resolution again &&
	(cd fi && shit add le) &&
	check_resolve_undo kept fi/le initial:fi/le second:fi/le third:fi/le &&
	test -z "$(shit ls-files -u)" &&
	(cd fi && shit rerere forget le) &&
	! test -f .shit/rr-cache/$rerere_id/postimage &&
	tr "\0" "\n" <.shit/MERGE_RR >actual &&
	echo "$rerere_id	fi/le" >expect &&
	test_cmp expect actual
'

test_expect_success 'rerere forget (binary)' '
	shit checkout -f side &&
	test_commit --printf binary binary "a\0c" &&
	test_must_fail shit merge second &&
	shit rerere forget binary
'

test_expect_success 'rerere forget (add-add conflict)' '
	shit checkout -f main &&
	echo main >add-differently &&
	shit add add-differently &&
	shit commit -m "add differently" &&
	test_must_fail shit merge fifth &&
	shit rerere forget add-differently 2>actual &&
	test_grep "no remembered" actual
'

test_expect_success 'resolve-undo keeps blobs from gc' '
	shit checkout -f main &&

	# First make sure we do not have any cruft left in the object store
	shit repack -a -d &&
	shit prune --expire=now &&
	shit prune-packed &&
	shit gc --prune=now &&
	shit fsck --unreachable >cruft &&
	test_must_be_empty cruft &&

	# Now add three otherwise unreferenced blob objects to the index
	shit reset --hard &&
	B1=$(echo "resolve undo test data 1" | shit hash-object -w --stdin) &&
	B2=$(echo "resolve undo test data 2" | shit hash-object -w --stdin) &&
	B3=$(echo "resolve undo test data 3" | shit hash-object -w --stdin) &&
	shit update-index --add --index-info <<-EOF &&
	100644 $B1 1	frotz
	100644 $B2 2	frotz
	100644 $B3 3	frotz
	EOF

	# These three blob objects are reachable (only) from the index
	shit fsck --unreachable >cruft &&
	test_must_be_empty cruft &&
	# and they should be protected from GC
	shit gc --prune=now &&
	shit cat-file -e $B1 &&
	shit cat-file -e $B2 &&
	shit cat-file -e $B3 &&

	# Now resolve the conflicted path
	B0=$(echo "resolve undo test data 0" | shit hash-object -w --stdin) &&
	shit update-index --add --cacheinfo 100644,$B0,frotz &&

	# These three blob objects are now reachable only from the resolve-undo
	shit fsck --unreachable >cruft &&
	test_must_be_empty cruft &&

	# and they should survive GC
	shit gc --prune=now &&
	shit cat-file -e $B0 &&
	shit cat-file -e $B1 &&
	shit cat-file -e $B2 &&
	shit cat-file -e $B3 &&

	# Now we switch away, which nukes resolve-undo, and
	# blobs B0..B3 would become dangling.  fsck should
	# notice that they are now unreachable.
	shit checkout -f side &&
	shit fsck --unreachable >cruft &&
	sort cruft >actual &&
	sort <<-EOF >expect &&
	unreachable blob $B0
	unreachable blob $B1
	unreachable blob $B2
	unreachable blob $B3
	EOF
	test_cmp expect actual &&

	# And they should go away when gc runs.
	shit gc --prune=now &&
	shit fsck --unreachable >cruft &&
	test_must_be_empty cruft &&

	test_must_fail shit cat-file -e $B0 &&
	test_must_fail shit cat-file -e $B1 &&
	test_must_fail shit cat-file -e $B2 &&
	test_must_fail shit cat-file -e $B3
'

test_done
