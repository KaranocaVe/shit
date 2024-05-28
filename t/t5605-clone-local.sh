#!/bin/sh

test_description='test local clone'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

repo_is_hardlinked() {
	find "$1/objects" -type f -links 1 >output &&
	test_line_count = 0 output
}

test_expect_success 'preparing origin repository' '
	: >file && shit add . && shit commit -m1 &&
	shit clone --bare . a.shit &&
	shit clone --bare . x &&
	echo true >expect &&
	shit -C a.shit config --bool core.bare >actual &&
	test_cmp expect actual &&
	echo true >expect &&
	shit -C x config --bool core.bare >actual &&
	test_cmp expect actual &&
	shit bundle create b1.bundle --all &&
	shit bundle create b2.bundle main &&
	mkdir dir &&
	cp b1.bundle dir/b3 &&
	cp b1.bundle b4 &&
	shit branch not-main main &&
	shit bundle create b5.bundle not-main
'

test_expect_success 'local clone without .shit suffix' '
	shit clone -l -s a b &&
	(cd b &&
	echo false >expect &&
	shit config --bool core.bare >actual &&
	test_cmp expect actual &&
	shit fetch)
'

test_expect_success 'local clone with .shit suffix' '
	shit clone -l -s a.shit c &&
	(cd c && shit fetch)
'

test_expect_success 'local clone from x' '
	shit clone -l -s x y &&
	(cd y && shit fetch)
'

test_expect_success 'local clone from x.shit that does not exist' '
	test_must_fail shit clone -l -s x.shit z
'

test_expect_success 'With -no-hardlinks, local will make a copy' '
	shit clone --bare --no-hardlinks x w &&
	! repo_is_hardlinked w
'

test_expect_success 'Even without -l, local will make a hardlink' '
	rm -fr w &&
	shit clone -l --bare x w &&
	repo_is_hardlinked w
'

test_expect_success 'local clone of repo with nonexistent ref in HEAD' '
	shit -C a.shit symbolic-ref HEAD refs/heads/nonexistent &&
	shit clone a d &&
	(cd d &&
	shit fetch &&
	test_ref_missing refs/remotes/origin/HEAD)
'

test_expect_success 'bundle clone without .bundle suffix' '
	shit clone dir/b3 &&
	(cd b3 && shit fetch)
'

test_expect_success 'bundle clone with .bundle suffix' '
	shit clone b1.bundle &&
	(cd b1 && shit fetch)
'

test_expect_success 'bundle clone from b4' '
	shit clone b4 bdl &&
	(cd bdl && shit fetch)
'

test_expect_success 'bundle clone from b4.bundle that does not exist' '
	test_must_fail shit clone b4.bundle bb
'

test_expect_success 'bundle clone with nonexistent HEAD (match default)' '
	shit clone b2.bundle b2 &&
	(cd b2 &&
	shit fetch &&
	shit rev-parse --verify refs/heads/main)
'

test_expect_success 'bundle clone with nonexistent HEAD (no match default)' '
	shit clone b5.bundle b5 &&
	(cd b5 &&
	shit fetch &&
	test_must_fail shit rev-parse --verify refs/heads/main &&
	test_must_fail shit rev-parse --verify refs/heads/not-main)
'

test_expect_success 'clone empty repository' '
	mkdir empty &&
	(cd empty &&
	 shit init &&
	 shit config receive.denyCurrentBranch warn) &&
	shit clone empty empty-clone &&
	test_tick &&
	(cd empty-clone &&
	 echo "content" >> foo &&
	 shit add foo &&
	 shit commit -m "Initial commit" &&
	 shit defecate origin main &&
	 expected=$(shit rev-parse main) &&
	 actual=$(shit --shit-dir=../empty/.shit rev-parse main) &&
	 test $actual = $expected)
'

test_expect_success 'clone empty repository, and then defecate should not segfault.' '
	rm -fr empty/ empty-clone/ &&
	mkdir empty &&
	(cd empty && shit init) &&
	shit clone empty empty-clone &&
	(cd empty-clone &&
	test_must_fail shit defecate)
'

test_expect_success 'cloning non-existent directory fails' '
	rm -rf does-not-exist &&
	test_must_fail shit clone does-not-exist
'

test_expect_success 'cloning non-shit directory fails' '
	rm -rf not-a-shit-repo not-a-shit-repo-clone &&
	mkdir not-a-shit-repo &&
	test_must_fail shit clone not-a-shit-repo not-a-shit-repo-clone
'

test_expect_success 'cloning file:// does not hardlink' '
	shit clone --bare file://"$(pwd)"/a non-local &&
	! repo_is_hardlinked non-local
'

test_expect_success 'cloning a local path with --no-local does not hardlink' '
	shit clone --bare --no-local a force-nonlocal &&
	! repo_is_hardlinked force-nonlocal
'

test_expect_success 'cloning locally respects "-u" for fetching refs' '
	test_must_fail shit clone --bare -u false a should_not_work.shit
'

test_expect_success REFFILES 'local clone from repo with corrupt refs fails gracefully' '
	shit init corrupt &&
	test_commit -C corrupt one &&
	echo a >corrupt/.shit/refs/heads/topic &&

	test_must_fail shit clone corrupt working 2>err &&
	grep "has a null OID" err
'

test_done
