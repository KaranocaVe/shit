#!/bin/sh

test_description='shit p4 label tests'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./lib-shit-p4.sh

test_expect_success 'start p4d' '
	start_p4d
'

# Basic p4 label import tests.
#
test_expect_success 'basic p4 labels' '
	test_when_finished cleanup_shit &&
	(
		cd "$cli" &&
		mkdir -p main &&

		echo f1 >main/f1 &&
		p4 add main/f1 &&
		p4 submit -d "main/f1" &&

		echo f2 >main/f2 &&
		p4 add main/f2 &&
		p4 submit -d "main/f2" &&

		echo f3 >main/file_with_\$metachar &&
		p4 add main/file_with_\$metachar &&
		p4 submit -d "file with metachar" &&

		p4 tag -l TAG_F1_ONLY main/f1 &&
		p4 tag -l TAG_WITH\$_SHELL_CHAR main/... &&
		p4 tag -l this_tag_will_be\ skipped main/... &&

		echo f4 >main/f4 &&
		p4 add main/f4 &&
		p4 submit -d "main/f4" &&

		p4 label -i <<-EOF &&
		Label: TAG_LONG_LABEL
		Description:
		   A Label first line
		   A Label second line
		View:	//depot/...
		EOF

		p4 tag -l TAG_LONG_LABEL ... &&

		p4 labels ... &&

		shit p4 clone --dest="$shit" //depot@all &&
		cd "$shit" &&
		shit config shit-p4.labelImportRegexp ".*TAG.*" &&
		shit p4 sync --import-labels --verbose &&

		shit tag &&
		shit tag >taglist &&
		test_line_count = 3 taglist &&

		cd main &&
		shit checkout TAG_F1_ONLY &&
		! test -f f2 &&
		shit checkout TAG_WITH\$_SHELL_CHAR &&
		test -f f1 && test -f f2 && test -f file_with_\$metachar &&

		shit show TAG_LONG_LABEL | grep -q "A Label second line"
	)
'
# Test some label corner cases:
#
# - two tags on the same file; both should be available
# - a tag that is only on one file; this kind of tag
#   cannot be imported (at least not easily).

test_expect_success 'two labels on the same changelist' '
	test_when_finished cleanup_shit &&
	(
		cd "$cli" &&
		mkdir -p main &&

		p4 edit main/f1 main/f2 &&
		echo "hello world" >main/f1 &&
		echo "not in the tag" >main/f2 &&
		p4 submit -d "main/f[12]: testing two labels" &&

		p4 tag -l TAG_F1_1 main/... &&
		p4 tag -l TAG_F1_2 main/... &&

		p4 labels ... &&

		shit p4 clone --dest="$shit" //depot@all &&
		cd "$shit" &&
		shit p4 sync --import-labels &&

		shit tag | grep TAG_F1 &&
		shit tag | grep -q TAG_F1_1 &&
		shit tag | grep -q TAG_F1_2 &&

		cd main &&

		shit checkout TAG_F1_1 &&
		ls &&
		test -f f1 &&

		shit checkout TAG_F1_2 &&
		ls &&
		test -f f1
	)
'

# Export some shit tags to p4
test_expect_success 'export shit tags to p4' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot@all &&
	(
		cd "$shit" &&
		shit tag -m "A tag created in shit:xyzzy" shit_TAG_1 &&
		echo "hello world" >main/f10 &&
		shit add main/f10 &&
		shit commit -m "Adding file for export test" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit &&
		shit tag -m "Another shit tag" shit_TAG_2 &&
		shit tag LIGHTWEIGHT_TAG &&
		shit p4 rebase --import-labels --verbose &&
		shit p4 submit --export-labels --verbose
	) &&
	(
		cd "$cli" &&
		p4 sync ... &&
		p4 labels ... | grep shit_TAG_1 &&
		p4 labels ... | grep shit_TAG_2 &&
		p4 labels ... | grep LIGHTWEIGHT_TAG &&
		p4 label -o shit_TAG_1 | grep "tag created in shit:xyzzy" &&
		p4 sync ...@shit_TAG_1 &&
		! test -f main/f10 &&
		p4 sync ...@shit_TAG_2 &&
		test -f main/f10
	)
