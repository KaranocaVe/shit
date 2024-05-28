#!/bin/sh

test_description='shit ls-files --format test'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

for flag in -s -o -k -t --resolve-undo --deduplicate --eol
do
	test_expect_success "usage: --format is incompatible with $flag" '
		test_expect_code 129 shit ls-files --format="%(objectname)" $flag
	'
done

test_expect_success 'setup' '
	printf "LINEONE\nLINETWO\nLINETHREE\n" >o1.txt &&
	printf "LINEONE\r\nLINETWO\r\nLINETHREE\r\n" >o2.txt &&
	printf "LINEONE\r\nLINETWO\nLINETHREE\n" >o3.txt &&
	shit add o?.txt &&
	oid=$(shit hash-object o1.txt) &&
	shit update-index --add --cacheinfo 120000 $oid o4.txt &&
	shit update-index --add --cacheinfo 160000 $oid o5.txt &&
	shit update-index --add --cacheinfo 100755 $oid o6.txt &&
	shit commit -m base
'

test_expect_success 'shit ls-files --format objectmode v.s. -s' '
	shit ls-files -s >files &&
	cut -d" " -f1 files >expect &&
	shit ls-files --format="%(objectmode)" >actual &&
	test_cmp expect actual
'

test_expect_success 'shit ls-files --format objectname v.s. -s' '
	shit ls-files -s >files &&
	cut -d" " -f2 files >expect &&
	shit ls-files --format="%(objectname)" >actual &&
	test_cmp expect actual
'

test_expect_success 'shit ls-files --format objecttype' '
	shit ls-files --format="%(objectname)" o1.txt o4.txt o6.txt >objectname &&
	shit cat-file --batch-check="%(objecttype)" >expect <objectname &&
	shit ls-files --format="%(objecttype)" o1.txt o4.txt o6.txt >actual &&
	test_cmp expect actual
'

test_expect_success 'shit ls-files --format objectsize' '
	cat>expect <<-\EOF &&
26
29
27
26
-
26
	EOF
	shit ls-files --format="%(objectsize)" >actual &&

	test_cmp expect actual
'

test_expect_success 'shit ls-files --format objectsize:padded' '
	cat>expect <<-\EOF &&
     26
     29
     27
     26
      -
     26
	EOF
	shit ls-files --format="%(objectsize:padded)" >actual &&

	test_cmp expect actual
'

test_expect_success 'shit ls-files --format v.s. --eol' '
	shit ls-files --eol >tmp &&
	sed -e "s/	/ /g" -e "s/  */ /g" tmp >expect 2>err &&
	test_must_be_empty err &&
	shit ls-files --format="i/%(eolinfo:index) w/%(eolinfo:worktree) attr/%(eolattr) %(path)" >actual 2>err &&
	test_must_be_empty err &&
	test_cmp expect actual
'

test_expect_success 'shit ls-files --format path v.s. -s' '
	shit ls-files -s >files &&
	cut -f2 files >expect &&
	shit ls-files --format="%(path)" >actual &&
	test_cmp expect actual
'

test_expect_success 'shit ls-files --format with relative path' '
	cat >expect <<-\EOF &&
	../o1.txt
	../o2.txt
	../o3.txt
	../o4.txt
	../o5.txt
	../o6.txt
	EOF
	mkdir sub &&
	cd sub &&
	shit ls-files --format="%(path)" ":/" >../actual &&
	cd .. &&
	test_cmp expect actual
'

test_expect_success 'shit ls-files --format with -m' '
	echo change >o1.txt &&
	cat >expect <<-\EOF &&
	o1.txt
	o4.txt
	o5.txt
	o6.txt
	EOF
	shit ls-files --format="%(path)" -m >actual &&
	test_cmp expect actual
'

test_expect_success 'shit ls-files --format with -d' '
	echo o7 >o7.txt &&
	shit add o7.txt &&
	rm o7.txt &&
	cat >expect <<-\EOF &&
	o4.txt
	o5.txt
	o6.txt
	o7.txt
	EOF
	shit ls-files --format="%(path)" -d >actual &&
	test_cmp expect actual
'

test_expect_success 'shit ls-files --format v.s -s' '
	shit ls-files --stage >expect &&
	shit ls-files --format="%(objectmode) %(objectname) %(stage)%x09%(path)" >actual &&
	test_cmp expect actual
'

test_expect_success 'shit ls-files --format with --debug' '
	shit ls-files --debug >expect &&
	shit ls-files --format="%(path)" --debug >actual &&
	test_cmp expect actual
'

test_done
