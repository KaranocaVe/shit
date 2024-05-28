#!/bin/sh
#
# Copyright (c) 2007 Carlos Rica
#

test_description='shit tag

Tests for operations with tags.'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-gpg.sh
. "$TEST_DIRECTORY"/lib-terminal.sh

# creating and listing lightweight tags:

tag_exists () {
	shit show-ref --quiet --verify refs/tags/"$1"
}

test_expect_success 'setup' '
	test_oid_cache <<-EOM
	othersigheader sha1:gpgsig-sha256
	othersigheader sha256:gpgsig
	EOM
'

test_expect_success 'listing all tags in an empty tree should succeed' '
	shit tag -l &&
	shit tag
'

test_expect_success 'listing all tags in an empty tree should output nothing' '
	test $(shit tag -l | wc -l) -eq 0 &&
	test $(shit tag | wc -l) -eq 0
'

test_expect_success 'sort tags, ignore case' '
	(
		shit init sort &&
		cd sort &&
		test_commit initial &&
		shit tag tag-one &&
		shit tag TAG-two &&
		shit tag -l >actual &&
		cat >expected <<-\EOF &&
		TAG-two
		initial
		tag-one
		EOF
		test_cmp expected actual &&
		shit tag -l -i >actual &&
		cat >expected <<-\EOF &&
		initial
		tag-one
		TAG-two
		EOF
		test_cmp expected actual
	)
'

test_expect_success 'looking for a tag in an empty tree should fail' \
	'! (tag_exists mytag)'

test_expect_success 'creating a tag in an empty tree should fail' '
	test_must_fail shit tag mynotag &&
	! tag_exists mynotag
'

test_expect_success 'creating a tag for HEAD in an empty tree should fail' '
	test_must_fail shit tag mytaghead HEAD &&
	! tag_exists mytaghead
'

test_expect_success 'creating a tag for an unknown revision should fail' '
	test_must_fail shit tag mytagnorev aaaaaaaaaaa &&
	! tag_exists mytagnorev
'

# commit used in the tests, test_tick is also called here to freeze the date:
test_expect_success 'creating a tag using default HEAD should succeed' '
	test_config core.logAllRefUpdates true &&
	test_tick &&
	echo foo >foo &&
	shit add foo &&
	shit commit -m Foo &&
	shit tag mytag &&
	test_must_fail shit reflog exists refs/tags/mytag
'

test_expect_success 'creating a tag with --create-reflog should create reflog' '
	shit log -1 \
		--format="format:tag: tagging %h (%s, %cd)%n" \
		--date=format:%Y-%m-%d >expected &&
	test_when_finished "shit tag -d tag_with_reflog1" &&
	shit tag --create-reflog tag_with_reflog1 &&
	shit reflog exists refs/tags/tag_with_reflog1 &&
	test-tool ref-store main for-each-reflog-ent refs/tags/tag_with_reflog1 | sed -e "s/^.*	//" >actual &&
	test_cmp expected actual
'

test_expect_success 'annotated tag with --create-reflog has correct message' '
	shit log -1 \
		--format="format:tag: tagging %h (%s, %cd)%n" \
		--date=format:%Y-%m-%d >expected &&
	test_when_finished "shit tag -d tag_with_reflog2" &&
	shit tag -m "annotated tag" --create-reflog tag_with_reflog2 &&
	shit reflog exists refs/tags/tag_with_reflog2 &&
	test-tool ref-store main for-each-reflog-ent refs/tags/tag_with_reflog2 | sed -e "s/^.*	//" >actual &&
	test_cmp expected actual
'

test_expect_success '--create-reflog does not create reflog on failure' '
	test_must_fail shit tag --create-reflog mytag &&
	test_must_fail shit reflog exists refs/tags/mytag
'

test_expect_success 'option core.logAllRefUpdates=always creates reflog' '
	test_when_finished "shit tag -d tag_with_reflog3" &&
	test_config core.logAllRefUpdates always &&
	shit tag tag_with_reflog3 &&
	shit reflog exists refs/tags/tag_with_reflog3
'

test_expect_success 'listing all tags if one exists should succeed' '
	shit tag -l &&
	shit tag
'

cat >expect <<EOF
mytag
EOF
test_expect_success 'Multiple -l or --list options are equivalent to one -l option' '
	shit tag -l -l >actual &&
	test_cmp expect actual &&
	shit tag --list --list >actual &&
	test_cmp expect actual &&
	shit tag --list -l --list >actual &&
	test_cmp expect actual
'

test_expect_success 'listing all tags if one exists should output that tag' '
	test $(shit tag -l) = mytag &&
	test $(shit tag) = mytag
'

# pattern matching:

test_expect_success 'listing a tag using a matching pattern should succeed' \
	'shit tag -l mytag'

test_expect_success 'listing a tag with --ignore-case' \
	'test $(shit tag -l --ignore-case MYTAG) = mytag'

test_expect_success \
	'listing a tag using a matching pattern should output that tag' \
	'test $(shit tag -l mytag) = mytag'

test_expect_success \
	'listing tags using a non-matching pattern should succeed' \
	'shit tag -l xxx'

test_expect_success \
	'listing tags using a non-matching pattern should output nothing' \
	'test $(shit tag -l xxx | wc -l) -eq 0'

# special cases for creating tags:

test_expect_success \
	'trying to create a tag with the name of one existing should fail' \
	'test_must_fail shit tag mytag'

test_expect_success \
	'trying to create a tag with a non-valid name should fail' '
	test $(shit tag -l | wc -l) -eq 1 &&
	test_must_fail shit tag "" &&
	test_must_fail shit tag .othertag &&
	test_must_fail shit tag "other tag" &&
	test_must_fail shit tag "othertag^" &&
	test_must_fail shit tag "other~tag" &&
	test $(shit tag -l | wc -l) -eq 1
'

test_expect_success 'creating a tag using HEAD directly should succeed' '
	shit tag myhead HEAD &&
	tag_exists myhead
'

test_expect_success '--force can create a tag with the name of one existing' '
	tag_exists mytag &&
	shit tag --force mytag &&
	tag_exists mytag'

test_expect_success '--force is moot with a non-existing tag name' '
	test_when_finished shit tag -d newtag forcetag &&
	shit tag newtag >expect &&
	shit tag --force forcetag >actual &&
	test_cmp expect actual
'

# deleting tags:

test_expect_success 'trying to delete an unknown tag should fail' '
	! tag_exists unknown-tag &&
	test_must_fail shit tag -d unknown-tag
'

cat >expect <<EOF
myhead
mytag
EOF
test_expect_success \
	'trying to delete tags without params should succeed and do nothing' '
	shit tag -l > actual && test_cmp expect actual &&
	shit tag -d &&
	shit tag -l > actual && test_cmp expect actual
'

test_expect_success \
	'deleting two existing tags in one command should succeed' '
	tag_exists mytag &&
	tag_exists myhead &&
	shit tag -d mytag myhead &&
	! tag_exists mytag &&
	! tag_exists myhead
'

test_expect_success \
	'creating a tag with the name of another deleted one should succeed' '
	! tag_exists mytag &&
	shit tag mytag &&
	tag_exists mytag
'

test_expect_success \
	'trying to delete two tags, existing and not, should fail in the 2nd' '
	tag_exists mytag &&
	! tag_exists nonexistingtag &&
	test_must_fail shit tag -d mytag nonexistingtag &&
	! tag_exists mytag &&
	! tag_exists nonexistingtag
'

test_expect_success 'trying to delete an already deleted tag should fail' \
	'test_must_fail shit tag -d mytag'

# listing various tags with pattern matching:

cat >expect <<EOF
a1
aa1
cba
t210
t211
v0.2.1
v1.0
v1.0.1
v1.1.3
EOF
test_expect_success 'listing all tags should print them ordered' '
	shit tag v1.0.1 &&
	shit tag t211 &&
	shit tag aa1 &&
	shit tag v0.2.1 &&
	shit tag v1.1.3 &&
	shit tag cba &&
	shit tag a1 &&
	shit tag v1.0 &&
	shit tag t210 &&
	shit tag -l > actual &&
	test_cmp expect actual &&
	shit tag > actual &&
	test_cmp expect actual
'

cat >expect <<EOF
a1
aa1
cba
EOF
test_expect_success \
	'listing tags with substring as pattern must print those matching' '
	rm *a* &&
	shit tag -l "*a*" > current &&
	test_cmp expect current
'

cat >expect <<EOF
v0.2.1
v1.0.1
EOF
test_expect_success \
	'listing tags with a suffix as pattern must print those matching' '
	shit tag -l "*.1" > actual &&
	test_cmp expect actual
'

cat >expect <<EOF
t210
t211
EOF
test_expect_success \
	'listing tags with a prefix as pattern must print those matching' '
	shit tag -l "t21*" > actual &&
	test_cmp expect actual
'

cat >expect <<EOF
a1
EOF
test_expect_success \
	'listing tags using a name as pattern must print that one matching' '
	shit tag -l a1 > actual &&
	test_cmp expect actual
'

cat >expect <<EOF
v1.0
EOF
test_expect_success \
	'listing tags using a name as pattern must print that one matching' '
	shit tag -l v1.0 > actual &&
	test_cmp expect actual
'

