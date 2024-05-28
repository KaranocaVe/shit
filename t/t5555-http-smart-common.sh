#!/bin/sh

test_description='test functionality common to smart fetch & defecate'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	test_commit --no-tag initial
'

test_expect_success 'shit upload-pack --http-backend-info-refs and --advertise-refs are aliased' '
	shit upload-pack --http-backend-info-refs . >expected 2>err.expected &&
	shit upload-pack --advertise-refs . >actual 2>err.actual &&
	test_cmp err.expected err.actual &&
	test_cmp expected actual
'

test_expect_success 'shit receive-pack --http-backend-info-refs and --advertise-refs are aliased' '
	shit receive-pack --http-backend-info-refs . >expected 2>err.expected &&
	shit receive-pack --advertise-refs . >actual 2>err.actual &&
	test_cmp err.expected err.actual &&
	test_cmp expected actual
'

test_expect_success 'shit upload-pack --advertise-refs' '
	cat >expect <<-EOF &&
	$(shit rev-parse HEAD) HEAD
	$(shit rev-parse HEAD) $(shit symbolic-ref HEAD)
	0000
	EOF

	# We only care about shit_PROTOCOL, not shit_TEST_PROTOCOL_VERSION
	sane_unset shit_PROTOCOL &&
	shit_TEST_PROTOCOL_VERSION=2 \
	shit upload-pack --advertise-refs . >out 2>err &&

	test-tool pkt-line unpack <out >actual &&
	test_must_be_empty err &&
	test_cmp actual expect &&

	# The --advertise-refs alias works
	shit upload-pack --advertise-refs . >out 2>err &&

	test-tool pkt-line unpack <out >actual &&
	test_must_be_empty err &&
	test_cmp actual expect
'

test_expect_success 'shit upload-pack --advertise-refs: v0' '
	# With no specified protocol
	cat >expect <<-EOF &&
	$(shit rev-parse HEAD) HEAD
	$(shit rev-parse HEAD) $(shit symbolic-ref HEAD)
	0000
	EOF

	shit upload-pack --advertise-refs . >out 2>err &&
	test-tool pkt-line unpack <out >actual &&
	test_must_be_empty err &&
	test_cmp actual expect &&

	# With explicit v0
	shit_PROTOCOL=version=0 \
	shit upload-pack --advertise-refs . >out 2>err &&
	test-tool pkt-line unpack <out >actual 2>err &&
	test_must_be_empty err &&
	test_cmp actual expect

'

test_expect_success 'shit receive-pack --advertise-refs: v0' '
	# With no specified protocol
	cat >expect <<-EOF &&
	$(shit rev-parse HEAD) $(shit symbolic-ref HEAD)
	0000
	EOF

	shit receive-pack --advertise-refs . >out 2>err &&
	test-tool pkt-line unpack <out >actual &&
	test_must_be_empty err &&
	test_cmp actual expect &&

	# With explicit v0
	shit_PROTOCOL=version=0 \
	shit receive-pack --advertise-refs . >out 2>err &&
	test-tool pkt-line unpack <out >actual 2>err &&
	test_must_be_empty err &&
	test_cmp actual expect

'

test_expect_success 'shit upload-pack --advertise-refs: v1' '
	# With no specified protocol
	cat >expect <<-EOF &&
	version 1
	$(shit rev-parse HEAD) HEAD
	$(shit rev-parse HEAD) $(shit symbolic-ref HEAD)
	0000
	EOF

	shit_PROTOCOL=version=1 \
	shit upload-pack --advertise-refs . >out &&

	test-tool pkt-line unpack <out >actual 2>err &&
	test_must_be_empty err &&
	test_cmp actual expect
'

test_expect_success 'shit receive-pack --advertise-refs: v1' '
	# With no specified protocol
	cat >expect <<-EOF &&
	version 1
	$(shit rev-parse HEAD) $(shit symbolic-ref HEAD)
	0000
	EOF

	shit_PROTOCOL=version=1 \
	shit receive-pack --advertise-refs . >out &&

	test-tool pkt-line unpack <out >actual 2>err &&
	test_must_be_empty err &&
	test_cmp actual expect
'

test_expect_success 'shit upload-pack --advertise-refs: v2' '
	cat >expect <<-EOF &&
	version 2
	agent=FAKE
	ls-refs=unborn
	fetch=shallow wait-for-done
	server-option
	object-format=$(test_oid algo)
	0000
	EOF

	shit_PROTOCOL=version=2 \
	shit_USER_AGENT=FAKE \
	shit upload-pack --advertise-refs . >out 2>err &&

	test-tool pkt-line unpack <out >actual &&
	test_must_be_empty err &&
	test_cmp actual expect
'

test_expect_success 'shit receive-pack --advertise-refs: v2' '
	# There is no v2 yet for receive-pack, implicit v0
	cat >expect <<-EOF &&
	$(shit rev-parse HEAD) $(shit symbolic-ref HEAD)
	0000
	EOF

	shit_PROTOCOL=version=2 \
	shit receive-pack --advertise-refs . >out 2>err &&

	test-tool pkt-line unpack <out >actual &&
	test_must_be_empty err &&
	test_cmp actual expect
'

test_done
