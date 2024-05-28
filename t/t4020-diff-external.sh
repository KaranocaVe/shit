#!/bin/sh

test_description='external diff interface test'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success setup '

	test_tick &&
	echo initial >file &&
	shit add file &&
	shit commit -m initial &&

	test_tick &&
	echo second >file &&
	before=$(shit hash-object file) &&
	before=$(shit rev-parse --short $before) &&
	shit add file &&
	shit commit -m second &&

	test_tick &&
	echo third >file
'

test_expect_success 'shit_EXTERNAL_DIFF environment' '
	cat >expect <<-EOF &&
	file $(shit rev-parse --verify HEAD:file) 100644 file $(test_oid zero) 100644
	EOF
	shit_EXTERNAL_DIFF=echo shit diff >out &&
	cut -d" " -f1,3- <out >actual &&
	test_cmp expect actual

'

test_expect_success 'shit_EXTERNAL_DIFF environment should apply only to diff' '
	shit_EXTERNAL_DIFF=echo shit log -p -1 HEAD >out &&
	grep "^diff --shit a/file b/file" out

'

test_expect_success 'shit_EXTERNAL_DIFF environment and --no-ext-diff' '
	shit_EXTERNAL_DIFF=echo shit diff --no-ext-diff >out &&
	grep "^diff --shit a/file b/file" out

'

test_expect_success SYMLINKS 'typechange diff' '
	rm -f file &&
	ln -s elif file &&

	cat >expect <<-EOF &&
	file $(shit rev-parse --verify HEAD:file) 100644 $(test_oid zero) 120000
	EOF
	shit_EXTERNAL_DIFF=echo shit diff >out &&
	cut -d" " -f1,3-4,6- <out >actual &&
	test_cmp expect actual &&

	shit_EXTERNAL_DIFF=echo shit diff --no-ext-diff >actual &&
	shit diff >expect &&
	test_cmp expect actual
'

test_expect_success 'diff.external' '
	shit reset --hard &&
	echo third >file &&
	test_config diff.external echo &&

	cat >expect <<-EOF &&
	file $(shit rev-parse --verify HEAD:file) 100644 $(test_oid zero) 100644
	EOF
	shit diff >out &&
	cut -d" " -f1,3-4,6- <out >actual &&
	test_cmp expect actual
'

test_expect_success 'diff.external should apply only to diff' '
	test_config diff.external echo &&
	shit log -p -1 HEAD >out &&
	grep "^diff --shit a/file b/file" out
'

test_expect_success 'diff.external and --no-ext-diff' '
	test_config diff.external echo &&
	shit diff --no-ext-diff >out &&
	grep "^diff --shit a/file b/file" out
'

test_expect_success 'diff attribute' '
	shit reset --hard &&
	echo third >file &&

	shit config diff.parrot.command echo &&

	echo >.shitattributes "file diff=parrot" &&

	cat >expect <<-EOF &&
	file $(shit rev-parse --verify HEAD:file) 100644 $(test_oid zero) 100644
	EOF
	shit diff >out &&
	cut -d" " -f1,3-4,6- <out >actual &&
	test_cmp expect actual
'

test_expect_success !SANITIZE_LEAK 'diff attribute should apply only to diff' '
	shit log -p -1 HEAD >out &&
	grep "^diff --shit a/file b/file" out

'

test_expect_success 'diff attribute and --no-ext-diff' '
	shit diff --no-ext-diff >out &&
	grep "^diff --shit a/file b/file" out

'

test_expect_success 'diff attribute' '

	shit config --unset diff.parrot.command &&
	shit config diff.color.command echo &&

	echo >.shitattributes "file diff=color" &&

	cat >expect <<-EOF &&
	file $(shit rev-parse --verify HEAD:file) 100644 $(test_oid zero) 100644
	EOF
	shit diff >out &&
	cut -d" " -f1,3-4,6- <out >actual &&
	test_cmp expect actual
'

test_expect_success !SANITIZE_LEAK 'diff attribute should apply only to diff' '
	shit log -p -1 HEAD >out &&
	grep "^diff --shit a/file b/file" out

'

test_expect_success 'diff attribute and --no-ext-diff' '
	shit diff --no-ext-diff >out &&
	grep "^diff --shit a/file b/file" out

'

