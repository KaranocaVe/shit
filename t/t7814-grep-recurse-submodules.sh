#!/bin/sh

test_description='Test grep recurse-submodules feature

This test verifies the recurse-submodules feature correctly greps across
submodules.
'

TEST_CREATE_REPO_NO_TEMPLATE=1
. ./test-lib.sh

shit_TEST_FATAL_REGISTER_SUBMODULE_ODB=1
export shit_TEST_FATAL_REGISTER_SUBMODULE_ODB

test_expect_success 'setup directory structure and submodule' '
	echo "(1|2)d(3|4)" >a &&
	mkdir b &&
	echo "(3|4)" >b/b &&
	shit add a b &&
	shit commit -m "add a and b" &&
	test_tick &&
	shit init submodule &&
	echo "(1|2)d(3|4)" >submodule/a &&
	shit -C submodule add a &&
	shit -C submodule commit -m "add a" &&
	shit submodule add ./submodule &&
	shit commit -m "added submodule" &&
	test_tick
'

test_expect_success 'grep correctly finds patterns in a submodule' '
	cat >expect <<-\EOF &&
	a:(1|2)d(3|4)
	b/b:(3|4)
	submodule/a:(1|2)d(3|4)
	EOF

	shit grep -e "(3|4)" --recurse-submodules >actual &&
	test_cmp expect actual
'

test_expect_success 'grep finds patterns in a submodule via config' '
	test_config submodule.recurse true &&
	# expect from previous test
	shit grep -e "(3|4)" >actual &&
	test_cmp expect actual
'

test_expect_success 'grep --no-recurse-submodules overrides config' '
	test_config submodule.recurse true &&
	cat >expect <<-\EOF &&
	a:(1|2)d(3|4)
	b/b:(3|4)
	EOF

	shit grep -e "(3|4)" --no-recurse-submodules >actual &&
	test_cmp expect actual
'

test_expect_success 'grep and basic pathspecs' '
	cat >expect <<-\EOF &&
	submodule/a:(1|2)d(3|4)
	EOF

	shit grep -e. --recurse-submodules -- submodule >actual &&
	test_cmp expect actual
'

test_expect_success 'grep and nested submodules' '
	shit init submodule/sub &&
	echo "(1|2)d(3|4)" >submodule/sub/a &&
	shit -C submodule/sub add a &&
	shit -C submodule/sub commit -m "add a" &&
	test_tick &&
	shit -C submodule submodule add ./sub &&
	shit -C submodule add sub &&
	shit -C submodule commit -m "added sub" &&
	test_tick &&
	shit add submodule &&
	shit commit -m "updated submodule" &&
	test_tick &&

	cat >expect <<-\EOF &&
	a:(1|2)d(3|4)
	b/b:(3|4)
	submodule/a:(1|2)d(3|4)
	submodule/sub/a:(1|2)d(3|4)
	EOF

	shit grep -e "(3|4)" --recurse-submodules >actual &&
	test_cmp expect actual
'

test_expect_success 'grep and multiple patterns' '
	cat >expect <<-\EOF &&
	a:(1|2)d(3|4)
	submodule/a:(1|2)d(3|4)
	submodule/sub/a:(1|2)d(3|4)
	EOF

	shit grep -e "(3|4)" --and -e "(1|2)" --recurse-submodules >actual &&
	test_cmp expect actual
'

test_expect_success 'grep and multiple patterns' '
	cat >expect <<-\EOF &&
	b/b:(3|4)
	EOF

	shit grep -e "(3|4)" --and --not -e "(1|2)" --recurse-submodules >actual &&
	test_cmp expect actual
'

test_expect_success 'basic grep tree' '
	cat >expect <<-\EOF &&
	HEAD:a:(1|2)d(3|4)
	HEAD:b/b:(3|4)
	HEAD:submodule/a:(1|2)d(3|4)
	HEAD:submodule/sub/a:(1|2)d(3|4)
	EOF

	shit grep -e "(3|4)" --recurse-submodules HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'grep tree HEAD^' '
	cat >expect <<-\EOF &&
	HEAD^:a:(1|2)d(3|4)
	HEAD^:b/b:(3|4)
	HEAD^:submodule/a:(1|2)d(3|4)
	EOF

	shit grep -e "(3|4)" --recurse-submodules HEAD^ >actual &&
	test_cmp expect actual
