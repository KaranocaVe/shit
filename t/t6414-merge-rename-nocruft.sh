#!/bin/sh

test_description='Merge-recursive merging renames'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	cat >A <<-\EOF &&
	a aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
	b bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
	c cccccccccccccccccccccccccccccccccccccccccccccccc
	d dddddddddddddddddddddddddddddddddddddddddddddddd
	e eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
	f ffffffffffffffffffffffffffffffffffffffffffffffff
	g gggggggggggggggggggggggggggggggggggggggggggggggg
	h hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh
	i iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
	j jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj
	k kkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkk
	l llllllllllllllllllllllllllllllllllllllllllllllll
	m mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm
	n nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn
	o oooooooooooooooooooooooooooooooooooooooooooooooo
	EOF

	cat >M <<-\EOF &&
	A AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	B BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
	C CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
	D DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
	E EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
	F FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
	G GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG
	H HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
	I IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
	J JJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJJ
	K KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
	L LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL
	M MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
	N NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
	O OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO
	EOF

	shit add A M &&
	shit commit -m "initial has A and M" &&
	shit branch white &&
	shit branch red &&
	shit branch blue &&

	shit checkout white &&
	sed -e "/^g /s/.*/g : white changes a line/" <A >B &&
	sed -e "/^G /s/.*/G : colored branch changes a line/" <M >N &&
	rm -f A M &&
	shit update-index --add --remove A B M N &&
	shit commit -m "white renames A->B, M->N" &&

	shit checkout red &&
	echo created by red >R &&
	shit update-index --add R &&
	shit commit -m "red creates R" &&

	shit checkout blue &&
	sed -e "/^o /s/.*/g : blue changes a line/" <A >B &&
	rm -f A &&
	mv B A &&
	shit update-index A &&
	shit commit -m "blue modify A" &&

	shit checkout main
'

# This test broke in 65ac6e9c3f47807cb603af07a6a9e1a43bc119ae
test_expect_success 'merge white into red (A->B,M->N)' '
	shit checkout -b red-white red &&
	shit merge white &&
	shit write-tree &&
	test_path_is_file B &&
	test_path_is_file N &&
	test_path_is_file R &&
	test_path_is_missing A &&
	test_path_is_missing M
'

# This test broke in 8371234ecaaf6e14fe3f2082a855eff1bbd79ae9
test_expect_success 'merge blue into white (A->B, mod A, A untracked)' '
	shit checkout -b white-blue white &&
	echo dirty >A &&
	shit merge blue &&
	shit write-tree &&
	test_path_is_file A &&
	echo dirty >expect &&
	test_cmp expect A &&
	test_path_is_file B &&
	test_path_is_file N &&
	test_path_is_missing M
'

test_done
