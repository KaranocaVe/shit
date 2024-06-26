#!/bin/sh
#

test_description='shit web--browse basic tests

This test checks that shit web--browse can handle various valid URLs.'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_web_browse () {
	# browser=$1 url=$2
	shit web--browse --browser="$1" "$2" >actual &&
	tr -d '\015' <actual >text &&
	test_cmp expect text
}

test_expect_success \
	'URL with an ampersand in it' '
	echo http://example.com/foo\&bar >expect &&
	shit config browser.custom.cmd echo &&
	test_web_browse custom http://example.com/foo\&bar
'

test_expect_success \
	'URL with a semi-colon in it' '
	echo http://example.com/foo\;bar >expect &&
	shit config browser.custom.cmd echo &&
	test_web_browse custom http://example.com/foo\;bar
'

test_expect_success \
	'URL with a hash in it' '
	echo http://example.com/foo#bar >expect &&
	shit config browser.custom.cmd echo &&
	test_web_browse custom http://example.com/foo#bar
'

test_expect_success \
	'browser paths are properly quoted' '
	echo fake: http://example.com/foo >expect &&
	cat >"fake browser" <<-\EOF &&
	#!/bin/sh
	echo fake: "$@"
	EOF
	chmod +x "fake browser" &&
	shit config browser.w3m.path "$(pwd)/fake browser" &&
	test_web_browse w3m http://example.com/foo
'

test_expect_success \
	'browser command allows arbitrary shell code' '
	echo "arg: http://example.com/foo" >expect &&
	shit config browser.custom.cmd "
		f() {
			for i in \"\$@\"; do
				echo arg: \$i
			done
		}
		f" &&
	test_web_browse custom http://example.com/foo
'

test_done
