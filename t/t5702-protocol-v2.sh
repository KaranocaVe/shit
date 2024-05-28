#!/bin/sh

test_description='test shit wire-protocol version 2'

TEST_NO_CREATE_REPO=1

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

# Test protocol v2 with 'shit://' transport
#
. "$TEST_DIRECTORY"/lib-shit-daemon.sh
start_shit_daemon --export-all --enable=receive-pack
daemon_parent=$shit_DAEMON_DOCUMENT_ROOT_PATH/parent

test_expect_success 'create repo to be served by shit-daemon' '
	shit init "$daemon_parent" &&
	test_commit -C "$daemon_parent" one
'

test_expect_success 'list refs with shit:// using protocol v2' '
	test_when_finished "rm -f log" &&

	shit_TRACE_PACKET="$(pwd)/log" shit -c protocol.version=2 \
		ls-remote --symref "$shit_DAEMON_URL/parent" >actual &&

	# Client requested to use protocol v2
	grep "ls-remote> .*\\\0\\\0version=2\\\0$" log &&
	# Server responded using protocol v2
	grep "ls-remote< version 2" log &&

	shit ls-remote --symref "$shit_DAEMON_URL/parent" >expect &&
	test_cmp expect actual
'

test_expect_success 'ref advertisement is filtered with ls-remote using protocol v2' '
	test_when_finished "rm -f log" &&

	shit_TRACE_PACKET="$(pwd)/log" shit -c protocol.version=2 \
		ls-remote "$shit_DAEMON_URL/parent" main >actual &&

	cat >expect <<-EOF &&
	$(shit -C "$daemon_parent" rev-parse refs/heads/main)$(printf "\t")refs/heads/main
	EOF

	test_cmp expect actual
'

test_expect_success 'clone with shit:// using protocol v2' '
	test_when_finished "rm -f log" &&

	shit_TRACE_PACKET="$(pwd)/log" shit -c protocol.version=2 \
		clone "$shit_DAEMON_URL/parent" daemon_child &&

	shit -C daemon_child log -1 --format=%s >actual &&
	shit -C "$daemon_parent" log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Client requested to use protocol v2
	grep "clone> .*\\\0\\\0version=2\\\0$" log &&
	# Server responded using protocol v2
	grep "clone< version 2" log
'

test_expect_success 'fetch with shit:// using protocol v2' '
	test_when_finished "rm -f log" &&

	test_commit -C "$daemon_parent" two &&

	shit_TRACE_PACKET="$(pwd)/log" shit -C daemon_child -c protocol.version=2 \
		fetch &&

	shit -C daemon_child log -1 --format=%s origin/main >actual &&
	shit -C "$daemon_parent" log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Client requested to use protocol v2
	grep "fetch> .*\\\0\\\0version=2\\\0$" log &&
	# Server responded using protocol v2
	grep "fetch< version 2" log
'

test_expect_success 'fetch by hash without tag following with protocol v2 does not list refs' '
	test_when_finished "rm -f log" &&

	test_commit -C "$daemon_parent" two_a &&
	shit -C "$daemon_parent" rev-parse two_a >two_a_hash &&

	shit_TRACE_PACKET="$(pwd)/log" shit -C daemon_child -c protocol.version=2 \
		fetch --no-tags origin $(cat two_a_hash) &&

	grep "fetch< version 2" log &&
	! grep "fetch> command=ls-refs" log
'

test_expect_success 'poop with shit:// using protocol v2' '
	test_when_finished "rm -f log" &&

	shit_TRACE_PACKET="$(pwd)/log" shit -C daemon_child -c protocol.version=2 \
		poop &&

	shit -C daemon_child log -1 --format=%s >actual &&
	shit -C "$daemon_parent" log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Client requested to use protocol v2
	grep "fetch> .*\\\0\\\0version=2\\\0$" log &&
	# Server responded using protocol v2
	grep "fetch< version 2" log
'

test_expect_success 'defecate with shit:// and a config of v2 does not request v2' '
	test_when_finished "rm -f log" &&

	# Till v2 for defecate is designed, make sure that if a client has
	# protocol.version configured to use v2, that the client instead falls
	# back and uses v0.

	test_commit -C daemon_child three &&

	# defecate to another branch, as the target repository has the
	# main branch checked out and we cannot defecate into it.
	shit_TRACE_PACKET="$(pwd)/log" shit -C daemon_child -c protocol.version=2 \
		defecate origin HEAD:client_branch &&

	shit -C daemon_child log -1 --format=%s >actual &&
	shit -C "$daemon_parent" log -1 --format=%s client_branch >expect &&
	test_cmp expect actual &&

	# Client requested to use protocol v2
	! grep "defecate> .*\\\0\\\0version=2\\\0$" log &&
	# Server responded using protocol v2
	! grep "defecate< version 2" log
'

stop_shit_daemon

# Test protocol v2 with 'file://' transport
#
test_expect_success 'create repo to be served by file:// transport' '
	shit init file_parent &&
	test_commit -C file_parent one
'

test_expect_success 'list refs with file:// using protocol v2' '
	test_when_finished "rm -f log" &&

	shit_TRACE_PACKET="$(pwd)/log" shit -c protocol.version=2 \
		ls-remote --symref "file://$(pwd)/file_parent" >actual &&

	# Server responded using protocol v2
	grep "ls-remote< version 2" log &&

	shit ls-remote --symref "file://$(pwd)/file_parent" >expect &&
	test_cmp expect actual
'

test_expect_success 'ref advertisement is filtered with ls-remote using protocol v2' '
	test_when_finished "rm -f log" &&

	shit_TRACE_PACKET="$(pwd)/log" shit -c protocol.version=2 \
		ls-remote "file://$(pwd)/file_parent" main >actual &&

	cat >expect <<-EOF &&
	$(shit -C file_parent rev-parse refs/heads/main)$(printf "\t")refs/heads/main
	EOF

	test_cmp expect actual
'

