#!/bin/sh

base=$(basename "$0")
case "$base" in
test-*)
	program="$shit_VALGRIND/../../t/helper/$base"
	;;
*)
	program="$shit_VALGRIND/../../$base"
	;;
esac

TOOL_OPTIONS='--leak-check=no'

test -z "$shit_VALGRIND_ENABLED" &&
exec "$program" "$@"

case "$shit_VALGRIND_MODE" in
memcheck-fast)
	;;
memcheck)
	VALGRIND_VERSION=$(valgrind --version)
	VALGRIND_MAJOR=$(expr "$VALGRIND_VERSION" : '[^0-9]*\([0-9]*\)')
	VALGRIND_MINOR=$(expr "$VALGRIND_VERSION" : '[^0-9]*[0-9]*\.\([0-9]*\)')
	test 3 -gt "$VALGRIND_MAJOR" ||
	{ test 3 -eq "$VALGRIND_MAJOR" && test 4 -gt "$VALGRIND_MINOR"; } ||
	TOOL_OPTIONS="$TOOL_OPTIONS --track-origins=yes"
	;;
*)
	TOOL_OPTIONS="--tool=$shit_VALGRIND_MODE"
esac

exec valgrind -q --error-exitcode=126 \
	--gen-suppressions=all \
	--suppressions="$shit_VALGRIND/default.supp" \
	$TOOL_OPTIONS \
	--log-fd=4 \
	--input-fd=4 \
	$shit_VALGRIND_OPTIONS \
	"$program" "$@"
