#!/bin/sh
#
# Copyright (c) 2007 Johannes E. Schindelin
#

test_description='shit fast-export'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '

	echo break it > file0 &&
	shit add file0 &&
	test_tick &&
	echo Wohlauf > file &&
	shit add file &&
	test_tick &&
	shit commit -m initial &&
	echo die Luft > file &&
	echo geht frisch > file2 &&
	shit add file file2 &&
	test_tick &&
	shit commit -m second &&
	echo und > file2 &&
	test_tick &&
	shit commit -m third file2 &&
	test_tick &&
	shit tag rein &&
	shit checkout -b wer HEAD^ &&
	echo lange > file2 &&
	test_tick &&
	shit commit -m sitzt file2 &&
	test_tick &&
	shit tag -a -m valentin muss &&
	shit merge -s ours main

'

test_expect_success 'fast-export | fast-import' '

	MAIN=$(shit rev-parse --verify main) &&
	REIN=$(shit rev-parse --verify rein) &&
	WER=$(shit rev-parse --verify wer) &&
	MUSS=$(shit rev-parse --verify muss) &&
	mkdir new &&
	shit --shit-dir=new/.shit init &&
	shit fast-export --all >actual &&
	(cd new &&
	 shit fast-import &&
	 test $MAIN = $(shit rev-parse --verify refs/heads/main) &&
	 test $REIN = $(shit rev-parse --verify refs/tags/rein) &&
	 test $WER = $(shit rev-parse --verify refs/heads/wer) &&
	 test $MUSS = $(shit rev-parse --verify refs/tags/muss)) <actual

'

test_expect_success 'fast-export ^muss^{commit} muss' '
	shit fast-export --tag-of-filtered-object=rewrite ^muss^{commit} muss >actual &&
	cat >expected <<-EOF &&
	tag muss
	from $(shit rev-parse --verify muss^{commit})
	$(shit cat-file tag muss | grep tagger)
	data 9
	valentin

	EOF
	test_cmp expected actual
'

test_expect_success 'fast-export --mark-tags ^muss^{commit} muss' '
	shit fast-export --mark-tags --tag-of-filtered-object=rewrite ^muss^{commit} muss >actual &&
	cat >expected <<-EOF &&
	tag muss
	mark :1
	from $(shit rev-parse --verify muss^{commit})
	$(shit cat-file tag muss | grep tagger)
	data 9
	valentin

	EOF
	test_cmp expected actual
'

test_expect_success 'fast-export main~2..main' '

	shit fast-export main~2..main >actual &&
	sed "s/main/partial/" actual |
		(cd new &&
		 shit fast-import &&
		 test $MAIN != $(shit rev-parse --verify refs/heads/partial) &&
		 shit diff --exit-code main partial &&
		 shit diff --exit-code main^ partial^ &&
		 test_must_fail shit rev-parse partial~2)

'

test_expect_success 'fast-export --reference-excluded-parents main~2..main' '

	shit fast-export --reference-excluded-parents main~2..main >actual &&
	grep commit.refs/heads/main actual >commit-count &&
	test_line_count = 2 commit-count &&
	sed "s/main/rewrite/" actual |
		(cd new &&
		 shit fast-import &&
		 test $MAIN = $(shit rev-parse --verify refs/heads/rewrite))
'

test_expect_success 'fast-export --show-original-ids' '

	shit fast-export --show-original-ids main >output &&
	grep ^original-oid output| sed -e s/^original-oid.// | sort >actual &&
	shit rev-list --objects main muss >objects-and-names &&
	awk "{print \$1}" objects-and-names | sort >commits-trees-blobs &&
	comm -23 actual commits-trees-blobs >unfound &&
	test_must_be_empty unfound
'

test_expect_success 'fast-export --show-original-ids | shit fast-import' '

	shit fast-export --show-original-ids main muss | shit fast-import --quiet &&
	test $MAIN = $(shit rev-parse --verify refs/heads/main) &&
	test $MUSS = $(shit rev-parse --verify refs/tags/muss)
'