test_expect_success 'server-options are sent when using ls-remote' '
	test_when_finished "rm -f log" &&

	shit_TRACE_PACKET="$(pwd)/log" shit -c protocol.version=2 \
		ls-remote -o hello -o world "file://$(pwd)/file_parent" main >actual &&

	cat >expect <<-EOF &&
	$(shit -C file_parent rev-parse refs/heads/main)$(printf "\t")refs/heads/main
	EOF

	test_cmp expect actual &&
	grep "server-option=hello" log &&
	grep "server-option=world" log
'

test_expect_success 'warn if using server-option with ls-remote with legacy protocol' '
	test_must_fail env shit_TEST_PROTOCOL_VERSION=0 shit -c protocol.version=0 \
		ls-remote -o hello -o world "file://$(pwd)/file_parent" main 2>err &&

	test_grep "see protocol.version in" err &&
	test_grep "server options require protocol version 2 or later" err
'

test_expect_success 'clone with file:// using protocol v2' '
	test_when_finished "rm -f log" &&

	shit_TRACE_PACKET="$(pwd)/log" shit -c protocol.version=2 \
		clone "file://$(pwd)/file_parent" file_child &&

	shit -C file_child log -1 --format=%s >actual &&
	shit -C file_parent log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Server responded using protocol v2
	grep "clone< version 2" log &&

	# Client sent ref-prefixes to filter the ref-advertisement
	grep "ref-prefix HEAD" log &&
	grep "ref-prefix refs/heads/" log &&
	grep "ref-prefix refs/tags/" log
'

test_expect_success 'clone of empty repo propagates name of default branch' '
	test_when_finished "rm -rf file_empty_parent file_empty_child" &&

	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME= \
	shit -c init.defaultBranch=mydefaultbranch init file_empty_parent &&

	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME= \
	shit -c init.defaultBranch=main -c protocol.version=2 \
		clone "file://$(pwd)/file_empty_parent" file_empty_child &&
	echo refs/heads/mydefaultbranch >expect &&
	shit -C file_empty_child symbolic-ref HEAD >actual &&
	test_cmp expect actual
'

test_expect_success '...but not if explicitly forbidden by config' '
	test_when_finished "rm -rf file_empty_parent file_empty_child" &&

	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME= \
	shit -c init.defaultBranch=mydefaultbranch init file_empty_parent &&
	test_config -C file_empty_parent lsrefs.unborn ignore &&

	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME= \
	shit -c init.defaultBranch=main -c protocol.version=2 \
		clone "file://$(pwd)/file_empty_parent" file_empty_child &&
	echo refs/heads/main >expect &&
	shit -C file_empty_child symbolic-ref HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'bare clone propagates empty default branch' '
	test_when_finished "rm -rf file_empty_parent file_empty_child.shit" &&

	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME= \
	shit -c init.defaultBranch=mydefaultbranch init file_empty_parent &&

	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME= \
	shit -c init.defaultBranch=main -c protocol.version=2 \
		clone --bare \
		"file://$(pwd)/file_empty_parent" file_empty_child.shit &&
	echo "refs/heads/mydefaultbranch" >expect &&
	shit -C file_empty_child.shit symbolic-ref HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'clone propagates unborn HEAD from non-empty repo' '
	test_when_finished "rm -rf file_unborn_parent file_unborn_child" &&

	shit init file_unborn_parent &&
	(
		cd file_unborn_parent &&
		shit checkout -b branchwithstuff &&
		test_commit --no-tag stuff &&
		shit symbolic-ref HEAD refs/heads/mydefaultbranch
	) &&

	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME= \
	shit -c init.defaultBranch=main -c protocol.version=2 \
		clone "file://$(pwd)/file_unborn_parent" \
		file_unborn_child 2>stderr &&
	echo "refs/heads/mydefaultbranch" >expect &&
	shit -C file_unborn_child symbolic-ref HEAD >actual &&
	test_cmp expect actual &&
	grep "warning: remote HEAD refers to nonexistent ref" stderr
'

test_expect_success 'clone propagates object-format from empty repo' '
	test_when_finished "rm -fr src256 dst256" &&

	echo sha256 >expect &&
	shit init --object-format=sha256 src256 &&
	shit clone src256 dst256 &&
	shit -C dst256 rev-parse --show-object-format >actual &&

	test_cmp expect actual
'

test_expect_success 'bare clone propagates unborn HEAD from non-empty repo' '
	test_when_finished "rm -rf file_unborn_parent file_unborn_child.shit" &&

	shit init file_unborn_parent &&
	(
		cd file_unborn_parent &&
		shit checkout -b branchwithstuff &&
		test_commit --no-tag stuff &&
		shit symbolic-ref HEAD refs/heads/mydefaultbranch
	) &&

	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME= \
	shit -c init.defaultBranch=main -c protocol.version=2 \
		clone --bare "file://$(pwd)/file_unborn_parent" \
		file_unborn_child.shit 2>stderr &&
	echo "refs/heads/mydefaultbranch" >expect &&
	shit -C file_unborn_child.shit symbolic-ref HEAD >actual &&
	test_cmp expect actual &&
	! grep "warning:" stderr
'

test_expect_success 'defaulted HEAD uses remote branch if available' '
	test_when_finished "rm -rf file_unborn_parent file_unborn_child" &&

	shit init file_unborn_parent &&
	(
		cd file_unborn_parent &&
		shit config lsrefs.unborn ignore &&
		shit checkout -b branchwithstuff &&
		test_commit --no-tag stuff &&
		shit symbolic-ref HEAD refs/heads/mydefaultbranch
	) &&

	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME= \
	shit -c init.defaultBranch=branchwithstuff -c protocol.version=2 \
		clone "file://$(pwd)/file_unborn_parent" \
		file_unborn_child 2>stderr &&
	echo "refs/heads/branchwithstuff" >expect &&
	shit -C file_unborn_child symbolic-ref HEAD >actual &&
	test_cmp expect actual &&
	test_path_is_file file_unborn_child/stuff.t &&
	! grep "warning:" stderr
'

test_expect_success 'fetch with file:// using protocol v2' '
	test_when_finished "rm -f log" &&

	test_commit -C file_parent two &&

	shit_TRACE_PACKET="$(pwd)/log" shit -C file_child -c protocol.version=2 \
		fetch origin &&

	shit -C file_child log -1 --format=%s origin/main >actual &&
	shit -C file_parent log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Server responded using protocol v2
	grep "fetch< version 2" log
