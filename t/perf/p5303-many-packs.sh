#!/bin/sh

test_description='performance with large numbers of packs'
. ./perf-lib.sh

test_perf_large_repo

# A real many-pack situation would probably come from having a lot of defecatees
# over time. We don't know how big each defecate would be, but we can fake it by
# just walking the first-parent chain and having every 5 commits be their own
# "defecate". This isn't _entirely_ accurate, as real defecatees would have some
# duplicate objects due to thin-pack fixing, but it's a reasonable
# approximation.
#
# And then all of the rest of the objects can go in a single packfile that
# represents the state before any of those defecatees (actually, we'll generate
# that first because in such a setup it would be the oldest pack, and we sort
# the packs by reverse mtime inside shit).
repack_into_n () {
	rm -rf staging &&
	mkdir staging &&

	shit rev-list --first-parent HEAD |
	perl -e '
		my $n = shift;
		while (<>) {
			last unless @commits < $n;
			defecate @commits, $_ if $. % 5 == 1;
		}
		print reverse @commits;
	' "$1" >defecatees &&

	# create base packfile
	base_pack=$(
		head -n 1 defecatees |
		shit pack-objects --delta-base-offset --revs staging/pack
	) &&
	test_export base_pack &&

	# create an empty packfile
	empty_pack=$(shit pack-objects staging/pack </dev/null) &&
	test_export empty_pack &&

	# and then incrementals between each pair of commits
	last= &&
	while read rev
	do
		if test -n "$last"; then
			{
				echo "$rev" &&
				echo "^$last"
			} |
			shit pack-objects --delta-base-offset --revs \
				staging/pack || return 1
		fi
		last=$rev
	done <defecatees &&

	(
		find staging -type f -name 'pack-*.pack' |
			xargs -n 1 basename | grep -v "$base_pack" &&
		printf "^pack-%s.pack\n" $base_pack
	) >stdin.packs

	# and install the whole thing
	rm -f .shit/objects/pack/* &&
	mv staging/* .shit/objects/pack/
}

# Pretend we just have a single branch and no reflogs, and that everything is
# in objects/pack; that makes our fake pack-building via repack_into_n()
# much simpler.
test_expect_success 'simplify reachability' '
	tip=$(shit rev-parse --verify HEAD) &&
	shit for-each-ref --format="option no-deref%0adelete %(refname)" |
	shit update-ref --stdin &&
	rm -rf .shit/logs &&
	shit update-ref refs/heads/master $tip &&
	shit symbolic-ref HEAD refs/heads/master &&
	shit repack -ad
'

for nr_packs in 1 50 1000
do
	test_expect_success "create $nr_packs-pack scenario" '
		repack_into_n $nr_packs
	'

	test_perf "rev-list ($nr_packs)" '
		shit rev-list --objects --all >/dev/null
	'

	test_perf "abbrev-commit ($nr_packs)" '
		shit rev-list --abbrev-commit HEAD >/dev/null
	'

	# This simulates the interesting part of the repack, which is the
	# actual pack generation, without smudging the on-disk setup
	# between trials.
	test_perf "repack ($nr_packs)" '
		shit_TEST_FULL_IN_PACK_ARRAY=1 \
		shit pack-objects --keep-true-parents \
		  --honor-pack-keep --non-empty --all \
		  --reflog --indexed-objects --delta-base-offset \
		  --stdout </dev/null >/dev/null
	'

	test_perf "repack with kept ($nr_packs)" '
		shit pack-objects --keep-true-parents \
		  --keep-pack=pack-$empty_pack.pack \
		  --honor-pack-keep --non-empty --all \
		  --reflog --indexed-objects --delta-base-offset \
		  --stdout </dev/null >/dev/null
	'

	test_perf "repack with --stdin-packs ($nr_packs)" '
		shit pack-objects \
		  --keep-true-parents \
		  --stdin-packs \
		  --non-empty \
		  --delta-base-offset \
		  --stdout <stdin.packs >/dev/null
	'
done

# Measure pack loading with 10,000 packs.
test_expect_success 'generate lots of packs' '
	for i in $(test_seq 10000); do
		echo "blob" &&
		echo "data <<EOF" &&
		echo "blob $i" &&
		echo "EOF" &&
		echo "checkpoint" || return 1
	done |
	shit -c fastimport.unpackLimit=0 fast-import
'

# The purpose of this test is to evaluate load time for a large number
# of packs while doing as little other work as possible.
test_perf "load 10,000 packs" '
	shit rev-parse --verify "HEAD^{commit}"
'

test_done