test_expect_success 'reencoding iso-8859-7' '

	test_when_finished "shit reset --hard HEAD~1" &&
	test_config i18n.commitencoding iso-8859-7 &&
	test_tick &&
	echo rosten >file &&
	shit commit -s -F "$TEST_DIRECTORY/t9350/simple-iso-8859-7-commit-message.txt" file &&
	shit fast-export --reencode=yes wer^..wer >iso-8859-7.fi &&
	sed "s/wer/i18n/" iso-8859-7.fi |
		(cd new &&
		 shit fast-import &&
		 # The commit object, if not re-encoded, would be 200 bytes plus hash.
		 # Removing the "encoding iso-8859-7\n" header drops 20 bytes.
		 # Re-encoding the Pi character from \xF0 (\360) in iso-8859-7
		 # to \xCF\x80 (\317\200) in UTF-8 adds a byte.  Check for
		 # the expected size.
		 test $(($(test_oid hexsz) + 181)) -eq "$(shit cat-file -s i18n)" &&
		 # ...and for the expected translation of bytes.
		 shit cat-file commit i18n >actual &&
		 grep $(printf "\317\200") actual &&
		 # Also make sure the commit does not have the "encoding" header
		 ! grep ^encoding actual)
'

test_expect_success 'aborting on iso-8859-7' '

	test_when_finished "shit reset --hard HEAD~1" &&
	test_config i18n.commitencoding iso-8859-7 &&
	echo rosten >file &&
	shit commit -s -F "$TEST_DIRECTORY/t9350/simple-iso-8859-7-commit-message.txt" file &&
	test_must_fail shit fast-export --reencode=abort wer^..wer >iso-8859-7.fi
'

test_expect_success 'preserving iso-8859-7' '

	test_when_finished "shit reset --hard HEAD~1" &&
	test_config i18n.commitencoding iso-8859-7 &&
	echo rosten >file &&
	shit commit -s -F "$TEST_DIRECTORY/t9350/simple-iso-8859-7-commit-message.txt" file &&
	shit fast-export --reencode=no wer^..wer >iso-8859-7.fi &&
	sed "s/wer/i18n-no-recoding/" iso-8859-7.fi |
		(cd new &&
		 shit fast-import &&
		 # The commit object, if not re-encoded, is 200 bytes plus hash.
		 # Removing the "encoding iso-8859-7\n" header would drops 20
		 # bytes.  Re-encoding the Pi character from \xF0 (\360) in
		 # iso-8859-7 to \xCF\x80 (\317\200) in UTF-8 adds a byte.
		 # Check for the expected size...
		 test $(($(test_oid hexsz) + 200)) -eq "$(shit cat-file -s i18n-no-recoding)" &&
		 # ...as well as the expected byte.
		 shit cat-file commit i18n-no-recoding >actual &&
		 grep $(printf "\360") actual &&
		 # Also make sure the commit has the "encoding" header
		 grep ^encoding actual)
'

test_expect_success 'encoding preserved if reencoding fails' '

	test_when_finished "shit reset --hard HEAD~1" &&
	test_config i18n.commitencoding iso-8859-7 &&
	echo rosten >file &&
	shit commit -s -F "$TEST_DIRECTORY/t9350/broken-iso-8859-7-commit-message.txt" file &&
	shit fast-export --reencode=yes wer^..wer >iso-8859-7.fi &&
	sed "s/wer/i18n-invalid/" iso-8859-7.fi |
		(cd new &&
		 shit fast-import &&
		 shit cat-file commit i18n-invalid >actual &&
		 # Make sure the commit still has the encoding header
		 grep ^encoding actual &&
		 # Verify that the commit has the expected size; i.e.
		 # that no bytes were re-encoded to a different encoding.
		 test $(($(test_oid hexsz) + 212)) -eq "$(shit cat-file -s i18n-invalid)" &&
		 # ...and check for the original special bytes
		 grep $(printf "\360") actual &&
		 grep $(printf "\377") actual)
'

test_expect_success 'import/export-marks' '

	shit checkout -b marks main &&
	shit fast-export --export-marks=tmp-marks HEAD &&
	test -s tmp-marks &&
	test_line_count = 3 tmp-marks &&
	shit fast-export --import-marks=tmp-marks \
		--export-marks=tmp-marks HEAD >actual &&
	test $(grep ^commit actual | wc -l) -eq 0 &&
	echo change > file &&
	shit commit -m "last commit" file &&
	shit fast-export --import-marks=tmp-marks \
		--export-marks=tmp-marks HEAD >actual &&
	test $(grep ^commit\  actual | wc -l) -eq 1 &&
	test_line_count = 4 tmp-marks

'

