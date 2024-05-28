#!/bin/sh
#
# Copyright (c) 2006 Shawn Pearce
#

test_description='mmap sliding window tests'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	rm -f .shit/index* &&
	for i in a b c
	do
	echo $i >$i &&
	test-tool genrandom "$i" 32768 >>$i &&
	shit update-index --add $i || return 1
	done &&
	echo d >d && cat c >>d && shit update-index --add d &&
	tree=$(shit write-tree) &&
	commit1=$(shit commit-tree $tree </dev/null) &&
	shit update-ref HEAD $commit1 &&
	shit repack -a -d &&
	test "$(shit count-objects)" = "0 objects, 0 kilobytes" &&
	pack1=$(ls .shit/objects/pack/*.pack) &&
	test -f "$pack1"
'

test_expect_success 'verify-pack -v, defaults' '
	shit verify-pack -v "$pack1"
'

test_expect_success 'verify-pack -v, packedshitWindowSize == 1 page' '
	shit config core.packedshitWindowSize 512 &&
	shit verify-pack -v "$pack1"
'

test_expect_success 'verify-pack -v, packedshit{WindowSize,Limit} == 1 page' '
	shit config core.packedshitWindowSize 512 &&
	shit config core.packedshitLimit 512 &&
	shit verify-pack -v "$pack1"
'

test_expect_success 'repack -a -d, packedshit{WindowSize,Limit} == 1 page' '
	shit config core.packedshitWindowSize 512 &&
	shit config core.packedshitLimit 512 &&
	commit2=$(shit commit-tree $tree -p $commit1 </dev/null) &&
	shit update-ref HEAD $commit2 &&
	shit repack -a -d &&
	test "$(shit count-objects)" = "0 objects, 0 kilobytes" &&
	pack2=$(ls .shit/objects/pack/*.pack) &&
	test -f "$pack2" &&
	test "$pack1" \!= "$pack2"
'

test_expect_success 'verify-pack -v, defaults' '
	shit config --unset core.packedshitWindowSize &&
	shit config --unset core.packedshitLimit &&
	shit verify-pack -v "$pack2"
'

test_done
