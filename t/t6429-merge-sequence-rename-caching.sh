#!/bin/sh

test_description="remember regular & dir renames in sequence of merges"

. ./test-lib.sh

#
# NOTE 1: this testfile tends to not only rename files, but modify on both
#         sides; without modifying on both sides, optimizations can kick in
#         which make rename detection irrelevant or trivial.  We want to make
#         sure that we are triggering rename caching rather than rename
#         bypassing.
#
# NOTE 2: this testfile uses 'test-tool fast-rebase' instead of either
#         cherry-pick or rebase.  sequencer.c is only superficially
#         integrated with merge-ort; it calls merge_switch_to_result()
#         after EACH merge, which updates the index and working copy AND
#         throws away the cached results (because merge_switch_to_result()
#         is only supposed to be called at the end of the sequence).
#         Integrating them more deeply is a big task, so for now the tests
#         use 'test-tool fast-rebase'.
#


#
# In the following simple testcase:
#   Base:     numbers_1, values_1
#   Upstream: numbers_2, values_2
#   Topic_1:  sequence_3
#   Topic_2:  scruples_3
# or, in english, rename numbers -> sequence in the first commit, and rename
# values -> scruples in the second commit.
#
# This shouldn't be a challenge, it's just verifying that cached renames isn't
# preventing us from finding new renames.
#
test_expect_success 'caching renames does not preclude finding new ones' '
	shit init caching-renames-and-new-renames &&
	(
		cd caching-renames-and-new-renames &&

		test_seq 2 10 >numbers &&
		test_seq 2 10 >values &&
		shit add numbers values &&
		shit commit -m orig &&

		shit branch upstream &&
		shit branch topic &&

		shit switch upstream &&
		test_seq 1 10 >numbers &&
		test_seq 1 10 >values &&
		shit add numbers values &&
		shit commit -m "Tweaked both files" &&

		shit switch topic &&

		test_seq 2 12 >numbers &&
		shit add numbers &&
		shit mv numbers sequence &&
		shit commit -m A &&

		test_seq 2 12 >values &&
		shit add values &&
		shit mv values scruples &&
		shit commit -m B &&

		#
		# Actual testing
		#

		shit switch upstream &&

		shit replay --onto HEAD upstream~1..topic >out &&
		shit update-ref --stdin <out &&
		shit checkout topic &&

		shit ls-files >tracked-files &&
		test_line_count = 2 tracked-files &&
		test_seq 1 12 >expect &&
		test_cmp expect sequence &&
		test_cmp expect scruples
	)
'

#
# In the following testcase:
#   Base:     numbers_1
#   Upstream: rename numbers_1 -> sequence_2
#   Topic_1:  numbers_3
#   Topic_2:  numbers_1
# or, in english, the first commit on the topic branch modifies numbers by
# shrinking it (dramatically) and the second commit on topic reverts its
# parent.
#
# Can shit apply both patches?
#
# Traditional cherry-pick/rebase will fail to apply the second commit, the
# one that reverted its parent, because despite detecting the rename from
# 'numbers' to 'sequence' for the first commit, it fails to detect that
# rename when picking the second commit.  That's "reasonable" given the
# dramatic change in size of the file, but remembering the rename and
# reusing it is reasonable too.
#
# We do test here that we expect rename detection to only be run once total
# (the topic side of history doesn't need renames, and with caching we
# should be able to only run rename detection on the upstream side one
# time.)
test_expect_success 'cherry-pick both a commit and its immediate revert' '
	shit init pick-commit-and-its-immediate-revert &&
	(
		cd pick-commit-and-its-immediate-revert &&

		test_seq 11 30 >numbers &&
		shit add numbers &&
		shit commit -m orig &&

		shit branch upstream &&
		shit branch topic &&

		shit switch upstream &&
		test_seq 1 30 >numbers &&
		shit add numbers &&
		shit mv numbers sequence &&
		shit commit -m "Renamed (and modified) numbers -> sequence" &&

		shit switch topic &&

		test_seq 11 13 >numbers &&
		shit add numbers &&
		shit commit -m A &&

		shit revert HEAD &&

		#
		# Actual testing
		#

		shit switch upstream &&

		shit_TRACE2_PERF="$(pwd)/trace.output" &&
		export shit_TRACE2_PERF &&

		shit replay --onto HEAD upstream~1..topic >out &&
		shit update-ref --stdin <out &&
		shit checkout topic &&

		grep region_enter.*diffcore_rename trace.output >calls &&
		test_line_count = 1 calls
	)
