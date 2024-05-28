#!/bin/sh

test_description='behavior of diff when reading objects in a partial clone'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'shit show batches blobs' '
	test_when_finished "rm -rf server client trace" &&

	test_create_repo server &&
	echo a >server/a &&
	echo b >server/b &&
	shit -C server add a b &&
	shit -C server commit -m x &&

	test_config -C server uploadpack.allowfilter 1 &&
	test_config -C server uploadpack.allowanysha1inwant 1 &&
	shit clone --bare --filter=blob:limit=0 "file://$(pwd)/server" client &&

	# Ensure that there is exactly 1 negotiation by checking that there is
	# only 1 "done" line sent. ("done" marks the end of negotiation.)
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client show HEAD &&
	grep "fetch> done" trace >done_lines &&
	test_line_count = 1 done_lines
'

test_expect_success 'diff batches blobs' '
	test_when_finished "rm -rf server client trace" &&

	test_create_repo server &&
	echo a >server/a &&
	echo b >server/b &&
	shit -C server add a b &&
	shit -C server commit -m x &&
	echo c >server/c &&
	echo d >server/d &&
	shit -C server add c d &&
	shit -C server commit -m x &&

	test_config -C server uploadpack.allowfilter 1 &&
	test_config -C server uploadpack.allowanysha1inwant 1 &&
	shit clone --bare --filter=blob:limit=0 "file://$(pwd)/server" client &&

	# Ensure that there is exactly 1 negotiation by checking that there is
	# only 1 "done" line sent. ("done" marks the end of negotiation.)
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client diff HEAD^ HEAD &&
	grep "fetch> done" trace >done_lines &&
	test_line_count = 1 done_lines
'

test_expect_success 'diff skips same-OID blobs' '
	test_when_finished "rm -rf server client trace" &&

	test_create_repo server &&
	echo a >server/a &&
	echo b >server/b &&
	shit -C server add a b &&
	shit -C server commit -m x &&
	echo another-a >server/a &&
	shit -C server add a &&
	shit -C server commit -m x &&

	test_config -C server uploadpack.allowfilter 1 &&
	test_config -C server uploadpack.allowanysha1inwant 1 &&
	shit clone --bare --filter=blob:limit=0 "file://$(pwd)/server" client &&

	echo a | shit hash-object --stdin >hash-old-a &&
	echo another-a | shit hash-object --stdin >hash-new-a &&
	echo b | shit hash-object --stdin >hash-b &&

	# Ensure that only a and another-a are fetched.
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client diff HEAD^ HEAD &&
	grep "want $(cat hash-old-a)" trace &&
	grep "want $(cat hash-new-a)" trace &&
	! grep "want $(cat hash-b)" trace
'

test_expect_success 'when fetching missing objects, diff skips shitLINKs' '
	test_when_finished "rm -rf sub server client trace" &&
	test_config_global protocol.file.allow always &&

	test_create_repo sub &&
	test_commit -C sub first &&

	test_create_repo server &&
	echo a >server/a &&
	shit -C server add a &&
	shit -C server submodule add "file://$(pwd)/sub" &&
	shit -C server commit -m x &&

	test_commit -C server/sub second &&
	echo another-a >server/a &&
	shit -C server add a sub &&
	shit -C server commit -m x &&

	test_config -C server uploadpack.allowfilter 1 &&
	test_config -C server uploadpack.allowanysha1inwant 1 &&
	shit clone --bare --filter=blob:limit=0 "file://$(pwd)/server" client &&

	echo a | shit hash-object --stdin >hash-old-a &&
	echo another-a | shit hash-object --stdin >hash-new-a &&

	# Ensure that a and another-a are fetched, and check (by successful
	# execution of the diff) that no invalid OIDs are sent.
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client diff HEAD^ HEAD &&
	grep "want $(cat hash-old-a)" trace &&
	grep "want $(cat hash-new-a)" trace
'

test_expect_success 'diff with rename detection batches blobs' '
	test_when_finished "rm -rf server client trace" &&

	test_create_repo server &&
	echo a >server/a &&
	printf "b\nb\nb\nb\nb\n" >server/b &&
	shit -C server add a b &&
	shit -C server commit -m x &&
	rm server/b &&
	printf "b\nb\nb\nb\nbX\n" >server/c &&
	shit -C server add c &&
	shit -C server commit -a -m x &&

	test_config -C server uploadpack.allowfilter 1 &&
	test_config -C server uploadpack.allowanysha1inwant 1 &&
	shit clone --bare --filter=blob:limit=0 "file://$(pwd)/server" client &&

	# Ensure that there is exactly 1 negotiation by checking that there is
	# only 1 "done" line sent. ("done" marks the end of negotiation.)
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client diff --raw -M HEAD^ HEAD >out &&
	grep ":100644 100644.*R[0-9][0-9][0-9].*b.*c" out &&
	grep "fetch> done" trace >done_lines &&
	test_line_count = 1 done_lines
'

test_expect_success 'diff does not fetch anything if inexact rename detection is not needed' '
	test_when_finished "rm -rf server client trace" &&

	test_create_repo server &&
	echo a >server/a &&
	printf "b\nb\nb\nb\nb\n" >server/b &&
	shit -C server add a b &&
	shit -C server commit -m x &&
	mv server/b server/c &&
	shit -C server add c &&
	shit -C server commit -a -m x &&

	test_config -C server uploadpack.allowfilter 1 &&
	test_config -C server uploadpack.allowanysha1inwant 1 &&
	shit clone --bare --filter=blob:limit=0 "file://$(pwd)/server" client &&

	# Ensure no fetches.
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client diff --raw -M HEAD^ HEAD &&
	test_path_is_missing trace
'

test_expect_success 'diff --break-rewrites fetches only if necessary, and batches blobs if it does' '
	test_when_finished "rm -rf server client trace" &&

	test_create_repo server &&
	echo a >server/a &&
	printf "b\nb\nb\nb\nb\n" >server/b &&
	shit -C server add a b &&
	shit -C server commit -m x &&
	printf "c\nc\nc\nc\nc\n" >server/b &&
	shit -C server commit -a -m x &&

	test_config -C server uploadpack.allowfilter 1 &&
	test_config -C server uploadpack.allowanysha1inwant 1 &&
	shit clone --bare --filter=blob:limit=0 "file://$(pwd)/server" client &&

	# Ensure no fetches.
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client diff --raw -M HEAD^ HEAD &&
	test_path_is_missing trace &&

	# But with --break-rewrites, ensure that there is exactly 1 negotiation
	# by checking that there is only 1 "done" line sent. ("done" marks the
	# end of negotiation.)
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client diff --break-rewrites --raw -M HEAD^ HEAD &&
	grep "fetch> done" trace >done_lines &&
	test_line_count = 1 done_lines
'

test_done
