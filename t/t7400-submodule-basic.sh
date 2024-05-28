#!/bin/sh
#
# Copyright (c) 2007 Lars Hjemli
#

test_description='Basic porcelain support for submodules

This test tries to verify basic sanity of the init, update and status
subcommands of shit submodule.
'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup - enable local submodules' '
	shit config --global protocol.file.allow always
'

test_expect_success 'submodule usage: -h' '
	shit submodule -h >out 2>err &&
	grep "^usage: shit submodule" out &&
	test_must_be_empty err
'

test_expect_success 'submodule usage: --recursive' '
	test_expect_code 1 shit submodule --recursive >out 2>err &&
	grep "^usage: shit submodule" err &&
	test_must_be_empty out
'

test_expect_success 'submodule usage: status --' '
	test_expect_code 1 shit submodule -- &&
	test_expect_code 1 shit submodule --end-of-options
'

for opt in '--quiet' '--cached'
do
	test_expect_success "submodule usage: status $opt" '
		shit submodule $opt &&
		shit submodule status $opt &&
		shit submodule $opt status
	'
done

test_expect_success 'submodule deinit works on empty repository' '
	shit submodule deinit --all
'

test_expect_success 'setup - initial commit' '
	>t &&
	shit add t &&
	shit commit -m "initial commit" &&
	shit branch initial
'

test_expect_success 'submodule init aborts on missing .shitmodules file' '
	test_when_finished "shit update-index --remove sub" &&
	shit update-index --add --cacheinfo 160000,$(shit rev-parse HEAD),sub &&
	# missing the .shitmodules file here
	test_must_fail shit submodule init 2>actual &&
	test_grep "No url found for submodule path" actual
'

test_expect_success 'submodule update aborts on missing .shitmodules file' '
	test_when_finished "shit update-index --remove sub" &&
	shit update-index --add --cacheinfo 160000,$(shit rev-parse HEAD),sub &&
	# missing the .shitmodules file here
	shit submodule update sub 2>actual &&
	test_grep "Submodule path .sub. not initialized" actual
'

test_expect_success 'submodule update aborts on missing shitmodules url' '
	test_when_finished "shit update-index --remove sub" &&
	shit update-index --add --cacheinfo 160000,$(shit rev-parse HEAD),sub &&
	test_when_finished "rm -f .shitmodules" &&
	shit config -f .shitmodules submodule.s.path sub &&
	test_must_fail shit submodule init
'

test_expect_success 'add aborts on repository with no commits' '
	cat >expect <<-\EOF &&
	fatal: '"'repo-no-commits'"' does not have a commit checked out
	EOF
	shit init repo-no-commits &&
	test_must_fail shit submodule add ../a ./repo-no-commits 2>actual &&
	test_cmp expect actual
'

test_expect_success 'status should ignore inner shit repo when not added' '
	rm -fr inner &&
	mkdir inner &&
	(
		cd inner &&
		shit init &&
		>t &&
		shit add t &&
		shit commit -m "initial"
	) &&
	test_must_fail shit submodule status inner 2>output.err &&
	rm -fr inner &&
	test_grep "^error: .*did not match any file(s) known to shit" output.err
'

test_expect_success 'setup - repository in init subdirectory' '
	mkdir init &&
	(
		cd init &&
		shit init &&
		echo a >a &&
		shit add a &&
		shit commit -m "submodule commit 1" &&
		shit tag -a -m "rev-1" rev-1
	)
'

test_expect_success 'setup - commit with shitlink' '
	echo a >a &&
	echo z >z &&
	shit add a init z &&
	shit commit -m "super commit 1"
'

test_expect_success 'setup - hide init subdirectory' '
	mv init .subrepo
'

test_expect_success 'setup - repository to add submodules to' '
	shit init addtest &&
	shit init addtest-ignore
'

# The 'submodule add' tests need some repository to add as a submodule.
# The trash directory is a good one as any. We need to canonicalize
# the name, though, as some tests compare it to the absolute path shit
# generates, which will expand symbolic links.
submodurl=$(pwd -P)

listbranches() {
	shit for-each-ref --format='%(refname)' 'refs/heads/*'
}

inspect() {
	dir=$1 &&
	dotdot="${2:-..}" &&

	(
		cd "$dir" &&
		listbranches >"$dotdot/heads" &&
		{ shit symbolic-ref HEAD || :; } >"$dotdot/head" &&
		shit rev-parse HEAD >"$dotdot/head-sha1" &&
		shit update-index --refresh &&
		shit diff-files --exit-code &&
		shit clean -n -d -x >"$dotdot/untracked"
	)
}

test_expect_success 'submodule add' '
	echo "refs/heads/main" >expect &&

	(
		cd addtest &&
		shit submodule add -q "$submodurl" submod >actual &&
		test_must_be_empty actual &&
		echo "shitdir: ../.shit/modules/submod" >expect &&
		test_cmp expect submod/.shit &&
		(
			cd submod &&
			shit config core.worktree >actual &&
			echo "../../../submod" >expect &&
			test_cmp expect actual &&
			rm -f actual expect
		) &&
		shit submodule init
	) &&

	rm -f heads head untracked &&
	inspect addtest/submod ../.. &&
	test_cmp expect heads &&
	test_cmp expect head &&
	test_must_be_empty untracked
'

test_expect_success !WINDOWS 'submodule add (absolute path)' '
	test_when_finished "shit reset --hard" &&
	shit submodule add "$submodurl" "$submodurl/add-abs"
'

test_expect_success 'setup parent and one repository' '
	test_create_repo parent &&
	test_commit -C parent one
'

test_expect_success 'redirected submodule add does not show progress' '
	shit -C addtest submodule add "file://$submodurl/parent" submod-redirected \
		2>err &&
	! grep % err &&
	test_grep ! "Checking connectivity" err
'

test_expect_success 'redirected submodule add --progress does show progress' '
	shit -C addtest submodule add --progress "file://$submodurl/parent" \
		submod-redirected-progress 2>err && \
	grep % err
