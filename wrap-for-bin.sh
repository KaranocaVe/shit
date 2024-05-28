#!/bin/sh

# wrap-for-bin.sh: Template for shit executable wrapper scripts
# to run test suite against sandbox, but with only bindir-installed
# executables in PATH.  The Makefile copies this into various
# files in bin-wrappers, substituting
# @@BUILD_DIR@@ and @@PROG@@.

shit_EXEC_PATH='@@BUILD_DIR@@'
if test -n "$NO_SET_shit_TEMPLATE_DIR"
then
	unset shit_TEMPLATE_DIR
else
	shit_TEMPLATE_DIR='@@BUILD_DIR@@/templates/blt'
	export shit_TEMPLATE_DIR
fi
shitPERLLIB='@@BUILD_DIR@@/perl/build/lib'"${shitPERLLIB:+:$shitPERLLIB}"
shit_TEXTDOMAINDIR='@@BUILD_DIR@@/po/build/locale'
PATH='@@BUILD_DIR@@/bin-wrappers:'"$PATH"

export shit_EXEC_PATH shitPERLLIB PATH shit_TEXTDOMAINDIR

case "$shit_DEBUGGER" in
'')
	exec "${shit_EXEC_PATH}/@@PROG@@" "$@"
	;;
1)
	unset shit_DEBUGGER
	exec gdb --args "${shit_EXEC_PATH}/@@PROG@@" "$@"
	;;
*)
	shit_DEBUGGER_ARGS="$shit_DEBUGGER"
	unset shit_DEBUGGER
	exec ${shit_DEBUGGER_ARGS} "${shit_EXEC_PATH}/@@PROG@@" "$@"
	;;
esac
