#!/bin/sh
#
# Copyright (c) Robin Rosenberg
#
test_description='Test export of commits to CVS'

. ./test-lib.sh

if ! test_have_prereq PERL; then
	skip_all='skipping shit cvsexportcommit tests, perl not available'
	test_done
fi

cvs >/dev/null 2>&1
if test $? -ne 1
then
    skip_all='skipping shit cvsexportcommit tests, cvs not found'
    test_done
fi

if ! test_have_prereq NOT_ROOT; then
	skip_all='When cvs is compiled with CVS_BADROOT commits as root fail'
	test_done
fi

CVSROOT=$PWD/tmpcvsroot
CVSWORK=$PWD/cvswork
shit_DIR=$PWD/.shit
export CVSROOT CVSWORK shit_DIR

rm -rf "$CVSROOT" "$CVSWORK"

cvs init &&
test -d "$CVSROOT" &&
cvs -Q co -d "$CVSWORK" . &&
echo >empty &&
shit add empty &&
shit commit -q -a -m "Initial" 2>/dev/null ||
exit 1

check_entries () {
	# $1 == directory, $2 == expected
	sed -ne '/^\//p' "$1/CVS/Entries" | sort | cut -d/ -f2,3,5 >actual
	if test -z "$2"
	then
		test_must_be_empty actual
	else
		printf '%s\n' "$2" | tr '|' '\012' >expected
		test_cmp expected actual
	fi
}

test_expect_success 'New file' '
	mkdir A B C D E F &&
	echo hello1 >A/newfile1.txt &&
	echo hello2 >B/newfile2.txt &&
	cp "$TEST_DIRECTORY"/test-binary-1.png C/newfile3.png &&
	cp "$TEST_DIRECTORY"/test-binary-1.png D/newfile4.png &&
	shit add A/newfile1.txt &&
	shit add B/newfile2.txt &&
	shit add C/newfile3.png &&
	shit add D/newfile4.png &&
	shit commit -a -m "Test: New file" &&
	id=$(shit rev-list --max-count=1 HEAD) &&
	(cd "$CVSWORK" &&
	shit cvsexportcommit -c $id &&
	check_entries A "newfile1.txt/1.1/" &&
	check_entries B "newfile2.txt/1.1/" &&
	check_entries C "newfile3.png/1.1/-kb" &&
	check_entries D "newfile4.png/1.1/-kb" &&
	test_cmp A/newfile1.txt ../A/newfile1.txt &&
	test_cmp B/newfile2.txt ../B/newfile2.txt &&
	test_cmp C/newfile3.png ../C/newfile3.png &&
	test_cmp D/newfile4.png ../D/newfile4.png
	)
'

test_expect_success 'Remove two files, add two and update two' '
	echo Hello1 >>A/newfile1.txt &&
	rm -f B/newfile2.txt &&
	rm -f C/newfile3.png &&
	echo Hello5  >E/newfile5.txt &&
	cp "$TEST_DIRECTORY"/test-binary-2.png D/newfile4.png &&
	cp "$TEST_DIRECTORY"/test-binary-1.png F/newfile6.png &&
	shit add E/newfile5.txt &&
	shit add F/newfile6.png &&
	shit commit -a -m "Test: Remove, add and update" &&
	id=$(shit rev-list --max-count=1 HEAD) &&
	(cd "$CVSWORK" &&
	shit cvsexportcommit -c $id &&
	check_entries A "newfile1.txt/1.2/" &&
	check_entries B "" &&
	check_entries C "" &&
	check_entries D "newfile4.png/1.2/-kb" &&
	check_entries E "newfile5.txt/1.1/" &&
	check_entries F "newfile6.png/1.1/-kb" &&
	test_cmp A/newfile1.txt ../A/newfile1.txt &&
	test_cmp D/newfile4.png ../D/newfile4.png &&
	test_cmp E/newfile5.txt ../E/newfile5.txt &&
	test_cmp F/newfile6.png ../F/newfile6.png
	)
'

# Should fail (but only on the shit cvsexportcommit stage)
test_expect_success \
    'Fail to change binary more than one generation old' \
    'cat F/newfile6.png >>D/newfile4.png &&
     shit commit -a -m "generatiion 1" &&
     cat F/newfile6.png >>D/newfile4.png &&
     shit commit -a -m "generation 2" &&
     id=$(shit rev-list --max-count=1 HEAD) &&
     (cd "$CVSWORK" &&
     test_must_fail shit cvsexportcommit -c $id
     )'

