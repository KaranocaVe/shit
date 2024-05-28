#!/bin/sh
#
# Copyright (c) 2012 SZEDER Gábor
#

test_description='test shit-specific bash prompt functions'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./lib-bash.sh

. "$shit_BUILD_DIR/contrib/completion/shit-prompt.sh"

actual="$TRASH_DIRECTORY/actual"
c_red='\001\e[31m\002'
c_green='\001\e[32m\002'
c_lblue='\001\e[1;34m\002'
c_clear='\001\e[0m\002'

test_expect_success 'setup for prompt tests' '
	shit init otherrepo &&
	echo 1 >file &&
	shit add file &&
	test_tick &&
	shit commit -m initial &&
	shit tag -a -m msg1 t1 &&
	shit checkout -b b1 &&
	echo 2 >file &&
	shit commit -m "second b1" file &&
	echo 3 >file &&
	shit commit -m "third b1" file &&
	shit tag -a -m msg2 t2 &&
	shit checkout -b b2 main &&
	echo 0 >file &&
	shit commit -m "second b2" file &&
	echo 00 >file &&
	shit commit -m "another b2" file &&
	echo 000 >file &&
	shit commit -m "yet another b2" file &&
	mkdir ignored_dir &&
	echo "ignored_dir/" >>.shitignore &&
	shit checkout main
'

test_expect_success 'prompt - branch name' '
	printf " (main)" >expected &&
	__shit_ps1 >"$actual" &&
	test_cmp expected "$actual"
'

test_expect_success SYMLINKS 'prompt - branch name - symlink symref' '
	printf " (main)" >expected &&
	test_when_finished "shit checkout main" &&
	test_config core.preferSymlinkRefs true &&
	shit checkout main &&
	__shit_ps1 >"$actual" &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - unborn branch' '
	printf " (unborn)" >expected &&
	shit checkout --orphan unborn &&
	test_when_finished "shit checkout main" &&
	__shit_ps1 >"$actual" &&
	test_cmp expected "$actual"
'

if test_have_prereq !FUNNYNAMES; then
	say 'Your filesystem does not allow newlines in filenames.'
fi

test_expect_success FUNNYNAMES 'prompt - with newline in path' '
    repo_with_newline="repo
