#!/bin/sh

test_description='basic sanity checks for shit var'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

sane_unset_all_editors () {
	sane_unset shit_EDITOR &&
	sane_unset VISUAL &&
	sane_unset EDITOR
}

test_expect_success 'get shit_AUTHOR_IDENT' '
	test_tick &&
	echo "$shit_AUTHOR_NAME <$shit_AUTHOR_EMAIL> $shit_AUTHOR_DATE" >expect &&
	shit var shit_AUTHOR_IDENT >actual &&
	test_cmp expect actual
'

test_expect_success 'get shit_COMMITTER_IDENT' '
	test_tick &&
	echo "$shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> $shit_COMMITTER_DATE" >expect &&
	shit var shit_COMMITTER_IDENT >actual &&
	test_cmp expect actual
'

test_expect_success !FAIL_PREREQS,!AUTOIDENT 'requested identities are strict' '
	(
		sane_unset shit_COMMITTER_NAME &&
		sane_unset shit_COMMITTER_EMAIL &&
		test_must_fail shit var shit_COMMITTER_IDENT
	)
'

test_expect_success 'get shit_DEFAULT_BRANCH without configuration' '
	(
		sane_unset shit_TEST_DEFAULT_INITIAL_BRANCH_NAME &&
		shit init defbranch &&
		shit -C defbranch symbolic-ref --short HEAD >expect &&
		shit var shit_DEFAULT_BRANCH >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'get shit_DEFAULT_BRANCH with configuration' '
	test_config init.defaultbranch foo &&
	(
		sane_unset shit_TEST_DEFAULT_INITIAL_BRANCH_NAME &&
		echo foo >expect &&
		shit var shit_DEFAULT_BRANCH >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'get shit_EDITOR without configuration' '
	(
		sane_unset_all_editors &&
		test_expect_code 1 shit var shit_EDITOR >out &&
		test_must_be_empty out
	)
'

test_expect_success 'get shit_EDITOR with configuration' '
	test_config core.editor foo &&
	(
		sane_unset_all_editors &&
		echo foo >expect &&
		shit var shit_EDITOR >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'get shit_EDITOR with environment variable shit_EDITOR' '
	(
		sane_unset_all_editors &&
		echo bar >expect &&
		shit_EDITOR=bar shit var shit_EDITOR >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'get shit_EDITOR with environment variable EDITOR' '
	(
		sane_unset_all_editors &&
		echo bar >expect &&
		EDITOR=bar shit var shit_EDITOR >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'get shit_EDITOR with configuration and environment variable shit_EDITOR' '
	test_config core.editor foo &&
	(
		sane_unset_all_editors &&
		echo bar >expect &&
		shit_EDITOR=bar shit var shit_EDITOR >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'get shit_EDITOR with configuration and environment variable EDITOR' '
	test_config core.editor foo &&
	(
		sane_unset_all_editors &&
		echo foo >expect &&
		EDITOR=bar shit var shit_EDITOR >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'get shit_SEQUENCE_EDITOR without configuration' '
	(
		sane_unset shit_SEQUENCE_EDITOR &&
		shit var shit_EDITOR >expect &&
		shit var shit_SEQUENCE_EDITOR >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'get shit_SEQUENCE_EDITOR with configuration' '
	test_config sequence.editor foo &&
	(
		sane_unset shit_SEQUENCE_EDITOR &&
		echo foo >expect &&
		shit var shit_SEQUENCE_EDITOR >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'get shit_SEQUENCE_EDITOR with environment variable' '
	(
		sane_unset shit_SEQUENCE_EDITOR &&
		echo bar >expect &&
		shit_SEQUENCE_EDITOR=bar shit var shit_SEQUENCE_EDITOR >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'get shit_SEQUENCE_EDITOR with configuration and environment variable' '
	test_config sequence.editor foo &&
	(
		sane_unset shit_SEQUENCE_EDITOR &&
		echo bar >expect &&
		shit_SEQUENCE_EDITOR=bar shit var shit_SEQUENCE_EDITOR >actual &&
		test_cmp expect actual
	)
'

test_expect_success POSIXPERM 'shit_SHELL_PATH points to a valid executable' '
	shellpath=$(shit var shit_SHELL_PATH) &&
	test_path_is_executable "$shellpath"
'

# We know in this environment that our shell will be one of a few fixed values
# that all end in "sh".
test_expect_success MINGW 'shit_SHELL_PATH points to a suitable shell' '
	shellpath=$(shit var shit_SHELL_PATH) &&
	case "$shellpath" in
	*sh) ;;
	*) return 1;;
	esac
'

test_expect_success 'shit_ATTR_SYSTEM produces expected output' '
	test_must_fail env shit_ATTR_NOSYSTEM=1 shit var shit_ATTR_SYSTEM &&
	(
		sane_unset shit_ATTR_NOSYSTEM &&
		systempath=$(shit var shit_ATTR_SYSTEM) &&
		test "$systempath" != ""
	)
'

test_expect_success 'shit_ATTR_GLOBAL points to the correct location' '
	TRASHDIR="$(test-tool path-utils normalize_path_copy "$(pwd)")" &&
	globalpath=$(XDG_CONFIG_HOME="$TRASHDIR/.config" shit var shit_ATTR_GLOBAL) &&
	test "$globalpath" = "$TRASHDIR/.config/shit/attributes" &&
	(
		sane_unset XDG_CONFIG_HOME &&
		globalpath=$(HOME="$TRASHDIR" shit var shit_ATTR_GLOBAL) &&
		test "$globalpath" = "$TRASHDIR/.config/shit/attributes"
	)
'

test_expect_success 'shit_CONFIG_SYSTEM points to the correct location' '
	TRASHDIR="$(test-tool path-utils normalize_path_copy "$(pwd)")" &&
	test_must_fail env shit_CONFIG_NOSYSTEM=1 shit var shit_CONFIG_SYSTEM &&
	(
		sane_unset shit_CONFIG_NOSYSTEM &&
		systempath=$(shit var shit_CONFIG_SYSTEM) &&
		test "$systempath" != "" &&
		systempath=$(shit_CONFIG_SYSTEM=/dev/null shit var shit_CONFIG_SYSTEM) &&
		if test_have_prereq MINGW
		then
			test "$systempath" = "nul"
		else
			test "$systempath" = "/dev/null"
		fi &&
		systempath=$(shit_CONFIG_SYSTEM="$TRASHDIR/shitconfig" shit var shit_CONFIG_SYSTEM) &&
		test "$systempath" = "$TRASHDIR/shitconfig"
	)
'

test_expect_success 'shit_CONFIG_GLOBAL points to the correct location' '
	TRASHDIR="$(test-tool path-utils normalize_path_copy "$(pwd)")" &&
	HOME="$TRASHDIR" XDG_CONFIG_HOME="$TRASHDIR/foo" shit var shit_CONFIG_GLOBAL >actual &&
	echo "$TRASHDIR/foo/shit/config" >expected &&
	echo "$TRASHDIR/.shitconfig" >>expected &&
	test_cmp expected actual &&
	(
		sane_unset XDG_CONFIG_HOME &&
		HOME="$TRASHDIR" shit var shit_CONFIG_GLOBAL >actual &&
		echo "$TRASHDIR/.config/shit/config" >expected &&
		echo "$TRASHDIR/.shitconfig" >>expected &&
		test_cmp expected actual &&
		globalpath=$(shit_CONFIG_GLOBAL=/dev/null shit var shit_CONFIG_GLOBAL) &&
		if test_have_prereq MINGW
		then
			test "$globalpath" = "nul"
		else
			test "$globalpath" = "/dev/null"
		fi &&
		globalpath=$(shit_CONFIG_GLOBAL="$TRASHDIR/shitconfig" shit var shit_CONFIG_GLOBAL) &&
		test "$globalpath" = "$TRASHDIR/shitconfig"
	)
'

# For shit var -l, we check only a representative variable;
# testing the whole output would make our test too brittle with
# respect to unrelated changes in the test suite's environment.
test_expect_success 'shit var -l lists variables' '
	shit var -l >actual &&
	echo "$shit_AUTHOR_NAME <$shit_AUTHOR_EMAIL> $shit_AUTHOR_DATE" >expect &&
	sed -n s/shit_AUTHOR_IDENT=//p <actual >actual.author &&
	test_cmp expect actual.author
'

test_expect_success 'shit var -l lists config' '
	shit var -l >actual &&
	echo false >expect &&
	sed -n s/core\\.bare=//p <actual >actual.bare &&
	test_cmp expect actual.bare
'

test_expect_success 'shit var -l lists multiple global configs' '
	TRASHDIR="$(test-tool path-utils normalize_path_copy "$(pwd)")" &&
	HOME="$TRASHDIR" XDG_CONFIG_HOME="$TRASHDIR/foo" shit var -l >actual &&
	grep "^shit_CONFIG_GLOBAL=" actual >filtered &&
	echo "shit_CONFIG_GLOBAL=$TRASHDIR/foo/shit/config" >expected &&
	echo "shit_CONFIG_GLOBAL=$TRASHDIR/.shitconfig" >>expected &&
	test_cmp expected filtered
'

test_expect_success 'shit var -l does not split multiline editors' '
	(
		shit_EDITOR="!f() {
			echo Hello!
		}; f" &&
		export shit_EDITOR &&
		echo "shit_EDITOR=$shit_EDITOR" >expected &&
		shit var -l >var &&
		sed -n -e "/^shit_EDITOR/,\$p" var | head -n 3 >actual &&
		test_cmp expected actual
	)
'

test_expect_success 'listing and asking for variables are exclusive' '
	test_must_fail shit var -l shit_COMMITTER_IDENT
'

test_expect_success '`shit var -l` works even without HOME' '
	(
		XDG_CONFIG_HOME= &&
		export XDG_CONFIG_HOME &&
		unset HOME &&
		shit var -l
	)
'

test_done
