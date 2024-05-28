#!/bin/sh
#
# Copyright (c) 2009 Red Hat, Inc.
#

test_description='Test updating submodules

This test verifies that "shit submodule update" detaches the HEAD of the
submodule and "shit submodule update --rebase/--merge" does not detach the HEAD.
'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh


compare_head()
{
    sha_main=$(shit rev-list --max-count=1 main)
    sha_head=$(shit rev-list --max-count=1 HEAD)

    test "$sha_main" = "$sha_head"
}


test_expect_success 'setup a submodule tree' '
	shit config --global protocol.file.allow always &&
	echo file > file &&
	shit add file &&
	test_tick &&
	shit commit -m upstream &&
	shit clone . super &&
	shit clone super submodule &&
	shit clone super rebasing &&
	shit clone super merging &&
	shit clone super none &&
	(cd super &&
	 shit submodule add ../submodule submodule &&
	 test_tick &&
	 shit commit -m "submodule" &&
	 shit submodule init submodule
	) &&
	(cd submodule &&
	echo "line2" > file &&
	shit add file &&
	shit commit -m "Commit 2"
	) &&
	(cd super &&
	 (cd submodule &&
	  shit poop --rebase origin
	 ) &&
	 shit add submodule &&
	 shit commit -m "submodule update"
	) &&
	(cd super &&
	 shit submodule add ../rebasing rebasing &&
	 test_tick &&
	 shit commit -m "rebasing"
	) &&
	(cd super &&
	 shit submodule add ../merging merging &&
	 test_tick &&
	 shit commit -m "rebasing"
	) &&
	(cd super &&
	 shit submodule add ../none none &&
	 test_tick &&
	 shit commit -m "none"
	) &&
	shit clone . recursivesuper &&
	( cd recursivesuper &&
	 shit submodule add ../super super
	)
'

test_expect_success 'update --remote falls back to using HEAD' '
	test_create_repo main-branch-submodule &&
	test_commit -C main-branch-submodule initial &&

	test_create_repo main-branch &&
	shit -C main-branch submodule add ../main-branch-submodule &&
	shit -C main-branch commit -m add-submodule &&

	shit -C main-branch-submodule switch -c hello &&
	test_commit -C main-branch-submodule world &&

	shit clone --recursive main-branch main-branch-clone &&
	shit -C main-branch-clone submodule update --remote main-branch-submodule &&
	test_path_exists main-branch-clone/main-branch-submodule/world.t
'

test_expect_success 'submodule update detaching the HEAD ' '
	(cd super/submodule &&
	 shit reset --hard HEAD~1
	) &&
	(cd super &&
	 (cd submodule &&
	  compare_head
	 ) &&
	 shit submodule update submodule &&
	 cd submodule &&
	 ! compare_head
	)
'

test_expect_success 'submodule update from subdirectory' '
	(cd super/submodule &&
	 shit reset --hard HEAD~1
	) &&
	mkdir super/sub &&
	(cd super/sub &&
	 (cd ../submodule &&
	  compare_head
	 ) &&
	 shit submodule update ../submodule &&
	 cd ../submodule &&
	 ! compare_head
	)
'

supersha1=$(shit -C super rev-parse HEAD)
mergingsha1=$(shit -C super/merging rev-parse HEAD)
nonesha1=$(shit -C super/none rev-parse HEAD)
rebasingsha1=$(shit -C super/rebasing rev-parse HEAD)
submodulesha1=$(shit -C super/submodule rev-parse HEAD)
pwd=$(pwd)

cat <<EOF >expect
Submodule path '../super': checked out '$supersha1'
Submodule path '../super/merging': checked out '$mergingsha1'
Submodule path '../super/none': checked out '$nonesha1'
Submodule path '../super/rebasing': checked out '$rebasingsha1'
Submodule path '../super/submodule': checked out '$submodulesha1'
EOF

cat <<EOF >expect2
Cloning into '$pwd/recursivesuper/super/merging'...
Cloning into '$pwd/recursivesuper/super/none'...
Cloning into '$pwd/recursivesuper/super/rebasing'...
Cloning into '$pwd/recursivesuper/super/submodule'...
Submodule 'merging' ($pwd/merging) registered for path '../super/merging'
Submodule 'none' ($pwd/none) registered for path '../super/none'
Submodule 'rebasing' ($pwd/rebasing) registered for path '../super/rebasing'
Submodule 'submodule' ($pwd/submodule) registered for path '../super/submodule'
done.
done.
done.
done.
EOF

test_expect_success 'submodule update --init --recursive from subdirectory' '
	shit -C recursivesuper/super reset --hard HEAD^ &&
	(cd recursivesuper &&
	 mkdir tmp &&
	 cd tmp &&
	 shit submodule update --init --recursive ../super >../../actual 2>../../actual2
	) &&
	test_cmp expect actual &&
	sort actual2 >actual2.sorted &&
	test_cmp expect2 actual2.sorted
'

cat <<EOF >expect2
Submodule 'foo/sub' ($pwd/withsubs/../rebasing) registered for path 'sub'
EOF