'

#
# In the following testcase:
#   Base:     sequence_1
#   Upstream: rename sequence_1 -> values_2
#   Topic_1:  rename sequence_1 -> values_3
#   Topic_2:  add unrelated sequence_4
# or, in english, both sides rename sequence -> values, and then the second
# commit on the topic branch adds an unrelated file called sequence.
#
# This testcase presents no problems for shit traditionally, but having both
# sides do the same rename in effect "uses it up" and if it remains cached,
# could cause a spurious rename/add conflict.
#
test_expect_success 'rename same file identically, then reintroduce it' '
	shit init rename-rename-1to1-then-add-old-filename &&
	(
		cd rename-rename-1to1-then-add-old-filename &&

		test_seq 3 8 >sequence &&
		shit add sequence &&
		shit commit -m orig &&

		shit branch upstream &&
		shit branch topic &&

		shit switch upstream &&
		test_seq 1 8 >sequence &&
		shit add sequence &&
		shit mv sequence values &&
		shit commit -m "Renamed (and modified) sequence -> values" &&

		shit switch topic &&

		test_seq 3 10 >sequence &&
		shit add sequence &&
		shit mv sequence values &&
		shit commit -m A &&

		test_write_lines A B C D E F G H I J >sequence &&
		shit add sequence &&
		shit commit -m B &&

		#
		# Actual testing
		#

		shit switch upstream &&

		shit_TRACE2_PERF="$(pwd)/trace.output" &&
		export shit_TRACE2_PERF &&

		shit replay --onto HEAD upstream~1..topic >out &&
		shit update-ref --stdin <out &&
		shit checkout topic &&

		shit ls-files >tracked &&
		test_line_count = 2 tracked &&
		test_path_is_file values &&
		test_path_is_file sequence &&

		grep region_enter.*diffcore_rename trace.output >calls &&
		test_line_count = 2 calls
	)
'

#
# In the following testcase:
#   Base:     olddir/{valuesZ_1, valuesY_1, valuesX_1}
#   Upstream: rename olddir/valuesZ_1 -> dirA/valuesZ_2
#             rename olddir/valuesY_1 -> dirA/valuesY_2
#             rename olddir/valuesX_1 -> dirB/valuesX_2
#   Topic_1:  rename olddir/valuesZ_1 -> dirA/valuesZ_3
#             rename olddir/valuesY_1 -> dirA/valuesY_3
#   Topic_2:  add olddir/newfile
#   Expected Pick1: dirA/{valuesZ, valuesY}, dirB/valuesX
#   Expected Pick2: dirA/{valuesZ, valuesY}, dirB/{valuesX, newfile}
#
# This testcase presents no problems for shit traditionally, but having both
# sides do the same renames in effect "use it up" but if the renames remain
# cached, the directory rename could put newfile in the wrong directory.
#
test_expect_success 'rename same file identically, then add file to old dir' '
	shit init rename-rename-1to1-then-add-file-to-old-dir &&
	(
		cd rename-rename-1to1-then-add-file-to-old-dir &&

		mkdir olddir/ &&
		test_seq 3 8 >olddir/valuesZ &&
		test_seq 3 8 >olddir/valuesY &&
		test_seq 3 8 >olddir/valuesX &&
		shit add olddir &&
		shit commit -m orig &&

		shit branch upstream &&
		shit branch topic &&

		shit switch upstream &&
		test_seq 1 8 >olddir/valuesZ &&
		test_seq 1 8 >olddir/valuesY &&
		test_seq 1 8 >olddir/valuesX &&
		shit add olddir &&
		mkdir dirA &&
		shit mv olddir/valuesZ olddir/valuesY dirA &&
		shit mv olddir/ dirB/ &&
		shit commit -m "Renamed (and modified) values*" &&

		shit switch topic &&

		test_seq 3 10 >olddir/valuesZ &&
		test_seq 3 10 >olddir/valuesY &&
		shit add olddir &&
		mkdir dirA &&
		shit mv olddir/valuesZ olddir/valuesY dirA &&
		shit commit -m A &&

		>olddir/newfile &&
		shit add olddir/newfile &&
		shit commit -m B &&

		#
		# Actual testing
		#

		shit switch upstream &&
		shit config merge.directoryRenames true &&

		shit_TRACE2_PERF="$(pwd)/trace.output" &&
		export shit_TRACE2_PERF &&

		shit replay --onto HEAD upstream~1..topic >out &&
		shit update-ref --stdin <out &&
		shit checkout topic &&

		shit ls-files >tracked &&
		test_line_count = 4 tracked &&
		test_path_is_file dirA/valuesZ &&
		test_path_is_file dirA/valuesY &&
		test_path_is_file dirB/valuesX &&
		test_path_is_file dirB/newfile &&

		grep region_enter.*diffcore_rename trace.output >calls &&
		test_line_count = 3 calls
	)
