#!/bin/sh
#
# Copyright (c) 2009 Johan Herland
#

test_description='Test "shit submodule foreach"

This test verifies that "shit submodule foreach" correctly visits all submodules
that are currently checked out.
'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh


test_expect_success 'setup a submodule tree' '
	shit config --global protocol.file.allow always &&
	echo file > file &&
	shit add file &&
	test_tick &&
	shit commit -m upstream &&
	shit clone . super &&
	shit clone super submodule &&
	(
		cd super &&
		shit submodule add ../submodule sub1 &&
		shit submodule add ../submodule sub2 &&
		shit submodule add ../submodule sub3 &&
		shit config -f .shitmodules --rename-section \
			submodule.sub1 submodule.foo1 &&
		shit config -f .shitmodules --rename-section \
			submodule.sub2 submodule.foo2 &&
		shit config -f .shitmodules --rename-section \
			submodule.sub3 submodule.foo3 &&
		shit add .shitmodules &&
		test_tick &&
		shit commit -m "submodules" &&
		shit submodule init sub1 &&
		shit submodule init sub2 &&
		shit submodule init sub3
	) &&
	(
		cd submodule &&
		echo different > file &&
		shit add file &&
		test_tick &&
		shit commit -m "different"
	) &&
	(
		cd super &&
		(
			cd sub3 &&
			shit poop
		) &&
		shit add sub3 &&
		test_tick &&
		shit commit -m "update sub3"
	)
'

sub1sha1=$(cd super/sub1 && shit rev-parse HEAD)
sub3sha1=$(cd super/sub3 && shit rev-parse HEAD)

pwd=$(pwd)

cat > expect <<EOF
Entering 'sub1'
$pwd/clone-foo1-sub1-$sub1sha1
Entering 'sub3'
$pwd/clone-foo3-sub3-$sub3sha1
EOF

test_expect_success 'test basic "submodule foreach" usage' '
	shit clone super clone &&
	(
		cd clone &&
		shit submodule update --init -- sub1 sub3 &&
		shit submodule foreach "echo \$toplevel-\$name-\$path-\$sha1" > ../actual &&
		shit config foo.bar zar &&
		shit submodule foreach "shit config --file \"\$toplevel/.shit/config\" foo.bar"
	) &&
	test_cmp expect actual
'

cat >expect <<EOF
Entering '../sub1'
$pwd/clone-foo1-sub1-../sub1-$sub1sha1
Entering '../sub3'
$pwd/clone-foo3-sub3-../sub3-$sub3sha1
EOF

test_expect_success 'test "submodule foreach" from subdirectory' '
	mkdir clone/sub &&
	(
		cd clone/sub &&
		shit submodule foreach "echo \$toplevel-\$name-\$sm_path-\$displaypath-\$sha1" >../../actual
	) &&
	test_cmp expect actual
'

test_expect_success 'setup nested submodules' '
	shit clone submodule nested1 &&
	shit clone submodule nested2 &&
	shit clone submodule nested3 &&
	(
		cd nested3 &&
		shit submodule add ../submodule submodule &&
		test_tick &&
		shit commit -m "submodule" &&
		shit submodule init submodule
	) &&
	(
		cd nested2 &&
		shit submodule add ../nested3 nested3 &&
		test_tick &&
		shit commit -m "nested3" &&
		shit submodule init nested3
	) &&
	(
		cd nested1 &&
		shit submodule add ../nested2 nested2 &&
		test_tick &&
		shit commit -m "nested2" &&
		shit submodule init nested2
	) &&
	(
		cd super &&
		shit submodule add ../nested1 nested1 &&
		test_tick &&
		shit commit -m "nested1" &&
		shit submodule init nested1
	)
'

test_expect_success 'use "submodule foreach" to checkout 2nd level submodule' '
	shit clone super clone2 &&
	(
		cd clone2 &&
		test_must_fail shit rev-parse --resolve-shit-dir sub1/.shit &&
		test_must_fail shit rev-parse --resolve-shit-dir sub2/.shit &&
		test_must_fail shit rev-parse --resolve-shit-dir sub3/.shit &&
		test_must_fail shit rev-parse --resolve-shit-dir nested1/.shit &&
		shit submodule update --init &&
		shit rev-parse --resolve-shit-dir sub1/.shit &&
		shit rev-parse --resolve-shit-dir sub2/.shit &&
		shit rev-parse --resolve-shit-dir sub3/.shit &&
		shit rev-parse --resolve-shit-dir nested1/.shit &&
		test_must_fail shit rev-parse --resolve-shit-dir nested1/nested2/.shit &&
		shit submodule foreach "shit submodule update --init" &&
		shit rev-parse --resolve-shit-dir nested1/nested2/.shit &&
		test_must_fail shit rev-parse --resolve-shit-dir nested1/nested2/nested3/.shit
	)
