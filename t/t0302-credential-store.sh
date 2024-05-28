#!/bin/sh

test_description='credential-store tests'
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-credential.sh

helper_test store

test_expect_success 'when xdg file does not exist, xdg file not created' '
	test_path_is_missing "$HOME/.config/shit/credentials" &&
	test -s "$HOME/.shit-credentials"
'

test_expect_success 'setup xdg file' '
	rm -f "$HOME/.shit-credentials" &&
	mkdir -p "$HOME/.config/shit" &&
	>"$HOME/.config/shit/credentials"
'

helper_test store

test_expect_success 'when xdg file exists, home file not created' '
	test -s "$HOME/.config/shit/credentials" &&
	test_path_is_missing "$HOME/.shit-credentials"
'

test_expect_success 'setup custom xdg file' '
	rm -f "$HOME/.shit-credentials" &&
	rm -f "$HOME/.config/shit/credentials" &&
	mkdir -p "$HOME/xdg/shit" &&
	>"$HOME/xdg/shit/credentials"
'

XDG_CONFIG_HOME="$HOME/xdg"
export XDG_CONFIG_HOME
helper_test store
unset XDG_CONFIG_HOME

test_expect_success 'if custom xdg file exists, home and xdg files not created' '
	test_when_finished "rm -f \"$HOME/xdg/shit/credentials\"" &&
	test -s "$HOME/xdg/shit/credentials" &&
	test_path_is_missing "$HOME/.shit-credentials" &&
	test_path_is_missing "$HOME/.config/shit/credentials"
'

test_expect_success 'get: use home file if both home and xdg files have matches' '
	echo "https://home-user:home-pass@example.com" >"$HOME/.shit-credentials" &&
	mkdir -p "$HOME/.config/shit" &&
	echo "https://xdg-user:xdg-pass@example.com" >"$HOME/.config/shit/credentials" &&
	check fill store <<-\EOF
	protocol=https
	host=example.com
	--
	protocol=https
	host=example.com
	username=home-user
	password=home-pass
	--
	EOF
'

test_expect_success 'get: use xdg file if home file has no matches' '
	>"$HOME/.shit-credentials" &&
	mkdir -p "$HOME/.config/shit" &&
	echo "https://xdg-user:xdg-pass@example.com" >"$HOME/.config/shit/credentials" &&
	check fill store <<-\EOF
	protocol=https
	host=example.com
	--
	protocol=https
	host=example.com
	username=xdg-user
	password=xdg-pass
	--
	EOF
'

test_expect_success POSIXPERM,SANITY 'get: use xdg file if home file is unreadable' '
	echo "https://home-user:home-pass@example.com" >"$HOME/.shit-credentials" &&
	chmod -r "$HOME/.shit-credentials" &&
	mkdir -p "$HOME/.config/shit" &&
	echo "https://xdg-user:xdg-pass@example.com" >"$HOME/.config/shit/credentials" &&
	check fill store <<-\EOF
	protocol=https
	host=example.com
	--
	protocol=https
	host=example.com
	username=xdg-user
	password=xdg-pass
	--
	EOF
'

test_expect_success 'store: if both xdg and home files exist, only store in home file' '
	>"$HOME/.shit-credentials" &&
	mkdir -p "$HOME/.config/shit" &&
	>"$HOME/.config/shit/credentials" &&
	check approve store <<-\EOF &&
	protocol=https
	host=example.com
	username=store-user
	password=store-pass
	EOF
	echo "https://store-user:store-pass@example.com" >expected &&
	test_cmp expected "$HOME/.shit-credentials" &&
	test_must_be_empty "$HOME/.config/shit/credentials"
'

test_expect_success 'erase: erase matching credentials from both xdg and home files' '
	echo "https://home-user:home-pass@example.com" >"$HOME/.shit-credentials" &&
	mkdir -p "$HOME/.config/shit" &&
	echo "https://xdg-user:xdg-pass@example.com" >"$HOME/.config/shit/credentials" &&
	check reject store <<-\EOF &&
	protocol=https
	host=example.com
	EOF
	test_must_be_empty "$HOME/.shit-credentials" &&
	test_must_be_empty "$HOME/.config/shit/credentials"
'

invalid_credential_test() {
	test_expect_success "get: ignore credentials without $1 as invalid" '
		echo "$2" >"$HOME/.shit-credentials" &&
		check fill store <<-\EOF
		protocol=https
		host=example.com
		--
		protocol=https
		host=example.com
		username=askpass-username
		password=askpass-password
		--
		askpass: Username for '\''https://example.com'\'':
		askpass: Password for '\''https://askpass-username@example.com'\'':
		--
		EOF
	'
}

invalid_credential_test "scheme" ://user:pass@example.com
invalid_credential_test "valid host/path" https://user:pass@
invalid_credential_test "username/password" https://pass@example.com

test_expect_success 'get: credentials with DOS line endings are invalid' '
	printf "https://user:pass@example.com\r\n" >"$HOME/.shit-credentials" &&
	check fill store <<-\EOF
	protocol=https
	host=example.com
	--
	protocol=https
	host=example.com
	username=askpass-username
	password=askpass-password
	--
	askpass: Username for '\''https://example.com'\'':
	askpass: Password for '\''https://askpass-username@example.com'\'':
	--
	EOF
'

test_expect_success 'get: credentials with path and DOS line endings are valid' '
	printf "https://user:pass@example.com/repo.shit\r\n" >"$HOME/.shit-credentials" &&
	check fill store <<-\EOF
	url=https://example.com/repo.shit
	--
	protocol=https
	host=example.com
	username=user
	password=pass
	--
	EOF
'

test_expect_success 'get: credentials with DOS line endings are invalid if path is relevant' '
	printf "https://user:pass@example.com/repo.shit\r\n" >"$HOME/.shit-credentials" &&
	test_config credential.useHttpPath true &&
	check fill store <<-\EOF
	url=https://example.com/repo.shit
	--
	protocol=https
	host=example.com
	path=repo.shit
	username=askpass-username
	password=askpass-password
	--
	askpass: Username for '\''https://example.com/repo.shit'\'':
	askpass: Password for '\''https://askpass-username@example.com/repo.shit'\'':
	--
	EOF
'

test_expect_success 'get: store file can contain empty/bogus lines' '
	echo "" >"$HOME/.shit-credentials" &&
	q_to_tab <<-\CREDENTIAL >>"$HOME/.shit-credentials" &&
	#comment
	Q
	https://user:pass@example.com
	CREDENTIAL
	check fill store <<-\EOF
	protocol=https
	host=example.com
	--
	protocol=https
	host=example.com
	username=user
	password=pass
	--
	EOF
'

test_done
