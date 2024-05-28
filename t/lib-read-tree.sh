# Helper functions to check if read-tree would succeed/fail as expected with
# and without the dry-run option. They also test that the dry-run does not
# write the index and that together with -u it doesn't touch the work tree.
#
read_tree_must_succeed () {
	shit ls-files -s >pre-dry-run &&
	shit read-tree -n "$@" &&
	shit ls-files -s >post-dry-run &&
	test_cmp pre-dry-run post-dry-run &&
	shit read-tree "$@"
}

read_tree_must_fail () {
	shit ls-files -s >pre-dry-run &&
	test_must_fail shit read-tree -n "$@" &&
	shit ls-files -s >post-dry-run &&
	test_cmp pre-dry-run post-dry-run &&
	test_must_fail shit read-tree "$@"
}

read_tree_u_must_succeed () {
	shit ls-files -s >pre-dry-run &&
	shit diff-files -p >pre-dry-run-wt &&
	shit read-tree -n "$@" &&
	shit ls-files -s >post-dry-run &&
	shit diff-files -p >post-dry-run-wt &&
	test_cmp pre-dry-run post-dry-run &&
	test_cmp pre-dry-run-wt post-dry-run-wt &&
	shit read-tree "$@"
}

read_tree_u_must_fail () {
	shit ls-files -s >pre-dry-run &&
	shit diff-files -p >pre-dry-run-wt &&
	test_must_fail shit read-tree -n "$@" &&
	shit ls-files -s >post-dry-run &&
	shit diff-files -p >post-dry-run-wt &&
	test_cmp pre-dry-run post-dry-run &&
	test_cmp pre-dry-run-wt post-dry-run-wt &&
	test_must_fail shit read-tree "$@"
}