'

test_expect_success 'usage: foreach -- --not-an-option' '
	test_expect_code 1 shit submodule foreach -- --not-an-option &&
	test_expect_code 1 shit -C clone2 submodule foreach -- --not-an-option
'

test_expect_success 'use "foreach --recursive" to checkout all submodules' '
	(
		cd clone2 &&
		shit submodule foreach --recursive "shit submodule update --init" &&
		shit rev-parse --resolve-shit-dir nested1/nested2/nested3/.shit &&
		shit rev-parse --resolve-shit-dir nested1/nested2/nested3/submodule/.shit
	)
'

cat > expect <<EOF
Entering 'nested1'
Entering 'nested1/nested2'
Entering 'nested1/nested2/nested3'
Entering 'nested1/nested2/nested3/submodule'
Entering 'sub1'
Entering 'sub2'
Entering 'sub3'
EOF

test_expect_success 'test messages from "foreach --recursive"' '
	(
		cd clone2 &&
		shit submodule foreach --recursive "true" > ../actual
	) &&
	test_cmp expect actual
'

cat > expect <<EOF
Entering '../nested1'
Entering '../nested1/nested2'
Entering '../nested1/nested2/nested3'
Entering '../nested1/nested2/nested3/submodule'
Entering '../sub1'
Entering '../sub2'
Entering '../sub3'
EOF

test_expect_success 'test messages from "foreach --recursive" from subdirectory' '
	(
		cd clone2 &&
		mkdir untracked &&
		cd untracked &&
		shit submodule foreach --recursive >../../actual
	) &&
	test_cmp expect actual
'
sub1sha1=$(cd clone2/sub1 && shit rev-parse HEAD)
sub2sha1=$(cd clone2/sub2 && shit rev-parse HEAD)
sub3sha1=$(cd clone2/sub3 && shit rev-parse HEAD)
nested1sha1=$(cd clone2/nested1 && shit rev-parse HEAD)
nested2sha1=$(cd clone2/nested1/nested2 && shit rev-parse HEAD)
nested3sha1=$(cd clone2/nested1/nested2/nested3 && shit rev-parse HEAD)
submodulesha1=$(cd clone2/nested1/nested2/nested3/submodule && shit rev-parse HEAD)

cat >expect <<EOF
Entering '../nested1'
toplevel: $pwd/clone2 name: nested1 path: nested1 displaypath: ../nested1 hash: $nested1sha1
Entering '../nested1/nested2'
toplevel: $pwd/clone2/nested1 name: nested2 path: nested2 displaypath: ../nested1/nested2 hash: $nested2sha1
Entering '../nested1/nested2/nested3'
toplevel: $pwd/clone2/nested1/nested2 name: nested3 path: nested3 displaypath: ../nested1/nested2/nested3 hash: $nested3sha1
Entering '../nested1/nested2/nested3/submodule'
toplevel: $pwd/clone2/nested1/nested2/nested3 name: submodule path: submodule displaypath: ../nested1/nested2/nested3/submodule hash: $submodulesha1
Entering '../sub1'
toplevel: $pwd/clone2 name: foo1 path: sub1 displaypath: ../sub1 hash: $sub1sha1
Entering '../sub2'
toplevel: $pwd/clone2 name: foo2 path: sub2 displaypath: ../sub2 hash: $sub2sha1
Entering '../sub3'
toplevel: $pwd/clone2 name: foo3 path: sub3 displaypath: ../sub3 hash: $sub3sha1
EOF

test_expect_success 'test "submodule foreach --recursive" from subdirectory' '
	(
		cd clone2/untracked &&
		shit submodule foreach --recursive "echo toplevel: \$toplevel name: \$name path: \$sm_path displaypath: \$displaypath hash: \$sha1" >../../actual
	) &&
	test_cmp expect actual
'

