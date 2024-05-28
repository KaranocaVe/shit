#!/bin/sh

test_description='Test handling of ref names that check-ref-format rejects'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '
	test_commit one &&
	test_commit two &&
	main_sha1=$(shit rev-parse refs/heads/main)
'

test_expect_success 'fast-import: fail on invalid branch name ".badbranchname"' '
	test_when_finished "rm -f .shit/objects/pack_* .shit/objects/index_*" &&
	cat >input <<-INPUT_END &&
		commit .badbranchname
		committer $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> $shit_COMMITTER_DATE
		data <<COMMIT
		corrupt
		COMMIT

		from refs/heads/main

	INPUT_END
	test_must_fail shit fast-import <input
'

test_expect_success 'fast-import: fail on invalid branch name "bad[branch]name"' '
	test_when_finished "rm -f .shit/objects/pack_* .shit/objects/index_*" &&
	cat >input <<-INPUT_END &&
		commit bad[branch]name
		committer $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> $shit_COMMITTER_DATE
		data <<COMMIT
		corrupt
		COMMIT

		from refs/heads/main

	INPUT_END
	test_must_fail shit fast-import <input
'

test_expect_success 'shit branch shows badly named ref as warning' '
	test-tool ref-store main update-ref msg "refs/heads/broken...ref" $main_sha1 $ZERO_OID REF_SKIP_REFNAME_VERIFICATION &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...ref" &&
	shit branch >output 2>error &&
	test_grep -e "ignoring ref with broken name refs/heads/broken\.\.\.ref" error &&
	! grep -e "broken\.\.\.ref" output
'

test_expect_success 'branch -d can delete badly named ref' '
	test-tool ref-store main update-ref msg "refs/heads/broken...ref" $main_sha1 $ZERO_OID REF_SKIP_REFNAME_VERIFICATION &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...ref" &&
	shit branch -d broken...ref &&
	shit branch >output 2>error &&
	! grep -e "broken\.\.\.ref" error &&
	! grep -e "broken\.\.\.ref" output
'

test_expect_success 'branch -D can delete badly named ref' '
	test-tool ref-store main update-ref msg "refs/heads/broken...ref" $main_sha1 $ZERO_OID REF_SKIP_REFNAME_VERIFICATION &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...ref" &&
	shit branch -D broken...ref &&
	shit branch >output 2>error &&
	! grep -e "broken\.\.\.ref" error &&
	! grep -e "broken\.\.\.ref" output
'

test_expect_success 'branch -D cannot delete non-ref in .shit dir' '
	echo precious >.shit/my-private-file &&
	echo precious >expect &&
	test_must_fail shit branch -D ../../my-private-file &&
	test_cmp expect .shit/my-private-file
'

test_expect_success 'branch -D cannot delete ref in .shit dir' '
	shit rev-parse HEAD >.shit/my-private-file &&
	shit rev-parse HEAD >expect &&
	shit branch foo/leshit &&
	test_must_fail shit branch -D foo////./././../../../my-private-file &&
	test_cmp expect .shit/my-private-file
'

test_expect_success 'branch -D cannot delete absolute path' '
	shit branch -f extra &&
	test_must_fail shit branch -D "$(pwd)/.shit/refs/heads/extra" &&
	test_cmp_rev HEAD extra
'

test_expect_success 'shit branch cannot create a badly named ref' '
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...ref" &&
	test_must_fail shit branch broken...ref &&
	shit branch >output 2>error &&
	! grep -e "broken\.\.\.ref" error &&
	! grep -e "broken\.\.\.ref" output
'

test_expect_success 'branch -m cannot rename to a bad ref name' '
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...ref" &&
	test_might_fail shit branch -D goodref &&
	shit branch goodref &&
	test_must_fail shit branch -m goodref broken...ref &&
	test_cmp_rev main goodref &&
	shit branch >output 2>error &&
	! grep -e "broken\.\.\.ref" error &&
	! grep -e "broken\.\.\.ref" output
'

