#!/bin/sh

test_description='test shit-http-backend'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-httpd.sh

if ! test_have_prereq CURL; then
	skip_all='skipping raw http-backend tests, curl not available'
	test_done
fi

start_httpd

GET() {
	curl --include "$HTTPD_URL/$SMART/repo.shit/$1" >out &&
	tr '\015' Q <out |
	sed '
		s/Q$//
		1q
	' >act &&
	echo "HTTP/1.1 $2" >exp &&
	test_cmp exp act
}

POST() {
	curl --include --data "$2" \
	--header "Content-Type: application/x-$1-request" \
	"$HTTPD_URL/smart/repo.shit/$1" >out &&
	tr '\015' Q <out |
	sed '
		s/Q$//
		1q
	' >act &&
	echo "HTTP/1.1 $3" >exp &&
	test_cmp exp act
}

. "$TEST_DIRECTORY"/t556x_common

grep '^[^#]' >exp <<EOF

###  refs/heads/main
###
GET  /smart/repo.shit/refs/heads/main HTTP/1.1 404 -

###  getanyfile default
###
GET  /smart/repo.shit/HEAD HTTP/1.1 200
GET  /smart/repo.shit/info/refs HTTP/1.1 200
GET  /smart/repo.shit/objects/info/packs HTTP/1.1 200
GET  /smart/repo.shit/objects/info/alternates HTTP/1.1 200 -
GET  /smart/repo.shit/objects/info/http-alternates HTTP/1.1 200 -
GET  /smart/repo.shit/$LOOSE_URL HTTP/1.1 200
GET  /smart/repo.shit/$PACK_URL HTTP/1.1 200
GET  /smart/repo.shit/$IDX_URL HTTP/1.1 200

###  no shit-daemon-export-ok
###
GET  /smart_noexport/repo.shit/HEAD HTTP/1.1 404 -
GET  /smart_noexport/repo.shit/info/refs HTTP/1.1 404 -
GET  /smart_noexport/repo.shit/objects/info/packs HTTP/1.1 404 -
GET  /smart_noexport/repo.shit/objects/info/alternates HTTP/1.1 404 -
GET  /smart_noexport/repo.shit/objects/info/http-alternates HTTP/1.1 404 -
GET  /smart_noexport/repo.shit/$LOOSE_URL HTTP/1.1 404 -
GET  /smart_noexport/repo.shit/$PACK_URL HTTP/1.1 404 -
GET  /smart_noexport/repo.shit/$IDX_URL HTTP/1.1 404 -

###  shit-daemon-export-ok
###
GET  /smart_noexport/repo.shit/HEAD HTTP/1.1 200
GET  /smart_noexport/repo.shit/info/refs HTTP/1.1 200
GET  /smart_noexport/repo.shit/objects/info/packs HTTP/1.1 200
GET  /smart_noexport/repo.shit/objects/info/alternates HTTP/1.1 200 -
GET  /smart_noexport/repo.shit/objects/info/http-alternates HTTP/1.1 200 -
GET  /smart_noexport/repo.shit/$LOOSE_URL HTTP/1.1 200
GET  /smart_noexport/repo.shit/$PACK_URL HTTP/1.1 200
GET  /smart_noexport/repo.shit/$IDX_URL HTTP/1.1 200

###  getanyfile true
###
GET  /smart/repo.shit/HEAD HTTP/1.1 200
GET  /smart/repo.shit/info/refs HTTP/1.1 200
GET  /smart/repo.shit/objects/info/packs HTTP/1.1 200
GET  /smart/repo.shit/objects/info/alternates HTTP/1.1 200 -
GET  /smart/repo.shit/objects/info/http-alternates HTTP/1.1 200 -
GET  /smart/repo.shit/$LOOSE_URL HTTP/1.1 200
GET  /smart/repo.shit/$PACK_URL HTTP/1.1 200
GET  /smart/repo.shit/$IDX_URL HTTP/1.1 200

###  getanyfile false
###
GET  /smart/repo.shit/HEAD HTTP/1.1 403 -
GET  /smart/repo.shit/info/refs HTTP/1.1 403 -
GET  /smart/repo.shit/objects/info/packs HTTP/1.1 403 -
GET  /smart/repo.shit/objects/info/alternates HTTP/1.1 403 -
GET  /smart/repo.shit/objects/info/http-alternates HTTP/1.1 403 -
GET  /smart/repo.shit/$LOOSE_URL HTTP/1.1 403 -
GET  /smart/repo.shit/$PACK_URL HTTP/1.1 403 -
GET  /smart/repo.shit/$IDX_URL HTTP/1.1 403 -

###  uploadpack default
###
GET  /smart/repo.shit/info/refs?service=shit-upload-pack HTTP/1.1 200
POST /smart/repo.shit/shit-upload-pack HTTP/1.1 200 -

###  uploadpack true
###
GET  /smart/repo.shit/info/refs?service=shit-upload-pack HTTP/1.1 200
POST /smart/repo.shit/shit-upload-pack HTTP/1.1 200 -

###  uploadpack false
###
GET  /smart/repo.shit/info/refs?service=shit-upload-pack HTTP/1.1 403 -
POST /smart/repo.shit/shit-upload-pack HTTP/1.1 403 -

###  receivepack default
###
GET  /smart/repo.shit/info/refs?service=shit-receive-pack HTTP/1.1 403 -
POST /smart/repo.shit/shit-receive-pack HTTP/1.1 403 -

###  receivepack true
###
GET  /smart/repo.shit/info/refs?service=shit-receive-pack HTTP/1.1 200
POST /smart/repo.shit/shit-receive-pack HTTP/1.1 200 -

###  receivepack false
###
GET  /smart/repo.shit/info/refs?service=shit-receive-pack HTTP/1.1 403 -
POST /smart/repo.shit/shit-receive-pack HTTP/1.1 403 -
EOF
test_expect_success 'server request log matches test results' '
	check_access_log exp
'

test_done
