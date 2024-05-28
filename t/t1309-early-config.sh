#!/bin/sh

test_description='Test read_early_config()'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'read early config' '
	test_config early.config correct &&
	test-tool config read_early_config early.config >output &&
	test correct = "$(cat output)"
'

test_expect_success 'in a sub-directory' '
	test_config early.config sub &&
	mkdir -p sub &&
	(
		cd sub &&
		test-tool config read_early_config early.config
	) >output &&
	test sub = "$(cat output)"
'

test_expect_success 'ceiling' '
	test_config early.config ceiling &&
	mkdir -p sub &&
	(
		shit_CEILING_DIRECTORIES="$PWD" &&
		export shit_CEILING_DIRECTORIES &&
		cd sub &&
		test-tool config read_early_config early.config
	) >output &&
	test_must_be_empty output
'

test_expect_success 'ceiling #2' '
	mkdir -p xdg/shit &&
	shit config -f xdg/shit/config early.config xdg &&
	test_config early.config ceiling &&
	mkdir -p sub &&
	(
		XDG_CONFIG_HOME="$PWD"/xdg &&
		shit_CEILING_DIRECTORIES="$PWD" &&
		export shit_CEILING_DIRECTORIES XDG_CONFIG_HOME &&
		cd sub &&
		test-tool config read_early_config early.config
	) >output &&
	test xdg = "$(cat output)"
'

cmdline_config="'test.source=cmdline'"
test_expect_success 'read config file in right order' '
	echo "[test]source = home" >>.shitconfig &&
	shit init foo &&
	(
		cd foo &&
		echo "[test]source = repo" >>.shit/config &&
		shit_CONFIG_PARAMETERS=$cmdline_config test-tool config \
			read_early_config test.source >actual &&
		cat >expected <<-\EOF &&
		home
		repo
		cmdline
		EOF
		test_cmp expected actual
	)
'

test_with_config () {
	rm -rf throwaway &&
	shit init throwaway &&
	(
		cd throwaway &&
		echo "$*" >.shit/config &&
		test-tool config read_early_config early.config
	)
}

test_expect_success 'ignore .shit/ with incompatible repository version' '
	test_with_config "[core]repositoryformatversion = 999999" 2>err &&
	test_grep "warning:.* Expected shit repo version <= [1-9]" err
'

test_expect_failure 'ignore .shit/ with invalid repository version' '
	test_with_config "[core]repositoryformatversion = invalid"
'


test_expect_failure 'ignore .shit/ with invalid config' '
	test_with_config "["
'

test_expect_success 'early config and onbranch' '
	echo "[broken" >broken &&
	test_with_config "[includeif \"onbranch:topic\"]path=../broken"
'

test_expect_success 'onbranch config outside of shit repo' '
	test_config_global includeIf.onbranch:topic.path non-existent &&
	nonshit shit help
'

test_done
