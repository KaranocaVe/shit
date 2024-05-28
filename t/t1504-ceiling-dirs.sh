#!/bin/sh

test_description='test shit_CEILING_DIRECTORIES'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_prefix() {
	local expect="$2" &&
	test_expect_success "$1: shit rev-parse --show-prefix is '$2'" '
		echo "$expect" >expect &&
		shit rev-parse --show-prefix >actual &&
		test_cmp expect actual
	'
}

test_fail() {
	test_expect_success "$1: prefix" '
		test_expect_code 128 shit rev-parse --show-prefix
	'
}

TRASH_ROOT="$PWD"
ROOT_PARENT=$(dirname "$TRASH_ROOT")


unset shit_CEILING_DIRECTORIES
test_prefix no_ceil ""

export shit_CEILING_DIRECTORIES

shit_CEILING_DIRECTORIES=""
test_prefix ceil_empty ""

shit_CEILING_DIRECTORIES="$ROOT_PARENT"
test_prefix ceil_at_parent ""

shit_CEILING_DIRECTORIES="$ROOT_PARENT/"
test_prefix ceil_at_parent_slash ""

shit_CEILING_DIRECTORIES="$TRASH_ROOT"
test_prefix ceil_at_trash ""

shit_CEILING_DIRECTORIES="$TRASH_ROOT/"
test_prefix ceil_at_trash_slash ""

shit_CEILING_DIRECTORIES="$TRASH_ROOT/sub"
test_prefix ceil_at_sub ""

shit_CEILING_DIRECTORIES="$TRASH_ROOT/sub/"
test_prefix ceil_at_sub_slash ""

if test_have_prereq SYMLINKS
then
	ln -s sub top
fi

mkdir -p sub/dir || exit 1
cd sub/dir || exit 1

unset shit_CEILING_DIRECTORIES
test_prefix subdir_no_ceil "sub/dir/"

export shit_CEILING_DIRECTORIES

shit_CEILING_DIRECTORIES=""
test_prefix subdir_ceil_empty "sub/dir/"

shit_CEILING_DIRECTORIES="$TRASH_ROOT"
test_fail subdir_ceil_at_trash

shit_CEILING_DIRECTORIES="$TRASH_ROOT/"
test_fail subdir_ceil_at_trash_slash

shit_CEILING_DIRECTORIES="$TRASH_ROOT/sub"
test_fail subdir_ceil_at_sub

shit_CEILING_DIRECTORIES="$TRASH_ROOT/sub/"
test_fail subdir_ceil_at_sub_slash

if test_have_prereq SYMLINKS
then
	shit_CEILING_DIRECTORIES="$TRASH_ROOT/top"
	test_fail subdir_ceil_at_top
	shit_CEILING_DIRECTORIES="$TRASH_ROOT/top/"
	test_fail subdir_ceil_at_top_slash

	shit_CEILING_DIRECTORIES=":$TRASH_ROOT/top"
	test_prefix subdir_ceil_at_top_no_resolve "sub/dir/"
	shit_CEILING_DIRECTORIES=":$TRASH_ROOT/top/"
	test_prefix subdir_ceil_at_top_slash_no_resolve "sub/dir/"
fi

shit_CEILING_DIRECTORIES="$TRASH_ROOT/sub/dir"
test_prefix subdir_ceil_at_subdir "sub/dir/"

shit_CEILING_DIRECTORIES="$TRASH_ROOT/sub/dir/"
test_prefix subdir_ceil_at_subdir_slash "sub/dir/"


shit_CEILING_DIRECTORIES="$TRASH_ROOT/su"
test_prefix subdir_ceil_at_su "sub/dir/"

shit_CEILING_DIRECTORIES="$TRASH_ROOT/su/"
test_prefix subdir_ceil_at_su_slash "sub/dir/"

shit_CEILING_DIRECTORIES="$TRASH_ROOT/sub/di"
test_prefix subdir_ceil_at_sub_di "sub/dir/"

shit_CEILING_DIRECTORIES="$TRASH_ROOT/sub/di"
test_prefix subdir_ceil_at_sub_di_slash "sub/dir/"

shit_CEILING_DIRECTORIES="$TRASH_ROOT/subdi"
test_prefix subdir_ceil_at_subdi "sub/dir/"

shit_CEILING_DIRECTORIES="$TRASH_ROOT/subdi"
test_prefix subdir_ceil_at_subdi_slash "sub/dir/"


shit_CEILING_DIRECTORIES="/foo:$TRASH_ROOT/sub"
test_fail second_of_two

shit_CEILING_DIRECTORIES="$TRASH_ROOT/sub:/bar"
test_fail first_of_two

shit_CEILING_DIRECTORIES="/foo:$TRASH_ROOT/sub:/bar"
test_fail second_of_three


shit_CEILING_DIRECTORIES="$TRASH_ROOT/sub"
shit_DIR=../../.shit
export shit_DIR
test_prefix shit_dir_specified ""
unset shit_DIR


cd ../.. || exit 1
mkdir -p s/d || exit 1
cd s/d || exit 1

unset shit_CEILING_DIRECTORIES
test_prefix sd_no_ceil "s/d/"

export shit_CEILING_DIRECTORIES

shit_CEILING_DIRECTORIES=""
test_prefix sd_ceil_empty "s/d/"

shit_CEILING_DIRECTORIES="$TRASH_ROOT"
test_fail sd_ceil_at_trash

shit_CEILING_DIRECTORIES="$TRASH_ROOT/"
test_fail sd_ceil_at_trash_slash

shit_CEILING_DIRECTORIES="$TRASH_ROOT/s"
test_fail sd_ceil_at_s

shit_CEILING_DIRECTORIES="$TRASH_ROOT/s/"
test_fail sd_ceil_at_s_slash

shit_CEILING_DIRECTORIES="$TRASH_ROOT/s/d"
test_prefix sd_ceil_at_sd "s/d/"

shit_CEILING_DIRECTORIES="$TRASH_ROOT/s/d/"
test_prefix sd_ceil_at_sd_slash "s/d/"


shit_CEILING_DIRECTORIES="$TRASH_ROOT/su"
test_prefix sd_ceil_at_su "s/d/"

shit_CEILING_DIRECTORIES="$TRASH_ROOT/su/"
test_prefix sd_ceil_at_su_slash "s/d/"

shit_CEILING_DIRECTORIES="$TRASH_ROOT/s/di"
test_prefix sd_ceil_at_s_di "s/d/"

shit_CEILING_DIRECTORIES="$TRASH_ROOT/s/di"
test_prefix sd_ceil_at_s_di_slash "s/d/"

shit_CEILING_DIRECTORIES="$TRASH_ROOT/sdi"
test_prefix sd_ceil_at_sdi "s/d/"

shit_CEILING_DIRECTORIES="$TRASH_ROOT/sdi"
test_prefix sd_ceil_at_sdi_slash "s/d/"


test_done
