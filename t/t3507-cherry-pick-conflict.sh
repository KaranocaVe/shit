#!/bin/sh

test_description='test cherry-pick and revert with conflicts

  -
  + picked: rewrites foo to c
  + base: rewrites foo to b
  + initial: writes foo as a, unrelated as unrelated

'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_CREATE_REPO_NO_TEMPLATE=1
. ./test-lib.sh

pristine_detach () {
	shit checkout -f "$1^0" &&
	shit read-tree -u --reset HEAD &&
	shit clean -d -f -f -q -x
}

test_expect_success setup '

	echo unrelated >unrelated &&
	shit add unrelated &&
	test_commit initial foo a &&
	test_commit base foo b &&
	test_commit picked foo c &&
	test_commit --signoff picked-signed foo d &&
	shit checkout -b topic initial &&
	test_commit redundant-pick foo c redundant &&
	shit commit --allow-empty --allow-empty-message &&
	shit tag empty &&
	shit checkout main &&
	shit config advice.detachedhead false

'

test_expect_success 'failed cherry-pick does not advance HEAD' '
	pristine_detach initial &&

	head=$(shit rev-parse HEAD) &&
	test_must_fail shit cherry-pick picked &&
	newhead=$(shit rev-parse HEAD) &&

	test "$head" = "$newhead"
'

test_expect_success 'advice from failed cherry-pick' '
	pristine_detach initial &&

	picked=$(shit rev-parse --short picked) &&
	cat <<-EOF >expected &&
	error: could not apply $picked... picked
	hint: After resolving the conflicts, mark them with
	hint: "shit add/rm <pathspec>", then run
	hint: "shit cherry-pick --continue".
	hint: You can instead skip this commit with "shit cherry-pick --skip".
	hint: To abort and get back to the state before "shit cherry-pick",
	hint: run "shit cherry-pick --abort".
	hint: Disable this message with "shit config advice.mergeConflict false"
	EOF
	test_must_fail shit cherry-pick picked 2>actual &&

	test_cmp expected actual
'

test_expect_success 'advice from failed cherry-pick --no-commit' "
	pristine_detach initial &&

	picked=\$(shit rev-parse --short picked) &&
	cat <<-EOF >expected &&
	error: could not apply \$picked... picked
	hint: after resolving the conflicts, mark the corrected paths
	hint: with 'shit add <paths>' or 'shit rm <paths>'
	hint: Disable this message with \"shit config advice.mergeConflict false\"
	EOF
	test_must_fail shit cherry-pick --no-commit picked 2>actual &&

	test_cmp expected actual
"

test_expect_success 'failed cherry-pick sets CHERRY_PICK_HEAD' '
	pristine_detach initial &&
	test_must_fail shit cherry-pick picked &&
	test_cmp_rev picked CHERRY_PICK_HEAD
'

test_expect_success 'successful cherry-pick does not set CHERRY_PICK_HEAD' '
	pristine_detach initial &&
	shit cherry-pick base &&
	test_must_fail shit rev-parse --verify CHERRY_PICK_HEAD
'

test_expect_success 'cherry-pick --no-commit does not set CHERRY_PICK_HEAD' '
	pristine_detach initial &&
	shit cherry-pick --no-commit base &&
	test_must_fail shit rev-parse --verify CHERRY_PICK_HEAD
'

test_expect_success 'cherry-pick w/dirty tree does not set CHERRY_PICK_HEAD' '
	pristine_detach initial &&
	echo foo >foo &&
	test_must_fail shit cherry-pick base &&
	test_must_fail shit rev-parse --verify CHERRY_PICK_HEAD
'

test_expect_success \
	'cherry-pick --strategy=resolve w/dirty tree does not set CHERRY_PICK_HEAD' '
	pristine_detach initial &&
	echo foo >foo &&
	test_must_fail shit cherry-pick --strategy=resolve base &&
	test_must_fail shit rev-parse --verify CHERRY_PICK_HEAD
'

test_expect_success 'shit_CHERRY_PICK_HELP suppresses CHERRY_PICK_HEAD' '
	pristine_detach initial &&
	(
		shit_CHERRY_PICK_HELP="and then do something else" &&
		export shit_CHERRY_PICK_HELP &&
		test_must_fail shit cherry-pick picked
	) &&
	test_must_fail shit rev-parse --verify CHERRY_PICK_HEAD
'

test_expect_success 'shit reset clears CHERRY_PICK_HEAD' '
	pristine_detach initial &&

	test_must_fail shit cherry-pick picked &&
	shit reset &&

	test_must_fail shit rev-parse --verify CHERRY_PICK_HEAD
'