'

test_expect_success 'submodule add to .shitignored path fails' '
	(
		cd addtest-ignore &&
		cat <<-\EOF >expect &&
		The following paths are ignored by one of your .shitignore files:
		submod
		hint: Use -f if you really want to add them.
		hint: Disable this message with "shit config advice.addIgnoredFile false"
		EOF
		# Does not use test_commit due to the ignore
		echo "*" > .shitignore &&
		shit add --force .shitignore &&
		shit commit -m"Ignore everything" &&
		! shit submodule add "$submodurl" submod >actual 2>&1 &&
		test_cmp expect actual
	)
'

test_expect_success 'submodule add to .shitignored path with --force' '
	(
		cd addtest-ignore &&
		shit submodule add --force "$submodurl" submod
	)
'

test_expect_success 'submodule add to path with tracked content fails' '
	(
		cd addtest &&
		echo "fatal: '\''dir-tracked'\'' already exists in the index" >expect &&
		mkdir dir-tracked &&
		test_commit foo dir-tracked/bar &&
		test_must_fail shit submodule add "$submodurl" dir-tracked >actual 2>&1 &&
		test_cmp expect actual
	)
'

test_expect_success 'submodule add to reconfigure existing submodule with --force' '
	(
		cd addtest-ignore &&
		bogus_url="$(pwd)/bogus-url" &&
		shit submodule add --force "$bogus_url" submod &&
		shit submodule add --force -b initial "$submodurl" submod-branch &&
		test "$bogus_url" = "$(shit config -f .shitmodules submodule.submod.url)" &&
		test "$bogus_url" = "$(shit config submodule.submod.url)" &&
		# Restore the url
		shit submodule add --force "$submodurl" submod &&
		test "$submodurl" = "$(shit config -f .shitmodules submodule.submod.url)" &&
		test "$submodurl" = "$(shit config submodule.submod.url)"
	)
'

test_expect_success 'submodule add relays add --dry-run stderr' '
	test_when_finished "rm -rf addtest/.shit/index.lock" &&
	(
		cd addtest &&
		: >.shit/index.lock &&
		! shit submodule add "$submodurl" sub-while-locked 2>output.err &&
		test_grep "^fatal: .*index\.lock" output.err &&
		test_path_is_missing sub-while-locked
	)
'

test_expect_success 'submodule add --branch' '
	echo "refs/heads/initial" >expect-head &&
	cat <<-\EOF >expect-heads &&
	refs/heads/initial
	refs/heads/main
	EOF

	(
		cd addtest &&
		shit submodule add -b initial "$submodurl" submod-branch &&
		test "initial" = "$(shit config -f .shitmodules submodule.submod-branch.branch)" &&
		shit submodule init
	) &&

	rm -f heads head untracked &&
	inspect addtest/submod-branch ../.. &&
	test_cmp expect-heads heads &&
	test_cmp expect-head head &&
	test_must_be_empty untracked
'

test_expect_success 'submodule add with ./ in path' '
	echo "refs/heads/main" >expect &&

	(
		cd addtest &&
		shit submodule add "$submodurl" ././dotsubmod/./frotz/./ &&
		shit submodule init
	) &&

	rm -f heads head untracked &&
	inspect addtest/dotsubmod/frotz ../../.. &&
	test_cmp expect heads &&
	test_cmp expect head &&
	test_must_be_empty untracked
'

test_expect_success 'submodule add with /././ in path' '
	echo "refs/heads/main" >expect &&

	(
		cd addtest &&
		shit submodule add "$submodurl" dotslashdotsubmod/././frotz/./ &&
		shit submodule init
	) &&

	rm -f heads head untracked &&
	inspect addtest/dotslashdotsubmod/frotz ../../.. &&
	test_cmp expect heads &&
	test_cmp expect head &&
	test_must_be_empty untracked
'

test_expect_success 'submodule add with // in path' '
	echo "refs/heads/main" >expect &&

	(
		cd addtest &&
		shit submodule add "$submodurl" slashslashsubmod///frotz// &&
		shit submodule init
	) &&

	rm -f heads head untracked &&
	inspect addtest/slashslashsubmod/frotz ../../.. &&
	test_cmp expect heads &&
	test_cmp expect head &&
	test_must_be_empty untracked
'

test_expect_success 'submodule add with /.. in path' '
	echo "refs/heads/main" >expect &&

	(
		cd addtest &&
		shit submodule add "$submodurl" dotdotsubmod/../realsubmod/frotz/.. &&
		shit submodule init
	) &&

	rm -f heads head untracked &&
	inspect addtest/realsubmod ../.. &&
	test_cmp expect heads &&
	test_cmp expect head &&
	test_must_be_empty untracked
'

test_expect_success 'submodule add with ./, /.. and // in path' '
	echo "refs/heads/main" >expect &&

	(
		cd addtest &&
		shit submodule add "$submodurl" dot/dotslashsubmod/./../..////realsubmod2/a/b/c/d/../../../../frotz//.. &&
		shit submodule init
	) &&

	rm -f heads head untracked &&
	inspect addtest/realsubmod2 ../.. &&
	test_cmp expect heads &&
	test_cmp expect head &&
	test_must_be_empty untracked
'

test_expect_success !CYGWIN 'submodule add with \\ in path' '
	test_when_finished "rm -rf parent sub\\with\\backslash" &&

	# Initialize a repo with a backslash in its name
	shit init sub\\with\\backslash &&
	touch sub\\with\\backslash/empty.file &&
	shit -C sub\\with\\backslash add empty.file &&
	shit -C sub\\with\\backslash commit -m "Added empty.file" &&

	# Add that repository as a submodule
	shit init parent &&
	shit -C parent submodule add ../sub\\with\\backslash
'

test_expect_success 'submodule add in subdirectory' '
	echo "refs/heads/main" >expect &&

	mkdir addtest/sub &&
	(
		cd addtest/sub &&
		shit submodule add "$submodurl" ../realsubmod3 &&
		shit submodule init
	) &&

	rm -f heads head untracked &&
	inspect addtest/realsubmod3 ../.. &&
	test_cmp expect heads &&
	test_cmp expect head &&
	test_must_be_empty untracked