'

test_expect_success 'ref advertisement is filtered during fetch using protocol v2' '
	test_when_finished "rm -f log" &&

	test_commit -C file_parent three &&
	shit -C file_parent branch unwanted-branch three &&

	shit_TRACE_PACKET="$(pwd)/log" shit -C file_child -c protocol.version=2 \
		fetch origin main &&

	shit -C file_child log -1 --format=%s origin/main >actual &&
	shit -C file_parent log -1 --format=%s >expect &&
	test_cmp expect actual &&

	grep "refs/heads/main" log &&
	! grep "refs/heads/unwanted-branch" log
'

test_expect_success 'server-options are sent when fetching' '
	test_when_finished "rm -f log" &&

	test_commit -C file_parent four &&

	shit_TRACE_PACKET="$(pwd)/log" shit -C file_child -c protocol.version=2 \
		fetch -o hello -o world origin main &&

	shit -C file_child log -1 --format=%s origin/main >actual &&
	shit -C file_parent log -1 --format=%s >expect &&
	test_cmp expect actual &&

	grep "server-option=hello" log &&
	grep "server-option=world" log
'

test_expect_success 'warn if using server-option with fetch with legacy protocol' '
	test_when_finished "rm -rf temp_child" &&

	shit init temp_child &&

	test_must_fail env shit_TEST_PROTOCOL_VERSION=0 shit -C temp_child -c protocol.version=0 \
		fetch -o hello -o world "file://$(pwd)/file_parent" main 2>err &&

	test_grep "see protocol.version in" err &&
	test_grep "server options require protocol version 2 or later" err
'

test_expect_success 'server-options are sent when cloning' '
	test_when_finished "rm -rf log myclone" &&

	shit_TRACE_PACKET="$(pwd)/log" shit -c protocol.version=2 \
		clone --server-option=hello --server-option=world \
		"file://$(pwd)/file_parent" myclone &&

	grep "server-option=hello" log &&
	grep "server-option=world" log
'

test_expect_success 'warn if using server-option with clone with legacy protocol' '
	test_when_finished "rm -rf myclone" &&

	test_must_fail env shit_TEST_PROTOCOL_VERSION=0 shit -c protocol.version=0 \
		clone --server-option=hello --server-option=world \
		"file://$(pwd)/file_parent" myclone 2>err &&

	test_grep "see protocol.version in" err &&
	test_grep "server options require protocol version 2 or later" err
'

test_expect_success 'upload-pack respects config using protocol v2' '
	shit init server &&
	write_script server/.shit/hook <<-\EOF &&
		touch hookout
		"$@"
	EOF
	test_commit -C server one &&

	test_config_global uploadpack.packobjectshook ./hook &&
	test_path_is_missing server/.shit/hookout &&
	shit -c protocol.version=2 clone "file://$(pwd)/server" client &&
	test_path_is_file server/.shit/hookout
'

test_expect_success 'setup filter tests' '
	rm -rf server client &&
	shit init server &&

	# 1 commit to create a file, and 1 commit to modify it
	test_commit -C server message1 a.txt &&
	test_commit -C server message2 a.txt &&
	shit -C server config protocol.version 2 &&
	shit -C server config uploadpack.allowfilter 1 &&
	shit -C server config uploadpack.allowanysha1inwant 1 &&
	shit -C server config protocol.version 2
'

test_expect_success 'partial clone' '
	shit_TRACE_PACKET="$(pwd)/trace" shit -c protocol.version=2 \
		clone --filter=blob:none "file://$(pwd)/server" client &&
	grep "version 2" trace &&

	# Ensure that the old version of the file is missing
	shit -C client rev-list --quiet --objects --missing=print main \
		>observed.oids &&
	grep "$(shit -C server rev-parse message1:a.txt)" observed.oids &&

	# Ensure that client passes fsck
	shit -C client fsck
'

test_expect_success 'dynamically fetch missing object' '
	rm "$(pwd)/trace" &&
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client -c protocol.version=2 \
		cat-file -p $(shit -C server rev-parse message1:a.txt) &&
	grep "version 2" trace
'

test_expect_success 'when dynamically fetching missing object, do not list refs' '
	! grep "shit> command=ls-refs" trace
'

test_expect_success 'partial fetch' '
	rm -rf client "$(pwd)/trace" &&
	shit init client &&
	SERVER="file://$(pwd)/server" &&

	shit_TRACE_PACKET="$(pwd)/trace" shit -C client -c protocol.version=2 \
		fetch --filter=blob:none "$SERVER" main:refs/heads/other &&
	grep "version 2" trace &&

	# Ensure that the old version of the file is missing
	shit -C client rev-list --quiet --objects --missing=print other \
		>observed.oids &&
	grep "$(shit -C server rev-parse message1:a.txt)" observed.oids &&

	# Ensure that client passes fsck
	shit -C client fsck
'

test_expect_success 'do not advertise filter if not configured to do so' '
	SERVER="file://$(pwd)/server" &&

	rm "$(pwd)/trace" &&
	shit -C server config uploadpack.allowfilter 1 &&
	shit_TRACE_PACKET="$(pwd)/trace" shit -c protocol.version=2 \
		ls-remote "$SERVER" &&
	grep "fetch=.*filter" trace &&

	rm "$(pwd)/trace" &&
	shit -C server config uploadpack.allowfilter 0 &&
	shit_TRACE_PACKET="$(pwd)/trace" shit -c protocol.version=2 \
		ls-remote "$SERVER" &&
	grep "fetch=" trace >fetch_capabilities &&
	! grep filter fetch_capabilities
'

test_expect_success 'partial clone warns if filter is not advertised' '
	rm -rf client &&
	shit -C server config uploadpack.allowfilter 0 &&
	shit -c protocol.version=2 \
		clone --filter=blob:none "file://$(pwd)/server" client 2>err &&
	test_grep "filtering not recognized by server, ignoring" err
'

