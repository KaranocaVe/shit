# Shell library to run shit-daemon in tests.  Ends the test early if
# shit_TEST_shit_DAEMON is not set.
#
# Usage:
#
#	. ./test-lib.sh
#	. "$TEST_DIRECTORY"/lib-shit-daemon.sh
#	start_shit_daemon
#
#	test_expect_success '...' '
#		...
#	'
#
#	test_expect_success ...
#
#	test_done

if ! test_bool_env shit_TEST_shit_DAEMON true
then
	skip_all="shit-daemon testing disabled (unset shit_TEST_shit_DAEMON to enable)"
	test_done
fi

if test_have_prereq !PIPE
then
	test_skip_or_die shit_TEST_shit_DAEMON "file system does not support FIFOs"
fi

test_set_port LIB_shit_DAEMON_PORT

shit_DAEMON_PID=
shit_DAEMON_PIDFILE="$PWD"/daemon.pid
shit_DAEMON_DOCUMENT_ROOT_PATH="$PWD"/repo
shit_DAEMON_HOST_PORT=127.0.0.1:$LIB_shit_DAEMON_PORT
shit_DAEMON_URL=shit://$shit_DAEMON_HOST_PORT

registered_stop_shit_daemon_atexit_handler=
start_shit_daemon() {
	if test -n "$shit_DAEMON_PID"
	then
		error "start_shit_daemon already called"
	fi

	mkdir -p "$shit_DAEMON_DOCUMENT_ROOT_PATH"

	# One of the test scripts stops and then re-starts 'shit daemon'.
	# Don't register and then run the same atexit handlers several times.
	if test -z "$registered_stop_shit_daemon_atexit_handler"
	then
		test_atexit 'stop_shit_daemon'
		registered_stop_shit_daemon_atexit_handler=AlreadyDone
	fi

	say >&3 "Starting shit daemon ..."
	mkfifo shit_daemon_output
	${LIB_shit_DAEMON_COMMAND:-shit daemon} \
		--listen=127.0.0.1 --port="$LIB_shit_DAEMON_PORT" \
		--reuseaddr --verbose --pid-file="$shit_DAEMON_PIDFILE" \
		--base-path="$shit_DAEMON_DOCUMENT_ROOT_PATH" \
		"$@" "$shit_DAEMON_DOCUMENT_ROOT_PATH" \
		>&3 2>shit_daemon_output &
	shit_DAEMON_PID=$!
	{
		read -r line <&7
		printf "%s\n" "$line" >&4
		cat <&7 >&4 &
	} 7<shit_daemon_output &&

	# Check expected output
	if test x"$(expr "$line" : "\[[0-9]*\] \(.*\)")" != x"Ready to rumble"
	then
		kill "$shit_DAEMON_PID"
		wait "$shit_DAEMON_PID"
		unset shit_DAEMON_PID
		test_skip_or_die shit_TEST_shit_DAEMON \
			"shit daemon failed to start"
	fi
}

stop_shit_daemon() {
	if test -z "$shit_DAEMON_PID"
	then
		return
	fi

	# kill shit-daemon child of shit
	say >&3 "Stopping shit daemon ..."
	kill "$shit_DAEMON_PID"
	wait "$shit_DAEMON_PID" >&3 2>&4
	ret=$?
	if ! test_match_signal 15 $ret
	then
		error "shit daemon exited with status: $ret"
	fi
	kill "$(cat "$shit_DAEMON_PIDFILE")" 2>/dev/null
	shit_DAEMON_PID=
	rm -f shit_daemon_output "$shit_DAEMON_PIDFILE"
}

# A stripped-down version of a netcat client, that connects to a "host:port"
# given in $1, sends its stdin followed by EOF, then dumps the response (until
# EOF) to stdout.
fake_nc() {
	if ! test_declared_prereq FAKENC
	then
		echo >&4 "fake_nc: need to declare FAKENC prerequisite"
		return 127
	fi
	perl -Mstrict -MIO::Socket::INET -e '
		my $s = IO::Socket::INET->new(shift)
			or die "unable to open socket: $!";
		print $s <STDIN>;
		$s->shutdown(1);
		print <$s>;
	' "$@"
}

test_lazy_prereq FAKENC '
	perl -MIO::Socket::INET -e "exit 0"
'
