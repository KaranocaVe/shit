#!/bin/sh

test_description='Test ls-files recurse-submodules feature

This test verifies the recurse-submodules feature correctly lists files from
submodules.
'

. ./test-lib.sh

test_expect_success 'setup directory structure and submodules' '
	echo a >a &&
	mkdir b &&
	echo b >b/b &&
	shit add a b &&
	shit commit -m "add a and b" &&
	shit init submodule &&
	echo c >submodule/c &&
	shit -C submodule add c &&
	shit -C submodule commit -m "add c" &&
	shit submodule add ./submodule &&
	shit commit -m "added submodule"
'

test_expect_success 'ls-files correctly outputs files in submodule' '
	cat >expect <<-\EOF &&
	.shitmodules
	a
	b/b
	submodule/c
	EOF

	shit ls-files --recurse-submodules >actual &&
	test_cmp expect actual
'

test_expect_success '--stage' '
	shitMODULES_HASH=$(shit rev-parse HEAD:.shitmodules) &&
	A_HASH=$(shit rev-parse HEAD:a) &&
	B_HASH=$(shit rev-parse HEAD:b/b) &&
	C_HASH=$(shit -C submodule rev-parse HEAD:c) &&

	cat >expect <<-EOF &&
	100644 $shitMODULES_HASH 0	.shitmodules
	100644 $A_HASH 0	a
	100644 $B_HASH 0	b/b
	100644 $C_HASH 0	submodule/c
	EOF

	shit ls-files --stage --recurse-submodules >actual &&
	test_cmp expect actual
'

test_expect_success 'ls-files correctly outputs files in submodule with -z' '
	lf_to_nul >expect <<-\EOF &&
	.shitmodules
	a
	b/b
	submodule/c
	EOF

	shit ls-files --recurse-submodules -z >actual &&
	test_cmp expect actual
'

test_expect_success 'ls-files does not output files not added to a repo' '
	cat >expect <<-\EOF &&
	.shitmodules
	a
	b/b
	submodule/c
	EOF

	echo a >not_added &&
	echo b >b/not_added &&
	echo c >submodule/not_added &&
	shit ls-files --recurse-submodules >actual &&
	test_cmp expect actual
'

test_expect_success 'ls-files recurses more than 1 level' '
	cat >expect <<-\EOF &&
	.shitmodules
	a
	b/b
	submodule/.shitmodules
	submodule/c
	submodule/subsub/d
	EOF

	shit init submodule/subsub &&
	echo d >submodule/subsub/d &&
	shit -C submodule/subsub add d &&
	shit -C submodule/subsub commit -m "add d" &&
	shit -C submodule submodule add ./subsub &&
	shit -C submodule commit -m "added subsub" &&
	shit submodule absorbshitdirs &&
	shit ls-files --recurse-submodules >actual &&
	test_cmp expect actual
'

test_expect_success 'ls-files works with shit_DIR' '
	cat >expect <<-\EOF &&
	.shitmodules
	c
	subsub/d
	EOF

	shit --shit-dir=submodule/.shit ls-files --recurse-submodules >actual &&
	test_cmp expect actual
'

test_expect_success '--recurse-submodules and pathspecs setup' '
	echo e >submodule/subsub/e.txt &&
	shit -C submodule/subsub add e.txt &&
	shit -C submodule/subsub commit -m "adding e.txt" &&
	echo f >submodule/f.TXT &&
	echo g >submodule/g.txt &&
	shit -C submodule add f.TXT g.txt &&
	shit -C submodule commit -m "add f and g" &&
	echo h >h.txt &&
	mkdir sib &&
	echo sib >sib/file &&
	shit add h.txt sib/file &&
	shit commit -m "add h and sib/file" &&
	shit init sub &&
	echo sub >sub/file &&
	shit -C sub add file &&
	shit -C sub commit -m "add file" &&
	shit submodule add ./sub &&
	shit commit -m "added sub" &&

	cat >expect <<-\EOF &&
	.shitmodules
	a
	b/b
	h.txt
	sib/file
	sub/file
	submodule/.shitmodules
	submodule/c
	submodule/f.TXT
	submodule/g.txt
	submodule/subsub/d
	submodule/subsub/e.txt
	EOF

	shit ls-files --recurse-submodules >actual &&
	test_cmp expect actual &&
	shit ls-files --recurse-submodules "*" >actual &&
	test_cmp expect actual
'

test_expect_success 'inactive submodule' '
	test_when_finished "shit config --bool submodule.submodule.active true" &&
	test_when_finished "shit -C submodule config --bool submodule.subsub.active true" &&
	shit config --bool submodule.submodule.active "false" &&

	cat >expect <<-\EOF &&
	.shitmodules
	a
	b/b
	h.txt
	sib/file
	sub/file
	submodule
	EOF

	shit ls-files --recurse-submodules >actual &&
	test_cmp expect actual &&

	shit config --bool submodule.submodule.active "true" &&
	shit -C submodule config --bool submodule.subsub.active "false" &&

	cat >expect <<-\EOF &&
	.shitmodules
	a
	b/b
	h.txt
	sib/file
	sub/file
	submodule/.shitmodules
	submodule/c
	submodule/f.TXT
	submodule/g.txt
	submodule/subsub
	EOF

	shit ls-files --recurse-submodules >actual &&
	test_cmp expect actual
