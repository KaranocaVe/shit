#!/bin/sh

test_description='reftables are compatible with Jshit'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME
shit_TEST_DEFAULT_REF_FORMAT=reftable
export shit_TEST_DEFAULT_REF_FORMAT

# Jshit does not support the 'link' DIRC extension.
shit_TEST_SPLIT_INDEX=0
export shit_TEST_SPLIT_INDEX

. ./test-lib.sh

if ! test_have_prereq Jshit
then
	skip_all='skipping reftable Jshit tests; Jshit is not present in PATH'
	test_done
fi

if ! test_have_prereq SHA1
then
	skip_all='skipping reftable Jshit tests; Jshit does not support SHA256 reftables'
	test_done
fi

test_commit_jshit () {
	touch "$1" &&
	jshit add "$1" &&
	jshit commit -m "$1"
}

test_same_refs () {
	shit show-ref --head >cshit.actual &&
	jshit show-ref >jshit-tabs.actual &&
	tr "\t" " " <jshit-tabs.actual >jshit.actual &&
	test_cmp cshit.actual jshit.actual
}

test_same_ref () {
	shit rev-parse "$1" >cshit.actual &&
	jshit rev-parse "$1" >jshit.actual &&
	test_cmp cshit.actual jshit.actual
}

test_same_reflog () {
	shit reflog "$*" >cshit.actual &&
	jshit reflog "$*" >jshit-newline.actual &&
	sed '/^$/d' <jshit-newline.actual >jshit.actual &&
	test_cmp cshit.actual jshit.actual
}

test_expect_success 'Cshit repository can be read by Jshit' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&
		test_commit A &&
		test_same_refs &&
		test_same_ref HEAD &&
		test_same_reflog HEAD
	)
'

test_expect_success 'Jshit repository can be read by Cshit' '
	test_when_finished "rm -rf repo" &&
	jshit init repo &&
	(
		cd repo &&

		touch file &&
		jshit add file &&
		jshit commit -m "initial commit" &&

		# Note that we must convert the ref storage after we have
		# written the default branch. Otherwise Jshit will end up with
		# no HEAD at all.
		jshit convert-ref-storage --format=reftable &&

		test_same_refs &&
		test_same_ref HEAD &&
		# Interestingly, Jshit cannot read its own reflog here. Cshit can
		# though.
		printf "%s HEAD@{0}: commit (initial): initial commit" "$(shit rev-parse --short HEAD)" >expect &&
		shit reflog HEAD >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'mixed writes from Jshit and Cshit' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&

		test_commit A &&
		test_commit_jshit B &&
		test_commit C &&
		test_commit_jshit D &&

		test_same_refs &&
		test_same_ref HEAD &&
		test_same_reflog HEAD
	)
'

test_expect_success 'Jshit can read multi-level index' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&

		test_commit A &&
		awk "
		    BEGIN {
			print \"start\";
			for (i = 0; i < 10000; i++)
			    printf \"create refs/heads/branch-%d HEAD\n\", i;
			print \"commit\";
		    }
		" >input &&
		shit update-ref --stdin <input &&

		test_same_refs &&
		test_same_ref refs/heads/branch-1 &&
		test_same_ref refs/heads/branch-5738 &&
		test_same_ref refs/heads/branch-9999
	)
'

test_done
