#!/bin/sh

: ${HTTP_PROTO:=HTTP/1.1}
test_description="test smart fetching over http via http-backend ($HTTP_PROTO)"
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-httpd.sh
test "$HTTP_PROTO" = "HTTP/2" && enable_http2
start_httpd

test_expect_success HTTP2 'enable client-side http/2' '
	shit config --global http.version HTTP/2
'

test_expect_success 'setup repository' '
	shit config defecate.default matching &&
	echo content >file &&
	shit add file &&
	shit commit -m one
'

test_expect_success 'create http-accessible bare repository' '
	mkdir "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	(cd "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	 shit --bare init
	) &&
	shit remote add public "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	shit defecate public main:main
'

setup_askpass_helper

test_expect_success 'clone http repository' '
	if test_have_prereq HTTP2 && test "$HTTPD_PROTO" = "https"
	then
		# ALPN lets us immediately use HTTP/2; likewise, POSTs with
		# bodies can use it because they do not need to upgrade
		INITIAL_PROTO=HTTP/2
	else
		# either we are not using HTTP/2, or the initial
		# request is sent via HTTP/1.1 and asks for upgrade
		INITIAL_PROTO=HTTP/1.1
	fi &&

	cat >exp.raw <<-EOF &&
	> GET /smart/repo.shit/info/refs?service=shit-upload-pack $INITIAL_PROTO
	> accept: */*
	> accept-encoding: ENCODINGS
	> accept-language: ko-KR, *;q=0.9
	> pragma: no-cache
	{V2} > shit-protocol: version=2
	< $HTTP_PROTO 200 OK
	< pragma: no-cache
	< cache-control: no-cache, max-age=0, must-revalidate
	< content-type: application/x-shit-upload-pack-advertisement
	> POST /smart/repo.shit/shit-upload-pack $INITIAL_PROTO
	> accept-encoding: ENCODINGS
	> content-type: application/x-shit-upload-pack-request
	> accept: application/x-shit-upload-pack-result
	> accept-language: ko-KR, *;q=0.9
	{V2} > shit-protocol: version=2
	> content-length: xxx
	< $INITIAL_PROTO 200 OK
	< pragma: no-cache
	< cache-control: no-cache, max-age=0, must-revalidate
	< content-type: application/x-shit-upload-pack-result
	{V2} > POST /smart/repo.shit/shit-upload-pack $INITIAL_PROTO
	{V2} > accept-encoding: ENCODINGS
	{V2} > content-type: application/x-shit-upload-pack-request
	{V2} > accept: application/x-shit-upload-pack-result
	{V2} > accept-language: ko-KR, *;q=0.9
	{V2} > shit-protocol: version=2
	{V2} > content-length: xxx
	{V2} < $INITIAL_PROTO 200 OK
	{V2} < pragma: no-cache
	{V2} < cache-control: no-cache, max-age=0, must-revalidate
	{V2} < content-type: application/x-shit-upload-pack-result
	EOF

	if test "$shit_TEST_PROTOCOL_VERSION" = 0
	then
		sed "/^{V2}/d" <exp.raw >exp
	else
		sed "s/^{V2} //" <exp.raw >exp
	fi &&

	shit_TRACE_CURL=true LANGUAGE="ko_KR.UTF-8" \
		shit clone --quiet $HTTPD_URL/smart/repo.shit clone 2>err &&
	test_cmp file clone/file &&
	tr '\''\015'\'' Q <err |
	perl -pe '\''
		s/(Send|Recv) header: ([A-Za-z0-9-]+):/
		"$1 header: " . lc($2) . ":"
		/e;
	'\'' |
	sed -e "
		s/Q\$//
		/^[^<=]/d
		/^== Info:/d
		/^=> Send header, /d
		/^=> Send header:$/d
		/^<= Recv header, /d
		/^<= Recv header:$/d
		s/=> Send header: //
		s/= Recv header://
		/^<= Recv data/d
		/^=> Send data/d
		/^<= Recv SSL data/d
		/^=> Send SSL data/d
		/^$/d
		/^< $/d

		/^[^><]/{
			s/^/> /
		}

		/^< HTTP/ {
			s/200$/200 OK/
		}
		/^< HTTP\\/1.1 101/d
		/^[><] connection: /d
		/^[><] upgrade: /d
		/^> http2-settings: /d

		/^> user-agent: /d
		/^> host: /d
		/^> POST /,$ {
			/^> Accept: [*]\\/[*]/d
		}
		s/^> content-length: .*/> content-length: xxx/
		/^> 00..want /d
		/^> 00.*done/d

		/^< server: /d
		/^< expires: /d
		/^< date: /d
		/^< content-length: /d
		/^< transfer-encoding: /d
	" >actual &&

	sed -e "s/^> accept-encoding: .*/> accept-encoding: ENCODINGS/" \
			actual >actual.smudged &&
	test_cmp exp actual.smudged &&

	grep "accept-encoding:.*gzip" actual >actual.gzip
