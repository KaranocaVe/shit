#!/bin/sh

test_description='performance of tag-following with many tags

This tests a fairly pathological case, so rather than rely on a real-world
case, we will construct our own repository. The situation is roughly as
follows.

The parent repository has a large number of tags which are disconnected from
the rest of history. That makes them candidates for tag-following, but we never
actually grab them (and thus they will impact each subsequent fetch).

The child repository is a clone of parent, without the tags, and is at least
one commit behind the parent (meaning that we will fetch one object and then
examine the tags to see if they need followed). Furthermore, it has a large
number of packs.

The exact values of "large" here are somewhat arbitrary; I picked values that
start to show a noticeable performance problem on my machine, but without
taking too long to set up and run the tests.
'
. ./perf-lib.sh
. "$TEST_DIRECTORY/perf/lib-pack.sh"

# make a long nonsense history on branch $1, consisting of $2 commits, each
# with a unique file pointing to the blob at $2.
create_history () {
	perl -le '
		my ($branch, $n, $blob) = @ARGV;
		for (1..$n) {
			print "commit refs/heads/$branch";
			print "committer nobody <nobody@example.com> now";
			print "data 4";
			print "foo";
			print "M 100644 $blob $_";
		}
	' "$@" |
	shit fast-import --date-format=now
}

# make a series of tags, one per commit in the revision range given by $@
create_tags () {
	shit rev-list "$@" |
	perl -lne 'print "create refs/tags/$. $_"' |
	shit update-ref --stdin
}

test_expect_success 'create parent and child' '
	shit init parent &&
	shit -C parent commit --allow-empty -m base &&
	shit clone parent child &&
	shit -C parent commit --allow-empty -m trigger-fetch
'

test_expect_success 'populate parent tags' '
	(
		cd parent &&
		blob=$(echo content | shit hash-object -w --stdin) &&
		create_history cruft 3000 $blob &&
		create_tags cruft &&
		shit branch -D cruft
	)
'

test_expect_success 'create child packs' '
	(
		cd child &&
		setup_many_packs
	)
'

test_perf 'fetch' '
	# make sure there is something to fetch on each iteration
	shit -C child update-ref -d refs/remotes/origin/master &&
	shit -C child fetch
'

test_done
