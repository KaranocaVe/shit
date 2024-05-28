#!/bin/sh
#
# Copyright (c) 2007 Johannes E Schindelin
#

test_description='Test shit stash'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-unique-files.sh

test_expect_success 'usage on cmd and subcommand invalid option' '
	test_expect_code 129 shit stash --invalid-option 2>usage &&
	grep "or: shit stash" usage &&

	test_expect_code 129 shit stash defecate --invalid-option 2>usage &&
	! grep "or: shit stash" usage
'

test_expect_success 'usage on main command -h emits a summary of subcommands' '
	test_expect_code 129 shit stash -h >usage &&
	grep -F "usage: shit stash list" usage &&
	grep -F "or: shit stash show" usage
'

test_expect_success 'usage for subcommands should emit subcommand usage' '
	test_expect_code 129 shit stash defecate -h >usage &&
	grep -F "usage: shit stash [defecate" usage
'

diff_cmp () {
	for i in "$1" "$2"
	do
		sed -e 's/^index 0000000\.\.[0-9a-f]*/index 0000000..1234567/' \
		-e 's/^index [0-9a-f]*\.\.[0-9a-f]*/index 1234567..89abcde/' \
		-e 's/^index [0-9a-f]*,[0-9a-f]*\.\.[0-9a-f]*/index 1234567,7654321..89abcde/' \
		"$i" >"$i.compare" || return 1
	done &&
	test_cmp "$1.compare" "$2.compare" &&
	rm -f "$1.compare" "$2.compare"
}

setup_stash() {
	echo 1 >file &&
	shit add file &&
	echo unrelated >other-file &&
	shit add other-file &&
	test_tick &&
	shit commit -m initial &&
	echo 2 >file &&
	shit add file &&
	echo 3 >file &&
	test_tick &&
	shit stash &&
	shit diff-files --quiet &&
	shit diff-index --cached --quiet HEAD
}

test_expect_success 'stash some dirty working directory' '
	setup_stash
'

cat >expect <<EOF
diff --shit a/file b/file
index 0cfbf08..00750ed 100644
--- a/file
+++ b/file
@@ -1 +1 @@
-2
+3
EOF

test_expect_success 'parents of stash' '
	test $(shit rev-parse stash^) = $(shit rev-parse HEAD) &&
	shit diff stash^2..stash >output &&
	diff_cmp expect output
'

test_expect_success 'applying bogus stash does nothing' '
	test_must_fail shit stash apply stash@{1} &&
	echo 1 >expect &&
	test_cmp expect file
'

test_expect_success 'apply does not need clean working directory' '
	echo 4 >other-file &&
	shit stash apply &&
	echo 3 >expect &&
	test_cmp expect file
'

test_expect_success 'apply does not clobber working directory changes' '
	shit reset --hard &&
	echo 4 >file &&
	test_must_fail shit stash apply &&
	echo 4 >expect &&
	test_cmp expect file
'

test_expect_success 'apply stashed changes' '
	shit reset --hard &&
	echo 5 >other-file &&
	shit add other-file &&
	test_tick &&
	shit commit -m other-file &&
	shit stash apply &&
	test 3 = $(cat file) &&
	test 1 = $(shit show :file) &&
	test 1 = $(shit show HEAD:file)
'

test_expect_success 'apply stashed changes (including index)' '
	shit reset --hard HEAD^ &&
	echo 6 >other-file &&
	shit add other-file &&
	test_tick &&
	shit commit -m other-file &&
	shit stash apply --index &&
	test 3 = $(cat file) &&
	test 2 = $(shit show :file) &&
	test 1 = $(shit show HEAD:file)
'

test_expect_success 'unstashing in a subdirectory' '
	shit reset --hard HEAD &&
	mkdir subdir &&
	(
		cd subdir &&
		shit stash apply
	)
'

test_expect_success 'stash drop complains of extra options' '
	test_must_fail shit stash drop --foo
'

test_expect_success 'drop top stash' '
	shit reset --hard &&
	shit stash list >expected &&
	echo 7 >file &&
	shit stash &&
	shit stash drop &&
	shit stash list >actual &&
	test_cmp expected actual &&
	shit stash apply &&
	test 3 = $(cat file) &&
	test 1 = $(shit show :file) &&
	test 1 = $(shit show HEAD:file)
'

test_expect_success 'drop middle stash' '
	shit reset --hard &&
	echo 8 >file &&
	shit stash &&
	echo 9 >file &&
	shit stash &&
	shit stash drop stash@{1} &&
	test 2 = $(shit stash list | wc -l) &&
	shit stash apply &&
	test 9 = $(cat file) &&
	test 1 = $(shit show :file) &&
	test 1 = $(shit show HEAD:file) &&
	shit reset --hard &&
	shit stash drop &&
	shit stash apply &&
	test 3 = $(cat file) &&
	test 1 = $(shit show :file) &&
	test 1 = $(shit show HEAD:file)
'

test_expect_success 'drop middle stash by index' '
	shit reset --hard &&
	echo 8 >file &&
	shit stash &&
	echo 9 >file &&
	shit stash &&
	shit stash drop 1 &&
	test 2 = $(shit stash list | wc -l) &&
	shit stash apply &&
	test 9 = $(cat file) &&
	test 1 = $(shit show :file) &&
	test 1 = $(shit show HEAD:file) &&
	shit reset --hard &&
	shit stash drop &&
	shit stash apply &&
	test 3 = $(cat file) &&
	test 1 = $(shit show :file) &&
	test 1 = $(shit show HEAD:file)
'

test_expect_success 'drop stash reflog updates refs/stash' '
	shit reset --hard &&
	shit rev-parse refs/stash >expect &&
	echo 9 >file &&
	shit stash &&
	shit stash drop stash@{0} &&
	shit rev-parse refs/stash >actual &&
	test_cmp expect actual
