#!/bin/sh
#
# Copyright (c) 2009 Marc Branchaud
#

test_description='shit svn multiple branch and tag paths in the svn repo'
. ./lib-shit-svn.sh

test_expect_success 'setup svnrepo' '
	mkdir	project \
		project/trunk \
		project/b_one \
		project/b_two \
		project/tags_A \
		project/tags_B &&
	echo 1 > project/trunk/a.file &&
	svn_cmd import -m "$test_description" project "$svnrepo/project" &&
	rm -rf project &&
	svn_cmd cp -m "Branch 1" "$svnrepo/project/trunk" \
				 "$svnrepo/project/b_one/first" &&
	svn_cmd cp -m "Tag 1" "$svnrepo/project/trunk" \
			      "$svnrepo/project/tags_A/1.0" &&
	svn_cmd co "$svnrepo/project" svn_project &&
	( cd svn_project &&
		echo 2 > trunk/a.file &&
		svn_cmd ci -m "Change 1" trunk/a.file &&
		svn_cmd cp -m "Branch 2" "$svnrepo/project/trunk" \
					 "$svnrepo/project/b_one/second" &&
		svn_cmd cp -m "Tag 2" "$svnrepo/project/trunk" \
				      "$svnrepo/project/tags_A/2.0" &&
		echo 3 > trunk/a.file &&
		svn_cmd ci -m "Change 2" trunk/a.file &&
		svn_cmd cp -m "Branch 3" "$svnrepo/project/trunk" \
					 "$svnrepo/project/b_two/1" &&
		svn_cmd cp -m "Tag 3" "$svnrepo/project/trunk" \
				      "$svnrepo/project/tags_A/3.0" &&
		echo 4 > trunk/a.file &&
		svn_cmd ci -m "Change 3" trunk/a.file &&
		svn_cmd cp -m "Branch 4" "$svnrepo/project/trunk" \
					 "$svnrepo/project/b_two/2" &&
		svn_cmd cp -m "Tag 4" "$svnrepo/project/trunk" \
				      "$svnrepo/project/tags_A/4.0" &&
		svn_cmd up &&
		echo 5 > b_one/first/a.file &&
		svn_cmd ci -m "Change 4" b_one/first/a.file &&
		svn_cmd cp -m "Tag 5" "$svnrepo/project/b_one/first" \
				      "$svnrepo/project/tags_B/v5" &&
		echo 6 > b_one/second/a.file &&
		svn_cmd ci -m "Change 5" b_one/second/a.file &&
		svn_cmd cp -m "Tag 6" "$svnrepo/project/b_one/second" \
				      "$svnrepo/project/tags_B/v6" &&
		echo 7 > b_two/1/a.file &&
		svn_cmd ci -m "Change 6" b_two/1/a.file &&
		svn_cmd cp -m "Tag 7" "$svnrepo/project/b_two/1" \
				      "$svnrepo/project/tags_B/v7" &&
		echo 8 > b_two/2/a.file &&
		svn_cmd ci -m "Change 7" b_two/2/a.file &&
		svn_cmd cp -m "Tag 8" "$svnrepo/project/b_two/2" \
				      "$svnrepo/project/tags_B/v8"
	)
'

test_expect_success 'clone multiple branch and tag paths' '
	shit svn clone -T trunk \
		      -b b_one/* --branches b_two/* \
		      -t tags_A/* --tags tags_B \
		      "$svnrepo/project" shit_project &&
	( cd shit_project &&
		shit rev-parse refs/remotes/origin/first &&
		shit rev-parse refs/remotes/origin/second &&
		shit rev-parse refs/remotes/origin/1 &&
		shit rev-parse refs/remotes/origin/2 &&
		shit rev-parse refs/remotes/origin/tags/1.0 &&
		shit rev-parse refs/remotes/origin/tags/2.0 &&
		shit rev-parse refs/remotes/origin/tags/3.0 &&
		shit rev-parse refs/remotes/origin/tags/4.0 &&
		shit rev-parse refs/remotes/origin/tags/v5 &&
		shit rev-parse refs/remotes/origin/tags/v6 &&
		shit rev-parse refs/remotes/origin/tags/v7 &&
		shit rev-parse refs/remotes/origin/tags/v8
	)
'

test_expect_success 'Multiple branch or tag paths require -d' '
	( cd shit_project &&
		test_must_fail shit svn branch -m "No new branch" Nope &&
		test_must_fail shit svn tag -m "No new tag" Tagless &&
		test_must_fail shit rev-parse refs/remotes/origin/Nope &&
		test_must_fail shit rev-parse refs/remotes/origin/tags/Tagless
	) &&
	( cd svn_project &&
		svn_cmd up &&
		test_path_is_missing b_one/Nope &&
		test_path_is_missing b_two/Nope &&
		test_path_is_missing tags_A/Tagless &&
		test_path_is_missing tags_B/Tagless
	)
'

test_expect_success 'create new branches and tags' '
	( cd shit_project &&
		shit svn branch -m "New branch 1" -d b_one New1 ) &&
	( cd svn_project &&
		svn_cmd up && test -e b_one/New1/a.file ) &&

	( cd shit_project &&
		shit svn branch -m "New branch 2" -d b_two New2 ) &&
	( cd svn_project &&
		svn_cmd up && test -e b_two/New2/a.file ) &&

	( cd shit_project &&
		shit svn branch -t -m "New tag 1" -d tags_A Tag1 ) &&
	( cd svn_project &&
		svn_cmd up && test -e tags_A/Tag1/a.file ) &&

	( cd shit_project &&
		shit svn tag -m "New tag 2" -d tags_B Tag2 ) &&
	( cd svn_project &&
		svn_cmd up && test -e tags_B/Tag2/a.file )
'

test_done