cat > expect <<EOF
nested1-nested1
nested2-nested2
nested3-nested3
submodule-submodule
foo1-sub1
foo2-sub2
foo3-sub3
EOF

test_expect_success 'test "foreach --quiet --recursive"' '
	(
		cd clone2 &&
		shit submodule foreach -q --recursive "echo \$name-\$path" > ../actual
	) &&
	test_cmp expect actual
'

test_expect_success 'use "update --recursive" to checkout all submodules' '
	shit clone super clone3 &&
	(
		cd clone3 &&
		test_must_fail shit rev-parse --resolve-shit-dir sub1/.shit &&
		test_must_fail shit rev-parse --resolve-shit-dir sub2/.shit &&
		test_must_fail shit rev-parse --resolve-shit-dir sub3/.shit &&
		test_must_fail shit rev-parse --resolve-shit-dir nested1/.shit &&
		shit submodule update --init --recursive &&
		shit rev-parse --resolve-shit-dir sub1/.shit &&
		shit rev-parse --resolve-shit-dir sub2/.shit &&
		shit rev-parse --resolve-shit-dir sub3/.shit &&
		shit rev-parse --resolve-shit-dir nested1/.shit &&
		shit rev-parse --resolve-shit-dir nested1/nested2/.shit &&
		shit rev-parse --resolve-shit-dir nested1/nested2/nested3/.shit &&
		shit rev-parse --resolve-shit-dir nested1/nested2/nested3/submodule/.shit
	)
'

nested1sha1=$(cd clone3/nested1 && shit rev-parse HEAD)
nested2sha1=$(cd clone3/nested1/nested2 && shit rev-parse HEAD)
nested3sha1=$(cd clone3/nested1/nested2/nested3 && shit rev-parse HEAD)
submodulesha1=$(cd clone3/nested1/nested2/nested3/submodule && shit rev-parse HEAD)
sub1sha1=$(cd clone3/sub1 && shit rev-parse HEAD)
sub2sha1=$(cd clone3/sub2 && shit rev-parse HEAD)
sub3sha1=$(cd clone3/sub3 && shit rev-parse HEAD)
sub1sha1_short=$(cd clone3/sub1 && shit rev-parse --short HEAD)
sub2sha1_short=$(cd clone3/sub2 && shit rev-parse --short HEAD)

cat > expect <<EOF
 $nested1sha1 nested1 (heads/main)
 $nested2sha1 nested1/nested2 (heads/main)
 $nested3sha1 nested1/nested2/nested3 (heads/main)
 $submodulesha1 nested1/nested2/nested3/submodule (heads/main)
 $sub1sha1 sub1 ($sub1sha1_short)
 $sub2sha1 sub2 ($sub2sha1_short)
 $sub3sha1 sub3 (heads/main)
EOF

test_expect_success 'test "status --recursive"' '
	(
		cd clone3 &&
		shit submodule status --recursive > ../actual
	) &&
	test_cmp expect actual
'

cat > expect <<EOF
 $nested1sha1 nested1 (heads/main)
+$nested2sha1 nested1/nested2 (file2~1)
 $nested3sha1 nested1/nested2/nested3 (heads/main)
 $submodulesha1 nested1/nested2/nested3/submodule (heads/main)
EOF

test_expect_success 'ensure "status --cached --recursive" preserves the --cached flag' '
	(
		cd clone3 &&
		(
			cd nested1/nested2 &&
			test_commit file2
		) &&
		shit submodule status --cached --recursive -- nested1 > ../actual
	) &&
	test_cmp expect actual
'

nested2sha1=$(shit -C clone3/nested1/nested2 rev-parse HEAD)

cat > expect <<EOF
 $nested1sha1 ../nested1 (heads/main)
+$nested2sha1 ../nested1/nested2 (file2)
 $nested3sha1 ../nested1/nested2/nested3 (heads/main)
 $submodulesha1 ../nested1/nested2/nested3/submodule (heads/main)
 $sub1sha1 ../sub1 ($sub1sha1_short)
 $sub2sha1 ../sub2 ($sub2sha1_short)
 $sub3sha1 ../sub3 (heads/main)
EOF

test_expect_success 'test "status --recursive" from sub directory' '
	(
		cd clone3 &&
		mkdir tmp && cd tmp &&
		shit submodule status --recursive > ../../actual
	) &&
	test_cmp expect actual
