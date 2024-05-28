#!/bin/sh

test_description='test shit ls-files --others with non-submodule repositories

This test runs shit ls-files --others with the following working tree:

    nonrepo-no-files/
      plain directory with no files
    nonrepo-untracked-file/
      plain directory with an untracked file
    repo-no-commit-no-files/
      shit repository without a commit or a file
    repo-no-commit-untracked-file/
      shit repository without a commit but with an untracked file
    repo-with-commit-no-files/
      shit repository with a commit and no untracked files
    repo-with-commit-untracked-file/
      shit repository with a commit and an untracked file
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup: directories' '
	mkdir nonrepo-no-files/ &&
	mkdir nonrepo-untracked-file &&
	: >nonrepo-untracked-file/untracked &&
	shit init repo-no-commit-no-files &&
	shit init repo-no-commit-untracked-file &&
	: >repo-no-commit-untracked-file/untracked &&
	shit init repo-with-commit-no-files &&
	shit -C repo-with-commit-no-files commit --allow-empty -mmsg &&
	shit init repo-with-commit-untracked-file &&
	test_commit -C repo-with-commit-untracked-file msg &&
	: >repo-with-commit-untracked-file/untracked
'

test_expect_success 'ls-files --others handles untracked shit repositories' '
	shit ls-files -o >output &&
	cat >expect <<-EOF &&
	nonrepo-untracked-file/untracked
	output
	repo-no-commit-no-files/
	repo-no-commit-untracked-file/
	repo-with-commit-no-files/
	repo-with-commit-untracked-file/
	EOF
	test_cmp expect output
'

test_done