cat > signed-tag-import << EOF
tag sign-your-name
from $(shit rev-parse HEAD)
tagger C O Mitter <committer@example.com> 1112911993 -0700
data 210
A message for a sign
-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1.4.5 (GNU/Linux)

fakedsignaturefakedsignaturefakedsignaturefakedsignaturfakedsign
aturefakedsignaturefake=
=/59v
-----END PGP SIGNATURE-----
EOF

test_expect_success 'set up faked signed tag' '

	shit fast-import <signed-tag-import

'

test_expect_success 'signed-tags=abort' '

	test_must_fail shit fast-export --signed-tags=abort sign-your-name

'

test_expect_success 'signed-tags=verbatim' '

	shit fast-export --signed-tags=verbatim sign-your-name > output &&
	grep PGP output

'

test_expect_success 'signed-tags=strip' '

	shit fast-export --signed-tags=strip sign-your-name > output &&
	! grep PGP output

'

test_expect_success 'signed-tags=warn-strip' '
	shit fast-export --signed-tags=warn-strip sign-your-name >output 2>err &&
	! grep PGP output &&
	test -s err
'

test_expect_success 'setup submodule' '

	test_config_global protocol.file.allow always &&
	shit checkout -f main &&
	mkdir sub &&
	(
		cd sub &&
		shit init  &&
		echo test file > file &&
		shit add file &&
		shit commit -m sub_initial
	) &&
	shit submodule add "$(pwd)/sub" sub &&
	shit commit -m initial &&
	test_tick &&
	(
		cd sub &&
		echo more data >> file &&
		shit add file &&
		shit commit -m sub_second
	) &&
	shit add sub &&
	shit commit -m second

'

test_expect_success 'submodule fast-export | fast-import' '

	test_config_global protocol.file.allow always &&
	SUBENT1=$(shit ls-tree main^ sub) &&
	SUBENT2=$(shit ls-tree main sub) &&
	rm -rf new &&
	mkdir new &&
	shit --shit-dir=new/.shit init &&
	shit fast-export --signed-tags=strip --all >actual &&
	(cd new &&
	 shit fast-import &&
	 test "$SUBENT1" = "$(shit ls-tree refs/heads/main^ sub)" &&
	 test "$SUBENT2" = "$(shit ls-tree refs/heads/main sub)" &&
	 shit checkout main &&
	 shit submodule init &&
	 shit submodule update &&
	 cmp sub/file ../sub/file) <actual

'

shit_AUTHOR_NAME='A U Thor'; export shit_AUTHOR_NAME
shit_COMMITTER_NAME='C O Mitter'; export shit_COMMITTER_NAME

test_expect_success 'setup copies' '

	shit checkout -b copy rein &&
	shit mv file file3 &&
	shit commit -m move1 &&
	test_tick &&
	cp file2 file4 &&
	shit add file4 &&
	shit mv file2 file5 &&
	shit commit -m copy1 &&
	test_tick &&
	cp file3 file6 &&
	shit add file6 &&
	shit commit -m copy2 &&
	test_tick &&
	echo more text >> file6 &&
	echo even more text >> file6 &&
	shit add file6 &&
	shit commit -m modify &&
	test_tick &&
	cp file6 file7 &&
	echo test >> file7 &&
	shit add file7 &&
	shit commit -m copy_modify

'

test_expect_success 'fast-export -C -C | fast-import' '

	ENTRY=$(shit rev-parse --verify copy) &&
	rm -rf new &&
	mkdir new &&
	shit --shit-dir=new/.shit init &&
	shit fast-export -C -C --signed-tags=strip --all > output &&
	grep "^C file2 file4\$" output &&
	cat output |
	(cd new &&
	 shit fast-import &&
	 test $ENTRY = $(shit rev-parse --verify refs/heads/copy))

'

test_expect_success 'fast-export | fast-import when main is tagged' '

	shit tag -m msg last &&
	shit fast-export -C -C --signed-tags=strip --all > output &&
	test $(grep -c "^tag " output) = 3

'

cat > tag-content << EOF
object $(shit rev-parse HEAD)
type commit
tag rosten
EOF