cat >expect <<EOF
v1.0.1
v1.1.3
EOF
test_expect_success \
	'listing tags with ? in the pattern should print those matching' '
	shit tag -l "v1.?.?" > actual &&
	test_cmp expect actual
'

test_expect_success \
	'listing tags using v.* should print nothing because none have v.' '
	shit tag -l "v.*" > actual &&
	test_must_be_empty actual
'

cat >expect <<EOF
v0.2.1
v1.0
v1.0.1
v1.1.3
EOF
test_expect_success \
	'listing tags using v* should print only those having v' '
	shit tag -l "v*" > actual &&
	test_cmp expect actual
'

test_expect_success 'tag -l can accept multiple patterns' '
	shit tag -l "v1*" "v0*" >actual &&
	test_cmp expect actual
'

# Between v1.7.7 & v2.13.0 a fair reading of the shit-tag documentation
# could leave you with the impression that "-l <pattern> -l <pattern>"
# was how we wanted to accept multiple patterns.
#
# This test should not imply that this is a sane thing to support. but
# since the documentation was worded like it was let's at least find
# out if we're going to break this long-documented form of taking
# multiple patterns.
test_expect_success 'tag -l <pattern> -l <pattern> works, as our buggy documentation previously suggested' '
	shit tag -l "v1*" -l "v0*" >actual &&
	test_cmp expect actual
'

test_expect_success 'listing tags in column' '
	COLUMNS=41 shit tag -l --column=row >actual &&
	cat >expected <<\EOF &&
a1      aa1     cba     t210    t211
v0.2.1  v1.0    v1.0.1  v1.1.3
EOF
	test_cmp expected actual
'

test_expect_success 'listing tags in column with column.*' '
	test_config column.tag row &&
	test_config column.ui dense &&
	COLUMNS=40 shit tag -l >actual &&
	cat >expected <<\EOF &&
a1      aa1   cba     t210    t211
v0.2.1  v1.0  v1.0.1  v1.1.3
EOF
	test_cmp expected actual
'

test_expect_success 'listing tag with -n --column should fail' '
	test_must_fail shit tag --column -n
'

test_expect_success 'listing tags -n in column with column.ui ignored' '
	test_config column.ui "row dense" &&
	COLUMNS=40 shit tag -l -n >actual &&
	cat >expected <<\EOF &&
a1              Foo
aa1             Foo
cba             Foo
t210            Foo
t211            Foo
v0.2.1          Foo
v1.0            Foo
v1.0.1          Foo
v1.1.3          Foo
EOF
	test_cmp expected actual
'

# creating and verifying lightweight tags:

test_expect_success \
	'a non-annotated tag created without parameters should point to HEAD' '
	shit tag non-annotated-tag &&
	test $(shit cat-file -t non-annotated-tag) = commit &&
	test $(shit rev-parse non-annotated-tag) = $(shit rev-parse HEAD)
'

test_expect_success 'trying to verify an unknown tag should fail' \
	'test_must_fail shit tag -v unknown-tag'

test_expect_success \
	'trying to verify a non-annotated and non-signed tag should fail' \
	'test_must_fail shit tag -v non-annotated-tag'

test_expect_success \
	'trying to verify many non-annotated or unknown tags, should fail' \
	'test_must_fail shit tag -v unknown-tag1 non-annotated-tag unknown-tag2'

# creating annotated tags:

get_tag_msg () {
	shit cat-file tag "$1" | sed -e "/BEGIN PGP/q"
}

# run test_tick before committing always gives the time in that timezone
get_tag_header () {
cat <<EOF
object $2
type $3
tag $1
tagger C O Mitter <committer@example.com> $4 -0700

EOF
}

commit=$(shit rev-parse HEAD)
time=$test_tick

get_tag_header annotated-tag $commit commit $time >expect
echo "A message" >>expect
test_expect_success \
	'creating an annotated tag with -m message should succeed' '
	shit tag -m "A message" annotated-tag &&
	get_tag_msg annotated-tag >actual &&
	test_cmp expect actual
'

get_tag_header annotated-tag-edit $commit commit $time >expect
echo "An edited message" >>expect
test_expect_success 'set up editor' '
	write_script fakeeditor <<-\EOF
	sed -e "s/A message/An edited message/g" <"$1" >"$1-"
	mv "$1-" "$1"
	EOF
'
test_expect_success \
	'creating an annotated tag with -m message --edit should succeed' '
	shit_EDITOR=./fakeeditor shit tag -m "A message" --edit annotated-tag-edit &&
	get_tag_msg annotated-tag-edit >actual &&
	test_cmp expect actual
'

cat >msgfile <<EOF
Another message
in a file.
EOF
get_tag_header file-annotated-tag $commit commit $time >expect
cat msgfile >>expect
test_expect_success \
	'creating an annotated tag with -F messagefile should succeed' '
	shit tag -F msgfile file-annotated-tag &&
	get_tag_msg file-annotated-tag >actual &&
	test_cmp expect actual
'

get_tag_header file-annotated-tag-edit $commit commit $time >expect
sed -e "s/Another message/Another edited message/g" msgfile >>expect
test_expect_success 'set up editor' '
	write_script fakeeditor <<-\EOF
	sed -e "s/Another message/Another edited message/g" <"$1" >"$1-"
	mv "$1-" "$1"
	EOF
'
test_expect_success \
	'creating an annotated tag with -F messagefile --edit should succeed' '
	shit_EDITOR=./fakeeditor shit tag -F msgfile --edit file-annotated-tag-edit &&
	get_tag_msg file-annotated-tag-edit >actual &&
	test_cmp expect actual
'

cat >inputmsg <<EOF
A message from the
standard input
EOF
get_tag_header stdin-annotated-tag $commit commit $time >expect
cat inputmsg >>expect
test_expect_success 'creating an annotated tag with -F - should succeed' '
	shit tag -F - stdin-annotated-tag <inputmsg &&
	get_tag_msg stdin-annotated-tag >actual &&
	test_cmp expect actual
'

test_expect_success \
	'trying to create a tag with a non-existing -F file should fail' '
	! test -f nonexistingfile &&
	! tag_exists notag &&
	test_must_fail shit tag -F nonexistingfile notag &&
	! tag_exists notag
'

test_expect_success \
	'trying to create tags giving both -m or -F options should fail' '
	echo "message file 1" >msgfile1 &&
	! tag_exists msgtag &&
	test_must_fail shit tag -m "message 1" -F msgfile1 msgtag &&
	! tag_exists msgtag &&
	test_must_fail shit tag -F msgfile1 -m "message 1" msgtag &&
	! tag_exists msgtag &&
	test_must_fail shit tag -m "message 1" -F msgfile1 \
		-m "message 2" msgtag &&
	! tag_exists msgtag
'

# blank and empty messages:

get_tag_header empty-annotated-tag $commit commit $time >expect
test_expect_success \
	'creating a tag with an empty -m message should succeed' '
	shit tag -m "" empty-annotated-tag &&
	get_tag_msg empty-annotated-tag >actual &&
	test_cmp expect actual
'

>emptyfile
get_tag_header emptyfile-annotated-tag $commit commit $time >expect
test_expect_success \
	'creating a tag with an empty -F messagefile should succeed' '
	shit tag -F emptyfile emptyfile-annotated-tag &&
	get_tag_msg emptyfile-annotated-tag >actual &&
	test_cmp expect actual
'

printf '\n\n  \n\t\nLeading blank lines\n' >blanksfile
printf '\n\t \t  \nRepeated blank lines\n' >>blanksfile
printf '\n\n\nTrailing spaces      \t  \n' >>blanksfile
printf '\nTrailing blank lines\n\n\t \n\n' >>blanksfile
get_tag_header blanks-annotated-tag $commit commit $time >expect
cat >>expect <<EOF
Leading blank lines

Repeated blank lines

Trailing spaces

Trailing blank lines
EOF
test_expect_success \
	'extra blanks in the message for an annotated tag should be removed' '
	shit tag -F blanksfile blanks-annotated-tag &&
	get_tag_msg blanks-annotated-tag >actual &&
	test_cmp expect actual
'

get_tag_header blank-annotated-tag $commit commit $time >expect
test_expect_success \
	'creating a tag with blank -m message with spaces should succeed' '
	shit tag -m "     " blank-annotated-tag &&
	get_tag_msg blank-annotated-tag >actual &&
	test_cmp expect actual
'

echo '     ' >blankfile
echo ''      >>blankfile
echo '  '    >>blankfile
get_tag_header blankfile-annotated-tag $commit commit $time >expect
test_expect_success \
	'creating a tag with blank -F messagefile with spaces should succeed' '
	shit tag -F blankfile blankfile-annotated-tag &&
	get_tag_msg blankfile-annotated-tag >actual &&
	test_cmp expect actual
'

printf '      ' >blanknonlfile
get_tag_header blanknonlfile-annotated-tag $commit commit $time >expect
test_expect_success \
	'creating a tag with -F file of spaces and no newline should succeed' '
	shit tag -F blanknonlfile blanknonlfile-annotated-tag &&
	get_tag_msg blanknonlfile-annotated-tag >actual &&
	test_cmp expect actual
'

# messages with commented lines:

cat >commentsfile <<EOF
# A comment

############
The message.
############
One line.


# commented lines
# commented lines

Another line.
# comments

