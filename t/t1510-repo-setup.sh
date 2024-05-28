#!/bin/sh

test_description="Tests of cwd/prefix/worktree/shitdir setup in all cases

A few rules for repo setup:

1. shit_DIR is relative to user's cwd. --shit-dir is equivalent to
   shit_DIR.

2. .shit file is relative to parent directory. .shit file is basically
   symlink in disguise. The directory where .shit file points to will
   become new shit_dir.

3. core.worktree is relative to shit_dir.

4. shit_WORK_TREE is relative to user's cwd. --work-tree is
   equivalent to shit_WORK_TREE.

5. shit_WORK_TREE/core.worktree was originally meant to work only if
   shit_DIR is set, but earlier shit didn't enforce it, and some scripts
   depend on the implementation that happened to first discover .shit by
   going up from the users $cwd and then using the specified working tree
   that may or may not have any relation to where .shit was found in.  This
   historical behaviour must be kept.

6. Effective shit_WORK_TREE overrides core.worktree and core.bare

7. Effective core.worktree conflicts with core.bare

8. If shit_DIR is set but neither worktree nor bare setting is given,
   original cwd becomes worktree.

9. If .shit discovery is done inside a repo, the repo becomes a bare
   repo. .shit discovery is performed if shit_DIR is not set.

10. If no worktree is available, cwd remains unchanged, prefix is
    NULL.

11. When user's cwd is outside worktree, cwd remains unchanged,
    prefix is NULL.
"

# This test heavily relies on the standard error of nested function calls.
test_untraceable=UnfortunatelyYes

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

here=$(pwd)

test_repo () {
	(
		cd "$1" &&
		if test -n "$2"
		then
			shit_DIR="$2" &&
			export shit_DIR
		fi &&
		if test -n "$3"
		then
			shit_WORK_TREE="$3" &&
			export shit_WORK_TREE
		fi &&
		rm -f trace &&
		shit_TRACE_SETUP="$(pwd)/trace" shit symbolic-ref HEAD >/dev/null &&
		grep '^setup: ' trace >result &&
		test_cmp expected result
	)
}

maybe_config () {
	file=$1 var=$2 value=$3 &&
	if test "$value" != unset
	then
		shit config --file="$file" "$var" "$value"
	fi
}

setup_repo () {
	name=$1 worktreecfg=$2 shitfile=$3 barecfg=$4 &&
	sane_unset shit_DIR shit_WORK_TREE &&

	shit -c init.defaultBranch=initial init "$name" &&
	maybe_config "$name/.shit/config" core.worktree "$worktreecfg" &&
	maybe_config "$name/.shit/config" core.bare "$barecfg" &&
	mkdir -p "$name/sub/sub" &&

	if test "${shitfile:+set}"
	then
		mv "$name/.shit" "$name.shit" &&
		echo "shitdir: ../$name.shit" >"$name/.shit"
	fi
}

maybe_set () {
	var=$1 value=$2 &&
	if test "$value" != unset
	then
		eval "$var=\$value" &&
		export $var
	fi
}

setup_env () {
	worktreenv=$1 shitdirenv=$2 &&
	sane_unset shit_DIR shit_WORK_TREE &&
	maybe_set shit_DIR "$shitdirenv" &&
	maybe_set shit_WORK_TREE "$worktreeenv"
}

expect () {
	cat >"$1/expected" <<-EOF
	setup: shit_dir: $2
	setup: shit_common_dir: $2
	setup: worktree: $3
	setup: cwd: $4
	setup: prefix: $5
	EOF
}

try_case () {
	name=$1 worktreeenv=$2 shitdirenv=$3 &&
	setup_env "$worktreeenv" "$shitdirenv" &&
	expect "$name" "$4" "$5" "$6" "$7" &&
	test_repo "$name"
}

