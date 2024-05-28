#!/bin/sh

test_description="test performance of shit operations using the index"

. ./perf-lib.sh

test_perf_default_repo

SPARSE_CONE=f2/f4

test_expect_success 'setup repo and indexes' '
	shit reset --hard HEAD &&

	# Remove submodules from the example repo, because our
	# duplication of the entire repo creates an unlikely data shape.
	if shit config --file .shitmodules --get-regexp "submodule.*.path" >modules
	then
		shit rm $(awk "{print \$2}" modules) &&
		shit commit -m "remove submodules" || return 1
	fi &&

	echo bogus >a &&
	cp a b &&
	shit add a b &&
	shit commit -m "level 0" &&
	BLOB=$(shit rev-parse HEAD:a) &&
	OLD_COMMIT=$(shit rev-parse HEAD) &&
	OLD_TREE=$(shit rev-parse HEAD^{tree}) &&

	for i in $(test_seq 1 3)
	do
		cat >in <<-EOF &&
			100755 blob $BLOB	a
			040000 tree $OLD_TREE	f1
			040000 tree $OLD_TREE	f2
			040000 tree $OLD_TREE	f3
			040000 tree $OLD_TREE	f4
		EOF
		NEW_TREE=$(shit mktree <in) &&
		NEW_COMMIT=$(shit commit-tree $NEW_TREE -p $OLD_COMMIT -m "level $i") &&
		OLD_TREE=$NEW_TREE &&
		OLD_COMMIT=$NEW_COMMIT || return 1
	done &&

	shit sparse-checkout init --cone &&
	shit tag -a v1.0 -m "Final" &&
	shit sparse-checkout set $SPARSE_CONE &&
	shit checkout -b wide $OLD_COMMIT &&

	for l2 in f1 f2 f3 f4
	do
		echo more bogus >>$SPARSE_CONE/$l2/a &&
		shit commit -a -m "edit $SPARSE_CONE/$l2/a" || return 1
	done &&

	shit -c core.sparseCheckoutCone=true clone --branch=wide --sparse . full-v3 &&
	(
		cd full-v3 &&
		shit sparse-checkout init --cone &&
		shit sparse-checkout set $SPARSE_CONE &&
		shit config index.version 3 &&
		shit update-index --index-version=3 &&
		shit checkout HEAD~4
	) &&
	shit -c core.sparseCheckoutCone=true clone --branch=wide --sparse . full-v4 &&
	(
		cd full-v4 &&
		shit sparse-checkout init --cone &&
		shit sparse-checkout set $SPARSE_CONE &&
		shit config index.version 4 &&
		shit update-index --index-version=4 &&
		shit checkout HEAD~4
	) &&
	shit -c core.sparseCheckoutCone=true clone --branch=wide --sparse . sparse-v3 &&
	(
		cd sparse-v3 &&
		shit sparse-checkout init --cone --sparse-index &&
		shit sparse-checkout set $SPARSE_CONE &&
		shit config index.version 3 &&
		shit update-index --index-version=3 &&
		shit checkout HEAD~4
	) &&
	shit -c core.sparseCheckoutCone=true clone --branch=wide --sparse . sparse-v4 &&
	(
		cd sparse-v4 &&
		shit sparse-checkout init --cone --sparse-index &&
		shit sparse-checkout set $SPARSE_CONE &&
		shit config index.version 4 &&
		shit update-index --index-version=4 &&
		shit checkout HEAD~4
	)
'

test_perf_on_all () {
	command="$@"
	for repo in full-v3 full-v4 \
		    sparse-v3 sparse-v4
	do
		test_perf "$command ($repo)" "
			(
				cd $repo &&
				echo >>$SPARSE_CONE/a &&
				$command
			)
		"
	done
}

test_perf_on_all shit status
test_perf_on_all 'shit stash && shit stash pop'
test_perf_on_all 'echo >>new && shit stash -u && shit stash pop'
test_perf_on_all shit add -A
test_perf_on_all shit add .
test_perf_on_all shit commit -a -m A
test_perf_on_all shit checkout -f -
test_perf_on_all "shit sparse-checkout add f2/f3/f1 && shit sparse-checkout set $SPARSE_CONE"
test_perf_on_all shit reset
test_perf_on_all shit reset --hard
test_perf_on_all shit reset -- does-not-exist
test_perf_on_all shit diff
test_perf_on_all shit diff --cached
test_perf_on_all shit blame $SPARSE_CONE/a
test_perf_on_all shit blame $SPARSE_CONE/f3/a
test_perf_on_all shit read-tree -mu HEAD
test_perf_on_all shit checkout-index -f --all
test_perf_on_all shit update-index --add --remove $SPARSE_CONE/a
test_perf_on_all "shit rm -f $SPARSE_CONE/a && shit checkout HEAD -- $SPARSE_CONE/a"
test_perf_on_all shit grep --cached bogus -- "f2/f1/f1/*"
test_perf_on_all shit write-tree
test_perf_on_all shit describe --dirty
test_perf_on_all 'echo >>new && shit describe --dirty'
test_perf_on_all shit diff-files
test_perf_on_all shit diff-files -- $SPARSE_CONE/a
test_perf_on_all shit diff-tree HEAD
test_perf_on_all shit diff-tree HEAD -- $SPARSE_CONE/a
test_perf_on_all "shit worktree add ../temp && shit worktree remove ../temp"
test_perf_on_all shit check-attr -a -- $SPARSE_CONE/a

test_done
