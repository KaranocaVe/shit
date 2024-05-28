#!/bin/sh
#
# Copyright (c) 2012-2020 Felipe Contreras
#

test_description='test bash completion'

# The Bash completion scripts must not print anything to either stdout or
# stderr, which we try to verify. When tracing is enabled without support for
# BASH_XTRACEFD this assertion will fail, so we have to mark the test as
# untraceable with such ancient Bash versions.
test_untraceable=UnfortunatelyYes

# Override environment and always use master for the default initial branch
# name for these tests, so that rev completion candidates are as expected.
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=master
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./lib-bash.sh

complete ()
{
	# do nothing
	return 0
}

# Be careful when updating these lists:
#
# (1) The build tree may have build artifact from different branch, or
#     the user's $PATH may have a random executable that may begin
#     with "shit-check" that are not part of the subcommands this build
#     will ship, e.g.  "check-ignore".  The tests for completion for
#     subcommand names tests how "check" is expanded; we limit the
#     possible candidates to "checkout" and "check-attr" to make sure
#     "check-attr", which is known by the filter function as a
#     subcommand to be thrown out, while excluding other random files
#     that happen to begin with "check" to avoid letting them get in
#     the way.
#
# (2) A test makes sure that common subcommands are included in the
#     completion for "shit <TAB>", and a plumbing is excluded.  "add",
#     "rebase" and "ls-files" are listed for this.

shit_TESTING_ALL_COMMAND_LIST='add checkout check-attr rebase ls-files'
shit_TESTING_PORCELAIN_COMMAND_LIST='add checkout rebase'

. "$shit_BUILD_DIR/contrib/completion/shit-completion.bash"

# We don't need this function to actually join words or do anything special.
# Also, it's cleaner to avoid touching bash's internal completion variables.
# So let's override it with a minimal version for testing purposes.
_get_comp_words_by_ref ()
{
	while [ $# -gt 0 ]; do
		case "$1" in
		cur)
			cur=${_words[_cword]}
			;;
		prev)
			prev=${_words[_cword-1]}
			;;
		words)
			words=("${_words[@]}")
			;;
		cword)
			cword=$_cword
			;;
		esac
		shift
	done
}

print_comp ()
{
	local IFS=$'\n'
	printf '%s\n' "${COMPREPLY[*]}" > out
}