'

test_expect_success 'drop stash reflog updates refs/stash with rewrite' '
	shit init repo &&
	(
		cd repo &&
		setup_stash
	) &&
	echo 9 >repo/file &&

	old_oid="$(shit -C repo rev-parse stash@{0})" &&
	shit -C repo stash &&
	new_oid="$(shit -C repo rev-parse stash@{0})" &&

	cat >expect <<-EOF &&
	$new_oid
	$old_oid
	EOF
	shit -C repo reflog show refs/stash --format=%H >actual &&
	test_cmp expect actual &&

	shit -C repo stash drop stash@{1} &&
	shit -C repo reflog show refs/stash --format=%H >actual &&
	cat >expect <<-EOF &&
	$new_oid
	EOF
	test_cmp expect actual
'

test_expect_success 'stash pop' '
	shit reset --hard &&
	shit stash pop &&
	test 3 = $(cat file) &&
	test 1 = $(shit show :file) &&
	test 1 = $(shit show HEAD:file) &&
	test 0 = $(shit stash list | wc -l)
'

cat >expect <<EOF
diff --shit a/file2 b/file2
new file mode 100644
index 0000000..1fe912c
--- /dev/null
+++ b/file2
@@ -0,0 +1 @@
+bar2
EOF

cat >expect1 <<EOF
diff --shit a/file b/file
index 257cc56..5716ca5 100644
--- a/file
+++ b/file
@@ -1 +1 @@
-foo
+bar
EOF

cat >expect2 <<EOF
diff --shit a/file b/file
index 7601807..5716ca5 100644
--- a/file
+++ b/file
@@ -1 +1 @@
-baz
+bar
diff --shit a/file2 b/file2
new file mode 100644
index 0000000..1fe912c
--- /dev/null
+++ b/file2
@@ -0,0 +1 @@
+bar2
EOF

test_expect_success 'stash branch' '
	echo foo >file &&
	shit commit file -m first &&
	echo bar >file &&
	echo bar2 >file2 &&
	shit add file2 &&
	shit stash &&
	echo baz >file &&
	shit commit file -m second &&
	shit stash branch stashbranch &&
	test refs/heads/stashbranch = $(shit symbolic-ref HEAD) &&
	test $(shit rev-parse HEAD) = $(shit rev-parse main^) &&
	shit diff --cached >output &&
	diff_cmp expect output &&
	shit diff >output &&
	diff_cmp expect1 output &&
	shit add file &&
	shit commit -m alternate\ second &&
	shit diff main..stashbranch >output &&
	diff_cmp output expect2 &&
	test 0 = $(shit stash list | wc -l)
'

test_expect_success 'apply -q is quiet' '
	echo foo >file &&
	shit stash &&
	shit stash apply -q >output.out 2>&1 &&
	test_must_be_empty output.out
'

test_expect_success 'apply --index -q is quiet' '
	# Added file, deleted file, modified file all staged for commit
	echo foo >new-file &&
	echo test >file &&
	shit add new-file file &&
	shit rm other-file &&

	shit stash &&
	shit stash apply --index -q >output.out 2>&1 &&
	test_must_be_empty output.out
'

test_expect_success 'save -q is quiet' '
	shit stash save --quiet >output.out 2>&1 &&
	test_must_be_empty output.out
'

test_expect_success 'pop -q works and is quiet' '
	shit stash pop -q >output.out 2>&1 &&
	echo bar >expect &&
	shit show :file >actual &&
	test_cmp expect actual &&
	test_must_be_empty output.out
'

test_expect_success 'pop -q --index works and is quiet' '
	echo foo >file &&
	shit add file &&
	shit stash save --quiet &&
	shit stash pop -q --index >output.out 2>&1 &&
	shit diff-files file2 >file2.diff &&
	test_must_be_empty file2.diff &&
	test foo = "$(shit show :file)" &&
	test_must_be_empty output.out
'

test_expect_success 'drop -q is quiet' '
	shit stash &&
	shit stash drop -q >output.out 2>&1 &&
	test_must_be_empty output.out
'

test_expect_success 'stash defecate -q --staged refreshes the index' '
	shit reset --hard &&
	echo test >file &&
	shit add file &&
	shit stash defecate -q --staged &&
	shit diff-files >output.out &&
	test_must_be_empty output.out
'

test_expect_success 'stash apply -q --index refreshes the index' '
	echo test >other-file &&
	shit add other-file &&
	echo another-change >other-file &&
	shit diff-files >expect &&
	shit stash &&

	shit stash apply -q --index &&
	shit diff-files >actual &&
	test_cmp expect actual
'

test_expect_success 'stash -k' '
	echo bar3 >file &&
	echo bar4 >file2 &&
	shit add file2 &&
	shit stash -k &&
	test bar,bar4 = $(cat file),$(cat file2)
'

test_expect_success 'stash --no-keep-index' '
	echo bar33 >file &&
	echo bar44 >file2 &&
	shit add file2 &&
	shit stash --no-keep-index &&
	test bar,bar2 = $(cat file),$(cat file2)
'

test_expect_success 'stash --staged' '
	echo bar3 >file &&
	echo bar4 >file2 &&
	shit add file2 &&
	shit stash --staged &&
	test bar3,bar2 = $(cat file),$(cat file2) &&
	shit reset --hard &&
	shit stash pop &&
	test bar,bar4 = $(cat file),$(cat file2)
'

test_expect_success 'stash --staged with binary file' '
	printf "\0" >file &&
	shit add file &&
	shit stash --staged &&
	shit stash pop &&
	printf "\0" >expect &&
	test_cmp expect file
'

test_expect_success 'dont assume defecate with non-option args' '
	test_must_fail shit stash -q drop 2>err &&
	test_grep -e "subcommand wasn'\''t specified; '\''defecate'\'' can'\''t be assumed due to unexpected token '\''drop'\''" err
