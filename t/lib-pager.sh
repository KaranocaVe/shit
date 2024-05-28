# Helpers for tests of shit's choice of pager.

test_expect_success 'determine default pager' '
	test_might_fail shit config --unset core.pager &&
	less=$(
		sane_unset PAGER shit_PAGER &&
		shit var shit_PAGER
	) &&
	test -n "$less"
'

if expr "$less" : '[a-z][a-z]*$' >/dev/null
then
	test_set_prereq SIMPLEPAGER
fi