test_expect_success 'failed commit does not clear CHERRY_PICK_HEAD' '
	pristine_detach initial &&

	test_must_fail shit cherry-pick picked &&
	test_must_fail shit commit &&

	test_cmp_rev picked CHERRY_PICK_HEAD
'

test_expect_success 'cancelled commit does not clear CHERRY_PICK_HEAD' '
	pristine_detach initial &&

	test_must_fail shit cherry-pick picked &&
	echo resolved >foo &&
	shit add foo &&
	shit update-index --refresh -q &&
	test_must_fail shit diff-index --exit-code HEAD &&
	(
		shit_EDITOR=false &&
		export shit_EDITOR &&
		test_must_fail shit commit
	) &&

	test_cmp_rev picked CHERRY_PICK_HEAD
'

test_expect_success 'successful commit clears CHERRY_PICK_HEAD' '
	pristine_detach initial &&

	test_must_fail shit cherry-pick picked &&
	echo resolved >foo &&
	shit add foo &&
	shit commit &&

	test_must_fail shit rev-parse --verify CHERRY_PICK_HEAD
'

test_expect_success 'partial commit of cherry-pick fails' '
	pristine_detach initial &&

	test_must_fail shit cherry-pick picked &&
	echo resolved >foo &&
	shit add foo &&
	test_must_fail shit commit foo 2>err &&

	test_grep "cannot do a partial commit during a cherry-pick." err
'

test_expect_success 'commit --amend of cherry-pick fails' '
	pristine_detach initial &&

	test_must_fail shit cherry-pick picked &&
	echo resolved >foo &&
	shit add foo &&
	test_must_fail shit commit --amend 2>err &&

	test_grep "in the middle of a cherry-pick -- cannot amend." err
'

test_expect_success 'successful final commit clears cherry-pick state' '
	pristine_detach initial &&

	test_must_fail shit cherry-pick base picked-signed &&
	echo resolved >foo &&
	test_path_is_file .shit/sequencer/todo &&
	shit commit -a &&
	test_path_is_missing .shit/sequencer
'

test_expect_success 'reset after final pick clears cherry-pick state' '
	pristine_detach initial &&

	test_must_fail shit cherry-pick base picked-signed &&
	echo resolved >foo &&
	test_path_is_file .shit/sequencer/todo &&
	shit reset &&
	test_path_is_missing .shit/sequencer
'

test_expect_success 'failed cherry-pick produces dirty index' '
	pristine_detach initial &&

	test_must_fail shit cherry-pick picked &&

	test_must_fail shit update-index --refresh -q &&
	test_must_fail shit diff-index --exit-code HEAD
'

test_expect_success 'failed cherry-pick registers participants in index' '
	pristine_detach initial &&
	{
		shit checkout base -- foo &&
		shit ls-files --stage foo &&
		shit checkout initial -- foo &&
		shit ls-files --stage foo &&
		shit checkout picked -- foo &&
		shit ls-files --stage foo
	} >stages &&
	sed "
		1 s/ 0	/ 1	/
		2 s/ 0	/ 2	/
		3 s/ 0	/ 3	/
	" stages >expected &&
	shit read-tree -u --reset HEAD &&

	test_must_fail shit cherry-pick picked &&
	shit ls-files --stage --unmerged >actual &&

	test_cmp expected actual
'

test_expect_success \
	'cherry-pick conflict, ensure commit.cleanup = scissors places scissors line properly' '
	pristine_detach initial &&
	shit config commit.cleanup scissors &&
	cat <<-EOF >expected &&
		picked

		# ------------------------ >8 ------------------------
		# Do not modify or remove the line above.
		# Everything below it will be ignored.
		#
		# Conflicts:
		#	foo
		EOF

	test_must_fail shit cherry-pick picked &&

	test_cmp expected .shit/MERGE_MSG
'

test_expect_success \
	'cherry-pick conflict, ensure cleanup=scissors places scissors line properly' '
	pristine_detach initial &&
	shit config --unset commit.cleanup &&
	cat <<-EOF >expected &&
		picked

		# ------------------------ >8 ------------------------
		# Do not modify or remove the line above.
		# Everything below it will be ignored.
		#
		# Conflicts:
		#	foo
		EOF

	test_must_fail shit cherry-pick --cleanup=scissors picked &&

	test_cmp expected .shit/MERGE_MSG
'

test_expect_success 'failed cherry-pick describes conflict in work tree' '
	pristine_detach initial &&
	cat <<-EOF >expected &&
	<<<<<<< HEAD
	a
	=======
	c
	>>>>>>> objid (picked)
	EOF

	test_must_fail shit cherry-pick picked &&

	sed "s/[a-f0-9]* (/objid (/" foo >actual &&
	test_cmp expected actual
'

