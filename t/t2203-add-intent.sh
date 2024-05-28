#!/bin/sh

test_description='Intent to add'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'intent to add' '
	test_commit 1 &&
	shit rm 1.t &&
	echo hello >1.t &&
	echo hello >file &&
	echo hello >elif &&
	shit add -N file &&
	shit add elif &&
	shit add -N 1.t
'

test_expect_success 'shit status' '
	shit status --porcelain | grep -v actual >actual &&
	cat >expect <<-\EOF &&
	DA 1.t
	A  elif
	 A file
	EOF
	test_cmp expect actual
'

test_expect_success 'shit status with porcelain v2' '
	shit status --porcelain=v2 | grep -v "^?" >actual &&
	nam1=$(echo 1 | shit hash-object --stdin) &&
	nam2=$(shit hash-object elif) &&
	cat >expect <<-EOF &&
	1 DA N... 100644 000000 100644 $nam1 $ZERO_OID 1.t
	1 A. N... 000000 100644 100644 $ZERO_OID $nam2 elif
	1 .A N... 000000 000000 100644 $ZERO_OID $ZERO_OID file
	EOF
	test_cmp expect actual
'

test_expect_success 'check result of "add -N"' '
	shit ls-files -s file >actual &&
	empty=$(shit hash-object --stdin </dev/null) &&
	echo "100644 $empty 0	file" >expect &&
	test_cmp expect actual
'

test_expect_success 'intent to add is just an ordinary empty blob' '
	shit add -u &&
	shit ls-files -s file >actual &&
	shit ls-files -s elif | sed -e "s/elif/file/" >expect &&
	test_cmp expect actual
'

test_expect_success 'intent to add does not clobber existing paths' '
	shit add -N file elif &&
	empty=$(shit hash-object --stdin </dev/null) &&
	shit ls-files -s >actual &&
	! grep "$empty" actual
'

test_expect_success 'i-t-a entry is simply ignored' '
	test_tick &&
	shit commit -a -m initial &&
	shit reset --hard &&

	echo xyzzy >rezrov &&
	echo frotz >nitfol &&
	shit add rezrov &&
	shit add -N nitfol &&
	shit commit -m second &&
	test $(shit ls-tree HEAD -- nitfol | wc -l) = 0 &&
	test $(shit diff --name-only HEAD -- nitfol | wc -l) = 1 &&
	test $(shit diff --name-only -- nitfol | wc -l) = 1
'

test_expect_success 'can commit with an unrelated i-t-a entry in index' '
	shit reset --hard &&
	echo bozbar >rezrov &&
	echo frotz >nitfol &&
	shit add rezrov &&
	shit add -N nitfol &&
	shit commit -m partial rezrov
'

test_expect_success 'can "commit -a" with an i-t-a entry' '
	shit reset --hard &&
	: >nitfol &&
	shit add -N nitfol &&
	shit commit -a -m all
'

test_expect_success 'cache-tree invalidates i-t-a paths' '
	shit reset --hard &&
	mkdir dir &&
	: >dir/foo &&
	shit add dir/foo &&
	shit commit -m foo &&

	: >dir/bar &&
	shit add -N dir/bar &&
	shit diff --name-only >actual &&
	echo dir/bar >expect &&
	test_cmp expect actual &&

	shit write-tree >/dev/null &&

	shit diff --name-only >actual &&
	echo dir/bar >expect &&
	test_cmp expect actual
'

test_expect_success 'cache-tree does not ignore dir that has i-t-a entries' '
	shit init ita-in-dir &&
	(
		cd ita-in-dir &&
		mkdir 2 &&
		for f in 1 2/1 2/2 3
		do
			echo "$f" >"$f" || return 1
		done &&
		shit add 1 2/2 3 &&
		shit add -N 2/1 &&
		shit commit -m committed &&
		shit ls-tree -r HEAD >actual &&
		grep 2/2 actual
	)
'

test_expect_success 'cache-tree does skip dir that becomes empty' '
	rm -fr ita-in-dir &&
	shit init ita-in-dir &&
	(
		cd ita-in-dir &&
		mkdir -p 1/2/3 &&
		echo 4 >1/2/3/4 &&
		shit add -N 1/2/3/4 &&
		shit write-tree >actual &&
		echo $EMPTY_TREE >expected &&
		test_cmp expected actual
	)
'

test_expect_success 'commit: ita entries ignored in empty initial commit check' '
	shit init empty-initial-commit &&
	(
		cd empty-initial-commit &&
		: >one &&
		shit add -N one &&
		test_must_fail shit commit -m nothing-new-here
	)
'

test_expect_success 'commit: ita entries ignored in empty commit check' '
	shit init empty-subsequent-commit &&
	(
		cd empty-subsequent-commit &&
		test_commit one &&
		: >two &&
		shit add -N two &&
		test_must_fail shit commit -m nothing-new-here
	)