Last line.
EOF
get_tag_header comments-annotated-tag $commit commit $time >expect
cat >>expect <<EOF
The message.
One line.

Another line.

Last line.
EOF
test_expect_success \
	'creating a tag using a -F messagefile with #comments should succeed' '
	shit tag -F commentsfile comments-annotated-tag &&
	get_tag_msg comments-annotated-tag >actual &&
	test_cmp expect actual
'

get_tag_header comment-annotated-tag $commit commit $time >expect
test_expect_success \
	'creating a tag with a #comment in the -m message should succeed' '
	shit tag -m "#comment" comment-annotated-tag &&
	get_tag_msg comment-annotated-tag >actual &&
	test_cmp expect actual
'

echo '#comment' >commentfile
echo ''         >>commentfile
echo '####'     >>commentfile
get_tag_header commentfile-annotated-tag $commit commit $time >expect
test_expect_success \
	'creating a tag with #comments in the -F messagefile should succeed' '
	shit tag -F commentfile commentfile-annotated-tag &&
	get_tag_msg commentfile-annotated-tag >actual &&
	test_cmp expect actual
'

printf '#comment' >commentnonlfile
get_tag_header commentnonlfile-annotated-tag $commit commit $time >expect
test_expect_success \
	'creating a tag with a file of #comment and no newline should succeed' '
	shit tag -F commentnonlfile commentnonlfile-annotated-tag &&
	get_tag_msg commentnonlfile-annotated-tag >actual &&
	test_cmp expect actual
'

# trailers

test_expect_success 'create tag with -m and --trailer' '
	get_tag_header tag-with-inline-message-and-trailers $commit commit $time >expect &&
	cat >>expect <<-\EOF &&
	create tag with trailers

	my-trailer: here
	alt-trailer: there
	EOF
	shit tag -m "create tag with trailers" \
		--trailer my-trailer=here \
		--trailer alt-trailer=there \
		tag-with-inline-message-and-trailers &&
	get_tag_msg tag-with-inline-message-and-trailers >actual &&
	test_cmp expect actual
'

test_expect_success 'list tag extracting trailers' '
	cat >expect <<-\EOF &&
	my-trailer: here
	alt-trailer: there

	EOF
	shit tag --list --format="%(trailers)" tag-with-inline-message-and-trailers >actual &&
	test_cmp expect actual
'

test_expect_success 'create tag with -F and --trailer' '
	echo "create tag from message file using --trailer" >messagefilewithnotrailers &&
	get_tag_header tag-with-file-message-and-trailers $commit commit $time >expect &&
	cat >>expect <<-\EOF &&
	create tag from message file using --trailer

	my-trailer: here
	alt-trailer: there
	EOF
	shit tag -F messagefilewithnotrailers \
		--trailer my-trailer=here \
		--trailer alt-trailer=there \
		tag-with-file-message-and-trailers &&
	get_tag_msg tag-with-file-message-and-trailers >actual &&
	test_cmp expect actual
'

test_expect_success 'create tag with -m and --trailer and --edit' '
	write_script fakeeditor <<-\EOF &&
	sed -e "1s/^/EDITED: /g" <"$1" >"$1-"
	mv "$1-" "$1"
	EOF
	get_tag_header tag-with-edited-inline-message-and-trailers $commit commit $time >expect &&
	cat >>expect <<-\EOF &&
	EDITED: create tag with trailers

	my-trailer: here
	alt-trailer: there
	EOF
	shit_EDITOR=./fakeeditor shit tag --edit \
		-m "create tag with trailers" \
		--trailer my-trailer=here \
		--trailer alt-trailer=there \
		tag-with-edited-inline-message-and-trailers &&
	get_tag_msg tag-with-edited-inline-message-and-trailers >actual &&
	test_cmp expect actual
'

test_expect_success 'create tag with -F and --trailer and --edit' '
	echo "create tag from message file using --trailer" >messagefilewithnotrailers &&
	get_tag_header tag-with-edited-file-message-and-trailers $commit commit $time >expect &&
	cat >>expect <<-\EOF &&
	EDITED: create tag from message file using --trailer

	my-trailer: here
	alt-trailer: there
	EOF
	shit_EDITOR=./fakeeditor shit tag --edit \
		-F messagefilewithnotrailers \
		--trailer my-trailer=here \
		--trailer alt-trailer=there \
		tag-with-edited-file-message-and-trailers &&
	get_tag_msg tag-with-edited-file-message-and-trailers >actual &&
	test_cmp expect actual
'

test_expect_success 'create annotated tag and force editor when only --trailer is given' '
	write_script fakeeditor <<-\EOF &&
	echo "add a line" >"$1-"
	cat <"$1" >>"$1-"
	mv "$1-" "$1"
	EOF
	get_tag_header tag-with-trailers-and-no-message $commit commit $time >expect &&
	cat >>expect <<-\EOF &&
	add a line

	my-trailer: here
	alt-trailer: there
	EOF
	shit_EDITOR=./fakeeditor shit tag \
		--trailer my-trailer=here \
		--trailer alt-trailer=there \
		tag-with-trailers-and-no-message &&
	get_tag_msg tag-with-trailers-and-no-message >actual &&
	test_cmp expect actual
'

test_expect_success 'bad editor causes panic when only --trailer is given' '
	test_must_fail env shit_EDITOR=false shit tag --trailer my-trailer=here tag-will-not-exist
'

# listing messages for annotated non-signed tags:

test_expect_success \
	'listing the one-line message of a non-signed tag should succeed' '
	shit tag -m "A msg" tag-one-line &&

	echo "tag-one-line" >expect &&
	shit tag -l | grep "^tag-one-line" >actual &&
	test_cmp expect actual &&
	shit tag -n0 -l | grep "^tag-one-line" >actual &&
	test_cmp expect actual &&
	shit tag -n0 -l tag-one-line >actual &&
	test_cmp expect actual &&

	shit tag -n0 | grep "^tag-one-line" >actual &&
	test_cmp expect actual &&
	shit tag -n0 tag-one-line >actual &&
	test_cmp expect actual &&

	echo "tag-one-line    A msg" >expect &&
	shit tag -n1 -l | grep "^tag-one-line" >actual &&
	test_cmp expect actual &&
	shit tag -n -l | grep "^tag-one-line" >actual &&
	test_cmp expect actual &&
	shit tag -n1 -l tag-one-line >actual &&
	test_cmp expect actual &&
	shit tag -n2 -l tag-one-line >actual &&
	test_cmp expect actual &&
	shit tag -n999 -l tag-one-line >actual &&
	test_cmp expect actual
'

test_expect_success 'The -n 100 invocation means -n --list 100, not -n100' '
	shit tag -n 100 >actual &&
	test_must_be_empty actual &&

	shit tag -m "A msg" 100 &&
	echo "100             A msg" >expect &&
	shit tag -n 100 >actual &&
	test_cmp expect actual
'

test_expect_success \
	'listing the zero-lines message of a non-signed tag should succeed' '
	shit tag -m "" tag-zero-lines &&

	echo "tag-zero-lines" >expect &&
	shit tag -l | grep "^tag-zero-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n0 -l | grep "^tag-zero-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n0 -l tag-zero-lines >actual &&
	test_cmp expect actual &&

	echo "tag-zero-lines  " >expect &&
	shit tag -n1 -l | grep "^tag-zero-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n -l | grep "^tag-zero-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n1 -l tag-zero-lines >actual &&
	test_cmp expect actual &&
	shit tag -n2 -l tag-zero-lines >actual &&
	test_cmp expect actual &&
	shit tag -n999 -l tag-zero-lines >actual &&
	test_cmp expect actual
'

echo 'tag line one' >annotagmsg
echo 'tag line two' >>annotagmsg
echo 'tag line three' >>annotagmsg
test_expect_success \
	'listing many message lines of a non-signed tag should succeed' '
	shit tag -F annotagmsg tag-lines &&

	echo "tag-lines" >expect &&
	shit tag -l | grep "^tag-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n0 -l | grep "^tag-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n0 -l tag-lines >actual &&
	test_cmp expect actual &&

	echo "tag-lines       tag line one" >expect &&
	shit tag -n1 -l | grep "^tag-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n -l | grep "^tag-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n1 -l tag-lines >actual &&
	test_cmp expect actual &&

	echo "    tag line two" >>expect &&
	shit tag -n2 -l | grep "^ *tag.line" >actual &&
	test_cmp expect actual &&
	shit tag -n2 -l tag-lines >actual &&
	test_cmp expect actual &&

	echo "    tag line three" >>expect &&
	shit tag -n3 -l | grep "^ *tag.line" >actual &&
	test_cmp expect actual &&
	shit tag -n3 -l tag-lines >actual &&
	test_cmp expect actual &&
	shit tag -n4 -l | grep "^ *tag.line" >actual &&
	test_cmp expect actual &&
	shit tag -n4 -l tag-lines >actual &&
	test_cmp expect actual &&
	shit tag -n99 -l | grep "^ *tag.line" >actual &&
	test_cmp expect actual &&
	shit tag -n99 -l tag-lines >actual &&
	test_cmp expect actual
'