with
newline" &&
	mkdir "$repo_with_newline" &&
	printf " (main)" >expected &&
	shit init "$repo_with_newline" &&
	test_when_finished "rm -rf \"$repo_with_newline\"" &&
	mkdir "$repo_with_newline"/subdir &&
	(
		cd "$repo_with_newline/subdir" &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - detached head' '
	printf " ((%s...))" $(shit log -1 --format="%h" --abbrev=13 b1^) >expected &&
	test_config core.abbrev 13 &&
	shit checkout b1^ &&
	test_when_finished "shit checkout main" &&
	__shit_ps1 >"$actual" &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - describe detached head - contains' '
	printf " ((t2~1))" >expected &&
	shit checkout b1^ &&
	test_when_finished "shit checkout main" &&
	(
		shit_PS1_DESCRIBE_STYLE=contains &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - describe detached head - branch' '
	printf " ((tags/t2~1))" >expected &&
	shit checkout b1^ &&
	test_when_finished "shit checkout main" &&
	(
		shit_PS1_DESCRIBE_STYLE=branch &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - describe detached head - describe' '
	printf " ((t1-1-g%s))" $(shit log -1 --format="%h" b1^) >expected &&
	shit checkout b1^ &&
	test_when_finished "shit checkout main" &&
	(
		shit_PS1_DESCRIBE_STYLE=describe &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - describe detached head - default' '
	printf " ((t2))" >expected &&
	shit checkout --detach b1 &&
	test_when_finished "shit checkout main" &&
	__shit_ps1 >"$actual" &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - inside .shit directory' '
	printf " (shit_DIR!)" >expected &&
	(
		cd .shit &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - deep inside .shit directory' '
	printf " (shit_DIR!)" >expected &&
	(
		cd .shit/objects &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - inside bare repository' '
	printf " (BARE:main)" >expected &&
	shit init --bare bare.shit &&
	test_when_finished "rm -rf bare.shit" &&
	(
		cd bare.shit &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - interactive rebase' '
	printf " (b1|REBASE 2/3)" >expected &&
	write_script fake_editor.sh <<-\EOF &&
		echo "exec echo" >"$1"
		echo "edit $(shit log -1 --format="%h")" >>"$1"
		echo "exec echo" >>"$1"
	EOF
	test_when_finished "rm -f fake_editor.sh" &&
	test_set_editor "$TRASH_DIRECTORY/fake_editor.sh" &&
	shit checkout b1 &&
	test_when_finished "shit checkout main" &&
	shit rebase -i HEAD^ &&
	test_when_finished "shit rebase --abort" &&
	__shit_ps1 >"$actual" &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - rebase merge' '
	printf " (b2|REBASE 1/3)" >expected &&
	shit checkout b2 &&
	test_when_finished "shit checkout main" &&
	test_must_fail shit rebase --merge b1 b2 &&
	test_when_finished "shit rebase --abort" &&
	__shit_ps1 >"$actual" &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - rebase am' '
	printf " (b2|REBASE 1/3)" >expected &&
	shit checkout b2 &&
	test_when_finished "shit checkout main" &&
	test_must_fail shit rebase --apply b1 b2 &&
	test_when_finished "shit rebase --abort" &&
	__shit_ps1 >"$actual" &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - merge' '
	printf " (b1|MERGING)" >expected &&
	shit checkout b1 &&
	test_when_finished "shit checkout main" &&
	test_must_fail shit merge b2 &&
	test_when_finished "shit reset --hard" &&
	__shit_ps1 >"$actual" &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - cherry-pick' '
	printf " (main|CHERRY-PICKING)" >expected &&
	test_must_fail shit cherry-pick b1 b1^ &&
	test_when_finished "shit cherry-pick --abort" &&
	__shit_ps1 >"$actual" &&
	test_cmp expected "$actual" &&
	shit reset --merge &&
	test_must_fail shit rev-parse CHERRY_PICK_HEAD &&
	__shit_ps1 >"$actual" &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - revert' '
	printf " (main|REVERTING)" >expected &&
	test_must_fail shit revert b1^ b1 &&
	test_when_finished "shit revert --abort" &&
	__shit_ps1 >"$actual" &&
	test_cmp expected "$actual" &&
	shit reset --merge &&
	test_must_fail shit rev-parse REVERT_HEAD &&
	__shit_ps1 >"$actual" &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - bisect' '
	printf " (main|BISECTING)" >expected &&
	shit bisect start &&
	test_when_finished "shit bisect reset" &&
	__shit_ps1 >"$actual" &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - dirty status indicator - clean' '
	printf " (main)" >expected &&
	(
		shit_PS1_SHOWDIRTYSTATE=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - dirty status indicator - dirty worktree' '
	printf " (main *)" >expected &&
	echo "dirty" >file &&
	test_when_finished "shit reset --hard" &&
	(
		shit_PS1_SHOWDIRTYSTATE=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - dirty status indicator - dirty index' '
	printf " (main +)" >expected &&
	echo "dirty" >file &&
	test_when_finished "shit reset --hard" &&
	shit add -u &&
	(
		shit_PS1_SHOWDIRTYSTATE=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - dirty status indicator - dirty index and worktree' '
	printf " (main *+)" >expected &&
	echo "dirty index" >file &&
	test_when_finished "shit reset --hard" &&
	shit add -u &&
	echo "dirty worktree" >file &&
	(
		shit_PS1_SHOWDIRTYSTATE=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - dirty status indicator - orphan branch - clean' '
	printf " (orphan #)" >expected &&
	test_when_finished "shit checkout main" &&
	shit checkout --orphan orphan &&
	shit reset --hard &&
	(
		shit_PS1_SHOWDIRTYSTATE=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - dirty status indicator - orphan branch - dirty index' '
	printf " (orphan +)" >expected &&
	test_when_finished "shit checkout main" &&
	shit checkout --orphan orphan &&
	(
		shit_PS1_SHOWDIRTYSTATE=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - dirty status indicator - orphan branch - dirty index and worktree' '
	printf " (orphan *+)" >expected &&
	test_when_finished "shit checkout main" &&
	shit checkout --orphan orphan &&
	>file &&
	(
		shit_PS1_SHOWDIRTYSTATE=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - dirty status indicator - shell variable unset with config disabled' '
	printf " (main)" >expected &&
	echo "dirty" >file &&
	test_when_finished "shit reset --hard" &&
	test_config bash.showDirtyState false &&
	(
		sane_unset shit_PS1_SHOWDIRTYSTATE &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - dirty status indicator - shell variable unset with config enabled' '
	printf " (main)" >expected &&
	echo "dirty" >file &&
	test_when_finished "shit reset --hard" &&
	test_config bash.showDirtyState true &&
	(
		sane_unset shit_PS1_SHOWDIRTYSTATE &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - dirty status indicator - shell variable set with config disabled' '
	printf " (main)" >expected &&
	echo "dirty" >file &&
	test_when_finished "shit reset --hard" &&
	test_config bash.showDirtyState false &&
	(
		shit_PS1_SHOWDIRTYSTATE=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - dirty status indicator - shell variable set with config enabled' '
	printf " (main *)" >expected &&
	echo "dirty" >file &&
	test_when_finished "shit reset --hard" &&
	test_config bash.showDirtyState true &&
	(
		shit_PS1_SHOWDIRTYSTATE=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - dirty status indicator - not shown inside .shit directory' '
	printf " (shit_DIR!)" >expected &&
	echo "dirty" >file &&
	test_when_finished "shit reset --hard" &&
	(
		shit_PS1_SHOWDIRTYSTATE=y &&
		cd .shit &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - stash status indicator - no stash' '
	printf " (main)" >expected &&
	(
		shit_PS1_SHOWSTASHSTATE=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - stash status indicator - stash' '
	printf " (main $)" >expected &&
	echo 2 >file &&
	shit stash &&
	test_when_finished "shit stash drop" &&
	shit pack-refs --all &&
	(
		shit_PS1_SHOWSTASHSTATE=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - stash status indicator - not shown inside .shit directory' '
	printf " (shit_DIR!)" >expected &&
	echo 2 >file &&
	shit stash &&
	test_when_finished "shit stash drop" &&
	(
		shit_PS1_SHOWSTASHSTATE=y &&
		cd .shit &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - untracked files status indicator - no untracked files' '
	printf " (main)" >expected &&
	(
		shit_PS1_SHOWUNTRACKEDFILES=y &&
		cd otherrepo &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - untracked files status indicator - untracked files' '
	printf " (main %%)" >expected &&
	(
		shit_PS1_SHOWUNTRACKEDFILES=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - untracked files status indicator - empty untracked dir' '
	printf " (main)" >expected &&
	mkdir otherrepo/untracked-dir &&
	test_when_finished "rm -rf otherrepo/untracked-dir" &&
	(
		shit_PS1_SHOWUNTRACKEDFILES=y &&
		cd otherrepo &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - untracked files status indicator - non-empty untracked dir' '
	printf " (main %%)" >expected &&
	mkdir otherrepo/untracked-dir &&
	test_when_finished "rm -rf otherrepo/untracked-dir" &&
	>otherrepo/untracked-dir/untracked-file &&
	(
		shit_PS1_SHOWUNTRACKEDFILES=y &&
		cd otherrepo &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - untracked files status indicator - untracked files outside cwd' '
	printf " (main %%)" >expected &&
	(
		mkdir -p ignored_dir &&
		cd ignored_dir &&
		shit_PS1_SHOWUNTRACKEDFILES=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - untracked files status indicator - shell variable unset with config disabled' '
	printf " (main)" >expected &&
	test_config bash.showUntrackedFiles false &&
	(
		sane_unset shit_PS1_SHOWUNTRACKEDFILES &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - untracked files status indicator - shell variable unset with config enabled' '
	printf " (main)" >expected &&
	test_config bash.showUntrackedFiles true &&
	(
		sane_unset shit_PS1_SHOWUNTRACKEDFILES &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - untracked files status indicator - shell variable set with config disabled' '
	printf " (main)" >expected &&
	test_config bash.showUntrackedFiles false &&
	(
		shit_PS1_SHOWUNTRACKEDFILES=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - untracked files status indicator - shell variable set with config enabled' '
	printf " (main %%)" >expected &&
	test_config bash.showUntrackedFiles true &&
	(
		shit_PS1_SHOWUNTRACKEDFILES=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - untracked files status indicator - not shown inside .shit directory' '
	printf " (shit_DIR!)" >expected &&
	(
		shit_PS1_SHOWUNTRACKEDFILES=y &&
		cd .shit &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - format string starting with dash' '
	printf -- "-main" >expected &&
	__shit_ps1 "-%s" >"$actual" &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - pc mode' '
	printf "BEFORE: (\${__shit_ps1_branch_name}):AFTER\\nmain" >expected &&
	(
		__shit_ps1 "BEFORE:" ":AFTER" >"$actual" &&
		test_must_be_empty "$actual" &&
		printf "%s\\n%s" "$PS1" "${__shit_ps1_branch_name}" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - bash color pc mode - branch name' '
	printf "BEFORE: (${c_green}\${__shit_ps1_branch_name}${c_clear}):AFTER\\nmain" >expected &&
	(
		shit_PS1_SHOWCOLORHINTS=y &&
		__shit_ps1 "BEFORE:" ":AFTER" >"$actual" &&
		printf "%s\\n%s" "$PS1" "${__shit_ps1_branch_name}" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - bash color pc mode - detached head' '
	printf "BEFORE: (${c_red}\${__shit_ps1_branch_name}${c_clear}):AFTER\\n(%s...)" $(shit log -1 --format="%h" b1^) >expected &&
	shit checkout b1^ &&
	test_when_finished "shit checkout main" &&
	(
		shit_PS1_SHOWCOLORHINTS=y &&
		__shit_ps1 "BEFORE:" ":AFTER" &&
		printf "%s\\n%s" "$PS1" "${__shit_ps1_branch_name}" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - bash color pc mode - dirty status indicator - dirty worktree' '
	printf "BEFORE: (${c_green}\${__shit_ps1_branch_name}${c_clear} ${c_red}*${c_clear}):AFTER\\nmain" >expected &&
	echo "dirty" >file &&
	test_when_finished "shit reset --hard" &&
	(
		shit_PS1_SHOWDIRTYSTATE=y &&
		shit_PS1_SHOWCOLORHINTS=y &&
		__shit_ps1 "BEFORE:" ":AFTER" &&
		printf "%s\\n%s" "$PS1" "${__shit_ps1_branch_name}" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - bash color pc mode - dirty status indicator - dirty index' '
	printf "BEFORE: (${c_green}\${__shit_ps1_branch_name}${c_clear} ${c_green}+${c_clear}):AFTER\\nmain" >expected &&
	echo "dirty" >file &&
	test_when_finished "shit reset --hard" &&
	shit add -u &&
	(
		shit_PS1_SHOWDIRTYSTATE=y &&
		shit_PS1_SHOWCOLORHINTS=y &&
		__shit_ps1 "BEFORE:" ":AFTER" &&
		printf "%s\\n%s" "$PS1" "${__shit_ps1_branch_name}" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - bash color pc mode - dirty status indicator - dirty index and worktree' '
	printf "BEFORE: (${c_green}\${__shit_ps1_branch_name}${c_clear} ${c_red}*${c_clear}${c_green}+${c_clear}):AFTER\\nmain" >expected &&
	echo "dirty index" >file &&
	test_when_finished "shit reset --hard" &&
	shit add -u &&
	echo "dirty worktree" >file &&
	(
		shit_PS1_SHOWCOLORHINTS=y &&
		shit_PS1_SHOWDIRTYSTATE=y &&
		__shit_ps1 "BEFORE:" ":AFTER" &&
		printf "%s\\n%s" "$PS1" "${__shit_ps1_branch_name}" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - bash color pc mode - dirty status indicator - before root commit' '
	printf "BEFORE: (${c_green}\${__shit_ps1_branch_name}${c_clear} ${c_green}#${c_clear}):AFTER\\nmain" >expected &&
	(
		shit_PS1_SHOWDIRTYSTATE=y &&
		shit_PS1_SHOWCOLORHINTS=y &&
		cd otherrepo &&
		__shit_ps1 "BEFORE:" ":AFTER" &&
		printf "%s\\n%s" "$PS1" "${__shit_ps1_branch_name}" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - bash color pc mode - inside .shit directory' '
	printf "BEFORE: (${c_green}\${__shit_ps1_branch_name}${c_clear}):AFTER\\nshit_DIR!" >expected &&
	echo "dirty" >file &&
	test_when_finished "shit reset --hard" &&
	(
		shit_PS1_SHOWDIRTYSTATE=y &&
		shit_PS1_SHOWCOLORHINTS=y &&
		cd .shit &&
		__shit_ps1 "BEFORE:" ":AFTER" &&
		printf "%s\\n%s" "$PS1" "${__shit_ps1_branch_name}" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - bash color pc mode - stash status indicator' '
	printf "BEFORE: (${c_green}\${__shit_ps1_branch_name}${c_clear} ${c_lblue}\$${c_clear}):AFTER\\nmain" >expected &&
	echo 2 >file &&
	shit stash &&
	test_when_finished "shit stash drop" &&
	(
		shit_PS1_SHOWSTASHSTATE=y &&
		shit_PS1_SHOWCOLORHINTS=y &&
		__shit_ps1 "BEFORE:" ":AFTER" &&
		printf "%s\\n%s" "$PS1" "${__shit_ps1_branch_name}" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - bash color pc mode - untracked files status indicator' '
	printf "BEFORE: (${c_green}\${__shit_ps1_branch_name}${c_clear} ${c_red}%%${c_clear}):AFTER\\nmain" >expected &&
	(
		shit_PS1_SHOWUNTRACKEDFILES=y &&
		shit_PS1_SHOWCOLORHINTS=y &&
		__shit_ps1 "BEFORE:" ":AFTER" &&
		printf "%s\\n%s" "$PS1" "${__shit_ps1_branch_name}" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - zsh color pc mode' '
	printf "BEFORE: (%%F{green}main%%f):AFTER" >expected &&
	(
		ZSH_VERSION=5.0.0 &&
		shit_PS1_SHOWCOLORHINTS=y &&
		__shit_ps1 "BEFORE:" ":AFTER" &&
		printf "%s" "$PS1" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - hide if pwd ignored - env var unset, config disabled' '
	printf " (main)" >expected &&
	test_config bash.hideIfPwdIgnored false &&
	(
		cd ignored_dir &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - hide if pwd ignored - env var unset, config disabled, pc mode' '
	printf "BEFORE: (\${__shit_ps1_branch_name}):AFTER" >expected &&
	test_config bash.hideIfPwdIgnored false &&
	(
		cd ignored_dir &&
		__shit_ps1 "BEFORE:" ":AFTER" &&
		printf "%s" "$PS1" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - hide if pwd ignored - env var unset, config unset' '
	printf " (main)" >expected &&
	(
		cd ignored_dir &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - hide if pwd ignored - env var unset, config unset, pc mode' '
	printf "BEFORE: (\${__shit_ps1_branch_name}):AFTER" >expected &&
	(
		cd ignored_dir &&
		__shit_ps1 "BEFORE:" ":AFTER" &&
		printf "%s" "$PS1" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - hide if pwd ignored - env var set, config disabled' '
	printf " (main)" >expected &&
	test_config bash.hideIfPwdIgnored false &&
	(
		cd ignored_dir &&
		shit_PS1_HIDE_IF_PWD_IGNORED=y &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - hide if pwd ignored - env var set, config disabled, pc mode' '
	printf "BEFORE: (\${__shit_ps1_branch_name}):AFTER" >expected &&
	test_config bash.hideIfPwdIgnored false &&
	(
		cd ignored_dir &&
		shit_PS1_HIDE_IF_PWD_IGNORED=y &&
		__shit_ps1 "BEFORE:" ":AFTER" &&
		printf "%s" "$PS1" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - hide if pwd ignored - env var set, config unset' '
	(
		cd ignored_dir &&
		shit_PS1_HIDE_IF_PWD_IGNORED=y &&
		__shit_ps1 >"$actual"
	) &&
	test_must_be_empty "$actual"
'

test_expect_success 'prompt - hide if pwd ignored - env var set, config unset, pc mode' '
	printf "BEFORE::AFTER" >expected &&
	(
		cd ignored_dir &&
		shit_PS1_HIDE_IF_PWD_IGNORED=y &&
		__shit_ps1 "BEFORE:" ":AFTER" &&
		printf "%s" "$PS1" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - hide if pwd ignored - inside shitdir' '
	printf " (shit_DIR!)" >expected &&
	(
		shit_PS1_HIDE_IF_PWD_IGNORED=y &&
		cd .shit &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'prompt - conflict indicator' '
	printf " (main|CONFLICT)" >expected &&
	echo "stash" >file &&
	shit stash &&
	test_when_finished "shit stash drop" &&
	echo "commit" >file &&
	shit commit -m "commit" file &&
	test_when_finished "shit reset --hard HEAD~" &&
	test_must_fail shit stash apply &&
	(
		shit_PS1_SHOWCONFLICTSTATE="yes" &&
		__shit_ps1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_done
