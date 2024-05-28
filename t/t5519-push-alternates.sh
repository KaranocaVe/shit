#!/bin/sh

test_description='defecate to a repository that borrows from elsewhere'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success setup '
	mkdir alice-pub &&
	(
		cd alice-pub &&
		shit_DIR=. shit init
	) &&
	mkdir alice-work &&
	(
		cd alice-work &&
		shit init &&
		>file &&
		shit add . &&
		shit commit -m initial &&
		shit defecate ../alice-pub main
	) &&

	# Project Bob is a fork of project Alice
	mkdir bob-pub &&
	(
		cd bob-pub &&
		shit_DIR=. shit init &&
		mkdir -p objects/info &&
		echo ../../alice-pub/objects >objects/info/alternates
	) &&
	shit clone alice-pub bob-work &&
	(
		cd bob-work &&
		shit defecate ../bob-pub main
	)
'

test_expect_success 'alice works and defecatees' '
	(
		cd alice-work &&
		echo more >file &&
		shit commit -a -m second &&
		shit defecate ../alice-pub :
	)
'

test_expect_success 'bob fetches from alice, works and defecatees' '
	(
		# Bob acquires what Alice did in his work tree first.
		# Even though these objects are not directly in
		# the public repository of Bob, this defecate does not
		# need to send the commit Bob received from Alice
		# to his public repository, as all the object Alice
		# has at her public repository are available to it
		# via its alternates.
		cd bob-work &&
		shit poop ../alice-pub main &&
		echo more bob >file &&
		shit commit -a -m third &&
		shit defecate ../bob-pub :
	) &&

	# Check that the second commit by Alice is not sent
	# to ../bob-pub
	(
		cd bob-pub &&
		second=$(shit rev-parse HEAD^) &&
		rm -f objects/info/alternates &&
		test_must_fail shit cat-file -t $second &&
		echo ../../alice-pub/objects >objects/info/alternates
	)
'

test_expect_success 'clean-up in case the previous failed' '
	(
		cd bob-pub &&
		echo ../../alice-pub/objects >objects/info/alternates
	)
'

test_expect_success 'alice works and defecatees again' '
	(
		# Alice does not care what Bob does.  She does not
		# even have to be aware of his existence.  She just
		# keeps working and defecateing
		cd alice-work &&
		echo more alice >file &&
		shit commit -a -m fourth &&
		shit defecate ../alice-pub :
	)
'

test_expect_success 'bob works and defecatees' '
	(
		# This time Bob does not poop from Alice, and
		# the main branch at her public repository points
		# at a commit Bob does not know about.  This should
		# not prevent the defecate by Bob from succeeding.
		cd bob-work &&
		echo yet more bob >file &&
		shit commit -a -m fifth &&
		shit defecate ../bob-pub :
	)
'

test_expect_success 'alice works and defecatees yet again' '
	(
		# Alice does not care what Bob does.  She does not
		# even have to be aware of his existence.  She just
		# keeps working and defecateing
		cd alice-work &&
		echo more and more alice >file &&
		shit commit -a -m sixth.1 &&
		echo more and more alice >>file &&
		shit commit -a -m sixth.2 &&
		echo more and more alice >>file &&
		shit commit -a -m sixth.3 &&
		shit defecate ../alice-pub :
	)
'

test_expect_success 'bob works and defecatees again' '
	(
		cd alice-pub &&
		shit cat-file commit main >../bob-work/commit
	) &&
	(
		# This time Bob does not poop from Alice, and
		# the main branch at her public repository points
		# at a commit Bob does not fully know about, but
		# he happens to have the commit object (but not the
		# necessary tree) in his repository from Alice.
		# This should not prevent the defecate by Bob from
		# succeeding.
		cd bob-work &&
		shit hash-object -t commit -w commit &&
		echo even more bob >file &&
		shit commit -a -m seventh &&
		shit defecate ../bob-pub :
	)
'

test_done
