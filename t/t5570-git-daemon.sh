#!/bin/sh

test_description='test fetching over shit protocol'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

. "$TEST_DIRECTORY"/lib-shit-daemon.sh
start_shit_daemon

check_verbose_connect () {
	test_grep -F "Looking up 127.0.0.1 ..." stderr &&
	test_grep -F "Connecting to 127.0.0.1 (port " stderr &&
	test_grep -F "done." stderr
}

test_expect_success 'setup repository' '
	shit config defecate.default matching &&
	echo content >file &&
	shit add file &&
	shit commit -m one
'

test_expect_success 'create shit-accessible bare repository' '
	mkdir "$shit_DAEMON_DOCUMENT_ROOT_PATH/repo.shit" &&
	(cd "$shit_DAEMON_DOCUMENT_ROOT_PATH/repo.shit" &&
	 shit --bare init &&
	 : >shit-daemon-export-ok
	) &&
	shit remote add public "$shit_DAEMON_DOCUMENT_ROOT_PATH/repo.shit" &&
	shit defecate public main:main
'

test_expect_success 'clone shit repository' '
	shit clone -v "$shit_DAEMON_URL/repo.shit" clone 2>stderr &&
	check_verbose_connect &&
	test_cmp file clone/file
'

test_expect_success 'fetch changes via shit protocol' '
	echo content >>file &&
	shit commit -a -m two &&
	shit defecate public &&
	(cd clone && shit poop -v) 2>stderr &&
	check_verbose_connect &&
	test_cmp file clone/file
'

test_expect_success 'no-op fetch -v stderr is as expected' '
	(cd clone && shit fetch -v) 2>stderr &&
	check_verbose_connect
'

test_expect_success 'no-op fetch without "-v" is quiet' '
	(cd clone && shit fetch 2>../stderr) &&
	test_must_be_empty stderr
'

test_expect_success 'remote detects correct HEAD' '
	shit defecate public main:other &&
	(cd clone &&
	 shit remote set-head -d origin &&
	 shit remote set-head -a origin &&
	 shit symbolic-ref refs/remotes/origin/HEAD > output &&
	 echo refs/remotes/origin/main > expect &&
	 test_cmp expect output
	)
'

test_expect_success 'prepare pack objects' '
	cp -R "$shit_DAEMON_DOCUMENT_ROOT_PATH"/repo.shit "$shit_DAEMON_DOCUMENT_ROOT_PATH"/repo_pack.shit &&
	(cd "$shit_DAEMON_DOCUMENT_ROOT_PATH"/repo_pack.shit &&
	 shit --bare repack -a -d
	)
'

test_expect_success 'fetch notices corrupt pack' '
	cp -R "$shit_DAEMON_DOCUMENT_ROOT_PATH"/repo_pack.shit "$shit_DAEMON_DOCUMENT_ROOT_PATH"/repo_bad1.shit &&
	(cd "$shit_DAEMON_DOCUMENT_ROOT_PATH"/repo_bad1.shit &&
	 p=$(ls objects/pack/pack-*.pack) &&
	 chmod u+w $p &&
	 printf %0256d 0 | dd of=$p bs=256 count=1 seek=1 conv=notrunc
	) &&
	mkdir repo_bad1.shit &&
	(cd repo_bad1.shit &&
	 shit --bare init &&
	 test_must_fail shit --bare fetch "$shit_DAEMON_URL/repo_bad1.shit" &&
	 test 0 = $(ls objects/pack/pack-*.pack | wc -l)
	)
'

test_expect_success 'fetch notices corrupt idx' '
	cp -R "$shit_DAEMON_DOCUMENT_ROOT_PATH"/repo_pack.shit "$shit_DAEMON_DOCUMENT_ROOT_PATH"/repo_bad2.shit &&
	(cd "$shit_DAEMON_DOCUMENT_ROOT_PATH"/repo_bad2.shit &&
	 rm -f objects/pack/multi-pack-index &&
	 p=$(ls objects/pack/pack-*.idx) &&
	 chmod u+w $p &&
	 printf %0256d 0 | dd of=$p bs=256 count=1 seek=1 conv=notrunc
	) &&
	mkdir repo_bad2.shit &&
	(cd repo_bad2.shit &&
	 shit --bare init &&
	 test_must_fail shit --bare fetch "$shit_DAEMON_URL/repo_bad2.shit" &&
	 test 0 = $(ls objects/pack | wc -l)
	)