'

#
# In the following testcase, upstream renames a directory, and the topic branch
# first adds a file to the directory, then later renames the directory
# differently:
#   Base:     olddir/a
#             olddir/b
#   Upstream: rename olddir/ -> newdir/
#   Topic_1:  add olddir/newfile
#   Topic_2:  rename olddir/ -> otherdir/
#
# Here we are just concerned that cached renames might prevent us from seeing
# the rename conflict, and we want to ensure that we do get a conflict.
#
# While at it, though, we do test that we only try to detect renames 2
# times and not three.  (The first merge needs to detect renames on the
# upstream side.  Traditionally, the second merge would need to detect
# renames on both sides of history, but our caching of upstream renames
# should avoid the need to re-detect upstream renames.)
#
test_expect_success 'cached dir rename does not prevent noticing later conflict' '
	shit init dir-rename-cache-not-occluding-later-conflict &&
	(
		cd dir-rename-cache-not-occluding-later-conflict &&

		mkdir olddir &&
		test_seq 3 10 >olddir/a &&
		test_seq 3 10 >olddir/b &&
		shit add olddir &&
		shit commit -m orig &&

		shit branch upstream &&
		shit branch topic &&

		shit switch upstream &&
		test_seq 3 10 >olddir/a &&
		test_seq 3 10 >olddir/b &&
		shit add olddir &&
		shit mv olddir newdir &&
		shit commit -m "Dir renamed" &&

		shit switch topic &&

		>olddir/newfile &&
		shit add olddir/newfile &&
		shit commit -m A &&

		test_seq 1 8 >olddir/a &&
		test_seq 1 8 >olddir/b &&
		shit add olddir &&
		shit mv olddir otherdir &&
		shit commit -m B &&

		#
		# Actual testing
		#

		shit switch upstream &&
		shit config merge.directoryRenames true &&

		shit_TRACE2_PERF="$(pwd)/trace.output" &&
		export shit_TRACE2_PERF &&

		test_must_fail shit replay --onto HEAD upstream~1..topic >output &&

		grep region_enter.*diffcore_rename trace.output >calls &&
		test_line_count = 2 calls
	)
'

# Helper for the next two tests
test_setup_upstream_rename () {
	shit init $1 &&
	(
		cd $1 &&

		test_seq 3 8 >somefile &&
		test_seq 3 8 >relevant-rename &&
		shit add somefile relevant-rename &&
		mkdir olddir &&
		test_write_lines a b c d e f g >olddir/a &&
		test_write_lines z y x w v u t >olddir/b &&
		shit add olddir &&
		shit commit -m orig &&

		shit branch upstream &&
		shit branch topic &&

		shit switch upstream &&
		test_seq 1 8 >somefile &&
		test_seq 1 8 >relevant-rename &&
		shit add somefile relevant-rename &&
		shit mv relevant-rename renamed &&
		echo h >>olddir/a &&
		echo s >>olddir/b &&
		shit add olddir &&
		shit mv olddir newdir &&
		shit commit -m "Dir renamed"
	)
}