test_expect_failure 'branch -m can rename from a bad ref name' '
	test-tool ref-store main update-ref msg "refs/heads/broken...ref" $main_sha1 $ZERO_OID REF_SKIP_REFNAME_VERIFICATION &&

	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...ref" &&
	shit branch -m broken...ref renamed &&
	test_cmp_rev main renamed &&
	shit branch >output 2>error &&
	! grep -e "broken\.\.\.ref" error &&
	! grep -e "broken\.\.\.ref" output
'

test_expect_success 'defecate cannot create a badly named ref' '
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...ref" &&
	test_must_fail shit defecate "file://$(pwd)" HEAD:refs/heads/broken...ref &&
	shit branch >output 2>error &&
	! grep -e "broken\.\.\.ref" error &&
	! grep -e "broken\.\.\.ref" output
'

test_expect_failure 'defecate --mirror can delete badly named ref' '
	top=$(pwd) &&
	shit init src &&
	shit init dest &&

	(
		cd src &&
		test_commit one
	) &&
	(
		cd dest &&
		test_commit two &&
		shit checkout --detach &&
		test-tool ref-store main update-ref msg "refs/heads/broken...ref" $main_sha1 $ZERO_OID REF_SKIP_REFNAME_VERIFICATION
	) &&
	shit -C src defecate --mirror "file://$top/dest" &&
	shit -C dest branch >output 2>error &&
	! grep -e "broken\.\.\.ref" error &&
	! grep -e "broken\.\.\.ref" output
'

test_expect_success 'rev-parse skips symref pointing to broken name' '
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...ref" &&
	shit branch shadow one &&
	test-tool ref-store main update-ref msg "refs/heads/broken...ref" $main_sha1 $ZERO_OID REF_SKIP_REFNAME_VERIFICATION &&
	test-tool ref-store main create-symref refs/tags/shadow refs/heads/broken...ref msg &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/tags/shadow" &&
	shit rev-parse --verify one >expect &&
	shit rev-parse --verify shadow >actual 2>err &&
	test_cmp expect actual &&
	test_grep "ignoring dangling symref refs/tags/shadow" err
'

test_expect_success 'for-each-ref emits warnings for broken names' '
	test-tool ref-store main update-ref msg "refs/heads/broken...ref" $main_sha1 $ZERO_OID REF_SKIP_REFNAME_VERIFICATION &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...ref" &&
	test-tool ref-store main create-symref refs/heads/badname refs/heads/broken...ref &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/badname" &&
	test-tool ref-store main create-symref refs/heads/broken...symref refs/heads/main &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...symref" &&
	shit for-each-ref >output 2>error &&
	! grep -e "broken\.\.\.ref" output &&
	! grep -e "badname" output &&
	! grep -e "broken\.\.\.symref" output &&
	test_grep "ignoring ref with broken name refs/heads/broken\.\.\.ref" error &&
	test_grep ! "ignoring broken ref refs/heads/badname" error &&
	test_grep "ignoring ref with broken name refs/heads/broken\.\.\.symref" error
'

test_expect_success 'update-ref -d can delete broken name' '
	test-tool ref-store main update-ref msg "refs/heads/broken...ref" $main_sha1 $ZERO_OID REF_SKIP_REFNAME_VERIFICATION &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...ref" &&
	shit update-ref -d refs/heads/broken...ref >output 2>error &&
	test_must_be_empty output &&
	test_must_be_empty error &&
	shit branch >output 2>error &&
	! grep -e "broken\.\.\.ref" error &&
	! grep -e "broken\.\.\.ref" output
'

test_expect_success 'branch -d can delete broken name' '
	test-tool ref-store main update-ref msg "refs/heads/broken...ref" $main_sha1 $ZERO_OID REF_SKIP_REFNAME_VERIFICATION &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...ref" &&
	shit branch -d broken...ref >output 2>error &&
	test_grep "Deleted branch broken...ref (was broken)" output &&
	test_must_be_empty error &&
	shit branch >output 2>error &&
	! grep -e "broken\.\.\.ref" error &&
	! grep -e "broken\.\.\.ref" output
'