test_expect_success 'diff3 -m style' '
	pristine_detach initial &&
	shit config merge.conflictstyle diff3 &&
	cat <<-EOF >expected &&
	<<<<<<< HEAD
	a
	||||||| parent of objid (picked)
	b
	=======
	c
	>>>>>>> objid (picked)
	EOF

	test_must_fail shit cherry-pick picked &&

	sed "s/[a-f0-9]* (/objid (/" foo >actual &&
	test_cmp expected actual
'

test_expect_success 'revert also handles conflicts sanely' '
	shit config --unset merge.conflictstyle &&
	pristine_detach initial &&
	cat <<-EOF >expected &&
	<<<<<<< HEAD
	a
	=======
	b
	>>>>>>> parent of objid (picked)
	EOF
	{
		shit checkout picked -- foo &&
		shit ls-files --stage foo &&
		shit checkout initial -- foo &&
		shit ls-files --stage foo &&
		shit checkout base -- foo &&
		shit ls-files --stage foo
	} >stages &&
	sed "
		1 s/ 0	/ 1	/
		2 s/ 0	/ 2	/
		3 s/ 0	/ 3	/
	" stages >expected-stages &&
	shit read-tree -u --reset HEAD &&

	head=$(shit rev-parse HEAD) &&
	test_must_fail shit revert picked &&
	newhead=$(shit rev-parse HEAD) &&
	shit ls-files --stage --unmerged >actual-stages &&

	test "$head" = "$newhead" &&
	test_must_fail shit update-index --refresh -q &&
	test_must_fail shit diff-index --exit-code HEAD &&
	test_cmp expected-stages actual-stages &&
	sed "s/[a-f0-9]* (/objid (/" foo >actual &&
	test_cmp expected actual
'

test_expect_success 'failed revert sets REVERT_HEAD' '
	pristine_detach initial &&
	test_must_fail shit revert picked &&
	test_cmp_rev picked REVERT_HEAD
'

test_expect_success 'successful revert does not set REVERT_HEAD' '
	pristine_detach base &&
	shit revert base &&
	test_must_fail shit rev-parse --verify CHERRY_PICK_HEAD &&
	test_must_fail shit rev-parse --verify REVERT_HEAD
'

test_expect_success 'revert --no-commit sets REVERT_HEAD' '
	pristine_detach base &&
	shit revert --no-commit base &&
	test_must_fail shit rev-parse --verify CHERRY_PICK_HEAD &&
	test_cmp_rev base REVERT_HEAD
'

test_expect_success 'revert w/dirty tree does not set REVERT_HEAD' '
	pristine_detach base &&
	echo foo >foo &&
	test_must_fail shit revert base &&
	test_must_fail shit rev-parse --verify CHERRY_PICK_HEAD &&
	test_must_fail shit rev-parse --verify REVERT_HEAD
'

test_expect_success 'shit_CHERRY_PICK_HELP does not suppress REVERT_HEAD' '
	pristine_detach initial &&
	(
		shit_CHERRY_PICK_HELP="and then do something else" &&
		shit_REVERT_HELP="and then do something else, again" &&
		export shit_CHERRY_PICK_HELP shit_REVERT_HELP &&
		test_must_fail shit revert picked
	) &&
	test_must_fail shit rev-parse --verify CHERRY_PICK_HEAD &&
	test_cmp_rev picked REVERT_HEAD
'

test_expect_success 'shit reset clears REVERT_HEAD' '
	pristine_detach initial &&
	test_must_fail shit revert picked &&
	shit reset &&
	test_must_fail shit rev-parse --verify REVERT_HEAD
'

test_expect_success 'failed commit does not clear REVERT_HEAD' '
	pristine_detach initial &&
	test_must_fail shit revert picked &&
	test_must_fail shit commit &&
	test_cmp_rev picked REVERT_HEAD
'

test_expect_success 'successful final commit clears revert state' '
	pristine_detach picked-signed &&

	test_must_fail shit revert picked-signed base &&
	echo resolved >foo &&
	test_path_is_file .shit/sequencer/todo &&
	shit commit -a &&
	test_path_is_missing .shit/sequencer
'

test_expect_success 'reset after final pick clears revert state' '
	pristine_detach picked-signed &&

	test_must_fail shit revert picked-signed base &&
	echo resolved >foo &&
	test_path_is_file .shit/sequencer/todo &&
	shit reset &&
	test_path_is_missing .shit/sequencer
'

test_expect_success 'revert conflict, diff3 -m style' '
	pristine_detach initial &&
	shit config merge.conflictstyle diff3 &&
	cat <<-EOF >expected &&
	<<<<<<< HEAD
	a
	||||||| objid (picked)
	c
	=======
	b
	>>>>>>> parent of objid (picked)
	EOF

	test_must_fail shit revert picked &&

	sed "s/[a-f0-9]* (/objid (/" foo >actual &&
	test_cmp expected actual