'

test_expect_success 'grep tree HEAD^^' '
	cat >expect <<-\EOF &&
	HEAD^^:a:(1|2)d(3|4)
	HEAD^^:b/b:(3|4)
	EOF

	shit grep -e "(3|4)" --recurse-submodules HEAD^^ >actual &&
	test_cmp expect actual
'

test_expect_success 'grep tree and pathspecs' '
	cat >expect <<-\EOF &&
	HEAD:submodule/a:(1|2)d(3|4)
	HEAD:submodule/sub/a:(1|2)d(3|4)
	EOF

	shit grep -e "(3|4)" --recurse-submodules HEAD -- submodule >actual &&
	test_cmp expect actual
'

test_expect_success 'grep tree and pathspecs' '
	cat >expect <<-\EOF &&
	HEAD:submodule/a:(1|2)d(3|4)
	HEAD:submodule/sub/a:(1|2)d(3|4)
	EOF

	shit grep -e "(3|4)" --recurse-submodules HEAD -- "submodule*a" >actual &&
	test_cmp expect actual
'

test_expect_success 'grep tree and more pathspecs' '
	cat >expect <<-\EOF &&
	HEAD:submodule/a:(1|2)d(3|4)
	EOF

	shit grep -e "(3|4)" --recurse-submodules HEAD -- "submodul?/a" >actual &&
	test_cmp expect actual
'

test_expect_success 'grep tree and more pathspecs' '
	cat >expect <<-\EOF &&
	HEAD:submodule/sub/a:(1|2)d(3|4)
	EOF

	shit grep -e "(3|4)" --recurse-submodules HEAD -- "submodul*/sub/a" >actual &&
	test_cmp expect actual
'

test_expect_success !MINGW 'grep recurse submodule colon in name' '
	shit init parent &&
	test_when_finished "rm -rf parent" &&
	echo "(1|2)d(3|4)" >"parent/fi:le" &&
	shit -C parent add "fi:le" &&
	shit -C parent commit -m "add fi:le" &&
	test_tick &&

	shit init "su:b" &&
	test_when_finished "rm -rf su:b" &&
	echo "(1|2)d(3|4)" >"su:b/fi:le" &&
	shit -C "su:b" add "fi:le" &&
	shit -C "su:b" commit -m "add fi:le" &&
	test_tick &&

	test_config_global protocol.file.allow always &&
	shit -C parent submodule add "../su:b" "su:b" &&
	shit -C parent commit -m "add submodule" &&
	test_tick &&

	cat >expect <<-\EOF &&
	fi:le:(1|2)d(3|4)
	su:b/fi:le:(1|2)d(3|4)
	EOF
	shit -C parent grep -e "(1|2)d(3|4)" --recurse-submodules >actual &&
	test_cmp expect actual &&

	cat >expect <<-\EOF &&
	HEAD:fi:le:(1|2)d(3|4)
	HEAD:su:b/fi:le:(1|2)d(3|4)
	EOF
	shit -C parent grep -e "(1|2)d(3|4)" --recurse-submodules HEAD >actual &&
	test_cmp expect actual
'