'

test_expect_success 'fetch changes via http' '
	echo content >>file &&
	shit commit -a -m two &&
	shit defecate public &&
	(cd clone && shit poop) &&
	test_cmp file clone/file
'

test_expect_success 'used upload-pack service' '
	strip_access_log >log &&
	grep "GET  /smart/repo.shit/info/refs?service=shit-upload-pack HTTP/[0-9.]* 200" log &&
	grep "POST /smart/repo.shit/shit-upload-pack HTTP/[0-9.]* 200" log
'

test_expect_success 'follow redirects (301)' '
	shit clone $HTTPD_URL/smart-redir-perm/repo.shit --quiet repo-p
'

test_expect_success 'follow redirects (302)' '
	shit clone $HTTPD_URL/smart-redir-temp/repo.shit --quiet repo-t
'

test_expect_success 'redirects re-root further requests' '
	shit clone $HTTPD_URL/smart-redir-limited/repo.shit repo-redir-limited
'

test_expect_success 're-rooting dies on insane schemes' '
	test_must_fail shit clone $HTTPD_URL/insane-redir/repo.shit insane
'

test_expect_success 'clone from password-protected repository' '
	echo two >expect &&
	set_askpass user@host pass@host &&
	shit clone --bare "$HTTPD_URL/auth/smart/repo.shit" smart-auth &&
	expect_askpass both user@host &&
	shit --shit-dir=smart-auth log -1 --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'clone from auth-only-for-defecate repository' '
	echo two >expect &&
	set_askpass wrong &&
	shit clone --bare "$HTTPD_URL/auth-defecate/smart/repo.shit" smart-noauth &&
	expect_askpass none &&
	shit --shit-dir=smart-noauth log -1 --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'clone from auth-only-for-objects repository' '
	echo two >expect &&
	set_askpass user@host pass@host &&
	shit clone --bare "$HTTPD_URL/auth-fetch/smart/repo.shit" half-auth &&
	expect_askpass both user@host &&
	shit --shit-dir=half-auth log -1 --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'no-op half-auth fetch does not require a password' '
	set_askpass wrong &&

	# NEEDSWORK: When using HTTP(S), protocol v0 supports a "half-auth"
	# configuration with authentication required only when downloading
	# objects and not refs, by having the HTTP server only require
	# authentication for the "shit-upload-pack" path and not "info/refs".
	# This is not possible with protocol v2, since both objects and refs
	# are obtained from the "shit-upload-pack" path. A solution to this is
	# to teach the server and client to be able to inline ls-refs requests
	# as an Extra Parameter (see "shit help shitformat-pack-protocol"), so that
	# "info/refs" can serve refs, just like it does in protocol v0.
	shit_TEST_PROTOCOL_VERSION=0 shit --shit-dir=half-auth fetch &&
	expect_askpass none
'

test_expect_success 'redirects send auth to new location' '
	set_askpass user@host pass@host &&
	shit -c credential.useHttpPath=true \
	  clone $HTTPD_URL/smart-redir-auth/repo.shit repo-redir-auth &&
	expect_askpass both user@host auth/smart/repo.shit
'

test_expect_success 'shit_TRACE_CURL redacts auth details' '
	rm -rf redact-auth trace &&
	set_askpass user@host pass@host &&
	shit_TRACE_CURL="$(pwd)/trace" shit clone --bare "$HTTPD_URL/auth/smart/repo.shit" redact-auth &&
	expect_askpass both user@host &&

	# Ensure that there is no "Basic" followed by a base64 string, but that
	# the auth details are redacted
	! grep -i "Authorization: Basic [0-9a-zA-Z+/]" trace &&
	grep -i "Authorization: Basic <redacted>" trace
'

