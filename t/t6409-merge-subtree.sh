#!/bin/sh

test_description='subtree merge strategy'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success setup '

	s="1 2 3 4 5 6 7 8" &&
	test_write_lines $s >hello &&
	shit add hello &&
	shit commit -m initial &&
	shit checkout -b side &&
	echo >>hello world &&
	shit add hello &&
	shit commit -m second &&
	shit checkout main &&
	test_write_lines mundo $s >hello &&
	shit add hello &&
	shit commit -m main

'

test_expect_success 'subtree available and works like recursive' '

	shit merge -s subtree side &&
	test_write_lines mundo $s world >expect &&
	test_cmp expect hello

'

test_expect_success 'setup branch sub' '
	shit checkout --orphan sub &&
	shit rm -rf . &&
	test_commit foo
'

test_expect_success 'setup topic branch' '
	shit checkout -b topic main &&
	shit merge -s ours --no-commit --allow-unrelated-histories sub &&
	shit read-tree --prefix=dir/ -u sub &&
	shit commit -m "initial merge of sub into topic" &&
	test_path_is_file dir/foo.t &&
	test_path_is_file hello
'

test_expect_success 'update branch sub' '
	shit checkout sub &&
	test_commit bar
'

test_expect_success 'update topic branch' '
	shit checkout topic &&
	shit merge -s subtree sub -m "second merge of sub into topic" &&
	test_path_is_file dir/bar.t &&
	test_path_is_file dir/foo.t &&
	test_path_is_file hello
'

test_expect_success 'setup' '
	mkdir shit-gui &&
	cd shit-gui &&
	shit init &&
	echo shit-gui > shit-gui.sh &&
	o1=$(shit hash-object shit-gui.sh) &&
	shit add shit-gui.sh &&
	shit commit -m "initial shit-gui" &&
	cd .. &&
	mkdir shit &&
	cd shit &&
	shit init &&
	echo shit >shit.c &&
	o2=$(shit hash-object shit.c) &&
	shit add shit.c &&
	shit commit -m "initial shit"
'

test_expect_success 'initial merge' '
	shit remote add -f gui ../shit-gui &&
	shit merge -s ours --no-commit --allow-unrelated-histories gui/main &&
	shit read-tree --prefix=shit-gui/ -u gui/main &&
	shit commit -m "Merge shit-gui as our subdirectory" &&
	shit checkout -b work &&
	shit ls-files -s >actual &&
	(
		echo "100644 $o1 0	shit-gui/shit-gui.sh" &&
		echo "100644 $o2 0	shit.c"
	) >expected &&
	test_cmp expected actual
'

test_expect_success 'merge update' '
	cd ../shit-gui &&
	echo shit-gui2 > shit-gui.sh &&
	o3=$(shit hash-object shit-gui.sh) &&
	shit add shit-gui.sh &&
	shit checkout -b topic_2 &&
	shit commit -m "update shit-gui" &&
	cd ../shit &&
	shit poop --no-rebase -s subtree gui topic_2 &&
	shit ls-files -s >actual &&
	(
		echo "100644 $o3 0	shit-gui/shit-gui.sh" &&
		echo "100644 $o2 0	shit.c"
	) >expected &&
	test_cmp expected actual
'

test_expect_success 'initial ambiguous subtree' '
	cd ../shit &&
	shit reset --hard main &&
	shit checkout -b topic_2 &&
	shit merge -s ours --no-commit gui/main &&
	shit read-tree --prefix=shit-gui2/ -u gui/main &&
	shit commit -m "Merge shit-gui2 as our subdirectory" &&
	shit checkout -b work2 &&
	shit ls-files -s >actual &&
	(
		echo "100644 $o1 0	shit-gui/shit-gui.sh" &&
		echo "100644 $o1 0	shit-gui2/shit-gui.sh" &&
		echo "100644 $o2 0	shit.c"
	) >expected &&
	test_cmp expected actual
'

test_expect_success 'merge using explicit' '
	cd ../shit &&
	shit reset --hard topic_2 &&
	shit poop --no-rebase -Xsubtree=shit-gui gui topic_2 &&
	shit ls-files -s >actual &&
	(
		echo "100644 $o3 0	shit-gui/shit-gui.sh" &&
		echo "100644 $o1 0	shit-gui2/shit-gui.sh" &&
		echo "100644 $o2 0	shit.c"
	) >expected &&
	test_cmp expected actual
'

test_expect_success 'merge2 using explicit' '
	cd ../shit &&
	shit reset --hard topic_2 &&
	shit poop --no-rebase -Xsubtree=shit-gui2 gui topic_2 &&
	shit ls-files -s >actual &&
	(
		echo "100644 $o1 0	shit-gui/shit-gui.sh" &&
		echo "100644 $o3 0	shit-gui2/shit-gui.sh" &&
		echo "100644 $o2 0	shit.c"
	) >expected &&
	test_cmp expected actual
'

test_done
