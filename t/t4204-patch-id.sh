#!/bin/sh

test_description='shit patch-id'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '
	str="ab cd ef gh ij kl mn op" &&
	test_write_lines $str >foo &&
	test_write_lines $str >bar &&
	shit add foo bar &&
	shit commit -a -m initial &&
	test_write_lines $str b >foo &&
	test_write_lines $str b >bar &&
	shit commit -a -m first &&
	shit checkout -b same main &&
	shit commit --amend -m same-msg &&
	shit checkout -b notsame main &&
	echo c >foo &&
	echo c >bar &&
	shit commit --amend -a -m notsame-msg &&
	shit checkout -b with_space main~ &&
	cat >foo <<-\EOF &&
	a  b
	c d
	e    f
	  g   h
	    i   j
	k l
	m   n
	op
	EOF
	cp foo bar &&
	shit add foo bar &&
	shit commit --amend -m "with spaces" &&
	test_write_lines bar foo >bar-then-foo &&
	test_write_lines foo bar >foo-then-bar

'

test_expect_success 'patch-id output is well-formed' '
	shit log -p -1 >log.output &&
	shit patch-id <log.output >output &&
	grep "^$OID_REGEX $(shit rev-parse HEAD)$" output
'

#calculate patch id. Make sure output is not empty.
calc_patch_id () {
	patch_name="$1"
	shift
	shit patch-id "$@" >patch-id.output &&
	sed "s/ .*//" patch-id.output >patch-id_"$patch_name" &&
	test_line_count -eq 1 patch-id_"$patch_name"
}

get_top_diff () {
	shit log -p -1 "$@" -O bar-then-foo --full-index --
}

get_patch_id () {
	get_top_diff "$1" >top-diff.output &&
	calc_patch_id <top-diff.output "$@"
}

test_expect_success 'patch-id detects equality' '
	get_patch_id main &&
	get_patch_id same &&
	test_cmp patch-id_main patch-id_same
'

test_expect_success 'patch-id detects inequality' '
	get_patch_id main &&
	get_patch_id notsame &&
	! test_cmp patch-id_main patch-id_notsame
'
test_expect_success 'patch-id detects equality binary' '
	cat >.shitattributes <<-\EOF &&
	foo binary
	bar binary
	EOF
	get_patch_id main &&
	get_patch_id same &&
	shit log -p -1 --binary main >top-diff.output &&
	calc_patch_id <top-diff.output main_binpatch &&
	shit log -p -1 --binary same >top-diff.output &&
	calc_patch_id <top-diff.output same_binpatch &&
	test_cmp patch-id_main patch-id_main_binpatch &&
	test_cmp patch-id_same patch-id_same_binpatch &&
	test_cmp patch-id_main patch-id_same &&
	test_when_finished "rm .shitattributes"
'

test_expect_success 'patch-id detects inequality binary' '
	cat >.shitattributes <<-\EOF &&
	foo binary
	bar binary
	EOF
	get_patch_id main &&
	get_patch_id notsame &&
	! test_cmp patch-id_main patch-id_notsame &&
	test_when_finished "rm .shitattributes"
'

test_expect_success 'patch-id supports shit-format-patch output' '
	get_patch_id main &&
	shit checkout same &&
	shit format-patch -1 --stdout >format-patch.output &&
	calc_patch_id same <format-patch.output &&
	test_cmp patch-id_main patch-id_same &&
	set $(shit patch-id <format-patch.output) &&
	test "$2" = $(shit rev-parse HEAD)
'

test_expect_success 'whitespace is irrelevant in footer' '
	get_patch_id main &&
	shit checkout same &&
	shit format-patch -1 --stdout >format-patch.output &&
	sed "s/ \$//" format-patch.output | calc_patch_id same &&
	test_cmp patch-id_main patch-id_same
'

cmp_patch_id () {
	if
		test "$1" = "relevant"
	then
		! test_cmp patch-id_"$2" patch-id_"$3"
	else
		test_cmp patch-id_"$2" patch-id_"$3"
	fi
}

test_patch_id_file_order () {
	relevant="$1"
	shift
	name="order-${1}-$relevant"
	shift
	get_top_diff "main" >top-diff.output &&
	calc_patch_id <top-diff.output "$name" "$@" &&
	shit checkout same &&
	shit format-patch -1 --stdout -O foo-then-bar >format-patch.output &&
	calc_patch_id <format-patch.output "ordered-$name" "$@" &&
	cmp_patch_id $relevant "$name" "ordered-$name"
}

test_patch_id_whitespace () {
	relevant="$1"
	shift
	name="ws-${1}-$relevant"
	shift
	get_top_diff "main~" >top-diff.output &&
	calc_patch_id <top-diff.output "$name" "$@" &&
	get_top_diff "with_space" >top-diff.output &&
	calc_patch_id <top-diff.output "ws-$name" "$@" &&
	cmp_patch_id $relevant "$name" "ws-$name"
}