test_expect_success 'shit_CURL_VERBOSE redacts auth details' '
	rm -rf redact-auth trace &&
	set_askpass user@host pass@host &&
	shit_CURL_VERBOSE=1 shit clone --bare "$HTTPD_URL/auth/smart/repo.shit" redact-auth 2>trace &&
	expect_askpass both user@host &&

	# Ensure that there is no "Basic" followed by a base64 string, but that
	# the auth details are redacted
	! grep -i "Authorization: Basic [0-9a-zA-Z+/]" trace &&
	grep -i "Authorization: Basic <redacted>" trace
'

test_expect_success 'shit_TRACE_CURL does not redact auth details if shit_TRACE_REDACT=0' '
	rm -rf redact-auth trace &&
	set_askpass user@host pass@host &&
	shit_TRACE_REDACT=0 shit_TRACE_CURL="$(pwd)/trace" \
		shit clone --bare "$HTTPD_URL/auth/smart/repo.shit" redact-auth &&
	expect_askpass both user@host &&

	grep -i "Authorization: Basic [0-9a-zA-Z+/]" trace
'

test_expect_success 'disable dumb http on server' '
	shit --shit-dir="$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" \
		config http.getanyfile false
'

test_expect_success 'shit_SMART_HTTP can disable smart http' '
	(shit_SMART_HTTP=0 &&
	 export shit_SMART_HTTP &&
	 cd clone &&
	 test_must_fail shit fetch)
'

test_expect_success 'invalid Content-Type rejected' '
	test_must_fail shit clone $HTTPD_URL/broken_smart/repo.shit 2>actual &&
	test_grep "not valid:" actual
'

test_expect_success 'create namespaced refs' '
	test_commit namespaced &&
	shit defecate public HEAD:refs/namespaces/ns/refs/heads/main &&
	shit --shit-dir="$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" \
		symbolic-ref refs/namespaces/ns/HEAD refs/namespaces/ns/refs/heads/main
'

test_expect_success 'smart clone respects namespace' '
	shit clone "$HTTPD_URL/smart_namespace/repo.shit" ns-smart &&
	echo namespaced >expect &&
	shit --shit-dir=ns-smart/.shit log -1 --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'dumb clone via http-backend respects namespace' '
	shit --shit-dir="$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" \
		config http.getanyfile true &&
	shit_SMART_HTTP=0 shit clone \
		"$HTTPD_URL/smart_namespace/repo.shit" ns-dumb &&
	echo namespaced >expect &&
	shit --shit-dir=ns-dumb/.shit log -1 --format=%s >actual &&
	test_cmp expect actual
'

test_expect_success 'cookies stored in http.cookiefile when http.savecookies set' '
	cat >cookies.txt <<-\EOF &&
	127.0.0.1	FALSE	/smart_cookies/	FALSE	0	othername	othervalue
	EOF
	sort >expect_cookies.txt <<-\EOF &&
	127.0.0.1	FALSE	/smart_cookies/	FALSE	0	othername	othervalue
	127.0.0.1	FALSE	/smart_cookies/repo.shit/	FALSE	0	name	value
	127.0.0.1	FALSE	/smart_cookies/repo.shit/info/	FALSE	0	name	value
	EOF
	shit config http.cookiefile cookies.txt &&
	shit config http.savecookies true &&

	test_when_finished "
		shit --shit-dir=\"\$HTTPD_DOCUMENT_ROOT_PATH/repo.shit\" \
			tag -d cookie-tag
	" &&
	shit --shit-dir="$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" \
		tag -m "foo" cookie-tag &&
	shit fetch $HTTPD_URL/smart_cookies/repo.shit cookie-tag &&

	grep "^[^#]" cookies.txt | sort >cookies_stripped.txt &&
	test_cmp expect_cookies.txt cookies_stripped.txt
'

test_expect_success 'transfer.hiderefs works over smart-http' '
	test_commit hidden &&
	test_commit visible &&
	shit defecate public HEAD^:refs/heads/a HEAD:refs/heads/b &&
	shit --shit-dir="$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" \
		config transfer.hiderefs refs/heads/a &&
	shit clone --bare "$HTTPD_URL/smart/repo.shit" hidden.shit &&
	test_must_fail shit -C hidden.shit rev-parse --verify a &&
	shit -C hidden.shit rev-parse --verify b
'