test_expect_success 'annotations for blobs are empty' '
	blob=$(shit hash-object -w --stdin <<-\EOF
	Blob paragraph 1.

	Blob paragraph 2.
	EOF
	) &&
	shit tag tag-blob $blob &&
	echo "tag-blob        " >expect &&
	shit tag -n1 -l tag-blob >actual &&
	test_cmp expect actual
'

# Run this before doing any signing, so the test has the same results
# regardless of the GPG prereq.
test_expect_success 'shit tag --format with ahead-behind' '
	test_when_finished shit reset --hard tag-one-line &&
	shit commit --allow-empty -m "left" &&
	shit tag -a -m left tag-left &&
	shit reset --hard HEAD~1 &&
	shit commit --allow-empty -m "right" &&
	shit tag -a -m left tag-right &&

	# Use " !" at the end to demonstrate whitespace
	# around empty ahead-behind token for tag-blob.
	cat >expect <<-EOF &&
	refs/tags/tag-blob  !
	refs/tags/tag-left 1 1 !
	refs/tags/tag-lines 0 1 !
	refs/tags/tag-one-line 0 1 !
	refs/tags/tag-right 0 0 !
	refs/tags/tag-with-edited-file-message-and-trailers 0 1 !
	refs/tags/tag-with-edited-inline-message-and-trailers 0 1 !
	refs/tags/tag-with-file-message-and-trailers 0 1 !
	refs/tags/tag-with-inline-message-and-trailers 0 1 !
	refs/tags/tag-with-trailers-and-no-message 0 1 !
	refs/tags/tag-zero-lines 0 1 !
	EOF
	shit tag -l --format="%(refname) %(ahead-behind:HEAD) !" >actual 2>err &&
	grep "refs/tags/tag" actual >actual.focus &&
	test_cmp expect actual.focus &&

	# Error reported for tags that point to non-commits.
	grep "error: object [0-9a-f]* is a blob, not a commit" err
'

# trying to verify annotated non-signed tags:

test_expect_success GPG \
	'trying to verify an annotated non-signed tag should fail' '
	tag_exists annotated-tag &&
	test_must_fail shit tag -v annotated-tag
'

test_expect_success GPG \
	'trying to verify a file-annotated non-signed tag should fail' '
	tag_exists file-annotated-tag &&
	test_must_fail shit tag -v file-annotated-tag
'

test_expect_success GPG \
	'trying to verify two annotated non-signed tags should fail' '
	tag_exists annotated-tag file-annotated-tag &&
	test_must_fail shit tag -v annotated-tag file-annotated-tag
'

# creating and verifying signed tags:

get_tag_header signed-tag $commit commit $time >expect
echo 'A signed tag message' >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG 'creating a signed tag with -m message should succeed' '
	shit tag -s -m "A signed tag message" signed-tag &&
	get_tag_msg signed-tag >actual &&
	test_cmp expect actual
'

get_tag_header u-signed-tag $commit commit $time >expect
echo 'Another message' >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG 'sign with a given key id' '

	shit tag -u committer@example.com -m "Another message" u-signed-tag &&
	get_tag_msg u-signed-tag >actual &&
	test_cmp expect actual

'

test_expect_success GPG 'sign with an unknown id (1)' '

	test_must_fail shit tag -u author@example.com \
		-m "Another message" o-signed-tag

'

test_expect_success GPG 'sign with an unknown id (2)' '

	test_must_fail shit tag -u DEADBEEF -m "Another message" o-signed-tag

'

cat >fakeeditor <<'EOF'
#!/bin/sh
test -n "$1" && exec >"$1"
echo A signed tag message
echo from a fake editor.
EOF
chmod +x fakeeditor

get_tag_header implied-sign $commit commit $time >expect
./fakeeditor >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG '-u implies signed tag' '
	shit_EDITOR=./fakeeditor shit tag -u CDDE430D implied-sign &&
	get_tag_msg implied-sign >actual &&
	test_cmp expect actual
'

cat >sigmsgfile <<EOF
Another signed tag
message in a file.
EOF
get_tag_header file-signed-tag $commit commit $time >expect
cat sigmsgfile >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with -F messagefile should succeed' '
	shit tag -s -F sigmsgfile file-signed-tag &&
	get_tag_msg file-signed-tag >actual &&
	test_cmp expect actual
'

cat >siginputmsg <<EOF
A signed tag message from
the standard input
EOF
get_tag_header stdin-signed-tag $commit commit $time >expect
cat siginputmsg >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG 'creating a signed tag with -F - should succeed' '
	shit tag -s -F - stdin-signed-tag <siginputmsg &&
	get_tag_msg stdin-signed-tag >actual &&
	test_cmp expect actual
'

get_tag_header implied-annotate $commit commit $time >expect
./fakeeditor >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG '-s implies annotated tag' '
	shit_EDITOR=./fakeeditor shit tag -s implied-annotate &&
	get_tag_msg implied-annotate >actual &&
	test_cmp expect actual
'

get_tag_header forcesignannotated-implied-sign $commit commit $time >expect
echo "A message" >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'shit tag -s implied if configured with tag.forcesignannotated' \
	'test_config tag.forcesignannotated true &&
	shit tag -m "A message" forcesignannotated-implied-sign &&
	get_tag_msg forcesignannotated-implied-sign >actual &&
	test_cmp expect actual
'

test_expect_success GPG \
	'lightweight with no message when configured with tag.forcesignannotated' \
	'test_config tag.forcesignannotated true &&
	shit tag forcesignannotated-lightweight &&
	tag_exists forcesignannotated-lightweight &&
	test_must_fail shit tag -v forcesignannotated-no-message
'

get_tag_header forcesignannotated-annotate $commit commit $time >expect
echo "A message" >>expect
test_expect_success GPG \
	'shit tag -a disable configured tag.forcesignannotated' \
	'test_config tag.forcesignannotated true &&
	shit tag -a -m "A message" forcesignannotated-annotate &&
	get_tag_msg forcesignannotated-annotate >actual &&
	test_cmp expect actual &&
	test_must_fail shit tag -v forcesignannotated-annotate
'

get_tag_header forcesignannotated-disabled $commit commit $time >expect
echo "A message" >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'shit tag --sign enable GPG sign' \
	'test_config tag.forcesignannotated false &&
	shit tag --sign -m "A message" forcesignannotated-disabled &&
	get_tag_msg forcesignannotated-disabled >actual &&
	test_cmp expect actual
'

get_tag_header gpgsign-enabled $commit commit $time >expect
echo "A message" >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'shit tag configured tag.gpgsign enables GPG sign' \
	'test_config tag.gpgsign true &&
	shit tag -m "A message" gpgsign-enabled &&
	get_tag_msg gpgsign-enabled>actual &&
	test_cmp expect actual
'

get_tag_header no-sign $commit commit $time >expect
echo "A message" >>expect
test_expect_success GPG \
	'shit tag --no-sign configured tag.gpgsign skip GPG sign' \
	'test_config tag.gpgsign true &&
	shit tag -a --no-sign -m "A message" no-sign &&
	get_tag_msg no-sign>actual &&
	test_cmp expect actual
'

test_expect_success GPG \
	'trying to create a signed tag with non-existing -F file should fail' '
	! test -f nonexistingfile &&
	! tag_exists nosigtag &&
	test_must_fail shit tag -s -F nonexistingfile nosigtag &&
	! tag_exists nosigtag
'

test_expect_success GPG 'verifying a signed tag should succeed' \
	'shit tag -v signed-tag'

test_expect_success GPG 'verifying two signed tags in one command should succeed' \
	'shit tag -v signed-tag file-signed-tag'

test_expect_success GPG \
	'verifying many signed and non-signed tags should fail' '
	test_must_fail shit tag -v signed-tag annotated-tag &&
	test_must_fail shit tag -v file-annotated-tag file-signed-tag &&
	test_must_fail shit tag -v annotated-tag \
		file-signed-tag file-annotated-tag &&
	test_must_fail shit tag -v signed-tag annotated-tag file-signed-tag
'

test_expect_success GPG 'verifying a forged tag should fail' '
	forged=$(shit cat-file tag signed-tag |
		sed -e "s/signed-tag/forged-tag/" |
		shit mktag) &&
	shit tag forged-tag $forged &&
	test_must_fail shit tag -v forged-tag
'

test_expect_success GPG 'verifying a proper tag with --format pass and format accordingly' '
	cat >expect <<-\EOF &&
	tagname : signed-tag
	EOF
	shit tag -v --format="tagname : %(tag)" "signed-tag" >actual &&
	test_cmp expect actual
'

test_expect_success GPG 'verifying a forged tag with --format should fail silently' '
	test_must_fail shit tag -v --format="tagname : %(tag)" "forged-tag" >actual &&
	test_must_be_empty actual
'

# blank and empty messages for signed tags:

get_tag_header empty-signed-tag $commit commit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with an empty -m message should succeed' '
	shit tag -s -m "" empty-signed-tag &&
	get_tag_msg empty-signed-tag >actual &&
	test_cmp expect actual &&
	shit tag -v empty-signed-tag
'

>sigemptyfile
get_tag_header emptyfile-signed-tag $commit commit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with an empty -F messagefile should succeed' '
	shit tag -s -F sigemptyfile emptyfile-signed-tag &&
	get_tag_msg emptyfile-signed-tag >actual &&
	test_cmp expect actual &&
	shit tag -v emptyfile-signed-tag
'

