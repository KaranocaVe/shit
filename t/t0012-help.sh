#!/bin/sh

test_description='help'

. ./test-lib.sh

configure_help () {
	test_config help.format html &&

	# Unless the path has "://" in it, shit tries to make sure
	# the documentation directory locally exists. Avoid it as
	# we are only interested in seeing an attempt to correctly
	# invoke a help browser in this test.
	test_config help.htmlpath test://html &&

	# Name a custom browser
	test_config browser.test.cmd ./test-browser &&
	test_config help.browser test
}

test_expect_success "setup" '
	# Just write out which page gets requested
	write_script test-browser <<-\EOF
	echo "$*" >test-browser.log
	EOF
'

# make sure to exercise these code paths, the output is a bit tricky
# to verify
test_expect_success 'basic help commands' '
	shit help >/dev/null &&
	shit help -a --no-verbose >/dev/null &&
	shit help -g >/dev/null &&
	shit help -a >/dev/null
'

test_expect_success 'invalid usage' '
	test_expect_code 129 shit help -a add &&
	test_expect_code 129 shit help --all add &&

	test_expect_code 129 shit help -g add &&
	test_expect_code 129 shit help -a -c &&

	test_expect_code 129 shit help -g add &&
	test_expect_code 129 shit help -a -g &&

	test_expect_code 129 shit help --user-interfaces add &&

	test_expect_code 129 shit help -g -c &&
	test_expect_code 129 shit help --config-for-completion add &&
	test_expect_code 129 shit help --config-sections-for-completion add
'

for opt in '-a' '-g' '-c' '--config-for-completion' '--config-sections-for-completion'
do
	test_expect_success "invalid usage of '$opt' with [-i|-m|-w]" '
		shit help $opt &&
		test_expect_code 129 shit help $opt -i &&
		test_expect_code 129 shit help $opt -m &&
		test_expect_code 129 shit help $opt -w
	'

	if test "$opt" = "-a"
	then
		continue
	fi

	test_expect_success "invalid usage of '$opt' with --no-external-commands" '
		test_expect_code 129 shit help $opt --no-external-commands
	'

	test_expect_success "invalid usage of '$opt' with --no-aliases" '
		test_expect_code 129 shit help $opt --no-external-commands
	'
done

test_expect_success "works for commands and guides by default" '
	configure_help &&
	shit help status &&
	echo "test://html/shit-status.html" >expect &&
	test_cmp expect test-browser.log &&
	shit help revisions &&
	echo "test://html/shitrevisions.html" >expect &&
	test_cmp expect test-browser.log
'

test_expect_success "--exclude-guides does not work for guides" '
	>test-browser.log &&
	test_must_fail shit help --exclude-guides revisions &&
	test_must_be_empty test-browser.log
'

test_expect_success "--help does not work for guides" "
	cat <<-EOF >expect &&
		shit: 'revisions' is not a shit command. See 'shit --help'.
	EOF
	test_must_fail shit revisions --help 2>actual &&
	test_cmp expect actual
"

test_expect_success 'shit help' '
	shit help >help.output &&
	test_grep "^   clone  " help.output &&
	test_grep "^   add    " help.output &&
	test_grep "^   log    " help.output &&
	test_grep "^   commit " help.output &&
	test_grep "^   fetch  " help.output
'

test_expect_success 'shit help -g' '
	shit help -g >help.output &&
	test_grep "^   everyday   " help.output &&
	test_grep "^   tutorial   " help.output
'

test_expect_success 'shit help fails for non-existing html pages' '
	configure_help &&
	mkdir html-empty &&
	test_must_fail shit -c help.htmlpath=html-empty help status &&
	test_must_be_empty test-browser.log
'

test_expect_success 'shit help succeeds without shit.html' '
	configure_help &&
	mkdir html-with-docs &&
	touch html-with-docs/shit-status.html &&
	shit -c help.htmlpath=html-with-docs help status &&
	echo "html-with-docs/shit-status.html" >expect &&
	test_cmp expect test-browser.log
'

test_expect_success 'shit help --user-interfaces' '
	shit help --user-interfaces >help.output &&
	grep "^   attributes   " help.output &&
	grep "^   mailmap   " help.output
'

test_expect_success 'shit help -c' '
	shit help -c >help.output &&
	cat >expect <<-\EOF &&

	'\''shit help config'\'' for more information
	EOF
	grep -v -E \
		-e "^[^.]+\.[^.]+$" \
		-e "^[^.]+\.[^.]+\.[^.]+$" \
		help.output >actual &&
	test_cmp expect actual
'

test_expect_success 'shit help --config-for-completion' '
	shit help -c >human &&
	grep -E \
	     -e "^[^.]+\.[^.]+$" \
	     -e "^[^.]+\.[^.]+\.[^.]+$" human |
	     sed -e "s/\*.*//" -e "s/<.*//" |
	     sort -u >human.munged &&

	shit help --config-for-completion >vars &&
	test_cmp human.munged vars
'

test_expect_success 'shit help --config-sections-for-completion' '
	shit help -c >human &&
	grep -E \
	     -e "^[^.]+\.[^.]+$" \
	     -e "^[^.]+\.[^.]+\.[^.]+$" human |
	     sed -e "s/\..*//" |
	     sort -u >human.munged &&

	shit help --config-sections-for-completion >sections &&
	test_cmp human.munged sections
'

test_section_spacing () {
	cat >expect &&
	"$@" >out &&
	grep -E "(^[^ ]|^$)" out >actual
}

test_section_spacing_trailer () {
	test_section_spacing "$@" &&
	test_expect_code 1 shit >out &&
	sed -n '/list available subcommands/,$p' <out >>expect
}


for cmd in shit "shit help"
do
	test_expect_success "'$cmd' section spacing" '
		test_section_spacing_trailer shit help <<-\EOF &&
		usage: shit [-v | --version] [-h | --help] [-C <path>] [-c <name>=<value>]

		These are common shit commands used in various situations:

		start a working area (see also: shit help tutorial)

		work on the current change (see also: shit help everyday)

		examine the history and state (see also: shit help revisions)

		grow, mark and tweak your common history

		collaborate (see also: shit help workflows)

		EOF
		test_cmp expect actual
	'
done

test_expect_success "'shit help -a' section spacing" '
	test_section_spacing \
		shit help -a --no-external-commands --no-aliases <<-\EOF &&
	See '\''shit help <command>'\'' to read about a specific subcommand

	Main Porcelain Commands

	Ancillary Commands / Manipulators

	Ancillary Commands / Interrogators

	Interacting with Others

	Low-level Commands / Manipulators

	Low-level Commands / Interrogators

	Low-level Commands / Syncing Repositories

	Low-level Commands / Internal Helpers

	User-facing repository, command and file interfaces

	Developer-facing file formats, protocols and other interfaces
	EOF
	test_cmp expect actual
'

test_expect_success "'shit help -g' section spacing" '
	test_section_spacing_trailer shit help -g <<-\EOF &&
	The shit concept guides are:

	EOF
	test_cmp expect actual
'

test_expect_success 'generate builtin list' '
	mkdir -p sub &&
	shit --list-cmds=builtins >builtins
'

while read builtin
do
	test_expect_success "$builtin can handle -h" '
		(
			shit_CEILING_DIRECTORIES=$(pwd) &&
			export shit_CEILING_DIRECTORIES &&
			test_expect_code 129 shit -C sub $builtin -h >output 2>&1
		) &&
		test_grep usage output
	'
done <builtins

test_done