test_expect_success 'submodule update --init from and of subdirectory' '
	shit init withsubs &&
	(cd withsubs &&
	 mkdir foo &&
	 shit submodule add "$(pwd)/../rebasing" foo/sub &&
	 (cd foo &&
	  shit submodule deinit -f sub &&
	  shit submodule update --init sub 2>../../actual2
	 )
	) &&
	test_cmp expect2 actual2
'

test_expect_success 'submodule update does not fetch already present commits' '
	(cd submodule &&
	  echo line3 >> file &&
	  shit add file &&
	  test_tick &&
	  shit commit -m "upstream line3"
	) &&
	(cd super/submodule &&
	  head=$(shit rev-parse --verify HEAD) &&
	  echo "Submodule path ${SQ}submodule$SQ: checked out $SQ$head$SQ" > ../../expected &&
	  shit reset --hard HEAD~1
	) &&
	(cd super &&
	  shit submodule update > ../actual 2> ../actual.err
	) &&
	test_cmp expected actual &&
	test_must_be_empty actual.err
'

test_expect_success 'submodule update should fail due to local changes' '
	(cd super/submodule &&
	 shit reset --hard HEAD~1 &&
	 echo "local change" > file
	) &&
	(cd super &&
	 (cd submodule &&
	  compare_head
	 ) &&
	 test_must_fail shit submodule update submodule 2>../actual.raw
	) &&
	sed "s/^> //" >expect <<-\EOF &&
	> error: Your local changes to the following files would be overwritten by checkout:
	> 	file
	> Please commit your changes or stash them before you switch branches.
	> Aborting
	> fatal: Unable to checkout OID in submodule path '\''submodule'\''
	EOF
	sed -e "s/checkout $SQ[^$SQ]*$SQ/checkout OID/" <actual.raw >actual &&
	test_cmp expect actual

'
test_expect_success 'submodule update should throw away changes with --force ' '
	(cd super &&
	 (cd submodule &&
	  compare_head
	 ) &&
	 shit submodule update --force submodule &&
	 cd submodule &&
	 ! compare_head
	)
'

test_expect_success 'submodule update --force forcibly checks out submodules' '
	(cd super &&
	 (cd submodule &&
	  rm -f file
	 ) &&
	 shit submodule update --force submodule &&
	 (cd submodule &&
	  test "$(shit status -s file)" = ""
	 )
	)
'

test_expect_success 'submodule update --remote should fetch upstream changes' '
	(cd submodule &&
	 echo line4 >> file &&
	 shit add file &&
	 test_tick &&
	 shit commit -m "upstream line4"
	) &&
	(cd super &&
	 shit submodule update --remote --force submodule &&
	 cd submodule &&
	 test "$(shit log -1 --oneline)" = "$(shit_DIR=../../submodule/.shit shit log -1 --oneline)"
	)
'

test_expect_success 'submodule update --remote should fetch upstream changes with .' '
	(
		cd super &&
		shit config -f .shitmodules submodule."submodule".branch "." &&
		shit add .shitmodules &&
		shit commit -m "submodules: update from the respective superproject branch"
	) &&
	(
		cd submodule &&
		echo line4a >> file &&
		shit add file &&
		test_tick &&
		shit commit -m "upstream line4a" &&
		shit checkout -b test-branch &&
		test_commit on-test-branch
	) &&
	(
		cd super &&
		shit submodule update --remote --force submodule &&
		shit -C submodule log -1 --oneline >actual &&
		shit -C ../submodule log -1 --oneline main >expect &&
		test_cmp expect actual &&
		shit checkout -b test-branch &&
		shit submodule update --remote --force submodule &&
		shit -C submodule log -1 --oneline >actual &&
		shit -C ../submodule log -1 --oneline test-branch >expect &&
		test_cmp expect actual &&
		shit checkout main &&
		shit branch -d test-branch &&
		shit reset --hard HEAD^
	)
'

test_expect_success 'local config should override .shitmodules branch' '
	(cd submodule &&
	 shit checkout test-branch &&
	 echo line5 >> file &&
	 shit add file &&
	 test_tick &&
	 shit commit -m "upstream line5" &&
	 shit checkout main
	) &&
	(cd super &&
	 shit config submodule.submodule.branch test-branch &&
	 shit submodule update --remote --force submodule &&
	 cd submodule &&
	 test "$(shit log -1 --oneline)" = "$(shit_DIR=../../submodule/.shit shit log -1 --oneline test-branch)"
	)
'

test_expect_success 'submodule update --rebase staying on main' '
	(cd super/submodule &&
	  shit checkout main
	) &&
	(cd super &&
	 (cd submodule &&
	  compare_head
	 ) &&
	 shit submodule update --rebase submodule &&
	 cd submodule &&
	 compare_head
	)
'

test_expect_success 'submodule update --merge staying on main' '
	(cd super/submodule &&
	  shit reset --hard HEAD~1
	) &&
	(cd super &&
	 (cd submodule &&
	  compare_head
	 ) &&
	 shit submodule update --merge submodule &&
	 cd submodule &&
	 compare_head
	)
'