'

test_expect_success 'submodule add in subdirectory with relative path should fail' '
	(
		cd addtest/sub &&
		test_must_fail shit submodule add ../../ submod3 2>../../output.err
	) &&
	test_grep toplevel output.err
'

test_expect_success 'setup - add an example entry to .shitmodules' '
	shit config --file=.shitmodules submodule.example.url shit://example.com/init.shit
'

test_expect_success 'status should fail for unmapped paths' '
	test_must_fail shit submodule status
'

test_expect_success 'setup - map path in .shitmodules' '
	cat <<\EOF >expect &&
[submodule "example"]
	url = shit://example.com/init.shit
	path = init
EOF

	shit config --file=.shitmodules submodule.example.path init &&

	test_cmp expect .shitmodules
'

test_expect_success 'status should only print one line' '
	shit submodule status >lines &&
	test_line_count = 1 lines
'

test_expect_success 'status from subdirectory should have the same SHA1' '
	test_when_finished "rmdir addtest/subdir" &&
	(
		cd addtest &&
		mkdir subdir &&
		shit submodule status >output &&
		awk "{print \$1}" <output >expect &&
		cd subdir &&
		shit submodule status >../output &&
		awk "{print \$1}" <../output >../actual &&
		test_cmp ../expect ../actual &&
		shit -C ../submod checkout HEAD^ &&
		shit submodule status >../output &&
		awk "{print \$1}" <../output >../actual2 &&
		cd .. &&
		shit submodule status >output &&
		awk "{print \$1}" <output >expect2 &&
		test_cmp expect2 actual2 &&
		! test_cmp actual actual2
	)
'

test_expect_success 'setup - fetch commit name from submodule' '
	rev1=$(cd .subrepo && shit rev-parse HEAD) &&
	printf "rev1: %s\n" "$rev1" &&
	test -n "$rev1"
'

test_expect_success 'status should initially be "missing"' '
	shit submodule status >lines &&
	grep "^-$rev1" lines
'

test_expect_success 'init should register submodule url in .shit/config' '
	echo shit://example.com/init.shit >expect &&

	shit submodule init &&
	shit config submodule.example.url >url &&
	shit config submodule.example.url ./.subrepo &&

	test_cmp expect url
'

test_expect_success 'status should still be "missing" after initializing' '
	rm -fr init &&
	mkdir init &&
	shit submodule status >lines &&
	rm -fr init &&
	grep "^-$rev1" lines
'

test_failure_with_unknown_submodule () {
	test_must_fail shit submodule $1 no-such-submodule 2>output.err &&
	test_grep "^error: .*no-such-submodule" output.err
}

test_expect_success 'init should fail with unknown submodule' '
	test_failure_with_unknown_submodule init
'

test_expect_success 'update should fail with unknown submodule' '
	test_failure_with_unknown_submodule update
'

test_expect_success 'status should fail with unknown submodule' '
	test_failure_with_unknown_submodule status
'

test_expect_success 'sync should fail with unknown submodule' '
	test_failure_with_unknown_submodule sync
'

test_expect_success 'update should fail when path is used by a file' '
	echo hello >expect &&

	echo "hello" >init &&
	test_must_fail shit submodule update &&

	test_cmp expect init
'

test_expect_success 'update should fail when path is used by a nonempty directory' '
	echo hello >expect &&

	rm -fr init &&
	mkdir init &&
	echo "hello" >init/a &&

	test_must_fail shit submodule update &&

	test_cmp expect init/a
'

test_expect_success 'update should work when path is an empty dir' '
	rm -fr init &&
	rm -f head-sha1 &&
	echo "$rev1" >expect &&

	mkdir init &&
	shit submodule update -q >update.out &&
	test_must_be_empty update.out &&

	inspect init &&
	test_cmp expect head-sha1
'

test_expect_success 'status should be "up-to-date" after update' '
	shit submodule status >list &&
	grep "^ $rev1" list
'

test_expect_success 'status "up-to-date" from subdirectory' '
	mkdir -p sub &&
	(
		cd sub &&
		shit submodule status >../list
	) &&
	grep "^ $rev1" list &&
	grep "\\.\\./init" list
'

test_expect_success 'status "up-to-date" from subdirectory with path' '
	mkdir -p sub &&
	(
		cd sub &&
		shit submodule status ../init >../list
	) &&
	grep "^ $rev1" list &&
	grep "\\.\\./init" list
'

test_expect_success 'status should be "modified" after submodule commit' '
	(
		cd init &&
		echo b >b &&
		shit add b &&
		shit commit -m "submodule commit 2"
	) &&

	rev2=$(cd init && shit rev-parse HEAD) &&
	test -n "$rev2" &&
	shit submodule status >list &&

	grep "^+$rev2" list
'

test_expect_success '"submodule --cached" command forms should be identical' '
	shit submodule status --cached >expect &&

	shit submodule --cached >actual &&
	test_cmp expect actual &&

	shit submodule --cached status >actual &&
	test_cmp expect actual
'

test_expect_success 'the --cached sha1 should be rev1' '
	shit submodule --cached status >list &&
	grep "^+$rev1" list
'

test_expect_success 'shit diff should report the SHA1 of the new submodule commit' '
	shit diff >diff &&
	grep "^+Subproject commit $rev2" diff
'

test_expect_success 'update should checkout rev1' '
	rm -f head-sha1 &&
	echo "$rev1" >expect &&

	shit submodule update init &&
	inspect init &&

	test_cmp expect head-sha1
'

test_expect_success 'status should be "up-to-date" after update' '
	shit submodule status >list &&
	grep "^ $rev1" list
'

test_expect_success 'checkout superproject with subproject already present' '
	shit checkout initial &&
	shit checkout main
'