run_wt_tests () {
	N=$1 shitfile=$2

	absshit="$here/$N/.shit"
	dotshit=.shit
	dotdotshit=../../.shit

	if test "$shitfile"
	then
		absshit="$here/$N.shit"
		dotshit=$absshit dotdotshit=$absshit
	fi

	test_expect_success "#$N: explicit shit_WORK_TREE and shit_DIR at toplevel" '
		try_case $N "$here/$N" .shit \
			"$dotshit" "$here/$N" "$here/$N" "(null)" &&
		try_case $N . .shit \
			"$dotshit" "$here/$N" "$here/$N" "(null)" &&
		try_case $N "$here/$N" "$here/$N/.shit" \
			"$absshit" "$here/$N" "$here/$N" "(null)" &&
		try_case $N . "$here/$N/.shit" \
			"$absshit" "$here/$N" "$here/$N" "(null)"
	'

	test_expect_success "#$N: explicit shit_WORK_TREE and shit_DIR in subdir" '
		try_case $N/sub/sub "$here/$N" ../../.shit \
			"$absshit" "$here/$N" "$here/$N" sub/sub/ &&
		try_case $N/sub/sub ../.. ../../.shit \
			"$absshit" "$here/$N" "$here/$N" sub/sub/ &&
		try_case $N/sub/sub "$here/$N" "$here/$N/.shit" \
			"$absshit" "$here/$N" "$here/$N" sub/sub/ &&
		try_case $N/sub/sub ../.. "$here/$N/.shit" \
			"$absshit" "$here/$N" "$here/$N" sub/sub/
	'

	test_expect_success "#$N: explicit shit_WORK_TREE from parent of worktree" '
		try_case $N "$here/$N/wt" .shit \
			"$dotshit" "$here/$N/wt" "$here/$N" "(null)" &&
		try_case $N wt .shit \
			"$dotshit" "$here/$N/wt" "$here/$N" "(null)" &&
		try_case $N wt "$here/$N/.shit" \
			"$absshit" "$here/$N/wt" "$here/$N" "(null)" &&
		try_case $N "$here/$N/wt" "$here/$N/.shit" \
			"$absshit" "$here/$N/wt" "$here/$N" "(null)"
	'

	test_expect_success "#$N: explicit shit_WORK_TREE from nephew of worktree" '
		try_case $N/sub/sub "$here/$N/wt" ../../.shit \
			"$dotdotshit" "$here/$N/wt" "$here/$N/sub/sub" "(null)" &&
		try_case $N/sub/sub ../../wt ../../.shit \
			"$dotdotshit" "$here/$N/wt" "$here/$N/sub/sub" "(null)" &&
		try_case $N/sub/sub ../../wt "$here/$N/.shit" \
			"$absshit" "$here/$N/wt" "$here/$N/sub/sub" "(null)" &&
		try_case $N/sub/sub "$here/$N/wt" "$here/$N/.shit" \
			"$absshit" "$here/$N/wt" "$here/$N/sub/sub" "(null)"
	'

	test_expect_success "#$N: chdir_to_toplevel uses worktree, not shit dir" '
		try_case $N "$here" .shit \
			"$absshit" "$here" "$here" $N/ &&
		try_case $N .. .shit \
			"$absshit" "$here" "$here" $N/ &&
		try_case $N .. "$here/$N/.shit" \
			"$absshit" "$here" "$here" $N/ &&
		try_case $N "$here" "$here/$N/.shit" \
			"$absshit" "$here" "$here" $N/
	'

	test_expect_success "#$N: chdir_to_toplevel uses worktree (from subdir)" '
		try_case $N/sub/sub "$here" ../../.shit \
			"$absshit" "$here" "$here" $N/sub/sub/ &&
		try_case $N/sub/sub ../../.. ../../.shit \
			"$absshit" "$here" "$here" $N/sub/sub/ &&
		try_case $N/sub/sub ../../../ "$here/$N/.shit" \
			"$absshit" "$here" "$here" $N/sub/sub/ &&
		try_case $N/sub/sub "$here" "$here/$N/.shit" \
			"$absshit" "$here" "$here" $N/sub/sub/
	'
}

