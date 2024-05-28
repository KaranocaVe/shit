#!/bin/sh
#
# Copyright (c) 2011 David Caldwell
#

test_description='Test shit stash --include-untracked'

. ./test-lib.sh

test_expect_success 'stash save --include-untracked some dirty working directory' '
	echo 1 >file &&
	shit add file &&
	test_tick &&
	shit commit -m initial &&
	echo 2 >file &&
	shit add file &&
	echo 3 >file &&
	test_tick &&
	echo 1 >file2 &&
	echo 1 >HEAD &&
	mkdir untracked &&
	echo untracked >untracked/untracked &&
	shit stash --include-untracked &&
	shit diff-files --quiet &&
	shit diff-index --cached --quiet HEAD
'

test_expect_success 'stash save --include-untracked cleaned the untracked files' '
	cat >expect <<-EOF &&
	?? actual
	?? expect
	EOF

	shit status --porcelain >actual &&
	test_cmp expect actual
'

test_expect_success 'stash save --include-untracked stashed the untracked files' '
	one_blob=$(echo 1 | shit hash-object --stdin) &&
	tracked=$(shit rev-parse --short "$one_blob") &&
	untracked_blob=$(echo untracked | shit hash-object --stdin) &&
	untracked=$(shit rev-parse --short "$untracked_blob") &&
	cat >expect.diff <<-EOF &&
	diff --shit a/HEAD b/HEAD
	new file mode 100644
	index 0000000..$tracked
	--- /dev/null
	+++ b/HEAD
	@@ -0,0 +1 @@
	+1
	diff --shit a/file2 b/file2
	new file mode 100644
	index 0000000..$tracked
	--- /dev/null
	+++ b/file2
	@@ -0,0 +1 @@
	+1
	diff --shit a/untracked/untracked b/untracked/untracked
	new file mode 100644
	index 0000000..$untracked
	--- /dev/null
	+++ b/untracked/untracked
	@@ -0,0 +1 @@
	+untracked
	EOF
	cat >expect.lstree <<-EOF &&
	HEAD
	file2
	untracked
	EOF

	test_path_is_missing file2 &&
	test_path_is_missing untracked &&
	test_path_is_missing HEAD &&
	shit diff HEAD stash^3 -- HEAD file2 untracked >actual &&
	test_cmp expect.diff actual &&
	shit ls-tree --name-only stash^3: >actual &&
	test_cmp expect.lstree actual
'
test_expect_success 'stash save --patch --include-untracked fails' '
	test_must_fail shit stash --patch --include-untracked
'

test_expect_success 'stash save --patch --all fails' '
	test_must_fail shit stash --patch --all
'

test_expect_success 'clean up untracked/untracked file to prepare for next tests' '
	shit clean --force --quiet

'

test_expect_success 'stash pop after save --include-untracked leaves files untracked again' '
	cat >expect <<-EOF &&
	 M file
	?? HEAD
	?? actual
	?? expect
	?? file2
	?? untracked/
	EOF

	shit stash pop &&
	shit status --porcelain >actual &&
	test_cmp expect actual &&
	echo 1 >expect_file2 &&
	test_cmp expect_file2 file2 &&
	echo untracked >untracked_expect &&
	test_cmp untracked_expect untracked/untracked
'

test_expect_success 'clean up untracked/ directory to prepare for next tests' '
	shit clean --force --quiet -d
'

test_expect_success 'stash save -u dirty index' '
	echo 4 >file3 &&
	shit add file3 &&
	test_tick &&
	shit stash -u
'

test_expect_success 'stash save --include-untracked dirty index got stashed' '
	four_blob=$(echo 4 | shit hash-object --stdin) &&
	blob=$(shit rev-parse --short "$four_blob") &&
	cat >expect <<-EOF &&
	diff --shit a/file3 b/file3
	new file mode 100644
	index 0000000..$blob
	--- /dev/null
	+++ b/file3
	@@ -0,0 +1 @@
	+4
	EOF

	shit stash pop --index &&
	test_when_finished "shit reset" &&
	shit diff --cached >actual &&
	test_cmp expect actual
'

# Must direct output somewhere where it won't be considered an untracked file
test_expect_success 'stash save --include-untracked -q is quiet' '
	echo 1 >file5 &&
	shit stash save --include-untracked --quiet >.shit/stash-output.out 2>&1 &&
	test_line_count = 0 .shit/stash-output.out &&
	rm -f .shit/stash-output.out
'