#
# In the following testcase, upstream renames a file in the toplevel directory
# as well as its only directory:
#   Base:     relevant-rename_1
#             somefile
#             olddir/a
#             olddir/b
#   Upstream: rename relevant-rename_1 -> renamed_2
#             rename olddir/           -> newdir/
#   Topic_1:  relevant-rename_3
#   Topic_2:  olddir/newfile_1
#   Topic_3:  olddir/newfile_2
#
# In this testcase, since the first commit being picked only modifies a
# file in the toplevel directory, the directory rename is irrelevant for
# that first merge.  However, we need to notice the directory rename for
# the merge that picks the second commit, and we don't want the third
# commit to mess up its location either.  We want to make sure that
# olddir/newfile doesn't exist in the result and that newdir/newfile does.
#
# We also test that we only do rename detection twice.  We never need
# rename detection on the topic side of history, but we do need it twice on
# the upstream side of history.  For the first topic commit, we only need
# the
#   relevant-rename -> renamed
# rename, because olddir is unmodified by Topic_1.  For Topic_2, however,
# the new file being added to olddir means files that were previously
# irrelevant for rename detection are now relevant, forcing us to repeat
# rename detection for the paths we don't already have cached.  Topic_3 also
# tweaks olddir/newfile, but the renames in olddir/ will have been cached
# from the second rename detection run.
#
test_expect_success 'dir rename unneeded, then add new file to old dir' '
	test_setup_upstream_rename dir-rename-unneeded-until-new-file &&
	(
		cd dir-rename-unneeded-until-new-file &&

		shit switch topic &&

		test_seq 3 10 >relevant-rename &&
		shit add relevant-rename &&
		shit commit -m A &&

		echo foo >olddir/newfile &&
		shit add olddir/newfile &&
		shit commit -m B &&

		echo bar >>olddir/newfile &&
		shit add olddir/newfile &&
		shit commit -m C &&

		#
		# Actual testing
		#

		shit switch upstream &&
		shit config merge.directoryRenames true &&

		shit_TRACE2_PERF="$(pwd)/trace.output" &&
		export shit_TRACE2_PERF &&

		shit replay --onto HEAD upstream~1..topic >out &&
		shit update-ref --stdin <out &&
		shit checkout topic &&

		grep region_enter.*diffcore_rename trace.output >calls &&
		test_line_count = 2 calls &&

		shit ls-files >tracked &&
		test_line_count = 5 tracked &&
		test_path_is_missing olddir/newfile &&
		test_path_is_file newdir/newfile
	)
'

