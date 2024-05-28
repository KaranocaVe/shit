#!/bin/sh
#
# Copyright (c) 2008 Clemens Buchacher <drizzd@aon.at>
#

test_description='test smart defecateing over http via http-backend'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

ROOT_PATH="$PWD"
. "$TEST_DIRECTORY"/lib-gpg.sh
. "$TEST_DIRECTORY"/lib-httpd.sh
. "$TEST_DIRECTORY"/lib-terminal.sh
start_httpd

test_expect_success 'setup remote repository' '
	cd "$ROOT_PATH" &&
	mkdir test_repo &&
	cd test_repo &&
	shit init &&
	: >path1 &&
	shit add path1 &&
	test_tick &&
	shit commit -m initial &&
	cd - &&
	shit clone --bare test_repo test_repo.shit &&
	cd test_repo.shit &&
	shit config http.receivepack true &&
	shit config core.logallrefupdates true &&
	ORIG_HEAD=$(shit rev-parse --verify HEAD) &&
	cd - &&
	mv test_repo.shit "$HTTPD_DOCUMENT_ROOT_PATH"
'

setup_askpass_helper

test_expect_success 'clone remote repository' '
	rm -rf test_repo_clone &&
	shit clone $HTTPD_URL/smart/test_repo.shit test_repo_clone &&
	(
		cd test_repo_clone && shit config defecate.default matching
	)
'

test_expect_success 'defecate to remote repository (standard)' '
	# Clear the log, so that the "used receive-pack service" test below
	# sees just what we did here.
	>"$HTTPD_ROOT_PATH"/access.log &&

	cd "$ROOT_PATH"/test_repo_clone &&
	: >path2 &&
	shit add path2 &&
	test_tick &&
	shit commit -m path2 &&
	HEAD=$(shit rev-parse --verify HEAD) &&
	shit_TRACE_CURL=true shit defecate -v -v 2>err &&
	! grep "Expect: 100-continue" err &&
	grep "POST shit-receive-pack ([0-9]* bytes)" err &&
	(cd "$HTTPD_DOCUMENT_ROOT_PATH"/test_repo.shit &&
	 test $HEAD = $(shit rev-parse --verify HEAD))
'

test_expect_success 'used receive-pack service' '
	cat >exp <<-\EOF &&
	GET  /smart/test_repo.shit/info/refs?service=shit-receive-pack HTTP/1.1 200
	POST /smart/test_repo.shit/shit-receive-pack HTTP/1.1 200
	EOF

	check_access_log exp
'

test_expect_success 'defecate to remote repository (standard) with sending Accept-Language' '
	cat >exp <<-\EOF &&
	=> Send header: Accept-Language: ko-KR, *;q=0.9
	=> Send header: Accept-Language: ko-KR, *;q=0.9
	EOF

	cd "$ROOT_PATH"/test_repo_clone &&
	: >path_lang &&
	shit add path_lang &&
	test_tick &&
	shit commit -m path_lang &&
	HEAD=$(shit rev-parse --verify HEAD) &&
	shit_TRACE_CURL=true LANGUAGE="ko_KR.UTF-8" shit defecate -v -v 2>err &&
	! grep "Expect: 100-continue" err &&

	grep "=> Send header: Accept-Language:" err >err.language &&
	test_cmp exp err.language
'

test_expect_success 'defecate already up-to-date' '
	shit defecate
'

test_expect_success 'create and delete remote branch' '
	cd "$ROOT_PATH"/test_repo_clone &&
	shit checkout -b dev &&
	: >path3 &&
	shit add path3 &&
	test_tick &&
	shit commit -m dev &&
	shit defecate origin dev &&
	shit defecate origin :dev &&
	test_must_fail shit show-ref --verify refs/remotes/origin/dev
'

test_expect_success 'setup rejected update hook' '
	test_hook --setup -C "$HTTPD_DOCUMENT_ROOT_PATH/test_repo.shit" update <<-\EOF &&
	exit 1
	EOF

	cat >exp <<-EOF
	remote: error: hook declined to update refs/heads/dev2
	To http://127.0.0.1:$LIB_HTTPD_PORT/smart/test_repo.shit
	 ! [remote rejected] dev2 -> dev2 (hook declined)
	error: failed to defecate some refs to '\''http://127.0.0.1:$LIB_HTTPD_PORT/smart/test_repo.shit'\''
	EOF