printf '\n\n  \n\t\nLeading blank lines\n' > sigblanksfile
printf '\n\t \t  \nRepeated blank lines\n' >>sigblanksfile
printf '\n\n\nTrailing spaces      \t  \n' >>sigblanksfile
printf '\nTrailing blank lines\n\n\t \n\n' >>sigblanksfile
get_tag_header blanks-signed-tag $commit commit $time >expect
cat >>expect <<EOF
Leading blank lines

Repeated blank lines

Trailing spaces

Trailing blank lines
EOF
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'extra blanks in the message for a signed tag should be removed' '
	shit tag -s -F sigblanksfile blanks-signed-tag &&
	get_tag_msg blanks-signed-tag >actual &&
	test_cmp expect actual &&
	shit tag -v blanks-signed-tag
'

get_tag_header blank-signed-tag $commit commit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with a blank -m message should succeed' '
	shit tag -s -m "     " blank-signed-tag &&
	get_tag_msg blank-signed-tag >actual &&
	test_cmp expect actual &&
	shit tag -v blank-signed-tag
'

echo '     ' >sigblankfile
echo ''      >>sigblankfile
echo '  '    >>sigblankfile
get_tag_header blankfile-signed-tag $commit commit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with blank -F file with spaces should succeed' '
	shit tag -s -F sigblankfile blankfile-signed-tag &&
	get_tag_msg blankfile-signed-tag >actual &&
	test_cmp expect actual &&
	shit tag -v blankfile-signed-tag
'

printf '      ' >sigblanknonlfile
get_tag_header blanknonlfile-signed-tag $commit commit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with spaces and no newline should succeed' '
	shit tag -s -F sigblanknonlfile blanknonlfile-signed-tag &&
	get_tag_msg blanknonlfile-signed-tag >actual &&
	test_cmp expect actual &&
	shit tag -v blanknonlfile-signed-tag
'

test_expect_success GPG 'signed tag with embedded PGP message' '
	cat >msg <<-\EOF &&
	-----BEGIN PGP MESSAGE-----

	this is not a real PGP message
	-----END PGP MESSAGE-----
	EOF
	shit tag -s -F msg confusing-pgp-message &&
	shit tag -v confusing-pgp-message
'

# messages with commented lines for signed tags:

cat >sigcommentsfile <<EOF
# A comment

############
The message.
############
One line.


# commented lines
# commented lines

Another line.
# comments

Last line.
EOF
get_tag_header comments-signed-tag $commit commit $time >expect
cat >>expect <<EOF
The message.
One line.

Another line.

Last line.
EOF
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with a -F file with #comments should succeed' '
	shit tag -s -F sigcommentsfile comments-signed-tag &&
	get_tag_msg comments-signed-tag >actual &&
	test_cmp expect actual &&
	shit tag -v comments-signed-tag
'

get_tag_header comment-signed-tag $commit commit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with #commented -m message should succeed' '
	shit tag -s -m "#comment" comment-signed-tag &&
	get_tag_msg comment-signed-tag >actual &&
	test_cmp expect actual &&
	shit tag -v comment-signed-tag
'

echo '#comment' >sigcommentfile
echo ''         >>sigcommentfile
echo '####'     >>sigcommentfile
get_tag_header commentfile-signed-tag $commit commit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with #commented -F messagefile should succeed' '
	shit tag -s -F sigcommentfile commentfile-signed-tag &&
	get_tag_msg commentfile-signed-tag >actual &&
	test_cmp expect actual &&
	shit tag -v commentfile-signed-tag
'

printf '#comment' >sigcommentnonlfile
get_tag_header commentnonlfile-signed-tag $commit commit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with a #comment and no newline should succeed' '
	shit tag -s -F sigcommentnonlfile commentnonlfile-signed-tag &&
	get_tag_msg commentnonlfile-signed-tag >actual &&
	test_cmp expect actual &&
	shit tag -v commentnonlfile-signed-tag
'

# listing messages for signed tags:

test_expect_success GPG \
	'listing the one-line message of a signed tag should succeed' '
	shit tag -s -m "A message line signed" stag-one-line &&

	echo "stag-one-line" >expect &&
	shit tag -l | grep "^stag-one-line" >actual &&
	test_cmp expect actual &&
	shit tag -n0 -l | grep "^stag-one-line" >actual &&
	test_cmp expect actual &&
	shit tag -n0 -l stag-one-line >actual &&
	test_cmp expect actual &&

	echo "stag-one-line   A message line signed" >expect &&
	shit tag -n1 -l | grep "^stag-one-line" >actual &&
	test_cmp expect actual &&
	shit tag -n -l | grep "^stag-one-line" >actual &&
	test_cmp expect actual &&
	shit tag -n1 -l stag-one-line >actual &&
	test_cmp expect actual &&
	shit tag -n2 -l stag-one-line >actual &&
	test_cmp expect actual &&
	shit tag -n999 -l stag-one-line >actual &&
	test_cmp expect actual
'

test_expect_success GPG \
	'listing the zero-lines message of a signed tag should succeed' '
	shit tag -s -m "" stag-zero-lines &&

	echo "stag-zero-lines" >expect &&
	shit tag -l | grep "^stag-zero-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n0 -l | grep "^stag-zero-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n0 -l stag-zero-lines >actual &&
	test_cmp expect actual &&

	echo "stag-zero-lines " >expect &&
	shit tag -n1 -l | grep "^stag-zero-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n -l | grep "^stag-zero-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n1 -l stag-zero-lines >actual &&
	test_cmp expect actual &&
	shit tag -n2 -l stag-zero-lines >actual &&
	test_cmp expect actual &&
	shit tag -n999 -l stag-zero-lines >actual &&
	test_cmp expect actual
'

echo 'stag line one' >sigtagmsg
echo 'stag line two' >>sigtagmsg
echo 'stag line three' >>sigtagmsg
test_expect_success GPG \
	'listing many message lines of a signed tag should succeed' '
	shit tag -s -F sigtagmsg stag-lines &&

	echo "stag-lines" >expect &&
	shit tag -l | grep "^stag-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n0 -l | grep "^stag-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n0 -l stag-lines >actual &&
	test_cmp expect actual &&

	echo "stag-lines      stag line one" >expect &&
	shit tag -n1 -l | grep "^stag-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n -l | grep "^stag-lines" >actual &&
	test_cmp expect actual &&
	shit tag -n1 -l stag-lines >actual &&
	test_cmp expect actual &&

	echo "    stag line two" >>expect &&
	shit tag -n2 -l | grep "^ *stag.line" >actual &&
	test_cmp expect actual &&
	shit tag -n2 -l stag-lines >actual &&
	test_cmp expect actual &&

	echo "    stag line three" >>expect &&
	shit tag -n3 -l | grep "^ *stag.line" >actual &&
	test_cmp expect actual &&
	shit tag -n3 -l stag-lines >actual &&
	test_cmp expect actual &&
	shit tag -n4 -l | grep "^ *stag.line" >actual &&
	test_cmp expect actual &&
	shit tag -n4 -l stag-lines >actual &&
	test_cmp expect actual &&
	shit tag -n99 -l | grep "^ *stag.line" >actual &&
	test_cmp expect actual &&
	shit tag -n99 -l stag-lines >actual &&
	test_cmp expect actual
'

# tags pointing to objects different from commits:

tree=$(shit rev-parse HEAD^{tree})
blob=$(shit rev-parse HEAD:foo)
tag=$(shit rev-parse signed-tag 2>/dev/null)

get_tag_header tree-signed-tag $tree tree $time >expect
echo "A message for a tree" >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag pointing to a tree should succeed' '
	shit tag -s -m "A message for a tree" tree-signed-tag HEAD^{tree} &&
	get_tag_msg tree-signed-tag >actual &&
	test_cmp expect actual
'

get_tag_header blob-signed-tag $blob blob $time >expect
echo "A message for a blob" >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag pointing to a blob should succeed' '
	shit tag -s -m "A message for a blob" blob-signed-tag HEAD:foo &&
	get_tag_msg blob-signed-tag >actual &&
	test_cmp expect actual
'

get_tag_header tag-signed-tag $tag tag $time >expect
echo "A message for another tag" >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag pointing to another tag should succeed' '
	shit tag -s -m "A message for another tag" tag-signed-tag signed-tag &&
	get_tag_msg tag-signed-tag >actual &&
	test_cmp expect actual
'

# usage with rfc1991 signatures
get_tag_header rfc1991-signed-tag $commit commit $time >expect
echo "RFC1991 signed tag" >>expect
echo '-----BEGIN PGP MESSAGE-----' >>expect
test_expect_success GPG,RFC1991 \
	'creating a signed tag with rfc1991' '
	echo "rfc1991" >gpghome/gpg.conf &&
	shit tag -s -m "RFC1991 signed tag" rfc1991-signed-tag $commit &&
	get_tag_msg rfc1991-signed-tag >actual &&
	test_cmp expect actual
'

cat >fakeeditor <<'EOF'
#!/bin/sh
cp "$1" actual
EOF
chmod +x fakeeditor

test_expect_success GPG,RFC1991 \
	'reediting a signed tag body omits signature' '
	echo "rfc1991" >gpghome/gpg.conf &&
	echo "RFC1991 signed tag" >expect &&
	shit_EDITOR=./fakeeditor shit tag -f -s rfc1991-signed-tag $commit &&
	test_cmp expect actual