#test_expect_success \
#    'Fail to remove binary file more than one generation old' \
#    'shit reset --hard HEAD^ &&
#     cat F/newfile6.png >>D/newfile4.png &&
#     shit commit -a -m "generation 2 (again)" &&
#     rm -f D/newfile4.png &&
#     shit commit -a -m "generation 3" &&
#     id=$(shit rev-list --max-count=1 HEAD) &&
#     (cd "$CVSWORK" &&
#     test_must_fail shit cvsexportcommit -c $id
#     )'

# We reuse the state from two tests back here

# This test is here because a patch for only binary files will
# fail with gnu patch, so cvsexportcommit must handle that.
test_expect_success 'Remove only binary files' '
	shit reset --hard HEAD^^ &&
	rm -f D/newfile4.png &&
	shit commit -a -m "test: remove only a binary file" &&
	id=$(shit rev-list --max-count=1 HEAD) &&
	(cd "$CVSWORK" &&
	shit cvsexportcommit -c $id &&
	check_entries A "newfile1.txt/1.2/" &&
	check_entries B "" &&
	check_entries C "" &&
	check_entries D "" &&
	check_entries E "newfile5.txt/1.1/" &&
	check_entries F "newfile6.png/1.1/-kb" &&
	test_cmp A/newfile1.txt ../A/newfile1.txt &&
	test_cmp E/newfile5.txt ../E/newfile5.txt &&
	test_cmp F/newfile6.png ../F/newfile6.png
	)
'

test_expect_success 'Remove only a text file' '
	rm -f A/newfile1.txt &&
	shit commit -a -m "test: remove only a binary file" &&
	id=$(shit rev-list --max-count=1 HEAD) &&
	(cd "$CVSWORK" &&
	shit cvsexportcommit -c $id &&
	check_entries A "" &&
	check_entries B "" &&
	check_entries C "" &&
	check_entries D "" &&
	check_entries E "newfile5.txt/1.1/" &&
	check_entries F "newfile6.png/1.1/-kb" &&
	test_cmp E/newfile5.txt ../E/newfile5.txt &&
	test_cmp F/newfile6.png ../F/newfile6.png
	)
'

test_expect_success 'New file with spaces in file name' '
	mkdir "G g" &&
	echo ok then >"G g/with spaces.txt" &&
	shit add "G g/with spaces.txt" && \
	cp "$TEST_DIRECTORY"/test-binary-1.png "G g/with spaces.png" && \
	shit add "G g/with spaces.png" &&
	shit commit -a -m "With spaces" &&
	id=$(shit rev-list --max-count=1 HEAD) &&
	(cd "$CVSWORK" &&
	shit cvsexportcommit -c $id &&
	check_entries "G g" "with spaces.png/1.1/-kb|with spaces.txt/1.1/"
	)
'

test_expect_success 'Update file with spaces in file name' '
	echo Ok then >>"G g/with spaces.txt" &&
	cat "$TEST_DIRECTORY"/test-binary-1.png >>"G g/with spaces.png" && \
	shit add "G g/with spaces.png" &&
	shit commit -a -m "Update with spaces" &&
	id=$(shit rev-list --max-count=1 HEAD) &&
	(cd "$CVSWORK" &&
	shit cvsexportcommit -c $id &&
	check_entries "G g" "with spaces.png/1.2/-kb|with spaces.txt/1.2/"
	)
'

# Some filesystems mangle pathnames with UTF-8 characters --
# check and skip
if p="Å/goo/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z/å/ä/ö" &&
	mkdir -p "tst/$p" &&
	date >"tst/$p/day" &&
	found=$(find tst -type f -print) &&
	test "z$found" = "ztst/$p/day" &&
	rm -fr tst
then

# This test contains UTF-8 characters
test_expect_success !MINGW 'File with non-ascii file name' '
	mkdir -p Å/goo/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z/å/ä/ö &&
	echo Foo >Å/goo/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z/å/ä/ö/gårdetsågårdet.txt &&
	shit add Å/goo/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z/å/ä/ö/gårdetsågårdet.txt &&
	cp "$TEST_DIRECTORY"/test-binary-1.png Å/goo/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z/å/ä/ö/gårdetsågårdet.png &&
	shit add Å/goo/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z/å/ä/ö/gårdetsågårdet.png &&
	shit commit -a -m "Går det så går det" && \
	id=$(shit rev-list --max-count=1 HEAD) &&
	(cd "$CVSWORK" &&
	shit cvsexportcommit -v -c $id &&
	check_entries \
	"Å/goo/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z/å/ä/ö" \
	"gårdetsågårdet.png/1.1/-kb|gårdetsågårdet.txt/1.1/"
	)