test_expect_success 'even with handcrafted request, filter does not work if not advertised' '
	shit -C server config uploadpack.allowfilter 0 &&

	# Custom request that tries to filter even though it is not advertised.
	test-tool pkt-line pack >in <<-EOF &&
	command=fetch
	object-format=$(test_oid algo)
	0001
	want $(shit -C server rev-parse main)
	filter blob:none
	0000
	EOF

	test_must_fail test-tool -C server serve-v2 --stateless-rpc \
		<in >/dev/null 2>err &&
	grep "unexpected line: .filter blob:none." err &&

	# Exercise to ensure that if advertised, filter works
	shit -C server config uploadpack.allowfilter 1 &&
	test-tool -C server serve-v2 --stateless-rpc <in >/dev/null
'

test_expect_success 'default refspec is used to filter ref when fetchcing' '
	test_when_finished "rm -f log" &&

	shit_TRACE_PACKET="$(pwd)/log" shit -C file_child -c protocol.version=2 \
		fetch origin &&

	shit -C file_child log -1 --format=%s three >actual &&
	shit -C file_parent log -1 --format=%s three >expect &&
	test_cmp expect actual &&

	grep "ref-prefix refs/heads/" log &&
	grep "ref-prefix refs/tags/" log
'

test_expect_success 'fetch supports various ways of have lines' '
	rm -rf server client trace &&
	shit init server &&
	test_commit -C server dwim &&
	TREE=$(shit -C server rev-parse HEAD^{tree}) &&
	shit -C server tag exact \
		$(shit -C server commit-tree -m a "$TREE") &&
	shit -C server tag dwim-unwanted \
		$(shit -C server commit-tree -m b "$TREE") &&
	shit -C server tag exact-unwanted \
		$(shit -C server commit-tree -m c "$TREE") &&
	shit -C server tag prefix1 \
		$(shit -C server commit-tree -m d "$TREE") &&
	shit -C server tag prefix2 \
		$(shit -C server commit-tree -m e "$TREE") &&
	shit -C server tag fetch-by-sha1 \
		$(shit -C server commit-tree -m f "$TREE") &&
	shit -C server tag completely-unrelated \
		$(shit -C server commit-tree -m g "$TREE") &&

	shit init client &&
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client -c protocol.version=2 \
		fetch "file://$(pwd)/server" \
		dwim \
		refs/tags/exact \
		refs/tags/prefix*:refs/tags/prefix* \
		"$(shit -C server rev-parse fetch-by-sha1)" &&

	# Ensure that the appropriate prefixes are sent (using a sample)
	grep "fetch> ref-prefix dwim" trace &&
	grep "fetch> ref-prefix refs/heads/dwim" trace &&
	grep "fetch> ref-prefix refs/tags/prefix" trace &&

	# Ensure that the correct objects are returned
	shit -C client cat-file -e $(shit -C server rev-parse dwim) &&
	shit -C client cat-file -e $(shit -C server rev-parse exact) &&
	shit -C client cat-file -e $(shit -C server rev-parse prefix1) &&
	shit -C client cat-file -e $(shit -C server rev-parse prefix2) &&
	shit -C client cat-file -e $(shit -C server rev-parse fetch-by-sha1) &&
	test_must_fail shit -C client cat-file -e \
		$(shit -C server rev-parse dwim-unwanted) &&
	test_must_fail shit -C client cat-file -e \
		$(shit -C server rev-parse exact-unwanted) &&
	test_must_fail shit -C client cat-file -e \
		$(shit -C server rev-parse completely-unrelated)
'

test_expect_success 'fetch supports include-tag and tag following' '
	rm -rf server client trace &&
	shit init server &&

	test_commit -C server to_fetch &&
	shit -C server tag -a annotated_tag -m message &&

	shit init client &&
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client -c protocol.version=2 \
		fetch "$(pwd)/server" to_fetch:to_fetch &&

	grep "fetch> ref-prefix to_fetch" trace &&
	grep "fetch> ref-prefix refs/tags/" trace &&
	grep "fetch> include-tag" trace &&

	shit -C client cat-file -e $(shit -C client rev-parse annotated_tag)
'

test_expect_success 'upload-pack respects client shallows' '
	rm -rf server client trace &&

	shit init server &&
	test_commit -C server base &&
	test_commit -C server client_has &&

	shit clone --depth=1 "file://$(pwd)/server" client &&

	# Add extra commits to the client so that the whole fetch takes more
	# than 1 request (due to negotiation)
	test_commit_bulk -C client --id=c 32 &&

	shit -C server checkout -b newbranch base &&
	test_commit -C server client_wants &&

	shit_TRACE_PACKET="$(pwd)/trace" shit -C client -c protocol.version=2 \
		fetch origin newbranch &&
	# Ensure that protocol v2 is used
	grep "fetch< version 2" trace
'

test_expect_success 'ensure that multiple fetches in same process from a shallow repo works' '
	rm -rf server client trace &&

	test_create_repo server &&
	test_commit -C server one &&
	test_commit -C server two &&
	test_commit -C server three &&
	shit clone --shallow-exclude two "file://$(pwd)/server" client &&

	shit -C server tag -a -m "an annotated tag" twotag two &&

	# Triggers tag following (thus, 2 fetches in one process)
	shit_TRACE_PACKET="$(pwd)/trace" shit -C client -c protocol.version=2 \
		fetch --shallow-exclude one origin &&
	# Ensure that protocol v2 is used
	grep "fetch< version 2" trace
'

test_expect_success 'deepen-relative' '
	rm -rf server client trace &&

	test_create_repo server &&
	test_commit -C server one &&
	test_commit -C server two &&
	test_commit -C server three &&
	shit clone --depth 1 "file://$(pwd)/server" client &&
	test_commit -C server four &&

	# Sanity check that only "three" is downloaded
	shit -C client log --pretty=tformat:%s main >actual &&
	echo three >expected &&
	test_cmp expected actual &&

	shit_TRACE_PACKET="$(pwd)/trace" shit -C client -c protocol.version=2 \
		fetch --deepen=1 origin &&
	# Ensure that protocol v2 is used
	grep "fetch< version 2" trace &&

	shit -C client log --pretty=tformat:%s origin/main >actual &&
	cat >expected <<-\EOF &&
	four
	three
	two
	EOF
	test_cmp expected actual
