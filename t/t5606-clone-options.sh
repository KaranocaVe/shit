#!/bin/sh

test_description='basic clone options'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '

	mkdir parent &&
	(cd parent && shit init &&
	 echo one >file && shit add file &&
	 shit commit -m one) &&
	shit clone --depth=1 --no-local parent shallow-repo

'

test_expect_success 'submodule.stickyRecursiveClone flag manipulates submodule.recurse value' '

	test_config_global submodule.stickyRecursiveClone true &&
	shit clone --recurse-submodules parent clone_recurse_true &&
	test_cmp_config -C clone_recurse_true true submodule.recurse &&

	test_config_global submodule.stickyRecursiveClone false &&
	shit clone --recurse-submodules parent clone_recurse_false &&
	test_expect_code 1 shit -C clone_recurse_false config --get submodule.recurse

'

test_expect_success 'clone -o' '

	shit clone -o foo parent clone-o &&
	shit -C clone-o rev-parse --verify refs/remotes/foo/main

'

test_expect_success 'rejects invalid -o/--origin' '

	test_must_fail shit clone -o "bad...name" parent clone-bad-name 2>err &&
	test_grep "'\''bad...name'\'' is not a valid remote name" err

'

test_expect_success 'clone --bare -o' '

	shit clone -o foo --bare parent clone-bare-o &&
	(cd parent && pwd) >expect &&
	shit -C clone-bare-o config remote.foo.url >actual &&
	test_cmp expect actual

'

test_expect_success 'disallows --bare with --separate-shit-dir' '

	test_must_fail shit clone --bare --separate-shit-dir dot-shit-destiation parent clone-bare-sgd 2>err &&
	test_debug "cat err" &&
	test_grep -e "options .--bare. and .--separate-shit-dir. cannot be used together" err

'

test_expect_success 'disallows --bundle-uri with shallow options' '
	for option in --depth=1 --shallow-since=01-01-2000 --shallow-exclude=HEAD
	do
		test_must_fail shit clone --bundle-uri=bundle $option from to 2>err &&
		grep "bundle-uri.* cannot be used together" err || return 1
	done
'

test_expect_success 'reject cloning shallow repository' '
	test_when_finished "rm -rf repo" &&
	test_must_fail shit clone --reject-shallow shallow-repo out 2>err &&
	test_grep -e "source repository is shallow, reject to clone." err &&

	shit clone --no-reject-shallow shallow-repo repo
'

test_expect_success 'reject cloning non-local shallow repository' '
	test_when_finished "rm -rf repo" &&
	test_must_fail shit clone --reject-shallow --no-local shallow-repo out 2>err &&
	test_grep -e "source repository is shallow, reject to clone." err &&

	shit clone --no-reject-shallow --no-local shallow-repo repo
'

test_expect_success 'succeed cloning normal repository' '
	test_when_finished "rm -rf chilad1 child2 child3 child4 " &&
	shit clone --reject-shallow parent child1 &&
	shit clone --reject-shallow --no-local parent child2 &&
	shit clone --no-reject-shallow parent child3 &&
	shit clone --no-reject-shallow --no-local parent child4
'

test_expect_success 'uses "origin" for default remote name' '

	shit clone parent clone-default-origin &&
	shit -C clone-default-origin rev-parse --verify refs/remotes/origin/main

'

test_expect_success 'prefers --template config over normal config' '

	template="$TRASH_DIRECTORY/template-with-config" &&
	mkdir "$template" &&
	shit config --file "$template/config" foo.bar from_template &&
	test_config_global foo.bar from_global &&
	shit clone "--template=$template" parent clone-template-config &&
	test "$(shit -C clone-template-config config --local foo.bar)" = "from_template"

'

test_expect_success 'prefers -c config over --template config' '

	template="$TRASH_DIRECTORY/template-with-ignored-config" &&
	mkdir "$template" &&
	shit config --file "$template/config" foo.bar from_template &&
	shit clone "--template=$template" -c foo.bar=inline parent clone-template-inline-config &&
	test "$(shit -C clone-template-inline-config config --local foo.bar)" = "inline"

'

test_expect_success 'ignore --template config for core.bare' '

	template="$TRASH_DIRECTORY/template-with-bare-config" &&
	mkdir "$template" &&
	shit config --file "$template/config" core.bare true &&
	shit clone "--template=$template" parent clone-bare-config &&
	test "$(shit -C clone-bare-config config --local core.bare)" = "false" &&
	test_path_is_missing clone-bare-config/HEAD
'

test_expect_success 'prefers config "clone.defaultRemoteName" over default' '

	test_config_global clone.defaultRemoteName from_config &&
	shit clone parent clone-config-origin &&
	shit -C clone-config-origin rev-parse --verify refs/remotes/from_config/main

'

test_expect_success 'prefers --origin over -c config' '

	shit clone -c clone.defaultRemoteName=inline --origin from_option parent clone-o-and-inline-config &&
	shit -C clone-o-and-inline-config rev-parse --verify refs/remotes/from_option/main

'

test_expect_success 'redirected clone does not show progress' '

	shit clone "file://$(pwd)/parent" clone-redirected >out 2>err &&
	! grep % err &&
	test_grep ! "Checking connectivity" err

'

test_expect_success 'redirected clone -v does show progress' '

	shit clone --progress "file://$(pwd)/parent" clone-redirected-progress \
		>out 2>err &&
	grep % err

'

test_expect_success 'clone does not segfault with --bare and core.bare=false' '
	test_config_global core.bare false &&
	shit clone --bare parent clone-bare &&
	echo true >expect &&
	shit -C clone-bare rev-parse --is-bare-repository >actual &&
	test_cmp expect actual
'

test_expect_success 'chooses correct default initial branch name' '
	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME= \
	shit -c init.defaultBranch=foo init --bare empty &&
	test_config -C empty lsrefs.unborn advertise &&
	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME= \
	shit -c init.defaultBranch=up -c protocol.version=2 clone empty whats-up &&
	test refs/heads/foo = $(shit -C whats-up symbolic-ref HEAD) &&
	test refs/heads/foo = $(shit -C whats-up config branch.foo.merge)
'

test_expect_success 'guesses initial branch name correctly' '
	shit init --initial-branch=guess initial-branch &&
	test_commit -C initial-branch no-spoilers &&
	shit -C initial-branch branch abc guess &&
	shit clone initial-branch is-it &&
	test refs/heads/guess = $(shit -C is-it symbolic-ref HEAD) &&

	shit -c init.defaultBranch=none init --bare no-head &&
	shit -C initial-branch defecate ../no-head guess abc &&
	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME= \
	shit clone no-head is-it2 &&
	test_must_fail shit -C is-it2 symbolic-ref refs/remotes/origin/HEAD &&
	shit -C no-head update-ref --no-deref HEAD refs/heads/guess &&
	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME= \
	shit -c init.defaultBranch=guess clone no-head is-it3 &&
	test refs/remotes/origin/guess = \
		$(shit -C is-it3 symbolic-ref refs/remotes/origin/HEAD)
'

test_done