'

fi

rm -fr tst

test_expect_success 'Mismatching patch should fail' '
	date >>"E/newfile5.txt" &&
	shit add "E/newfile5.txt" &&
	shit commit -a -m "Update one" &&
	date >>"E/newfile5.txt" &&
	shit add "E/newfile5.txt" &&
	shit commit -a -m "Update two" &&
	id=$(shit rev-list --max-count=1 HEAD) &&
	(cd "$CVSWORK" &&
	test_must_fail shit cvsexportcommit -c $id
	)
'

test_expect_success FILEMODE 'Retain execute bit' '
	mkdir G &&
	echo executeon >G/on &&
	chmod +x G/on &&
	echo executeoff >G/off &&
	shit add G/on &&
	shit add G/off &&
	shit commit -a -m "Execute test" &&
	(cd "$CVSWORK" &&
	shit cvsexportcommit -c HEAD &&
	test -x G/on &&
	! test -x G/off
	)
'

test_expect_success '-w option should work with relative shit_DIR' '
	mkdir W &&
	echo foobar >W/file1.txt &&
	echo bazzle >W/file2.txt &&
	shit add W/file1.txt &&
	shit add W/file2.txt &&
	shit commit -m "More updates" &&
	id=$(shit rev-list --max-count=1 HEAD) &&
	(cd "$shit_DIR" &&
	shit_DIR=. shit cvsexportcommit -w "$CVSWORK" -c $id &&
	check_entries "$CVSWORK/W" "file1.txt/1.1/|file2.txt/1.1/" &&
	test_cmp "$CVSWORK/W/file1.txt" ../W/file1.txt &&
	test_cmp "$CVSWORK/W/file2.txt" ../W/file2.txt
	)
'

test_expect_success 'check files before directories' '

	echo Notes > release-notes &&
	shit add release-notes &&
	shit commit -m "Add release notes" release-notes &&
	id=$(shit rev-parse HEAD) &&
	shit cvsexportcommit -w "$CVSWORK" -c $id &&

	echo new > DS &&
	echo new > E/DS &&
	echo modified > release-notes &&
	shit add DS E/DS release-notes &&
	shit commit -m "Add two files with the same basename" &&
	id=$(shit rev-parse HEAD) &&
	shit cvsexportcommit -w "$CVSWORK" -c $id &&
	check_entries "$CVSWORK/E" "DS/1.1/|newfile5.txt/1.1/" &&
	check_entries "$CVSWORK" "DS/1.1/|release-notes/1.2/" &&
	test_cmp "$CVSWORK/DS" DS &&
	test_cmp "$CVSWORK/E/DS" E/DS &&
	test_cmp "$CVSWORK/release-notes" release-notes

'

test_expect_success 're-commit a removed filename which remains in CVS attic' '
	(cd "$CVSWORK" &&
	echo >attic_gremlin &&
	cvs -Q add attic_gremlin &&
	cvs -Q ci -m "added attic_gremlin" &&
	rm attic_gremlin &&
	cvs -Q rm attic_gremlin &&
	cvs -Q ci -m "removed attic_gremlin") &&

	echo > attic_gremlin &&
	shit add attic_gremlin &&
	shit commit -m "Added attic_gremlin" &&
	shit cvsexportcommit -w "$CVSWORK" -c HEAD &&
	(cd "$CVSWORK" && cvs -Q update -d) &&
	test -f "$CVSWORK/attic_gremlin"
'

# the state of the CVS sandbox may be indeterminate for ' space'
# after this test on some platforms / with some versions of CVS
# consider adding new tests above this point
test_expect_success 'commit a file with leading spaces in the name' '

	echo space > " space" &&
	shit add " space" &&
	shit commit -m "Add a file with a leading space" &&
	id=$(shit rev-parse HEAD) &&
	shit cvsexportcommit -w "$CVSWORK" -c $id &&
	check_entries "$CVSWORK" " space/1.1/|DS/1.1/|attic_gremlin/1.3/|release-notes/1.2/" &&
	test_cmp "$CVSWORK/ space" " space"

'

test_expect_success 'use the same checkout for shit and CVS' '

	(mkdir shared &&
	 cd shared &&
	 sane_unset shit_DIR &&
	 cvs co . &&
	 shit init &&
	 shit add " space" &&
	 shit commit -m "fake initial commit" &&
	 echo Hello >> " space" &&
	 shit commit -m "Another change" " space" &&
	 shit cvsexportcommit -W -p -u -c HEAD &&
	 grep Hello " space" &&
	 shit diff-files)

'

test_done