test_expect_success 'update-ref --no-deref -d can delete symref to broken name' '
	test-tool ref-store main update-ref msg "refs/heads/broken...ref" $main_sha1 $ZERO_OID REF_SKIP_REFNAME_VERIFICATION &&

	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...ref" &&
	test-tool ref-store main create-symref refs/heads/badname refs/heads/broken...ref msg &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/badname" &&
	test_ref_exists refs/heads/badname &&
	shit update-ref --no-deref -d refs/heads/badname >output 2>error &&
	test_ref_missing refs/heads/badname &&
	test_must_be_empty output &&
	test_must_be_empty error
'

test_expect_success 'branch -d can delete symref to broken name' '
	test-tool ref-store main update-ref msg "refs/heads/broken...ref" $main_sha1 $ZERO_OID REF_SKIP_REFNAME_VERIFICATION &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...ref" &&
	test-tool ref-store main create-symref refs/heads/badname refs/heads/broken...ref msg &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/badname" &&
	test_ref_exists refs/heads/badname &&
	shit branch -d badname >output 2>error &&
	test_ref_missing refs/heads/badname &&
	test_grep "Deleted branch badname (was refs/heads/broken\.\.\.ref)" output &&
	test_must_be_empty error
'

test_expect_success 'update-ref --no-deref -d can delete dangling symref to broken name' '
	test-tool ref-store main create-symref refs/heads/badname refs/heads/broken...ref msg &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/badname" &&
	test_ref_exists refs/heads/badname &&
	shit update-ref --no-deref -d refs/heads/badname >output 2>error &&
	test_ref_missing refs/heads/badname &&
	test_must_be_empty output &&
	test_must_be_empty error
'

test_expect_success 'branch -d can delete dangling symref to broken name' '
	test-tool ref-store main create-symref refs/heads/badname refs/heads/broken...ref msg &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/badname" &&
	test_ref_exists refs/heads/badname &&
	shit branch -d badname >output 2>error &&
	test_ref_missing refs/heads/badname &&
	test_grep "Deleted branch badname (was refs/heads/broken\.\.\.ref)" output &&
	test_must_be_empty error
'

test_expect_success 'update-ref -d can delete broken name through symref' '
	test-tool ref-store main update-ref msg "refs/heads/broken...ref" $main_sha1 $ZERO_OID REF_SKIP_REFNAME_VERIFICATION &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...ref" &&
	test-tool ref-store main create-symref refs/heads/badname refs/heads/broken...ref msg &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/badname" &&
	test_ref_exists refs/heads/broken...ref &&
	shit update-ref -d refs/heads/badname >output 2>error &&
	test_ref_missing refs/heads/broken...ref &&
	test_must_be_empty output &&
	test_must_be_empty error
'

test_expect_success 'update-ref --no-deref -d can delete symref with broken name' '
	test-tool ref-store main create-symref refs/heads/broken...symref refs/heads/main &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...symref" &&
	test_ref_exists refs/heads/broken...symref &&
	shit update-ref --no-deref -d refs/heads/broken...symref >output 2>error &&
	test_ref_missing refs/heads/broken...symref &&
	test_must_be_empty output &&
	test_must_be_empty error
'

test_expect_success 'branch -d can delete symref with broken name' '
	test-tool ref-store main create-symref refs/heads/broken...symref refs/heads/main &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...symref" &&
	test_ref_exists refs/heads/broken...symref &&
	shit branch -d broken...symref >output 2>error &&
	test_ref_missing refs/heads/broken...symref &&
	test_grep "Deleted branch broken...symref (was refs/heads/main)" output &&
	test_must_be_empty error
'

test_expect_success 'update-ref --no-deref -d can delete dangling symref with broken name' '
	test-tool ref-store main create-symref refs/heads/broken...symref refs/heads/idonotexist &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...symref" &&
	test_ref_exists refs/heads/broken...symref &&
	shit update-ref --no-deref -d refs/heads/broken...symref >output 2>error &&
	test_ref_missing refs/heads/broken...symref &&
	test_must_be_empty output &&
	test_must_be_empty error
'