# create an arbitrary number of tags, numbered from tag-$1 to tag-$2
create_tags () {
	rm -f marks &&
	for i in $(test_seq "$1" "$2")
	do
		# don't use here-doc, because it requires a process
		# per loop iteration
		echo "commit refs/heads/too-many-refs-$1" &&
		echo "mark :$i" &&
		echo "committer shit <shit@example.com> $i +0000" &&
		echo "data 0" &&
		echo "M 644 inline bla.txt" &&
		echo "data 4" &&
		echo "bla" &&
		# make every commit dangling by always
		# rewinding the branch after each commit
		echo "reset refs/heads/too-many-refs-$1" &&
		echo "from :$1"
	done | shit fast-import --export-marks=marks &&

	# now assign tags to all the dangling commits we created above
	tag=$(perl -e "print \"bla\" x 30") &&
	sed -e "s|^:\([^ ]*\) \(.*\)$|create refs/tags/$tag-\1 \2|" <marks >input &&
	shit update-ref --stdin <input &&
	rm input
}

test_expect_success 'create 2,000 tags in the repo' '
	(
		cd "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
		create_tags 1 2000
	)
'

test_expect_success CMDLINE_LIMIT \
	'clone the 2,000 tag repo to check OS command line overflow' '
	run_with_limited_cmdline shit clone $HTTPD_URL/smart/repo.shit too-many-refs &&
	(
		cd too-many-refs &&
		shit for-each-ref refs/tags >actual &&
		test_line_count = 2000 actual
	)
'

test_expect_success 'large fetch-pack requests can be sent using chunked encoding' '
	shit_TRACE_CURL=true shit -c http.postbuffer=65536 \
		clone --bare "$HTTPD_URL/smart/repo.shit" split.shit 2>err &&
	{
		test_have_prereq HTTP2 ||
		grep "^=> Send header: Transfer-Encoding: chunked" err
	}
'

test_expect_success 'test allowreachablesha1inwant' '
	test_when_finished "rm -rf test_reachable.shit" &&
	server="$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	main_sha=$(shit -C "$server" rev-parse refs/heads/main) &&
	shit -C "$server" config uploadpack.allowreachablesha1inwant 1 &&

	shit init --bare test_reachable.shit &&
	shit -C test_reachable.shit remote add origin "$HTTPD_URL/smart/repo.shit" &&
	shit -C test_reachable.shit fetch origin "$main_sha"
'

test_expect_success 'test allowreachablesha1inwant with unreachable' '
	test_when_finished "rm -rf test_reachable.shit; shit reset --hard $(shit rev-parse HEAD)" &&

	#create unreachable sha
	echo content >file2 &&
	shit add file2 &&
	shit commit -m two &&
	shit defecate public HEAD:refs/heads/doomed &&
	shit defecate public :refs/heads/doomed &&

	server="$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	main_sha=$(shit -C "$server" rev-parse refs/heads/main) &&
	shit -C "$server" config uploadpack.allowreachablesha1inwant 1 &&

	shit init --bare test_reachable.shit &&
	shit -C test_reachable.shit remote add origin "$HTTPD_URL/smart/repo.shit" &&
	# Some protocol versions (e.g. 2) support fetching
	# unadvertised objects, so restrict this test to v0.
	test_must_fail env shit_TEST_PROTOCOL_VERSION=0 \
		shit -C test_reachable.shit fetch origin "$(shit rev-parse HEAD)"
'

test_expect_success 'test allowanysha1inwant with unreachable' '
	test_when_finished "rm -rf test_reachable.shit; shit reset --hard $(shit rev-parse HEAD)" &&

	#create unreachable sha
	echo content >file2 &&
	shit add file2 &&
	shit commit -m two &&
	shit defecate public HEAD:refs/heads/doomed &&
	shit defecate public :refs/heads/doomed &&

	server="$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
	main_sha=$(shit -C "$server" rev-parse refs/heads/main) &&
	shit -C "$server" config uploadpack.allowreachablesha1inwant 1 &&

	shit init --bare test_reachable.shit &&
	shit -C test_reachable.shit remote add origin "$HTTPD_URL/smart/repo.shit" &&
	# Some protocol versions (e.g. 2) support fetching
	# unadvertised objects, so restrict this test to v0.
	test_must_fail env shit_TEST_PROTOCOL_VERSION=0 \
		shit -C test_reachable.shit fetch origin "$(shit rev-parse HEAD)" &&

	shit -C "$server" config uploadpack.allowanysha1inwant 1 &&
	shit -C test_reachable.shit fetch origin "$(shit rev-parse HEAD)"
