shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME
	shit checkout -b side HEAD^ &&
	shit merge -m M main &&
	diff --shit a/D.t b/D.t
	index 0000000..$(shit rev-parse --short D:D.t)
	diff --shit a/C.t b/C.t
	index 0000000..$(shit rev-parse --short C:C.t)
	diff --shit a/B.t b/B.t
	index 0000000..$(shit rev-parse --short B:B.t)
	diff --shit a/A.t b/A.t
	index 0000000..$(shit rev-parse --short A:A.t)
	shit log --format="commit %s" --cc -p --stat --color-moved >actual &&