# combined test for options: add more tests here to make them
# run with all options
test_patch_id () {
	test_patch_id_file_order "$@"
}

# small tests with detailed diagnostic for basic options.
test_expect_success 'file order is irrelevant with --stable' '
	test_patch_id_file_order irrelevant --stable --stable
'

test_expect_success 'file order is relevant with --unstable' '
	test_patch_id_file_order relevant --unstable --unstable
'

test_expect_success 'whitespace is relevant with --verbatim' '
	test_patch_id_whitespace relevant --verbatim --verbatim
'

test_expect_success 'whitespace is irrelevant without --verbatim' '
	test_patch_id_whitespace irrelevant --stable --stable
'

#Now test various option combinations.
test_expect_success 'default is unstable' '
	test_patch_id relevant default
'

test_expect_success 'patchid.stable = true is stable' '
	test_config patchid.stable true &&
	test_patch_id irrelevant patchid.stable=true
'

test_expect_success 'patchid.stable = false is unstable' '
	test_config patchid.stable false &&
	test_patch_id relevant patchid.stable=false
'

test_expect_success 'patchid.verbatim = true is correct and stable' '
	test_config patchid.verbatim true &&
	test_patch_id_whitespace relevant patchid.verbatim=true &&
	test_patch_id irrelevant patchid.verbatim=true
'

test_expect_success 'patchid.verbatim = false is unstable' '
	test_config patchid.verbatim false &&
	test_patch_id relevant patchid.verbatim=false
'

test_expect_success '--unstable overrides patchid.stable = true' '
	test_config patchid.stable true &&
	test_patch_id relevant patchid.stable=true--unstable --unstable
'

test_expect_success '--stable overrides patchid.stable = false' '
	test_config patchid.stable false &&
	test_patch_id irrelevant patchid.stable=false--stable --stable
'

test_expect_success '--verbatim overrides patchid.stable = false' '
	test_config patchid.stable false &&
	test_patch_id_whitespace relevant stable=false--verbatim --verbatim
'

test_expect_success 'patch-id supports shit-format-patch MIME output' '
	get_patch_id main &&
	shit checkout same &&
	shit format-patch -1 --attach --stdout >format-patch.output &&
	calc_patch_id <format-patch.output same &&
	test_cmp patch-id_main patch-id_same
'

test_expect_success 'patch-id respects config from subdir' '
	test_config patchid.stable true &&
	mkdir subdir &&

	# copy these because test_patch_id() looks for them in
	# the current directory
	cp bar-then-foo foo-then-bar subdir &&

	(
		cd subdir &&
		test_patch_id irrelevant patchid.stable=true
	)
'

test_expect_success 'patch-id handles no-nl-at-eof markers' '
	cat >nonl <<-\EOF &&
	diff --shit i/a w/a
	index e69de29..2e65efe 100644
	--- i/a
	+++ w/a
	@@ -0,0 +1 @@
	+a
	\ No newline at end of file
	diff --shit i/b w/b
	index e69de29..6178079 100644
	--- i/b
	+++ w/b
	@@ -0,0 +1 @@
	+b
	EOF
	cat >withnl <<-\EOF &&
	diff --shit i/a w/a
	index e69de29..7898192 100644
	--- i/a
	+++ w/a
	@@ -0,0 +1 @@
	+a
	diff --shit i/b w/b
	index e69de29..6178079 100644
	--- i/b
	+++ w/b
	@@ -0,0 +1 @@
	+b
	EOF
	calc_patch_id nonl <nonl &&
	calc_patch_id withnl <withnl &&
	test_cmp patch-id_nonl patch-id_withnl &&
	calc_patch_id nonl-inc-ws --verbatim <nonl &&
	calc_patch_id withnl-inc-ws --verbatim <withnl &&
	! test_cmp patch-id_nonl-inc-ws patch-id_withnl-inc-ws
'

test_expect_success 'patch-id handles diffs with one line of before/after' '
	cat >diffu1 <<-\EOF &&
	diff --shit a/bar b/bar
	index bdaf90f..31051f6 100644
	--- a/bar
	+++ b/bar
	@@ -2 +2,2 @@
	 b
	+c
	diff --shit a/car b/car
	index 00750ed..2ae5e34 100644
	--- a/car
	+++ b/car
	@@ -1 +1,2 @@
	 3
	+d
	diff --shit a/foo b/foo
	index e439850..7146eb8 100644
	--- a/foo
	+++ b/foo
	@@ -2 +2,2 @@
	 a
	+e
	EOF
	calc_patch_id diffu1 <diffu1 &&
	test_config patchid.stable true &&
	calc_patch_id diffu1stable <diffu1
'
test_done