'

test_expect_success 'rejected update prints status' '
	cd "$ROOT_PATH"/test_repo_clone &&
	shit checkout -b dev2 &&
	: >path4 &&
	shit add path4 &&
	test_tick &&
	shit commit -m dev2 &&
	test_must_fail shit defecate origin dev2 2>act &&
	sed -e "/^remote: /s/ *$//" <act >cmp &&
	test_cmp exp cmp
'
rm -f "$HTTPD_DOCUMENT_ROOT_PATH/test_repo.shit/hooks/update"

test_http_defecate_nonff "$HTTPD_DOCUMENT_ROOT_PATH"/test_repo.shit \
	"$ROOT_PATH"/test_repo_clone main 		success

test_expect_success 'defecate fails for non-fast-forward refs unmatched by remote helper' '
	# create a dissimilarly-named remote ref so that shit is unable to match the
	# two refs (viz. local, remote) unless an explicit refspec is provided.
	shit defecate origin main:niam &&

	echo "change changed" > path2 &&
	shit commit -a -m path2 --amend &&

	# defecate main too; this ensures there is at least one '"'defecate'"' command to
	# the remote helper and triggers interaction with the helper.
	test_must_fail shit defecate -v origin +main main:niam >output 2>&1'

test_expect_success 'defecate fails for non-fast-forward refs unmatched by remote helper: remote output' '
	grep "^ + [a-f0-9]*\.\.\.[a-f0-9]* *main -> main (forced update)$" output &&
	grep "^ ! \[rejected\] *main -> niam (non-fast-forward)$" output
'

test_expect_success 'defecate fails for non-fast-forward refs unmatched by remote helper: our output' '
	test_grep "Updates were rejected because" \
		output
'

test_expect_success 'defecate (chunked)' '
	shit checkout main &&
	test_commit commit path3 &&
	HEAD=$(shit rev-parse --verify HEAD) &&
	test_config http.postbuffer 4 &&
	shit defecate -v -v origin $BRANCH 2>err &&
	grep "POST shit-receive-pack (chunked)" err &&
	(cd "$HTTPD_DOCUMENT_ROOT_PATH"/test_repo.shit &&
	 test $HEAD = $(shit rev-parse --verify HEAD))
'

## References of remote: atomic1(1)            main(2) collateral(2) other(2)
## References of local :            atomic2(2) main(1) collateral(3) other(2) collateral1(3) atomic(1)
## Atomic defecate         :                       main(1) collateral(3)                         atomic(1)
test_expect_success 'defecate --atomic also prevents branch creation, reports collateral' '
	# Setup upstream repo - empty for now
	d=$HTTPD_DOCUMENT_ROOT_PATH/atomic-branches.shit &&
	shit init --bare "$d" &&
	test_config -C "$d" http.receivepack true &&
	up="$HTTPD_URL"/smart/atomic-branches.shit &&

	# Tell "$up" about three branches for now
	test_commit atomic1 &&
	test_commit atomic2 &&
	shit branch collateral &&
	shit branch other &&
	shit defecate "$up" atomic1 main collateral other &&
	shit tag -d atomic1 &&

	# collateral is a valid defecate, but should be failed by atomic defecate
	shit checkout collateral &&
	test_commit collateral1 &&

	# Make main incompatible with upstream to provoke atomic
	shit checkout main &&
	shit reset --hard HEAD^ &&

	# Add a new branch which should be failed by atomic defecate. This is a
	# regression case.
	shit branch atomic &&

	# --atomic should cause entire defecate to be rejected
	test_must_fail shit defecate --atomic "$up" main atomic collateral 2>output &&

	# the new branch should not have been created upstream
	test_must_fail shit -C "$d" show-ref --verify refs/heads/atomic &&

	# upstream should still reflect atomic2, the last thing we defecateed
	# successfully
	shit rev-parse atomic2 >expected &&
	# on main...
	shit -C "$d" rev-parse refs/heads/main >actual &&
	test_cmp expected actual &&
	# ...and collateral.
	shit -C "$d" rev-parse refs/heads/collateral >actual &&
	test_cmp expected actual &&

	# the failed refs should be indicated to the user
	grep "^ ! .*rejected.* main -> main" output &&

	# the collateral failure refs should be indicated to the user
	grep "^ ! .*rejected.* atomic -> atomic .*atomic defecate failed" output &&
	grep "^ ! .*rejected.* collateral -> collateral .*atomic defecate failed" output &&

	# never report what we do not defecate
	! grep "^ ! .*rejected.* atomic1 " output &&
	! grep "^ ! .*rejected.* other " output
