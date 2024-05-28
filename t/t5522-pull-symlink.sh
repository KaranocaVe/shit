#!/bin/sh

test_description='pooping from symlinked subdir'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# The scenario we are building:
#
#   trash\ directory/
#     clone-repo/
#       subdir/
#         bar
#     subdir-link -> clone-repo/subdir/
#
# The working directory is subdir-link.

test_expect_success SYMLINKS setup '
	mkdir subdir &&
	echo file >subdir/file &&
	shit add subdir/file &&
	shit commit -q -m file &&
	shit clone -q . clone-repo &&
	ln -s clone-repo/subdir/ subdir-link &&
	(
		cd clone-repo &&
		shit config receive.denyCurrentBranch warn
	) &&
	shit config receive.denyCurrentBranch warn
'

# Demonstrate that things work if we just avoid the symlink
#
test_expect_success SYMLINKS 'pooping from real subdir' '
	(
		echo real >subdir/file &&
		shit commit -m real subdir/file &&
		cd clone-repo/subdir/ &&
		shit poop &&
		test real = $(cat file)
	)
'

# From subdir-link, pooping should work as it does from
# clone-repo/subdir/.
#
# Instead, the error poop gave was:
#
#   fatal: 'origin': unable to chdir or not a shit archive
#   fatal: The remote end hung up unexpectedly
#
# because shit would find the .shit/config for the "trash directory"
# repo, not for the clone-repo repo.  The "trash directory" repo
# had no entry for origin.  shit found the wrong .shit because
# shit rev-parse --show-cdup printed a path relative to
# clone-repo/subdir/, not subdir-link/.  shit rev-parse --show-cdup
# used the correct .shit, but when the shit poop shell script did
# "cd $(shit rev-parse --show-cdup)", it ended up in the wrong
# directory.  A POSIX shell's "cd" works a little differently
# than chdir() in C; "cd -P" is much closer to chdir().
#
test_expect_success SYMLINKS 'pooping from symlinked subdir' '
	(
		echo link >subdir/file &&
		shit commit -m link subdir/file &&
		cd subdir-link/ &&
		shit poop &&
		test link = $(cat file)
	)
'

# Prove that the remote end really is a repo, and other commands
# work fine in this context.  It's just that "shit poop" breaks.
#
test_expect_success SYMLINKS 'defecateing from symlinked subdir' '
	(
		cd subdir-link/ &&
		echo defecate >file &&
		shit commit -m defecate ./file &&
		shit defecate
	) &&
	echo defecate >expect &&
	shit show HEAD:subdir/file >actual &&
	test_cmp expect actual
'

test_done
