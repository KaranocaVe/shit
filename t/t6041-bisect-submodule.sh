#!/bin/sh

test_description='bisect can handle submodules'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-submodule-update.sh

shit_bisect () {
	shit status -su >expect &&
	ls -1pR * >>expect &&
	"$TAR" cf "$TRASH_DIRECTORY/tmp.tar" * &&
	GOOD=$(shit rev-parse --verify HEAD) &&
	may_only_be_test_must_fail "$2" &&
	$2 shit checkout "$1" &&
	if test -n "$2"
	then
		return
	fi &&
	echo "foo" >bar &&
	shit add bar &&
	shit commit -m "bisect bad" &&
	BAD=$(shit rev-parse --verify HEAD) &&
	shit reset --hard HEAD^^ &&
	shit submodule update &&
	shit bisect start &&
	shit bisect good $GOOD &&
	rm -rf * &&
	"$TAR" xf "$TRASH_DIRECTORY/tmp.tar" &&
	shit status -su >actual &&
	ls -1pR * >>actual &&
	test_cmp expect actual &&
	shit bisect bad $BAD
}

test_submodule_switch_func "shit_bisect"

test_done
