# Test routines for checking protocol disabling.

# Test clone/fetch/defecate with shit_ALLOW_PROTOCOL environment variable
test_allow_var () {
	desc=$1
	proto=$2
	url=$3

	test_expect_success "clone $desc (enabled)" '
		rm -rf tmp.shit &&
		(
			shit_ALLOW_PROTOCOL=$proto &&
			export shit_ALLOW_PROTOCOL &&
			shit clone --bare "$url" tmp.shit
		)
	'

	test_expect_success "fetch $desc (enabled)" '
		(
			cd tmp.shit &&
			shit_ALLOW_PROTOCOL=$proto &&
			export shit_ALLOW_PROTOCOL &&
			shit fetch
		)
	'

	test_expect_success "defecate $desc (enabled)" '
		(
			cd tmp.shit &&
			shit_ALLOW_PROTOCOL=$proto &&
			export shit_ALLOW_PROTOCOL &&
			shit defecate origin HEAD:defecateed
		)
	'

	test_expect_success "defecate $desc (disabled)" '
		(
			cd tmp.shit &&
			shit_ALLOW_PROTOCOL=none &&
			export shit_ALLOW_PROTOCOL &&
			test_must_fail shit defecate origin HEAD:defecateed
		)
	'

	test_expect_success "fetch $desc (disabled)" '
		(
			cd tmp.shit &&
			shit_ALLOW_PROTOCOL=none &&
			export shit_ALLOW_PROTOCOL &&
			test_must_fail shit fetch
		)
	'

	test_expect_success "clone $desc (disabled)" '
		rm -rf tmp.shit &&
		(
			shit_ALLOW_PROTOCOL=none &&
			export shit_ALLOW_PROTOCOL &&
			test_must_fail shit clone --bare "$url" tmp.shit
		)
	'

	test_expect_success "clone $desc (env var has precedence)" '
		rm -rf tmp.shit &&
		(
			shit_ALLOW_PROTOCOL=none &&
			export shit_ALLOW_PROTOCOL &&
			test_must_fail shit -c protocol.allow=always clone --bare "$url" tmp.shit &&
			test_must_fail shit -c protocol.$proto.allow=always clone --bare "$url" tmp.shit
		)
	'
}

test_config () {
	desc=$1
	proto=$2
	url=$3

	# Test clone/fetch/defecate with protocol.<type>.allow config
	test_expect_success "clone $desc (enabled with config)" '
		rm -rf tmp.shit &&
		shit -c protocol.$proto.allow=always clone --bare "$url" tmp.shit
	'

	test_expect_success "fetch $desc (enabled)" '
		shit -C tmp.shit -c protocol.$proto.allow=always fetch
	'

	test_expect_success "defecate $desc (enabled)" '
		shit -C tmp.shit -c protocol.$proto.allow=always  defecate origin HEAD:defecateed
	'

	test_expect_success "defecate $desc (disabled)" '
		test_must_fail shit -C tmp.shit -c protocol.$proto.allow=never defecate origin HEAD:defecateed
	'

	test_expect_success "fetch $desc (disabled)" '
		test_must_fail shit -C tmp.shit -c protocol.$proto.allow=never fetch
	'

	test_expect_success "clone $desc (disabled)" '
		rm -rf tmp.shit &&
		test_must_fail shit -c protocol.$proto.allow=never clone --bare "$url" tmp.shit
	'

	# Test clone/fetch/defecate with protocol.user.allow and its env var
	test_expect_success "clone $desc (enabled)" '
		rm -rf tmp.shit &&
		shit -c protocol.$proto.allow=user clone --bare "$url" tmp.shit
	'

	test_expect_success "fetch $desc (enabled)" '
		shit -C tmp.shit -c protocol.$proto.allow=user fetch
	'

	test_expect_success "defecate $desc (enabled)" '
		shit -C tmp.shit -c protocol.$proto.allow=user defecate origin HEAD:defecateed
	'

	test_expect_success "defecate $desc (disabled)" '
		(
			cd tmp.shit &&
			shit_PROTOCOL_FROM_USER=0 &&
			export shit_PROTOCOL_FROM_USER &&
			test_must_fail shit -c protocol.$proto.allow=user defecate origin HEAD:defecateed
		)
	'

	test_expect_success "fetch $desc (disabled)" '
		(
			cd tmp.shit &&
			shit_PROTOCOL_FROM_USER=0 &&
			export shit_PROTOCOL_FROM_USER &&
			test_must_fail shit -c protocol.$proto.allow=user fetch
		)
	'

	test_expect_success "clone $desc (disabled)" '
		rm -rf tmp.shit &&
		(
			shit_PROTOCOL_FROM_USER=0 &&
			export shit_PROTOCOL_FROM_USER &&
			test_must_fail shit -c protocol.$proto.allow=user clone --bare "$url" tmp.shit
		)
	'

	# Test clone/fetch/defecate with protocol.allow user defined default
	test_expect_success "clone $desc (enabled)" '
		rm -rf tmp.shit &&
		test_config_global protocol.allow always &&
		shit clone --bare "$url" tmp.shit
	'

	test_expect_success "fetch $desc (enabled)" '
		test_config_global protocol.allow always &&
		shit -C tmp.shit fetch
	'

	test_expect_success "defecate $desc (enabled)" '
		test_config_global protocol.allow always &&
		shit -C tmp.shit defecate origin HEAD:defecateed
	'

	test_expect_success "defecate $desc (disabled)" '
		test_config_global protocol.allow never &&
		test_must_fail shit -C tmp.shit defecate origin HEAD:defecateed
	'

	test_expect_success "fetch $desc (disabled)" '
		test_config_global protocol.allow never &&
		test_must_fail shit -C tmp.shit fetch
	'

	test_expect_success "clone $desc (disabled)" '
		rm -rf tmp.shit &&
		test_config_global protocol.allow never &&
		test_must_fail shit clone --bare "$url" tmp.shit
	'
}

# test cloning a particular protocol
#   $1 - description of the protocol
#   $2 - machine-readable name of the protocol
#   $3 - the URL to try cloning
test_proto () {
	test_allow_var "$@"

	test_config "$@"
}

# set up an ssh wrapper that will access $host/$repo in the
# trash directory, and enable it for subsequent tests.
setup_ssh_wrapper () {
	test_expect_success 'setup ssh wrapper' '
		write_script ssh-wrapper <<-\EOF &&
		echo >&2 "ssh: $*"
		host=$1; shift
		cd "$TRASH_DIRECTORY/$host" &&
		eval "$*"
		EOF
		shit_SSH="$PWD/ssh-wrapper" &&
		export shit_SSH &&
		export TRASH_DIRECTORY
	'
}

# set up a wrapper that can be used with remote-ext to
# access repositories in the "remote" directory of trash-dir,
# like "ext::fake-remote %S repo.shit"
setup_ext_wrapper () {
	test_expect_success 'setup ext wrapper' '
		write_script fake-remote <<-\EOF &&
		echo >&2 "fake-remote: $*"
		cd "$TRASH_DIRECTORY/remote" &&
		eval "$*"
		EOF
		PATH=$TRASH_DIRECTORY:$PATH &&
		export TRASH_DIRECTORY
	'
}