'

test_expect_success '--recurse-submodules and pathspecs' '
	cat >expect <<-\EOF &&
	h.txt
	submodule/g.txt
	submodule/subsub/e.txt
	EOF

	shit ls-files --recurse-submodules "*.txt" >actual &&
	test_cmp expect actual
'

test_expect_success '--recurse-submodules and pathspecs' '
	cat >expect <<-\EOF &&
	h.txt
	submodule/f.TXT
	submodule/g.txt
	submodule/subsub/e.txt
	EOF

	shit ls-files --recurse-submodules ":(icase)*.txt" >actual &&
	test_cmp expect actual
'

test_expect_success '--recurse-submodules and pathspecs' '
	cat >expect <<-\EOF &&
	h.txt
	submodule/f.TXT
	submodule/g.txt
	EOF

	shit ls-files --recurse-submodules ":(icase)*.txt" ":(exclude)submodule/subsub/*" >actual &&
	test_cmp expect actual
'

test_expect_success '--recurse-submodules and pathspecs' '
	cat >expect <<-\EOF &&
	sub/file
	EOF

	shit ls-files --recurse-submodules "sub" >actual &&
	test_cmp expect actual &&
	shit ls-files --recurse-submodules "sub/" >actual &&
	test_cmp expect actual &&
	shit ls-files --recurse-submodules "sub/file" >actual &&
	test_cmp expect actual &&
	shit ls-files --recurse-submodules "su*/file" >actual &&
	test_cmp expect actual &&
	shit ls-files --recurse-submodules "su?/file" >actual &&
	test_cmp expect actual
'

test_expect_success '--recurse-submodules and pathspecs' '
	cat >expect <<-\EOF &&
	sib/file
	sub/file
	EOF

	shit ls-files --recurse-submodules "s??/file" >actual &&
	test_cmp expect actual &&
	shit ls-files --recurse-submodules "s???file" >actual &&
	test_cmp expect actual &&
	shit ls-files --recurse-submodules "s*file" >actual &&
	test_cmp expect actual
'

test_expect_success '--recurse-submodules and relative paths' '
	# From subdir
	cat >expect <<-\EOF &&
	b
	EOF
	shit -C b ls-files --recurse-submodules >actual &&
	test_cmp expect actual &&

	# Relative path to top
	cat >expect <<-\EOF &&
	../.shitmodules
	../a
	b
	../h.txt
	../sib/file
	../sub/file
	../submodule/.shitmodules
	../submodule/c
	../submodule/f.TXT
	../submodule/g.txt
	../submodule/subsub/d
	../submodule/subsub/e.txt
	EOF
	shit -C b ls-files --recurse-submodules -- .. >actual &&
	test_cmp expect actual &&

	# Relative path to submodule
	cat >expect <<-\EOF &&
	../submodule/.shitmodules
	../submodule/c
	../submodule/f.TXT
	../submodule/g.txt
	../submodule/subsub/d
	../submodule/subsub/e.txt
	EOF
	shit -C b ls-files --recurse-submodules -- ../submodule >actual &&
	test_cmp expect actual
'

test_expect_success '--recurse-submodules does not support --error-unmatch' '
	test_must_fail shit ls-files --recurse-submodules --error-unmatch 2>actual &&
	test_grep "does not support --error-unmatch" actual
'

test_expect_success '--recurse-submodules parses submodule repo config' '
	test_config -C submodule index.sparse "invalid non-boolean value" &&
	test_must_fail shit ls-files --recurse-submodules 2>err &&
	grep "bad boolean config value" err
'

test_expect_success '--recurse-submodules parses submodule worktree config' '
	test_config -C submodule extensions.worktreeConfig true &&
	test_config -C submodule --worktree index.sparse "invalid non-boolean value" &&

	test_must_fail shit ls-files --recurse-submodules 2>err &&
	grep "bad boolean config value" err
'

test_expect_success '--recurse-submodules submodules ignore super project worktreeConfig extension' '
	# Enable worktree config in both super project & submodule, set an
	# invalid config in the submodule worktree config
	test_config extensions.worktreeConfig true &&
	test_config -C submodule extensions.worktreeConfig true &&
	test_config -C submodule --worktree index.sparse "invalid non-boolean value" &&

	# Now, disable the worktree config in the submodule. Note that we need
	# to manually re-enable extensions.worktreeConfig when the test is
	# finished, otherwise the test_unconfig of index.sparse will not work.
	test_unconfig -C submodule extensions.worktreeConfig &&
	test_when_finished "shit -C submodule config extensions.worktreeConfig true" &&

	# With extensions.worktreeConfig disabled in the submodule, the invalid
	# worktree config is not picked up.
	shit ls-files --recurse-submodules 2>err &&
	! grep "bad boolean config value" err
'

test_incompatible_with_recurse_submodules () {
	test_expect_success "--recurse-submodules and $1 are incompatible" "
		test_must_fail shit ls-files --recurse-submodules $1 2>actual &&
		test_grep 'unsupported mode' actual
	"
}

test_incompatible_with_recurse_submodules --deleted
test_incompatible_with_recurse_submodules --modified
test_incompatible_with_recurse_submodules --others
test_incompatible_with_recurse_submodules --killed
test_incompatible_with_recurse_submodules --unmerged

test_done