#
# The following testcase is *very* similar to the last one, but instead of
# adding a new olddir/newfile, it renames somefile -> olddir/newfile:
#   Base:     relevant-rename_1
#             somefile_1
#             olddir/a
#             olddir/b
#   Upstream: rename relevant-rename_1 -> renamed_2
#             rename olddir/           -> newdir/
#   Topic_1:  relevant-rename_3
#   Topic_2:  rename somefile -> olddir/newfile_2
#   Topic_3:  modify olddir/newfile_3
#
# In this testcase, since the first commit being picked only modifies a
# file in the toplevel directory, the directory rename is irrelevant for
# that first merge.  However, we need to notice the directory rename for
# the merge that picks the second commit, and we don't want the third
# commit to mess up its location either.  We want to make sure that
# neither somefile or olddir/newfile exists in the result and that
# newdir/newfile does.
#
# This testcase needs one more call to rename detection than the last
# testcase, because of the somefile -> olddir/newfile rename in Topic_2.
test_expect_success 'dir rename unneeded, then rename existing file into old dir' '
	test_setup_upstream_rename dir-rename-unneeded-until-file-moved-inside &&
	(
		cd dir-rename-unneeded-until-file-moved-inside &&

		shit switch topic &&

		test_seq 3 10 >relevant-rename &&
		shit add relevant-rename &&
		shit commit -m A &&

		test_seq 1 10 >somefile &&
		shit add somefile &&
		shit mv somefile olddir/newfile &&
		shit commit -m B &&

		test_seq 1 12 >olddir/newfile &&
		shit add olddir/newfile &&
		shit commit -m C &&

		#
		# Actual testing
		#

		shit switch upstream &&
		shit config merge.directoryRenames true &&

		shit_TRACE2_PERF="$(pwd)/trace.output" &&
		export shit_TRACE2_PERF &&

		shit replay --onto HEAD upstream~1..topic >out &&
		shit update-ref --stdin <out &&
		shit checkout topic &&

		grep region_enter.*diffcore_rename trace.output >calls &&
		test_line_count = 3 calls &&

		test_path_is_missing somefile &&
		test_path_is_missing olddir/newfile &&
		test_path_is_file newdir/newfile &&
		shit ls-files >tracked &&
		test_line_count = 4 tracked
	)
'

# Helper for the next two tests
test_setup_topic_rename () {
	shit init $1 &&
	(
		cd $1 &&

		test_seq 3 8 >somefile &&
		mkdir olddir &&
		test_seq 3 8 >olddir/a &&
		echo b >olddir/b &&
		shit add olddir somefile &&
		shit commit -m orig &&

		shit branch upstream &&
		shit branch topic &&

		shit switch topic &&
		test_seq 1 8 >somefile &&
		test_seq 1 8 >olddir/a &&
		shit add somefile olddir/a &&
		shit mv olddir newdir &&
		shit commit -m "Dir renamed" &&

		test_seq 1 10 >somefile &&
		shit add somefile &&
		mkdir olddir &&
		>olddir/unrelated-file &&
		shit add olddir &&
		shit commit -m "Unrelated file in recreated old dir"
	)
}

#
# In the following testcase, the first commit on the topic branch renames
# a directory, while the second recreates the old directory and places a
# file into it:
#   Base:     somefile
#             olddir/a
#             olddir/b
#   Upstream: olddir/newfile
#   Topic_1:  somefile_2
#             rename olddir/ -> newdir/
#   Topic_2:  olddir/unrelated-file
#
# Note that the first pick should merge:
#   Base:     somefile
#             olddir/{a,b}
#   Upstream: olddir/newfile
#   Topic_1:  rename olddir/ -> newdir/
# For which the expected result (assuming merge.directoryRenames=true) is
# clearly:
#   Result:   somefile
#             newdir/{a, b, newfile}
#
# While the second pick does the following three-way merge:
#   Base (Topic_1):           somefile
#                             newdir/{a,b}
#   Upstream (Result from 1): same files as base, but adds newdir/newfile
#   Topic_2:                  same files as base, but adds olddir/unrelated-file
#
# The second merge is pretty trivial; upstream adds newdir/newfile, and
# topic_2 adds olddir/unrelated-file.  We're just testing that we don't
# accidentally cache directory renames somehow and rename
# olddir/unrelated-file to newdir/unrelated-file.
#
# This testcase should only need one call to diffcore_rename_extended().
test_expect_success 'caching renames only on upstream side, part 1' '
	test_setup_topic_rename cache-renames-only-upstream-add-file &&
	(
		cd cache-renames-only-upstream-add-file &&

		shit switch upstream &&

		>olddir/newfile &&
		shit add olddir/newfile &&
		shit commit -m "Add newfile" &&

		#
		# Actual testing
		#

		shit switch upstream &&

		shit config merge.directoryRenames true &&

		shit_TRACE2_PERF="$(pwd)/trace.output" &&
		export shit_TRACE2_PERF &&

		shit replay --onto HEAD upstream~1..topic >out &&
		shit update-ref --stdin <out &&
		shit checkout topic &&

		grep region_enter.*diffcore_rename trace.output >calls &&
		test_line_count = 1 calls &&

		shit ls-files >tracked &&
		test_line_count = 5 tracked &&
		test_path_is_missing newdir/unrelated-file &&
		test_path_is_file olddir/unrelated-file &&
		test_path_is_file newdir/newfile &&
		test_path_is_file newdir/b &&
		test_path_is_file newdir/a &&
		test_path_is_file somefile
	)