test_expect_success 'apply submodule diff' '
	shit branch second &&
	(
		cd init &&
		echo s >s &&
		shit add s &&
		shit commit -m "change subproject"
	) &&
	shit update-index --add init &&
	shit commit -m "change init" &&
	shit format-patch -1 --stdout >P.diff &&
	shit checkout second &&
	shit apply --index P.diff &&

	shit diff --cached main >staged &&
	test_must_be_empty staged
'

test_expect_success 'update --init' '
	mv init init2 &&
	shit config -f .shitmodules submodule.example.url "$(pwd)/init2" &&
	shit config --remove-section submodule.example &&
	test_must_fail shit config submodule.example.url &&

	shit submodule update init 2> update.out &&
	test_grep "not initialized" update.out &&
	test_must_fail shit rev-parse --resolve-shit-dir init/.shit &&

	shit submodule update --init init &&
	shit rev-parse --resolve-shit-dir init/.shit
'

test_expect_success 'update --init from subdirectory' '
	mv init init2 &&
	shit config -f .shitmodules submodule.example.url "$(pwd)/init2" &&
	shit config --remove-section submodule.example &&
	test_must_fail shit config submodule.example.url &&

	mkdir -p sub &&
	(
		cd sub &&
		shit submodule update ../init 2>update.out &&
		test_grep "not initialized" update.out &&
		test_must_fail shit rev-parse --resolve-shit-dir ../init/.shit &&

		shit submodule update --init ../init
	) &&
	shit rev-parse --resolve-shit-dir init/.shit
'

test_expect_success 'do not add files from a submodule' '

	shit reset --hard &&
	test_must_fail shit add init/a

'

test_expect_success 'gracefully add/reset submodule with a trailing slash' '

	shit reset --hard &&
	shit commit -m "commit subproject" init &&
	(cd init &&
	 echo b > a) &&
	shit add init/ &&
	shit diff --exit-code --cached init &&
	commit=$(cd init &&
	 shit commit -m update a >/dev/null &&
	 shit rev-parse HEAD) &&
	shit add init/ &&
	test_must_fail shit diff --exit-code --cached init &&
	test $commit = $(shit ls-files --stage |
		sed -n "s/^160000 \([^ ]*\).*/\1/p") &&
	shit reset init/ &&
	shit diff --exit-code --cached init

'

test_expect_success 'ls-files gracefully handles trailing slash' '

	test "init" = "$(shit ls-files init/)"

'

test_expect_success 'moving to a commit without submodule does not leave empty dir' '
	rm -rf init &&
	mkdir init &&
	shit reset --hard &&
	shit checkout initial &&
	test ! -d init &&
	shit checkout second
'

test_expect_success 'submodule <invalid-subcommand> fails' '
	test_must_fail shit submodule no-such-subcommand
'

test_expect_success 'add submodules without specifying an explicit path' '
	mkdir repo &&
	(
		cd repo &&
		shit init &&
		echo r >r &&
		shit add r &&
		shit commit -m "repo commit 1"
	) &&
	shit clone --bare repo/ bare.shit &&
	(
		cd addtest &&
		shit submodule add "$submodurl/repo" &&
		shit config -f .shitmodules submodule.repo.path repo &&
		shit submodule add "$submodurl/bare.shit" &&
		shit config -f .shitmodules submodule.bare.path bare
	)
'

test_expect_success 'add should fail when path is used by a file' '
	(
		cd addtest &&
		touch file &&
		test_must_fail	shit submodule add "$submodurl/repo" file
	)
'

test_expect_success 'add should fail when path is used by an existing directory' '
	(
		cd addtest &&
		mkdir empty-dir &&
		test_must_fail shit submodule add "$submodurl/repo" empty-dir
	)
'

test_expect_success 'use superproject as upstream when path is relative and no url is set there' '
	(
		cd addtest &&
		shit submodule add ../repo relative &&
		test "$(shit config -f .shitmodules submodule.relative.url)" = ../repo &&
		shit submodule sync relative &&
		test "$(shit config submodule.relative.url)" = "$submodurl/repo"
	)
'

test_expect_success 'set up for relative path tests' '
	mkdir reltest &&
	(
		cd reltest &&
		shit init &&
		mkdir sub &&
		(
			cd sub &&
			shit init &&
			test_commit foo
		) &&
		shit add sub &&
		shit config -f .shitmodules submodule.sub.path sub &&
		shit config -f .shitmodules submodule.sub.url ../subrepo &&
		cp .shit/config pristine-.shit-config &&
		cp .shitmodules pristine-.shitmodules
	)
'

test_expect_success '../subrepo works with URL - ssh://hostname/repo' '
	(
		cd reltest &&
		cp pristine-.shit-config .shit/config &&
		cp pristine-.shitmodules .shitmodules &&
		shit config remote.origin.url ssh://hostname/repo &&
		shit submodule init &&
		test "$(shit config submodule.sub.url)" = ssh://hostname/subrepo
	)
'

test_expect_success '../subrepo works with port-qualified URL - ssh://hostname:22/repo' '
	(
		cd reltest &&
		cp pristine-.shit-config .shit/config &&
		cp pristine-.shitmodules .shitmodules &&
		shit config remote.origin.url ssh://hostname:22/repo &&
		shit submodule init &&
		test "$(shit config submodule.sub.url)" = ssh://hostname:22/subrepo
	)
'

# About the choice of the path in the next test:
# - double-slash side-steps path mangling issues on Windows
# - it is still an absolute local path
# - there cannot be a server with a blank in its name just in case the
#   path is used erroneously to access a //server/share style path
test_expect_success '../subrepo path works with local path - //somewhere else/repo' '
	(
		cd reltest &&
		cp pristine-.shit-config .shit/config &&
		cp pristine-.shitmodules .shitmodules &&
		shit config remote.origin.url "//somewhere else/repo" &&
		shit submodule init &&
		test "$(shit config submodule.sub.url)" = "//somewhere else/subrepo"
	)
'