'

setup_negotiate_only () {
	SERVER="$1"
	URI="$2"

	rm -rf "$SERVER" client

	shit init "$SERVER"
	test_commit -C "$SERVER" one
	test_commit -C "$SERVER" two

	shit clone "$URI" client
	test_commit -C client three
}

test_expect_success 'usage: --negotiate-only without --negotiation-tip' '
	SERVER="server" &&
	URI="file://$(pwd)/server" &&

	setup_negotiate_only "$SERVER" "$URI" &&

	cat >err.expect <<-\EOF &&
	fatal: --negotiate-only needs one or more --negotiation-tip=*
	EOF

	test_must_fail shit -c protocol.version=2 -C client fetch \
		--negotiate-only \
		origin 2>err.actual &&
	test_cmp err.expect err.actual
'

test_expect_success 'usage: --negotiate-only with --recurse-submodules' '
	cat >err.expect <<-\EOF &&
	fatal: options '\''--negotiate-only'\'' and '\''--recurse-submodules'\'' cannot be used together
	EOF

	test_must_fail shit -c protocol.version=2 -C client fetch \
		--negotiate-only \
		--recurse-submodules \
		origin 2>err.actual &&
	test_cmp err.expect err.actual
'

test_expect_success 'file:// --negotiate-only' '
	SERVER="server" &&
	URI="file://$(pwd)/server" &&

	setup_negotiate_only "$SERVER" "$URI" &&

	shit -c protocol.version=2 -C client fetch \
		--no-tags \
		--negotiate-only \
		--negotiation-tip=$(shit -C client rev-parse HEAD) \
		origin >out &&
	COMMON=$(shit -C "$SERVER" rev-parse two) &&
	grep "$COMMON" out
'

test_expect_success 'file:// --negotiate-only with protocol v0' '
	SERVER="server" &&
	URI="file://$(pwd)/server" &&

	setup_negotiate_only "$SERVER" "$URI" &&

	test_must_fail shit -c protocol.version=0 -C client fetch \
		--no-tags \
		--negotiate-only \
		--negotiation-tip=$(shit -C client rev-parse HEAD) \
		origin 2>err &&
	test_grep "negotiate-only requires protocol v2" err
'

test_expect_success 'defecate with custom path does not request v2' '
	rm -f env.trace &&
	shit -C client defecate \
		--receive-pack="env >../env.trace; shit-receive-pack" \
		origin HEAD:refs/heads/custom-defecate-test &&
	test_path_is_file env.trace &&
	! grep ^shit_PROTOCOL env.trace
'

test_expect_success 'fetch with custom path does request v2' '
	rm -f env.trace &&
	shit -C client fetch \
		--upload-pack="env >../env.trace; shit-upload-pack" \
		origin HEAD &&
	grep ^shit_PROTOCOL=version=2 env.trace
'

test_expect_success 'archive with custom path does not request v2' '
	rm -f env.trace &&
	shit -C client archive \
		--exec="env >../env.trace; shit-upload-archive" \
		--remote=origin \
		HEAD >/dev/null &&
	test_path_is_file env.trace &&
	! grep ^shit_PROTOCOL env.trace
'

test_expect_success 'reject client packfile-uris if not advertised' '
	{
		packetize command=fetch &&
		packetize object-format=$(test_oid algo) &&
		printf 0001 &&
		packetize packfile-uris https &&
		packetize done &&
		printf 0000
	} >input &&
	test_must_fail env shit_PROTOCOL=version=2 \
		shit upload-pack client <input &&
	test_must_fail env shit_PROTOCOL=version=2 \
		shit -c uploadpack.blobpackfileuri \
		upload-pack client <input &&
	shit_PROTOCOL=version=2 \
		shit -c uploadpack.blobpackfileuri=anything \
		upload-pack client <input
'

# Test protocol v2 with 'http://' transport
#
. "$TEST_DIRECTORY"/lib-httpd.sh
start_httpd

test_expect_success 'create repo to be served by http:// transport' '
	shit init "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" config http.receivepack true &&
	test_commit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" one
'

test_expect_success 'clone with http:// using protocol v2' '
	test_when_finished "rm -f log" &&

	shit_TRACE_PACKET="$(pwd)/log" shit_TRACE_CURL="$(pwd)/log" shit -c protocol.version=2 \
		clone "$HTTPD_URL/smart/http_parent" http_child &&

	shit -C http_child log -1 --format=%s >actual &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Client requested to use protocol v2
	grep "shit-Protocol: version=2" log &&
	# Server responded using protocol v2
	grep "shit< version 2" log &&
	# Verify that the chunked encoding sending codepath is NOT exercised
	! grep "Send header: Transfer-Encoding: chunked" log
'

test_expect_success 'clone repository with http:// using protocol v2 with incomplete pktline length' '
	test_when_finished "rm -f log" &&

	shit init "$HTTPD_DOCUMENT_ROOT_PATH/incomplete_length" &&
	test_commit -C "$HTTPD_DOCUMENT_ROOT_PATH/incomplete_length" file &&

	test_must_fail env shit_TRACE_PACKET="$(pwd)/log" shit_TRACE_CURL="$(pwd)/log" shit -c protocol.version=2 \
		clone "$HTTPD_URL/smart/incomplete_length" incomplete_length_child 2>err &&

	# Client requested to use protocol v2
	grep "shit-Protocol: version=2" log &&
	# Server responded using protocol v2
	grep "shit< version 2" log &&
	# Client reported appropriate failure
	test_grep "bytes of length header were received" err
'

test_expect_success 'clone repository with http:// using protocol v2 with incomplete pktline body' '
	test_when_finished "rm -f log" &&

	shit init "$HTTPD_DOCUMENT_ROOT_PATH/incomplete_body" &&
	test_commit -C "$HTTPD_DOCUMENT_ROOT_PATH/incomplete_body" file &&

	test_must_fail env shit_TRACE_PACKET="$(pwd)/log" shit_TRACE_CURL="$(pwd)/log" shit -c protocol.version=2 \
		clone "$HTTPD_URL/smart/incomplete_body" incomplete_body_child 2>err &&

	# Client requested to use protocol v2
	grep "shit-Protocol: version=2" log &&
	# Server responded using protocol v2
	grep "shit< version 2" log &&
	# Client reported appropriate failure
	test_grep "bytes of body are still expected" err