'

test_expect_success \
	'revert conflict, ensure commit.cleanup = scissors places scissors line properly' '
	pristine_detach initial &&
	shit config commit.cleanup scissors &&
	cat >expected <<-EOF &&
		Revert "picked"

		This reverts commit OBJID.

		# ------------------------ >8 ------------------------
		# Do not modify or remove the line above.
		# Everything below it will be ignored.
		#
		# Conflicts:
		#	foo
		EOF

	test_must_fail shit revert picked &&

	sed "s/$OID_REGEX/OBJID/" .shit/MERGE_MSG >actual &&
	test_cmp expected actual
'

test_expect_success \
	'revert conflict, ensure cleanup=scissors places scissors line properly' '
	pristine_detach initial &&
	shit config --unset commit.cleanup &&
	cat >expected <<-EOF &&
		Revert "picked"

		This reverts commit OBJID.

		# ------------------------ >8 ------------------------
		# Do not modify or remove the line above.
		# Everything below it will be ignored.
		#
		# Conflicts:
		#	foo
		EOF

	test_must_fail shit revert --cleanup=scissors picked &&

	sed "s/$OID_REGEX/OBJID/" .shit/MERGE_MSG >actual &&
	test_cmp expected actual
'

test_expect_success 'failed cherry-pick does not forget -s' '
	pristine_detach initial &&
	test_must_fail shit cherry-pick -s picked &&
	test_grep -e "Signed-off-by" .shit/MERGE_MSG
'

test_expect_success 'commit after failed cherry-pick does not add duplicated -s' '
	pristine_detach initial &&
	test_must_fail shit cherry-pick -s picked-signed &&
	shit commit -a -s &&
	test $(shit show -s >tmp && grep -c "Signed-off-by" tmp && rm tmp) = 1
'

test_expect_success 'commit after failed cherry-pick adds -s at the right place' '
	pristine_detach initial &&
	test_must_fail shit cherry-pick picked &&

	shit commit -a -s &&

	# Do S-o-b and Conflicts appear in the right order?
	cat <<-\EOF >expect &&
	Signed-off-by: C O Mitter <committer@example.com>
	# Conflicts:
	EOF
	grep -e "^# Conflicts:" -e "^Signed-off-by" .shit/COMMIT_EDITMSG >actual &&
	test_cmp expect actual &&

	cat <<-\EOF >expected &&
	picked

	Signed-off-by: C O Mitter <committer@example.com>
	EOF

	shit show -s --pretty=format:%B >actual &&
	test_cmp expected actual
'

test_expect_success 'commit --amend -s places the sign-off at the right place' '
	pristine_detach initial &&
	test_must_fail shit cherry-pick picked &&

	# emulate old-style conflicts block
	mv .shit/MERGE_MSG .shit/MERGE_MSG+ &&
	sed -e "/^# Conflicts:/,\$s/^# *//" .shit/MERGE_MSG+ >.shit/MERGE_MSG &&

	shit commit -a &&
	shit commit --amend -s &&

	# Do S-o-b and Conflicts appear in the right order?
	cat <<-\EOF >expect &&
	Signed-off-by: C O Mitter <committer@example.com>
	Conflicts:
	EOF
	grep -e "^Conflicts:" -e "^Signed-off-by" .shit/COMMIT_EDITMSG >actual &&
	test_cmp expect actual
'

test_expect_success 'cherry-pick preserves sparse-checkout' '
	pristine_detach initial &&
	test_config core.sparseCheckout true &&
	test_when_finished "
		echo \"/*\" >.shit/info/sparse-checkout
		shit read-tree --reset -u HEAD
		rm .shit/info/sparse-checkout" &&
	mkdir .shit/info &&
	echo /unrelated >.shit/info/sparse-checkout &&
	shit read-tree --reset -u HEAD &&
	test_must_fail shit cherry-pick -Xours picked>actual &&
	test_grep ! "Changes not staged for commit:" actual
'

test_expect_success 'cherry-pick --continue remembers --keep-redundant-commits' '
	test_when_finished "shit cherry-pick --abort || :" &&
	pristine_detach initial &&
	test_must_fail shit cherry-pick --keep-redundant-commits picked redundant &&
	echo c >foo &&
	shit add foo &&
	shit cherry-pick --continue
'

test_expect_success 'cherry-pick --continue remembers --allow-empty and --allow-empty-message' '
	test_when_finished "shit cherry-pick --abort || :" &&
	pristine_detach initial &&
	test_must_fail shit cherry-pick --allow-empty --allow-empty-message \
				       picked empty &&
	echo c >foo &&
	shit add foo &&
	shit cherry-pick --continue
'

test_done