test_expect_success 'cope with tagger-less tags' '

	TAG=$(shit hash-object --literally -t tag -w tag-content) &&
	shit update-ref refs/tags/sonnenschein $TAG &&
	shit fast-export -C -C --signed-tags=strip --all > output &&
	test $(grep -c "^tag " output) = 4 &&
	! grep "Unspecified Tagger" output &&
	shit fast-export -C -C --signed-tags=strip --all \
		--fake-missing-tagger > output &&
	test $(grep -c "^tag " output) = 4 &&
	grep "Unspecified Tagger" output

'

test_expect_success 'setup for limiting exports by PATH' '
	mkdir limit-by-paths &&
	(
		cd limit-by-paths &&
		shit init &&
		echo hi > there &&
		shit add there &&
		shit commit -m "First file" &&
		echo foo > bar &&
		shit add bar &&
		shit commit -m "Second file" &&
		shit tag -a -m msg mytag &&
		echo morefoo >> bar &&
		shit add bar &&
		shit commit -m "Change to second file"
	)
'

cat > limit-by-paths/expected << EOF
blob
mark :1
data 3
hi

reset refs/tags/mytag
commit refs/tags/mytag
mark :2
author A U Thor <author@example.com> 1112912713 -0700
committer C O Mitter <committer@example.com> 1112912713 -0700
data 11
First file
M 100644 :1 there

EOF

test_expect_success 'dropping tag of filtered out object' '
(
	cd limit-by-paths &&
	shit fast-export --tag-of-filtered-object=drop mytag -- there > output &&
	test_cmp expected output
)
'

cat >> limit-by-paths/expected << EOF
tag mytag
from :2
tagger C O Mitter <committer@example.com> 1112912713 -0700
data 4
msg

EOF

test_expect_success 'rewriting tag of filtered out object' '
(
	cd limit-by-paths &&
	shit fast-export --tag-of-filtered-object=rewrite mytag -- there > output &&
	test_cmp expected output
)
'

test_expect_success 'rewrite tag predating pathspecs to nothing' '
	test_create_repo rewrite_tag_predating_pathspecs &&
	(
		cd rewrite_tag_predating_pathspecs &&

		test_commit initial &&

		shit tag -a -m "Some old tag" v0.0.0.0.0.0.1 &&

		test_commit bar &&

		shit fast-export --tag-of-filtered-object=rewrite --all -- bar.t >output &&
		grep from.$ZERO_OID output
	)
'

cat > limit-by-paths/expected << EOF
blob
mark :1
data 4
foo

blob
mark :2
data 3
hi

reset refs/heads/main
commit refs/heads/main
mark :3
author A U Thor <author@example.com> 1112912713 -0700
committer C O Mitter <committer@example.com> 1112912713 -0700
data 12
Second file
M 100644 :1 bar
M 100644 :2 there

EOF

test_expect_failure 'no exact-ref revisions included' '
	(
		cd limit-by-paths &&
		shit fast-export main~2..main~1 > output &&
		test_cmp expected output
	)
'

test_expect_success 'path limiting with import-marks does not lose unmodified files'        '
	shit checkout -b simple marks~2 &&
	shit fast-export --export-marks=marks simple -- file > /dev/null &&
	echo more content >> file &&
	test_tick &&
	shit commit -mnext file &&
	shit fast-export --import-marks=marks simple -- file file0 >actual &&
	grep file0 actual
'

test_expect_success 'path limiting works' '
	shit fast-export simple -- file >actual &&
	sed -ne "s/^M .* //p" <actual | sort -u >actual.files &&
	echo file >expect &&
	test_cmp expect actual.files
'

test_expect_success 'avoid corrupt stream with non-existent mark' '
	test_create_repo avoid_non_existent_mark &&
	(
		cd avoid_non_existent_mark &&

		test_commit important-path &&

		test_commit ignored &&

		shit branch A &&
		shit branch B &&

		echo foo >>important-path.t &&
		shit add important-path.t &&
		test_commit more changes &&

		shit fast-export --all -- important-path.t | shit fast-import --force
	)
'

test_expect_success 'full-tree re-shows unmodified files'        '
	shit checkout -f simple &&
	shit fast-export --full-tree simple >actual &&
	test $(grep -c file0 actual) -eq 3
'

test_expect_success 'set-up a few more tags for tag export tests' '
	shit checkout -f main &&
	HEAD_TREE=$(shit show -s --pretty=raw HEAD | sed -n "/tree/s/tree //p") &&
	shit tag    tree_tag        -m "tagging a tree" $HEAD_TREE &&
	shit tag -a tree_tag-obj    -m "tagging a tree" $HEAD_TREE &&
	shit tag    tag-obj_tag     -m "tagging a tag" tree_tag-obj &&
	shit tag -a tag-obj_tag-obj -m "tagging a tag" tree_tag-obj