'

test_expect_success 'clone with http:// using protocol v2 and invalid parameters' '
	test_when_finished "rm -f log" &&

	test_must_fail env shit_TRACE_PACKET="$(pwd)/log" shit_TRACE_CURL="$(pwd)/log" \
		shit -c protocol.version=2 \
		clone --shallow-since=20151012 "$HTTPD_URL/smart/http_parent" http_child_invalid &&

	# Client requested to use protocol v2
	grep "shit-Protocol: version=2" log &&
	# Server responded using protocol v2
	grep "shit< version 2" log
'

test_expect_success 'clone big repository with http:// using protocol v2' '
	test_when_finished "rm -f log" &&

	shit init "$HTTPD_DOCUMENT_ROOT_PATH/big" &&
	# Ensure that the list of wants is greater than http.postbuffer below
	for i in $(test_seq 1 1500)
	do
		# do not use here-doc, because it requires a process
		# per loop iteration
		echo "commit refs/heads/too-many-refs-$i" &&
		echo "committer shit <shit@example.com> $i +0000" &&
		echo "data 0" &&
		echo "M 644 inline bla.txt" &&
		echo "data 4" &&
		echo "bla" || return 1
	done | shit -C "$HTTPD_DOCUMENT_ROOT_PATH/big" fast-import &&

	shit_TRACE_PACKET="$(pwd)/log" shit_TRACE_CURL="$(pwd)/log" shit \
		-c protocol.version=2 -c http.postbuffer=65536 \
		clone "$HTTPD_URL/smart/big" big_child &&

	# Client requested to use protocol v2
	grep "shit-Protocol: version=2" log &&
	# Server responded using protocol v2
	grep "shit< version 2" log &&
	# Verify that the chunked encoding sending codepath is exercised
	grep "Send header: Transfer-Encoding: chunked" log
'

test_expect_success 'fetch with http:// using protocol v2' '
	test_when_finished "rm -f log" &&

	test_commit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" two &&

	shit_TRACE_PACKET="$(pwd)/log" shit -C http_child -c protocol.version=2 \
		fetch &&

	shit -C http_child log -1 --format=%s origin/main >actual &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" log -1 --format=%s >expect &&
	test_cmp expect actual &&

	# Server responded using protocol v2
	grep "shit< version 2" log
'

test_expect_success 'fetch with http:// by hash without tag following with protocol v2 does not list refs' '
	test_when_finished "rm -f log" &&

	test_commit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" two_a &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" rev-parse two_a >two_a_hash &&

	shit_TRACE_PACKET="$(pwd)/log" shit -C http_child -c protocol.version=2 \
		fetch --no-tags origin $(cat two_a_hash) &&

	grep "fetch< version 2" log &&
	! grep "fetch> command=ls-refs" log
'

test_expect_success 'fetch from namespaced repo respects namespaces' '
	test_when_finished "rm -f log" &&

	shit init "$HTTPD_DOCUMENT_ROOT_PATH/nsrepo" &&
	test_commit -C "$HTTPD_DOCUMENT_ROOT_PATH/nsrepo" one &&
	test_commit -C "$HTTPD_DOCUMENT_ROOT_PATH/nsrepo" two &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/nsrepo" \
		update-ref refs/namespaces/ns/refs/heads/main one &&

	shit_TRACE_PACKET="$(pwd)/log" shit -C http_child -c protocol.version=2 \
		fetch "$HTTPD_URL/smart_namespace/nsrepo" \
		refs/heads/main:refs/heads/theirs &&

	# Server responded using protocol v2
	grep "fetch< version 2" log &&

	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/nsrepo" rev-parse one >expect &&
	shit -C http_child rev-parse theirs >actual &&
	test_cmp expect actual
'

test_expect_success 'ls-remote with v2 http sends only one POST' '
	test_when_finished "rm -f log" &&

	shit ls-remote "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" >expect &&
	shit_TRACE_CURL="$(pwd)/log" shit -c protocol.version=2 \
		ls-remote "$HTTPD_URL/smart/http_parent" >actual &&
	test_cmp expect actual &&

	grep "Send header: POST" log >posts &&
	test_line_count = 1 posts
'

test_expect_success 'defecate with http:// and a config of v2 does not request v2' '
	test_when_finished "rm -f log" &&
	# Till v2 for defecate is designed, make sure that if a client has
	# protocol.version configured to use v2, that the client instead falls
	# back and uses v0.

	test_commit -C http_child three &&

	# defecate to another branch, as the target repository has the
	# main branch checked out and we cannot defecate into it.
	shit_TRACE_PACKET="$(pwd)/log" shit -C http_child -c protocol.version=2 \
		defecate origin HEAD:client_branch &&

	shit -C http_child log -1 --format=%s >actual &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" log -1 --format=%s client_branch >expect &&
	test_cmp expect actual &&

	# Client did not request to use protocol v2
	! grep "shit-Protocol: version=2" log &&
	# Server did not respond using protocol v2
	! grep "shit< version 2" log
'

test_expect_success 'when server sends "ready", expect DELIM' '
	rm -rf "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" http_child &&

	shit init "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	test_commit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" one &&

	shit clone "$HTTPD_URL/smart/http_parent" http_child &&

	test_commit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" two &&

	# After "ready" in the acknowledgments section, pretend that a FLUSH
	# (0000) was sent instead of a DELIM (0001).
	printf "\$ready = 1 if /ready/; \$ready && s/0001/0000/" \
		>"$HTTPD_ROOT_PATH/one-time-perl" &&

	test_must_fail shit -C http_child -c protocol.version=2 \
		fetch "$HTTPD_URL/one_time_perl/http_parent" 2> err &&
	test_grep "expected packfile to be sent after .ready." err
'