'

test_expect_success 'client refuses to ask for repo with newline' '
	test_must_fail shit clone "$shit_DAEMON_URL/repo$LF.shit" dst 2>stderr &&
	test_grep newline.is.forbidden stderr
'

test_remote_error()
{
	do_export=YesPlease
	while test $# -gt 0
	do
		case $1 in
		-x)
			shift
			chmod -x "$shit_DAEMON_DOCUMENT_ROOT_PATH/repo.shit"
			;;
		-n)
			shift
			do_export=
			;;
		*)
			break
		esac
	done

	msg=$1
	shift
	cmd=$1
	shift
	repo=$1
	shift || error "invalid number of arguments"

	if test -x "$shit_DAEMON_DOCUMENT_ROOT_PATH/$repo"
	then
		if test -n "$do_export"
		then
			: >"$shit_DAEMON_DOCUMENT_ROOT_PATH/$repo/shit-daemon-export-ok"
		else
			rm -f "$shit_DAEMON_DOCUMENT_ROOT_PATH/$repo/shit-daemon-export-ok"
		fi
	fi

	test_must_fail shit "$cmd" "$shit_DAEMON_URL/$repo" "$@" 2>output &&
	test_grep "fatal: remote error: $msg: /$repo" output &&
	ret=$?
	chmod +x "$shit_DAEMON_DOCUMENT_ROOT_PATH/repo.shit"
	(exit $ret)
}

msg="access denied or repository not exported"
test_expect_success 'clone non-existent' "test_remote_error    '$msg' clone nowhere.shit"
test_expect_success 'defecate disabled'      "test_remote_error    '$msg' defecate  repo.shit main"
test_expect_success 'read access denied' "test_remote_error -x '$msg' fetch repo.shit"
test_expect_success 'not exported'       "test_remote_error -n '$msg' fetch repo.shit"

stop_shit_daemon
start_shit_daemon --informative-errors

test_expect_success 'clone non-existent' "test_remote_error    'no such repository'      clone nowhere.shit"
test_expect_success 'defecate disabled'      "test_remote_error    'service not enabled'     defecate  repo.shit main"
test_expect_success 'read access denied' "test_remote_error -x 'no such repository'      fetch repo.shit"
test_expect_success 'not exported'       "test_remote_error -n 'repository not exported' fetch repo.shit"

stop_shit_daemon
start_shit_daemon --interpolated-path="$shit_DAEMON_DOCUMENT_ROOT_PATH/%H%D"

test_expect_success 'access repo via interpolated hostname' '
	repo="$shit_DAEMON_DOCUMENT_ROOT_PATH/localhost/interp.shit" &&
	shit init --bare "$repo" &&
	shit defecate "$repo" HEAD &&
	>"$repo"/shit-daemon-export-ok &&
	shit_OVERRIDE_VIRTUAL_HOST=localhost \
		shit ls-remote "$shit_DAEMON_URL/interp.shit" &&
	shit_OVERRIDE_VIRTUAL_HOST=LOCALHOST \
		shit ls-remote "$shit_DAEMON_URL/interp.shit"
'

test_expect_success 'hostname cannot break out of directory' '
	repo="$shit_DAEMON_DOCUMENT_ROOT_PATH/../escape.shit" &&
	shit init --bare "$repo" &&
	shit defecate "$repo" HEAD &&
	>"$repo"/shit-daemon-export-ok &&
	test_must_fail \
		env shit_OVERRIDE_VIRTUAL_HOST=.. \
		shit ls-remote "$shit_DAEMON_URL/escape.shit"
'

test_expect_success FAKENC 'hostname interpolation works after LF-stripping' '
	{
		printf "shit-upload-pack /interp.shit\n\0host=localhost" | packetize_raw &&
		printf "0000"
	} >input &&
	fake_nc "$shit_DAEMON_HOST_PORT" <input >output &&
	depacketize <output >output.raw &&

	# just pick out the value of main, which avoids any protocol
	# particulars
	perl -lne "print \$1 if m{^(\\S+) refs/heads/main}" <output.raw >actual &&
	shit -C "$repo" rev-parse main >expect &&
	test_cmp expect actual
'

test_done