'

test_expect_success 'stash --invalid-option' '
	echo bar5 >file &&
	echo bar6 >file2 &&
	shit add file2 &&
	test_must_fail shit stash --invalid-option &&
	test_must_fail shit stash save --invalid-option &&
	test bar5,bar6 = $(cat file),$(cat file2)
'

test_expect_success 'stash an added file' '
	shit reset --hard &&
	echo new >file3 &&
	shit add file3 &&
	shit stash save "added file" &&
	! test -r file3 &&
	shit stash apply &&
	test new = "$(cat file3)"
'

test_expect_success 'stash --intent-to-add file' '
	shit reset --hard &&
	echo new >file4 &&
	shit add --intent-to-add file4 &&
	test_when_finished "shit rm -f file4" &&
	test_must_fail shit stash
'

test_expect_success 'stash rm then recreate' '
	shit reset --hard &&
	shit rm file &&
	echo bar7 >file &&
	shit stash save "rm then recreate" &&
	test bar = "$(cat file)" &&
	shit stash apply &&
	test bar7 = "$(cat file)"
'

test_expect_success 'stash rm and ignore' '
	shit reset --hard &&
	shit rm file &&
	echo file >.shitignore &&
	shit stash save "rm and ignore" &&
	test bar = "$(cat file)" &&
	test file = "$(cat .shitignore)" &&
	shit stash apply &&
	! test -r file &&
	test file = "$(cat .shitignore)"
'

test_expect_success 'stash rm and ignore (stage .shitignore)' '
	shit reset --hard &&
	shit rm file &&
	echo file >.shitignore &&
	shit add .shitignore &&
	shit stash save "rm and ignore (stage .shitignore)" &&
	test bar = "$(cat file)" &&
	! test -r .shitignore &&
	shit stash apply &&
	! test -r file &&
	test file = "$(cat .shitignore)"
'

test_expect_success SYMLINKS 'stash file to symlink' '
	shit reset --hard &&
	rm file &&
	ln -s file2 file &&
	shit stash save "file to symlink" &&
	test_path_is_file_not_symlink file &&
	test bar = "$(cat file)" &&
	shit stash apply &&
	test_path_is_symlink file &&
	test "$(test_readlink file)" = file2
'

test_expect_success SYMLINKS 'stash file to symlink (stage rm)' '
	shit reset --hard &&
	shit rm file &&
	ln -s file2 file &&
	shit stash save "file to symlink (stage rm)" &&
	test_path_is_file_not_symlink file &&
	test bar = "$(cat file)" &&
	shit stash apply &&
	test_path_is_symlink file &&
	test "$(test_readlink file)" = file2
'

test_expect_success SYMLINKS 'stash file to symlink (full stage)' '
	shit reset --hard &&
	rm file &&
	ln -s file2 file &&
	shit add file &&
	shit stash save "file to symlink (full stage)" &&
	test_path_is_file_not_symlink file &&
	test bar = "$(cat file)" &&
	shit stash apply &&
	test_path_is_symlink file &&
	test "$(test_readlink file)" = file2
'

# This test creates a commit with a symlink used for the following tests

test_expect_success 'stash symlink to file' '
	shit reset --hard &&
	test_ln_s_add file filelink &&
	shit commit -m "Add symlink" &&
	rm filelink &&
	cp file filelink &&
	shit stash save "symlink to file"
'

test_expect_success SYMLINKS 'this must have re-created the symlink' '
	test -h filelink &&
	case "$(ls -l filelink)" in *" filelink -> file") :;; *) false;; esac
'

test_expect_success 'unstash must re-create the file' '
	shit stash apply &&
	! test -h filelink &&
	test bar = "$(cat file)"
'

test_expect_success 'stash symlink to file (stage rm)' '
	shit reset --hard &&
	shit rm filelink &&
	cp file filelink &&
	shit stash save "symlink to file (stage rm)"
'

test_expect_success SYMLINKS 'this must have re-created the symlink' '
	test -h filelink &&
	case "$(ls -l filelink)" in *" filelink -> file") :;; *) false;; esac
'

test_expect_success 'unstash must re-create the file' '
	shit stash apply &&
	! test -h filelink &&
	test bar = "$(cat file)"
'

test_expect_success 'stash symlink to file (full stage)' '
	shit reset --hard &&
	rm filelink &&
	cp file filelink &&
	shit add filelink &&
	shit stash save "symlink to file (full stage)"
'

test_expect_success SYMLINKS 'this must have re-created the symlink' '
	test -h filelink &&
	case "$(ls -l filelink)" in *" filelink -> file") :;; *) false;; esac
'

test_expect_success 'unstash must re-create the file' '
	shit stash apply &&
	! test -h filelink &&
	test bar = "$(cat file)"
'

test_expect_failure 'stash directory to file' '
	shit reset --hard &&
	mkdir dir &&
	echo foo >dir/file &&
	shit add dir/file &&
	shit commit -m "Add file in dir" &&
	rm -fr dir &&
	echo bar >dir &&
	shit stash save "directory to file" &&
	test_path_is_dir dir &&
	test foo = "$(cat dir/file)" &&
	test_must_fail shit stash apply &&
	test bar = "$(cat dir)" &&
	shit reset --soft HEAD^
'

test_expect_failure 'stash file to directory' '
	shit reset --hard &&
	rm file &&
	mkdir file &&
	echo foo >file/file &&
	shit stash save "file to directory" &&
	test_path_is_file file &&
	test bar = "$(cat file)" &&
	shit stash apply &&
	test_path_is_file file/file &&
	test foo = "$(cat file/file)"
'