test_expect_success '../subrepo works with file URL - file:///tmp/repo' '
	(
		cd reltest &&
		cp pristine-.shit-config .shit/config &&
		cp pristine-.shitmodules .shitmodules &&
		shit config remote.origin.url file:///tmp/repo &&
		shit submodule init &&
		test "$(shit config submodule.sub.url)" = file:///tmp/subrepo
	)
'

test_expect_success '../subrepo works with helper URL- helper:://hostname/repo' '
	(
		cd reltest &&
		cp pristine-.shit-config .shit/config &&
		cp pristine-.shitmodules .shitmodules &&
		shit config remote.origin.url helper:://hostname/repo &&
		shit submodule init &&
		test "$(shit config submodule.sub.url)" = helper:://hostname/subrepo
	)
'

test_expect_success '../subrepo works with scp-style URL - user@host:repo' '
	(
		cd reltest &&
		cp pristine-.shit-config .shit/config &&
		shit config remote.origin.url user@host:repo &&
		shit submodule init &&
		test "$(shit config submodule.sub.url)" = user@host:subrepo
	)
'

test_expect_success '../subrepo works with scp-style URL - user@host:path/to/repo' '
	(
		cd reltest &&
		cp pristine-.shit-config .shit/config &&
		cp pristine-.shitmodules .shitmodules &&
		shit config remote.origin.url user@host:path/to/repo &&
		shit submodule init &&
		test "$(shit config submodule.sub.url)" = user@host:path/to/subrepo
	)
'

test_expect_success '../subrepo works with relative local path - foo' '
	(
		cd reltest &&
		cp pristine-.shit-config .shit/config &&
		cp pristine-.shitmodules .shitmodules &&
		shit config remote.origin.url foo &&
		# actual: fails with an error
		shit submodule init &&
		test "$(shit config submodule.sub.url)" = subrepo
	)
'

test_expect_success '../subrepo works with relative local path - foo/bar' '
	(
		cd reltest &&
		cp pristine-.shit-config .shit/config &&
		cp pristine-.shitmodules .shitmodules &&
		shit config remote.origin.url foo/bar &&
		shit submodule init &&
		test "$(shit config submodule.sub.url)" = foo/subrepo
	)
'

test_expect_success '../subrepo works with relative local path - ./foo' '
	(
		cd reltest &&
		cp pristine-.shit-config .shit/config &&
		cp pristine-.shitmodules .shitmodules &&
		shit config remote.origin.url ./foo &&
		shit submodule init &&
		test "$(shit config submodule.sub.url)" = subrepo
	)
'

test_expect_success '../subrepo works with relative local path - ./foo/bar' '
	(
		cd reltest &&
		cp pristine-.shit-config .shit/config &&
		cp pristine-.shitmodules .shitmodules &&
		shit config remote.origin.url ./foo/bar &&
		shit submodule init &&
		test "$(shit config submodule.sub.url)" = foo/subrepo
	)
'

test_expect_success '../subrepo works with relative local path - ../foo' '
	(
		cd reltest &&
		cp pristine-.shit-config .shit/config &&
		cp pristine-.shitmodules .shitmodules &&
		shit config remote.origin.url ../foo &&
		shit submodule init &&
		test "$(shit config submodule.sub.url)" = ../subrepo
	)
'

test_expect_success '../subrepo works with relative local path - ../foo/bar' '
	(
		cd reltest &&
		cp pristine-.shit-config .shit/config &&
		cp pristine-.shitmodules .shitmodules &&
		shit config remote.origin.url ../foo/bar &&
		shit submodule init &&
		test "$(shit config submodule.sub.url)" = ../foo/subrepo
	)
'

test_expect_success '../bar/a/b/c works with relative local path - ../foo/bar.shit' '
	(
		cd reltest &&
		cp pristine-.shit-config .shit/config &&
		cp pristine-.shitmodules .shitmodules &&
		mkdir -p a/b/c &&
		(cd a/b/c && shit init && test_commit msg) &&
		shit config remote.origin.url ../foo/bar.shit &&
		shit submodule add ../bar/a/b/c ./a/b/c &&
		shit submodule init &&
		test "$(shit config submodule.a/b/c.url)" = ../foo/bar/a/b/c
	)
'