'

test_expect_success GPG,RFC1991 \
	'verifying rfc1991 signature' '
	echo "rfc1991" >gpghome/gpg.conf &&
	shit tag -v rfc1991-signed-tag
'

test_expect_success GPG,RFC1991 \
	'list tag with rfc1991 signature' '
	echo "rfc1991" >gpghome/gpg.conf &&
	echo "rfc1991-signed-tag RFC1991 signed tag" >expect &&
	shit tag -l -n1 rfc1991-signed-tag >actual &&
	test_cmp expect actual &&
	shit tag -l -n2 rfc1991-signed-tag >actual &&
	test_cmp expect actual &&
	shit tag -l -n999 rfc1991-signed-tag >actual &&
	test_cmp expect actual
'

rm -f gpghome/gpg.conf

test_expect_success GPG,RFC1991 \
	'verifying rfc1991 signature without --rfc1991' '
	shit tag -v rfc1991-signed-tag
'

test_expect_success GPG,RFC1991 \
	'list tag with rfc1991 signature without --rfc1991' '
	echo "rfc1991-signed-tag RFC1991 signed tag" >expect &&
	shit tag -l -n1 rfc1991-signed-tag >actual &&
	test_cmp expect actual &&
	shit tag -l -n2 rfc1991-signed-tag >actual &&
	test_cmp expect actual &&
	shit tag -l -n999 rfc1991-signed-tag >actual &&
	test_cmp expect actual
'

test_expect_success GPG,RFC1991 \
	'reediting a signed tag body omits signature' '
	echo "RFC1991 signed tag" >expect &&
	shit_EDITOR=./fakeeditor shit tag -f -s rfc1991-signed-tag $commit &&
	test_cmp expect actual
'

# try to sign with bad user.signingkey
test_expect_success GPG \
	'shit tag -s fails if gpg is misconfigured (bad key)' \
	'test_config user.signingkey BobTheMouse &&
	test_must_fail shit tag -s -m tail tag-gpg-failure'

# try to produce invalid signature
test_expect_success GPG \
	'shit tag -s fails if gpg is misconfigured (bad signature format)' \
	'test_config gpg.program echo &&
	 test_must_fail shit tag -s -m tail tag-gpg-failure'

# try to produce invalid signature
test_expect_success GPG 'shit verifies tag is valid with double signature' '
	shit tag -s -m tail tag-gpg-double-sig &&
	shit cat-file tag tag-gpg-double-sig >tag &&
	othersigheader=$(test_oid othersigheader) &&
	sed -ne "/^\$/q;p" tag >new-tag &&
	cat <<-EOM >>new-tag &&
	$othersigheader -----BEGIN PGP SIGNATURE-----
	 someinvaliddata
	 -----END PGP SIGNATURE-----
	EOM
	sed -e "1,/^tagger/d" tag >>new-tag &&
	new_tag=$(shit hash-object -t tag -w new-tag) &&
	shit update-ref refs/tags/tag-gpg-double-sig $new_tag &&
	shit verify-tag tag-gpg-double-sig &&
	shit fsck
'

# try to sign with bad user.signingkey
test_expect_success GPGSM \
	'shit tag -s fails if gpgsm is misconfigured (bad key)' \
	'test_config user.signingkey BobTheMouse &&
	 test_config gpg.format x509 &&
	 test_must_fail shit tag -s -m tail tag-gpg-failure'

# try to produce invalid signature
test_expect_success GPGSM \
	'shit tag -s fails if gpgsm is misconfigured (bad signature format)' \
	'test_config gpg.x509.program echo &&
	 test_config gpg.format x509 &&
	 test_must_fail shit tag -s -m tail tag-gpg-failure'

# try to verify without gpg:

rm -rf gpghome
test_expect_success GPG \
	'verify signed tag fails when public key is not present' \
	'test_must_fail shit tag -v signed-tag'

test_expect_success \
	'shit tag -a fails if tag annotation is empty' '
	! (shit_EDITOR=cat shit tag -a initial-comment)
'

test_expect_success \
	'message in editor has initial comment' '
	! (shit_EDITOR=cat shit tag -a initial-comment > actual)
'

test_expect_success 'message in editor has initial comment: first line' '
	# check the first line --- should be empty
	echo >first.expect &&
	sed -e 1q <actual >first.actual &&
	test_cmp first.expect first.actual
'

test_expect_success \
	'message in editor has initial comment: remainder' '
	# remove commented lines from the remainder -- should be empty
	sed -e 1d -e "/^#/d" <actual >rest.actual &&
	test_must_be_empty rest.actual
'

get_tag_header reuse $commit commit $time >expect
echo "An annotation to be reused" >> expect
test_expect_success \
	'overwriting an annotated tag should use its previous body' '
	shit tag -a -m "An annotation to be reused" reuse &&
	shit_EDITOR=true shit tag -f -a reuse &&
	get_tag_msg reuse >actual &&
	test_cmp expect actual
'

test_expect_success 'filename for the message is relative to cwd' '
	mkdir subdir &&
	echo "Tag message in top directory" >msgfile-5 &&
	echo "Tag message in sub directory" >subdir/msgfile-5 &&
	(
		cd subdir &&
		shit tag -a -F msgfile-5 tag-from-subdir
	) &&
	shit cat-file tag tag-from-subdir | grep "in sub directory"
'

test_expect_success 'filename for the message is relative to cwd' '
	echo "Tag message in sub directory" >subdir/msgfile-6 &&
	(
		cd subdir &&
		shit tag -a -F msgfile-6 tag-from-subdir-2
	) &&
	shit cat-file tag tag-from-subdir-2 | grep "in sub directory"
'

# create a few more commits to test --contains

hash1=$(shit rev-parse HEAD)

test_expect_success 'creating second commit and tag' '
	echo foo-2.0 >foo &&
	shit add foo &&
	shit commit -m second &&
	shit tag v2.0
'

hash2=$(shit rev-parse HEAD)

test_expect_success 'creating third commit without tag' '
	echo foo-dev >foo &&
	shit add foo &&
	shit commit -m third
'

hash3=$(shit rev-parse HEAD)

# simple linear checks of --continue

cat > expected <<EOF
v0.2.1
v1.0
v1.0.1
v1.1.3
v2.0
EOF

test_expect_success 'checking that first commit is in all tags (hash)' "
	shit tag -l --contains $hash1 v* >actual &&
	test_cmp expected actual
"

# other ways of specifying the commit
test_expect_success 'checking that first commit is in all tags (tag)' "
	shit tag -l --contains v1.0 v* >actual &&
	test_cmp expected actual
"

test_expect_success 'checking that first commit is in all tags (relative)' "
	shit tag -l --contains HEAD~2 v* >actual &&
	test_cmp expected actual
"

# All the --contains tests above, but with --no-contains
test_expect_success 'checking that first commit is not listed in any tag with --no-contains  (hash)' "
	shit tag -l --no-contains $hash1 v* >actual &&
	test_must_be_empty actual
"

test_expect_success 'checking that first commit is in all tags (tag)' "
	shit tag -l --no-contains v1.0 v* >actual &&
	test_must_be_empty actual
"

test_expect_success 'checking that first commit is in all tags (relative)' "
	shit tag -l --no-contains HEAD~2 v* >actual &&
	test_must_be_empty actual
"

cat > expected <<EOF
v2.0
EOF

test_expect_success 'checking that second commit only has one tag' "
	shit tag -l --contains $hash2 v* >actual &&
	test_cmp expected actual
"

cat > expected <<EOF
v0.2.1
v1.0
v1.0.1
v1.1.3
EOF

test_expect_success 'inverse of the last test, with --no-contains' "
	shit tag -l --no-contains $hash2 v* >actual &&
	test_cmp expected actual
"

test_expect_success 'checking that third commit has no tags' "
	shit tag -l --contains $hash3 v* >actual &&
	test_must_be_empty actual
"

cat > expected <<EOF
v0.2.1
v1.0
v1.0.1
v1.1.3
v2.0
EOF

test_expect_success 'conversely --no-contains on the third commit lists all tags' "
	shit tag -l --no-contains $hash3 v* >actual &&
	test_cmp expected actual
"

# how about a simple merge?

test_expect_success 'creating simple branch' '
	shit branch stable v2.0 &&
        shit checkout stable &&
	echo foo-3.0 > foo &&
	shit commit foo -m fourth &&
	shit tag v3.0
'

hash4=$(shit rev-parse HEAD)

cat > expected <<EOF
v3.0
EOF

test_expect_success 'checking that branch head only has one tag' "
	shit tag -l --contains $hash4 v* >actual &&
	test_cmp expected actual
"

cat > expected <<EOF
v0.2.1
v1.0
v1.0.1
v1.1.3
v2.0
EOF

test_expect_success 'checking that branch head with --no-contains lists all but one tag' "
	shit tag -l --no-contains $hash4 v* >actual &&
	test_cmp expected actual
"

test_expect_success 'merging original branch into this branch' '
	shit merge --strategy=ours main &&
        shit tag v4.0
'

cat > expected <<EOF
v4.0
EOF

test_expect_success 'checking that original branch head has one tag now' "
	shit tag -l --contains $hash3 v* >actual &&
	test_cmp expected actual