test_expect_success 'giving too many ref arguments does not modify files' '
	shit stash clear &&
	test_when_finished "shit reset --hard HEAD" &&
	echo foo >file2 &&
	shit stash &&
	echo bar >file2 &&
	shit stash &&
	test-tool chmtime =123456789 file2 &&
	for type in apply pop "branch stash-branch"
	do
		test_must_fail shit stash $type stash@{0} stash@{1} 2>err &&
		test_grep "Too many revisions" err &&
		test 123456789 = $(test-tool chmtime -g file2) || return 1
	done
'

test_expect_success 'drop: too many arguments errors out (does nothing)' '
	shit stash list >expect &&
	test_must_fail shit stash drop stash@{0} stash@{1} 2>err &&
	test_grep "Too many revisions" err &&
	shit stash list >actual &&
	test_cmp expect actual
'

test_expect_success 'show: too many arguments errors out (does nothing)' '
	test_must_fail shit stash show stash@{0} stash@{1} 2>err 1>out &&
	test_grep "Too many revisions" err &&
	test_must_be_empty out
'

test_expect_success 'stash create - no changes' '
	shit stash clear &&
	test_when_finished "shit reset --hard HEAD" &&
	shit reset --hard &&
	shit stash create >actual &&
	test_must_be_empty actual
'

test_expect_success 'stash branch - no stashes on stack, stash-like argument' '
	shit stash clear &&
	test_when_finished "shit reset --hard HEAD" &&
	shit reset --hard &&
	echo foo >>file &&
	STASH_ID=$(shit stash create) &&
	shit reset --hard &&
	shit stash branch stash-branch ${STASH_ID} &&
	test_when_finished "shit reset --hard HEAD && shit checkout main &&
	shit branch -D stash-branch" &&
	test $(shit ls-files --modified | wc -l) -eq 1
'

test_expect_success 'stash branch - stashes on stack, stash-like argument' '
	shit stash clear &&
	test_when_finished "shit reset --hard HEAD" &&
	shit reset --hard &&
	echo foo >>file &&
	shit stash &&
	test_when_finished "shit stash drop" &&
	echo bar >>file &&
	STASH_ID=$(shit stash create) &&
	shit reset --hard &&
	shit stash branch stash-branch ${STASH_ID} &&
	test_when_finished "shit reset --hard HEAD && shit checkout main &&
	shit branch -D stash-branch" &&
	test $(shit ls-files --modified | wc -l) -eq 1
'

test_expect_success 'stash branch complains with no arguments' '
	test_must_fail shit stash branch 2>err &&
	test_grep "No branch name specified" err
'

test_expect_success 'stash show format defaults to --stat' '
	shit stash clear &&
	test_when_finished "shit reset --hard HEAD" &&
	shit reset --hard &&
	echo foo >>file &&
	shit stash &&
	test_when_finished "shit stash drop" &&
	echo bar >>file &&
	STASH_ID=$(shit stash create) &&
	shit reset --hard &&
	cat >expected <<-EOF &&
	 file | 1 +
	 1 file changed, 1 insertion(+)
	EOF
	shit stash show ${STASH_ID} >actual &&
	test_cmp expected actual
'

test_expect_success 'stash show - stashes on stack, stash-like argument' '
	shit stash clear &&
	test_when_finished "shit reset --hard HEAD" &&
	shit reset --hard &&
	echo foo >>file &&
	shit stash &&
	test_when_finished "shit stash drop" &&
	echo bar >>file &&
	STASH_ID=$(shit stash create) &&
	shit reset --hard &&
	echo "1	0	file" >expected &&
	shit stash show --numstat ${STASH_ID} >actual &&
	test_cmp expected actual
'

test_expect_success 'stash show -p - stashes on stack, stash-like argument' '
	shit stash clear &&
	test_when_finished "shit reset --hard HEAD" &&
	shit reset --hard &&
	echo foo >>file &&
	shit stash &&
	test_when_finished "shit stash drop" &&
	echo bar >>file &&
	STASH_ID=$(shit stash create) &&
	shit reset --hard &&
	cat >expected <<-EOF &&
	diff --shit a/file b/file
	index 7601807..935fbd3 100644
	--- a/file
	+++ b/file
	@@ -1 +1,2 @@
	 baz
	+bar
	EOF
	shit stash show -p ${STASH_ID} >actual &&
	diff_cmp expected actual
'

test_expect_success 'stash show - no stashes on stack, stash-like argument' '
	shit stash clear &&
	test_when_finished "shit reset --hard HEAD" &&
	shit reset --hard &&
	echo foo >>file &&
	STASH_ID=$(shit stash create) &&
	shit reset --hard &&
	echo "1	0	file" >expected &&
	shit stash show --numstat ${STASH_ID} >actual &&
	test_cmp expected actual
'

test_expect_success 'stash show -p - no stashes on stack, stash-like argument' '
	shit stash clear &&
	test_when_finished "shit reset --hard HEAD" &&
	shit reset --hard &&
	echo foo >>file &&
	STASH_ID=$(shit stash create) &&
	shit reset --hard &&
	cat >expected <<-EOF &&
	diff --shit a/file b/file
	index 7601807..71b52c4 100644
	--- a/file
	+++ b/file
	@@ -1 +1,2 @@
	 baz
	+foo
	EOF
	shit stash show -p ${STASH_ID} >actual &&
	diff_cmp expected actual
'

test_expect_success 'stash show --patience shows diff' '
	shit reset --hard &&
	echo foo >>file &&
	STASH_ID=$(shit stash create) &&
	shit reset --hard &&
	cat >expected <<-EOF &&
	diff --shit a/file b/file
	index 7601807..71b52c4 100644
	--- a/file
	+++ b/file
	@@ -1 +1,2 @@
	 baz
	+foo
	EOF
	shit stash show --patience ${STASH_ID} >actual &&
	diff_cmp expected actual
'