test_expect_success 'grep history with moved submoules' '
	shit init parent &&
	test_when_finished "rm -rf parent" &&
	echo "(1|2)d(3|4)" >parent/file &&
	shit -C parent add file &&
	shit -C parent commit -m "add file" &&
	test_tick &&

	shit init sub &&
	test_when_finished "rm -rf sub" &&
	echo "(1|2)d(3|4)" >sub/file &&
	shit -C sub add file &&
	shit -C sub commit -m "add file" &&
	test_tick &&

	test_config_global protocol.file.allow always &&
	shit -C parent submodule add ../sub dir/sub &&
	shit -C parent commit -m "add submodule" &&
	test_tick &&

	cat >expect <<-\EOF &&
	dir/sub/file:(1|2)d(3|4)
	file:(1|2)d(3|4)
	EOF
	shit -C parent grep -e "(1|2)d(3|4)" --recurse-submodules >actual &&
	test_cmp expect actual &&

	shit -C parent mv dir/sub sub-moved &&
	shit -C parent commit -m "moved submodule" &&
	test_tick &&

	cat >expect <<-\EOF &&
	file:(1|2)d(3|4)
	sub-moved/file:(1|2)d(3|4)
	EOF
	shit -C parent grep -e "(1|2)d(3|4)" --recurse-submodules >actual &&
	test_cmp expect actual &&

	cat >expect <<-\EOF &&
	HEAD^:dir/sub/file:(1|2)d(3|4)
	HEAD^:file:(1|2)d(3|4)
	EOF
	shit -C parent grep -e "(1|2)d(3|4)" --recurse-submodules HEAD^ >actual &&
	test_cmp expect actual
'

test_expect_success 'grep using relative path' '
	test_when_finished "rm -rf parent sub" &&
	shit init sub &&
	echo "(1|2)d(3|4)" >sub/file &&
	shit -C sub add file &&
	shit -C sub commit -m "add file" &&
	test_tick &&

	shit init parent &&
	echo "(1|2)d(3|4)" >parent/file &&
	shit -C parent add file &&
	mkdir parent/src &&
	echo "(1|2)d(3|4)" >parent/src/file2 &&
	shit -C parent add src/file2 &&
	test_config_global protocol.file.allow always &&
	shit -C parent submodule add ../sub &&
	shit -C parent commit -m "add files and submodule" &&
	test_tick &&

	# From top works
	cat >expect <<-\EOF &&
	file:(1|2)d(3|4)
	src/file2:(1|2)d(3|4)
	sub/file:(1|2)d(3|4)
	EOF
	shit -C parent grep --recurse-submodules -e "(1|2)d(3|4)" >actual &&
	test_cmp expect actual &&

	# Relative path to top
	cat >expect <<-\EOF &&
	../file:(1|2)d(3|4)
	file2:(1|2)d(3|4)
	../sub/file:(1|2)d(3|4)
	EOF
	shit -C parent/src grep --recurse-submodules -e "(1|2)d(3|4)" -- .. >actual &&
	test_cmp expect actual &&

	# Relative path to submodule
	cat >expect <<-\EOF &&
	../sub/file:(1|2)d(3|4)
	EOF
	shit -C parent/src grep --recurse-submodules -e "(1|2)d(3|4)" -- ../sub >actual &&
	test_cmp expect actual
'

test_expect_success 'grep from a subdir' '
	test_when_finished "rm -rf parent sub" &&
	shit init sub &&
	echo "(1|2)d(3|4)" >sub/file &&
	shit -C sub add file &&
	shit -C sub commit -m "add file" &&
	test_tick &&

	shit init parent &&
	mkdir parent/src &&
	echo "(1|2)d(3|4)" >parent/src/file &&
	shit -C parent add src/file &&
	test_config_global protocol.file.allow always &&
	shit -C parent submodule add ../sub src/sub &&
	shit -C parent submodule add ../sub sub &&
	shit -C parent commit -m "add files and submodules" &&
	test_tick &&

	# Verify grep from root works
	cat >expect <<-\EOF &&
	src/file:(1|2)d(3|4)
	src/sub/file:(1|2)d(3|4)
	sub/file:(1|2)d(3|4)
	EOF
	shit -C parent grep --recurse-submodules -e "(1|2)d(3|4)" >actual &&
	test_cmp expect actual &&

	# Verify grep from a subdir works
	cat >expect <<-\EOF &&
	file:(1|2)d(3|4)
	sub/file:(1|2)d(3|4)
	EOF
	shit -C parent/src grep --recurse-submodules -e "(1|2)d(3|4)" >actual &&
	test_cmp expect actual