run_completion ()
{
	local -a COMPREPLY _words
	local _cword
	_words=( $1 )
	test "${1: -1}" = ' ' && _words[${#_words[@]}+1]=''
	(( _cword = ${#_words[@]} - 1 ))
	__shit_wrap__shit_main && print_comp
}

# Test high-level completion
# Arguments are:
# 1: typed text so far (cur)
# 2: expected completion
test_completion ()
{
	if test $# -gt 1
	then
		printf '%s\n' "$2" >expected
	else
		sed -e 's/Z$//' |sort >expected
	fi &&
	run_completion "$1" >"$TRASH_DIRECTORY"/bash-completion-output 2>&1 &&
	sort out >out_sorted &&
	test_cmp expected out_sorted &&
	test_must_be_empty "$TRASH_DIRECTORY"/bash-completion-output &&
	rm "$TRASH_DIRECTORY"/bash-completion-output
}

# Test __shitcomp.
# The first argument is the typed text so far (cur); the rest are
# passed to __shitcomp.  Expected output comes is read from the
# standard input, like test_completion().
test_shitcomp ()
{
	local -a COMPREPLY &&
	sed -e 's/Z$//' >expected &&
	local cur="$1" &&
	shift &&
	__shitcomp "$@" &&
	print_comp &&
	test_cmp expected out
}

# Test __shitcomp_nl
# Arguments are:
# 1: current word (cur)
# -: the rest are passed to __shitcomp_nl
test_shitcomp_nl ()
{
	local -a COMPREPLY &&
	sed -e 's/Z$//' >expected &&
	local cur="$1" &&
	shift &&
	__shitcomp_nl "$@" &&
	print_comp &&
	test_cmp expected out
}

invalid_variable_name='${foo.bar}'

actual="$TRASH_DIRECTORY/actual"

if test_have_prereq MINGW
then
	ROOT="$(pwd -W)"
else
	ROOT="$(pwd)"
fi

test_expect_success 'setup for __shit_find_repo_path/__shitdir tests' '
	mkdir -p subdir/subsubdir &&
	mkdir -p non-repo &&
	shit init -b main otherrepo
'

test_expect_success '__shit_find_repo_path - from command line (through $__shit_dir)' '
	echo "$ROOT/otherrepo/.shit" >expected &&
	(
		__shit_dir="$ROOT/otherrepo/.shit" &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - .shit directory in cwd' '
	echo ".shit" >expected &&
	(
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - .shit directory in parent' '
	echo "$ROOT/.shit" >expected &&
	(
		cd subdir/subsubdir &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - cwd is a .shit directory' '
	echo "." >expected &&
	(
		cd .shit &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - parent is a .shit directory' '
	echo "$ROOT/.shit" >expected &&
	(
		cd .shit/objects &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - $shit_DIR set while .shit directory in cwd' '
	echo "$ROOT/otherrepo/.shit" >expected &&
	(
		shit_DIR="$ROOT/otherrepo/.shit" &&
		export shit_DIR &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - $shit_DIR set while .shit directory in parent' '
	echo "$ROOT/otherrepo/.shit" >expected &&
	(
		shit_DIR="$ROOT/otherrepo/.shit" &&
		export shit_DIR &&
		cd subdir &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - from command line while "shit -C"' '
	echo "$ROOT/.shit" >expected &&
	(
		__shit_dir="$ROOT/.shit" &&
		__shit_C_args=(-C otherrepo) &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - relative dir from command line and "shit -C"' '
	echo "$ROOT/otherrepo/.shit" >expected &&
	(
		cd subdir &&
		__shit_dir="otherrepo/.shit" &&
		__shit_C_args=(-C ..) &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - $shit_DIR set while "shit -C"' '
	echo "$ROOT/.shit" >expected &&
	(
		shit_DIR="$ROOT/.shit" &&
		export shit_DIR &&
		__shit_C_args=(-C otherrepo) &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - relative dir in $shit_DIR and "shit -C"' '
	echo "$ROOT/otherrepo/.shit" >expected &&
	(
		cd subdir &&
		shit_DIR="otherrepo/.shit" &&
		export shit_DIR &&
		__shit_C_args=(-C ..) &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - "shit -C" while .shit directory in cwd' '
	echo "$ROOT/otherrepo/.shit" >expected &&
	(
		__shit_C_args=(-C otherrepo) &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - "shit -C" while cwd is a .shit directory' '
	echo "$ROOT/otherrepo/.shit" >expected &&
	(
		cd .shit &&
		__shit_C_args=(-C .. -C otherrepo) &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - "shit -C" while .shit directory in parent' '
	echo "$ROOT/otherrepo/.shit" >expected &&
	(
		cd subdir &&
		__shit_C_args=(-C .. -C otherrepo) &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - non-existing path in "shit -C"' '
	(
		__shit_C_args=(-C non-existing) &&
		test_must_fail __shit_find_repo_path &&
		printf "$__shit_repo_path" >"$actual"
	) &&
	test_must_be_empty "$actual"
'

test_expect_success '__shit_find_repo_path - non-existing path in $__shit_dir' '
	(
		__shit_dir="non-existing" &&
		test_must_fail __shit_find_repo_path &&
		printf "$__shit_repo_path" >"$actual"
	) &&
	test_must_be_empty "$actual"
'

test_expect_success '__shit_find_repo_path - non-existing $shit_DIR' '
	(
		shit_DIR="$ROOT/non-existing" &&
		export shit_DIR &&
		test_must_fail __shit_find_repo_path &&
		printf "$__shit_repo_path" >"$actual"
	) &&
	test_must_be_empty "$actual"
'

test_expect_success '__shit_find_repo_path - shitfile in cwd' '
	echo "$ROOT/otherrepo/.shit" >expected &&
	echo "shitdir: $ROOT/otherrepo/.shit" >subdir/.shit &&
	test_when_finished "rm -f subdir/.shit" &&
	(
		cd subdir &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - shitfile in parent' '
	echo "$ROOT/otherrepo/.shit" >expected &&
	echo "shitdir: $ROOT/otherrepo/.shit" >subdir/.shit &&
	test_when_finished "rm -f subdir/.shit" &&
	(
		cd subdir/subsubdir &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success SYMLINKS '__shit_find_repo_path - resulting path avoids symlinks' '
	echo "$ROOT/otherrepo/.shit" >expected &&
	mkdir otherrepo/dir &&
	test_when_finished "rm -rf otherrepo/dir" &&
	ln -s otherrepo/dir link &&
	test_when_finished "rm -f link" &&
	(
		cd link &&
		__shit_find_repo_path &&
		echo "$__shit_repo_path" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_find_repo_path - not a shit repository' '
	(
		cd non-repo &&
		shit_CEILING_DIRECTORIES="$ROOT" &&
		export shit_CEILING_DIRECTORIES &&
		test_must_fail __shit_find_repo_path &&
		printf "$__shit_repo_path" >"$actual"
	) &&
	test_must_be_empty "$actual"
'

test_expect_success '__shitdir - finds repo' '
	echo "$ROOT/.shit" >expected &&
	(
		cd subdir/subsubdir &&
		__shitdir >"$actual"
	) &&
	test_cmp expected "$actual"
'


test_expect_success '__shitdir - returns error when cannot find repo' '
	(
		__shit_dir="non-existing" &&
		test_must_fail __shitdir >"$actual"
	) &&
	test_must_be_empty "$actual"
'

test_expect_success '__shitdir - repo as argument' '
	echo "otherrepo/.shit" >expected &&
	(
		__shitdir "otherrepo" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shitdir - remote as argument' '
	echo "remote" >expected &&
	(
		__shitdir "remote" >"$actual"
	) &&
	test_cmp expected "$actual"
'


test_expect_success '__shit_dequote - plain unquoted word' '
	__shit_dequote unquoted-word &&
	test unquoted-word = "$dequoted_word"
'

# input:    b\a\c\k\'\\\"s\l\a\s\h\es
# expected: back'\"slashes
test_expect_success '__shit_dequote - backslash escaped' '
	__shit_dequote "b\a\c\k\\'\''\\\\\\\"s\l\a\s\h\es" &&
	test "back'\''\\\"slashes" = "$dequoted_word"
'

# input:    sin'gle\' '"quo'ted
# expected: single\ "quoted
test_expect_success '__shit_dequote - single quoted' '
	__shit_dequote "'"sin'gle\\\\' '\\\"quo'ted"'" &&
	test '\''single\ "quoted'\'' = "$dequoted_word"
'

# input:    dou"ble\\" "\"\quot"ed
# expected: double\ "\quoted
test_expect_success '__shit_dequote - double quoted' '
	__shit_dequote '\''dou"ble\\" "\"\quot"ed'\'' &&
	test '\''double\ "\quoted'\'' = "$dequoted_word"
'

# input: 'open single quote
test_expect_success '__shit_dequote - open single quote' '
	__shit_dequote "'\''open single quote" &&
	test "open single quote" = "$dequoted_word"
'

# input: "open double quote
test_expect_success '__shit_dequote - open double quote' '
	__shit_dequote "\"open double quote" &&
	test "open double quote" = "$dequoted_word"
'


test_expect_success '__shitcomp_direct - puts everything into COMPREPLY as-is' '
	sed -e "s/Z$//g" >expected <<-EOF &&
	with-trailing-space Z
	without-trailing-spaceZ
	--option Z
	--option=Z
	$invalid_variable_name Z
	EOF
	(
		cur=should_be_ignored &&
		__shitcomp_direct "$(cat expected)" &&
		print_comp
	) &&
	test_cmp expected out
'

test_expect_success '__shitcomp - trailing space - options' '
	test_shitcomp "--re" "--dry-run --reuse-message= --reedit-message=
		--reset-author" <<-EOF
	--reuse-message=Z
	--reedit-message=Z
	--reset-author Z
	EOF
'

test_expect_success '__shitcomp - trailing space - config keys' '
	test_shitcomp "br" "branch. branch.autosetupmerge
		branch.autosetuprebase browser." <<-\EOF
	branch.Z
	branch.autosetupmerge Z
	branch.autosetuprebase Z
	browser.Z
	EOF
'

test_expect_success '__shitcomp - option parameter' '
	test_shitcomp "--strategy=re" "octopus ours recursive resolve subtree" \
		"" "re" <<-\EOF
	recursive Z
	resolve Z
	EOF
'

test_expect_success '__shitcomp - prefix' '
	test_shitcomp "branch.me" "remote merge mergeoptions rebase" \
		"branch.maint." "me" <<-\EOF
	branch.maint.merge Z
	branch.maint.mergeoptions Z
	EOF
'

test_expect_success '__shitcomp - suffix' '
	test_shitcomp "branch.me" "master maint next seen" "branch." \
		"ma" "." <<-\EOF
	branch.master.Z
	branch.maint.Z
	EOF
'

test_expect_success '__shitcomp - ignore optional negative options' '
	test_shitcomp "--" "--abc --def --no-one -- --no-two" <<-\EOF
	--abc Z
	--def Z
	--no-one Z
	--no-... Z
	EOF
'

test_expect_success '__shitcomp - ignore/narrow optional negative options' '
	test_shitcomp "--a" "--abc --abcdef --no-one -- --no-two" <<-\EOF
	--abc Z
	--abcdef Z
	EOF
'

test_expect_success '__shitcomp - ignore/narrow optional negative options' '
	test_shitcomp "--n" "--abc --def --no-one -- --no-two" <<-\EOF
	--no-one Z
	--no-... Z
	EOF
'

test_expect_success '__shitcomp - expand all negative options' '
	test_shitcomp "--no-" "--abc --def --no-one -- --no-two" <<-\EOF
	--no-one Z
	--no-two Z
	EOF
'

test_expect_success '__shitcomp - expand/narrow all negative options' '
	test_shitcomp "--no-o" "--abc --def --no-one -- --no-two" <<-\EOF
	--no-one Z
	EOF
'

test_expect_success '__shitcomp - equal skip' '
	test_shitcomp "--option=" "--option=" <<-\EOF &&

	EOF
	test_shitcomp "option=" "option=" <<-\EOF

	EOF
'

test_expect_success '__shitcomp - doesnt fail because of invalid variable name' '
	__shitcomp "$invalid_variable_name"
'

read -r -d "" refs <<-\EOF
main
maint
next
seen
EOF

test_expect_success '__shitcomp_nl - trailing space' '
	test_shitcomp_nl "m" "$refs" <<-EOF
	main Z
	maint Z
	EOF
'

test_expect_success '__shitcomp_nl - prefix' '
	test_shitcomp_nl "--fixup=m" "$refs" "--fixup=" "m" <<-EOF
	--fixup=main Z
	--fixup=maint Z
	EOF
'

test_expect_success '__shitcomp_nl - suffix' '
	test_shitcomp_nl "branch.ma" "$refs" "branch." "ma" "." <<-\EOF
	branch.main.Z
	branch.maint.Z
	EOF
'

test_expect_success '__shitcomp_nl - no suffix' '
	test_shitcomp_nl "ma" "$refs" "" "ma" "" <<-\EOF
	mainZ
	maintZ
	EOF
'

test_expect_success '__shitcomp_nl - doesnt fail because of invalid variable name' '
	__shitcomp_nl "$invalid_variable_name"
'

test_expect_success '__shit_remotes - list remotes from $shit_DIR/remotes and from config file' '
	cat >expect <<-EOF &&
	remote_from_file_1
	remote_from_file_2
	remote_in_config_1
	remote_in_config_2
	EOF
	test_when_finished "rm -rf .shit/remotes" &&
	mkdir -p .shit/remotes &&
	>.shit/remotes/remote_from_file_1 &&
	>.shit/remotes/remote_from_file_2 &&
	test_when_finished "shit remote remove remote_in_config_1" &&
	shit remote add remote_in_config_1 shit://remote_1 &&
	test_when_finished "shit remote remove remote_in_config_2" &&
	shit remote add remote_in_config_2 shit://remote_2 &&
	(
		__shit_remotes >actual
	) &&
	test_cmp expect actual
'

test_expect_success '__shit_is_configured_remote' '
	test_when_finished "shit remote remove remote_1" &&
	shit remote add remote_1 shit://remote_1 &&
	test_when_finished "shit remote remove remote_2" &&
	shit remote add remote_2 shit://remote_2 &&
	(
		__shit_is_configured_remote remote_2 &&
		test_must_fail __shit_is_configured_remote non-existent
	)
'

test_expect_success 'setup for ref completion' '
	shit commit --allow-empty -m initial &&
	shit branch -M main &&
	shit branch matching-branch &&
	shit tag matching-tag &&
	(
		cd otherrepo &&
		shit commit --allow-empty -m initial &&
		shit branch -m main main-in-other &&
		shit branch branch-in-other &&
		shit tag tag-in-other
	) &&
	shit remote add other "$ROOT/otherrepo/.shit" &&
	shit fetch --no-tags other &&
	rm -f .shit/FETCH_HEAD &&
	shit init thirdrepo
'

test_expect_success '__shit_refs - simple' '
	cat >expected <<-EOF &&
	HEAD
	main
	matching-branch
	other/branch-in-other
	other/main-in-other
	matching-tag
	EOF
	(
		cur= &&
		__shit_refs >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - full refs' '
	cat >expected <<-EOF &&
	refs/heads/main
	refs/heads/matching-branch
	refs/remotes/other/branch-in-other
	refs/remotes/other/main-in-other
	refs/tags/matching-tag
	EOF
	(
		cur=refs/heads/ &&
		__shit_refs >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - repo given on the command line' '
	cat >expected <<-EOF &&
	HEAD
	branch-in-other
	main-in-other
	tag-in-other
	EOF
	(
		__shit_dir="$ROOT/otherrepo/.shit" &&
		cur= &&
		__shit_refs >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - remote on local file system' '
	cat >expected <<-EOF &&
	HEAD
	branch-in-other
	main-in-other
	tag-in-other
	EOF
	(
		cur= &&
		__shit_refs otherrepo >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - remote on local file system - full refs' '
	cat >expected <<-EOF &&
	refs/heads/branch-in-other
	refs/heads/main-in-other
	refs/tags/tag-in-other
	EOF
	(
		cur=refs/ &&
		__shit_refs otherrepo >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - configured remote' '
	cat >expected <<-EOF &&
	HEAD
	branch-in-other
	main-in-other
	EOF
	(
		cur= &&
		__shit_refs other >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - configured remote - full refs' '
	cat >expected <<-EOF &&
	HEAD
	refs/heads/branch-in-other
	refs/heads/main-in-other
	refs/tags/tag-in-other
	EOF
	(
		cur=refs/ &&
		__shit_refs other >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - configured remote - repo given on the command line' '
	cat >expected <<-EOF &&
	HEAD
	branch-in-other
	main-in-other
	EOF
	(
		cd thirdrepo &&
		__shit_dir="$ROOT/.shit" &&
		cur= &&
		__shit_refs other >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - configured remote - full refs - repo given on the command line' '
	cat >expected <<-EOF &&
	HEAD
	refs/heads/branch-in-other
	refs/heads/main-in-other
	refs/tags/tag-in-other
	EOF
	(
		cd thirdrepo &&
		__shit_dir="$ROOT/.shit" &&
		cur=refs/ &&
		__shit_refs other >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - configured remote - remote name matches a directory' '
	cat >expected <<-EOF &&
	HEAD
	branch-in-other
	main-in-other
	EOF
	mkdir other &&
	test_when_finished "rm -rf other" &&
	(
		cur= &&
		__shit_refs other >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - URL remote' '
	cat >expected <<-EOF &&
	HEAD
	branch-in-other
	main-in-other
	tag-in-other
	EOF
	(
		cur= &&
		__shit_refs "file://$ROOT/otherrepo/.shit" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - URL remote - full refs' '
	cat >expected <<-EOF &&
	HEAD
	refs/heads/branch-in-other
	refs/heads/main-in-other
	refs/tags/tag-in-other
	EOF
	(
		cur=refs/ &&
		__shit_refs "file://$ROOT/otherrepo/.shit" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - non-existing remote' '
	(
		cur= &&
		__shit_refs non-existing >"$actual"
	) &&
	test_must_be_empty "$actual"
'

test_expect_success '__shit_refs - non-existing remote - full refs' '
	(
		cur=refs/ &&
		__shit_refs non-existing >"$actual"
	) &&
	test_must_be_empty "$actual"
'

test_expect_success '__shit_refs - non-existing URL remote' '
	(
		cur= &&
		__shit_refs "file://$ROOT/non-existing" >"$actual"
	) &&
	test_must_be_empty "$actual"
'

test_expect_success '__shit_refs - non-existing URL remote - full refs' '
	(
		cur=refs/ &&
		__shit_refs "file://$ROOT/non-existing" >"$actual"
	) &&
	test_must_be_empty "$actual"
'

test_expect_success '__shit_refs - not in a shit repository' '
	(
		shit_CEILING_DIRECTORIES="$ROOT" &&
		export shit_CEILING_DIRECTORIES &&
		cd subdir &&
		cur= &&
		__shit_refs >"$actual"
	) &&
	test_must_be_empty "$actual"
'

test_expect_success '__shit_refs - unique remote branches for shit checkout DWIMery' '
	cat >expected <<-EOF &&
	HEAD
	main
	matching-branch
	other/ambiguous
	other/branch-in-other
	other/main-in-other
	remote/ambiguous
	remote/branch-in-remote
	matching-tag
	branch-in-other
	branch-in-remote
	main-in-other
	EOF
	for remote_ref in refs/remotes/other/ambiguous \
		refs/remotes/remote/ambiguous \
		refs/remotes/remote/branch-in-remote
	do
		shit update-ref $remote_ref main &&
		test_when_finished "shit update-ref -d $remote_ref" || return 1
	done &&
	(
		cur= &&
		__shit_refs "" 1 >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - after --opt=' '
	cat >expected <<-EOF &&
	HEAD
	main
	matching-branch
	other/branch-in-other
	other/main-in-other
	matching-tag
	EOF
	(
		cur="--opt=" &&
		__shit_refs "" "" "" "" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - after --opt= - full refs' '
	cat >expected <<-EOF &&
	refs/heads/main
	refs/heads/matching-branch
	refs/remotes/other/branch-in-other
	refs/remotes/other/main-in-other
	refs/tags/matching-tag
	EOF
	(
		cur="--opt=refs/" &&
		__shit_refs "" "" "" refs/ >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit refs - excluding refs' '
	cat >expected <<-EOF &&
	^HEAD
	^main
	^matching-branch
	^other/branch-in-other
	^other/main-in-other
	^matching-tag
	EOF
	(
		cur=^ &&
		__shit_refs >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit refs - excluding full refs' '
	cat >expected <<-EOF &&
	^refs/heads/main
	^refs/heads/matching-branch
	^refs/remotes/other/branch-in-other
	^refs/remotes/other/main-in-other
	^refs/tags/matching-tag
	EOF
	(
		cur=^refs/ &&
		__shit_refs >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'setup for filtering matching refs' '
	shit branch matching/branch &&
	shit tag matching/tag &&
	shit -C otherrepo branch matching/branch-in-other &&
	shit fetch --no-tags other &&
	rm -f .shit/FETCH_HEAD
'

test_expect_success '__shit_refs - do not filter refs unless told so' '
	cat >expected <<-EOF &&
	HEAD
	main
	matching-branch
	matching/branch
	other/branch-in-other
	other/main-in-other
	other/matching/branch-in-other
	matching-tag
	matching/tag
	EOF
	(
		cur=main &&
		__shit_refs >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - only matching refs' '
	cat >expected <<-EOF &&
	matching-branch
	matching/branch
	matching-tag
	matching/tag
	EOF
	(
		cur=mat &&
		__shit_refs "" "" "" "$cur" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - only matching refs - full refs' '
	cat >expected <<-EOF &&
	refs/heads/matching-branch
	refs/heads/matching/branch
	EOF
	(
		cur=refs/heads/mat &&
		__shit_refs "" "" "" "$cur" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - only matching refs - remote on local file system' '
	cat >expected <<-EOF &&
	main-in-other
	matching/branch-in-other
	EOF
	(
		cur=ma &&
		__shit_refs otherrepo "" "" "$cur" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - only matching refs - configured remote' '
	cat >expected <<-EOF &&
	main-in-other
	matching/branch-in-other
	EOF
	(
		cur=ma &&
		__shit_refs other "" "" "$cur" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - only matching refs - remote - full refs' '
	cat >expected <<-EOF &&
	refs/heads/main-in-other
	refs/heads/matching/branch-in-other
	EOF
	(
		cur=refs/heads/ma &&
		__shit_refs other "" "" "$cur" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_refs - only matching refs - checkout DWIMery' '
	cat >expected <<-EOF &&
	matching-branch
	matching/branch
	matching-tag
	matching/tag
	matching/branch-in-other
	EOF
	for remote_ref in refs/remotes/other/ambiguous \
		refs/remotes/remote/ambiguous \
		refs/remotes/remote/branch-in-remote
	do
		shit update-ref $remote_ref main &&
		test_when_finished "shit update-ref -d $remote_ref" || return 1
	done &&
	(
		cur=mat &&
		__shit_refs "" 1 "" "$cur" >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success 'teardown after filtering matching refs' '
	shit branch -d matching/branch &&
	shit tag -d matching/tag &&
	shit update-ref -d refs/remotes/other/matching/branch-in-other &&
	shit -C otherrepo branch -D matching/branch-in-other
'

test_expect_success '__shit_refs - for-each-ref format specifiers in prefix' '
	cat >expected <<-EOF &&
	evil-%%-%42-%(refname)..main
	EOF
	(
		cur="evil-%%-%42-%(refname)..mai" &&
		__shit_refs "" "" "evil-%%-%42-%(refname).." mai >"$actual"
	) &&
	test_cmp expected "$actual"
'

test_expect_success '__shit_complete_refs - simple' '
	sed -e "s/Z$//" >expected <<-EOF &&
	HEAD Z
	main Z
	matching-branch Z
	other/branch-in-other Z
	other/main-in-other Z
	matching-tag Z
	EOF
	(
		cur= &&
		__shit_complete_refs &&
		print_comp
	) &&
	test_cmp expected out
'

test_expect_success '__shit_complete_refs - matching' '
	sed -e "s/Z$//" >expected <<-EOF &&
	matching-branch Z
	matching-tag Z
	EOF
	(
		cur=mat &&
		__shit_complete_refs &&
		print_comp
	) &&
	test_cmp expected out
'

test_expect_success '__shit_complete_refs - remote' '
	sed -e "s/Z$//" >expected <<-EOF &&
	HEAD Z
	branch-in-other Z
	main-in-other Z
	EOF
	(
		cur= &&
		__shit_complete_refs --remote=other &&
		print_comp
	) &&
	test_cmp expected out
'

test_expect_success '__shit_complete_refs - track' '
	sed -e "s/Z$//" >expected <<-EOF &&
	HEAD Z
	main Z
	matching-branch Z
	other/branch-in-other Z
	other/main-in-other Z
	matching-tag Z
	branch-in-other Z
	main-in-other Z
	EOF
	(
		cur= &&
		__shit_complete_refs --track &&
		print_comp
	) &&
	test_cmp expected out
'

test_expect_success '__shit_complete_refs - current word' '
	sed -e "s/Z$//" >expected <<-EOF &&
	matching-branch Z
	matching-tag Z
	EOF
	(
		cur="--option=mat" &&
		__shit_complete_refs --cur="${cur#*=}" &&
		print_comp
	) &&
	test_cmp expected out
'

test_expect_success '__shit_complete_refs - prefix' '
	sed -e "s/Z$//" >expected <<-EOF &&
	v1.0..matching-branch Z
	v1.0..matching-tag Z
	EOF
	(
		cur=v1.0..mat &&
		__shit_complete_refs --pfx=v1.0.. --cur=mat &&
		print_comp
	) &&
	test_cmp expected out
'

test_expect_success '__shit_complete_refs - suffix' '
	cat >expected <<-EOF &&
	HEAD.
	main.
	matching-branch.
	other/branch-in-other.
	other/main-in-other.
	matching-tag.
	EOF
	(
		cur= &&
		__shit_complete_refs --sfx=. &&
		print_comp
	) &&
	test_cmp expected out
'

test_expect_success '__shit_complete_fetch_refspecs - simple' '
	sed -e "s/Z$//" >expected <<-EOF &&
	HEAD:HEAD Z
	branch-in-other:branch-in-other Z
	main-in-other:main-in-other Z
	EOF
	(
		cur= &&
		__shit_complete_fetch_refspecs other &&
		print_comp
	) &&
	test_cmp expected out
'

test_expect_success '__shit_complete_fetch_refspecs - matching' '
	sed -e "s/Z$//" >expected <<-EOF &&
	branch-in-other:branch-in-other Z
	EOF
	(
		cur=br &&
		__shit_complete_fetch_refspecs other "" br &&
		print_comp
	) &&
	test_cmp expected out
'

test_expect_success '__shit_complete_fetch_refspecs - prefix' '
	sed -e "s/Z$//" >expected <<-EOF &&
	+HEAD:HEAD Z
	+branch-in-other:branch-in-other Z
	+main-in-other:main-in-other Z
	EOF
	(
		cur="+" &&
		__shit_complete_fetch_refspecs other "+" ""  &&
		print_comp
	) &&
	test_cmp expected out
'

test_expect_success '__shit_complete_fetch_refspecs - fully qualified' '
	sed -e "s/Z$//" >expected <<-EOF &&
	refs/heads/branch-in-other:refs/heads/branch-in-other Z
	refs/heads/main-in-other:refs/heads/main-in-other Z
	refs/tags/tag-in-other:refs/tags/tag-in-other Z
	EOF
	(
		cur=refs/ &&
		__shit_complete_fetch_refspecs other "" refs/ &&
		print_comp
	) &&
	test_cmp expected out
'

test_expect_success '__shit_complete_fetch_refspecs - fully qualified & prefix' '
	sed -e "s/Z$//" >expected <<-EOF &&
	+refs/heads/branch-in-other:refs/heads/branch-in-other Z
	+refs/heads/main-in-other:refs/heads/main-in-other Z
	+refs/tags/tag-in-other:refs/tags/tag-in-other Z
	EOF
	(
		cur=+refs/ &&
		__shit_complete_fetch_refspecs other + refs/ &&
		print_comp
	) &&
	test_cmp expected out
'

test_expect_success '__shit_complete_worktree_paths' '
	test_when_finished "shit worktree remove other_wt" &&
	shit worktree add --orphan other_wt &&
	run_completion "shit worktree remove " &&
	grep other_wt out
'

test_expect_success '__shit_complete_worktree_paths - not a shit repository' '
	(
		cd non-repo &&
		shit_CEILING_DIRECTORIES="$ROOT" &&
		export shit_CEILING_DIRECTORIES &&
		test_completion "shit worktree remove " ""
	)
'

test_expect_success '__shit_complete_worktree_paths with -C' '
	test_when_finished "shit -C otherrepo worktree remove otherrepo_wt" &&
	shit -C otherrepo worktree add --orphan otherrepo_wt &&
	run_completion "shit -C otherrepo worktree remove " &&
	grep otherrepo_wt out
'

test_expect_success 'shit switch - with no options, complete local branches and unique remote branch names for DWIM logic' '
	test_completion "shit switch " <<-\EOF
	branch-in-other Z
	main Z
	main-in-other Z
	matching-branch Z
	EOF
'

test_expect_success 'shit bisect - when not bisecting, complete only replay and start subcommands' '
	test_completion "shit bisect " <<-\EOF
	replay Z
	start Z
	EOF
'

test_expect_success 'shit bisect - complete options to start subcommand' '
	test_completion "shit bisect start --" <<-\EOF
	--term-new Z
	--term-bad Z
	--term-old Z
	--term-good Z
	--no-checkout Z
	--first-parent Z
	EOF
'

test_expect_success 'setup for shit-bisect tests requiring a repo' '
	shit init shit-bisect &&
	(
		cd shit-bisect &&
		echo "initial contents" >file &&
		shit add file &&
		shit commit -am "Initial commit" &&
		shit tag initial &&
		echo "new line" >>file &&
		shit commit -am "First change" &&
		echo "another new line" >>file &&
		shit commit -am "Second change" &&
		shit tag final
	)
'

test_expect_success 'shit bisect - start subcommand arguments before double-dash are completed as revs' '
	(
		cd shit-bisect &&
		test_completion "shit bisect start " <<-\EOF
		HEAD Z
		final Z
		initial Z
		master Z
		EOF
	)
'

# Note that these arguments are <pathspec>s, which in practice the fallback
# completion (not the shit completion) later ends up completing as paths.
test_expect_success 'shit bisect - start subcommand arguments after double-dash are not completed' '
	(
		cd shit-bisect &&
		test_completion "shit bisect start final initial -- " ""
	)
'

test_expect_success 'setup for shit-bisect tests requiring ongoing bisection' '
	(
		cd shit-bisect &&
		shit bisect start --term-new=custom_new --term-old=custom_old final initial
	)
'

test_expect_success 'shit-bisect - when bisecting all subcommands are candidates' '
	(
		cd shit-bisect &&
		test_completion "shit bisect " <<-\EOF
		start Z
		bad Z
		custom_new Z
		custom_old Z
		new Z
		good Z
		old Z
		terms Z
		skip Z
		reset Z
		visualize Z
		replay Z
		log Z
		run Z
		help Z
		EOF
	)
'

test_expect_success 'shit-bisect - options to terms subcommand are candidates' '
	(
		cd shit-bisect &&
		test_completion "shit bisect terms --" <<-\EOF
		--term-bad Z
		--term-good Z
		--term-new Z
		--term-old Z
		EOF
	)
'

test_expect_success 'shit-bisect - shit-log options to visualize subcommand are candidates' '
	(
		cd shit-bisect &&
		# The completion used for shit-log and here does not complete
		# every shit-log option, so rather than hope to stay in sync
		# with exactly what it does we will just spot-test here.
		test_completion "shit bisect visualize --sta" <<-\EOF &&
		--stat Z
		EOF
		test_completion "shit bisect visualize --summar" <<-\EOF
		--summary Z
		EOF
	)
'

test_expect_success 'shit-bisect - view subcommand is not a candidate' '
	(
		cd shit-bisect &&
		test_completion "shit bisect vi" <<-\EOF
		visualize Z
		EOF
	)
'

test_expect_success 'shit-bisect - existing view subcommand is recognized and enables completion of shit-log options' '
	(
		cd shit-bisect &&
		# The completion used for shit-log and here does not complete
		# every shit-log option, so rather than hope to stay in sync
		# with exactly what it does we will just spot-test here.
		test_completion "shit bisect view --sta" <<-\EOF &&
		--stat Z
		EOF
		test_completion "shit bisect view --summar" <<-\EOF
		--summary Z
		EOF
	)
'

test_expect_success 'shit checkout - completes refs and unique remote branches for DWIM' '
	test_completion "shit checkout " <<-\EOF
	HEAD Z
	branch-in-other Z
	main Z
	main-in-other Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit switch - with --no-guess, complete only local branches' '
	test_completion "shit switch --no-guess " <<-\EOF
	main Z
	matching-branch Z
	EOF
'

test_expect_success 'shit switch - with shit_COMPLETION_CHECKOUT_NO_GUESS=1, complete only local branches' '
	shit_COMPLETION_CHECKOUT_NO_GUESS=1 test_completion "shit switch " <<-\EOF
	main Z
	matching-branch Z
	EOF
'

test_expect_success 'shit switch - --guess overrides shit_COMPLETION_CHECKOUT_NO_GUESS=1, complete local branches and unique remote names for DWIM logic' '
	shit_COMPLETION_CHECKOUT_NO_GUESS=1 test_completion "shit switch --guess " <<-\EOF
	branch-in-other Z
	main Z
	main-in-other Z
	matching-branch Z
	EOF
'

test_expect_success 'shit switch - a later --guess overrides previous --no-guess, complete local and remote unique branches for DWIM' '
	test_completion "shit switch --no-guess --guess " <<-\EOF
	branch-in-other Z
	main Z
	main-in-other Z
	matching-branch Z
	EOF
'

test_expect_success 'shit switch - a later --no-guess overrides previous --guess, complete only local branches' '
	test_completion "shit switch --guess --no-guess " <<-\EOF
	main Z
	matching-branch Z
	EOF
'

test_expect_success 'shit checkout - with shit_COMPLETION_NO_GUESS=1 only completes refs' '
	shit_COMPLETION_CHECKOUT_NO_GUESS=1 test_completion "shit checkout " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - --guess overrides shit_COMPLETION_NO_GUESS=1, complete refs and unique remote branches for DWIM' '
	shit_COMPLETION_CHECKOUT_NO_GUESS=1 test_completion "shit checkout --guess " <<-\EOF
	HEAD Z
	branch-in-other Z
	main Z
	main-in-other Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - with --no-guess, only completes refs' '
	test_completion "shit checkout --no-guess " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - a later --guess overrides previous --no-guess, complete refs and unique remote branches for DWIM' '
	test_completion "shit checkout --no-guess --guess " <<-\EOF
	HEAD Z
	branch-in-other Z
	main Z
	main-in-other Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - a later --no-guess overrides previous --guess, complete only refs' '
	test_completion "shit checkout --guess --no-guess " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - with checkout.guess = false, only completes refs' '
	test_config checkout.guess false &&
	test_completion "shit checkout " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - with checkout.guess = true, completes refs and unique remote branches for DWIM' '
	test_config checkout.guess true &&
	test_completion "shit checkout " <<-\EOF
	HEAD Z
	branch-in-other Z
	main Z
	main-in-other Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - a later --guess overrides previous checkout.guess = false, complete refs and unique remote branches for DWIM' '
	test_config checkout.guess false &&
	test_completion "shit checkout --guess " <<-\EOF
	HEAD Z
	branch-in-other Z
	main Z
	main-in-other Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - a later --no-guess overrides previous checkout.guess = true, complete only refs' '
	test_config checkout.guess true &&
	test_completion "shit checkout --no-guess " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit switch - with --detach, complete all references' '
	test_completion "shit switch --detach " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - with --detach, complete only references' '
	test_completion "shit checkout --detach " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'setup sparse-checkout tests' '
	# set up sparse-checkout repo
	shit init sparse-checkout &&
	(
		cd sparse-checkout &&
		mkdir -p folder1/0/1 folder2/0 folder3 &&
		touch folder1/0/1/t.txt &&
		touch folder2/0/t.txt &&
		touch folder3/t.txt &&
		shit add . &&
		shit commit -am "Initial commit"
	)
'

test_expect_success 'sparse-checkout completes subcommands' '
	test_completion "shit sparse-checkout " <<-\EOF
	list Z
	init Z
	set Z
	add Z
	reapply Z
	disable Z
	EOF
'

test_expect_success 'cone mode sparse-checkout completes directory names' '
	# initialize sparse-checkout definitions
	shit -C sparse-checkout sparse-checkout set --cone folder1/0 folder3 &&

	# test tab completion
	(
		cd sparse-checkout &&
		test_completion "shit sparse-checkout set f" <<-\EOF
		folder1/
		folder2/
		folder3/
		EOF
	) &&

	(
		cd sparse-checkout &&
		test_completion "shit sparse-checkout set folder1/" <<-\EOF
		folder1/0/
		EOF
	) &&

	(
		cd sparse-checkout &&
		test_completion "shit sparse-checkout set folder1/0/" <<-\EOF
		folder1/0/1/
		EOF
	) &&

	(
		cd sparse-checkout/folder1 &&
		test_completion "shit sparse-checkout add 0" <<-\EOF
		0/
		EOF
	)
'

test_expect_success 'cone mode sparse-checkout completes directory names with spaces and accents' '
	# reset sparse-checkout
	shit -C sparse-checkout sparse-checkout disable &&
	(
		cd sparse-checkout &&
		mkdir "directory with spaces" &&
		mkdir "directory-with-áccent" &&
		>"directory with spaces/randomfile" &&
		>"directory-with-áccent/randomfile" &&
		shit add . &&
		shit commit -m "Add directory with spaces and directory with accent" &&
		shit sparse-checkout set --cone "directory with spaces" \
			"directory-with-áccent" &&
		test_completion "shit sparse-checkout add dir" <<-\EOF &&
		directory with spaces/
		directory-with-áccent/
		EOF
		rm -rf "directory with spaces" &&
		rm -rf "directory-with-áccent" &&
		shit add . &&
		shit commit -m "Remove directory with spaces and directory with accent"
	)
'

# use FUNNYNAMES to avoid running on Windows, which doesn't permit tabs in paths
test_expect_success FUNNYNAMES 'cone mode sparse-checkout completes directory names with tabs' '
	# reset sparse-checkout
	shit -C sparse-checkout sparse-checkout disable &&
	(
		cd sparse-checkout &&
		mkdir "$(printf "directory\twith\ttabs")" &&
		>"$(printf "directory\twith\ttabs")/randomfile" &&
		shit add . &&
		shit commit -m "Add directory with tabs" &&
		shit sparse-checkout set --cone \
			"$(printf "directory\twith\ttabs")" &&
		test_completion "shit sparse-checkout add dir" <<-\EOF &&
		directory	with	tabs/
		EOF
		rm -rf "$(printf "directory\twith\ttabs")" &&
		shit add . &&
		shit commit -m "Remove directory with tabs"
	)
'

# use FUNNYNAMES to avoid running on Windows, and !CYGWIN for Cygwin, as neither permit backslashes in paths
test_expect_success FUNNYNAMES,!CYGWIN 'cone mode sparse-checkout completes directory names with backslashes' '
	# reset sparse-checkout
	shit -C sparse-checkout sparse-checkout disable &&
	(
		cd sparse-checkout &&
		mkdir "directory\with\backslashes" &&
		>"directory\with\backslashes/randomfile" &&
		shit add . &&
		shit commit -m "Add directory with backslashes" &&
		shit sparse-checkout set --cone \
			"directory\with\backslashes" &&
		test_completion "shit sparse-checkout add dir" <<-\EOF &&
		directory\with\backslashes/
		EOF
		rm -rf "directory\with\backslashes" &&
		shit add . &&
		shit commit -m "Remove directory with backslashes"
	)
'

test_expect_success 'non-cone mode sparse-checkout gives rooted paths' '
	# reset sparse-checkout repo to non-cone mode
	shit -C sparse-checkout sparse-checkout disable &&
	shit -C sparse-checkout sparse-checkout set --no-cone &&

	(
		cd sparse-checkout &&
		# expected to be empty since we have not configured
		# custom completion for non-cone mode
		test_completion "shit sparse-checkout set f" <<-\EOF
		/folder1/0/1/t.txt Z
		/folder1/expected Z
		/folder1/out Z
		/folder1/out_sorted Z
		/folder2/0/t.txt Z
		/folder3/t.txt Z
		EOF
	)
'

test_expect_success 'shit sparse-checkout set --cone completes directory names' '
	shit -C sparse-checkout sparse-checkout disable &&

	(
		cd sparse-checkout &&
		test_completion "shit sparse-checkout set --cone f" <<-\EOF
		folder1/
		folder2/
		folder3/
		EOF
	)
'

test_expect_success 'shit switch - with -d, complete all references' '
	test_completion "shit switch -d " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - with -d, complete only references' '
	test_completion "shit checkout -d " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit switch - with --track, complete only remote branches' '
	test_completion "shit switch --track " <<-\EOF &&
	other/branch-in-other Z
	other/main-in-other Z
	EOF
	test_completion "shit switch -t " <<-\EOF
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - with --track, complete only remote branches' '
	test_completion "shit checkout --track " <<-\EOF &&
	other/branch-in-other Z
	other/main-in-other Z
	EOF
	test_completion "shit checkout -t " <<-\EOF
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit switch - with --no-track, complete only local branch names' '
	test_completion "shit switch --no-track " <<-\EOF
	main Z
	matching-branch Z
	EOF
'

test_expect_success 'shit checkout - with --no-track, complete only local references' '
	test_completion "shit checkout --no-track " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit switch - with -c, complete all references' '
	test_completion "shit switch -c new-branch " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit switch - with -C, complete all references' '
	test_completion "shit switch -C new-branch " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit switch - with -c and --track, complete all references' '
	test_completion "shit switch -c new-branch --track " <<-EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit switch - with -C and --track, complete all references' '
	test_completion "shit switch -C new-branch --track " <<-EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit switch - with -c and --no-track, complete all references' '
	test_completion "shit switch -c new-branch --no-track " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit switch - with -C and --no-track, complete all references' '
	test_completion "shit switch -C new-branch --no-track " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - with -b, complete all references' '
	test_completion "shit checkout -b new-branch " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - with -B, complete all references' '
	test_completion "shit checkout -B new-branch " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - with -b and --track, complete all references' '
	test_completion "shit checkout -b new-branch --track " <<-EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - with -B and --track, complete all references' '
	test_completion "shit checkout -B new-branch --track " <<-EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - with -b and --no-track, complete all references' '
	test_completion "shit checkout -b new-branch --no-track " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit checkout - with -B and --no-track, complete all references' '
	test_completion "shit checkout -B new-branch --no-track " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit switch - for -c, complete local branches and unique remote branches' '
	test_completion "shit switch -c " <<-\EOF
	branch-in-other Z
	main Z
	main-in-other Z
	matching-branch Z
	EOF
'

test_expect_success 'shit switch - for -C, complete local branches and unique remote branches' '
	test_completion "shit switch -C " <<-\EOF
	branch-in-other Z
	main Z
	main-in-other Z
	matching-branch Z
	EOF
'

test_expect_success 'shit switch - for -c with --no-guess, complete local branches only' '
	test_completion "shit switch --no-guess -c " <<-\EOF
	main Z
	matching-branch Z
	EOF
'

test_expect_success 'shit switch - for -C with --no-guess, complete local branches only' '
	test_completion "shit switch --no-guess -C " <<-\EOF
	main Z
	matching-branch Z
	EOF
'

test_expect_success 'shit switch - for -c with --no-track, complete local branches only' '
	test_completion "shit switch --no-track -c " <<-\EOF
	main Z
	matching-branch Z
	EOF
'

test_expect_success 'shit switch - for -C with --no-track, complete local branches only' '
	test_completion "shit switch --no-track -C " <<-\EOF
	main Z
	matching-branch Z
	EOF
'

test_expect_success 'shit checkout - for -b, complete local branches and unique remote branches' '
	test_completion "shit checkout -b " <<-\EOF
	branch-in-other Z
	main Z
	main-in-other Z
	matching-branch Z
	EOF
'

test_expect_success 'shit checkout - for -B, complete local branches and unique remote branches' '
	test_completion "shit checkout -B " <<-\EOF
	branch-in-other Z
	main Z
	main-in-other Z
	matching-branch Z
	EOF
'

test_expect_success 'shit checkout - for -b with --no-guess, complete local branches only' '
	test_completion "shit checkout --no-guess -b " <<-\EOF
	main Z
	matching-branch Z
	EOF
'

test_expect_success 'shit checkout - for -B with --no-guess, complete local branches only' '
	test_completion "shit checkout --no-guess -B " <<-\EOF
	main Z
	matching-branch Z
	EOF
'

test_expect_success 'shit checkout - for -b with --no-track, complete local branches only' '
	test_completion "shit checkout --no-track -b " <<-\EOF
	main Z
	matching-branch Z
	EOF
'

test_expect_success 'shit checkout - for -B with --no-track, complete local branches only' '
	test_completion "shit checkout --no-track -B " <<-\EOF
	main Z
	matching-branch Z
	EOF
'

test_expect_success 'shit switch - with --orphan completes local branch names and unique remote branch names' '
	test_completion "shit switch --orphan " <<-\EOF
	branch-in-other Z
	main Z
	main-in-other Z
	matching-branch Z
	EOF
'

test_expect_success 'shit switch - --orphan with branch already provided completes nothing else' '
	test_completion "shit switch --orphan main " <<-\EOF

	EOF
'

test_expect_success 'shit checkout - with --orphan completes local branch names and unique remote branch names' '
	test_completion "shit checkout --orphan " <<-\EOF
	branch-in-other Z
	main Z
	main-in-other Z
	matching-branch Z
	EOF
'

test_expect_success 'shit checkout - --orphan with branch already provided completes local refs for a start-point' '
	test_completion "shit checkout --orphan main " <<-\EOF
	HEAD Z
	main Z
	matching-branch Z
	matching-tag Z
	other/branch-in-other Z
	other/main-in-other Z
	EOF
'

test_expect_success 'shit restore completes modified files' '
	test_commit A a.file &&
	echo B >a.file &&
	test_completion "shit restore a." <<-\EOF
	a.file
	EOF
'

test_expect_success 'teardown after ref completion' '
	shit branch -d matching-branch &&
	shit tag -d matching-tag &&
	shit remote remove other
'


test_path_completion ()
{
	test $# = 2 || BUG "not 2 parameters to test_path_completion"

	local cur="$1" expected="$2"
	echo "$expected" >expected &&
	(
		# In the following tests calling this function we only
		# care about how __shit_complete_index_file() deals with
		# unusual characters in path names.  By requesting only
		# untracked files we do not have to bother adding any
		# paths to the index in those tests.
		__shit_complete_index_file --others &&
		print_comp
	) &&
	test_cmp expected out
}

test_expect_success 'setup for path completion tests' '
	mkdir simple-dir \
	      "spaces in dir" \
	      árvíztűrő &&
	touch simple-dir/simple-file \
	      "spaces in dir/spaces in file" \
	      "árvíztűrő/Сайн яваарай" &&
	if test_have_prereq !MINGW &&
	   mkdir BS\\dir \
		 '$'separators\034in\035dir'' &&
	   touch BS\\dir/DQ\"file \
		 '$'separators\034in\035dir/sep\036in\037file''
	then
		test_set_prereq FUNNIERNAMES
	else
		rm -rf BS\\dir '$'separators\034in\035dir''
	fi
'

test_expect_success '__shit_complete_index_file - simple' '
	test_path_completion simple simple-dir &&  # Bash is supposed to
						   # add the trailing /.
	test_path_completion simple-dir/simple simple-dir/simple-file
'

test_expect_success \
    '__shit_complete_index_file - escaped characters on cmdline' '
	test_path_completion spac "spaces in dir" &&  # Bash will turn this
						      # into "spaces\ in\ dir"
	test_path_completion "spaces\\ i" \
			     "spaces in dir" &&
	test_path_completion "spaces\\ in\\ dir/s" \
			     "spaces in dir/spaces in file" &&
	test_path_completion "spaces\\ in\\ dir/spaces\\ i" \
			     "spaces in dir/spaces in file"
'

test_expect_success \
    '__shit_complete_index_file - quoted characters on cmdline' '
	# Testing with an opening but without a corresponding closing
	# double quote is important.
	test_path_completion \"spac "spaces in dir" &&
	test_path_completion "\"spaces i" \
			     "spaces in dir" &&
	test_path_completion "\"spaces in dir/s" \
			     "spaces in dir/spaces in file" &&
	test_path_completion "\"spaces in dir/spaces i" \
			     "spaces in dir/spaces in file"
'

test_expect_success '__shit_complete_index_file - UTF-8 in ls-files output' '
	test_path_completion á árvíztűrő &&
	test_path_completion árvíztűrő/С "árvíztűrő/Сайн яваарай"
'

test_expect_success FUNNIERNAMES \
    '__shit_complete_index_file - C-style escapes in ls-files output' '
	test_path_completion BS \
			     BS\\dir &&
	test_path_completion BS\\\\d \
			     BS\\dir &&
	test_path_completion BS\\\\dir/DQ \
			     BS\\dir/DQ\"file &&
	test_path_completion BS\\\\dir/DQ\\\"f \
			     BS\\dir/DQ\"file
'

test_expect_success FUNNIERNAMES \
    '__shit_complete_index_file - \nnn-escaped characters in ls-files output' '
	test_path_completion sep '$'separators\034in\035dir'' &&
	test_path_completion '$'separators\034i'' \
			     '$'separators\034in\035dir'' &&
	test_path_completion '$'separators\034in\035dir/sep'' \
			     '$'separators\034in\035dir/sep\036in\037file'' &&
	test_path_completion '$'separators\034in\035dir/sep\036i'' \
			     '$'separators\034in\035dir/sep\036in\037file''
'

test_expect_success FUNNYNAMES \
    '__shit_complete_index_file - removing repeated quoted path components' '
	test_when_finished rm -r repeated-quoted &&
	mkdir repeated-quoted &&      # A directory whose name in itself
				      # would not be quoted ...
	>repeated-quoted/0-file &&
	>repeated-quoted/1\"file &&   # ... but here the file makes the
				      # dirname quoted ...
	>repeated-quoted/2-file &&
	>repeated-quoted/3\"file &&   # ... and here, too.

	# Still, we shold only list the directory name only once.
	test_path_completion repeated repeated-quoted
'

test_expect_success 'teardown after path completion tests' '
	rm -rf simple-dir "spaces in dir" árvíztűrő \
	       BS\\dir '$'separators\034in\035dir''
'

test_expect_success '__shit_find_on_cmdline - single match' '
	echo list >expect &&
	(
		words=(shit command --opt list) &&
		cword=${#words[@]} &&
		__shit_cmd_idx=1 &&
		__shit_find_on_cmdline "add list remove" >actual
	) &&
	test_cmp expect actual
'

test_expect_success '__shit_find_on_cmdline - multiple matches' '
	echo remove >expect &&
	(
		words=(shit command -o --opt remove list add) &&
		cword=${#words[@]} &&
		__shit_cmd_idx=1 &&
		__shit_find_on_cmdline "add list remove" >actual
	) &&
	test_cmp expect actual
'

test_expect_success '__shit_find_on_cmdline - no match' '
	(
		words=(shit command --opt branch) &&
		cword=${#words[@]} &&
		__shit_cmd_idx=1 &&
		__shit_find_on_cmdline "add list remove" >actual
	) &&
	test_must_be_empty actual
'

test_expect_success '__shit_find_on_cmdline - single match with index' '
	echo "3 list" >expect &&
	(
		words=(shit command --opt list) &&
		cword=${#words[@]} &&
		__shit_cmd_idx=1 &&
		__shit_find_on_cmdline --show-idx "add list remove" >actual
	) &&
	test_cmp expect actual
'

test_expect_success '__shit_find_on_cmdline - multiple matches with index' '
	echo "4 remove" >expect &&
	(
		words=(shit command -o --opt remove list add) &&
		cword=${#words[@]} &&
		__shit_cmd_idx=1 &&
		__shit_find_on_cmdline --show-idx "add list remove" >actual
	) &&
	test_cmp expect actual
'

test_expect_success '__shit_find_on_cmdline - no match with index' '
	(
		words=(shit command --opt branch) &&
		cword=${#words[@]} &&
		__shit_cmd_idx=1 &&
		__shit_find_on_cmdline --show-idx "add list remove" >actual
	) &&
	test_must_be_empty actual
'

test_expect_success '__shit_find_on_cmdline - ignores matches before command with index' '
	echo "6 remove" >expect &&
	(
		words=(shit -C remove command -o --opt remove list add) &&
		cword=${#words[@]} &&
		__shit_cmd_idx=3 &&
		__shit_find_on_cmdline --show-idx "add list remove" >actual
	) &&
	test_cmp expect actual
'

test_expect_success '__shit_get_config_variables' '
	cat >expect <<-EOF &&
	name-1
	name-2
	EOF
	test_config interesting.name-1 good &&
	test_config interesting.name-2 good &&
	test_config subsection.interesting.name-3 bad &&
	__shit_get_config_variables interesting >actual &&
	test_cmp expect actual
'

test_expect_success '__shit_pretty_aliases' '
	cat >expect <<-EOF &&
	author
	hash
	EOF
	test_config pretty.author "%an %ae" &&
	test_config pretty.hash %H &&
	__shit_pretty_aliases >actual &&
	test_cmp expect actual
'

test_expect_success 'basic' '
	run_completion "shit " &&
	# built-in
	grep -q "^add \$" out &&
	# script
	grep -q "^rebase \$" out &&
	# plumbing
	! grep -q "^ls-files \$" out &&

	run_completion "shit r" &&
	! grep -q -v "^r" out
'

test_expect_success 'double dash "shit" itself' '
	test_completion "shit --" <<-\EOF
	--paginate Z
	--no-pager Z
	--shit-dir=
	--bare Z
	--version Z
	--exec-path Z
	--exec-path=
	--html-path Z
	--man-path Z
	--info-path Z
	--work-tree=
	--namespace=
	--no-replace-objects Z
	--help Z
	EOF
'

test_expect_success 'double dash "shit checkout"' '
	test_completion "shit checkout --" <<-\EOF
	--quiet Z
	--detach Z
	--track Z
	--orphan=Z
	--ours Z
	--theirs Z
	--merge Z
	--conflict=Z
	--patch Z
	--ignore-skip-worktree-bits Z
	--ignore-other-worktrees Z
	--recurse-submodules Z
	--progress Z
	--guess Z
	--no-guess Z
	--no-... Z
	--overlay Z
	--pathspec-file-nul Z
	--pathspec-from-file=Z
	EOF
'

test_expect_success 'general options' '
	test_completion "shit --ver" "--version " &&
	test_completion "shit --hel" "--help " &&
	test_completion "shit --exe" <<-\EOF &&
	--exec-path Z
	--exec-path=
	EOF
	test_completion "shit --htm" "--html-path " &&
	test_completion "shit --pag" "--paginate " &&
	test_completion "shit --no-p" "--no-pager " &&
	test_completion "shit --shit" "--shit-dir=" &&
	test_completion "shit --wor" "--work-tree=" &&
	test_completion "shit --nam" "--namespace=" &&
	test_completion "shit --bar" "--bare " &&
	test_completion "shit --inf" "--info-path " &&
	test_completion "shit --no-r" "--no-replace-objects "
'

test_expect_success 'general options plus command' '
	test_completion "shit --version check" "checkout " &&
	test_completion "shit --paginate check" "checkout " &&
	test_completion "shit --shit-dir=foo check" "checkout " &&
	test_completion "shit --bare check" "checkout " &&
	test_completion "shit --exec-path=foo check" "checkout " &&
	test_completion "shit --html-path check" "checkout " &&
	test_completion "shit --no-pager check" "checkout " &&
	test_completion "shit --work-tree=foo check" "checkout " &&
	test_completion "shit --namespace=foo check" "checkout " &&
	test_completion "shit --paginate check" "checkout " &&
	test_completion "shit --info-path check" "checkout " &&
	test_completion "shit --no-replace-objects check" "checkout " &&
	test_completion "shit --shit-dir some/path check" "checkout " &&
	test_completion "shit -c conf.var=value check" "checkout " &&
	test_completion "shit -C some/path check" "checkout " &&
	test_completion "shit --work-tree some/path check" "checkout " &&
	test_completion "shit --namespace name/space check" "checkout "
'

test_expect_success 'shit --help completion' '
	test_completion "shit --help ad" "add " &&
	test_completion "shit --help core" "core-tutorial "
'

test_expect_success 'completion.commands removes multiple commands' '
	test_config completion.commands "-cherry -mergetool" &&
	shit --list-cmds=list-mainporcelain,list-complete,config >out &&
	! grep -E "^(cherry|mergetool)$" out
'

test_expect_success 'setup for integration tests' '
	echo content >file1 &&
	echo more >file2 &&
	shit add file1 file2 &&
	shit commit -m one &&
	shit branch mybranch &&
	shit tag mytag
'

test_expect_success 'checkout completes ref names' '
	test_completion "shit checkout m" <<-\EOF
	main Z
	mybranch Z
	mytag Z
	EOF
'

test_expect_success 'checkout does not match ref names of a different case' '
	test_completion "shit checkout M" ""
'

test_expect_success 'checkout matches case insensitively with shit_COMPLETION_IGNORE_CASE' '
	(
		shit_COMPLETION_IGNORE_CASE=1 &&
		test_completion "shit checkout M" <<-\EOF
		main Z
		mybranch Z
		mytag Z
		EOF
	)
'

test_expect_success 'checkout completes pseudo refs' '
	test_completion "shit checkout H" <<-\EOF
	HEAD Z
	EOF
'

test_expect_success 'checkout completes pseudo refs case insensitively with shit_COMPLETION_IGNORE_CASE' '
	(
		shit_COMPLETION_IGNORE_CASE=1 &&
		test_completion "shit checkout h" <<-\EOF
		HEAD Z
		EOF
	)
'

test_expect_success 'shit -C <path> checkout uses the right repo' '
	test_completion "shit -C subdir -C subsubdir -C .. -C ../otherrepo checkout b" <<-\EOF
	branch-in-other Z
	EOF
'

test_expect_success 'show completes all refs' '
	test_completion "shit show m" <<-\EOF
	main Z
	mybranch Z
	mytag Z
	EOF
'

test_expect_success '<ref>: completes paths' '
	test_completion "shit show mytag:f" <<-\EOF
	file1Z
	file2Z
	EOF
'

test_expect_success 'complete tree filename with spaces' '
	echo content >"name with spaces" &&
	shit add "name with spaces" &&
	shit commit -m spaces &&
	test_completion "shit show HEAD:nam" <<-\EOF
	name with spacesZ
	EOF
'

test_expect_success 'complete tree filename with metacharacters' '
	echo content >"name with \${meta}" &&
	shit add "name with \${meta}" &&
	shit commit -m meta &&
	test_completion "shit show HEAD:nam" <<-\EOF
	name with ${meta}Z
	name with spacesZ
	EOF
'

test_expect_success 'symbolic-ref completes builtin options' '
	test_completion "shit symbolic-ref --d" <<-\EOF
	--delete Z
	EOF
'

test_expect_success 'symbolic-ref completes short ref names' '
	test_completion "shit symbolic-ref foo m" <<-\EOF
	main Z
	mybranch Z
	mytag Z
	EOF
'

test_expect_success 'symbolic-ref completes full ref names' '
	test_completion "shit symbolic-ref foo refs/" <<-\EOF
	refs/heads/main Z
	refs/heads/mybranch Z
	refs/tags/mytag Z
	refs/tags/A Z
	EOF
'

test_expect_success PERL 'send-email' '
	test_completion "shit send-email --cov" <<-\EOF &&
	--cover-from-description=Z
	--cover-letter Z
	EOF
	test_completion "shit send-email --val" <<-\EOF &&
	--validate Z
	EOF
	test_completion "shit send-email ma" "main "
'

test_expect_success 'complete files' '
	shit init tmp && cd tmp &&
	test_when_finished "cd .. && rm -rf tmp" &&

	echo "expected" > .shitignore &&
	echo "out" >> .shitignore &&
	echo "out_sorted" >> .shitignore &&

	shit add .shitignore &&
	test_completion "shit commit " ".shitignore" &&

	shit commit -m ignore &&

	touch new &&
	test_completion "shit add " "new" &&

	shit add new &&
	shit commit -a -m new &&
	test_completion "shit add " "" &&

	shit mv new modified &&
	echo modify > modified &&
	test_completion "shit add " "modified" &&

	mkdir -p some/deep &&
	touch some/deep/path &&
	test_completion "shit add some/" "some/deep" &&
	shit clean -f some &&

	touch untracked &&

	: TODO .shitignore should not be here &&
	test_completion "shit rm " <<-\EOF &&
	.shitignore
	modified
	EOF

	test_completion "shit clean " "untracked" &&

	: TODO .shitignore should not be here &&
	test_completion "shit mv " <<-\EOF &&
	.shitignore
	modified
	EOF

	mkdir dir &&
	touch dir/file-in-dir &&
	shit add dir/file-in-dir &&
	shit commit -m dir &&

	mkdir untracked-dir &&

	: TODO .shitignore should not be here &&
	test_completion "shit mv modified " <<-\EOF &&
	.shitignore
	dir
	modified
	untracked
	untracked-dir
	EOF

	test_completion "shit commit " "modified" &&

	: TODO .shitignore should not be here &&
	test_completion "shit ls-files " <<-\EOF &&
	.shitignore
	dir
	modified
	EOF

	touch momified &&
	test_completion "shit add mom" "momified"
'

test_expect_success "simple alias" '
	test_config alias.co checkout &&
	test_completion "shit co m" <<-\EOF
	main Z
	mybranch Z
	mytag Z
	EOF
'

test_expect_success "recursive alias" '
	test_config alias.co checkout &&
	test_config alias.cod "co --detached" &&
	test_completion "shit cod m" <<-\EOF
	main Z
	mybranch Z
	mytag Z
	EOF
'

test_expect_success "completion uses <cmd> completion for alias: !sh -c 'shit <cmd> ...'" '
	test_config alias.co "!sh -c '"'"'shit checkout ...'"'"'" &&
	test_completion "shit co m" <<-\EOF
	main Z
	mybranch Z
	mytag Z
	EOF
'

test_expect_success 'completion uses <cmd> completion for alias: !f () { VAR=val shit <cmd> ... }' '
	test_config alias.co "!f () { VAR=val shit checkout ... ; } f" &&
	test_completion "shit co m" <<-\EOF
	main Z
	mybranch Z
	mytag Z
	EOF
'

test_expect_success 'completion used <cmd> completion for alias: !f() { : shit <cmd> ; ... }' '
	test_config alias.co "!f() { : shit checkout ; if ... } f" &&
	test_completion "shit co m" <<-\EOF
	main Z
	mybranch Z
	mytag Z
	EOF
'

test_expect_success 'completion used <cmd> completion for alias: !f() { : <cmd> ; ... }' '
	test_config alias.co "!f() { : checkout ; if ... } f" &&
	test_completion "shit co m" <<-\EOF
	main Z
	mybranch Z
	mytag Z
	EOF
'

test_expect_success 'completion used <cmd> completion for alias: !f() { : <cmd>; ... }' '
	test_config alias.co "!f() { : checkout; if ... } f" &&
	test_completion "shit co m" <<-\EOF
	main Z
	mybranch Z
	mytag Z
	EOF
'

test_expect_success 'completion without explicit _shit_xxx function' '
	test_completion "shit version --" <<-\EOF
	--build-options Z
	--no-build-options Z
	EOF
'

test_expect_failure 'complete with tilde expansion' '
	shit init tmp && cd tmp &&
	test_when_finished "cd .. && rm -rf tmp" &&

	touch ~/tmp/file &&

	test_completion "shit add ~/tmp/" "~/tmp/file"
'

test_expect_success 'setup other remote for remote reference completion' '
	shit remote add other otherrepo &&
	shit fetch other
'

for flag in -d --delete
do
	test_expect_success "__shit_complete_remote_or_refspec - defecate $flag other" '
		sed -e "s/Z$//" >expected <<-EOF &&
		main-in-other Z
		EOF
		(
			words=(shit defecate '$flag' other ma) &&
			cword=${#words[@]} cur=${words[cword-1]} &&
			__shit_cmd_idx=1 &&
			__shit_complete_remote_or_refspec &&
			print_comp
		) &&
		test_cmp expected out
	'

	test_expect_failure "__shit_complete_remote_or_refspec - defecate other $flag" '
		sed -e "s/Z$//" >expected <<-EOF &&
		main-in-other Z
		EOF
		(
			words=(shit defecate other '$flag' ma) &&
			cword=${#words[@]} cur=${words[cword-1]} &&
			__shit_cmd_idx=1 &&
			__shit_complete_remote_or_refspec &&
			print_comp
		) &&
		test_cmp expected out
	'
done

test_expect_success 'shit config - section' '
	test_completion "shit config br" <<-\EOF
	branch.Z
	browser.Z
	EOF
'

test_expect_success 'shit config - section include, includeIf' '
	test_completion "shit config inclu" <<-\EOF
	include.Z
	includeIf.Z
	EOF
'

test_expect_success 'shit config - variable name' '
	test_completion "shit config log.d" <<-\EOF
	log.date Z
	log.decorate Z
	log.diffMerges Z
	EOF
'

test_expect_success 'shit config - variable name include' '
	test_completion "shit config include.p" <<-\EOF
	include.path Z
	EOF
'

test_expect_success 'setup for shit config submodule tests' '
	test_create_repo sub &&
	test_commit -C sub initial &&
	shit submodule add ./sub
'

test_expect_success 'shit config - variable name - submodule and __shit_compute_first_level_config_vars_for_section' '
	test_completion "shit config submodule." <<-\EOF
	submodule.active Z
	submodule.alternateErrorStrategy Z
	submodule.alternateLocation Z
	submodule.fetchJobs Z
	submodule.propagateBranches Z
	submodule.recurse Z
	submodule.sub.Z
	EOF
'

test_expect_success 'shit config - variable name - __shit_compute_second_level_config_vars_for_section' '
	test_completion "shit config submodule.sub." <<-\EOF
	submodule.sub.url Z
	submodule.sub.update Z
	submodule.sub.branch Z
	submodule.sub.fetchRecurseSubmodules Z
	submodule.sub.ignore Z
	submodule.sub.active Z
	EOF
'

test_expect_success 'shit config - value' '
	test_completion "shit config color.pager " <<-\EOF
	false Z
	true Z
	EOF
'

test_expect_success 'shit -c - section' '
	test_completion "shit -c br" <<-\EOF
	branch.Z
	browser.Z
	EOF
'

test_expect_success 'shit -c - variable name' '
	test_completion "shit -c log.d" <<-\EOF
	log.date=Z
	log.decorate=Z
	log.diffMerges=Z
	EOF
'

test_expect_success 'shit -c - value' '
	test_completion "shit -c color.pager=" <<-\EOF
	false Z
	true Z
	EOF
'

test_expect_success 'shit clone --config= - section' '
	test_completion "shit clone --config=br" <<-\EOF
	branch.Z
	browser.Z
	EOF
'

test_expect_success 'shit clone --config= - variable name' '
	test_completion "shit clone --config=log.d" <<-\EOF
	log.date=Z
	log.decorate=Z
	log.diffMerges=Z
	EOF
'

test_expect_success 'shit clone --config= - value' '
	test_completion "shit clone --config=color.pager=" <<-\EOF
	false Z
	true Z
	EOF
'

test_expect_success 'shit reflog show' '
	test_when_finished "shit checkout - && shit branch -d shown" &&
	shit checkout -b shown &&
	test_completion "shit reflog sho" <<-\EOF &&
	show Z
	shown Z
	EOF
	test_completion "shit reflog show sho" "shown " &&
	test_completion "shit reflog shown sho" "shown " &&
	test_completion "shit reflog --unt" "--until=" &&
	test_completion "shit reflog show --unt" "--until=" &&
	test_completion "shit reflog shown --unt" "--until="
'

test_expect_success 'options with value' '
	test_completion "shit merge -X diff-algorithm=" <<-\EOF

	EOF
'

test_expect_success 'sourcing the completion script clears cached commands' '
	(
		__shit_compute_all_commands &&
		test -n "$__shit_all_commands" &&
		. "$shit_BUILD_DIR/contrib/completion/shit-completion.bash" &&
		test -z "$__shit_all_commands"
	)
'

test_expect_success 'sourcing the completion script clears cached merge strategies' '
	(
		__shit_compute_merge_strategies &&
		test -n "$__shit_merge_strategies" &&
		. "$shit_BUILD_DIR/contrib/completion/shit-completion.bash" &&
		test -z "$__shit_merge_strategies"
	)
'

test_expect_success 'sourcing the completion script clears cached --options' '
	(
		__shitcomp_builtin checkout &&
		test -n "$__shitcomp_builtin_checkout" &&
		__shitcomp_builtin notes_edit &&
		test -n "$__shitcomp_builtin_notes_edit" &&
		. "$shit_BUILD_DIR/contrib/completion/shit-completion.bash" &&
		test -z "$__shitcomp_builtin_checkout" &&
		test -z "$__shitcomp_builtin_notes_edit"
	)
'

test_expect_success 'option aliases are not shown by default' '
	test_completion "shit clone --recurs" "--recurse-submodules "
'

test_expect_success 'option aliases are shown with shit_COMPLETION_SHOW_ALL' '
	(
		. "$shit_BUILD_DIR/contrib/completion/shit-completion.bash" &&
		shit_COMPLETION_SHOW_ALL=1 && export shit_COMPLETION_SHOW_ALL &&
		test_completion "shit clone --recurs" <<-\EOF
		--recurse-submodules Z
		--recursive Z
		EOF
	)
'

test_expect_success 'plumbing commands are excluded without shit_COMPLETION_SHOW_ALL_COMMANDS' '
	(
		. "$shit_BUILD_DIR/contrib/completion/shit-completion.bash" &&
		sane_unset shit_TESTING_PORCELAIN_COMMAND_LIST &&

		# Just mainporcelain, not plumbing commands
		run_completion "shit c" &&
		grep checkout out &&
		! grep cat-file out
	)
'

test_expect_success 'all commands are shown with shit_COMPLETION_SHOW_ALL_COMMANDS (also main non-builtin)' '
	(
		. "$shit_BUILD_DIR/contrib/completion/shit-completion.bash" &&
		shit_COMPLETION_SHOW_ALL_COMMANDS=1 &&
		export shit_COMPLETION_SHOW_ALL_COMMANDS &&
		sane_unset shit_TESTING_PORCELAIN_COMMAND_LIST &&

		# Both mainporcelain and plumbing commands
		run_completion "shit c" &&
		grep checkout out &&
		grep cat-file out &&

		# Check "shitk", a "main" command, but not a built-in + more plumbing
		run_completion "shit g" &&
		grep shitk out &&
		grep get-tar-commit-id out
	)
'

test_expect_success '__shit_complete' '
	unset -f __shit_wrap__shit_main &&

	__shit_complete foo __shit_main &&
	__shit_have_func __shit_wrap__shit_main &&
	unset -f __shit_wrap__shit_main &&

	__shit_complete gf _shit_fetch &&
	__shit_have_func __shit_wrap_shit_fetch &&

	__shit_complete foo shit &&
	__shit_have_func __shit_wrap__shit_main &&
	unset -f __shit_wrap__shit_main &&

	__shit_complete gd shit_diff &&
	__shit_have_func __shit_wrap_shit_diff &&

	test_must_fail __shit_complete ga missing
'

test_expect_success '__shit_pseudoref_exists' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&
		sane_unset __shit_repo_path &&

		# HEAD should exist, even if it points to an unborn branch.
		__shit_pseudoref_exists HEAD >output 2>&1 &&
		test_must_be_empty output &&

		# HEAD points to an existing branch, so it should exist.
		test_commit A &&
		__shit_pseudoref_exists HEAD >output 2>&1 &&
		test_must_be_empty output &&

		# CHERRY_PICK_HEAD does not exist, so the existence check should fail.
		! __shit_pseudoref_exists CHERRY_PICK_HEAD >output 2>&1 &&
		test_must_be_empty output &&

		# CHERRY_PICK_HEAD points to a commit, so it should exist.
		shit update-ref CHERRY_PICK_HEAD A &&
		__shit_pseudoref_exists CHERRY_PICK_HEAD >output 2>&1 &&
		test_must_be_empty output
	)
'

test_done