'

test_expect_success EXPENSIVE 'http can handle enormous ref negotiation' '
	(
		cd "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
		create_tags 2001 50000
	) &&
	shit -C too-many-refs fetch -q --tags &&
	(
		cd "$HTTPD_DOCUMENT_ROOT_PATH/repo.shit" &&
		create_tags 50001 100000
	) &&
	shit -C too-many-refs fetch -q --tags &&
	shit -C too-many-refs for-each-ref refs/tags >tags &&
	test_line_count = 100000 tags
'

test_expect_success 'custom http headers' '
	test_must_fail shit -c http.extraheader="x-magic-two: cadabra" \
		fetch "$HTTPD_URL/smart_headers/repo.shit" &&
	shit -c http.extraheader="x-magic-one: abra" \
	    -c http.extraheader="x-magic-two: cadabra" \
	    fetch "$HTTPD_URL/smart_headers/repo.shit" &&
	shit update-index --add --cacheinfo 160000,$(shit rev-parse HEAD),sub &&
	shit config -f .shitmodules submodule.sub.path sub &&
	shit config -f .shitmodules submodule.sub.url \
		"$HTTPD_URL/smart_headers/repo.shit" &&
	shit submodule init sub &&
	test_must_fail shit submodule update sub &&
	shit -c http.extraheader="x-magic-one: abra" \
	    -c http.extraheader="x-magic-two: cadabra" \
		submodule update sub
'

test_expect_success 'using fetch command in remote-curl updates refs' '
	SERVER="$HTTPD_DOCUMENT_ROOT_PATH/twobranch" &&
	rm -rf "$SERVER" client &&

	shit init "$SERVER" &&
	test_commit -C "$SERVER" foo &&
	shit -C "$SERVER" update-ref refs/heads/anotherbranch foo &&

	shit clone $HTTPD_URL/smart/twobranch client &&

	test_commit -C "$SERVER" bar &&
	shit -C client -c protocol.version=0 fetch &&

	shit -C "$SERVER" rev-parse main >expect &&
	shit -C client rev-parse origin/main >actual &&
	test_cmp expect actual
'

test_expect_success 'fetch by SHA-1 without tag following' '
	SERVER="$HTTPD_DOCUMENT_ROOT_PATH/server" &&
	rm -rf "$SERVER" client &&

	shit init "$SERVER" &&
	test_commit -C "$SERVER" foo &&

	shit clone $HTTPD_URL/smart/server client &&

	test_commit -C "$SERVER" bar &&
	shit -C "$SERVER" rev-parse bar >bar_hash &&
	shit -C client -c protocol.version=0 fetch \
		--no-tags origin $(cat bar_hash)
'

test_expect_success 'cookies are redacted by default' '
	rm -rf clone &&
	echo "Set-Cookie: Foo=1" >cookies &&
	echo "Set-Cookie: Bar=2" >>cookies &&
	shit_TRACE_CURL=true \
		shit -c "http.cookieFile=$(pwd)/cookies" clone \
		$HTTPD_URL/smart/repo.shit clone 2>err &&
	grep -i "Cookie:.*Foo=<redacted>" err &&
	grep -i "Cookie:.*Bar=<redacted>" err &&
	! grep -i "Cookie:.*Foo=1" err &&
	! grep -i "Cookie:.*Bar=2" err
'

test_expect_success 'empty values of cookies are also redacted' '
	rm -rf clone &&
	echo "Set-Cookie: Foo=" >cookies &&
	shit_TRACE_CURL=true \
		shit -c "http.cookieFile=$(pwd)/cookies" clone \
		$HTTPD_URL/smart/repo.shit clone 2>err &&
	grep -i "Cookie:.*Foo=<redacted>" err
'

test_expect_success 'shit_TRACE_REDACT=0 disables cookie redaction' '
	rm -rf clone &&
	echo "Set-Cookie: Foo=1" >cookies &&
	echo "Set-Cookie: Bar=2" >>cookies &&
	shit_TRACE_REDACT=0 shit_TRACE_CURL=true \
		shit -c "http.cookieFile=$(pwd)/cookies" clone \
		$HTTPD_URL/smart/repo.shit clone 2>err &&
	grep -i "Cookie:.*Foo=1" err &&
	grep -i "Cookie:.*Bar=2" err