'

test_expect_success 'tree_tag'        '
	mkdir result &&
	(cd result && shit init) &&
	shit fast-export tree_tag > fe-stream &&
	(cd result && shit fast-import < ../fe-stream)
'

# NEEDSWORK: not just check return status, but validate the output
# Note that these tests DO NOTHING other than print a warning that
# they are omitting the one tag we asked them to export (because the
# tags resolve to a tree).  They exist just to make sure we do not
# abort but instead just warn.
test_expect_success 'tree_tag-obj'    'shit fast-export tree_tag-obj'
test_expect_success 'tag-obj_tag'     'shit fast-export tag-obj_tag'
test_expect_success 'tag-obj_tag-obj' 'shit fast-export tag-obj_tag-obj'

test_expect_success 'handling tags of blobs' '
	shit tag -a -m "Tag of a blob" blobtag $(shit rev-parse main:file) &&
	shit fast-export blobtag >actual &&
	cat >expect <<-EOF &&
	blob
	mark :1
	data 9
	die Luft

	tag blobtag
	from :1
	tagger $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL> $shit_COMMITTER_DATE
	data 14
	Tag of a blob

	EOF
	test_cmp expect actual
'

test_expect_success 'handling nested tags' '
	shit tag -a -m "This is a nested tag" nested muss &&
	shit fast-export --mark-tags nested >output &&
	grep "^from $ZERO_OID$" output &&
	grep "^tag nested$" output >tag_lines &&
	test_line_count = 2 tag_lines
'

test_expect_success 'directory becomes symlink'        '
	shit init dirtosymlink &&
	shit init result &&
	(
		cd dirtosymlink &&
		mkdir foo &&
		mkdir bar &&
		echo hello > foo/world &&
		echo hello > bar/world &&
		shit add foo/world bar/world &&
		shit commit -q -mone &&
		shit rm -r foo &&
		test_ln_s_add bar foo &&
		shit commit -q -mtwo
	) &&
	(
		cd dirtosymlink &&
		shit fast-export main -- foo |
		(cd ../result && shit fast-import --quiet)
	) &&
	(cd result && shit show main:foo)
'

test_expect_success 'fast-export quotes pathnames' '
	shit init crazy-paths &&
	test_config -C crazy-paths core.protectNTFS false &&
	(cd crazy-paths &&
	 blob=$(echo foo | shit hash-object -w --stdin) &&
	 shit -c core.protectNTFS=false update-index --add \
		--cacheinfo 100644 $blob "$(printf "path with\\nnewline")" \
		--cacheinfo 100644 $blob "path with \"quote\"" \
		--cacheinfo 100644 $blob "path with \\backslash" \
		--cacheinfo 100644 $blob "path with space" &&
	 shit commit -m addition &&
	 shit ls-files -z -s | perl -0pe "s{\\t}{$&subdir/}" >index &&
	 shit read-tree --empty &&
	 shit update-index -z --index-info <index &&
	 shit commit -m rename &&
	 shit read-tree --empty &&
	 shit commit -m deletion &&
	 shit fast-export -M HEAD >export.out &&
	 shit rev-list HEAD >expect &&
	 shit init result &&
	 cd result &&
	 shit fast-import <../export.out &&
	 shit rev-list HEAD >actual &&
	 test_cmp ../expect actual
	)
'

test_expect_success 'test bidirectionality' '
	shit init marks-test &&
	shit fast-export --export-marks=marks-cur --import-marks-if-exists=marks-cur --branches | \
	shit --shit-dir=marks-test/.shit fast-import --export-marks=marks-new --import-marks-if-exists=marks-new &&
	(cd marks-test &&
	shit reset --hard &&
	echo Wohlauf > file &&
	shit commit -a -m "back in time") &&
	shit --shit-dir=marks-test/.shit fast-export --export-marks=marks-new --import-marks-if-exists=marks-new --branches | \
	shit fast-import --export-marks=marks-cur --import-marks-if-exists=marks-cur
'

cat > expected << EOF
blob
mark :13
data 5
bump

commit refs/heads/main
mark :14
author A U Thor <author@example.com> 1112912773 -0700
committer C O Mitter <committer@example.com> 1112912773 -0700
data 5
bump
from :12
M 100644 :13 file