'

#
# The following testcase is *very* similar to the last one, but instead of
# adding a new olddir/newfile, it renames somefile -> olddir/newfile:
#   Base:     somefile
#             olddir/a
#             olddir/b
#   Upstream: somefile_1 -> olddir/newfile
#   Topic_1:  rename olddir/ -> newdir/
#             somefile_2
#   Topic_2:  olddir/unrelated-file
#             somefile_3
#
# Much like the previous test, this case is actually trivial and we are just
# making sure there isn't some spurious directory rename caching going on
# for the wrong side of history.
#
#
# This testcase should only need two calls to diffcore_rename_extended(),
# both for the first merge, one for each side of history.
#
test_expect_success 'caching renames only on upstream side, part 2' '
	test_setup_topic_rename cache-renames-only-upstream-rename-file &&
	(
		cd cache-renames-only-upstream-rename-file &&

		shit switch upstream &&

		shit mv somefile olddir/newfile &&
		shit commit -m "Add newfile" &&

		#
		# Actual testing
		#

		shit switch upstream &&

		shit config merge.directoryRenames true &&

		shit_TRACE2_PERF="$(pwd)/trace.output" &&
		export shit_TRACE2_PERF &&

		shit replay --onto HEAD upstream~1..topic >out &&
		shit update-ref --stdin <out &&
		shit checkout topic &&

		grep region_enter.*diffcore_rename trace.output >calls &&
		test_line_count = 2 calls &&

		shit ls-files >tracked &&
		test_line_count = 4 tracked &&
		test_path_is_missing newdir/unrelated-file &&
		test_path_is_file olddir/unrelated-file &&
		test_path_is_file newdir/newfile &&
		test_path_is_file newdir/b &&
		test_path_is_file newdir/a
	)
'

#
# The following testcase just creates two simple renames (slightly modified
# on both sides but without conflicting changes), and a directory full of
# files that are otherwise uninteresting.  The setup is as follows:
#
#   base:     unrelated/<BUNCH OF FILES>
#             numbers
#             values
#   upstream: modify: numbers
#             modify: values
#   topic:    add: unrelated/foo
#             modify: numbers
#             modify: values
#             rename: numbers -> sequence
#             rename: values -> progression
#
# This is a trivial rename case, but we're curious what happens with a very
# low renameLimit interacting with the restart optimization trying to notice
# that unrelated/ looks like a trivial merge candidate.
#
test_expect_success 'avoid assuming we detected renames' '
	shit init redo-weirdness &&
	(
		cd redo-weirdness &&

		mkdir unrelated &&
		for i in $(test_seq 1 10)
		do
			>unrelated/$i || exit 1
		done &&
		test_seq  2 10 >numbers &&
		test_seq 12 20 >values &&
		shit add numbers values unrelated/ &&
		shit commit -m orig &&

		shit branch upstream &&
		shit branch topic &&

		shit switch upstream &&
		test_seq  1 10 >numbers &&
		test_seq 11 20 >values &&
		shit add numbers &&
		shit commit -m "Some tweaks" &&

		shit switch topic &&

		>unrelated/foo &&
		test_seq  2 12 >numbers &&
		test_seq 12 22 >values &&
		shit add numbers values unrelated/ &&
		shit mv numbers sequence &&
		shit mv values progression &&
		shit commit -m A &&

		#
		# Actual testing
		#

		shit switch --detach topic^0 &&

		test_must_fail shit -c merge.renameLimit=1 rebase upstream &&

		shit ls-files -u >actual &&
		test_line_count = 2 actual
	)
'

test_done