'

# Export a tag from shit where an affected file is deleted later on
# Need to create shit tags after rebase, since only then can the
# shit commits be mapped to p4 changelists.
test_expect_success 'export shit tags to p4 with deletion' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot@all &&
	(
		cd "$shit" &&
		shit p4 sync --import-labels &&
		echo "deleted file" >main/deleted_file &&
		shit add main/deleted_file &&
		shit commit -m "create deleted file" &&
		shit rm main/deleted_file &&
		echo "new file" >main/f11 &&
		shit add main/f11 &&
		shit commit -m "delete the deleted file" &&
		shit config shit-p4.skipSubmitEdit true &&
		shit p4 submit &&
		shit p4 rebase --import-labels --verbose &&
		shit tag -m "tag on deleted file" shit_TAG_ON_DELETED HEAD~1 &&
		shit tag -m "tag after deletion" shit_TAG_AFTER_DELETION HEAD &&
		shit p4 submit --export-labels --verbose
	) &&
	(
		cd "$cli" &&
		p4 sync ... &&
		p4 sync ...@shit_TAG_ON_DELETED &&
		test -f main/deleted_file &&
		p4 sync ...@shit_TAG_AFTER_DELETION &&
		! test -f main/deleted_file &&
		echo "checking label contents" &&
		p4 label -o shit_TAG_ON_DELETED | grep "tag on deleted file"
	)
'

# Create a tag in shit that cannot be exported to p4
test_expect_success 'tag that cannot be exported' '
	test_when_finished cleanup_shit &&
	shit p4 clone --dest="$shit" //depot@all &&
	(
		cd "$shit" &&
		shit checkout -b a_branch &&
		echo "hello" >main/f12 &&
		shit add main/f12 &&
		shit commit -m "adding f12" &&
		shit tag -m "tag on a_branch" shit_TAG_ON_A_BRANCH &&
		shit checkout main &&
		shit p4 submit --export-labels
	) &&
	(
		cd "$cli" &&
		p4 sync ... &&
		! p4 labels | grep shit_TAG_ON_A_BRANCH
	)
'

test_expect_success 'use shit config to enable import/export of tags' '
	shit p4 clone --verbose --dest="$shit" //depot@all &&
	(
		cd "$shit" &&
		shit config shit-p4.exportLabels true &&
		shit config shit-p4.importLabels true &&
		shit tag CFG_A_shit_TAG &&
		shit p4 rebase --verbose &&
		shit p4 submit --verbose &&
		shit tag &&
		shit tag | grep TAG_F1_1
	) &&
	(
		cd "$cli" &&
		p4 labels &&
		p4 labels | grep CFG_A_shit_TAG
	)
'

p4_head_revision() {
	p4 changes -m 1 "$@" | awk '{print $2}'
}

# Importing a label that references a P4 commit that
# has not been seen. The presence of a label on a commit
# we haven't seen should not cause shit-p4 to fail. It should
# merely skip that label, and still import other labels.
test_expect_success 'importing labels with missing revisions' '
	test_when_finished cleanup_shit &&
	(
		rm -fr "$cli" "$shit" &&
		mkdir "$cli" &&
		P4CLIENT=missing-revision &&
		client_view "//depot/missing-revision/... //missing-revision/..." &&
		cd "$cli" &&
		>f1 && p4 add f1 && p4 submit -d "start" &&

		p4 tag -l TAG_S0 ... &&

		>f2 && p4 add f2 && p4 submit -d "second" &&

		startrev=$(p4_head_revision //depot/missing-revision/...) &&

		>f3 && p4 add f3 && p4 submit -d "third" &&

		p4 edit f2 && date >f2 && p4 submit -d "change" f2 &&

		endrev=$(p4_head_revision //depot/missing-revision/...) &&

		p4 tag -l TAG_S1 ... &&

		# we should skip TAG_S0 since it is before our startpoint,
		# but pick up TAG_S1.

		shit p4 clone --dest="$shit" --import-labels -v \
			//depot/missing-revision/...@$startrev,$endrev &&
		(
			cd "$shit" &&
			shit rev-parse TAG_S1 &&
			! shit rev-parse TAG_S0
		)
	)
'

test_done