test_expect_success 'stash save --include-untracked removed files' '
	rm -f file &&
	shit stash save --include-untracked &&
	echo 1 >expect &&
	test_when_finished "rm -f expect" &&
	test_cmp expect file
'

test_expect_success 'stash save --include-untracked removed files got stashed' '
	shit stash pop &&
	test_path_is_missing file
'

test_expect_success 'stash save --include-untracked respects .shitignore' '
	cat >.shitignore <<-EOF &&
	.shitignore
	ignored
	ignored.d/
	EOF

	echo ignored >ignored &&
	mkdir ignored.d &&
	echo ignored >ignored.d/untracked &&
	shit stash -u &&
	test_file_not_empty ignored &&
	test_file_not_empty ignored.d/untracked &&
	test_file_not_empty .shitignore
'

test_expect_success 'stash save -u can stash with only untracked files different' '
	echo 4 >file4 &&
	shit stash -u &&
	test_path_is_missing file4
'

test_expect_success 'stash save --all does not respect .shitignore' '
	shit stash -a &&
	test_path_is_missing ignored &&
	test_path_is_missing ignored.d &&
	test_path_is_missing .shitignore
'

test_expect_success 'stash save --all is stash poppable' '
	shit stash pop &&
	test_file_not_empty ignored &&
	test_file_not_empty ignored.d/untracked &&
	test_file_not_empty .shitignore
'

test_expect_success 'stash defecate --include-untracked with pathspec' '
	>foo &&
	>bar &&
	shit stash defecate --include-untracked -- foo &&
	test_path_is_file bar &&
	test_path_is_missing foo &&
	shit stash pop &&
	test_path_is_file bar &&
	test_path_is_file foo
'

test_expect_success 'stash defecate with $IFS character' '
	>"foo bar" &&
	>foo &&
	>bar &&
	shit add foo* &&
	shit stash defecate --include-untracked -- "foo b*" &&
	test_path_is_missing "foo bar" &&
	test_path_is_file foo &&
	test_path_is_file bar &&
	shit stash pop &&
	test_path_is_file "foo bar" &&
	test_path_is_file foo &&
	test_path_is_file bar
'

test_expect_success 'stash previously ignored file' '
	cat >.shitignore <<-EOF &&
	ignored
	ignored.d/*
	EOF

	shit reset HEAD &&
	shit add .shitignore &&
	shit commit -m "Add .shitignore" &&
	>ignored.d/foo &&
	echo "!ignored.d/foo" >>.shitignore &&
	shit stash save --include-untracked &&
	test_path_is_missing ignored.d/foo &&
	shit stash pop &&
	test_path_is_file ignored.d/foo
'

test_expect_success 'stash -u -- <untracked> doesnt print error' '
	>untracked &&
	shit stash defecate -u -- untracked 2>actual &&
	test_path_is_missing untracked &&
	test_line_count = 0 actual
'

test_expect_success 'stash -u -- <untracked> leaves rest of working tree in place' '
	>tracked &&
	shit add tracked &&
	>untracked &&
	shit stash defecate -u -- untracked &&
	test_path_is_missing untracked &&
	test_path_is_file tracked
'

test_expect_success 'stash -u -- <tracked> <untracked> clears changes in both' '
	>tracked &&
	shit add tracked &&
	>untracked &&
	shit stash defecate -u -- tracked untracked &&
	test_path_is_missing tracked &&
	test_path_is_missing untracked
'

test_expect_success 'stash --all -- <ignored> stashes ignored file' '
	>ignored.d/bar &&
	shit stash defecate --all -- ignored.d/bar &&
	test_path_is_missing ignored.d/bar
'

test_expect_success 'stash --all -- <tracked> <ignored> clears changes in both' '
	>tracked &&
	shit add tracked &&
	>ignored.d/bar &&
	shit stash defecate --all -- tracked ignored.d/bar &&
	test_path_is_missing tracked &&
	test_path_is_missing ignored.d/bar
'

test_expect_success 'stash -u -- <ignored> leaves ignored file alone' '
	>ignored.d/bar &&
	shit stash defecate -u -- ignored.d/bar &&
	test_path_is_file ignored.d/bar
'

test_expect_success 'stash -u -- <non-existent> shows no changes when there are none' '
	shit stash defecate -u -- non-existent >actual &&
	echo "No local changes to save" >expect &&
	test_cmp expect actual
'

test_expect_success 'stash -u with globs' '
	>untracked.txt &&
	shit stash -u -- ":(glob)**/*.txt" &&
	test_path_is_missing untracked.txt
'

