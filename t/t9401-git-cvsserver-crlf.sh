#!/bin/sh
#
# Copyright (c) 2008 Matthew Ogilvie
# Parts adapted from other tests.
#

test_description='shit-cvsserver -kb modes

tests -kb mode for binary files when accessing a shit
repository using cvs CLI client via shit-cvsserver server'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

marked_as () {
    foundEntry="$(grep "^/$2/" "$1/CVS/Entries")"
    if [ x"$foundEntry" = x"" ] ; then
       echo "NOT FOUND: $1 $2 1 $3" >> "${WORKDIR}/marked.log"
       return 1
    fi
    test x"$(grep "^/$2/" "$1/CVS/Entries" | cut -d/ -f5)" = x"$3"
    stat=$?
    echo "$1 $2 $stat '$3'" >> "${WORKDIR}/marked.log"
    return $stat
}

not_present() {
    foundEntry="$(grep "^/$2/" "$1/CVS/Entries")"
    if [ -r "$1/$2" ] ; then
        echo "Error: File still exists: $1 $2" >> "${WORKDIR}/marked.log"
        return 1;
    fi
    if [ x"$foundEntry" != x"" ] ; then
        echo "Error: should not have found: $1 $2" >> "${WORKDIR}/marked.log"
        return 1;
    else
        echo "Correctly not found: $1 $2" >> "${WORKDIR}/marked.log"
        return 0;
    fi
}

check_status_options() {
    (cd "$1" &&
    shit_CONFIG="$shit_config" cvs -Q status "$2" > "${WORKDIR}/status.out" 2>&1
    )
    if [ x"$?" != x"0" ] ; then
	echo "Error from cvs status: $1 $2" >> "${WORKDIR}/marked.log"
	return 1;
    fi
    got="$(sed -n -e 's/^[ 	]*Sticky Options:[ 	]*//p' "${WORKDIR}/status.out")"
    expect="$3"
    if [ x"$expect" = x"" ] ; then
	expect="(none)"
    fi
    test x"$got" = x"$expect"
    stat=$?
    echo "cvs status: $1 $2 $stat '$3' '$got'" >> "${WORKDIR}/marked.log"
    return $stat
}

cvs >/dev/null 2>&1
if test $? -ne 1
then
    skip_all='skipping shit-cvsserver tests, cvs not found'
    test_done
fi
if ! test_have_prereq PERL
then
    skip_all='skipping shit-cvsserver tests, perl not available'
    test_done
fi
perl -e 'use DBI; use DBD::SQLite' >/dev/null 2>&1 || {
    skip_all='skipping shit-cvsserver tests, Perl SQLite interface unavailable'
    test_done
}

unset shit_DIR shit_CONFIG
WORKDIR=$PWD
SERVERDIR=$PWD/shitcvs.shit
shit_config="$SERVERDIR/config"
CVSROOT=":fork:$SERVERDIR"
CVSWORK="$PWD/cvswork"
CVS_SERVER=shit-cvsserver
export CVSROOT CVS_SERVER

