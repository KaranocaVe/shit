#!/bin/sh

test_description='shit merge

Testing merge when using a custom message for the merge commit.'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

create_merge_msgs() {
	echo >exp.subject "custom message"

	cp exp.subject exp.log &&
	echo >>exp.log "" &&
	echo >>exp.log "* tag 'c2':" &&
	echo >>exp.log "  c2"
}

test_expect_success 'setup' '
	echo c0 >c0.c &&
	shit add c0.c &&
	shit commit -m c0 &&
	shit tag c0 &&
	echo c1 >c1.c &&
	shit add c1.c &&
	shit commit -m c1 &&
	shit tag c1 &&
	shit reset --hard c0 &&
	echo c2 >c2.c &&
	shit add c2.c &&
	shit commit -m c2 &&
	shit tag c2 &&
	create_merge_msgs
'


test_expect_success 'merge c2 with a custom message' '
	shit reset --hard c1 &&
	shit merge -m "$(cat exp.subject)" c2 &&
	shit cat-file commit HEAD >raw &&
	sed -e "1,/^$/d" raw >actual &&
	test_cmp exp.subject actual
'

test_expect_success 'merge --log appends to custom message' '
	shit reset --hard c1 &&
	shit merge --log -m "$(cat exp.subject)" c2 &&
	shit cat-file commit HEAD >raw &&
	sed -e "1,/^$/d" raw >actual &&
	test_cmp exp.log actual
'

mesg_with_comment_and_newlines='
# text

'

test_expect_success 'prepare file with comment line and trailing newlines'  '
	printf "%s" "$mesg_with_comment_and_newlines" >expect
'

test_expect_success 'cleanup commit messages (verbatim option)' '
	shit reset --hard c1 &&
	shit merge --cleanup=verbatim -F expect c2 &&
	shit cat-file commit HEAD >raw &&
	sed -e "1,/^$/d" raw >actual &&
	test_cmp expect actual
'

test_expect_success 'cleanup commit messages (whitespace option)' '
	shit reset --hard c1 &&
	test_write_lines "" "# text" "" >text &&
	echo "# text" >expect &&
	shit merge --cleanup=whitespace -F text c2 &&
	shit cat-file commit HEAD >raw &&
	sed -e "1,/^$/d" raw >actual &&
	test_cmp expect actual
'

test_expect_success 'cleanup merge messages (scissors option)' '
	shit reset --hard c1 &&
	cat >text <<-\EOF &&

	# to be kept

	  # ------------------------ >8 ------------------------
	# to be kept, too
	# ------------------------ >8 ------------------------
	to be removed
	# ------------------------ >8 ------------------------
	to be removed, too
	EOF

	cat >expect <<-\EOF &&
	# to be kept

	  # ------------------------ >8 ------------------------
	# to be kept, too
	EOF
	shit merge --cleanup=scissors -e -F text c2 &&
	shit cat-file commit HEAD >raw &&
	sed -e "1,/^$/d" raw >actual &&
	test_cmp expect actual
'

test_expect_success 'cleanup commit messages (strip option)' '
	shit reset --hard c1 &&
	test_write_lines "" "# text" "sample" "" >text &&
	echo sample >expect &&
	shit merge --cleanup=strip -F text c2 &&
	shit cat-file commit HEAD >raw &&
	sed -e "1,/^$/d" raw >actual &&
	test_cmp expect actual
'

test_done