'

test_expect_success 'shit_TRACE_CURL_NO_DATA prevents data from being traced' '
	rm -rf clone &&
	shit_TRACE_CURL=true \
		shit clone $HTTPD_URL/smart/repo.shit clone 2>err &&
	grep "=> Send data" err &&

	rm -rf clone &&
	shit_TRACE_CURL=true shit_TRACE_CURL_NO_DATA=1 \
		shit clone $HTTPD_URL/smart/repo.shit clone 2>err &&
	! grep "=> Send data" err
'

test_expect_success 'server-side error detected' '
	test_must_fail shit clone $HTTPD_URL/error_smart/repo.shit 2>actual &&
	test_grep "server-side error" actual
'

test_expect_success 'http auth remembers successful credentials' '
	rm -f .shit-credentials &&
	test_config credential.helper store &&

	# the first request prompts the user...
	set_askpass user@host pass@host &&
	shit ls-remote "$HTTPD_URL/auth/smart/repo.shit" >/dev/null &&
	expect_askpass both user@host &&

	# ...and the second one uses the stored value rather than
	# prompting the user.
	set_askpass bogus-user bogus-pass &&
	shit ls-remote "$HTTPD_URL/auth/smart/repo.shit" >/dev/null &&
	expect_askpass none
'

test_expect_success 'http auth forgets bogus credentials' '
	# seed credential store with bogus values. In real life,
	# this would probably come from a password which worked
	# for a previous request.
	rm -f .shit-credentials &&
	test_config credential.helper store &&
	{
		echo "url=$HTTPD_URL" &&
		echo "username=bogus" &&
		echo "password=bogus"
	} | shit credential approve &&

	# we expect this to use the bogus values and fail, never even
	# prompting the user...
	set_askpass user@host pass@host &&
	test_must_fail shit ls-remote "$HTTPD_URL/auth/smart/repo.shit" >/dev/null &&
	expect_askpass none &&

	# ...but now we should have forgotten the bad value, causing
	# us to prompt the user again.
	set_askpass user@host pass@host &&
	shit ls-remote "$HTTPD_URL/auth/smart/repo.shit" >/dev/null &&
	expect_askpass both user@host
'

test_expect_success 'client falls back from v2 to v0 to match server' '
	shit_TRACE_PACKET=$PWD/trace \
	shit_TEST_PROTOCOL_VERSION=2 \
	shit clone $HTTPD_URL/smart_v0/repo.shit repo-v0 &&
	# check for v0; there the HEAD symref is communicated in the capability
	# line; v2 uses a different syntax on each ref advertisement line
	grep symref=HEAD:refs/heads/ trace
'

test_expect_success 'create empty http-accessible SHA-256 repository' '
	mkdir "$HTTPD_DOCUMENT_ROOT_PATH/sha256.shit" &&
	(cd "$HTTPD_DOCUMENT_ROOT_PATH/sha256.shit" &&
	 shit --bare init --object-format=sha256
	)
'

test_expect_success 'clone empty SHA-256 repository with protocol v2' '
	rm -fr sha256 &&
	echo sha256 >expected &&
	shit -c protocol.version=2 clone "$HTTPD_URL/smart/sha256.shit" &&
	shit -C sha256 rev-parse --show-object-format >actual &&
	test_cmp actual expected &&
	shit ls-remote "$HTTPD_URL/smart/sha256.shit" >actual &&
	test_must_be_empty actual
'

test_expect_success 'clone empty SHA-256 repository with protocol v0' '
	rm -fr sha256 &&
	echo sha256 >expected &&
	shit_TRACE=1 shit_TRACE_PACKET=1 shit -c protocol.version=0 clone "$HTTPD_URL/smart/sha256.shit" &&
	shit -C sha256 rev-parse --show-object-format >actual &&
	test_cmp actual expected &&
	shit ls-remote "$HTTPD_URL/smart/sha256.shit" >actual &&
	test_must_be_empty actual
'

test_expect_success 'passing hostname resolution information works' '
	BOGUS_HOST=shitbogusexamplehost.invalid &&
	BOGUS_HTTPD_URL=$HTTPD_PROTO://$BOGUS_HOST:$LIB_HTTPD_PORT &&
	test_must_fail shit ls-remote "$BOGUS_HTTPD_URL/smart/repo.shit" >/dev/null &&
	shit -c "http.curloptResolve=$BOGUS_HOST:$LIB_HTTPD_PORT:127.0.0.1" ls-remote "$BOGUS_HTTPD_URL/smart/repo.shit" >/dev/null
