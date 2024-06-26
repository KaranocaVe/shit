#!/bin/sh

test_description='shit svn authorship'

. ./lib-shit-svn.sh

test_expect_success 'setup svn repository' '
	svn_cmd checkout "$svnrepo" work.svn &&
	(
		cd work.svn &&
		echo >file &&
		svn_cmd add file &&
		svn_cmd commit -m "first commit" file
	)
'

test_expect_success 'interact with it via shit svn' '
	mkdir work.shit &&
	(
		cd work.shit &&
		shit svn init "$svnrepo" &&
		shit svn fetch &&

		echo modification >file &&
		test_tick &&
		shit commit -a -m second &&

		test_tick &&
		shit svn dcommit &&

		echo "further modification" >file &&
		test_tick &&
		shit commit -a -m third &&

		test_tick &&
		shit svn --add-author-from dcommit &&

		echo "yet further modification" >file &&
		test_tick &&
		shit commit -a -m fourth &&

		test_tick &&
		shit svn --add-author-from --use-log-author dcommit &&

		shit log &&

		shit show -s HEAD^^ >../actual.2 &&
		shit show -s HEAD^  >../actual.3 &&
		shit show -s HEAD   >../actual.4

	) &&

	# Make sure that --add-author-from without --use-log-author
	# did not affect the authorship information
	myself=$(grep "^Author: " actual.2) &&
	unaffected=$(grep "^Author: " actual.3) &&
	test "z$myself" = "z$unaffected" &&

	# Make sure lack of --add-author-from did not add cruft
	! grep "^    From: A U Thor " actual.2 &&

	# Make sure --add-author-from added cruft
	grep "^    From: A U Thor " actual.3 &&
	grep "^    From: A U Thor " actual.4 &&

	# Make sure --add-author-from with --use-log-author affected
	# the authorship information
	grep "^Author: A U Thor " actual.4 &&

	# Make sure there are no commit messages with excess blank lines
	test $(grep "^ " actual.2 | wc -l) = 3 &&
	test $(grep "^ " actual.3 | wc -l) = 5 &&
	test $(grep "^ " actual.4 | wc -l) = 5 &&

	# Make sure there are no svn commit messages with excess blank lines
	(
		cd work.svn &&
		svn_cmd up &&
		
		test $(svn_cmd log -r2:2 | wc -l) = 5 &&
		test $(svn_cmd log -r4:4 | wc -l) = 7
	)
'

test_done
