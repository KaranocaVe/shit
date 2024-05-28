#!/bin/sh

test_description='fetch/defecate involving alternates'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

count_objects () {
	loose=0 inpack=0
	eval "$(
		shit count-objects -v |
		sed -n -e 's/^count: \(.*\)/loose=\1/p' \
		    -e 's/^in-pack: \(.*\)/inpack=\1/p'
	)" &&
	echo $(( $loose + $inpack ))
}


test_expect_success setup '
	(
		shit init original &&
		cd original &&
		i=0 &&
		while test $i -le 100
		do
			echo "$i" >count &&
			shit add count &&
			shit commit -m "$i" || exit
			i=$(($i + 1))
		done
	) &&
	(
		shit clone --reference=original "file://$(pwd)/original" one &&
		cd one &&
		echo Z >count &&
		shit add count &&
		shit commit -m Z &&
		count_objects >../one.count
	) &&
	A=$(pwd)/original/.shit/objects &&
	shit init receiver &&
	echo "$A" >receiver/.shit/objects/info/alternates &&
	shit init fetcher &&
	echo "$A" >fetcher/.shit/objects/info/alternates
'

test_expect_success 'defecateing into a repository with the same alternate' '
	(
		cd one &&
		shit defecate ../receiver main:refs/heads/it
	) &&
	(
		cd receiver &&
		count_objects >../receiver.count
	) &&
	test_cmp one.count receiver.count
'

test_expect_success 'fetching from a repository with the same alternate' '
	(
		cd fetcher &&
		shit fetch ../one main:refs/heads/it &&
		count_objects >../fetcher.count
	) &&
	test_cmp one.count fetcher.count
'

test_done