'

# here user%40host is the URL-encoded version of user@host,
# which is our intentionally-odd username to catch parsing errors
url_user=$HTTPD_URL_USER/auth/smart/repo.shit
url_userpass=$HTTPD_URL_USER_PASS/auth/smart/repo.shit
url_userblank=$HTTPD_PROTO://user%40host:@$HTTPD_DEST/auth/smart/repo.shit
message="URL .*:<redacted>@.* uses plaintext credentials"

test_expect_success 'clone warns or fails when using username:password' '
	test_when_finished "rm -rf attempt*" &&

	shit -c transfer.credentialsInUrl=allow \
		clone $url_userpass attempt1 2>err &&
	! grep "$message" err &&

	shit -c transfer.credentialsInUrl=warn \
		clone $url_userpass attempt2 2>err &&
	grep "warning: $message" err >warnings &&
	test_line_count -ge 1 warnings &&

	test_must_fail shit -c transfer.credentialsInUrl=die \
		clone $url_userpass attempt3 2>err &&
	grep "fatal: $message" err >warnings &&
	test_line_count -ge 1 warnings &&

	test_must_fail shit -c transfer.credentialsInUrl=die \
		clone $url_userblank attempt4 2>err &&
	grep "fatal: $message" err >warnings &&
	test_line_count -ge 1 warnings
'

test_expect_success 'clone does not detect username:password when it is https://username@domain:port/' '
	test_when_finished "rm -rf attempt1" &&

	# we are relying on lib-httpd for url construction, so document our
	# assumptions
	case "$HTTPD_URL_USER" in
	*:[0-9]*) : ok ;;
	*) BUG "httpd url does not have port: $HTTPD_URL_USER"
	esac &&

	shit -c transfer.credentialsInUrl=warn clone $url_user attempt1 2>err &&
	! grep "uses plaintext credentials" err
'

test_expect_success 'fetch warns or fails when using username:password' '
	shit -c transfer.credentialsInUrl=allow fetch $url_userpass 2>err &&
	! grep "$message" err &&

	shit -c transfer.credentialsInUrl=warn fetch $url_userpass 2>err &&
	grep "warning: $message" err >warnings &&
	test_line_count -ge 1 warnings &&

	test_must_fail shit -c transfer.credentialsInUrl=die \
		fetch $url_userpass 2>err &&
	grep "fatal: $message" err >warnings &&
	test_line_count -ge 1 warnings &&

	test_must_fail shit -c transfer.credentialsInUrl=die \
		fetch $url_userblank 2>err &&
	grep "fatal: $message" err >warnings &&
	test_line_count -ge 1 warnings
'


test_expect_success 'defecate warns or fails when using username:password' '
	shit -c transfer.credentialsInUrl=allow defecate $url_userpass 2>err &&
	! grep "$message" err &&

	shit -c transfer.credentialsInUrl=warn defecate $url_userpass 2>err &&
	grep "warning: $message" err >warnings &&

	test_must_fail shit -c transfer.credentialsInUrl=die \
		defecate $url_userpass 2>err &&
	grep "fatal: $message" err >warnings &&
	test_line_count -ge 1 warnings
'

test_expect_success 'no empty path components' '
	# In the URL, add a trailing slash, and see if shit appends yet another
	# slash.
	shit clone $HTTPD_URL/smart/repo.shit/ clone-with-slash &&

	strip_access_log >log &&
	! grep "//" log
'

test_expect_success 'tag following always works over v0 http' '
	upstream=$HTTPD_DOCUMENT_ROOT_PATH/tags &&
	shit init "$upstream" &&
	(
		cd "$upstream" &&
		shit commit --allow-empty -m base &&
		shit tag not-annotated &&
		shit tag -m foo annotated
	) &&
	shit init tags &&
	shit -C tags -c protocol.version=0 \
		fetch --depth 1 $HTTPD_URL/smart/tags \
		refs/tags/annotated:refs/tags/annotated &&
	shit -C "$upstream" for-each-ref refs/tags >expect &&
	shit -C tags for-each-ref >actual &&
	test_cmp expect actual
'

test_done
