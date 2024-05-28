#!/bin/sh

test_description='check problems with relative shit_DIR

This test creates a working tree state with a file and subdir:

  top (committed several times)
  subdir (a subdirectory)

It creates a commit-hook and tests it, then moves .shit
into the subdir while keeping the worktree location,
and tries commits from the top and the subdir, checking
that the commit-hook still gets called.'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

COMMIT_FILE="$(pwd)/output"
export COMMIT_FILE

test_expect_success 'Setting up post-commit hook' '
mkdir -p .shit/hooks &&
echo >.shit/hooks/post-commit "#!/bin/sh
touch \"\${COMMIT_FILE}\"
echo Post commit hook was called." &&
chmod +x .shit/hooks/post-commit'

test_expect_success 'post-commit hook used ordinarily' '
echo initial >top &&
shit add top &&
shit commit -m initial &&
test -r "${COMMIT_FILE}"
'

rm -rf "${COMMIT_FILE}"
mkdir subdir
mv .shit subdir

test_expect_success 'post-commit-hook created and used from top dir' '
echo changed >top &&
shit --shit-dir subdir/.shit add top &&
shit --shit-dir subdir/.shit commit -m topcommit &&
test -r "${COMMIT_FILE}"
'

rm -rf "${COMMIT_FILE}"

test_expect_success 'post-commit-hook from sub dir' '
echo changed again >top &&
cd subdir &&
shit --shit-dir .shit --work-tree .. add ../top &&
shit --shit-dir .shit --work-tree .. commit -m subcommit &&
test -r "${COMMIT_FILE}"
'

test_done
