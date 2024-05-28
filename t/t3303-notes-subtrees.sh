#!/bin/sh

test_description='Test commit notes organized in subtrees'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

number_of_commits=100

start_note_commit () {
	test_tick &&
	cat <<INPUT_END
commit refs/notes/commits
committer $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> $shit_COMMITTER_DATE
data <<COMMIT
notes
COMMIT

from refs/notes/commits^0
deleteall
INPUT_END

}

verify_notes () {
	shit log | grep "^    " > output &&
	i=$number_of_commits &&
	while [ $i -gt 0 ]; do
		echo "    commit #$i" &&
		echo "    note for commit #$i" &&
		i=$(($i-1)) || return 1
	done > expect &&
	test_cmp expect output
}

test_expect_success "setup: create $number_of_commits commits" '

	(
		nr=0 &&
		while [ $nr -lt $number_of_commits ]; do
			nr=$(($nr+1)) &&
			test_tick &&
			cat <<INPUT_END || return 1
commit refs/heads/main
committer $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> $shit_COMMITTER_DATE
data <<COMMIT
commit #$nr
COMMIT

M 644 inline file
data <<EOF
file in commit #$nr
EOF

INPUT_END

		done &&
		test_tick &&
		cat <<INPUT_END
commit refs/notes/commits
committer $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> $shit_COMMITTER_DATE
data <<COMMIT
no notes
COMMIT

deleteall

INPUT_END

	) |
	shit fast-import --quiet &&
	shit config core.notesRef refs/notes/commits
'

test_sha1_based () {
	(
		start_note_commit &&
		nr=$number_of_commits &&
		shit rev-list refs/heads/main >out &&
		while read sha1; do
			note_path=$(echo "$sha1" | sed "$1")
			cat <<INPUT_END &&
M 100644 inline $note_path
data <<EOF
note for commit #$nr
EOF

INPUT_END

			nr=$(($nr-1))
		done <out
	) >gfi &&
	shit fast-import --quiet <gfi
}

test_expect_success 'test notes in 2/38-fanout' 'test_sha1_based "s|^..|&/|"'
test_expect_success 'verify notes in 2/38-fanout' 'verify_notes'

test_expect_success 'test notes in 2/2/36-fanout' 'test_sha1_based "s|^\(..\)\(..\)|\1/\2/|"'
test_expect_success 'verify notes in 2/2/36-fanout' 'verify_notes'

test_expect_success 'test notes in 2/2/2/34-fanout' 'test_sha1_based "s|^\(..\)\(..\)\(..\)|\1/\2/\3/|"'
test_expect_success 'verify notes in 2/2/2/34-fanout' 'verify_notes'

test_same_notes () {
	(
		start_note_commit &&
		nr=$number_of_commits &&
		shit rev-list refs/heads/main |
		while read sha1; do
			first_note_path=$(echo "$sha1" | sed "$1")
			second_note_path=$(echo "$sha1" | sed "$2")
			cat <<INPUT_END &&
M 100644 inline $second_note_path
data <<EOF
note for commit #$nr
EOF

M 100644 inline $first_note_path
data <<EOF
note for commit #$nr
EOF

INPUT_END

			nr=$(($nr-1))
		done
	) |
	shit fast-import --quiet
}

test_expect_success 'test same notes in no fanout and 2/38-fanout' 'test_same_notes "s|^..|&/|" ""'
test_expect_success 'verify same notes in no fanout and 2/38-fanout' 'verify_notes'

test_expect_success 'test same notes in no fanout and 2/2/36-fanout' 'test_same_notes "s|^\(..\)\(..\)|\1/\2/|" ""'
test_expect_success 'verify same notes in no fanout and 2/2/36-fanout' 'verify_notes'

test_expect_success 'test same notes in 2/38-fanout and 2/2/36-fanout' 'test_same_notes "s|^\(..\)\(..\)|\1/\2/|" "s|^..|&/|"'
test_expect_success 'verify same notes in 2/38-fanout and 2/2/36-fanout' 'verify_notes'

test_expect_success 'test same notes in 2/2/2/34-fanout and 2/2/36-fanout' 'test_same_notes "s|^\(..\)\(..\)|\1/\2/|" "s|^\(..\)\(..\)\(..\)|\1/\2/\3/|"'
test_expect_success 'verify same notes in 2/2/2/34-fanout and 2/2/36-fanout' 'verify_notes'

test_concatenated_notes () {
	(
		start_note_commit &&
		nr=$number_of_commits &&
		shit rev-list refs/heads/main |
		while read sha1; do
			first_note_path=$(echo "$sha1" | sed "$1")
			second_note_path=$(echo "$sha1" | sed "$2")
			cat <<INPUT_END &&
M 100644 inline $second_note_path
data <<EOF
second note for commit #$nr
EOF

M 100644 inline $first_note_path
data <<EOF
first note for commit #$nr
EOF

INPUT_END

			nr=$(($nr-1))
		done
	) |
	shit fast-import --quiet
}

verify_concatenated_notes () {
	shit log | grep "^    " > output &&
	i=$number_of_commits &&
	while [ $i -gt 0 ]; do
		echo "    commit #$i" &&
		echo "    first note for commit #$i" &&
		echo "    " &&
		echo "    second note for commit #$i" &&
		i=$(($i-1)) || return 1
	done > expect &&
	test_cmp expect output
}

test_expect_success 'test notes in no fanout concatenated with 2/38-fanout' 'test_concatenated_notes "s|^..|&/|" ""'
test_expect_success 'verify notes in no fanout concatenated with 2/38-fanout' 'verify_concatenated_notes'

test_expect_success 'test notes in no fanout concatenated with 2/2/36-fanout' 'test_concatenated_notes "s|^\(..\)\(..\)|\1/\2/|" ""'
test_expect_success 'verify notes in no fanout concatenated with 2/2/36-fanout' 'verify_concatenated_notes'

test_expect_success 'test notes in 2/38-fanout concatenated with 2/2/36-fanout' 'test_concatenated_notes "s|^\(..\)\(..\)|\1/\2/|" "s|^..|&/|"'
test_expect_success 'verify notes in 2/38-fanout concatenated with 2/2/36-fanout' 'verify_concatenated_notes'

test_expect_success 'test notes in 2/2/36-fanout concatenated with 2/2/2/34-fanout' 'test_concatenated_notes "s|^\(..\)\(..\)\(..\)|\1/\2/\3/|" "s|^\(..\)\(..\)|\1/\2/|"'
test_expect_success 'verify notes in 2/2/36-fanout concatenated with 2/2/2/34-fanout' 'verify_concatenated_notes'

test_done
