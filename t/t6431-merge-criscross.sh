#!/bin/sh

test_description='merge-recursive backend test'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

#         A      <- create some files
#        / \
#       B   C    <- cause rename/delete conflicts between B and C
#      /     \
#     |\     /|
#     | D   E |
#     |  \ /  |
#     |   X   |
#     |  / \  |
#     | /   \ |
#     |/     \|
#     F       G  <- merge E into B, D into C
#      \     /
#       \   /
#        \ /
#         H      <- recursive merge crashes
#

# initialize
test_expect_success 'setup repo with criss-cross history' '
	mkdir data &&

	# create a bunch of files
	n=1 &&
	while test $n -le 10
	do
		echo $n > data/$n &&
		n=$(($n+1)) ||
		return 1
	done &&

	# check them in
	shit add data &&
	shit commit -m A &&
	shit branch A &&

	# a file in one branch
	shit checkout -b B A &&
	shit rm data/9 &&
	shit add data &&
	shit commit -m B &&

	# with a branch off of it
	shit branch D &&

	# put some commits on D
	shit checkout D &&
	echo testD > data/testD &&
	shit add data &&
	shit commit -m D &&

	# back up to the top, create another branch and cause
	# a rename conflict with the file we deleted earlier
	shit checkout -b C A &&
	shit mv data/9 data/new-9 &&
	shit add data &&
	shit commit -m C &&

	# with a branch off of it
	shit branch E &&

	# put a commit on E
	shit checkout E &&
	echo testE > data/testE &&
	shit add data &&
	shit commit -m E &&

	# now, merge E into B
	shit checkout B &&
	test_must_fail shit merge E &&
	# force-resolve
	shit add data &&
	shit commit -m F &&
	shit branch F &&

	# and merge D into C
	shit checkout C &&
	test_must_fail shit merge D &&
	# force-resolve
	shit add data &&
	shit commit -m G &&
	shit branch G
'

test_expect_success 'recursive merge between F and G does not cause segfault' '
	shit merge F
'

test_done