# try_repo #c shit_WORK_TREE shit_DIR core.worktree .shitfile? core.bare \
#	(shit dir) (work tree) (cwd) (prefix) \	<-- at toplevel
#	(shit dir) (work tree) (cwd) (prefix)	<-- from subdir
try_repo () {
	name=$1 worktreeenv=$2 shitdirenv=$3 &&
	setup_repo "$name" "$4" "$5" "$6" &&
	shift 6 &&
	try_case "$name" "$worktreeenv" "$shitdirenv" \
		"$1" "$2" "$3" "$4" &&
	shift 4 &&
	case "$shitdirenv" in
	/* | ?:/* | unset) ;;
	*)
		shitdirenv=../$shitdirenv ;;
	esac &&
	try_case "$name/sub" "$worktreeenv" "$shitdirenv" \
		"$1" "$2" "$3" "$4"
}

# Bit 0 = shit_WORK_TREE
# Bit 1 = shit_DIR
# Bit 2 = core.worktree
# Bit 3 = .shit is a file
# Bit 4 = bare repo
# Case# = encoding of the above 5 bits

test_expect_success '#0: nonbare repo, no explicit configuration' '
	try_repo 0 unset unset unset "" unset \
		.shit "$here/0" "$here/0" "(null)" \
		.shit "$here/0" "$here/0" sub/ 2>message &&
	test_must_be_empty message
'

test_expect_success '#1: shit_WORK_TREE without explicit shit_DIR is accepted' '
	try_repo 1 "$here" unset unset "" unset \
		"$here/1/.shit" "$here" "$here" 1/ \
		"$here/1/.shit" "$here" "$here" 1/sub/ 2>message &&
	test_must_be_empty message
'

test_expect_success '#2: worktree defaults to cwd with explicit shit_DIR' '
	try_repo 2 unset "$here/2/.shit" unset "" unset \
		"$here/2/.shit" "$here/2" "$here/2" "(null)" \
		"$here/2/.shit" "$here/2/sub" "$here/2/sub" "(null)"
'

test_expect_success '#2b: relative shit_DIR' '
	try_repo 2b unset ".shit" unset "" unset \
		".shit" "$here/2b" "$here/2b" "(null)" \
		"../.shit" "$here/2b/sub" "$here/2b/sub" "(null)"
'

test_expect_success '#3: setup' '
	setup_repo 3 unset "" unset &&
	mkdir -p 3/sub/sub 3/wt/sub
'
run_wt_tests 3

test_expect_success '#4: core.worktree without shit_DIR set is accepted' '
	setup_repo 4 ../sub "" unset &&
	mkdir -p 4/sub sub &&
	try_case 4 unset unset \
		.shit "$here/4/sub" "$here/4" "(null)" \
		"$here/4/.shit" "$here/4/sub" "$here/4/sub" "(null)" 2>message &&
	test_must_be_empty message
'

test_expect_success '#5: core.worktree + shit_WORK_TREE is accepted' '
	# or: you cannot intimidate away the lack of shit_DIR setting
	try_repo 5 "$here" unset "$here/5" "" unset \
		"$here/5/.shit" "$here" "$here" 5/ \
		"$here/5/.shit" "$here" "$here" 5/sub/ 2>message &&
	try_repo 5a .. unset "$here/5a" "" unset \
		"$here/5a/.shit" "$here" "$here" 5a/ \
		"$here/5a/.shit" "$here/5a" "$here/5a" sub/ &&
	test_must_be_empty message
'

test_expect_success '#6: setting shit_DIR brings core.worktree to life' '
	setup_repo 6 "$here/6" "" unset &&
	try_case 6 unset .shit \
		.shit "$here/6" "$here/6" "(null)" &&
	try_case 6 unset "$here/6/.shit" \
		"$here/6/.shit" "$here/6" "$here/6" "(null)" &&
	try_case 6/sub/sub unset ../../.shit \
		"$here/6/.shit" "$here/6" "$here/6" sub/sub/ &&
	try_case 6/sub/sub unset "$here/6/.shit" \
		"$here/6/.shit" "$here/6" "$here/6" sub/sub/
'

test_expect_success '#6b: shit_DIR set, core.worktree relative' '
	setup_repo 6b .. "" unset &&
	try_case 6b unset .shit \
		.shit "$here/6b" "$here/6b" "(null)" &&
	try_case 6b unset "$here/6b/.shit" \
		"$here/6b/.shit" "$here/6b" "$here/6b" "(null)" &&
	try_case 6b/sub/sub unset ../../.shit \
		"$here/6b/.shit" "$here/6b" "$here/6b" sub/sub/ &&
	try_case 6b/sub/sub unset "$here/6b/.shit" \
		"$here/6b/.shit" "$here/6b" "$here/6b" sub/sub/
'

test_expect_success '#6c: shit_DIR set, core.worktree=../wt (absolute)' '
	setup_repo 6c "$here/6c/wt" "" unset &&
	mkdir -p 6c/wt/sub &&

	try_case 6c unset .shit \
		.shit "$here/6c/wt" "$here/6c" "(null)" &&
	try_case 6c unset "$here/6c/.shit" \
		"$here/6c/.shit" "$here/6c/wt" "$here/6c" "(null)" &&
	try_case 6c/sub/sub unset ../../.shit \
		../../.shit "$here/6c/wt" "$here/6c/sub/sub" "(null)" &&
	try_case 6c/sub/sub unset "$here/6c/.shit" \
		"$here/6c/.shit" "$here/6c/wt" "$here/6c/sub/sub" "(null)"
'

test_expect_success '#6d: shit_DIR set, core.worktree=../wt (relative)' '
	setup_repo 6d "$here/6d/wt" "" unset &&
	mkdir -p 6d/wt/sub &&

	try_case 6d unset .shit \
		.shit "$here/6d/wt" "$here/6d" "(null)" &&
	try_case 6d unset "$here/6d/.shit" \
		"$here/6d/.shit" "$here/6d/wt" "$here/6d" "(null)" &&
	try_case 6d/sub/sub unset ../../.shit \
		../../.shit "$here/6d/wt" "$here/6d/sub/sub" "(null)" &&
	try_case 6d/sub/sub unset "$here/6d/.shit" \
		"$here/6d/.shit" "$here/6d/wt" "$here/6d/sub/sub" "(null)"
'

test_expect_success '#6e: shit_DIR set, core.worktree=../.. (absolute)' '
	setup_repo 6e "$here" "" unset &&
	try_case 6e unset .shit \
		"$here/6e/.shit" "$here" "$here" 6e/ &&
	try_case 6e unset "$here/6e/.shit" \
		"$here/6e/.shit" "$here" "$here" 6e/ &&
	try_case 6e/sub/sub unset ../../.shit \
		"$here/6e/.shit" "$here" "$here" 6e/sub/sub/ &&
	try_case 6e/sub/sub unset "$here/6e/.shit" \
		"$here/6e/.shit" "$here" "$here" 6e/sub/sub/
'

test_expect_success '#6f: shit_DIR set, core.worktree=../.. (relative)' '
	setup_repo 6f ../../ "" unset &&
	try_case 6f unset .shit \
		"$here/6f/.shit" "$here" "$here" 6f/ &&
	try_case 6f unset "$here/6f/.shit" \
		"$here/6f/.shit" "$here" "$here" 6f/ &&
	try_case 6f/sub/sub unset ../../.shit \
		"$here/6f/.shit" "$here" "$here" 6f/sub/sub/ &&
	try_case 6f/sub/sub unset "$here/6f/.shit" \
		"$here/6f/.shit" "$here" "$here" 6f/sub/sub/
'

# case #7: shit_WORK_TREE overrides core.worktree.
test_expect_success '#7: setup' '
	setup_repo 7 non-existent "" unset &&
	mkdir -p 7/sub/sub 7/wt/sub
'
run_wt_tests 7

test_expect_success '#8: shitfile, easy case' '
	try_repo 8 unset unset unset shitfile unset \
		"$here/8.shit" "$here/8" "$here/8" "(null)" \
		"$here/8.shit" "$here/8" "$here/8" sub/
'

test_expect_success '#9: shit_WORK_TREE accepted with shitfile' '
	mkdir -p 9/wt &&
	try_repo 9 wt unset unset shitfile unset \
		"$here/9.shit" "$here/9/wt" "$here/9" "(null)" \
		"$here/9.shit" "$here/9/sub/wt" "$here/9/sub" "(null)" 2>message &&
	test_must_be_empty message
'

test_expect_success '#10: shit_DIR can point to shitfile' '
	try_repo 10 unset "$here/10/.shit" unset shitfile unset \
		"$here/10.shit" "$here/10" "$here/10" "(null)" \
		"$here/10.shit" "$here/10/sub" "$here/10/sub" "(null)"
'

test_expect_success '#10b: relative shit_DIR can point to shitfile' '
	try_repo 10b unset .shit unset shitfile unset \
		"$here/10b.shit" "$here/10b" "$here/10b" "(null)" \
		"$here/10b.shit" "$here/10b/sub" "$here/10b/sub" "(null)"
'

# case #11: shit_WORK_TREE works, shitfile case.
test_expect_success '#11: setup' '
	setup_repo 11 unset shitfile unset &&
	mkdir -p 11/sub/sub 11/wt/sub
'
run_wt_tests 11 shitfile

test_expect_success '#12: core.worktree with shitfile is accepted' '
	try_repo 12 unset unset "$here/12" shitfile unset \
		"$here/12.shit" "$here/12" "$here/12" "(null)" \
		"$here/12.shit" "$here/12" "$here/12" sub/ 2>message &&
	test_must_be_empty message
'

test_expect_success '#13: core.worktree+shit_WORK_TREE accepted (with shitfile)' '
	# or: you cannot intimidate away the lack of shit_DIR setting
	try_repo 13 non-existent-too unset non-existent shitfile unset \
		"$here/13.shit" "$here/13/non-existent-too" "$here/13" "(null)" \
		"$here/13.shit" "$here/13/sub/non-existent-too" "$here/13/sub" "(null)" 2>message &&
	test_must_be_empty message
'

# case #14.
# If this were more table-driven, it could share code with case #6.

test_expect_success '#14: core.worktree with shit_DIR pointing to shitfile' '
	setup_repo 14 "$here/14" shitfile unset &&
	try_case 14 unset .shit \
		"$here/14.shit" "$here/14" "$here/14" "(null)" &&
	try_case 14 unset "$here/14/.shit" \
		"$here/14.shit" "$here/14" "$here/14" "(null)" &&
	try_case 14/sub/sub unset ../../.shit \
		"$here/14.shit" "$here/14" "$here/14" sub/sub/ &&
	try_case 14/sub/sub unset "$here/14/.shit" \
		"$here/14.shit" "$here/14" "$here/14" sub/sub/ &&

	setup_repo 14c "$here/14c/wt" shitfile unset &&
	mkdir -p 14c/wt/sub &&

	try_case 14c unset .shit \
		"$here/14c.shit" "$here/14c/wt" "$here/14c" "(null)" &&
	try_case 14c unset "$here/14c/.shit" \
		"$here/14c.shit" "$here/14c/wt" "$here/14c" "(null)" &&
	try_case 14c/sub/sub unset ../../.shit \
		"$here/14c.shit" "$here/14c/wt" "$here/14c/sub/sub" "(null)" &&
	try_case 14c/sub/sub unset "$here/14c/.shit" \
		"$here/14c.shit" "$here/14c/wt" "$here/14c/sub/sub" "(null)" &&

	setup_repo 14d "$here/14d/wt" shitfile unset &&
	mkdir -p 14d/wt/sub &&

	try_case 14d unset .shit \
		"$here/14d.shit" "$here/14d/wt" "$here/14d" "(null)" &&
	try_case 14d unset "$here/14d/.shit" \
		"$here/14d.shit" "$here/14d/wt" "$here/14d" "(null)" &&
	try_case 14d/sub/sub unset ../../.shit \
		"$here/14d.shit" "$here/14d/wt" "$here/14d/sub/sub" "(null)" &&
	try_case 14d/sub/sub unset "$here/14d/.shit" \
		"$here/14d.shit" "$here/14d/wt" "$here/14d/sub/sub" "(null)" &&

	setup_repo 14e "$here" shitfile unset &&
	try_case 14e unset .shit \
		"$here/14e.shit" "$here" "$here" 14e/ &&
	try_case 14e unset "$here/14e/.shit" \
		"$here/14e.shit" "$here" "$here" 14e/ &&
	try_case 14e/sub/sub unset ../../.shit \
		"$here/14e.shit" "$here" "$here" 14e/sub/sub/ &&
	try_case 14e/sub/sub unset "$here/14e/.shit" \
		"$here/14e.shit" "$here" "$here" 14e/sub/sub/
'

test_expect_success '#14b: core.worktree is relative to actual shit dir' '
	setup_repo 14b ../14b shitfile unset &&
	try_case 14b unset .shit \
		"$here/14b.shit" "$here/14b" "$here/14b" "(null)" &&
	try_case 14b unset "$here/14b/.shit" \
		"$here/14b.shit" "$here/14b" "$here/14b" "(null)" &&
	try_case 14b/sub/sub unset ../../.shit \
		"$here/14b.shit" "$here/14b" "$here/14b" sub/sub/ &&
	try_case 14b/sub/sub unset "$here/14b/.shit" \
		"$here/14b.shit" "$here/14b" "$here/14b" sub/sub/ &&

	setup_repo 14f ../ shitfile unset &&
	try_case 14f unset .shit \
		"$here/14f.shit" "$here" "$here" 14f/ &&
	try_case 14f unset "$here/14f/.shit" \
		"$here/14f.shit" "$here" "$here" 14f/ &&
	try_case 14f/sub/sub unset ../../.shit \
		"$here/14f.shit" "$here" "$here" 14f/sub/sub/ &&
	try_case 14f/sub/sub unset "$here/14f/.shit" \
		"$here/14f.shit" "$here" "$here" 14f/sub/sub/
'

# case #15: shit_WORK_TREE overrides core.worktree (shitfile case).
test_expect_success '#15: setup' '
	setup_repo 15 non-existent shitfile unset &&
	mkdir -p 15/sub/sub 15/wt/sub
'
run_wt_tests 15 shitfile

test_expect_success '#16a: implicitly bare repo (cwd inside .shit dir)' '
	setup_repo 16a unset "" unset &&
	mkdir -p 16a/.shit/wt/sub &&

	try_case 16a/.shit unset unset \
		. "(null)" "$here/16a/.shit" "(null)" &&
	try_case 16a/.shit/wt unset unset \
		"$here/16a/.shit" "(null)" "$here/16a/.shit/wt" "(null)" &&
	try_case 16a/.shit/wt/sub unset unset \
		"$here/16a/.shit" "(null)" "$here/16a/.shit/wt/sub" "(null)"
'

test_expect_success '#16b: bare .shit (cwd inside .shit dir)' '
	setup_repo 16b unset "" true &&
	mkdir -p 16b/.shit/wt/sub &&

	try_case 16b/.shit unset unset \
		. "(null)" "$here/16b/.shit" "(null)" &&
	try_case 16b/.shit/wt unset unset \
		"$here/16b/.shit" "(null)" "$here/16b/.shit/wt" "(null)" &&
	try_case 16b/.shit/wt/sub unset unset \
		"$here/16b/.shit" "(null)" "$here/16b/.shit/wt/sub" "(null)"
'

test_expect_success '#16c: bare .shit has no worktree' '
	try_repo 16c unset unset unset "" true \
		.shit "(null)" "$here/16c" "(null)" \
		"$here/16c/.shit" "(null)" "$here/16c/sub" "(null)"
'

test_expect_success '#16d: bareness preserved across alias' '
	setup_repo 16d unset "" unset &&
	(
		cd 16d/.shit &&
		test_must_fail shit status &&
		shit config alias.st status &&
		test_must_fail shit st
	)
'

test_expect_success '#16e: bareness preserved by --bare' '
	setup_repo 16e unset "" unset &&
	(
		cd 16e/.shit &&
		test_must_fail shit status &&
		test_must_fail shit --bare status
	)
'

test_expect_success '#17: shit_WORK_TREE without explicit shit_DIR is accepted (bare case)' '
	# Just like #16.
	setup_repo 17a unset "" true &&
	setup_repo 17b unset "" true &&
	mkdir -p 17a/.shit/wt/sub &&
	mkdir -p 17b/.shit/wt/sub &&

	try_case 17a/.shit "$here/17a" unset \
		"$here/17a/.shit" "$here/17a" "$here/17a" .shit/ \
		2>message &&
	try_case 17a/.shit/wt "$here/17a" unset \
		"$here/17a/.shit" "$here/17a" "$here/17a" .shit/wt/ &&
	try_case 17a/.shit/wt/sub "$here/17a" unset \
		"$here/17a/.shit" "$here/17a" "$here/17a" .shit/wt/sub/ &&

	try_case 17b/.shit "$here/17b" unset \
		"$here/17b/.shit" "$here/17b" "$here/17b" .shit/ &&
	try_case 17b/.shit/wt "$here/17b" unset \
		"$here/17b/.shit" "$here/17b" "$here/17b" .shit/wt/ &&
	try_case 17b/.shit/wt/sub "$here/17b" unset \
		"$here/17b/.shit" "$here/17b" "$here/17b" .shit/wt/sub/ &&

	try_repo 17c "$here/17c" unset unset "" true \
		.shit "$here/17c" "$here/17c" "(null)" \
		"$here/17c/.shit" "$here/17c" "$here/17c" sub/ 2>message &&
	test_must_be_empty message
'

test_expect_success '#18: bare .shit named by shit_DIR has no worktree' '
	try_repo 18 unset .shit unset "" true \
		.shit "(null)" "$here/18" "(null)" \
		../.shit "(null)" "$here/18/sub" "(null)" &&
	try_repo 18b unset "$here/18b/.shit" unset "" true \
		"$here/18b/.shit" "(null)" "$here/18b" "(null)" \
		"$here/18b/.shit" "(null)" "$here/18b/sub" "(null)"
'

# Case #19: shit_DIR + shit_WORK_TREE suppresses bareness.
test_expect_success '#19: setup' '
	setup_repo 19 unset "" true &&
	mkdir -p 19/sub/sub 19/wt/sub
'
run_wt_tests 19

test_expect_success '#20a: core.worktree without shit_DIR accepted (inside .shit)' '
	# Unlike case #16a.
	setup_repo 20a "$here/20a" "" unset &&
	mkdir -p 20a/.shit/wt/sub &&
	try_case 20a/.shit unset unset \
		"$here/20a/.shit" "$here/20a" "$here/20a" .shit/ 2>message &&
	try_case 20a/.shit/wt unset unset \
		"$here/20a/.shit" "$here/20a" "$here/20a" .shit/wt/ &&
	try_case 20a/.shit/wt/sub unset unset \
		"$here/20a/.shit" "$here/20a" "$here/20a" .shit/wt/sub/ &&
	test_must_be_empty message
'

test_expect_success '#20b/c: core.worktree and core.bare conflict' '
	setup_repo 20b non-existent "" true &&
	mkdir -p 20b/.shit/wt/sub &&
	(
		cd 20b/.shit &&
		test_must_fail shit status >/dev/null
	) 2>message &&
	grep "core.bare and core.worktree" message
'

test_expect_success '#20d: core.worktree and core.bare OK when working tree not needed' '
	setup_repo 20d non-existent "" true &&
	mkdir -p 20d/.shit/wt/sub &&
	(
		cd 20d/.shit &&
		shit config foo.bar value
	)
'

# Case #21: core.worktree/shit_WORK_TREE overrides core.bare' '
test_expect_success '#21: setup, core.worktree warns before overriding core.bare' '
	setup_repo 21 non-existent "" unset &&
	mkdir -p 21/.shit/wt/sub &&
	(
		cd 21/.shit &&
		shit_WORK_TREE="$here/21" &&
		export shit_WORK_TREE &&
		shit status >/dev/null
	) 2>message &&
	test_must_be_empty message

'
run_wt_tests 21

test_expect_success '#22a: core.worktree = shit_DIR = .shit dir' '
	# like case #6.

	setup_repo 22a "$here/22a/.shit" "" unset &&
	setup_repo 22ab . "" unset &&
	mkdir -p 22a/.shit/sub 22a/sub &&
	mkdir -p 22ab/.shit/sub 22ab/sub &&
	try_case 22a/.shit unset . \
		. "$here/22a/.shit" "$here/22a/.shit" "(null)" &&
	try_case 22a/.shit unset "$here/22a/.shit" \
		"$here/22a/.shit" "$here/22a/.shit" "$here/22a/.shit" "(null)" &&
	try_case 22a/.shit/sub unset .. \
		"$here/22a/.shit" "$here/22a/.shit" "$here/22a/.shit" sub/ &&
	try_case 22a/.shit/sub unset "$here/22a/.shit" \
		"$here/22a/.shit" "$here/22a/.shit" "$here/22a/.shit" sub/ &&

	try_case 22ab/.shit unset . \
		. "$here/22ab/.shit" "$here/22ab/.shit" "(null)" &&
	try_case 22ab/.shit unset "$here/22ab/.shit" \
		"$here/22ab/.shit" "$here/22ab/.shit" "$here/22ab/.shit" "(null)" &&
	try_case 22ab/.shit/sub unset .. \
		"$here/22ab/.shit" "$here/22ab/.shit" "$here/22ab/.shit" sub/ &&
	try_case 22ab/.shit unset "$here/22ab/.shit" \
		"$here/22ab/.shit" "$here/22ab/.shit" "$here/22ab/.shit" "(null)"
'

test_expect_success '#22b: core.worktree child of .shit, shit_DIR=.shit' '
	setup_repo 22b "$here/22b/.shit/wt" "" unset &&
	setup_repo 22bb wt "" unset &&
	mkdir -p 22b/.shit/sub 22b/sub 22b/.shit/wt/sub 22b/wt/sub &&
	mkdir -p 22bb/.shit/sub 22bb/sub 22bb/.shit/wt 22bb/wt &&

	try_case 22b/.shit unset . \
		. "$here/22b/.shit/wt" "$here/22b/.shit" "(null)" &&
	try_case 22b/.shit unset "$here/22b/.shit" \
		"$here/22b/.shit" "$here/22b/.shit/wt" "$here/22b/.shit" "(null)" &&
	try_case 22b/.shit/sub unset .. \
		.. "$here/22b/.shit/wt" "$here/22b/.shit/sub" "(null)" &&
	try_case 22b/.shit/sub unset "$here/22b/.shit" \
		"$here/22b/.shit" "$here/22b/.shit/wt" "$here/22b/.shit/sub" "(null)" &&

	try_case 22bb/.shit unset . \
		. "$here/22bb/.shit/wt" "$here/22bb/.shit" "(null)" &&
	try_case 22bb/.shit unset "$here/22bb/.shit" \
		"$here/22bb/.shit" "$here/22bb/.shit/wt" "$here/22bb/.shit" "(null)" &&
	try_case 22bb/.shit/sub unset .. \
		.. "$here/22bb/.shit/wt" "$here/22bb/.shit/sub" "(null)" &&
	try_case 22bb/.shit/sub unset "$here/22bb/.shit" \
		"$here/22bb/.shit" "$here/22bb/.shit/wt" "$here/22bb/.shit/sub" "(null)"
'

test_expect_success '#22c: core.worktree = .shit/.., shit_DIR=.shit' '
	setup_repo 22c "$here/22c" "" unset &&
	setup_repo 22cb .. "" unset &&
	mkdir -p 22c/.shit/sub 22c/sub &&
	mkdir -p 22cb/.shit/sub 22cb/sub &&

	try_case 22c/.shit unset . \
		"$here/22c/.shit" "$here/22c" "$here/22c" .shit/ &&
	try_case 22c/.shit unset "$here/22c/.shit" \
		"$here/22c/.shit" "$here/22c" "$here/22c" .shit/ &&
	try_case 22c/.shit/sub unset .. \
		"$here/22c/.shit" "$here/22c" "$here/22c" .shit/sub/ &&
	try_case 22c/.shit/sub unset "$here/22c/.shit" \
		"$here/22c/.shit" "$here/22c" "$here/22c" .shit/sub/ &&

	try_case 22cb/.shit unset . \
		"$here/22cb/.shit" "$here/22cb" "$here/22cb" .shit/ &&
	try_case 22cb/.shit unset "$here/22cb/.shit" \
		"$here/22cb/.shit" "$here/22cb" "$here/22cb" .shit/ &&
	try_case 22cb/.shit/sub unset .. \
		"$here/22cb/.shit" "$here/22cb" "$here/22cb" .shit/sub/ &&
	try_case 22cb/.shit/sub unset "$here/22cb/.shit" \
		"$here/22cb/.shit" "$here/22cb" "$here/22cb" .shit/sub/
'

test_expect_success '#22.2: core.worktree and core.bare conflict' '
	setup_repo 22 "$here/22" "" true &&
	(
		cd 22/.shit &&
		shit_DIR=. &&
		export shit_DIR &&
		test_must_fail shit status 2>result
	) &&
	(
		cd 22 &&
		shit_DIR=.shit &&
		export shit_DIR &&
		test_must_fail shit status 2>result
	) &&
	grep "core.bare and core.worktree" 22/.shit/result &&
	grep "core.bare and core.worktree" 22/result
'

# Case #23: shit_DIR + shit_WORK_TREE(+core.worktree) suppresses bareness.
test_expect_success '#23: setup' '
	setup_repo 23 non-existent "" true &&
	mkdir -p 23/sub/sub 23/wt/sub
'
run_wt_tests 23

test_expect_success '#24: bare repo has no worktree (shitfile case)' '
	try_repo 24 unset unset unset shitfile true \
		"$here/24.shit" "(null)" "$here/24" "(null)" \
		"$here/24.shit" "(null)" "$here/24/sub" "(null)"
'

test_expect_success '#25: shit_WORK_TREE accepted if shit_DIR unset (bare shitfile case)' '
	try_repo 25 "$here/25" unset unset shitfile true \
		"$here/25.shit" "$here/25" "$here/25" "(null)"  \
		"$here/25.shit" "$here/25" "$here/25" "sub/" 2>message &&
	test_must_be_empty message
'

test_expect_success '#26: bare repo has no worktree (shit_DIR -> shitfile case)' '
	try_repo 26 unset "$here/26/.shit" unset shitfile true \
		"$here/26.shit" "(null)" "$here/26" "(null)" \
		"$here/26.shit" "(null)" "$here/26/sub" "(null)" &&
	try_repo 26b unset .shit unset shitfile true \
		"$here/26b.shit" "(null)" "$here/26b" "(null)" \
		"$here/26b.shit" "(null)" "$here/26b/sub" "(null)"
'

# Case #27: shit_DIR + shit_WORK_TREE suppresses bareness (with shitfile).
test_expect_success '#27: setup' '
	setup_repo 27 unset shitfile true &&
	mkdir -p 27/sub/sub 27/wt/sub
'
run_wt_tests 27 shitfile

test_expect_success '#28: core.worktree and core.bare conflict (shitfile case)' '
	setup_repo 28 "$here/28" shitfile true &&
	(
		cd 28 &&
		test_must_fail shit status
	) 2>message &&
	grep "core.bare and core.worktree" message
'

# Case #29: shit_WORK_TREE(+core.worktree) overrides core.bare (shitfile case).
test_expect_success '#29: setup' '
	setup_repo 29 non-existent shitfile true &&
	mkdir -p 29/sub/sub 29/wt/sub &&
	(
		cd 29 &&
		shit_WORK_TREE="$here/29" &&
		export shit_WORK_TREE &&
		shit status
	) 2>message &&
	test_must_be_empty message
'
run_wt_tests 29 shitfile

test_expect_success '#30: core.worktree and core.bare conflict (shitfile version)' '
	# Just like case #22.
	setup_repo 30 "$here/30" shitfile true &&
	(
		cd 30 &&
		test_must_fail env shit_DIR=.shit shit status 2>result
	) &&
	grep "core.bare and core.worktree" 30/result
'

# Case #31: shit_DIR + shit_WORK_TREE(+core.worktree) suppresses
# bareness (shitfile version).
test_expect_success '#31: setup' '
	setup_repo 31 non-existent shitfile true &&
	mkdir -p 31/sub/sub 31/wt/sub
'
run_wt_tests 31 shitfile

test_done