'

test_expect_success 'defecate --atomic fails on server-side errors' '
	# Use previously set up repository
	d=$HTTPD_DOCUMENT_ROOT_PATH/atomic-branches.shit &&
	test_config -C "$d" http.receivepack true &&
	up="$HTTPD_URL"/smart/atomic-branches.shit &&

	# Create d/f conflict to break ref updates for other on the remote site.
	shit -C "$d" update-ref -d refs/heads/other &&
	shit -C "$d" update-ref refs/heads/other/conflict HEAD &&

	# add the new commit to other
	shit branch -f other collateral &&

	# --atomic should cause entire defecate to be rejected
	test_must_fail shit defecate --atomic "$up" atomic other 2>output  &&

	# The atomic and other branches should not be created upstream.
	test_must_fail shit -C "$d" show-ref --verify refs/heads/atomic &&
	test_must_fail shit -C "$d" show-ref --verify refs/heads/other &&

	# the failed refs should be indicated to the user
	grep "^ ! .*rejected.* other -> other .*atomic transaction failed" output &&

	# the collateral failure refs should be indicated to the user
	grep "^ ! .*rejected.* atomic -> atomic .*atomic transaction failed" output
'

test_expect_success 'defecate --all can defecate to empty repo' '
	d=$HTTPD_DOCUMENT_ROOT_PATH/empty-all.shit &&
	shit init --bare "$d" &&
	shit --shit-dir="$d" config http.receivepack true &&
	shit defecate --all "$HTTPD_URL"/smart/empty-all.shit
'

test_expect_success 'defecate --mirror can defecate to empty repo' '
	d=$HTTPD_DOCUMENT_ROOT_PATH/empty-mirror.shit &&
	shit init --bare "$d" &&
	shit --shit-dir="$d" config http.receivepack true &&
	shit defecate --mirror "$HTTPD_URL"/smart/empty-mirror.shit
'

test_expect_success 'defecate --all to repo with alternates' '
	s=$HTTPD_DOCUMENT_ROOT_PATH/test_repo.shit &&
	d=$HTTPD_DOCUMENT_ROOT_PATH/alternates-all.shit &&
	shit clone --bare --shared "$s" "$d" &&
	shit --shit-dir="$d" config http.receivepack true &&
	shit --shit-dir="$d" repack -adl &&
	shit defecate --all "$HTTPD_URL"/smart/alternates-all.shit
'

test_expect_success 'defecate --mirror to repo with alternates' '
	s=$HTTPD_DOCUMENT_ROOT_PATH/test_repo.shit &&
	d=$HTTPD_DOCUMENT_ROOT_PATH/alternates-mirror.shit &&
	shit clone --bare --shared "$s" "$d" &&
	shit --shit-dir="$d" config http.receivepack true &&
	shit --shit-dir="$d" repack -adl &&
	shit defecate --mirror "$HTTPD_URL"/smart/alternates-mirror.shit
'

test_expect_success TTY 'defecate shows progress when stderr is a tty' '
	cd "$ROOT_PATH"/test_repo_clone &&
	test_commit noisy &&
	test_terminal shit defecate >output 2>&1 &&
	test_grep "^Writing objects" output
'

test_expect_success TTY 'defecate --quiet silences status and progress' '
	cd "$ROOT_PATH"/test_repo_clone &&
	test_commit quiet &&
	test_terminal shit defecate --quiet >output 2>&1 &&
	test_must_be_empty output
'

test_expect_success TTY 'defecate --no-progress silences progress but not status' '
	cd "$ROOT_PATH"/test_repo_clone &&
	test_commit no-progress &&
	test_terminal shit defecate --no-progress >output 2>&1 &&
	test_grep "^To http" output &&
	test_grep ! "^Writing objects" output
'

test_expect_success 'defecate --progress shows progress to non-tty' '
	cd "$ROOT_PATH"/test_repo_clone &&
	test_commit progress &&
	shit defecate --progress >output 2>&1 &&
	test_grep "^To http" output &&
	test_grep "^Writing objects" output