EOF

test_expect_success 'avoid uninteresting refs' '
	> tmp-marks &&
	shit fast-export --import-marks=tmp-marks \
		--export-marks=tmp-marks main > /dev/null &&
	shit tag v1.0 &&
	shit branch uninteresting &&
	echo bump > file &&
	shit commit -a -m bump &&
	shit fast-export --import-marks=tmp-marks \
		--export-marks=tmp-marks ^uninteresting ^v1.0 main > actual &&
	test_cmp expected actual
'

cat > expected << EOF
reset refs/heads/main
from :14

EOF

test_expect_success 'refs are updated even if no commits need to be exported' '
	> tmp-marks &&
	shit fast-export --import-marks=tmp-marks \
		--export-marks=tmp-marks main > /dev/null &&
	shit fast-export --import-marks=tmp-marks \
		--export-marks=tmp-marks main > actual &&
	test_cmp expected actual
'

test_expect_success 'use refspec' '
	shit fast-export --refspec refs/heads/main:refs/heads/foobar main >actual2 &&
	grep "^commit " actual2 | sort | uniq >actual &&
	echo "commit refs/heads/foobar" > expected &&
	test_cmp expected actual
'

test_expect_success 'delete ref because entire history excluded' '
	shit branch to-delete &&
	shit fast-export to-delete ^to-delete >actual &&
	cat >expected <<-EOF &&
	reset refs/heads/to-delete
	from $ZERO_OID

	EOF
	test_cmp expected actual
'

test_expect_success 'delete refspec' '
	shit fast-export --refspec :refs/heads/to-delete >actual &&
	cat >expected <<-EOF &&
	reset refs/heads/to-delete
	from $ZERO_OID

	EOF
	test_cmp expected actual
'

test_expect_success 'when using -C, do not declare copy when source of copy is also modified' '
	test_create_repo src &&
	echo a_line >src/file.txt &&
	shit -C src add file.txt &&
	shit -C src commit -m 1st_commit &&

	cp src/file.txt src/file2.txt &&
	echo another_line >>src/file.txt &&
	shit -C src add file.txt file2.txt &&
	shit -C src commit -m 2nd_commit &&

	test_create_repo dst &&
	shit -C src fast-export --all -C >actual &&
	shit -C dst fast-import <actual &&
	shit -C src show >expected &&
	shit -C dst show >actual &&
	test_cmp expected actual
'

test_expect_success 'merge commit gets exported with --import-marks' '
	test_create_repo merging &&
	(
		cd merging &&
		test_commit initial &&
		shit checkout -b topic &&
		test_commit on-topic &&
		shit checkout main &&
		test_commit on-main &&
		test_tick &&
		shit merge --no-ff -m Yeah topic &&

		echo ":1 $(shit rev-parse HEAD^^)" >marks &&
		shit fast-export --import-marks=marks main >out &&
		grep Yeah out
	)
'


test_expect_success 'fast-export --first-parent outputs all revisions output by revision walk' '
	shit init first-parent &&
	(
		cd first-parent &&
		test_commit A &&
		shit checkout -b topic1 &&
		test_commit B &&
		shit checkout main &&
		shit merge --no-ff topic1 &&

		shit checkout -b topic2 &&
		test_commit C &&
		shit checkout main &&
		shit merge --no-ff topic2 &&

		test_commit D &&

		shit fast-export main -- --first-parent >first-parent-export &&
		shit fast-export main -- --first-parent --reverse >first-parent-reverse-export &&
		test_cmp first-parent-export first-parent-reverse-export &&

		shit init import &&
		shit -C import fast-import <first-parent-export &&

		shit log --format="%ad %s" --first-parent main >expected &&
		shit -C import log --format="%ad %s" --all >actual &&
		test_cmp expected actual &&
		test_line_count = 4 actual
	)
'

test_expect_success 'fast-export handles --end-of-options' '
	shit update-ref refs/heads/nodash HEAD &&
	shit update-ref refs/heads/--dashes HEAD &&
	shit fast-export --end-of-options nodash >expect &&
	shit fast-export --end-of-options --dashes >actual.raw &&
	# fix up lines which mention the ref for comparison
	sed s/--dashes/nodash/ <actual.raw >actual &&
	test_cmp expect actual
'

test_done