'

test_incompatible_with_recurse_submodules ()
{
	test_expect_success "--recurse-submodules and $1 are incompatible" "
		test_must_fail shit grep -e. --recurse-submodules $1 2>actual &&
		test_grep 'not supported with --recurse-submodules' actual
	"
}

test_incompatible_with_recurse_submodules --untracked

test_expect_success 'grep --recurse-submodules --no-index ignores --recurse-submodules' '
	shit grep --recurse-submodules --no-index -e "^(.|.)[\d]" >actual &&
	cat >expect <<-\EOF &&
	a:(1|2)d(3|4)
	submodule/a:(1|2)d(3|4)
	submodule/sub/a:(1|2)d(3|4)
	EOF
	test_cmp expect actual
'

test_expect_success 'grep --recurse-submodules should pass the pattern type along' '
	# Fixed
	test_must_fail shit grep -F --recurse-submodules -e "(.|.)[\d]" &&
	test_must_fail shit -c grep.patternType=fixed grep --recurse-submodules -e "(.|.)[\d]" &&

	# Basic
	shit grep -G --recurse-submodules -e "(.|.)[\d]" >actual &&
	cat >expect <<-\EOF &&
	a:(1|2)d(3|4)
	submodule/a:(1|2)d(3|4)
	submodule/sub/a:(1|2)d(3|4)
	EOF
	test_cmp expect actual &&
	shit -c grep.patternType=basic grep --recurse-submodules -e "(.|.)[\d]" >actual &&
	test_cmp expect actual &&

	# Extended
	shit grep -E --recurse-submodules -e "(.|.)[\d]" >actual &&
	cat >expect <<-\EOF &&
	.shitmodules:[submodule "submodule"]
	.shitmodules:	path = submodule
	.shitmodules:	url = ./submodule
	a:(1|2)d(3|4)
	submodule/.shitmodules:[submodule "sub"]
	submodule/a:(1|2)d(3|4)
	submodule/sub/a:(1|2)d(3|4)
	EOF
	test_cmp expect actual &&
	shit -c grep.patternType=extended grep --recurse-submodules -e "(.|.)[\d]" >actual &&
	test_cmp expect actual &&
	shit -c grep.extendedRegexp=true grep --recurse-submodules -e "(.|.)[\d]" >actual &&
	test_cmp expect actual &&

	# Perl
	if test_have_prereq PCRE
	then
		shit grep -P --recurse-submodules -e "(.|.)[\d]" >actual &&
		cat >expect <<-\EOF &&
		a:(1|2)d(3|4)
		b/b:(3|4)
		submodule/a:(1|2)d(3|4)
		submodule/sub/a:(1|2)d(3|4)
		EOF
		test_cmp expect actual &&
		shit -c grep.patternType=perl grep --recurse-submodules -e "(.|.)[\d]" >actual &&
		test_cmp expect actual
	fi
'

test_expect_success 'grep --recurse-submodules with submodules without .shitmodules in the working tree' '
	test_when_finished "shit -C submodule checkout .shitmodules" &&
	rm submodule/.shitmodules &&
	shit grep --recurse-submodules -e "(.|.)[\d]" >actual &&
	cat >expect <<-\EOF &&
	a:(1|2)d(3|4)
	submodule/a:(1|2)d(3|4)
	submodule/sub/a:(1|2)d(3|4)
	EOF
	test_cmp expect actual
'

reset_and_clean () {
	shit reset --hard &&
	shit clean -fd &&
	shit submodule foreach --recursive 'shit reset --hard' &&
	shit submodule foreach --recursive 'shit clean -fd'
}

test_expect_success 'grep --recurse-submodules without --cached considers worktree modifications' '
	reset_and_clean &&
	echo "A modified line in submodule" >>submodule/a &&
	echo "submodule/a:A modified line in submodule" >expect &&
	shit grep --recurse-submodules "A modified line in submodule" >actual &&
	test_cmp expect actual