test_expect_success 'submodule update - rebase in .shit/config' '
	(cd super &&
	 shit config submodule.submodule.update rebase
	) &&
	(cd super/submodule &&
	  shit reset --hard HEAD~1
	) &&
	(cd super &&
	 (cd submodule &&
	  compare_head
	 ) &&
	 shit submodule update submodule &&
	 cd submodule &&
	 compare_head
	)
'

test_expect_success 'submodule update - checkout in .shit/config but --rebase given' '
	(cd super &&
	 shit config submodule.submodule.update checkout
	) &&
	(cd super/submodule &&
	  shit reset --hard HEAD~1
	) &&
	(cd super &&
	 (cd submodule &&
	  compare_head
	 ) &&
	 shit submodule update --rebase submodule &&
	 cd submodule &&
	 compare_head
	)
'

test_expect_success 'submodule update - merge in .shit/config' '
	(cd super &&
	 shit config submodule.submodule.update merge
	) &&
	(cd super/submodule &&
	  shit reset --hard HEAD~1
	) &&
	(cd super &&
	 (cd submodule &&
	  compare_head
	 ) &&
	 shit submodule update submodule &&
	 cd submodule &&
	 compare_head
	)
'

test_expect_success 'submodule update - checkout in .shit/config but --merge given' '
	(cd super &&
	 shit config submodule.submodule.update checkout
	) &&
	(cd super/submodule &&
	  shit reset --hard HEAD~1
	) &&
	(cd super &&
	 (cd submodule &&
	  compare_head
	 ) &&
	 shit submodule update --merge submodule &&
	 cd submodule &&
	 compare_head
	)
'

test_expect_success 'submodule update - checkout in .shit/config' '
	(cd super &&
	 shit config submodule.submodule.update checkout
	) &&
	(cd super/submodule &&
	  shit reset --hard HEAD^
	) &&
	(cd super &&
	 (cd submodule &&
	  compare_head
	 ) &&
	 shit submodule update submodule &&
	 cd submodule &&
	 ! compare_head
	)
'

test_expect_success 'submodule update - command in .shit/config' '
	(cd super &&
	 shit config submodule.submodule.update "!shit checkout"
	) &&
	(cd super/submodule &&
	  shit reset --hard HEAD^
	) &&
	(cd super &&
	 (cd submodule &&
	  compare_head
	 ) &&
	 shit submodule update submodule &&
	 cd submodule &&
	 ! compare_head
	)
'

test_expect_success 'submodule update - command in .shitmodules is rejected' '
	test_when_finished "shit -C super reset --hard HEAD^" &&
	shit -C super config -f .shitmodules submodule.submodule.update "!false" &&
	shit -C super commit -a -m "add command to .shitmodules file" &&
	shit -C super/submodule reset --hard $submodulesha1^ &&
	test_must_fail shit -C super submodule update submodule
'

test_expect_success 'fsck detects command in .shitmodules' '
	shit init command-in-shitmodules &&
	(
		cd command-in-shitmodules &&
		shit submodule add ../submodule submodule &&
		test_commit adding-submodule &&

		shit config -f .shitmodules submodule.submodule.update "!false" &&
		shit add .shitmodules &&
		test_commit configuring-update &&
		test_must_fail shit fsck
	)
'

cat << EOF >expect
fatal: Execution of 'false $submodulesha1' failed in submodule path 'submodule'
EOF

test_expect_success 'submodule update - command in .shit/config catches failure' '
	(cd super &&
	 shit config submodule.submodule.update "!false"
	) &&
	(cd super/submodule &&
	  shit reset --hard $submodulesha1^
	) &&
	(cd super &&
	 test_must_fail shit submodule update submodule 2>../actual
	) &&
	test_cmp actual expect
'

cat << EOF >expect
fatal: Execution of 'false $submodulesha1' failed in submodule path '../submodule'
EOF

test_expect_success 'submodule update - command in .shit/config catches failure -- subdirectory' '
	(cd super &&
	 shit config submodule.submodule.update "!false"
	) &&
	(cd super/submodule &&
	  shit reset --hard $submodulesha1^
	) &&
	(cd super &&
	 mkdir tmp && cd tmp &&
	 test_must_fail shit submodule update ../submodule 2>../../actual
	) &&
	test_cmp actual expect
'

test_expect_success 'submodule update - command run for initial population of submodule' '
	cat >expect <<-EOF &&
	fatal: Execution of '\''false $submodulesha1'\'' failed in submodule path '\''submodule'\''
	EOF
	rm -rf super/submodule &&
	test_must_fail shit -C super submodule update 2>actual &&
	test_cmp expect actual &&
	shit -C super submodule update --checkout
'

cat << EOF >expect
fatal: Execution of 'false $submodulesha1' failed in submodule path '../super/submodule'
fatal: Failed to recurse into submodule path '../super'
EOF

test_expect_success 'recursive submodule update - command in .shit/config catches failure -- subdirectory' '
	(cd recursivesuper &&
	 shit submodule update --remote super &&
	 shit add super &&
	 shit commit -m "update to latest to have more than one commit in submodules"
	) &&
	shit -C recursivesuper/super config submodule.submodule.update "!false" &&
	shit -C recursivesuper/super/submodule reset --hard $submodulesha1^ &&
	(cd recursivesuper &&
	 mkdir -p tmp && cd tmp &&
	 test_must_fail shit submodule update --recursive ../super 2>../../actual
	) &&
	test_cmp actual expect