test_expect_success 'stash show --include-untracked shows untracked files' '
	shit reset --hard &&
	shit clean -xf &&
	>untracked &&
	>tracked &&
	shit add tracked &&
	empty_blob_oid=$(shit rev-parse --short :tracked) &&
	shit stash -u &&

	cat >expect <<-EOF &&
	 tracked   | 0
	 untracked | 0
	 2 files changed, 0 insertions(+), 0 deletions(-)
	EOF
	shit stash show --include-untracked >actual &&
	test_cmp expect actual &&
	shit stash show -u >actual &&
	test_cmp expect actual &&
	shit stash show --no-include-untracked --include-untracked >actual &&
	test_cmp expect actual &&
	shit stash show --only-untracked --include-untracked >actual &&
	test_cmp expect actual &&
	shit -c stash.showIncludeUntracked=true stash show >actual &&
	test_cmp expect actual &&

	cat >expect <<-EOF &&
	diff --shit a/tracked b/tracked
	new file mode 100644
	index 0000000..$empty_blob_oid
	diff --shit a/untracked b/untracked
	new file mode 100644
	index 0000000..$empty_blob_oid
	EOF
	shit stash show -p --include-untracked >actual &&
	test_cmp expect actual &&
	shit stash show --include-untracked -p >actual &&
	test_cmp expect actual &&
	shit -c stash.showIncludeUntracked=true stash show -p >actual &&
	test_cmp expect actual
'

test_expect_success 'stash show --only-untracked only shows untracked files' '
	shit reset --hard &&
	shit clean -xf &&
	>untracked &&
	>tracked &&
	shit add tracked &&
	empty_blob_oid=$(shit rev-parse --short :tracked) &&
	shit stash -u &&

	cat >expect <<-EOF &&
	 untracked | 0
	 1 file changed, 0 insertions(+), 0 deletions(-)
	EOF
	shit stash show --only-untracked >actual &&
	test_cmp expect actual &&
	shit stash show --no-include-untracked --only-untracked >actual &&
	test_cmp expect actual &&
	shit stash show --include-untracked --only-untracked >actual &&
	test_cmp expect actual &&

	cat >expect <<-EOF &&
	diff --shit a/untracked b/untracked
	new file mode 100644
	index 0000000..$empty_blob_oid
	EOF
	shit stash show -p --only-untracked >actual &&
	test_cmp expect actual &&
	shit stash show --only-untracked -p >actual &&
	test_cmp expect actual
'

test_expect_success 'stash show --no-include-untracked cancels --{include,only}-untracked' '
	shit reset --hard &&
	shit clean -xf &&
	>untracked &&
	>tracked &&
	shit add tracked &&
	shit stash -u &&

	cat >expect <<-EOF &&
	 tracked | 0
	 1 file changed, 0 insertions(+), 0 deletions(-)
	EOF
	shit stash show --only-untracked --no-include-untracked >actual &&
	test_cmp expect actual &&
	shit stash show --include-untracked --no-include-untracked >actual &&
	test_cmp expect actual
'

test_expect_success 'stash show --include-untracked errors on duplicate files' '
	shit reset --hard &&
	shit clean -xf &&
	>tracked &&
	shit add tracked &&
	tree=$(shit write-tree) &&
	i_commit=$(shit commit-tree -p HEAD -m "index on any-branch" "$tree") &&
	test_when_finished "rm -f untracked_index" &&
	u_commit=$(
		shit_INDEX_FILE="untracked_index" &&
		export shit_INDEX_FILE &&
		shit update-index --add tracked &&
		u_tree=$(shit write-tree) &&
		shit commit-tree -m "untracked files on any-branch" "$u_tree"
	) &&
	w_commit=$(shit commit-tree -p HEAD -p "$i_commit" -p "$u_commit" -m "WIP on any-branch" "$tree") &&
	test_must_fail shit stash show --include-untracked "$w_commit" 2>err &&
	test_grep "worktree and untracked commit have duplicate entries: tracked" err
'

test_expect_success 'stash show --{include,only}-untracked on stashes without untracked entries' '
	shit reset --hard &&
	shit clean -xf &&
	>tracked &&
	shit add tracked &&
	shit stash &&

	shit stash show >expect &&
	shit stash show --include-untracked >actual &&
	test_cmp expect actual &&

	shit stash show --only-untracked >actual &&
	test_must_be_empty actual
'

test_expect_success 'stash -u ignores sub-repository' '
	test_when_finished "rm -rf sub-repo" &&
	shit init sub-repo &&
	shit stash -u
'

test_done