'

test_expect_success 'grep --recurse-submodules with --cached ignores worktree modifications' '
	reset_and_clean &&
	echo "A modified line in submodule" >>submodule/a &&
	test_must_fail shit grep --recurse-submodules --cached "A modified line in submodule" >actual 2>&1 &&
	test_must_be_empty actual
'

test_expect_failure 'grep --textconv: superproject .shitattributes does not affect submodules' '
	reset_and_clean &&
	test_config_global diff.d2x.textconv "sed -e \"s/d/x/\"" &&
	echo "a diff=d2x" >.shitattributes &&

	cat >expect <<-\EOF &&
	a:(1|2)x(3|4)
	EOF
	shit grep --textconv --recurse-submodules x >actual &&
	test_cmp expect actual
'

test_expect_failure 'grep --textconv: superproject .shitattributes (from index) does not affect submodules' '
	reset_and_clean &&
	test_config_global diff.d2x.textconv "sed -e \"s/d/x/\"" &&
	echo "a diff=d2x" >.shitattributes &&
	shit add .shitattributes &&
	rm .shitattributes &&

	cat >expect <<-\EOF &&
	a:(1|2)x(3|4)
	EOF
	shit grep --textconv --recurse-submodules x >actual &&
	test_cmp expect actual
'

test_expect_failure 'grep --textconv: superproject .shit/info/attributes does not affect submodules' '
	reset_and_clean &&
	test_config_global diff.d2x.textconv "sed -e \"s/d/x/\"" &&
	super_info="$(shit rev-parse --shit-path info)" &&
	super_attr="$super_info/attributes" &&
	test_when_finished "rm -f \"$super_attr\"" &&
	mkdir "$super_info" &&
	echo "a diff=d2x" >"$super_attr" &&

	cat >expect <<-\EOF &&
	a:(1|2)x(3|4)
	EOF
	shit grep --textconv --recurse-submodules x >actual &&
	test_cmp expect actual
'

# Note: what currently prevents this test from passing is not that the
# .shitattributes file from "./submodule" is being ignored, but that it is being
# propagated to the nested "./submodule/sub" files.
#
test_expect_failure 'grep --textconv correctly reads submodule .shitattributes' '
	reset_and_clean &&
	test_config_global diff.d2x.textconv "sed -e \"s/d/x/\"" &&
	echo "a diff=d2x" >submodule/.shitattributes &&

	cat >expect <<-\EOF &&
	submodule/a:(1|2)x(3|4)
	EOF
	shit grep --textconv --recurse-submodules x >actual &&
	test_cmp expect actual
'

test_expect_failure 'grep --textconv correctly reads submodule .shitattributes (from index)' '
	reset_and_clean &&
	test_config_global diff.d2x.textconv "sed -e \"s/d/x/\"" &&
	echo "a diff=d2x" >submodule/.shitattributes &&
	shit -C submodule add .shitattributes &&
	rm submodule/.shitattributes &&

	cat >expect <<-\EOF &&
	submodule/a:(1|2)x(3|4)
	EOF
	shit grep --textconv --recurse-submodules x >actual &&
	test_cmp expect actual
'

test_expect_failure 'grep --textconv correctly reads submodule .shit/info/attributes' '
	reset_and_clean &&
	test_config_global diff.d2x.textconv "sed -e \"s/d/x/\"" &&

	submodule_info="$(shit -C submodule rev-parse --path-format=absolute --shit-path info)" &&
	submodule_attr="$submodule_info/attributes" &&
	test_when_finished "rm -f \"$submodule_attr\"" &&
	echo "a diff=d2x" >"$submodule_attr" &&

	cat >expect <<-\EOF &&
	submodule/a:(1|2)x(3|4)
	EOF
	shit grep --textconv --recurse-submodules x >actual &&
	test_cmp expect actual
'