"

cat > expected <<EOF
v0.2.1
v1.0
v1.0.1
v1.1.3
v2.0
v3.0
EOF

test_expect_success 'checking that original branch head with --no-contains lists all but one tag now' "
	shit tag -l --no-contains $hash3 v* >actual &&
	test_cmp expected actual
"

cat > expected <<EOF
v0.2.1
v1.0
v1.0.1
v1.1.3
v2.0
v3.0
v4.0
EOF

test_expect_success 'checking that initial commit is in all tags' "
	shit tag -l --contains $hash1 v* >actual &&
	test_cmp expected actual
"

test_expect_success 'checking that --contains can be used in non-list mode' '
	shit tag --contains $hash1 v* >actual &&
	test_cmp expected actual
'

test_expect_success 'checking that initial commit is in all tags with --no-contains' "
	shit tag -l --no-contains $hash1 v* >actual &&
	test_must_be_empty actual
"

# mixing modes and options:

test_expect_success 'mixing incompatibles modes and options is forbidden' '
	test_must_fail shit tag -a &&
	test_must_fail shit tag -a -l &&
	test_must_fail shit tag -s &&
	test_must_fail shit tag -s -l &&
	test_must_fail shit tag -m &&
	test_must_fail shit tag -m -l &&
	test_must_fail shit tag -m "hlagh" &&
	test_must_fail shit tag -m "hlagh" -l &&
	test_must_fail shit tag -F &&
	test_must_fail shit tag -F -l &&
	test_must_fail shit tag -f &&
	test_must_fail shit tag -f -l &&
	test_must_fail shit tag -a -s -m -F &&
	test_must_fail shit tag -a -s -m -F -l &&
	test_must_fail shit tag -l -v &&
	test_must_fail shit tag -l -d &&
	test_must_fail shit tag -l -v -d &&
	test_must_fail shit tag -n 100 -v &&
	test_must_fail shit tag -l -m msg &&
	test_must_fail shit tag -l -F some file &&
	test_must_fail shit tag -v -s &&
	test_must_fail shit tag --contains tag-tree &&
	test_must_fail shit tag --contains tag-blob &&
	test_must_fail shit tag --no-contains tag-tree &&
	test_must_fail shit tag --no-contains tag-blob &&
	test_must_fail shit tag --contains --no-contains &&
	test_must_fail shit tag --no-with HEAD &&
	test_must_fail shit tag --no-without HEAD
'

for option in --contains --with --no-contains --without --merged --no-merged --points-at
do
	test_expect_success "mixing incompatible modes with $option is forbidden" "
		test_must_fail shit tag -d $option HEAD &&
		test_must_fail shit tag -d $option HEAD some-tag &&
		test_must_fail shit tag -v $option HEAD
	"
	test_expect_success "Doing 'shit tag --list-like $option <commit> <pattern> is permitted" "
		shit tag -n $option HEAD HEAD &&
		shit tag $option HEAD HEAD &&
		shit tag $option
	"
done

# check points-at

test_expect_success '--points-at can be used in non-list mode' '
	echo v4.0 >expect &&
	shit tag --points-at=v4.0 "v*" >actual &&
	test_cmp expect actual
'

test_expect_success '--points-at is a synonym for --points-at HEAD' '
	echo v4.0 >expect &&
	shit tag --points-at >actual &&
	test_cmp expect actual
'

test_expect_success '--points-at finds lightweight tags' '
	echo v4.0 >expect &&
	shit tag --points-at v4.0 >actual &&
	test_cmp expect actual
'

test_expect_success '--points-at finds annotated tags of commits' '
	shit tag -m "v4.0, annotated" annotated-v4.0 v4.0 &&
	echo annotated-v4.0 >expect &&
	shit tag -l --points-at v4.0 "annotated*" >actual &&
	test_cmp expect actual
'

test_expect_success '--points-at finds annotated tags of tags' '
	shit tag -m "describing the v4.0 tag object" \
		annotated-again-v4.0 annotated-v4.0 &&
	cat >expect <<-\EOF &&
	annotated-again-v4.0
	annotated-v4.0
	EOF
	shit tag --points-at=annotated-v4.0 >actual &&
	test_cmp expect actual
'

test_expect_success 'recursive tagging should give advice' '
	cat >expect <<-EOF &&
	hint: You have created a nested tag. The object referred to by your new tag is
	hint: already a tag. If you meant to tag the object that it points to, use:
	hint:
	hint: 	shit tag -f nested annotated-v4.0^{}
	hint: Disable this message with "shit config advice.nestedTag false"
	EOF
	shit tag -m nested nested annotated-v4.0 2>actual &&
	test_cmp expect actual
'

test_expect_success 'multiple --points-at are OR-ed together' '
	cat >expect <<-\EOF &&
	v2.0
	v3.0
	EOF
	shit tag --points-at=v2.0 --points-at=v3.0 >actual &&
	test_cmp expect actual
'

test_expect_success 'lexical sort' '
	shit tag foo1.3 &&
	shit tag foo1.6 &&
	shit tag foo1.10 &&
	shit tag -l --sort=refname "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.10
	foo1.3
	foo1.6
	EOF
	test_cmp expect actual
'

test_expect_success 'version sort' '
	shit tag -l --sort=version:refname "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.3
	foo1.6
	foo1.10
	EOF
	test_cmp expect actual
'

test_expect_success 'reverse version sort' '
	shit tag -l --sort=-version:refname "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.10
	foo1.6
	foo1.3
	EOF
	test_cmp expect actual
'

test_expect_success 'reverse lexical sort' '
	shit tag -l --sort=-refname "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.6
	foo1.3
	foo1.10
	EOF
	test_cmp expect actual
'

test_expect_success 'configured lexical sort' '
	test_config tag.sort "v:refname" &&
	shit tag -l "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.3
	foo1.6
	foo1.10
	EOF
	test_cmp expect actual
'

test_expect_success 'option override configured sort' '
	test_config tag.sort "v:refname" &&
	shit tag -l --sort=-refname "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.6
	foo1.3
	foo1.10
	EOF
	test_cmp expect actual
'

test_expect_success '--no-sort cancels config sort keys' '
	test_config tag.sort "-refname" &&

	# objecttype is identical for all of them, so sort falls back on
	# default (ascending refname)
	shit tag -l \
		--no-sort \
		--sort="objecttype" \
		"foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.10
	foo1.3
	foo1.6
	EOF
	test_cmp expect actual
'

test_expect_success '--no-sort cancels command line sort keys' '
	# objecttype is identical for all of them, so sort falls back on
	# default (ascending refname)
	shit tag -l \
		--sort="-refname" \
		--no-sort \
		--sort="objecttype" \
		"foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.10
	foo1.3
	foo1.6
	EOF
	test_cmp expect actual
'

test_expect_success '--no-sort without subsequent --sort prints expected tags' '
	# Sort the results with `sort` for a consistent comparison against
	# expected
	shit tag -l --no-sort "foo*" | sort >actual &&
	cat >expect <<-\EOF &&
	foo1.10
	foo1.3
	foo1.6
	EOF
	test_cmp expect actual
'

test_expect_success 'invalid sort parameter on command line' '
	test_must_fail shit tag -l --sort=notvalid "foo*" >actual
'

test_expect_success 'invalid sort parameter in configuratoin' '
	test_config tag.sort "v:notvalid" &&
	test_must_fail shit tag -l "foo*"
'

test_expect_success 'version sort handles empty value for versionsort.{prereleaseSuffix,suffix}' '
	cp .shit/config .shit/config.orig &&
	test_when_finished mv .shit/config.orig .shit/config &&

	cat >>.shit/config <<-\EOF &&
	[versionsort]
		prereleaseSuffix
		suffix
	EOF
	cat >expect <<-\EOF &&
	error: missing value for '\''versionsort.suffix'\''
	error: missing value for '\''versionsort.prereleasesuffix'\''
	EOF
	shit tag -l --sort=version:refname 2>actual &&
	test_cmp expect actual
'

test_expect_success 'version sort with prerelease reordering' '
	test_config versionsort.prereleaseSuffix -rc &&
	shit tag foo1.6-rc1 &&
	shit tag foo1.6-rc2 &&
	shit tag -l --sort=version:refname "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.3
	foo1.6-rc1
	foo1.6-rc2
	foo1.6
	foo1.10
	EOF
	test_cmp expect actual
'

test_expect_success 'reverse version sort with prerelease reordering' '
	test_config versionsort.prereleaseSuffix -rc &&
	shit tag -l --sort=-version:refname "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.10
	foo1.6
	foo1.6-rc2
	foo1.6-rc1
	foo1.3
	EOF
	test_cmp expect actual
'

test_expect_success 'version sort with prerelease reordering and common leading character' '
	test_config versionsort.prereleaseSuffix -before &&
	shit tag foo1.7-before1 &&
	shit tag foo1.7 &&
	shit tag foo1.7-after1 &&
	shit tag -l --sort=version:refname "foo1.7*" >actual &&
	cat >expect <<-\EOF &&
	foo1.7-before1
	foo1.7
	foo1.7-after1
	EOF
	test_cmp expect actual
'