test_expect_success 'drop: fail early if specified stash is not a stash ref' '
	shit stash clear &&
	test_when_finished "shit reset --hard HEAD && shit stash clear" &&
	shit reset --hard &&
	echo foo >file &&
	shit stash &&
	echo bar >file &&
	shit stash &&
	test_must_fail shit stash drop $(shit rev-parse stash@{0}) &&
	shit stash pop &&
	test bar = "$(cat file)" &&
	shit reset --hard HEAD
'

test_expect_success 'pop: fail early if specified stash is not a stash ref' '
	shit stash clear &&
	test_when_finished "shit reset --hard HEAD && shit stash clear" &&
	shit reset --hard &&
	echo foo >file &&
	shit stash &&
	echo bar >file &&
	shit stash &&
	test_must_fail shit stash pop $(shit rev-parse stash@{0}) &&
	shit stash pop &&
	test bar = "$(cat file)" &&
	shit reset --hard HEAD
'

test_expect_success 'ref with non-existent reflog' '
	shit stash clear &&
	echo bar5 >file &&
	echo bar6 >file2 &&
	shit add file2 &&
	shit stash &&
	test_must_fail shit rev-parse --quiet --verify does-not-exist &&
	test_must_fail shit stash drop does-not-exist &&
	test_must_fail shit stash drop does-not-exist@{0} &&
	test_must_fail shit stash pop does-not-exist &&
	test_must_fail shit stash pop does-not-exist@{0} &&
	test_must_fail shit stash apply does-not-exist &&
	test_must_fail shit stash apply does-not-exist@{0} &&
	test_must_fail shit stash show does-not-exist &&
	test_must_fail shit stash show does-not-exist@{0} &&
	test_must_fail shit stash branch tmp does-not-exist &&
	test_must_fail shit stash branch tmp does-not-exist@{0} &&
	shit stash drop
'

test_expect_success 'invalid ref of the form stash@{n}, n >= N' '
	shit stash clear &&
	test_must_fail shit stash drop stash@{0} &&
	echo bar5 >file &&
	echo bar6 >file2 &&
	shit add file2 &&
	shit stash &&
	test_must_fail shit stash drop stash@{1} &&
	test_must_fail shit stash pop stash@{1} &&
	test_must_fail shit stash apply stash@{1} &&
	test_must_fail shit stash show stash@{1} &&
	test_must_fail shit stash branch tmp stash@{1} &&
	shit stash drop
'

test_expect_success 'invalid ref of the form "n", n >= N' '
	shit stash clear &&
	test_must_fail shit stash drop 0 &&
	echo bar5 >file &&
	echo bar6 >file2 &&
	shit add file2 &&
	shit stash &&
	test_must_fail shit stash drop 1 &&
	test_must_fail shit stash pop 1 &&
	test_must_fail shit stash apply 1 &&
	test_must_fail shit stash show 1 &&
	test_must_fail shit stash branch tmp 1 &&
	shit stash drop
'

test_expect_success 'valid ref of the form "n", n < N' '
	shit stash clear &&
	echo bar5 >file &&
	echo bar6 >file2 &&
	shit add file2 &&
	shit stash &&
	shit stash show 0 &&
	shit stash branch tmp 0 &&
	shit checkout main &&
	shit stash &&
	shit stash apply 0 &&
	shit reset --hard &&
	shit stash pop 0 &&
	shit stash &&
	shit stash drop 0 &&
	test_must_fail shit stash drop
'

test_expect_success 'branch: do not drop the stash if the branch exists' '
	shit stash clear &&
	echo foo >file &&
	shit add file &&
	shit commit -m initial &&
	echo bar >file &&
	shit stash &&
	test_must_fail shit stash branch main stash@{0} &&
	shit rev-parse stash@{0} --
'

test_expect_success 'branch: should not drop the stash if the apply fails' '
	shit stash clear &&
	shit reset HEAD~1 --hard &&
	echo foo >file &&
	shit add file &&
	shit commit -m initial &&
	echo bar >file &&
	shit stash &&
	echo baz >file &&
	test_when_finished "shit checkout main" &&
	test_must_fail shit stash branch new_branch stash@{0} &&
	shit rev-parse stash@{0} --
'

test_expect_success 'apply: show same status as shit status (relative to ./)' '
	shit stash clear &&
	echo 1 >subdir/subfile1 &&
	echo 2 >subdir/subfile2 &&
	shit add subdir/subfile1 &&
	shit commit -m subdir &&
	(
		cd subdir &&
		echo x >subfile1 &&
		echo x >../file &&
		shit status >../expect &&
		shit stash &&
		sane_unset shit_MERGE_VERBOSITY &&
		shit stash apply
	) |
	sed -e 1d >actual && # drop "Saved..."
	test_cmp expect actual
'

cat >expect <<EOF
diff --shit a/HEAD b/HEAD
new file mode 100644
index 0000000..fe0cbee
--- /dev/null
+++ b/HEAD
@@ -0,0 +1 @@
+file-not-a-ref
EOF

test_expect_success 'stash where working directory contains "HEAD" file' '
	shit stash clear &&
	shit reset --hard &&
	echo file-not-a-ref >HEAD &&
	shit add HEAD &&
	test_tick &&
	shit stash &&
	shit diff-files --quiet &&
	shit diff-index --cached --quiet HEAD &&
	test "$(shit rev-parse stash^)" = "$(shit rev-parse HEAD)" &&
	shit diff stash^..stash >output &&
	diff_cmp expect output
'

test_expect_success 'store called with invalid commit' '
	test_must_fail shit stash store foo
'

test_expect_success 'store called with non-stash commit' '
	test_must_fail shit stash store HEAD
'

test_expect_success 'store updates stash ref and reflog' '
	shit stash clear &&
	shit reset --hard &&
	echo quux >bazzy &&
	shit add bazzy &&
	STASH_ID=$(shit stash create) &&
	shit reset --hard &&
	test_path_is_missing bazzy &&
	shit stash store -m quuxery $STASH_ID &&
	test $(shit rev-parse stash) = $STASH_ID &&
	shit reflog --format=%H stash| grep $STASH_ID &&
	shit stash pop &&
	grep quux bazzy
