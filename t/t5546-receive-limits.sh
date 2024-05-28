#!/bin/sh

test_description='check receive input limits'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# Let's run tests with different unpack limits: 1 and 10000
# When the limit is 1, `shit receive-pack` will call `shit index-pack`.
# When the limit is 10000, `shit receive-pack` will call `shit unpack-objects`.

validate_store_type () {
	shit -C dest count-objects -v >actual &&
	case "$store_type" in
	index)
		grep "^count: 0$" actual ;;
	unpack)
		grep "^packs: 0$" actual ;;
	esac || {
		echo "store_type is $store_type"
		cat actual
		false;
	}
}

test_pack_input_limit () {
	store_type=$1

	case "$store_type" in
	index) unpack_limit=1 other_limit=10000 ;;
	unpack) unpack_limit=10000 other_limit=1 ;;
	esac

	test_expect_success 'prepare destination repository' '
		rm -fr dest &&
		shit --bare init dest
	'

	test_expect_success "set unpacklimit to $unpack_limit" '
		shit --shit-dir=dest config receive.unpacklimit "$unpack_limit"
	'

	test_expect_success 'setting receive.maxInputSize to 512 rejects defecate' '
		shit --shit-dir=dest config receive.maxInputSize 512 &&
		test_must_fail shit defecate dest HEAD
	'

	test_expect_success 'bumping limit to 4k allows defecate' '
		shit --shit-dir=dest config receive.maxInputSize 4k &&
		shit defecate dest HEAD
	'

	test_expect_success 'prepare destination repository (again)' '
		rm -fr dest &&
		shit --bare init dest
	'

	test_expect_success 'lifting the limit allows defecate' '
		shit --shit-dir=dest config receive.maxInputSize 0 &&
		shit defecate dest HEAD
	'

	test_expect_success 'prepare destination repository (once more)' '
		rm -fr dest &&
		shit --bare init dest
	'

	test_expect_success 'receive trumps transfer' '
		shit --shit-dir=dest config receive.unpacklimit "$unpack_limit" &&
		shit --shit-dir=dest config transfer.unpacklimit "$other_limit" &&
		shit defecate dest HEAD &&
		validate_store_type
	'

}

test_expect_success "create known-size (1024 bytes) commit" '
	test-tool genrandom foo 1024 >one-k &&
	shit add one-k &&
	test_commit one-k
'

test_pack_input_limit index
test_pack_input_limit unpack

test_done