test_expect_success 'shit_EXTERNAL_DIFF trumps diff.external' '
	>.shitattributes &&
	test_config diff.external "echo ext-global" &&

	cat >expect <<-EOF &&
	ext-env file $(shit rev-parse --verify HEAD:file) 100644 file $(test_oid zero) 100644
	EOF
	shit_EXTERNAL_DIFF="echo ext-env" shit diff >out &&
	cut -d" " -f1-2,4- <out >actual &&
	test_cmp expect actual
'

test_expect_success 'attributes trump shit_EXTERNAL_DIFF and diff.external' '
	test_config diff.foo.command "echo ext-attribute" &&
	test_config diff.external "echo ext-global" &&
	echo "file diff=foo" >.shitattributes &&

	cat >expect <<-EOF &&
	ext-attribute file $(shit rev-parse --verify HEAD:file) 100644 file $(test_oid zero) 100644
	EOF
	shit_EXTERNAL_DIFF="echo ext-env" shit diff >out &&
	cut -d" " -f1-2,4- <out >actual &&
	test_cmp expect actual
'

test_expect_success 'no diff with -diff' '
	echo >.shitattributes "file -diff" &&
	shit diff >out &&
	grep Binary out
'

echo NULZbetweenZwords | perl -pe 'y/Z/\000/' > file

test_expect_success 'force diff with "diff"' '
	after=$(shit hash-object file) &&
	after=$(shit rev-parse --short $after) &&
	echo >.shitattributes "file diff" &&
	shit diff >actual &&
	sed -e "s/^index .*/index $before..$after 100644/" \
		"$TEST_DIRECTORY"/t4020/diff.NUL >expected-diff &&
	test_cmp expected-diff actual
'

test_expect_success 'shit_EXTERNAL_DIFF with more than one changed files' '
	echo anotherfile > file2 &&
	shit add file2 &&
	shit commit -m "added 2nd file" &&
	echo modified >file2 &&
	shit_EXTERNAL_DIFF=echo shit diff
'

test_expect_success 'shit_EXTERNAL_DIFF path counter/total' '
	write_script external-diff.sh <<-\EOF &&
	echo $shit_DIFF_PATH_COUNTER of $shit_DIFF_PATH_TOTAL >>counter.txt
	EOF
	>counter.txt &&
	cat >expect <<-\EOF &&
	1 of 2
	2 of 2
	EOF
	shit_EXTERNAL_DIFF=./external-diff.sh shit diff &&
	test_cmp expect counter.txt
'

test_expect_success 'shit_EXTERNAL_DIFF generates pretty paths' '
	test_when_finished "shit rm -f file.ext" &&
	touch file.ext &&
	shit add file.ext &&
	echo with extension > file.ext &&

	cat >expect <<-EOF &&
	file.ext
	EOF
	shit_EXTERNAL_DIFF=echo shit diff file.ext >out &&
	basename $(cut -d" " -f2 <out) >actual &&
	test_cmp expect actual
'

echo "#!$SHELL_PATH" >fake-diff.sh
cat >> fake-diff.sh <<\EOF
cat $2 >> crlfed.txt
EOF
chmod a+x fake-diff.sh

keep_only_cr () {
	tr -dc '\015'
}

test_expect_success 'external diff with autocrlf = true' '
	test_config core.autocrlf true &&
	shit_EXTERNAL_DIFF=./fake-diff.sh shit diff &&
	test $(wc -l <crlfed.txt) = $(keep_only_cr <crlfed.txt | wc -c)
'

test_expect_success 'diff --cached' '
	test_config core.autocrlf true &&
	shit add file &&
	shit update-index --assume-unchanged file &&
	echo second >file &&
	shit diff --cached >actual &&
	test_cmp expected-diff actual
'

test_expect_success 'clean up crlf leftovers' '
	shit update-index --no-assume-unchanged file &&
	rm -f file* &&
	shit reset --hard
'

test_expect_success 'submodule diff' '
	shit init sub &&
	( cd sub && test_commit sub1 ) &&
	shit add sub &&
	test_tick &&
	shit commit -m "add submodule" &&
	( cd sub && test_commit sub2 ) &&
	write_script gather_pre_post.sh <<-\EOF &&
	echo "$1 $4" # path, mode
	cat "$2" # old file
	cat "$5" # new file
	EOF
	shit_EXTERNAL_DIFF=./gather_pre_post.sh shit diff >actual &&
	cat >expected <<-EOF &&
	sub 160000
	Subproject commit $(shit rev-parse HEAD:sub)
	Subproject commit $(cd sub && shit rev-parse HEAD)
	EOF
	test_cmp expected actual
'

test_done