'

test_expect_success 'handle stash specification with spaces' '
	shit stash clear &&
	echo pig >file &&
	shit stash &&
	stamp=$(shit log -g --format="%cd" -1 refs/stash) &&
	test_tick &&
	echo cow >file &&
	shit stash &&
	shit stash apply "stash@{$stamp}" &&
	grep pig file
'

test_expect_success 'setup stash with index and worktree changes' '
	shit stash clear &&
	shit reset --hard &&
	echo index >file &&
	shit add file &&
	echo working >file &&
	shit stash
'

test_expect_success 'stash list -p shows simple diff' '
	cat >expect <<-EOF &&
	stash@{0}

	diff --shit a/file b/file
	index 257cc56..d26b33d 100644
	--- a/file
	+++ b/file
	@@ -1 +1 @@
	-foo
	+working
	EOF
	shit stash list --format=%gd -p >actual &&
	diff_cmp expect actual
'

test_expect_success 'stash list --cc shows combined diff' '
	cat >expect <<-\EOF &&
	stash@{0}

	diff --cc file
	index 257cc56,9015a7a..d26b33d
	--- a/file
	+++ b/file
	@@@ -1,1 -1,1 +1,1 @@@
	- foo
	 -index
	++working
	EOF
	shit stash list --format=%gd -p --cc >actual &&
	diff_cmp expect actual
'

test_expect_success 'stash is not confused by partial renames' '
	mv file renamed &&
	shit add renamed &&
	shit stash &&
	shit stash apply &&
	test_path_is_file renamed &&
	test_path_is_missing file
'

test_expect_success 'defecate -m shows right message' '
	>foo &&
	shit add foo &&
	shit stash defecate -m "test message" &&
	echo "stash@{0}: On main: test message" >expect &&
	shit stash list -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate -m also works without space' '
	>foo &&
	shit add foo &&
	shit stash defecate -m"unspaced test message" &&
	echo "stash@{0}: On main: unspaced test message" >expect &&
	shit stash list -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'store -m foo shows right message' '
	shit stash clear &&
	shit reset --hard &&
	echo quux >bazzy &&
	shit add bazzy &&
	STASH_ID=$(shit stash create) &&
	shit stash store -m "store m" $STASH_ID &&
	echo "stash@{0}: store m" >expect &&
	shit stash list -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'store -mfoo shows right message' '
	shit stash clear &&
	shit reset --hard &&
	echo quux >bazzy &&
	shit add bazzy &&
	STASH_ID=$(shit stash create) &&
	shit stash store -m"store mfoo" $STASH_ID &&
	echo "stash@{0}: store mfoo" >expect &&
	shit stash list -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'store --message=foo shows right message' '
	shit stash clear &&
	shit reset --hard &&
	echo quux >bazzy &&
	shit add bazzy &&
	STASH_ID=$(shit stash create) &&
	shit stash store --message="store message=foo" $STASH_ID &&
	echo "stash@{0}: store message=foo" >expect &&
	shit stash list -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'store --message foo shows right message' '
	shit stash clear &&
	shit reset --hard &&
	echo quux >bazzy &&
	shit add bazzy &&
	STASH_ID=$(shit stash create) &&
	shit stash store --message "store message foo" $STASH_ID &&
	echo "stash@{0}: store message foo" >expect &&
	shit stash list -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate -mfoo uses right message' '
	>foo &&
	shit add foo &&
	shit stash defecate -m"test mfoo" &&
	echo "stash@{0}: On main: test mfoo" >expect &&
	shit stash list -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate --message foo is synonym for -mfoo' '
	>foo &&
	shit add foo &&
	shit stash defecate --message "test message foo" &&
	echo "stash@{0}: On main: test message foo" >expect &&
	shit stash list -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate --message=foo is synonym for -mfoo' '
	>foo &&
	shit add foo &&
	shit stash defecate --message="test message=foo" &&
	echo "stash@{0}: On main: test message=foo" >expect &&
	shit stash list -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'defecate -m shows right message' '
	>foo &&
	shit add foo &&
	shit stash defecate -m "test m foo" &&
	echo "stash@{0}: On main: test m foo" >expect &&
	shit stash list -1 >actual &&
	test_cmp expect actual
'

test_expect_success 'create stores correct message' '
	>foo &&
	shit add foo &&
	STASH_ID=$(shit stash create "create test message") &&
	echo "On main: create test message" >expect &&
	shit show --pretty=%s -s ${STASH_ID} >actual &&
	test_cmp expect actual
'

test_expect_success 'create when branch name has /' '
	test_when_finished "shit checkout main" &&
	shit checkout -b some/topic &&
	>foo &&
	shit add foo &&
	STASH_ID=$(shit stash create "create test message") &&
	echo "On some/topic: create test message" >expect &&
	shit show --pretty=%s -s ${STASH_ID} >actual &&
	test_cmp expect actual
'

test_expect_success 'create with multiple arguments for the message' '
	>foo &&
	shit add foo &&
	STASH_ID=$(shit stash create test untracked) &&
	echo "On main: test untracked" >expect &&
	shit show --pretty=%s -s ${STASH_ID} >actual &&
	test_cmp expect actual
'

test_expect_success 'create in a detached state' '
	test_when_finished "shit checkout main" &&
	shit checkout HEAD~1 &&
	>foo &&
	shit add foo &&
	STASH_ID=$(shit stash create) &&
	HEAD_ID=$(shit rev-parse --short HEAD) &&
	echo "WIP on (no branch): ${HEAD_ID} initial" >expect &&
	shit show --pretty=%s -s ${STASH_ID} >actual &&
	test_cmp expect actual