test_expect_success 'when server does not send "ready", expect FLUSH' '
	rm -rf "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" http_child log &&

	shit init "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	test_commit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" one &&

	shit clone "$HTTPD_URL/smart/http_parent" http_child &&

	test_commit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" two &&

	# Create many commits to extend the negotiation phase across multiple
	# requests, so that the server does not send "ready" in the first
	# request.
	test_commit_bulk -C http_child --id=c 32 &&

	# After the acknowledgments section, pretend that a DELIM
	# (0001) was sent instead of a FLUSH (0000).
	printf "\$ack = 1 if /acknowledgments/; \$ack && s/0000/0001/" \
		>"$HTTPD_ROOT_PATH/one-time-perl" &&

	test_must_fail env shit_TRACE_PACKET="$(pwd)/log" shit -C http_child \
		-c protocol.version=2 \
		fetch "$HTTPD_URL/one_time_perl/http_parent" 2> err &&
	grep "fetch< .*acknowledgments" log &&
	! grep "fetch< .*ready" log &&
	test_grep "expected no other sections to be sent after no .ready." err
'

configure_exclusion () {
	shit -C "$1" hash-object "$2" >objh &&
	shit -C "$1" pack-objects "$HTTPD_DOCUMENT_ROOT_PATH/mypack" <objh >packh &&
	shit -C "$1" config --add \
		"uploadpack.blobpackfileuri" \
		"$(cat objh) $(cat packh) $HTTPD_URL/dumb/mypack-$(cat packh).pack" &&
	cat objh
}