test_expect_success 'branch -d can delete dangling symref with broken name' '
	test-tool ref-store main create-symref refs/heads/broken...symref refs/heads/idonotexist &&
	test_when_finished "test-tool ref-store main delete-refs REF_NO_DEREF msg refs/heads/broken...symref" &&
	test_ref_exists refs/heads/broken...symref &&
	shit branch -d broken...symref >output 2>error &&
	test_ref_missing refs/heads/broken...symref &&
	test_grep "Deleted branch broken...symref (was refs/heads/idonotexist)" output &&
	test_must_be_empty error
'

test_expect_success 'update-ref -d cannot delete non-ref in .shit dir' '
	echo precious >.shit/my-private-file &&
	echo precious >expect &&
	test_must_fail shit update-ref -d my-private-file >output 2>error &&
	test_must_be_empty output &&
	test_grep -e "refusing to update ref with bad name" error &&
	test_cmp expect .shit/my-private-file
'

test_expect_success 'update-ref -d cannot delete absolute path' '
	shit branch -f extra &&
	test_must_fail shit update-ref -d "$(pwd)/.shit/refs/heads/extra" &&
	test_cmp_rev HEAD extra
'

test_expect_success 'update-ref --stdin fails create with bad ref name' '
	echo "create ~a refs/heads/main" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: invalid ref format: ~a" err
'

test_expect_success 'update-ref --stdin fails update with bad ref name' '
	echo "update ~a refs/heads/main" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: invalid ref format: ~a" err
'

test_expect_success 'update-ref --stdin fails delete with bad ref name' '
	echo "delete ~a refs/heads/main" >stdin &&
	test_must_fail shit update-ref --stdin <stdin 2>err &&
	grep "fatal: invalid ref format: ~a" err
'

test_expect_success 'update-ref --stdin -z fails create with bad ref name' '
	printf "%s\0" "create ~a " refs/heads/main >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: invalid ref format: ~a " err
'

test_expect_success 'update-ref --stdin -z fails update with bad ref name' '
	printf "%s\0" "update ~a" refs/heads/main "" >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: invalid ref format: ~a" err
'

test_expect_success 'update-ref --stdin -z fails delete with bad ref name' '
	printf "%s\0" "delete ~a" refs/heads/main >stdin &&
	test_must_fail shit update-ref -z --stdin <stdin 2>err &&
	grep "fatal: invalid ref format: ~a" err
'

test_expect_success 'branch rejects HEAD as a branch name' '
	test_must_fail shit branch HEAD HEAD^ &&
	test_must_fail shit show-ref refs/heads/HEAD
'

test_expect_success 'checkout -b rejects HEAD as a branch name' '
	test_must_fail shit checkout -B HEAD HEAD^ &&
	test_must_fail shit show-ref refs/heads/HEAD
'

test_expect_success 'update-ref can operate on refs/heads/HEAD' '
	shit update-ref refs/heads/HEAD HEAD^ &&
	shit show-ref refs/heads/HEAD &&
	shit update-ref -d refs/heads/HEAD &&
	test_must_fail shit show-ref refs/heads/HEAD
'

test_expect_success 'branch -d can remove refs/heads/HEAD' '
	shit update-ref refs/heads/HEAD HEAD^ &&
	shit branch -d HEAD &&
	test_must_fail shit show-ref refs/heads/HEAD
'

test_expect_success 'branch -m can rename refs/heads/HEAD' '
	shit update-ref refs/heads/HEAD HEAD^ &&
	shit branch -m HEAD tail &&
	test_must_fail shit show-ref refs/heads/HEAD &&
	shit show-ref refs/heads/tail
'

test_expect_success 'branch -d can remove refs/heads/-dash' '
	shit update-ref refs/heads/-dash HEAD^ &&
	shit branch -d -- -dash &&
	test_must_fail shit show-ref refs/heads/-dash
'

test_expect_success 'branch -m can rename refs/heads/-dash' '
	shit update-ref refs/heads/-dash HEAD^ &&
	shit branch -m -- -dash dash &&
	test_must_fail shit show-ref refs/heads/-dash &&
	shit show-ref refs/heads/dash
'

test_done