test_expect_failure 'grep saves textconv cache in the appropriate repository' '
	reset_and_clean &&
	test_config_global diff.d2x_cached.textconv "sed -e \"s/d/x/\"" &&
	test_config_global diff.d2x_cached.cachetextconv true &&
	echo "a diff=d2x_cached" >submodule/.shitattributes &&

	# We only read/write to the textconv cache when grepping from an OID,
	# as the working tree file might have modifications.
	shit grep --textconv --cached --recurse-submodules x &&

	super_textconv_cache="$(shit rev-parse --shit-path refs/notes/textconv/d2x_cached)" &&
	sub_textconv_cache="$(shit -C submodule rev-parse \
			--path-format=absolute --shit-path refs/notes/textconv/d2x_cached)" &&
	test_path_is_missing "$super_textconv_cache" &&
	test_path_is_file "$sub_textconv_cache"
'

test_expect_success 'grep partially-cloned submodule' '
	# Set up clean superproject and submodule for partial cloning.
	test_config_global protocol.file.allow always &&
	shit init super &&
	shit init super/sub &&
	(
		cd super &&
		test_commit --no-tag "Add file in superproject" \
			super-file "Some content for super-file" &&
		test_commit -C sub --no-tag "Add file in submodule" \
			sub-file "Some content for sub-file" &&
		shit submodule add ./sub &&
		shit commit -m "Add other as submodule sub" &&
		test_tick &&
		test_commit -C sub --no-tag --append "Update file in submodule" \
			sub-file "Some more content for sub-file" &&
		shit add sub &&
		shit commit -m "Update submodule" &&
		test_tick &&
		shit config --local uploadpack.allowfilter 1 &&
		shit config --local uploadpack.allowanysha1inwant 1 &&
		shit -C sub config --local uploadpack.allowfilter 1 &&
		shit -C sub config --local uploadpack.allowanysha1inwant 1
	) &&
	# Clone the superproject & submodule, then make sure we can lazy-fetch submodule objects.
	shit clone --filter=blob:none --also-filter-submodules \
		--recurse-submodules "file://$(pwd)/super" partial &&
	(
		cd partial &&
		cat >expect <<-\EOF &&
		HEAD^:sub/sub-file:Some content for sub-file
		HEAD^:super-file:Some content for super-file
		EOF

		shit_TRACE2_EVENT="$(pwd)/trace2.log" shit grep -e content \
			--recurse-submodules HEAD^ >actual &&
		test_cmp expect actual &&
		# Verify that we actually fetched data from the promisor remote:
		grep \"category\":\"promisor\",\"key\":\"fetch_count\",\"value\":\"1\" trace2.log
	)
'

test_expect_success 'check scope of core.useReplaceRefs' '
	shit init base &&
	shit init base/sub &&

	echo A >base/a &&
	echo B >base/b &&
	echo C >base/sub/c &&
	echo D >base/sub/d &&

	shit -C base/sub add c d &&
	shit -C base/sub commit -m "Add files" &&

	shit -C base submodule add ./sub &&
	shit -C base add a b sub &&
	shit -C base commit -m "Add files and submodule" &&

	A=$(shit -C base rev-parse HEAD:a) &&
	B=$(shit -C base rev-parse HEAD:b) &&
	C=$(shit -C base/sub rev-parse HEAD:c) &&
	D=$(shit -C base/sub rev-parse HEAD:d) &&

	shit -C base replace $A $B &&
	shit -C base/sub replace $C $D &&

	test_must_fail shit -C base grep --cached --recurse-submodules A &&
	test_must_fail shit -C base grep --cached --recurse-submodules C &&

	shit -C base config core.useReplaceRefs false &&
	shit -C base grep --recurse-submodules A &&
	test_must_fail shit -C base grep --cached --recurse-submodules C &&

	shit -C base/sub config core.useReplaceRefs false &&
	shit -C base grep --cached --recurse-submodules A &&
	shit -C base grep --cached --recurse-submodules C &&

	shit -C base config --unset core.useReplaceRefs &&
	test_must_fail shit -C base grep --cached --recurse-submodules A &&
	shit -C base grep --cached --recurse-submodules C
'

test_done
