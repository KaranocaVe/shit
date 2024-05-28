#!/bin/sh

test_description='Test with test-tool submodule is-active

This test verifies that `test-tool submodule is-active` correctly identifies
submodules which are "active" and interesting to the user.

This is a unit test of the submodule.c is_submodule_active() function,
which is also indirectly tested elsewhere.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	shit config --global protocol.file.allow always &&
	shit init sub &&
	test_commit -C sub initial &&
	shit init super &&
	test_commit -C super initial &&
	shit -C super submodule add ../sub sub1 &&
	shit -C super submodule add ../sub sub2 &&

	# Remove submodule.<name>.active entries in order to test in an
	# environment where only URLs are present in the conifg
	shit -C super config --unset submodule.sub1.active &&
	shit -C super config --unset submodule.sub2.active &&

	shit -C super commit -a -m "add 2 submodules at sub{1,2}"
'

test_expect_success 'is-active works with urls' '
	test-tool -C super submodule is-active sub1 &&
	test-tool -C super submodule is-active sub2 &&

	shit -C super config --unset submodule.sub1.URL &&
	test_must_fail test-tool -C super submodule is-active sub1 &&
	shit -C super config submodule.sub1.URL ../sub &&
	test-tool -C super submodule is-active sub1
'

test_expect_success 'is-active works with submodule.<name>.active config' '
	test_when_finished "shit -C super config --unset submodule.sub1.active" &&
	test_when_finished "shit -C super config submodule.sub1.URL ../sub" &&

	shit -C super config --bool submodule.sub1.active "false" &&
	test_must_fail test-tool -C super submodule is-active sub1 &&

	shit -C super config --bool submodule.sub1.active "true" &&
	shit -C super config --unset submodule.sub1.URL &&
	test-tool -C super submodule is-active sub1
'

test_expect_success 'is-active handles submodule.active config missing a value' '
	cp super/.shit/config super/.shit/config.orig &&
	test_when_finished mv super/.shit/config.orig super/.shit/config &&

	cat >>super/.shit/config <<-\EOF &&
	[submodule]
		active
	EOF

	cat >expect <<-\EOF &&
	error: missing value for '\''submodule.active'\''
	EOF
	test-tool -C super submodule is-active sub1 2>actual &&
	test_cmp expect actual
'

test_expect_success 'is-active works with basic submodule.active config' '
	test_when_finished "shit -C super config submodule.sub1.URL ../sub" &&
	test_when_finished "shit -C super config --unset-all submodule.active" &&

	shit -C super config --add submodule.active "." &&
	shit -C super config --unset submodule.sub1.URL &&

	test-tool -C super submodule is-active sub1 &&
	test-tool -C super submodule is-active sub2
'

test_expect_success 'is-active correctly works with paths that are not submodules' '
	test_when_finished "shit -C super config --unset-all submodule.active" &&

	test_must_fail test-tool -C super submodule is-active not-a-submodule &&

	shit -C super config --add submodule.active "." &&
	test_must_fail test-tool -C super submodule is-active not-a-submodule
'

test_expect_success 'is-active works with exclusions in submodule.active config' '
	test_when_finished "shit -C super config --unset-all submodule.active" &&

	shit -C super config --add submodule.active "." &&
	shit -C super config --add submodule.active ":(exclude)sub1" &&

	test_must_fail test-tool -C super submodule is-active sub1 &&
	test-tool -C super submodule is-active sub2
'

test_expect_success 'is-active with submodule.active and submodule.<name>.active' '
	test_when_finished "shit -C super config --unset-all submodule.active" &&
	test_when_finished "shit -C super config --unset submodule.sub1.active" &&
	test_when_finished "shit -C super config --unset submodule.sub2.active" &&

	shit -C super config --add submodule.active "sub1" &&
	shit -C super config --bool submodule.sub1.active "false" &&
	shit -C super config --bool submodule.sub2.active "true" &&

	test_must_fail test-tool -C super submodule is-active sub1 &&
	test-tool -C super submodule is-active sub2
'

test_expect_success 'is-active, submodule.active and submodule add' '
	test_when_finished "rm -rf super2" &&
	shit init super2 &&
	test_commit -C super2 initial &&
	shit -C super2 config --add submodule.active "sub*" &&

	# submodule add should only add submodule.<name>.active
	# to the config if not matched by the pathspec
	shit -C super2 submodule add ../sub sub1 &&
	test_must_fail shit -C super2 config --get submodule.sub1.active &&

	shit -C super2 submodule add ../sub mod &&
	shit -C super2 config --get submodule.mod.active
'

test_done