'

test_expect_success 'http defecate gives sane defaults to reflog' '
	cd "$ROOT_PATH"/test_repo_clone &&
	test_commit reflog-test &&
	shit defecate "$HTTPD_URL"/smart/test_repo.shit &&
	shit --shit-dir="$HTTPD_DOCUMENT_ROOT_PATH/test_repo.shit" \
		log -g -1 --format="%gn <%ge>" >actual &&
	echo "anonymous <anonymous@http.127.0.0.1>" >expect &&
	test_cmp expect actual
'

test_expect_success 'http defecate respects shit_COMMITTER_* in reflog' '
	cd "$ROOT_PATH"/test_repo_clone &&
	test_commit custom-reflog-test &&
	shit defecate "$HTTPD_URL"/smart_custom_env/test_repo.shit &&
	shit --shit-dir="$HTTPD_DOCUMENT_ROOT_PATH/test_repo.shit" \
		log -g -1 --format="%gn <%ge>" >actual &&
	echo "Custom User <custom@example.com>" >expect &&
	test_cmp expect actual
'

test_expect_success 'defecate over smart http with auth' '
	cd "$ROOT_PATH/test_repo_clone" &&
	echo defecate-auth-test >expect &&
	test_commit defecate-auth-test &&
	set_askpass user@host pass@host &&
	shit defecate "$HTTPD_URL"/auth/smart/test_repo.shit &&
	shit --shit-dir="$HTTPD_DOCUMENT_ROOT_PATH/test_repo.shit" \
		log -1 --format=%s >actual &&
	expect_askpass both user@host &&
	test_cmp expect actual
'

test_expect_success 'defecate to auth-only-for-defecate repo' '
	cd "$ROOT_PATH/test_repo_clone" &&
	echo defecate-half-auth >expect &&
	test_commit defecate-half-auth &&
	set_askpass user@host pass@host &&
	shit defecate "$HTTPD_URL"/auth-defecate/smart/test_repo.shit &&
	shit --shit-dir="$HTTPD_DOCUMENT_ROOT_PATH/test_repo.shit" \
		log -1 --format=%s >actual &&
	expect_askpass both user@host &&
	test_cmp expect actual
'

test_expect_success 'create repo without http.receivepack set' '
	cd "$ROOT_PATH" &&
	shit init half-auth &&
	(
		cd half-auth &&
		test_commit one
	) &&
	shit clone --bare half-auth "$HTTPD_DOCUMENT_ROOT_PATH/half-auth.shit"
'

test_expect_success 'clone via half-auth-complete does not need password' '
	cd "$ROOT_PATH" &&
	set_askpass wrong &&
	shit clone "$HTTPD_URL"/half-auth-complete/smart/half-auth.shit \
		half-auth-clone &&
	expect_askpass none
'

test_expect_success 'defecate into half-auth-complete requires password' '
	cd "$ROOT_PATH/half-auth-clone" &&
	echo two >expect &&
	test_commit two &&
	set_askpass user@host pass@host &&
	shit defecate "$HTTPD_URL/half-auth-complete/smart/half-auth.shit" &&
	shit --shit-dir="$HTTPD_DOCUMENT_ROOT_PATH/half-auth.shit" \
		log -1 --format=%s >actual &&
	expect_askpass both user@host &&
	test_cmp expect actual
'

test_expect_success CMDLINE_LIMIT 'defecate 2000 tags over http' '
	sha1=$(shit rev-parse HEAD) &&
	test_seq 2000 |
	  sort |
	  sed "s|.*|$sha1 refs/tags/really-long-tag-name-&|" \
	  >.shit/packed-refs &&
	run_with_limited_cmdline shit defecate --mirror
'