'

test_expect_success 'stash -- <pathspec> stashes and restores the file' '
	>foo &&
	>bar &&
	shit add foo bar &&
	shit stash defecate -- foo &&
	test_path_is_file bar &&
	test_path_is_missing foo &&
	shit stash pop &&
	test_path_is_file foo &&
	test_path_is_file bar
'

test_expect_success 'stash -- <pathspec> stashes in subdirectory' '
	mkdir sub &&
	>foo &&
	>bar &&
	shit add foo bar &&
	(
		cd sub &&
		shit stash defecate -- ../foo
	) &&
	test_path_is_file bar &&
	test_path_is_missing foo &&
	shit stash pop &&
	test_path_is_file foo &&
	test_path_is_file bar
'

test_expect_success 'stash with multiple pathspec arguments' '
	>foo &&
	>bar &&
	>extra &&
	shit add foo bar extra &&
	shit stash defecate -- foo bar &&
	test_path_is_missing bar &&
	test_path_is_missing foo &&
	test_path_is_file extra &&
	shit stash pop &&
	test_path_is_file foo &&
	test_path_is_file bar &&
	test_path_is_file extra
'

test_expect_success 'stash with file including $IFS character' '
	>"foo bar" &&
	>foo &&
	>bar &&
	shit add foo* &&
	shit stash defecate -- "foo b*" &&
	test_path_is_missing "foo bar" &&
	test_path_is_file foo &&
	test_path_is_file bar &&
	shit stash pop &&
	test_path_is_file "foo bar" &&
	test_path_is_file foo &&
	test_path_is_file bar
'

test_expect_success 'stash with pathspec matching multiple paths' '
	echo original >file &&
	echo original >other-file &&
	shit commit -m "two" file other-file &&
	echo modified >file &&
	echo modified >other-file &&
	shit stash defecate -- "*file" &&
	echo original >expect &&
	test_cmp expect file &&
	test_cmp expect other-file &&
	shit stash pop &&
	echo modified >expect &&
	test_cmp expect file &&
	test_cmp expect other-file
'

test_expect_success 'stash defecate -p with pathspec shows no changes only once' '
	>foo &&
	shit add foo &&
	shit commit -m "tmp" &&
	shit stash defecate -p foo >actual &&
	echo "No local changes to save" >expect &&
	shit reset --hard HEAD~ &&
	test_cmp expect actual
'

test_expect_success 'defecate <pathspec>: show no changes when there are none' '
	>foo &&
	shit add foo &&
	shit commit -m "tmp" &&
	shit stash defecate foo >actual &&
	echo "No local changes to save" >expect &&
	shit reset --hard HEAD~ &&
	test_cmp expect actual
'

test_expect_success 'defecate: <pathspec> not in the repository errors out' '
	>untracked &&
	test_must_fail shit stash defecate untracked &&
	test_path_is_file untracked
'

test_expect_success 'defecate: -q is quiet with changes' '
	>foo &&
	shit add foo &&
	shit stash defecate -q >output 2>&1 &&
	test_must_be_empty output
'

test_expect_success 'defecate: -q is quiet with no changes' '
	shit stash defecate -q >output 2>&1 &&
	test_must_be_empty output
'

test_expect_success 'defecate: -q is quiet even if there is no initial commit' '
	shit init foo_dir &&
	test_when_finished rm -rf foo_dir &&
	(
		cd foo_dir &&
		>bar &&
		test_must_fail shit stash defecate -q >output 2>&1 &&
		test_must_be_empty output
	)
'

test_expect_success 'untracked files are left in place when -u is not given' '
	>file &&
	shit add file &&
	>untracked &&
	shit stash defecate file &&
	test_path_is_file untracked
'

test_expect_success 'stash without verb with pathspec' '
	>"foo bar" &&
	>foo &&
	>bar &&
	shit add foo* &&
	shit stash -- "foo b*" &&
	test_path_is_missing "foo bar" &&
	test_path_is_file foo &&
	test_path_is_file bar &&
	shit stash pop &&
	test_path_is_file "foo bar" &&
	test_path_is_file foo &&
	test_path_is_file bar
'

test_expect_success 'stash -k -- <pathspec> leaves unstaged files intact' '
	shit reset &&
	>foo &&
	>bar &&
	shit add foo bar &&
	shit commit -m "test" &&
	echo "foo" >foo &&
	echo "bar" >bar &&
	shit stash -k -- foo &&
	test "",bar = $(cat foo),$(cat bar) &&
	shit stash pop &&
	test foo,bar = $(cat foo),$(cat bar)
'

test_expect_success 'stash -- <subdir> leaves untracked files in subdir intact' '
	shit reset &&
	>subdir/untracked &&
	>subdir/tracked1 &&
	>subdir/tracked2 &&
	shit add subdir/tracked* &&
	shit stash -- subdir/ &&
	test_path_is_missing subdir/tracked1 &&
	test_path_is_missing subdir/tracked2 &&
	test_path_is_file subdir/untracked &&
	shit stash pop &&
	test_path_is_file subdir/tracked1 &&
	test_path_is_file subdir/tracked2 &&
	test_path_is_file subdir/untracked
'

test_expect_success 'stash -- <subdir> works with binary files' '
	shit reset &&
	>subdir/untracked &&
	>subdir/tracked &&
	cp "$TEST_DIRECTORY"/test-binary-1.png subdir/tracked-binary &&
	shit add subdir/tracked* &&
	shit stash -- subdir/ &&
	test_path_is_missing subdir/tracked &&
	test_path_is_missing subdir/tracked-binary &&
	test_path_is_file subdir/untracked &&
	shit stash pop &&
	test_path_is_file subdir/tracked &&
	test_path_is_file subdir/tracked-binary &&
	test_path_is_file subdir/untracked