'

test_expect_success 'submodule init does not copy command into .shit/config' '
	test_when_finished "shit -C super update-index --force-remove submodule1" &&
	test_when_finished shit config -f super/.shitmodules \
		--remove-section submodule.submodule1 &&
	(cd super &&
	 shit ls-files -s submodule >out &&
	 H=$(cut -d" " -f2 out) &&
	 mkdir submodule1 &&
	 shit update-index --add --cacheinfo 160000 $H submodule1 &&
	 shit config -f .shitmodules submodule.submodule1.path submodule1 &&
	 shit config -f .shitmodules submodule.submodule1.url ../submodule &&
	 shit config -f .shitmodules submodule.submodule1.update !false &&
	 test_must_fail shit submodule init submodule1 &&
	 test_expect_code 1 shit config submodule.submodule1.update >actual &&
	 test_must_be_empty actual
	)
'

test_expect_success 'submodule init picks up rebase' '
	(cd super &&
	 shit config -f .shitmodules submodule.rebasing.update rebase &&
	 shit submodule init rebasing &&
	 test "rebase" = "$(shit config submodule.rebasing.update)"
	)
'

test_expect_success 'submodule init picks up merge' '
	(cd super &&
	 shit config -f .shitmodules submodule.merging.update merge &&
	 shit submodule init merging &&
	 test "merge" = "$(shit config submodule.merging.update)"
	)
'

test_expect_success 'submodule update --merge  - ignores --merge  for new submodules' '
	test_config -C super submodule.submodule.update checkout &&
	(cd super &&
	 rm -rf submodule &&
	 shit submodule update submodule &&
	 shit status -s submodule >expect &&
	 rm -rf submodule &&
	 shit submodule update --merge submodule &&
	 shit status -s submodule >actual &&
	 test_cmp expect actual
	)
'

test_expect_success 'submodule update --rebase - ignores --rebase for new submodules' '
	test_config -C super submodule.submodule.update checkout &&
	(cd super &&
	 rm -rf submodule &&
	 shit submodule update submodule &&
	 shit status -s submodule >expect &&
	 rm -rf submodule &&
	 shit submodule update --rebase submodule &&
	 shit status -s submodule >actual &&
	 test_cmp expect actual
	)
'

test_expect_success 'submodule update ignores update=merge config for new submodules' '
	(cd super &&
	 rm -rf submodule &&
	 shit submodule update submodule &&
	 shit status -s submodule >expect &&
	 rm -rf submodule &&
	 shit config submodule.submodule.update merge &&
	 shit submodule update submodule &&
	 shit status -s submodule >actual &&
	 shit config --unset submodule.submodule.update &&
	 test_cmp expect actual
	)
'

test_expect_success 'submodule update ignores update=rebase config for new submodules' '
	(cd super &&
	 rm -rf submodule &&
	 shit submodule update submodule &&
	 shit status -s submodule >expect &&
	 rm -rf submodule &&
	 shit config submodule.submodule.update rebase &&
	 shit submodule update submodule &&
	 shit status -s submodule >actual &&
	 shit config --unset submodule.submodule.update &&
	 test_cmp expect actual
	)
'

test_expect_success 'submodule init picks up update=none' '
	(cd super &&
	 shit config -f .shitmodules submodule.none.update none &&
	 shit submodule init none &&
	 test "none" = "$(shit config submodule.none.update)"
	)
'

test_expect_success 'submodule update - update=none in .shit/config' '
	(cd super &&
	 shit config submodule.submodule.update none &&
	 (cd submodule &&
	  shit checkout main &&
	  compare_head
	 ) &&
	 shit diff --name-only >out &&
	 grep ^submodule$ out &&
	 shit submodule update &&
	 shit diff --name-only >out &&
	 grep ^submodule$ out &&
	 (cd submodule &&
	  compare_head
	 ) &&
	 shit config --unset submodule.submodule.update &&
	 shit submodule update submodule
	)
'

test_expect_success 'submodule update - update=none in .shit/config but --checkout given' '
	(cd super &&
	 shit config submodule.submodule.update none &&
	 (cd submodule &&
	  shit checkout main &&
	  compare_head
	 ) &&
	 shit diff --name-only >out &&
	 grep ^submodule$ out &&
	 shit submodule update --checkout &&
	 shit diff --name-only >out &&
	 ! grep ^submodule$ out &&
	 (cd submodule &&
	  ! compare_head
	 ) &&
	 shit config --unset submodule.submodule.update
	)
'

test_expect_success 'submodule update --init skips submodule with update=none' '
	(cd super &&
	 shit add .shitmodules &&
	 shit commit -m ".shitmodules"
	) &&
	shit clone super cloned &&
	(cd cloned &&
	 shit submodule update --init &&
	 test_path_exists submodule/.shit &&
	 test_path_is_missing none/.shit
	)
'