test_expect_success 'version sort with prerelease reordering, multiple suffixes and common leading character' '
	test_config versionsort.prereleaseSuffix -before &&
	shit config --add versionsort.prereleaseSuffix -after &&
	shit tag -l --sort=version:refname "foo1.7*" >actual &&
	cat >expect <<-\EOF &&
	foo1.7-before1
	foo1.7-after1
	foo1.7
	EOF
	test_cmp expect actual
'

test_expect_success 'version sort with prerelease reordering, multiple suffixes match the same tag' '
	test_config versionsort.prereleaseSuffix -bar &&
	shit config --add versionsort.prereleaseSuffix -foo-baz &&
	shit config --add versionsort.prereleaseSuffix -foo-bar &&
	shit tag foo1.8-foo-bar &&
	shit tag foo1.8-foo-baz &&
	shit tag foo1.8 &&
	shit tag -l --sort=version:refname "foo1.8*" >actual &&
	cat >expect <<-\EOF &&
	foo1.8-foo-baz
	foo1.8-foo-bar
	foo1.8
	EOF
	test_cmp expect actual
'

test_expect_success 'version sort with prerelease reordering, multiple suffixes match starting at the same position' '
	test_config versionsort.prereleaseSuffix -pre &&
	shit config --add versionsort.prereleaseSuffix -prerelease &&
	shit tag foo1.9-pre1 &&
	shit tag foo1.9-pre2 &&
	shit tag foo1.9-prerelease1 &&
	shit tag -l --sort=version:refname "foo1.9*" >actual &&
	cat >expect <<-\EOF &&
	foo1.9-pre1
	foo1.9-pre2
	foo1.9-prerelease1
	EOF
	test_cmp expect actual
'

test_expect_success 'version sort with general suffix reordering' '
	test_config versionsort.suffix -alpha &&
	shit config --add versionsort.suffix -beta &&
	shit config --add versionsort.suffix ""  &&
	shit config --add versionsort.suffix -gamma &&
	shit config --add versionsort.suffix -delta &&
	shit tag foo1.10-alpha &&
	shit tag foo1.10-beta &&
	shit tag foo1.10-gamma &&
	shit tag foo1.10-delta &&
	shit tag foo1.10-unlisted-suffix &&
	shit tag -l --sort=version:refname "foo1.10*" >actual &&
	cat >expect <<-\EOF &&
	foo1.10-alpha
	foo1.10-beta
	foo1.10
	foo1.10-unlisted-suffix
	foo1.10-gamma
	foo1.10-delta
	EOF
	test_cmp expect actual
'

test_expect_success 'versionsort.suffix overrides versionsort.prereleaseSuffix' '
	test_config versionsort.suffix -before &&
	test_config versionsort.prereleaseSuffix -after &&
	shit tag -l --sort=version:refname "foo1.7*" >actual &&
	cat >expect <<-\EOF &&
	foo1.7-before1
	foo1.7
	foo1.7-after1
	EOF
	test_cmp expect actual
'

test_expect_success 'version sort with very long prerelease suffix' '
	test_config versionsort.prereleaseSuffix -very-looooooooooooooooooooooooong-prerelease-suffix &&
	shit tag -l --sort=version:refname
'

test_expect_success ULIMIT_STACK_SIZE '--contains and --no-contains work in a deep repo' '
	i=1 &&
	while test $i -lt 8000
	do
		echo "commit refs/heads/main
committer A U Thor <author@example.com> $((1000000000 + $i * 100)) +0200
data <<EOF
commit #$i
EOF" &&
		if test $i = 1
		then
			echo "from refs/heads/main^0"
		fi &&
		i=$(($i + 1)) || return 1
	done | shit fast-import &&
	shit checkout main &&
	shit tag far-far-away HEAD^ &&
	run_with_limited_stack shit tag --contains HEAD >actual &&
	test_must_be_empty actual &&
	run_with_limited_stack shit tag --no-contains HEAD >actual &&
	test_line_count "-gt" 10 actual
'

test_expect_success '--format should list tags as per format given' '
	cat >expect <<-\EOF &&
	refname : refs/tags/v1.0
	refname : refs/tags/v1.0.1
	refname : refs/tags/v1.1.3
	EOF
	shit tag -l --format="refname : %(refname)" "v1*" >actual &&
	test_cmp expect actual
'

test_expect_success '--format --omit-empty works' '
	cat >expect <<-\EOF &&
	refname : refs/tags/v1.0

	refname : refs/tags/v1.1.3
	EOF
	shit tag -l --format="%(if:notequals=refs/tags/v1.0.1)%(refname)%(then)refname : %(refname)%(end)" "v1*" >actual &&
	test_cmp expect actual &&
	cat >expect <<-\EOF &&
	refname : refs/tags/v1.0
	refname : refs/tags/v1.1.3
	EOF
	shit tag -l --omit-empty --format="%(if:notequals=refs/tags/v1.0.1)%(refname)%(then)refname : %(refname)%(end)" "v1*" >actual &&
	test_cmp expect actual
'

test_expect_success 'shit tag -l with --format="%(rest)" must fail' '
	test_must_fail shit tag -l --format="%(rest)" "v1*"
'

test_expect_success "set up color tests" '
	echo "<RED>v1.0<RESET>" >expect.color &&
	echo "v1.0" >expect.bare &&
	color_args="--format=%(color:red)%(refname:short) --list v1.0"
'

test_expect_success '%(color) omitted without tty' '
	TERM=vt100 shit tag $color_args >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect.bare actual
'

test_expect_success TTY '%(color) present with tty' '
	test_terminal shit tag $color_args >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect.color actual
'

test_expect_success '--color overrides auto-color' '
	shit tag --color $color_args >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect.color actual
'

test_expect_success 'color.ui=always overrides auto-color' '
	shit -c color.ui=always tag $color_args >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect.color actual
'

test_expect_success 'setup --merged test tags' '
	shit tag mergetest-1 HEAD~2 &&
	shit tag mergetest-2 HEAD~1 &&
	shit tag mergetest-3 HEAD
'

test_expect_success '--merged can be used in non-list mode' '
	cat >expect <<-\EOF &&
	mergetest-1
	mergetest-2
	EOF
	shit tag --merged=mergetest-2 "mergetest*" >actual &&
	test_cmp expect actual
'

test_expect_success '--merged is compatible with --no-merged' '
	shit tag --merged HEAD --no-merged HEAD
'

test_expect_success '--merged shows merged tags' '
	cat >expect <<-\EOF &&
	mergetest-1
	mergetest-2
	EOF
	shit tag -l --merged=mergetest-2 mergetest-* >actual &&
	test_cmp expect actual
'

test_expect_success '--no-merged show unmerged tags' '
	cat >expect <<-\EOF &&
	mergetest-3
	EOF
	shit tag -l --no-merged=mergetest-2 mergetest-* >actual &&
	test_cmp expect actual
'

test_expect_success '--no-merged can be used in non-list mode' '
	shit tag --no-merged=mergetest-2 mergetest-* >actual &&
	test_cmp expect actual
'

test_expect_success 'ambiguous branch/tags not marked' '
	shit tag ambiguous &&
	shit branch ambiguous &&
	echo ambiguous >expect &&
	shit tag -l ambiguous >actual &&
	test_cmp expect actual
'

test_expect_success '--contains combined with --no-contains' '
	(
		shit init no-contains &&
		cd no-contains &&
		test_commit v0.1 &&
		test_commit v0.2 &&
		test_commit v0.3 &&
		test_commit v0.4 &&
		test_commit v0.5 &&
		cat >expected <<-\EOF &&
		v0.2
		v0.3
		v0.4
		EOF
		shit tag --contains v0.2 --no-contains v0.5 >actual &&
		test_cmp expected actual
	)
'

# As the docs say, list tags which contain a specified *commit*. We
# don't recurse down to tags for trees or blobs pointed to by *those*
# commits.
test_expect_success 'Does --[no-]contains stop at commits? Yes!' '
	cd no-contains &&
	blob=$(shit rev-parse v0.3:v0.3.t) &&
	tree=$(shit rev-parse v0.3^{tree}) &&
	shit tag tag-blob $blob &&
	shit tag tag-tree $tree &&
	shit tag --contains v0.3 >actual &&
	cat >expected <<-\EOF &&
	v0.3
	v0.4
	v0.5
	EOF
	test_cmp expected actual &&
	shit tag --no-contains v0.3 >actual &&
	cat >expected <<-\EOF &&
	v0.1
	v0.2
	EOF
	test_cmp expected actual
'

test_expect_success 'If tag is created then tag message file is unlinked' '
	test_when_finished "shit tag -d foo" &&
	write_script fakeeditor <<-\EOF &&
	echo Message >.shit/TAG_EDITMSG
	EOF
	shit_EDITOR=./fakeeditor shit tag -a foo &&
	test_path_is_missing .shit/TAG_EDITMSG
'

test_expect_success 'If tag cannot be created then tag message file is not unlinked' '
	test_when_finished "shit tag -d foo/bar && rm .shit/TAG_EDITMSG" &&
	write_script fakeeditor <<-\EOF &&
	echo Message >.shit/TAG_EDITMSG
	EOF
	shit tag foo/bar &&
	test_must_fail env shit_EDITOR=./fakeeditor shit tag -a foo &&
	test_path_exists .shit/TAG_EDITMSG
'

test_done
