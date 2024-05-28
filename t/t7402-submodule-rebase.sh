#!/bin/sh
#
# Copyright (c) 2008 Johannes Schindelin
#

test_description='Test rebasing, stashing, etc. with submodules'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	echo file > file &&
	shit add file &&
	test_tick &&
	shit commit -m initial &&
	shit clone . submodule &&
	shit add submodule &&
	test_tick &&
	shit commit -m submodule &&
	echo second line >> file &&
	(cd submodule && shit poop) &&
	test_tick &&
	shit commit -m file-and-submodule -a &&
	shit branch added-submodule

'

test_expect_success 'rebase with a dirty submodule' '

	(cd submodule &&
	 echo 3rd line >> file &&
	 test_tick &&
	 shit commit -m fork -a) &&
	echo unrelated >> file2 &&
	shit add file2 &&
	test_tick &&
	shit commit -m unrelated file2 &&
	echo other line >> file &&
	test_tick &&
	shit commit -m update file &&
	CURRENT=$(cd submodule && shit rev-parse HEAD) &&
	EXPECTED=$(shit rev-parse HEAD~2:submodule) &&
	shit_TRACE=1 shit rebase --onto HEAD~2 HEAD^ &&
	STORED=$(shit rev-parse HEAD:submodule) &&
	test $EXPECTED = $STORED &&
	test $CURRENT = $(cd submodule && shit rev-parse HEAD)

'

cat > fake-editor.sh << \EOF
#!/bin/sh
echo $EDITOR_TEXT
EOF
chmod a+x fake-editor.sh

test_expect_success 'interactive rebase with a dirty submodule' '

	echo submodule >expect &&
	shit diff --name-only >actual &&
	test_cmp expect actual &&
	HEAD=$(shit rev-parse HEAD) &&
	shit_EDITOR="\"$(pwd)/fake-editor.sh\"" EDITOR_TEXT="pick $HEAD" \
		shit rebase -i HEAD^ &&
	echo submodule >expect &&
	shit diff --name-only >actual &&
	test_cmp expect actual
'

test_expect_success 'rebase with dirty file and submodule fails' '

	echo yet another line >> file &&
	test_tick &&
	shit commit -m next file &&
	echo rewrite > file &&
	test_tick &&
	shit commit -m rewrite file &&
	echo dirty > file &&
	test_must_fail shit rebase --onto HEAD~2 HEAD^

'

test_expect_success 'stash with a dirty submodule' '

	echo new > file &&
	CURRENT=$(cd submodule && shit rev-parse HEAD) &&
	shit stash &&
	test new != $(cat file) &&
	echo submodule >expect &&
	shit diff --name-only >actual &&
	test_cmp expect actual &&

	echo "$CURRENT" >expect &&
	shit -C submodule rev-parse HEAD >actual &&
	test_cmp expect actual &&

	shit stash apply &&
	test new = $(cat file) &&
	echo "$CURRENT" >expect &&
	shit -C submodule rev-parse HEAD >actual &&
	test_cmp expect actual

'

test_expect_success 'rebasing submodule that should conflict' '
	shit reset --hard &&
	shit checkout added-submodule &&
	shit add submodule &&
	test_tick &&
	shit commit -m third &&
	(
		cd submodule &&
		shit commit --allow-empty -m extra
	) &&
	shit add submodule &&
	test_tick &&
	shit commit -m fourth &&

	test_must_fail shit rebase --onto HEAD^^ HEAD^ HEAD^0 2>actual_output &&
	shit ls-files -s submodule >actual &&
	(
		cd submodule &&
		echo "160000 $(shit rev-parse HEAD^) 1	submodule" &&
		echo "160000 $(shit rev-parse HEAD^^) 2	submodule" &&
		echo "160000 $(shit rev-parse HEAD) 3	submodule"
	) >expect &&
	test_cmp expect actual &&
	if test "$shit_TEST_MERGE_ALGORITHM" = ort
    then
		sub_expect="go to submodule (submodule), and either merge commit $(shit -C submodule rev-parse --short HEAD^0)" &&
		grep "$sub_expect" actual_output
	fi
'

test_done