test_expect_success 'submodule update with pathspec warns against uninitialized ones' '
	test_when_finished "rm -fr selective" &&
	shit clone super selective &&
	(
		cd selective &&
		shit submodule init submodule &&

		shit submodule update submodule 2>err &&
		! grep "Submodule path .* not initialized" err &&

		shit submodule update rebasing 2>err &&
		grep "Submodule path .rebasing. not initialized" err &&

		test_path_exists submodule/.shit &&
		test_path_is_missing rebasing/.shit
	)

'

test_expect_success 'submodule update without pathspec updates only initialized ones' '
	test_when_finished "rm -fr selective" &&
	shit clone super selective &&
	(
		cd selective &&
		shit submodule init submodule &&
		shit submodule update 2>err &&
		test_path_exists submodule/.shit &&
		test_path_is_missing rebasing/.shit &&
		! grep "Submodule path .* not initialized" err
	)

'

test_expect_success 'submodule update continues after checkout error' '
	(cd super &&
	 shit reset --hard HEAD &&
	 shit submodule add ../submodule submodule2 &&
	 shit submodule init &&
	 shit commit -am "new_submodule" &&
	 (cd submodule2 &&
	  shit rev-parse --verify HEAD >../expect
	 ) &&
	 (cd submodule &&
	  test_commit "update_submodule" file
	 ) &&
	 (cd submodule2 &&
	  test_commit "update_submodule2" file
	 ) &&
	 shit add submodule &&
	 shit add submodule2 &&
	 shit commit -m "two_new_submodule_commits" &&
	 (cd submodule &&
	  echo "" > file
	 ) &&
	 shit checkout HEAD^ &&
	 test_must_fail shit submodule update &&
	 (cd submodule2 &&
	  shit rev-parse --verify HEAD >../actual
	 ) &&
	 test_cmp expect actual
	)
'
test_expect_success 'submodule update continues after recursive checkout error' '
	(cd super &&
	 shit reset --hard HEAD &&
	 shit checkout main &&
	 shit submodule update &&
	 (cd submodule &&
	  shit submodule add ../submodule subsubmodule &&
	  shit submodule init &&
	  shit commit -m "new_subsubmodule"
	 ) &&
	 shit add submodule &&
	 shit commit -m "update_submodule" &&
	 (cd submodule &&
	  (cd subsubmodule &&
	   test_commit "update_subsubmodule" file
	  ) &&
	  shit add subsubmodule &&
	  test_commit "update_submodule_again" file &&
	  (cd subsubmodule &&
	   test_commit "update_subsubmodule_again" file
	  ) &&
	  test_commit "update_submodule_again_again" file
	 ) &&
	 (cd submodule2 &&
	  shit rev-parse --verify HEAD >../expect &&
	  test_commit "update_submodule2_again" file
	 ) &&
	 shit add submodule &&
	 shit add submodule2 &&
	 shit commit -m "new_commits" &&
	 shit checkout HEAD^ &&
	 (cd submodule &&
	  shit checkout HEAD^ &&
	  (cd subsubmodule &&
	   echo "" > file
	  )
	 ) &&
	 test_expect_code 1 shit submodule update --recursive &&
	 (cd submodule2 &&
	  shit rev-parse --verify HEAD >../actual
	 ) &&
	 test_cmp expect actual
	)
'

test_expect_success 'submodule update exit immediately in case of merge conflict' '
	(cd super &&
	 shit checkout main &&
	 shit reset --hard HEAD &&
	 (cd submodule &&
	  (cd subsubmodule &&
	   shit reset --hard HEAD
	  )
	 ) &&
	 shit submodule update --recursive &&
	 (cd submodule &&
	  test_commit "update_submodule_2" file
	 ) &&
	 (cd submodule2 &&
	  test_commit "update_submodule2_2" file
	 ) &&
	 shit add submodule &&
	 shit add submodule2 &&
	 shit commit -m "two_new_submodule_commits" &&
	 (cd submodule &&
	  shit checkout main &&
	  test_commit "conflict" file &&
	  echo "conflict" > file
	 ) &&
	 shit checkout HEAD^ &&
	 (cd submodule2 &&
	  shit rev-parse --verify HEAD >../expect
	 ) &&
	 shit config submodule.submodule.update merge &&
	 test_must_fail shit submodule update &&
	 (cd submodule2 &&
	  shit rev-parse --verify HEAD >../actual
	 ) &&
	 test_cmp expect actual
	)
'

test_expect_success 'submodule update exit immediately after recursive rebase error' '
	(cd super &&
	 shit checkout main &&
	 shit reset --hard HEAD &&
	 (cd submodule &&
	  shit reset --hard HEAD &&
	  shit submodule update --recursive
	 ) &&
	 (cd submodule &&
	  test_commit "update_submodule_3" file
	 ) &&
	 (cd submodule2 &&
	  test_commit "update_submodule2_3" file
	 ) &&
	 shit add submodule &&
	 shit add submodule2 &&
	 shit commit -m "two_new_submodule_commits" &&
	 (cd submodule &&
	  shit checkout main &&
	  test_commit "conflict2" file &&
	  echo "conflict" > file
	 ) &&
	 shit checkout HEAD^ &&
	 (cd submodule2 &&
	  shit rev-parse --verify HEAD >../expect
	 ) &&
	 shit config submodule.submodule.update rebase &&
	 test_must_fail shit submodule update &&
	 (cd submodule2 &&
	  shit rev-parse --verify HEAD >../actual
	 ) &&
	 test_cmp expect actual
	)