'

test_expect_success 'rename detection finds the right names' '
	shit init rename-detection &&
	(
		cd rename-detection &&
		echo contents >first &&
		shit add first &&
		shit commit -m first &&
		mv first third &&
		shit add -N third &&

		shit status | grep -v "^?" >actual.1 &&
		test_grep "renamed: *first -> third" actual.1 &&

		shit status --porcelain | grep -v "^?" >actual.2 &&
		cat >expected.2 <<-\EOF &&
		 R first -> third
		EOF
		test_cmp expected.2 actual.2 &&

		hash=$(shit hash-object third) &&
		shit status --porcelain=v2 | grep -v "^?" >actual.3 &&
		cat >expected.3 <<-EOF &&
		2 .R N... 100644 100644 100644 $hash $hash R100 third	first
		EOF
		test_cmp expected.3 actual.3 &&

		shit diff --stat >actual.4 &&
		cat >expected.4 <<-EOF &&
		 first => third | 0
		 1 file changed, 0 insertions(+), 0 deletions(-)
		EOF
		test_cmp expected.4 actual.4 &&

		shit diff --cached --stat >actual.5 &&
		test_must_be_empty actual.5

	)
'

test_expect_success 'double rename detection in status' '
	shit init rename-detection-2 &&
	(
		cd rename-detection-2 &&
		echo contents >first &&
		shit add first &&
		shit commit -m first &&
		shit mv first second &&
		mv second third &&
		shit add -N third &&

		shit status | grep -v "^?" >actual.1 &&
		test_grep "renamed: *first -> second" actual.1 &&
		test_grep "renamed: *second -> third" actual.1 &&

		shit status --porcelain | grep -v "^?" >actual.2 &&
		cat >expected.2 <<-\EOF &&
		R  first -> second
		 R second -> third
		EOF
		test_cmp expected.2 actual.2 &&

		hash=$(shit hash-object third) &&
		shit status --porcelain=v2 | grep -v "^?" >actual.3 &&
		cat >expected.3 <<-EOF &&
		2 R. N... 100644 100644 100644 $hash $hash R100 second	first
		2 .R N... 100644 100644 100644 $hash $hash R100 third	second
		EOF
		test_cmp expected.3 actual.3
	)
'

test_expect_success 'i-t-a files shown as new for "diff", "diff-files"; not-new for "diff --cached"' '
	shit reset --hard &&
	: >empty &&
	content="foo" &&
	echo "$content" >not-empty &&

	hash_e=$(shit hash-object empty) &&
	hash_n=$(shit hash-object not-empty) &&

	cat >expect.diff_p <<-EOF &&
	diff --shit a/empty b/empty
	new file mode 100644
	index 0000000..$(shit rev-parse --short $hash_e)
	diff --shit a/not-empty b/not-empty
	new file mode 100644
	index 0000000..$(shit rev-parse --short $hash_n)
	--- /dev/null
	+++ b/not-empty
	@@ -0,0 +1 @@
	+$content
	EOF
	cat >expect.diff_s <<-EOF &&
	 create mode 100644 empty
	 create mode 100644 not-empty
	EOF
	cat >expect.diff_a <<-EOF &&
	:000000 100644 0000000 0000000 A$(printf "\t")empty
	:000000 100644 0000000 0000000 A$(printf "\t")not-empty
	EOF

	shit add -N empty not-empty &&

	shit diff >actual &&
	test_cmp expect.diff_p actual &&

	shit diff --summary >actual &&
	test_cmp expect.diff_s actual &&

	shit diff-files -p >actual &&
	test_cmp expect.diff_p actual &&

	shit diff-files --abbrev >actual &&
	test_cmp expect.diff_a actual &&

	shit diff --cached >actual &&
	test_must_be_empty actual
'

test_expect_success '"diff HEAD" includes ita as new files' '
	shit reset --hard &&
	echo new >new-ita &&
	oid=$(shit hash-object new-ita) &&
	oid=$(shit rev-parse --short $oid) &&
	shit add -N new-ita &&
	shit diff HEAD >actual &&
	cat >expected <<-EOF &&
	diff --shit a/new-ita b/new-ita
	new file mode 100644
	index 0000000..$oid
	--- /dev/null
	+++ b/new-ita
	@@ -0,0 +1 @@
	+new
	EOF
	test_cmp expected actual
'

test_expect_success 'apply --intent-to-add' '
	shit reset --hard &&
	echo new >new-ita &&
	shit add -N new-ita &&
	shit diff >expected &&
	grep "new file" expected &&
	shit reset --hard &&
	shit apply --intent-to-add expected &&
	shit diff >actual &&
	test_cmp expected actual
'

test_done