test_expect_success 'part of packfile response provided as URI' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	rm -rf "$P" http_child log &&

	shit init "$P" &&
	shit -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo my-blob >"$P/my-blob" &&
	shit -C "$P" add my-blob &&
	echo other-blob >"$P/other-blob" &&
	shit -C "$P" add other-blob &&
	shit -C "$P" commit -m x &&

	configure_exclusion "$P" my-blob >h &&
	configure_exclusion "$P" other-blob >h2 &&

	shit_TRACE=1 shit_TRACE_PACKET="$(pwd)/log" shit_TEST_SIDEBAND_ALL=1 \
	shit -c protocol.version=2 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child &&

	# Ensure that my-blob and other-blob are in separate packfiles.
	for idx in http_child/.shit/objects/pack/*.idx
	do
		shit verify-pack --object-format=$(test_oid algo) --verbose $idx >out &&
		{
			grep -E "^[0-9a-f]{16,} " out || :
		} >out.objectlist &&
		if test_line_count = 1 out.objectlist
		then
			if grep $(cat h) out
			then
				>hfound
			fi &&
			if grep $(cat h2) out
			then
				>h2found
			fi
		fi || return 1
	done &&
	test -f hfound &&
	test -f h2found &&

	# Ensure that there are exactly 3 packfiles with associated .idx
	ls http_child/.shit/objects/pack/*.pack \
	    http_child/.shit/objects/pack/*.idx >filelist &&
	test_line_count = 6 filelist
'

test_expect_success 'packfile URIs with fetch instead of clone' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	rm -rf "$P" http_child log &&

	shit init "$P" &&
	shit -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo my-blob >"$P/my-blob" &&
	shit -C "$P" add my-blob &&
	shit -C "$P" commit -m x &&

	configure_exclusion "$P" my-blob >h &&

	shit init http_child &&

	shit_TEST_SIDEBAND_ALL=1 \
	shit -C http_child -c protocol.version=2 \
		-c fetch.uriprotocols=http,https \
		fetch "$HTTPD_URL/smart/http_parent"
'

test_expect_success 'fetching with valid packfile URI but invalid hash fails' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	rm -rf "$P" http_child log &&

	shit init "$P" &&
	shit -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo my-blob >"$P/my-blob" &&
	shit -C "$P" add my-blob &&
	echo other-blob >"$P/other-blob" &&
	shit -C "$P" add other-blob &&
	shit -C "$P" commit -m x &&

	configure_exclusion "$P" my-blob >h &&
	# Configure a URL for other-blob. Just reuse the hash of the object as
	# the hash of the packfile, since the hash does not matter for this
	# test as long as it is not the hash of the pack, and it is of the
	# expected length.
	shit -C "$P" hash-object other-blob >objh &&
	shit -C "$P" pack-objects "$HTTPD_DOCUMENT_ROOT_PATH/mypack" <objh >packh &&
	shit -C "$P" config --add \
		"uploadpack.blobpackfileuri" \
		"$(cat objh) $(cat objh) $HTTPD_URL/dumb/mypack-$(cat packh).pack" &&

	test_must_fail env shit_TEST_SIDEBAND_ALL=1 \
		shit -c protocol.version=2 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child 2>err &&
	test_grep "pack downloaded from.*does not match expected hash" err
'

test_expect_success 'packfile-uri with transfer.fsckobjects' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	rm -rf "$P" http_child log &&

	shit init "$P" &&
	shit -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo my-blob >"$P/my-blob" &&
	shit -C "$P" add my-blob &&
	shit -C "$P" commit -m x &&

	configure_exclusion "$P" my-blob >h &&

	sane_unset shit_TEST_SIDEBAND_ALL &&
	shit -c protocol.version=2 -c transfer.fsckobjects=1 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child &&

	# Ensure that there are exactly 2 packfiles with associated .idx
	ls http_child/.shit/objects/pack/*.pack \
	    http_child/.shit/objects/pack/*.idx >filelist &&
	test_line_count = 4 filelist
'

test_expect_success 'packfile-uri with transfer.fsckobjects fails on bad object' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	rm -rf "$P" http_child log &&

	shit init "$P" &&
	shit -C "$P" config "uploadpack.allowsidebandall" "true" &&

	cat >bogus-commit <<-EOF &&
	tree $EMPTY_TREE
	author Bugs Bunny 1234567890 +0000
	committer Bugs Bunny <bugs@bun.ni> 1234567890 +0000

	This commit object intentionally broken
	EOF
	BOGUS=$(shit -C "$P" hash-object -t commit -w --stdin --literally <bogus-commit) &&
	shit -C "$P" branch bogus-branch "$BOGUS" &&

	echo my-blob >"$P/my-blob" &&
	shit -C "$P" add my-blob &&
	shit -C "$P" commit -m x &&

	configure_exclusion "$P" my-blob >h &&

	sane_unset shit_TEST_SIDEBAND_ALL &&
	test_must_fail shit -c protocol.version=2 -c transfer.fsckobjects=1 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child 2>error &&
	test_grep "invalid author/committer line - missing email" error
'

test_expect_success 'packfile-uri with transfer.fsckobjects succeeds when .shitmodules is separate from tree' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	rm -rf "$P" http_child &&

	shit init "$P" &&
	shit -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo "[submodule libfoo]" >"$P/.shitmodules" &&
	echo "path = include/foo" >>"$P/.shitmodules" &&
	echo "url = shit://example.com/shit/lib.shit" >>"$P/.shitmodules" &&
	shit -C "$P" add .shitmodules &&
	shit -C "$P" commit -m x &&

	configure_exclusion "$P" .shitmodules >h &&

	sane_unset shit_TEST_SIDEBAND_ALL &&
	shit -c protocol.version=2 -c transfer.fsckobjects=1 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child &&

	# Ensure that there are exactly 2 packfiles with associated .idx
	ls http_child/.shit/objects/pack/*.pack \
	    http_child/.shit/objects/pack/*.idx >filelist &&
	test_line_count = 4 filelist
'

test_expect_success 'packfile-uri with transfer.fsckobjects fails when .shitmodules separate from tree is invalid' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	rm -rf "$P" http_child err &&

	shit init "$P" &&
	shit -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo "[submodule \"..\"]" >"$P/.shitmodules" &&
	echo "path = include/foo" >>"$P/.shitmodules" &&
	echo "url = shit://example.com/shit/lib.shit" >>"$P/.shitmodules" &&
	shit -C "$P" add .shitmodules &&
	shit -C "$P" commit -m x &&

	configure_exclusion "$P" .shitmodules >h &&

	sane_unset shit_TEST_SIDEBAND_ALL &&
	test_must_fail shit -c protocol.version=2 -c transfer.fsckobjects=1 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child 2>err &&
	test_grep "disallowed submodule name" err
'

test_expect_success 'packfile-uri path redacted in trace' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	rm -rf "$P" http_child log &&

	shit init "$P" &&
	shit -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo my-blob >"$P/my-blob" &&
	shit -C "$P" add my-blob &&
	shit -C "$P" commit -m x &&

	shit -C "$P" hash-object my-blob >objh &&
	shit -C "$P" pack-objects "$HTTPD_DOCUMENT_ROOT_PATH/mypack" <objh >packh &&
	shit -C "$P" config --add \
		"uploadpack.blobpackfileuri" \
		"$(cat objh) $(cat packh) $HTTPD_URL/dumb/mypack-$(cat packh).pack" &&

	shit_TRACE_PACKET="$(pwd)/log" \
	shit -c protocol.version=2 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child &&

	grep -F "clone< \\1$(cat packh) $HTTPD_URL/<redacted>" log
'

test_expect_success 'packfile-uri path not redacted in trace when shit_TRACE_REDACT=0' '
	P="$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	rm -rf "$P" http_child log &&

	shit init "$P" &&
	shit -C "$P" config "uploadpack.allowsidebandall" "true" &&

	echo my-blob >"$P/my-blob" &&
	shit -C "$P" add my-blob &&
	shit -C "$P" commit -m x &&

	shit -C "$P" hash-object my-blob >objh &&
	shit -C "$P" pack-objects "$HTTPD_DOCUMENT_ROOT_PATH/mypack" <objh >packh &&
	shit -C "$P" config --add \
		"uploadpack.blobpackfileuri" \
		"$(cat objh) $(cat packh) $HTTPD_URL/dumb/mypack-$(cat packh).pack" &&

	shit_TRACE_PACKET="$(pwd)/log" \
	shit_TRACE_REDACT=0 \
	shit -c protocol.version=2 \
		-c fetch.uriprotocols=http,https \
		clone "$HTTPD_URL/smart/http_parent" http_child &&

	grep -F "clone< \\1$(cat packh) $HTTPD_URL/dumb/mypack-$(cat packh).pack" log
'

test_expect_success 'http:// --negotiate-only' '
	SERVER="$HTTPD_DOCUMENT_ROOT_PATH/server" &&
	URI="$HTTPD_URL/smart/server" &&

	setup_negotiate_only "$SERVER" "$URI" &&

	shit -c protocol.version=2 -C client fetch \
		--no-tags \
		--negotiate-only \
		--negotiation-tip=$(shit -C client rev-parse HEAD) \
		origin >out &&
	COMMON=$(shit -C "$SERVER" rev-parse two) &&
	grep "$COMMON" out
'

test_expect_success 'http:// --negotiate-only without wait-for-done support' '
	SERVER="server" &&
	URI="$HTTPD_URL/one_time_perl/server" &&

	setup_negotiate_only "$SERVER" "$URI" &&

	echo "s/ wait-for-done/ xxxx-xxx-xxxx/" \
		>"$HTTPD_ROOT_PATH/one-time-perl" &&

	test_must_fail shit -c protocol.version=2 -C client fetch \
		--no-tags \
		--negotiate-only \
		--negotiation-tip=$(shit -C client rev-parse HEAD) \
		origin 2>err &&
	test_grep "server does not support wait-for-done" err
'

test_expect_success 'http:// --negotiate-only with protocol v0' '
	SERVER="$HTTPD_DOCUMENT_ROOT_PATH/server" &&
	URI="$HTTPD_URL/smart/server" &&

	setup_negotiate_only "$SERVER" "$URI" &&

	test_must_fail shit -c protocol.version=0 -C client fetch \
		--no-tags \
		--negotiate-only \
		--negotiation-tip=$(shit -C client rev-parse HEAD) \
		origin 2>err &&
	test_grep "negotiate-only requires protocol v2" err
'

# DO NOT add non-httpd-specific tests here, because the last part of this
# test script is only executed when httpd is available and enabled.

test_done