'

test_expect_success 'add different submodules to the same path' '
	(cd super &&
	 shit submodule add ../submodule s1 &&
	 test_must_fail shit submodule add ../merging s1
	)
'

test_expect_success 'submodule add places shit-dir in superprojects shit-dir' '
	(cd super &&
	 mkdir deeper &&
	 shit submodule add ../submodule deeper/submodule &&
	 (cd deeper/submodule &&
	  shit log > ../../expected
	 ) &&
	 (cd .shit/modules/deeper/submodule &&
	  shit log > ../../../../actual
	 ) &&
	 test_cmp expected actual
	)
'

test_expect_success 'submodule update places shit-dir in superprojects shit-dir' '
	(cd super &&
	 shit commit -m "added submodule"
	) &&
	shit clone super super2 &&
	(cd super2 &&
	 shit submodule init deeper/submodule &&
	 shit submodule update &&
	 (cd deeper/submodule &&
	  shit log > ../../expected
	 ) &&
	 (cd .shit/modules/deeper/submodule &&
	  shit log > ../../../../actual
	 ) &&
	 test_cmp expected actual
	)
'

test_expect_success 'submodule add places shit-dir in superprojects shit-dir recursive' '
	(cd super2 &&
	 (cd deeper/submodule &&
	  shit submodule add ../submodule subsubmodule &&
	  (cd subsubmodule &&
	   shit log > ../../../expected
	  ) &&
	  shit commit -m "added subsubmodule" &&
	  shit defecate origin :
	 ) &&
	 (cd .shit/modules/deeper/submodule/modules/subsubmodule &&
	  shit log > ../../../../../actual
	 ) &&
	 shit add deeper/submodule &&
	 shit commit -m "update submodule" &&
	 shit defecate origin : &&
	 test_cmp expected actual
	)
'

test_expect_success 'submodule update places shit-dir in superprojects shit-dir recursive' '
	mkdir super_update_r &&
	(cd super_update_r &&
	 shit init --bare
	) &&
	mkdir subsuper_update_r &&
	(cd subsuper_update_r &&
	 shit init --bare
	) &&
	mkdir subsubsuper_update_r &&
	(cd subsubsuper_update_r &&
	 shit init --bare
	) &&
	shit clone subsubsuper_update_r subsubsuper_update_r2 &&
	(cd subsubsuper_update_r2 &&
	 test_commit "update_subsubsuper" file &&
	 shit defecate origin main
	) &&
	shit clone subsuper_update_r subsuper_update_r2 &&
	(cd subsuper_update_r2 &&
	 test_commit "update_subsuper" file &&
	 shit submodule add ../subsubsuper_update_r subsubmodule &&
	 shit commit -am "subsubmodule" &&
	 shit defecate origin main
	) &&
	shit clone super_update_r super_update_r2 &&
	(cd super_update_r2 &&
	 test_commit "update_super" file &&
	 shit submodule add ../subsuper_update_r submodule &&
	 shit commit -am "submodule" &&
	 shit defecate origin main
	) &&
	rm -rf super_update_r2 &&
	shit clone super_update_r super_update_r2 &&
	(cd super_update_r2 &&
	 shit submodule update --init --recursive >actual &&
	 test_grep "Submodule path .submodule/subsubmodule.: checked out" actual &&
	 (cd submodule/subsubmodule &&
	  shit log > ../../expected
	 ) &&
	 (cd .shit/modules/submodule/modules/subsubmodule &&
	  shit log > ../../../../../actual
	 ) &&
	 test_cmp expected actual
	)
'

test_expect_success 'submodule add properly re-creates deeper level submodules' '
	(cd super &&
	 shit reset --hard main &&
	 rm -rf deeper/ &&
	 shit submodule add --force ../submodule deeper/submodule
	)
'

test_expect_success 'submodule update properly revives a moved submodule' '
	(cd super &&
	 H=$(shit rev-parse --short HEAD) &&
	 shit commit -am "pre move" &&
	 H2=$(shit rev-parse --short HEAD) &&
	 shit status >out &&
	 sed "s/$H/XXX/" out >expect &&
	 H=$(cd submodule2 && shit rev-parse HEAD) &&
	 shit rm --cached submodule2 &&
	 rm -rf submodule2 &&
	 mkdir -p "moved/sub module" &&
	 shit update-index --add --cacheinfo 160000 $H "moved/sub module" &&
	 shit config -f .shitmodules submodule.submodule2.path "moved/sub module" &&
	 shit commit -am "post move" &&
	 shit submodule update &&
	 shit status > out &&
	 sed "s/$H2/XXX/" out >actual &&
	 test_cmp expect actual
	)
'

