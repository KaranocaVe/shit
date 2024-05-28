#!/bin/sh

test_description='diff order & rotate'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

create_files () {
	echo "$1" >a.h &&
	echo "$1" >b.c &&
	echo "$1" >c/Makefile &&
	echo "$1" >d.txt &&
	shit add a.h b.c c/Makefile d.txt &&
	shit commit -m"$1"
}

test_expect_success 'setup' '
	mkdir c &&
	create_files 1 &&
	create_files 2 &&

	cat >order_file_1 <<-\EOF &&
	*Makefile
	*.txt
	*.h
	EOF

	cat >order_file_2 <<-\EOF &&
	*Makefile
	*.h
	*.c
	EOF

	cat >expect_none <<-\EOF &&
	a.h
	b.c
	c/Makefile
	d.txt
	EOF

	cat >expect_1 <<-\EOF &&
	c/Makefile
	d.txt
	a.h
	b.c
	EOF

	cat >expect_2 <<-\EOF
	c/Makefile
	a.h
	b.c
	d.txt
	EOF
'

test_expect_success "no order (=tree object order)" '
	shit diff --name-only HEAD^..HEAD >actual &&
	test_cmp expect_none actual
'

test_expect_success 'missing orderfile' '
	rm -f bogus_file &&
	test_must_fail shit diff -Obogus_file --name-only HEAD^..HEAD
'

test_expect_success POSIXPERM,SANITY 'unreadable orderfile' '
	>unreadable_file &&
	chmod -r unreadable_file &&
	test_must_fail shit diff -Ounreadable_file --name-only HEAD^..HEAD
'

test_expect_success "orderfile using option from subdir with --output" '
	mkdir subdir &&
	shit -C subdir diff -O../order_file_1 --output ../actual --name-only HEAD^..HEAD &&
	test_cmp expect_1 actual
'

for i in 1 2
do
	test_expect_success "orderfile using option ($i)" '
		shit diff -Oorder_file_$i --name-only HEAD^..HEAD >actual &&
		test_cmp expect_$i actual
	'

	test_expect_success PIPE "orderfile is fifo ($i)" '
		rm -f order_fifo &&
		mkfifo order_fifo &&
		{
			cat order_file_$i >order_fifo &
		} &&
		shit diff -O order_fifo --name-only HEAD^..HEAD >actual &&
		wait &&
		test_cmp expect_$i actual
	'

	test_expect_success "orderfile using config ($i)" '
		shit -c diff.orderfile=order_file_$i diff --name-only HEAD^..HEAD >actual &&
		test_cmp expect_$i actual
	'

	test_expect_success "cancelling configured orderfile ($i)" '
		shit -c diff.orderfile=order_file_$i diff -O/dev/null --name-only HEAD^..HEAD >actual &&
		test_cmp expect_none actual
	'
done

test_expect_success 'setup for testing combine-diff order' '
	shit checkout -b tmp HEAD~ &&
	create_files 3 &&
	shit checkout main &&
	shit merge --no-commit -s ours tmp &&
	create_files 5
'

test_expect_success "combine-diff: no order (=tree object order)" '
	shit diff --name-only HEAD HEAD^ HEAD^2 >actual &&
	test_cmp expect_none actual
'

for i in 1 2
do
	test_expect_success "combine-diff: orderfile using option ($i)" '
		shit diff -Oorder_file_$i --name-only HEAD HEAD^ HEAD^2 >actual &&
		test_cmp expect_$i actual
	'
done

### rotate and skip

test_expect_success 'rotate and skip setup' '
	>sample1.t &&
	>sample2.t &&
	>sample3.t &&
	>sample4.t &&
	shit add sample[1234].t &&
	shit commit -m "added" sample[1234].t &&
	echo modified >>sample1.t &&
	echo modified >>sample2.t &&
	echo modified >>sample4.t &&
	shit commit -m "updated" sample[1234].t
'

test_expect_success 'diff --rotate-to' '
	shit diff --rotate-to=sample2.t --name-only HEAD^ >actual &&
	test_write_lines sample2.t sample4.t sample1.t >expect &&
	test_cmp expect actual
'

test_expect_success 'diff --skip-to' '
	shit diff --skip-to=sample2.t --name-only HEAD^ >actual &&
	test_write_lines sample2.t sample4.t >expect &&
	test_cmp expect actual
'

test_expect_success 'diff --rotate/skip-to error condition' '
	test_must_fail shit diff --rotate-to=sample3.t HEAD^ &&
	test_must_fail shit diff --skip-to=sample3.t HEAD^
'

test_expect_success 'log --rotate-to' '
	shit log --rotate-to=sample3.t --raw HEAD~2.. >raw &&
	# just distill the commit header and paths
	sed -n -e "s/^commit.*/commit/p" \
	       -e "/^:/s/^.*	//p" raw >actual &&

	cat >expect <<-\EOF &&
	commit
	sample4.t
	sample1.t
	sample2.t
	commit
	sample3.t
	sample4.t
	sample1.t
	sample2.t
	EOF

	test_cmp expect actual
'

test_expect_success 'log --skip-to' '
	shit log --skip-to=sample3.t --raw HEAD~2.. >raw &&
	# just distill the commit header and paths
	sed -n -e "s/^commit.*/commit/p" \
	       -e "/^:/s/^.*	//p" raw >actual &&

	cat >expect <<-\EOF &&
	commit
	sample4.t
	commit
	sample3.t
	sample4.t
	EOF

	test_cmp expect actual
'

test_done