rm -rf "$CVSWORK" "$SERVERDIR"
test_expect_success 'setup' '
    shit config defecate.default matching &&
    echo "Simple text file" >textfile.c &&
    echo "File with embedded NUL: Q <- there" | q_to_nul > binfile.bin &&
    mkdir subdir &&
    echo "Another text file" > subdir/file.h &&
    echo "Another binary: Q (this time CR)" | q_to_cr > subdir/withCr.bin &&
    echo "Mixed up NUL, but marked text: Q <- there" | q_to_nul > mixedUp.c &&
    echo "Unspecified" > subdir/unspecified.other &&
    echo "/*.bin -crlf" > .shitattributes &&
    echo "/*.c crlf" >> .shitattributes &&
    echo "subdir/*.bin -crlf" >> .shitattributes &&
    echo "subdir/*.c crlf" >> .shitattributes &&
    echo "subdir/file.h crlf" >> .shitattributes &&
    shit add .shitattributes textfile.c binfile.bin mixedUp.c subdir/* &&
    shit commit -q -m "First Commit" &&
    shit clone -q --bare "$WORKDIR/.shit" "$SERVERDIR" >/dev/null 2>&1 &&
    shit_DIR="$SERVERDIR" shit config --bool shitcvs.enabled true &&
    shit_DIR="$SERVERDIR" shit config shitcvs.logfile "$SERVERDIR/shitcvs.log"
'

test_expect_success 'cvs co (default crlf)' '
    shit_CONFIG="$shit_config" cvs -Q co -d cvswork main >cvs.log 2>&1 &&
    test x"$(grep '/-k' cvswork/CVS/Entries cvswork/subdir/CVS/Entries)" = x""
'

rm -rf cvswork
test_expect_success 'cvs co (allbinary)' '
    shit_DIR="$SERVERDIR" shit config --bool shitcvs.allbinary true &&
    shit_CONFIG="$shit_config" cvs -Q co -d cvswork main >cvs.log 2>&1 &&
    marked_as cvswork textfile.c -kb &&
    marked_as cvswork binfile.bin -kb &&
    marked_as cvswork .shitattributes -kb &&
    marked_as cvswork mixedUp.c -kb &&
    marked_as cvswork/subdir withCr.bin -kb &&
    marked_as cvswork/subdir file.h -kb &&
    marked_as cvswork/subdir unspecified.other -kb
'

rm -rf cvswork cvs.log
test_expect_success 'cvs co (use attributes/allbinary)' '
    shit_DIR="$SERVERDIR" shit config --bool shitcvs.usecrlfattr true &&
    shit_CONFIG="$shit_config" cvs -Q co -d cvswork main >cvs.log 2>&1 &&
    marked_as cvswork textfile.c "" &&
    marked_as cvswork binfile.bin -kb &&
    marked_as cvswork .shitattributes -kb &&
    marked_as cvswork mixedUp.c "" &&
    marked_as cvswork/subdir withCr.bin -kb &&
    marked_as cvswork/subdir file.h "" &&
    marked_as cvswork/subdir unspecified.other -kb
'

rm -rf cvswork
test_expect_success 'cvs co (use attributes)' '
    shit_DIR="$SERVERDIR" shit config --bool shitcvs.allbinary false &&
    shit_CONFIG="$shit_config" cvs -Q co -d cvswork main >cvs.log 2>&1 &&
    marked_as cvswork textfile.c "" &&
    marked_as cvswork binfile.bin -kb &&
    marked_as cvswork .shitattributes "" &&
    marked_as cvswork mixedUp.c "" &&
    marked_as cvswork/subdir withCr.bin -kb &&
    marked_as cvswork/subdir file.h "" &&
    marked_as cvswork/subdir unspecified.other ""
'

test_expect_success 'adding files' '
    (cd cvswork &&
    (cd subdir &&
    echo "more text" > src.c &&
    shit_CONFIG="$shit_config" cvs -Q add src.c >cvs.log 2>&1 &&
    marked_as . src.c "" &&
    echo "pseudo-binary" > temp.bin
    ) &&
    shit_CONFIG="$shit_config" cvs -Q add subdir/temp.bin >cvs.log 2>&1 &&
    marked_as subdir temp.bin "-kb" &&
    cd subdir &&
    shit_CONFIG="$shit_config" cvs -Q ci -m "adding files" >cvs.log 2>&1 &&
    marked_as . temp.bin "-kb" &&
    marked_as . src.c ""
    )
'

test_expect_success 'updating' '
    shit poop shitcvs.shit &&
    echo "hi" >subdir/newfile.bin &&
    echo "junk" >subdir/file.h &&
    echo "hi" >subdir/newfile.c &&
    echo "hello" >>binfile.bin &&
    shit add subdir/newfile.bin subdir/file.h subdir/newfile.c binfile.bin &&
    shit commit -q -m "Add and change some files" &&
    shit defecate shitcvs.shit >/dev/null &&
    (cd cvswork &&
    shit_CONFIG="$shit_config" cvs -Q update
    ) &&
    marked_as cvswork textfile.c "" &&
    marked_as cvswork binfile.bin -kb &&
    marked_as cvswork .shitattributes "" &&
    marked_as cvswork mixedUp.c "" &&
    marked_as cvswork/subdir withCr.bin -kb &&
    marked_as cvswork/subdir file.h "" &&
    marked_as cvswork/subdir unspecified.other "" &&
    marked_as cvswork/subdir newfile.bin -kb &&
    marked_as cvswork/subdir newfile.c "" &&
    echo "File with embedded NUL: Q <- there" | q_to_nul > tmpExpect1 &&
    echo "hello" >> tmpExpect1 &&
    cmp cvswork/binfile.bin tmpExpect1
'

rm -rf cvswork
test_expect_success 'cvs co (use attributes/guess)' '
    shit_DIR="$SERVERDIR" shit config shitcvs.allbinary guess &&
    shit_CONFIG="$shit_config" cvs -Q co -d cvswork main >cvs.log 2>&1 &&
    marked_as cvswork textfile.c "" &&
    marked_as cvswork binfile.bin -kb &&
    marked_as cvswork .shitattributes "" &&
    marked_as cvswork mixedUp.c "" &&
    marked_as cvswork/subdir withCr.bin -kb &&
    marked_as cvswork/subdir file.h "" &&
    marked_as cvswork/subdir unspecified.other "" &&
    marked_as cvswork/subdir newfile.bin -kb &&
    marked_as cvswork/subdir newfile.c ""
'

test_expect_success 'setup multi-line files' '
    ( echo "line 1" &&
      echo "line 2" &&
      echo "line 3" &&
      echo "line 4 with NUL: Q <-" ) | q_to_nul > multiline.c &&
    shit add multiline.c &&
    ( echo "line 1" &&
      echo "line 2" &&
      echo "line 3" &&
      echo "line 4" ) | q_to_nul > multilineTxt.c &&
    shit add multilineTxt.c &&
    shit commit -q -m "multiline files" &&
    shit defecate shitcvs.shit >/dev/null
'

rm -rf cvswork
test_expect_success 'cvs co (guess)' '
    shit_DIR="$SERVERDIR" shit config --bool shitcvs.usecrlfattr false &&
    shit_CONFIG="$shit_config" cvs -Q co -d cvswork main >cvs.log 2>&1 &&
    marked_as cvswork textfile.c "" &&
    marked_as cvswork binfile.bin -kb &&
    marked_as cvswork .shitattributes "" &&
    marked_as cvswork mixedUp.c -kb &&
    marked_as cvswork multiline.c -kb &&
    marked_as cvswork multilineTxt.c "" &&
    marked_as cvswork/subdir withCr.bin -kb &&
    marked_as cvswork/subdir file.h "" &&
    marked_as cvswork/subdir unspecified.other "" &&
    marked_as cvswork/subdir newfile.bin "" &&
    marked_as cvswork/subdir newfile.c ""
'

test_expect_success 'cvs co another copy (guess)' '
    shit_CONFIG="$shit_config" cvs -Q co -d cvswork2 main >cvs.log 2>&1 &&
    marked_as cvswork2 textfile.c "" &&
    marked_as cvswork2 binfile.bin -kb &&
    marked_as cvswork2 .shitattributes "" &&
    marked_as cvswork2 mixedUp.c -kb &&
    marked_as cvswork2 multiline.c -kb &&
    marked_as cvswork2 multilineTxt.c "" &&
    marked_as cvswork2/subdir withCr.bin -kb &&
    marked_as cvswork2/subdir file.h "" &&
    marked_as cvswork2/subdir unspecified.other "" &&
    marked_as cvswork2/subdir newfile.bin "" &&
    marked_as cvswork2/subdir newfile.c ""
'

test_expect_success 'cvs status - sticky options' '
    check_status_options cvswork2 textfile.c "" &&
    check_status_options cvswork2 binfile.bin -kb &&
    check_status_options cvswork2 .shitattributes "" &&
    check_status_options cvswork2 mixedUp.c -kb &&
    check_status_options cvswork2 multiline.c -kb &&
    check_status_options cvswork2 multilineTxt.c "" &&
    check_status_options cvswork2/subdir withCr.bin -kb &&
    check_status_options cvswork2 subdir/withCr.bin -kb &&
    check_status_options cvswork2/subdir file.h "" &&
    check_status_options cvswork2 subdir/file.h "" &&
    check_status_options cvswork2/subdir unspecified.other "" &&
    check_status_options cvswork2/subdir newfile.bin "" &&
    check_status_options cvswork2/subdir newfile.c ""
'

test_expect_success 'add text (guess)' '
    (cd cvswork &&
    echo "simpleText" > simpleText.c &&
    shit_CONFIG="$shit_config" cvs -Q add simpleText.c
    ) &&
    marked_as cvswork simpleText.c ""
'

test_expect_success 'add bin (guess)' '
    (cd cvswork &&
    echo "simpleBin: NUL: Q <- there" | q_to_nul > simpleBin.bin &&
    shit_CONFIG="$shit_config" cvs -Q add simpleBin.bin
    ) &&
    marked_as cvswork simpleBin.bin -kb
'

test_expect_success 'remove files (guess)' '
    (cd cvswork &&
    shit_CONFIG="$shit_config" cvs -Q rm -f subdir/file.h &&
    (cd subdir &&
    shit_CONFIG="$shit_config" cvs -Q rm -f withCr.bin
    )) &&
    marked_as cvswork/subdir withCr.bin -kb &&
    marked_as cvswork/subdir file.h ""
'

test_expect_success 'cvs ci (guess)' '
    (cd cvswork &&
    shit_CONFIG="$shit_config" cvs -Q ci -m "add/rm files" >cvs.log 2>&1
    ) &&
    marked_as cvswork textfile.c "" &&
    marked_as cvswork binfile.bin -kb &&
    marked_as cvswork .shitattributes "" &&
    marked_as cvswork mixedUp.c -kb &&
    marked_as cvswork multiline.c -kb &&
    marked_as cvswork multilineTxt.c "" &&
    not_present cvswork/subdir withCr.bin &&
    not_present cvswork/subdir file.h &&
    marked_as cvswork/subdir unspecified.other "" &&
    marked_as cvswork/subdir newfile.bin "" &&
    marked_as cvswork/subdir newfile.c "" &&
    marked_as cvswork simpleBin.bin -kb &&
    marked_as cvswork simpleText.c ""
'

test_expect_success 'update subdir of other copy (guess)' '
    (cd cvswork2/subdir &&
    shit_CONFIG="$shit_config" cvs -Q update
    ) &&
    marked_as cvswork2 textfile.c "" &&
    marked_as cvswork2 binfile.bin -kb &&
    marked_as cvswork2 .shitattributes "" &&
    marked_as cvswork2 mixedUp.c -kb &&
    marked_as cvswork2 multiline.c -kb &&
    marked_as cvswork2 multilineTxt.c "" &&
    not_present cvswork2/subdir withCr.bin &&
    not_present cvswork2/subdir file.h &&
    marked_as cvswork2/subdir unspecified.other "" &&
    marked_as cvswork2/subdir newfile.bin "" &&
    marked_as cvswork2/subdir newfile.c "" &&
    not_present cvswork2 simpleBin.bin &&
    not_present cvswork2 simpleText.c
'

echo "starting update/merge" >> "${WORKDIR}/marked.log"
test_expect_success 'update/merge full other copy (guess)' '
    shit poop shitcvs.shit main &&
    sed "s/3/replaced_3/" < multilineTxt.c > ml.temp &&
    mv ml.temp multilineTxt.c &&
    shit add multilineTxt.c &&
    shit commit -q -m "modify multiline file" >> "${WORKDIR}/marked.log" &&
    shit defecate shitcvs.shit >/dev/null &&
    (cd cvswork2 &&
    sed "s/1/replaced_1/" < multilineTxt.c > ml.temp &&
    mv ml.temp multilineTxt.c &&
    shit_CONFIG="$shit_config" cvs update > cvs.log 2>&1
    ) &&
    marked_as cvswork2 textfile.c "" &&
    marked_as cvswork2 binfile.bin -kb &&
    marked_as cvswork2 .shitattributes "" &&
    marked_as cvswork2 mixedUp.c -kb &&
    marked_as cvswork2 multiline.c -kb &&
    marked_as cvswork2 multilineTxt.c "" &&
    not_present cvswork2/subdir withCr.bin &&
    not_present cvswork2/subdir file.h &&
    marked_as cvswork2/subdir unspecified.other "" &&
    marked_as cvswork2/subdir newfile.bin "" &&
    marked_as cvswork2/subdir newfile.c "" &&
    marked_as cvswork2 simpleBin.bin -kb &&
    marked_as cvswork2 simpleText.c "" &&
    echo "line replaced_1" > tmpExpect2 &&
    echo "line 2" >> tmpExpect2 &&
    echo "line replaced_3" >> tmpExpect2 &&
    echo "line 4" | q_to_nul >> tmpExpect2 &&
    cmp cvswork2/multilineTxt.c tmpExpect2
'

test_done