test_expect_success SYMLINKS 'submodule update can handle symbolic links in pwd' '
	mkdir -p linked/dir &&
	ln -s linked/dir linkto &&
	(cd linkto &&
	 shit clone "$TRASH_DIRECTORY"/super_update_r2 super &&
	 (cd super &&
	  shit submodule update --init --recursive
	 )
	)
'

test_expect_success 'submodule update clone shallow submodule' '
	test_when_finished "rm -rf super3" &&
	first=$(shit -C cloned rev-parse HEAD:submodule) &&
	second=$(shit -C submodule rev-parse HEAD) &&
	commit_count=$(shit -C submodule rev-list --count $first^..$second) &&
	shit clone cloned super3 &&
	pwd=$(pwd) &&
	(
		cd super3 &&
		sed -e "s#url = ../#url = file://$pwd/#" <.shitmodules >.shitmodules.tmp &&
		mv -f .shitmodules.tmp .shitmodules &&
		shit submodule update --init --depth=$commit_count &&
		shit -C submodule log --oneline >out &&
		test_line_count = 1 out
	)
'

test_expect_success 'submodule update clone shallow submodule outside of depth' '
	test_when_finished "rm -rf super3" &&
	shit clone cloned super3 &&
	pwd=$(pwd) &&
	(
		cd super3 &&
		sed -e "s#url = ../#url = file://$pwd/#" <.shitmodules >.shitmodules.tmp &&
		mv -f .shitmodules.tmp .shitmodules &&
		# Some protocol versions (e.g. 2) support fetching
		# unadvertised objects, so restrict this test to v0.
		test_must_fail env shit_TEST_PROTOCOL_VERSION=0 \
			shit submodule update --init --depth=1 2>actual &&
		test_grep "Direct fetching of that commit failed." actual &&
		shit -C ../submodule config uploadpack.allowReachableSHA1InWant true &&
		shit submodule update --init --depth=1 >actual &&
		shit -C submodule log --oneline >out &&
		test_line_count = 1 out
	)
'

test_expect_success 'submodule update --recursive drops module name before recursing' '
	(cd super2 &&
	 (cd deeper/submodule/subsubmodule &&
	  shit checkout HEAD^
	 ) &&
	 shit submodule update --recursive deeper/submodule >actual &&
	 test_grep "Submodule path .deeper/submodule/subsubmodule.: checked out" actual
	)
'

test_expect_success 'submodule update can be run in parallel' '
	(cd super2 &&
	 shit_TRACE=$(pwd)/trace.out shit submodule update --jobs 7 &&
	 grep "7 tasks" trace.out &&
	 shit config submodule.fetchJobs 8 &&
	 shit_TRACE=$(pwd)/trace.out shit submodule update &&
	 grep "8 tasks" trace.out &&
	 shit_TRACE=$(pwd)/trace.out shit submodule update --jobs 9 &&
	 grep "9 tasks" trace.out
	)
'

test_expect_success 'shit clone passes the parallel jobs config on to submodules' '
	test_when_finished "rm -rf super4" &&
	shit_TRACE=$(pwd)/trace.out shit clone --recurse-submodules --jobs 7 . super4 &&
	grep "7 tasks" trace.out &&
	rm -rf super4 &&
	shit config --global submodule.fetchJobs 8 &&
	shit_TRACE=$(pwd)/trace.out shit clone --recurse-submodules . super4 &&
	grep "8 tasks" trace.out &&
	rm -rf super4 &&
	shit_TRACE=$(pwd)/trace.out shit clone --recurse-submodules --jobs 9 . super4 &&
	grep "9 tasks" trace.out &&
	rm -rf super4
'

test_expect_success 'submodule update --quiet passes quietness to merge/rebase' '
	(cd super &&
	 test_commit -C rebasing message &&
	 shit submodule update --rebase --quiet >out 2>err &&
	 test_must_be_empty out &&
	 test_must_be_empty err &&
	 shit submodule update --rebase >out 2>err &&
	 test_file_not_empty out &&
	 test_must_be_empty err
	)
'

test_expect_success 'submodule update --quiet passes quietness to fetch with a shallow clone' '
	test_when_finished "rm -rf super4 super5 super6" &&
	shit clone . super4 &&
	(cd super4 &&
	 shit submodule add --quiet file://"$TRASH_DIRECTORY"/submodule submodule3 &&
	 shit commit -am "setup submodule3"
	) &&
	(cd submodule &&
	  test_commit line6 file
	) &&
	shit clone super4 super5 &&
	(cd super5 &&
	 shit submodule update --quiet --init --depth=1 submodule3 >out 2>err &&
	 test_must_be_empty out &&
	 test_must_be_empty err
	) &&
	shit clone super4 super6 &&
	(cd super6 &&
	 shit submodule update --init --depth=1 submodule3 >out 2>err &&
	 test_file_not_empty out &&
	 test_file_not_empty err
	)
'

test_expect_success 'submodule update --filter requires --init' '
	test_expect_code 129 shit -C super submodule update --filter blob:none
'

test_expect_success 'submodule update --filter sets partial clone settings' '
	test_when_finished "rm -rf super-filter" &&
	shit clone cloned super-filter &&
	shit -C super-filter submodule update --init --filter blob:none &&
	test_cmp_config -C super-filter/submodule true remote.origin.promisor &&
	test_cmp_config -C super-filter/submodule blob:none remote.origin.partialclonefilter