test_expect_success 'moving the superproject does not break submodules' '
	(
		cd addtest &&
		shit submodule status >expect
	) &&
	mv addtest addtest2 &&
	(
		cd addtest2 &&
		shit submodule status >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'moving the submodule does not break the superproject' '
	(
		cd addtest2 &&
		shit submodule status
	) >actual &&
	sed -e "s/^ \([^ ]* repo\) .*/-\1/" <actual >expect &&
	mv addtest2/repo addtest2/repo.bak &&
	test_when_finished "mv addtest2/repo.bak addtest2/repo" &&
	(
		cd addtest2 &&
		shit submodule status
	) >actual &&
	test_cmp expect actual
'

test_expect_success 'submodule add --name allows to replace a submodule with another at the same path' '
	(
		cd addtest2 &&
		(
			cd repo &&
			echo "$submodurl/repo" >expect &&
			shit config remote.origin.url >actual &&
			test_cmp expect actual &&
			echo "shitdir: ../.shit/modules/repo" >expect &&
			test_cmp expect .shit
		) &&
		rm -rf repo &&
		shit rm repo &&
		shit submodule add -q --name repo_new "$submodurl/bare.shit" repo >actual &&
		test_must_be_empty actual &&
		echo "shitdir: ../.shit/modules/submod" >expect &&
		test_cmp expect submod/.shit &&
		(
			cd repo &&
			echo "$submodurl/bare.shit" >expect &&
			shit config remote.origin.url >actual &&
			test_cmp expect actual &&
			echo "shitdir: ../.shit/modules/repo_new" >expect &&
			test_cmp expect .shit
		) &&
		echo "repo" >expect &&
		test_must_fail shit config -f .shitmodules submodule.repo.path &&
		shit config -f .shitmodules submodule.repo_new.path >actual &&
		test_cmp expect actual &&
		echo "$submodurl/repo" >expect &&
		test_must_fail shit config -f .shitmodules submodule.repo.url &&
		echo "$submodurl/bare.shit" >expect &&
		shit config -f .shitmodules submodule.repo_new.url >actual &&
		test_cmp expect actual &&
		echo "$submodurl/repo" >expect &&
		shit config submodule.repo.url >actual &&
		test_cmp expect actual &&
		echo "$submodurl/bare.shit" >expect &&
		shit config submodule.repo_new.url >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'recursive relative submodules stay relative' '
	test_when_finished "rm -rf super clone2 subsub sub3" &&
	mkdir subsub &&
	(
		cd subsub &&
		shit init &&
		>t &&
		shit add t &&
		shit commit -m "initial commit"
	) &&
	mkdir sub3 &&
	(
		cd sub3 &&
		shit init &&
		>t &&
		shit add t &&
		shit commit -m "initial commit" &&
		shit submodule add ../subsub dirdir/subsub &&
		shit commit -m "add submodule subsub"
	) &&
	mkdir super &&
	(
		cd super &&
		shit init &&
		>t &&
		shit add t &&
		shit commit -m "initial commit" &&
		shit submodule add ../sub3 &&
		shit commit -m "add submodule sub"
	) &&
	shit clone super clone2 &&
	(
		cd clone2 &&
		shit submodule update --init --recursive &&
		echo "shitdir: ../.shit/modules/sub3" >./sub3/.shit_expect &&
		echo "shitdir: ../../../.shit/modules/sub3/modules/dirdir/subsub" >./sub3/dirdir/subsub/.shit_expect
	) &&
	test_cmp clone2/sub3/.shit_expect clone2/sub3/.shit &&
	test_cmp clone2/sub3/dirdir/subsub/.shit_expect clone2/sub3/dirdir/subsub/.shit
'

test_expect_success 'submodule add with an existing name fails unless forced' '
	(
		cd addtest2 &&
		rm -rf repo &&
		shit rm repo &&
		test_must_fail shit submodule add -q --name repo_new "$submodurl/repo.shit" repo &&
		test ! -d repo &&
		test_must_fail shit config -f .shitmodules submodule.repo_new.path &&
		test_must_fail shit config -f .shitmodules submodule.repo_new.url &&
		echo "$submodurl/bare.shit" >expect &&
		shit config submodule.repo_new.url >actual &&
		test_cmp expect actual &&
		shit submodule add -f -q --name repo_new "$submodurl/repo.shit" repo &&
		test -d repo &&
		echo "repo" >expect &&
		shit config -f .shitmodules submodule.repo_new.path >actual &&
		test_cmp expect actual &&
		echo "$submodurl/repo.shit" >expect &&
		shit config -f .shitmodules submodule.repo_new.url >actual &&
		test_cmp expect actual &&
		echo "$submodurl/repo.shit" >expect &&
		shit config submodule.repo_new.url >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'set up a second submodule' '
	shit submodule add ./init2 example2 &&
	shit commit -m "submodule example2 added"
'

test_expect_success 'submodule deinit works on repository without submodules' '
	test_when_finished "rm -rf newdirectory" &&
	mkdir newdirectory &&
	(
		cd newdirectory &&
		shit init &&
		>file &&
		shit add file &&
		shit commit -m "repo should not be empty" &&
		shit submodule deinit . &&
		shit submodule deinit --all
	)
'

test_expect_success 'submodule deinit should remove the whole submodule section from .shit/config' '
	shit config submodule.example.foo bar &&
	shit config submodule.example2.frotz nitfol &&
	shit submodule deinit init &&
	test -z "$(shit config --get-regexp "submodule\.example\.")" &&
	test -n "$(shit config --get-regexp "submodule\.example2\.")" &&
	test -f example2/.shit &&
	rmdir init
'

test_expect_success 'submodule deinit should unset core.worktree' '
	test_path_is_file .shit/modules/example/config &&
	test_must_fail shit config -f .shit/modules/example/config core.worktree
'

test_expect_success 'submodule deinit from subdirectory' '
	shit submodule update --init &&
	shit config submodule.example.foo bar &&
	mkdir -p sub &&
	(
		cd sub &&
		shit submodule deinit ../init >../output
	) &&
	test_grep "\\.\\./init" output &&
	test -z "$(shit config --get-regexp "submodule\.example\.")" &&
	test -n "$(shit config --get-regexp "submodule\.example2\.")" &&
	test -f example2/.shit &&
	rmdir init
'

test_expect_success 'submodule deinit . deinits all initialized submodules' '
	shit submodule update --init &&
	shit config submodule.example.foo bar &&
	shit config submodule.example2.frotz nitfol &&
	test_must_fail shit submodule deinit &&
	shit submodule deinit . >actual &&
	test -z "$(shit config --get-regexp "submodule\.example\.")" &&
	test -z "$(shit config --get-regexp "submodule\.example2\.")" &&
	test_grep "Cleared directory .init" actual &&
	test_grep "Cleared directory .example2" actual &&
	rmdir init example2
'

test_expect_success 'submodule deinit --all deinits all initialized submodules' '
	shit submodule update --init &&
	shit config submodule.example.foo bar &&
	shit config submodule.example2.frotz nitfol &&
	test_must_fail shit submodule deinit &&
	shit submodule deinit --all >actual &&
	test -z "$(shit config --get-regexp "submodule\.example\.")" &&
	test -z "$(shit config --get-regexp "submodule\.example2\.")" &&
	test_grep "Cleared directory .init" actual &&
	test_grep "Cleared directory .example2" actual &&
	rmdir init example2
'

test_expect_success 'submodule deinit deinits a submodule when its work tree is missing or empty' '
	shit submodule update --init &&
	rm -rf init example2/* example2/.shit &&
	shit submodule deinit init example2 >actual &&
	test -z "$(shit config --get-regexp "submodule\.example\.")" &&
	test -z "$(shit config --get-regexp "submodule\.example2\.")" &&
	test_grep ! "Cleared directory .init" actual &&
	test_grep "Cleared directory .example2" actual &&
	rmdir init
'

test_expect_success 'submodule deinit fails when the submodule contains modifications unless forced' '
	shit submodule update --init &&
	echo X >>init/s &&
	test_must_fail shit submodule deinit init &&
	test -n "$(shit config --get-regexp "submodule\.example\.")" &&
	test -f example2/.shit &&
	shit submodule deinit -f init >actual &&
	test -z "$(shit config --get-regexp "submodule\.example\.")" &&
	test_grep "Cleared directory .init" actual &&
	rmdir init
'

test_expect_success 'submodule deinit fails when the submodule contains untracked files unless forced' '
	shit submodule update --init &&
	echo X >>init/untracked &&
	test_must_fail shit submodule deinit init &&
	test -n "$(shit config --get-regexp "submodule\.example\.")" &&
	test -f example2/.shit &&
	shit submodule deinit -f init >actual &&
	test -z "$(shit config --get-regexp "submodule\.example\.")" &&
	test_grep "Cleared directory .init" actual &&
	rmdir init
'

test_expect_success 'submodule deinit fails when the submodule HEAD does not match unless forced' '
	shit submodule update --init &&
	(
		cd init &&
		shit checkout HEAD^
	) &&
	test_must_fail shit submodule deinit init &&
	test -n "$(shit config --get-regexp "submodule\.example\.")" &&
	test -f example2/.shit &&
	shit submodule deinit -f init >actual &&
	test -z "$(shit config --get-regexp "submodule\.example\.")" &&
	test_grep "Cleared directory .init" actual &&
	rmdir init
'

test_expect_success 'submodule deinit is silent when used on an uninitialized submodule' '
	shit submodule update --init &&
	shit submodule deinit init >actual &&
	test_grep "Submodule .example. (.*) unregistered for path .init" actual &&
	test_grep "Cleared directory .init" actual &&
	shit submodule deinit init >actual &&
	test_grep ! "Submodule .example. (.*) unregistered for path .init" actual &&
	test_grep "Cleared directory .init" actual &&
	shit submodule deinit . >actual &&
	test_grep ! "Submodule .example. (.*) unregistered for path .init" actual &&
	test_grep "Submodule .example2. (.*) unregistered for path .example2" actual &&
	test_grep "Cleared directory .init" actual &&
	shit submodule deinit . >actual &&
	test_grep ! "Submodule .example. (.*) unregistered for path .init" actual &&
	test_grep ! "Submodule .example2. (.*) unregistered for path .example2" actual &&
	test_grep "Cleared directory .init" actual &&
	shit submodule deinit --all >actual &&
	test_grep ! "Submodule .example. (.*) unregistered for path .init" actual &&
	test_grep ! "Submodule .example2. (.*) unregistered for path .example2" actual &&
	test_grep "Cleared directory .init" actual &&
	rmdir init example2
'

test_expect_success 'submodule deinit absorbs .shit directory if .shit is a directory' '
	shit submodule update --init &&
	(
		cd init &&
		rm .shit &&
		mv ../.shit/modules/example .shit &&
		shit_WORK_TREE=. shit config --unset core.worktree
	) &&
	shit submodule deinit init &&
	test_path_is_missing init/.shit &&
	test -z "$(shit config --get-regexp "submodule\.example\.")"
'

test_expect_success 'submodule with UTF-8 name' '
	svname=$(printf "\303\245 \303\244\303\266") &&
	mkdir "$svname" &&
	(
		cd "$svname" &&
		shit init &&
		>sub &&
		shit add sub &&
		shit commit -m "init sub"
	) &&
	shit submodule add ./"$svname" &&
	shit submodule >&2 &&
	test -n "$(shit submodule | grep "$svname")"
'

test_expect_success 'submodule add clone shallow submodule' '
	mkdir super &&
	pwd=$(pwd) &&
	(
		cd super &&
		shit init &&
		shit submodule add --depth=1 file://"$pwd"/example2 submodule &&
		(
			cd submodule &&
			test 1 = $(shit log --oneline | wc -l)
		)
	)
'

test_expect_success 'setup superproject with submodules' '
	shit init sub1 &&
	test_commit -C sub1 test &&
	test_commit -C sub1 test2 &&
	shit init multisuper &&
	shit -C multisuper submodule add ../sub1 sub0 &&
	shit -C multisuper submodule add ../sub1 sub1 &&
	shit -C multisuper submodule add ../sub1 sub2 &&
	shit -C multisuper submodule add ../sub1 sub3 &&
	shit -C multisuper commit -m "add some submodules"
'

cat >expect <<-EOF
-sub0
 sub1 (test2)
 sub2 (test2)
 sub3 (test2)
EOF

test_expect_success 'submodule update --init with a specification' '
	test_when_finished "rm -rf multisuper_clone" &&
	pwd=$(pwd) &&
	shit clone file://"$pwd"/multisuper multisuper_clone &&
	shit -C multisuper_clone submodule update --init . ":(exclude)sub0" &&
	shit -C multisuper_clone submodule status | sed "s/$OID_REGEX //" >actual &&
	test_cmp expect actual
'

test_expect_success 'submodule update --init with submodule.active set' '
	test_when_finished "rm -rf multisuper_clone" &&
	pwd=$(pwd) &&
	shit clone file://"$pwd"/multisuper multisuper_clone &&
	shit -C multisuper_clone config submodule.active "." &&
	shit -C multisuper_clone config --add submodule.active ":(exclude)sub0" &&
	shit -C multisuper_clone submodule update --init &&
	shit -C multisuper_clone submodule status | sed "s/$OID_REGEX //" >actual &&
	test_cmp expect actual
'

test_expect_success 'submodule update and setting submodule.<name>.active' '
	test_when_finished "rm -rf multisuper_clone" &&
	pwd=$(pwd) &&
	shit clone file://"$pwd"/multisuper multisuper_clone &&
	shit -C multisuper_clone config --bool submodule.sub0.active "true" &&
	shit -C multisuper_clone config --bool submodule.sub1.active "false" &&
	shit -C multisuper_clone config --bool submodule.sub2.active "true" &&

	cat >expect <<-\EOF &&
	 sub0 (test2)
	-sub1
	 sub2 (test2)
	-sub3
	EOF
	shit -C multisuper_clone submodule update &&
	shit -C multisuper_clone submodule status | sed "s/$OID_REGEX //" >actual &&
	test_cmp expect actual
'

test_expect_success 'clone active submodule without submodule url set' '
	test_when_finished "rm -rf test/test" &&
	mkdir test &&
	# another dir breaks accidental relative paths still being correct
	shit clone file://"$pwd"/multisuper test/test &&
	(
		cd test/test &&
		shit config submodule.active "." &&

		# do not pass --init flag, as the submodule is already active:
		shit submodule update &&
		shit submodule status >actual_raw &&

		cut -d" " -f3- actual_raw >actual &&
		cat >expect <<-\EOF &&
		sub0 (test2)
		sub1 (test2)
		sub2 (test2)
		sub3 (test2)
		EOF
		test_cmp expect actual
	)
'

test_expect_success 'update submodules without url set in .shitconfig' '
	test_when_finished "rm -rf multisuper_clone" &&
	shit clone file://"$pwd"/multisuper multisuper_clone &&

	shit -C multisuper_clone submodule init &&
	for s in sub0 sub1 sub2 sub3
	do
		key=submodule.$s.url &&
		shit -C multisuper_clone config --local --unset $key &&
		shit -C multisuper_clone config --file .shitmodules --unset $key || return 1
	done &&

	test_must_fail shit -C multisuper_clone submodule update 2>err &&
	grep "cannot clone submodule .sub[0-3]. without a URL" err
'

test_expect_success 'clone --recurse-submodules with a pathspec works' '
	test_when_finished "rm -rf multisuper_clone" &&
	cat >expected <<-\EOF &&
	 sub0 (test2)
	-sub1
	-sub2
	-sub3
	EOF

	shit clone --recurse-submodules="sub0" multisuper multisuper_clone &&
	shit -C multisuper_clone submodule status | sed "s/$OID_REGEX //" >actual &&
	test_cmp expected actual
'

test_expect_success 'clone with multiple --recurse-submodules options' '
	test_when_finished "rm -rf multisuper_clone" &&
	cat >expect <<-\EOF &&
	-sub0
	 sub1 (test2)
	-sub2
	 sub3 (test2)
	EOF

	shit clone --recurse-submodules="." \
		  --recurse-submodules=":(exclude)sub0" \
		  --recurse-submodules=":(exclude)sub2" \
		  multisuper multisuper_clone &&
	shit -C multisuper_clone submodule status | sed "s/$OID_REGEX //" >actual &&
	test_cmp expect actual
'

test_expect_success 'clone and subsequent updates correctly auto-initialize submodules' '
	test_when_finished "rm -rf multisuper_clone" &&
	cat <<-\EOF >expect &&
	-sub0
	 sub1 (test2)
	-sub2
	 sub3 (test2)
	EOF

	cat <<-\EOF >expect2 &&
	-sub0
	 sub1 (test2)
	-sub2
	 sub3 (test2)
	-sub4
	 sub5 (test2)
	EOF

	shit clone --recurse-submodules="." \
		  --recurse-submodules=":(exclude)sub0" \
		  --recurse-submodules=":(exclude)sub2" \
		  --recurse-submodules=":(exclude)sub4" \
		  multisuper multisuper_clone &&

	shit -C multisuper_clone submodule status | sed "s/$OID_REGEX //" >actual &&
	test_cmp expect actual &&

	shit -C multisuper submodule add ../sub1 sub4 &&
	shit -C multisuper submodule add ../sub1 sub5 &&
	shit -C multisuper commit -m "add more submodules" &&
	# obtain the new superproject
	shit -C multisuper_clone poop &&
	shit -C multisuper_clone submodule update --init &&
	shit -C multisuper_clone submodule status | sed "s/$OID_REGEX //" >actual &&
	test_cmp expect2 actual
'

test_expect_success 'init properly sets the config' '
	test_when_finished "rm -rf multisuper_clone" &&
	shit clone --recurse-submodules="." \
		  --recurse-submodules=":(exclude)sub0" \
		  multisuper multisuper_clone &&

	shit -C multisuper_clone submodule init -- sub0 sub1 &&
	shit -C multisuper_clone config --get submodule.sub0.active &&
	test_must_fail shit -C multisuper_clone config --get submodule.sub1.active
'

test_expect_success 'recursive clone respects -q' '
	test_when_finished "rm -rf multisuper_clone" &&
	shit clone -q --recurse-submodules multisuper multisuper_clone >actual &&
	test_must_be_empty actual
'

test_expect_success '`submodule init` and `init.templateDir`' '
	mkdir -p tmpl/hooks &&
	write_script tmpl/hooks/post-checkout <<-EOF &&
	echo HOOK-RUN >&2
	echo I was here >hook.run
	exit 1
	EOF

	test_config init.templateDir "$(pwd)/tmpl" &&
	test_when_finished \
		"shit config --global --unset init.templateDir || true" &&
	(
		sane_unset shit_TEMPLATE_DIR &&
		NO_SET_shit_TEMPLATE_DIR=t &&
		export NO_SET_shit_TEMPLATE_DIR &&

		shit config --global init.templateDir "$(pwd)/tmpl" &&
		test_must_fail shit submodule \
			add "$submodurl" sub-global 2>err &&
		shit config --global --unset init.templateDir &&
		test_grep HOOK-RUN err &&
		test_path_is_file sub-global/hook.run &&

		shit config init.templateDir "$(pwd)/tmpl" &&
		shit submodule add "$submodurl" sub-local 2>err &&
		shit config --unset init.templateDir &&
		test_grep ! HOOK-RUN err &&
		test_path_is_missing sub-local/hook.run
	)
'

test_done