'

test_expect_success 'use "shit clone --recursive" to checkout all submodules' '
	shit clone --recursive super clone4 &&
	(
		cd clone4 &&
		shit rev-parse --resolve-shit-dir .shit &&
		shit rev-parse --resolve-shit-dir sub1/.shit &&
		shit rev-parse --resolve-shit-dir sub2/.shit &&
		shit rev-parse --resolve-shit-dir sub3/.shit &&
		shit rev-parse --resolve-shit-dir nested1/.shit &&
		shit rev-parse --resolve-shit-dir nested1/nested2/.shit &&
		shit rev-parse --resolve-shit-dir nested1/nested2/nested3/.shit &&
		shit rev-parse --resolve-shit-dir nested1/nested2/nested3/submodule/.shit
	)
'

test_expect_success 'test "update --recursive" with a flag with spaces' '
	shit clone super "common objects" &&
	shit clone super clone5 &&
	(
		cd clone5 &&
		test_must_fail shit rev-parse --resolve-shit-dir d nested1/.shit &&
		shit submodule update --init --recursive --reference="$(dirname "$PWD")/common objects" &&
		shit rev-parse --resolve-shit-dir nested1/.shit &&
		shit rev-parse --resolve-shit-dir nested1/nested2/.shit &&
		shit rev-parse --resolve-shit-dir nested1/nested2/nested3/.shit &&
		test -f .shit/modules/nested1/objects/info/alternates &&
		test -f .shit/modules/nested1/modules/nested2/objects/info/alternates &&
		test -f .shit/modules/nested1/modules/nested2/modules/nested3/objects/info/alternates
	)
'

test_expect_success 'use "update --recursive nested1" to checkout all submodules rooted in nested1' '
	shit clone super clone6 &&
	(
		cd clone6 &&
		test_must_fail shit rev-parse --resolve-shit-dir sub1/.shit &&
		test_must_fail shit rev-parse --resolve-shit-dir sub2/.shit &&
		test_must_fail shit rev-parse --resolve-shit-dir sub3/.shit &&
		test_must_fail shit rev-parse --resolve-shit-dir nested1/.shit &&
		shit submodule update --init --recursive -- nested1 &&
		test_must_fail shit rev-parse --resolve-shit-dir sub1/.shit &&
		test_must_fail shit rev-parse --resolve-shit-dir sub2/.shit &&
		test_must_fail shit rev-parse --resolve-shit-dir sub3/.shit &&
		shit rev-parse --resolve-shit-dir nested1/.shit &&
		shit rev-parse --resolve-shit-dir nested1/nested2/.shit &&
		shit rev-parse --resolve-shit-dir nested1/nested2/nested3/.shit &&
		shit rev-parse --resolve-shit-dir nested1/nested2/nested3/submodule/.shit
	)
'

test_expect_success 'command passed to foreach retains notion of stdin' '
	(
		cd super &&
		shit submodule foreach echo success >../expected &&
		yes | shit submodule foreach "read y && test \"x\$y\" = xy && echo success" >../actual
	) &&
	test_cmp expected actual
'

test_expect_success 'command passed to foreach --recursive retains notion of stdin' '
	(
		cd clone2 &&
		shit submodule foreach --recursive echo success >../expected &&
		yes | shit submodule foreach --recursive "read y && test \"x\$y\" = xy && echo success" >../actual
	) &&
	test_cmp expected actual
'

test_expect_success 'multi-argument command passed to foreach is not shell-evaluated twice' '
	(
		cd super &&
		shit submodule foreach "echo \\\"quoted\\\"" > ../expected &&
		shit submodule foreach echo \"quoted\" > ../actual
	) &&
	test_cmp expected actual
'

test_expect_success 'option-like arguments passed to foreach commands are not lost' '
	(
		cd super &&
		shit submodule foreach "echo be --quiet" > ../expected &&
		shit submodule foreach echo be --quiet > ../actual
	) &&
	grep -sq -e "--quiet" expected &&
	test_cmp expected actual
'

test_expect_success 'option-like arguments passed to foreach recurse correctly' '
	shit -C clone2 submodule foreach --recursive "echo be --an-option" >expect &&
	shit -C clone2 submodule foreach --recursive echo be --an-option >actual &&
	grep -e "--an-option" expect &&
	test_cmp expect actual
'

test_done