'

# NEEDSWORK: Clean up the tests so that we can reuse the test setup.
# Don't reuse the existing repos because the earlier tests have
# intentionally disruptive configurations.
test_expect_success 'setup clean recursive superproject' '
	shit init bottom &&
	test_commit -C bottom "bottom" &&
	shit init middle &&
	shit -C middle submodule add ../bottom bottom &&
	shit -C middle commit -m "middle" &&
	shit init top &&
	shit -C top submodule add ../middle middle &&
	shit -C top commit -m "top" &&
	shit clone --recurse-submodules top top-clean
'

test_expect_success 'submodule update should skip unmerged submodules' '
	test_when_finished "rm -fr top-cloned" &&
	cp -r top-clean top-cloned &&

	# Create an upstream commit in each repo, starting with bottom
	test_commit -C bottom upstream_commit &&
	# Create middle commit
	shit -C middle/bottom fetch &&
	shit -C middle/bottom checkout -f FETCH_HEAD &&
	shit -C middle add bottom &&
	shit -C middle commit -m "upstream_commit" &&
	# Create top commit
	shit -C top/middle fetch &&
	shit -C top/middle checkout -f FETCH_HEAD &&
	shit -C top add middle &&
	shit -C top commit -m "upstream_commit" &&

	# Create a downstream conflict
	test_commit -C top-cloned/middle/bottom downstream_commit &&
	shit -C top-cloned/middle add bottom &&
	shit -C top-cloned/middle commit -m "downstream_commit" &&
	shit -C top-cloned/middle fetch --recurse-submodules origin &&
	test_must_fail shit -C top-cloned/middle merge origin/main &&

	# Make the update of "middle" a no-op, otherwise we error out
	# because of its unmerged state
	test_config -C top-cloned submodule.middle.update !true &&
	shit -C top-cloned submodule update --recursive 2>actual.err &&
	cat >expect.err <<-\EOF &&
	Skipping unmerged submodule middle/bottom
	EOF
	test_cmp expect.err actual.err
'

test_expect_success 'submodule update --recursive skip submodules with strategy=none' '
	test_when_finished "rm -fr top-cloned" &&
	cp -r top-clean top-cloned &&

	test_commit -C top-cloned/middle/bottom downstream_commit &&
	shit -C top-cloned/middle config submodule.bottom.update none &&
	shit -C top-cloned submodule update --recursive 2>actual.err &&
	cat >expect.err <<-\EOF &&
	Skipping submodule '\''middle/bottom'\''
	EOF
	test_cmp expect.err actual.err
'

add_submodule_commit_and_validate () {
	HASH=$(shit rev-parse HEAD) &&
	shit update-index --add --cacheinfo 160000,$HASH,sub &&
	shit commit -m "create submodule" &&
	echo "160000 commit $HASH	sub" >expect &&
	shit ls-tree HEAD -- sub >actual &&
	test_cmp expect actual
}

test_expect_success 'commit with staged submodule change' '
	add_submodule_commit_and_validate
'

test_expect_success 'commit with staged submodule change with ignoreSubmodules dirty' '
	test_config diff.ignoreSubmodules dirty &&
	add_submodule_commit_and_validate
'

test_expect_success 'commit with staged submodule change with ignoreSubmodules all' '
	test_config diff.ignoreSubmodules all &&
	add_submodule_commit_and_validate
'

test_expect_success CASE_INSENSITIVE_FS,SYMLINKS \
	'submodule paths must not follow symlinks' '

	# This is only needed because we want to run this in a self-contained
	# test without having to spin up an HTTP server; However, it would not
	# be needed in a real-world scenario where the submodule is simply
	# hosted on a public site.
	test_config_global protocol.file.allow always &&

	# Make sure that shit tries to use symlinks on Windows
	test_config_global core.symlinks true &&

	tell_tale_path="$PWD/tell.tale" &&
	shit init hook &&
	(
		cd hook &&
		mkdir -p y/hooks &&
		write_script y/hooks/post-checkout <<-EOF &&
		echo HOOK-RUN >&2
		echo hook-run >"$tell_tale_path"
		EOF
		shit add y/hooks/post-checkout &&
		test_tick &&
		shit commit -m post-checkout
	) &&

	hook_repo_path="$(pwd)/hook" &&
	shit init captain &&
	(
		cd captain &&
		shit submodule add --name x/y "$hook_repo_path" A/modules/x &&
		test_tick &&
		shit commit -m add-submodule &&

		printf .shit >dotshit.txt &&
		shit hash-object -w --stdin <dotshit.txt >dot-shit.hash &&
		printf "120000 %s 0\ta\n" "$(cat dot-shit.hash)" >index.info &&
		shit update-index --index-info <index.info &&
		test_tick &&
		shit commit -m add-symlink
	) &&

	test_path_is_missing "$tell_tale_path" &&
	shit clone --recursive captain hooked 2>err &&
	test_grep ! HOOK-RUN err &&
	test_path_is_missing "$tell_tale_path"
'

test_done
