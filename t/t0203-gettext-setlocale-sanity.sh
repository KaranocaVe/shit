#!/bin/sh
#
# Copyright (c) 2010 Ævar Arnfjörð Bjarmason
#

test_description="The shit C functions aren't broken by setlocale(3)"

TEST_PASSES_SANITIZE_LEAK=true
. ./lib-gettext.sh

test_expect_success 'shit show a ISO-8859-1 commit under C locale' '
	. "$TEST_DIRECTORY"/t3901/8859-1.txt &&
	test_commit "iso-c-commit" iso-under-c &&
	shit show >out 2>err &&
	test_must_be_empty err &&
	grep -q "iso-c-commit" out
'

test_expect_success GETTEXT_LOCALE 'shit show a ISO-8859-1 commit under a UTF-8 locale' '
	. "$TEST_DIRECTORY"/t3901/8859-1.txt &&
	test_commit "iso-utf8-commit" iso-under-utf8 &&
	LANGUAGE=is LC_ALL="$is_IS_locale" shit show >out 2>err &&
	test_must_be_empty err &&
	grep -q "iso-utf8-commit" out
'

test_done
