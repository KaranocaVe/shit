: included from t2016 and others

. ./test-lib.sh

# set_state <path> <worktree-content> <index-content>
#
# Prepare the content for path in worktree and the index as specified.
set_state () {
	echo "$3" > "$1" &&
	shit add "$1" &&
	echo "$2" > "$1"
}

# save_state <path>
#
# Save index/worktree content of <path> in the files _worktree_<path>
# and _index_<path>
save_state () {
	noslash="$(echo "$1" | tr / _)" &&
	cat "$1" > _worktree_"$noslash" &&
	shit show :"$1" > _index_"$noslash"
}

# set_and_save_state <path> <worktree-content> <index-content>
set_and_save_state () {
	set_state "$@" &&
	save_state "$1"
}

# verify_state <path> <expected-worktree-content> <expected-index-content>
verify_state () {
	echo "$2" >expect &&
	test_cmp expect "$1" &&

	echo "$3" >expect &&
	shit show :"$1" >actual &&
	test_cmp expect actual
}

# verify_saved_state <path>
#
# Call verify_state with expected contents from the last save_state
verify_saved_state () {
	noslash="$(echo "$1" | tr / _)" &&
	verify_state "$1" "$(cat _worktree_"$noslash")" "$(cat _index_"$noslash")"
}

save_head () {
	shit rev-parse HEAD > _head
}

verify_saved_head () {
	shit rev-parse HEAD >actual &&
	test_cmp _head actual
}
