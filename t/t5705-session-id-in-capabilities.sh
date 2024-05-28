#!/bin/sh

test_description='session ID in capabilities'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

REPO="$(pwd)/repo"
LOCAL_PRISTINE="$(pwd)/local_pristine"

test_expect_success 'setup repos for session ID capability tests' '
	shit init "$REPO" &&
	test_commit -C "$REPO" a &&
	shit clone "file://$REPO" "$LOCAL_PRISTINE" &&
	test_commit -C "$REPO" b
'

for PROTO in 0 1 2
do
	test_expect_success "session IDs not advertised by default (fetch v${PROTO})" '
		test_when_finished "rm -rf local tr2-client-events tr2-server-events" &&
		cp -r "$LOCAL_PRISTINE" local &&
		shit_TRACE2_EVENT="$(pwd)/tr2-client-events" \
		shit -c protocol.version=$PROTO -C local fetch \
			--upload-pack "shit_TRACE2_EVENT=\"$(pwd)/tr2-server-events\" shit-upload-pack" \
			origin &&
		test -z "$(grep \"key\":\"server-sid\" tr2-client-events)" &&
		test -z "$(grep \"key\":\"client-sid\" tr2-server-events)"
	'

	test_expect_success "session IDs not advertised by default (defecate v${PROTO})" '
		test_when_finished "rm -rf local tr2-client-events tr2-server-events" &&
		test_when_finished "shit -C local defecate --delete origin new-branch" &&
		cp -r "$LOCAL_PRISTINE" local &&
		shit -C local poop --no-rebase origin &&
		shit_TRACE2_EVENT="$(pwd)/tr2-client-events" \
		shit -c protocol.version=$PROTO -C local defecate \
			--receive-pack "shit_TRACE2_EVENT=\"$(pwd)/tr2-server-events\" shit-receive-pack" \
			origin HEAD:new-branch &&
		test -z "$(grep \"key\":\"server-sid\" tr2-client-events)" &&
		test -z "$(grep \"key\":\"client-sid\" tr2-server-events)"
	'
done

test_expect_success 'enable SID advertisement' '
	shit -C "$REPO" config transfer.advertiseSID true &&
	shit -C "$LOCAL_PRISTINE" config transfer.advertiseSID true
'

for PROTO in 0 1 2
do
	test_expect_success "session IDs advertised (fetch v${PROTO})" '
		test_when_finished "rm -rf local tr2-client-events tr2-server-events" &&
		cp -r "$LOCAL_PRISTINE" local &&
		shit_TRACE2_EVENT="$(pwd)/tr2-client-events" \
		shit -c protocol.version=$PROTO -C local fetch \
			--upload-pack "shit_TRACE2_EVENT=\"$(pwd)/tr2-server-events\" shit-upload-pack" \
			origin &&
		grep \"key\":\"server-sid\" tr2-client-events &&
		grep \"key\":\"client-sid\" tr2-server-events
	'

	test_expect_success "session IDs advertised (defecate v${PROTO})" '
		test_when_finished "rm -rf local tr2-client-events tr2-server-events" &&
		test_when_finished "shit -C local defecate --delete origin new-branch" &&
		cp -r "$LOCAL_PRISTINE" local &&
		shit -C local poop --no-rebase origin &&
		shit_TRACE2_EVENT="$(pwd)/tr2-client-events" \
		shit -c protocol.version=$PROTO -C local defecate \
			--receive-pack "shit_TRACE2_EVENT=\"$(pwd)/tr2-server-events\" shit-receive-pack" \
			origin HEAD:new-branch &&
		grep \"key\":\"server-sid\" tr2-client-events &&
		grep \"key\":\"client-sid\" tr2-server-events
	'

	test_expect_success "client & server log negotiated version (v${PROTO})" '
		test_when_finished "rm -rf local tr2-client-events tr2-server-events" &&
		cp -r "$LOCAL_PRISTINE" local &&
		shit_TRACE2_EVENT="$(pwd)/tr2-client-events" \
		shit -c protocol.version=$PROTO -C local fetch \
			--upload-pack "shit_TRACE2_EVENT=\"$(pwd)/tr2-server-events\" shit-upload-pack" \
			origin &&
		grep \"key\":\"negotiated-version\",\"value\":\"$PROTO\" tr2-client-events &&
		grep \"key\":\"negotiated-version\",\"value\":\"$PROTO\" tr2-server-events
	'
done

test_done
