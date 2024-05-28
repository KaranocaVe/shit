#!/bin/sh

test_description='tests for shit clone -c key=value'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'clone -c sets config in cloned repo' '
	rm -rf child &&
	shit clone -c core.foo=bar . child &&
	echo bar >expect &&
	shit --shit-dir=child/.shit config core.foo >actual &&
	test_cmp expect actual
'

test_expect_success 'clone -c can set multi-keys' '
	rm -rf child &&
	shit clone -c core.foo=bar -c core.foo=baz . child &&
	test_write_lines bar baz >expect &&
	shit --shit-dir=child/.shit config --get-all core.foo >actual &&
	test_cmp expect actual
'

test_expect_success 'clone -c can set multi-keys, including some empty' '
	rm -rf child &&
	shit clone -c credential.helper= -c credential.helper=hi . child &&
	printf "%s\n" "" hi >expect &&
	shit --shit-dir=child/.shit config --get-all credential.helper >actual &&
	test_cmp expect actual
'

test_expect_success 'clone -c without a value is boolean true' '
	rm -rf child &&
	shit clone -c core.foo . child &&
	echo true >expect &&
	shit --shit-dir=child/.shit config --bool core.foo >actual &&
	test_cmp expect actual
'

test_expect_success 'clone -c config is available during clone' '
	echo content >file &&
	shit add file &&
	shit commit -m one &&
	rm -rf child &&
	shit clone -c core.autocrlf . child &&
	printf "content\\r\\n" >expect &&
	test_cmp expect child/file
'

test_expect_success 'clone -c remote.origin.fetch=<refspec> works' '
	rm -rf child &&
	shit update-ref refs/grab/it refs/heads/main &&
	shit update-ref refs/leave/out refs/heads/main &&
	shit clone -c "remote.origin.fetch=+refs/grab/*:refs/grab/*" . child &&
	shit -C child for-each-ref --format="%(refname)" >actual &&

	cat >expect <<-\EOF &&
	refs/grab/it
	refs/heads/main
	refs/remotes/origin/HEAD
	refs/remotes/origin/main
	EOF
	test_cmp expect actual
'

test_expect_success 'shit -c remote.origin.fetch=<refspec> clone works' '
	rm -rf child &&
	shit -c "remote.origin.fetch=+refs/grab/*:refs/grab/*" clone . child &&
	shit -C child for-each-ref --format="%(refname)" >actual &&

	cat >expect <<-\EOF &&
	refs/grab/it
	refs/heads/main
	refs/remotes/origin/HEAD
	refs/remotes/origin/main
	EOF
	test_cmp expect actual
'

test_expect_success 'clone -c remote.<remote>.fetch=<refspec> --origin=<name>' '
	rm -rf child &&
	shit clone --origin=upstream \
		  -c "remote.upstream.fetch=+refs/grab/*:refs/grab/*" \
		  -c "remote.origin.fetch=+refs/leave/*:refs/leave/*" \
		  . child &&
	shit -C child for-each-ref --format="%(refname)" >actual &&

	cat >expect <<-\EOF &&
	refs/grab/it
	refs/heads/main
	refs/remotes/upstream/HEAD
	refs/remotes/upstream/main
	EOF
	test_cmp expect actual
'

test_expect_success 'set up shallow repository' '
	shit clone --depth=1 --no-local . shallow-repo
'

test_expect_success 'clone.rejectshallow=true should reject cloning shallow repo' '
	test_when_finished "rm -rf out" &&
	test_must_fail shit -c clone.rejectshallow=true clone --no-local shallow-repo out 2>err &&
	test_grep -e "source repository is shallow, reject to clone." err &&

	shit -c clone.rejectshallow=false clone --no-local shallow-repo out
'

test_expect_success 'option --[no-]reject-shallow override clone.rejectshallow config' '
	test_when_finished "rm -rf out" &&
	test_must_fail shit -c clone.rejectshallow=false clone --reject-shallow --no-local shallow-repo out 2>err &&
	test_grep -e "source repository is shallow, reject to clone." err &&

	shit -c clone.rejectshallow=true clone --no-reject-shallow --no-local shallow-repo out
'

test_expect_success 'clone.rejectshallow=true should succeed cloning normal repo' '
	test_when_finished "rm -rf out" &&
	shit -c clone.rejectshallow=true clone --no-local . out
'

test_expect_success MINGW 'clone -c core.hideDotFiles' '
	test_commit attributes .shitattributes "" &&
	rm -rf child &&
	shit clone -c core.hideDotFiles=false . child &&
	! test_path_is_hidden child/.shitattributes &&
	rm -rf child &&
	shit clone -c core.hideDotFiles=dotshitOnly . child &&
	! test_path_is_hidden child/.shitattributes &&
	rm -rf child &&
	shit clone -c core.hideDotFiles=true . child &&
	test_path_is_hidden child/.shitattributes
'

test_done