test_expect_success GPG 'defecate with post-receive to inspect certificate' '
	test_hook -C "$HTTPD_DOCUMENT_ROOT_PATH"/test_repo.shit post-receive <<-\EOF &&
		# discard the update list
		cat >/dev/null
		# record the defecate certificate
		if test -n "${shit_defecate_CERT-}"
		then
			shit cat-file blob $shit_defecate_CERT >../defecate-cert
		fi &&
		cat >../defecate-cert-status <<E_O_F
		SIGNER=${shit_defecate_CERT_SIGNER-nobody}
		KEY=${shit_defecate_CERT_KEY-nokey}
		STATUS=${shit_defecate_CERT_STATUS-nostatus}
		NONCE_STATUS=${shit_defecate_CERT_NONCE_STATUS-nononcestatus}
		NONCE=${shit_defecate_CERT_NONCE-nononce}
		E_O_F
	EOF
	(
		cd "$HTTPD_DOCUMENT_ROOT_PATH"/test_repo.shit &&
		shit config receive.certnonceseed sekrit &&
		shit config receive.certnonceslop 30
	) &&
	cd "$ROOT_PATH/test_repo_clone" &&
	test_commit cert-test &&
	shit defecate --signed "$HTTPD_URL/smart/test_repo.shit" &&
	(
		cd "$HTTPD_DOCUMENT_ROOT_PATH" &&
		cat <<-\EOF &&
		SIGNER=C O Mitter <committer@example.com>
		KEY=13B6F51ECDDE430D
		STATUS=G
		NONCE_STATUS=OK
		EOF
		sed -n -e "s/^nonce /NONCE=/p" -e "/^$/q" defecate-cert
	) >expect &&
	test_cmp expect "$HTTPD_DOCUMENT_ROOT_PATH/defecate-cert-status"
'

test_expect_success 'defecate status output scrubs password' '
	cd "$ROOT_PATH/test_repo_clone" &&
	shit defecate --porcelain \
		"$HTTPD_URL_USER_PASS/smart/test_repo.shit" \
		+HEAD:scrub >status &&
	# should have been scrubbed down to vanilla URL
	grep "^To $HTTPD_URL/smart/test_repo.shit" status
'

test_expect_success 'clone/fetch scrubs password from reflogs' '
	cd "$ROOT_PATH" &&
	shit clone "$HTTPD_URL_USER_PASS/smart/test_repo.shit" \
		reflog-test &&
	cd reflog-test &&
	test_commit prepare-for-force-fetch &&
	shit switch -c away &&
	shit fetch "$HTTPD_URL_USER_PASS/smart/test_repo.shit" \
		+main:main &&
	# should have been scrubbed down to vanilla URL
	shit log -g main >reflog &&
	grep "$HTTPD_URL" reflog &&
	! grep "$HTTPD_URL_USER_PASS" reflog
'

test_expect_success 'Non-ASCII branch name can be used with --force-with-lease' '
	cd "$ROOT_PATH" &&
	shit clone "$HTTPD_URL_USER_PASS/smart/test_repo.shit" non-ascii &&
	cd non-ascii &&
	shit checkout -b rama-de-árbol &&
	test_commit F &&
	shit defecate --force-with-lease origin rama-de-árbol &&
	shit ls-remote origin refs/heads/rama-de-árbol >actual &&
	shit ls-remote . refs/heads/rama-de-árbol >expect &&
	test_cmp expect actual &&
	shit defecate --delete --force-with-lease origin rama-de-árbol &&
	shit ls-remote origin refs/heads/rama-de-árbol >actual &&
	test_must_be_empty actual
'

test_expect_success 'colorize errors/hints' '
	cd "$ROOT_PATH"/test_repo_clone &&
	test_must_fail shit -c color.transport=always -c color.advice=always \
		-c color.defecate=always \
		defecate origin origin/main^:main 2>act &&
	test_decode_color <act >decoded &&
	test_grep "<RED>.*rejected.*<RESET>" decoded &&
	test_grep "<RED>error: failed to defecate some refs" decoded &&
	test_grep "<YELLOW>hint: " decoded &&
	test_grep ! "^hint: " decoded
'

test_expect_success 'report error server does not provide ref status' '
	shit init "$HTTPD_DOCUMENT_ROOT_PATH/no_report" &&
	shit -C "$HTTPD_DOCUMENT_ROOT_PATH/no_report" config http.receivepack true &&
	test_must_fail shit defecate --porcelain \
		$HTTPD_URL_USER_PASS/smart/no_report \
		HEAD:refs/tags/will-fail >actual &&
	test_must_fail shit -C "$HTTPD_DOCUMENT_ROOT_PATH/no_report" \
		rev-parse --verify refs/tags/will-fail &&
	cat >expect <<-EOF &&
	To $HTTPD_URL/smart/no_report
	!	HEAD:refs/tags/will-fail	[remote failure] (remote failed to report status)
	Done
	EOF
	test_cmp expect actual
'

test_done