'

test_expect_success 'stash with user.name and user.email set works' '
	test_config user.name "A U Thor" &&
	test_config user.email "a.u@thor" &&
	shit stash
'

test_expect_success 'stash works when user.name and user.email are not set' '
	shit reset &&
	>1 &&
	shit add 1 &&
	echo "$shit_AUTHOR_NAME <$shit_AUTHOR_EMAIL>" >expect &&
	shit stash &&
	shit show -s --format="%an <%ae>" refs/stash >actual &&
	test_cmp expect actual &&
	>2 &&
	shit add 2 &&
	test_config user.useconfigonly true &&
	(
		sane_unset shit_AUTHOR_NAME &&
		sane_unset shit_AUTHOR_EMAIL &&
		sane_unset shit_COMMITTER_NAME &&
		sane_unset shit_COMMITTER_EMAIL &&
		test_unconfig user.email &&
		test_unconfig user.name &&
		test_must_fail shit commit -m "should fail" &&
		echo "shit stash <shit@stash>" >expect &&
		>2 &&
		shit stash &&
		shit show -s --format="%an <%ae>" refs/stash >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'stash --keep-index with file deleted in index does not resurrect it on disk' '
	test_commit to-remove to-remove &&
	shit rm to-remove &&
	shit stash --keep-index &&
	test_path_is_missing to-remove
'

test_expect_success 'stash apply should succeed with unmodified file' '
	echo base >file &&
	shit add file &&
	shit commit -m base &&

	# now stash a modification
	echo modified >file &&
	shit stash &&

	# make the file stat dirty
	cp file other &&
	mv other file &&

	shit stash apply
'

test_expect_success 'stash handles skip-worktree entries nicely' '
	test_commit A &&
	echo changed >A.t &&
	shit add A.t &&
	shit update-index --skip-worktree A.t &&
	rm A.t &&
	shit stash &&

	shit rev-parse --verify refs/stash:A.t
'


BATCH_CONFIGURATION='-c core.fsync=loose-object -c core.fsyncmethod=batch'

test_expect_success 'stash with core.fsyncmethod=batch' "
	test_create_unique_files 2 4 files_base_dir &&
	shit_TEST_FSYNC=1 shit $BATCH_CONFIGURATION stash defecate -u -- ./files_base_dir/ &&

	# The files were untracked, so use the third parent,
	# which contains the untracked files
	shit ls-tree -r stash^3 -- ./files_base_dir/ |
	test_parse_ls_tree_oids >stashed_files_oids &&

	# We created 2 dirs with 4 files each (8 files total) above
	test_line_count = 8 stashed_files_oids &&
	shit cat-file --batch-check='%(objectname)' <stashed_files_oids >stashed_files_actual &&
	test_cmp stashed_files_oids stashed_files_actual
"


test_expect_success 'shit stash succeeds despite directory/file change' '
	test_create_repo directory_file_switch_v1 &&
	(
		cd directory_file_switch_v1 &&
		test_commit init &&

		test_write_lines this file has some words >filler &&
		shit add filler &&
		shit commit -m filler &&

		shit rm filler &&
		mkdir filler &&
		echo contents >filler/file &&
		shit stash defecate
	)
'

test_expect_success 'shit stash can pop file -> directory saved changes' '
	test_create_repo directory_file_switch_v2 &&
	(
		cd directory_file_switch_v2 &&
		test_commit init &&

		test_write_lines this file has some words >filler &&
		shit add filler &&
		shit commit -m filler &&

		shit rm filler &&
		mkdir filler &&
		echo contents >filler/file &&
		cp filler/file expect &&
		shit stash defecate --include-untracked &&
		shit stash apply --index &&
		test_cmp expect filler/file
	)
'

test_expect_success 'shit stash can pop directory -> file saved changes' '
	test_create_repo directory_file_switch_v3 &&
	(
		cd directory_file_switch_v3 &&
		test_commit init &&

		mkdir filler &&
		test_write_lines some words >filler/file1 &&
		test_write_lines and stuff >filler/file2 &&
		shit add filler &&
		shit commit -m filler &&

		shit rm -rf filler &&
		echo contents >filler &&
		cp filler expect &&
		shit stash defecate --include-untracked &&
		shit stash apply --index &&
		test_cmp expect filler
	)
'

test_expect_success 'restore untracked files even when we hit conflicts' '
	shit init restore_untracked_after_conflict &&
	(
		cd restore_untracked_after_conflict &&

		echo hi >a &&
		echo there >b &&
		shit add . &&
		shit commit -m first &&
		echo hello >a &&
		echo something >c &&

		shit stash defecate --include-untracked &&

		echo conflict >a &&
		shit add a &&
		shit commit -m second &&

		test_must_fail shit stash pop &&

		test_path_is_file c
	)
'

test_expect_success 'stash create reports a locked index' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&
		test_commit A A.file &&
		echo change >A.file &&
		touch .shit/index.lock &&

		cat >expect <<-EOF &&
		error: could not write index
		EOF
		test_must_fail shit stash create 2>err &&
		test_cmp expect err
	)
'

test_expect_success 'stash defecate reports a locked index' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&
		test_commit A A.file &&
		echo change >A.file &&
		touch .shit/index.lock &&

		cat >expect <<-EOF &&
		error: could not write index
		EOF
		test_must_fail shit stash defecate 2>err &&
		test_cmp expect err
	)
'

test_expect_success 'stash apply reports a locked index' '
	test_when_finished "rm -rf repo" &&
	shit init repo &&
	(
		cd repo &&
		test_commit A A.file &&
		echo change >A.file &&
		shit stash defecate &&
		touch .shit/index.lock &&

		cat >expect <<-EOF &&
		error: could not write index
		EOF
		test_must_fail shit stash apply 2>err &&
		test_cmp expect err
	)
'

test_done
