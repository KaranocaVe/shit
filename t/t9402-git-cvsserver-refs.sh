#!/bin/sh

test_description='shit-cvsserver and shit refspecs

tests ability for shit-cvsserver to switch between and compare
tags, branches and other shit refspecs'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

#########

check_start_tree() {
	rm -f "$WORKDIR/list.expected"
	echo "start $1" >>"${WORKDIR}/check.log"
}

check_file() {
	sandbox="$1"
	file="$2"
	ver="$3"
	shit_DIR=$SERVERDIR shit show "${ver}:${file}" \
		>"$WORKDIR/check.got" 2>"$WORKDIR/check.stderr"
	test_cmp "$WORKDIR/check.got" "$sandbox/$file"
	stat=$?
	echo "check_file $sandbox $file $ver : $stat" >>"$WORKDIR/check.log"
	echo "$file" >>"$WORKDIR/list.expected"
	return $stat
}

check_end_tree() {
	sandbox="$1" &&
	find "$sandbox" -name CVS -prune -o -type f -print >"$WORKDIR/list.actual" &&
	sort <"$WORKDIR/list.expected" >expected &&
	sort <"$WORKDIR/list.actual" | sed -e "s%cvswork/%%" >actual &&
	test_cmp expected actual &&
	rm expected actual
}

check_end_full_tree() {
	sandbox="$1" &&
	sort <"$WORKDIR/list.expected" >expected &&
	find "$sandbox" -name CVS -prune -o -type f -print |
	sed -e "s%$sandbox/%%" | sort >act1 &&
	test_cmp expected act1 &&
	shit ls-tree --name-only -r "$2" | sort >act2 &&
	test_cmp expected act2 &&
	rm expected act1 act2
}

#########

check_diff() {
	diffFile="$1"
	vOld="$2"
	vNew="$3"
	rm -rf diffSandbox
	shit clone -q -n . diffSandbox &&
	(
		cd diffSandbox &&
		shit checkout "$vOld" &&
		shit apply -p0 --index <"../$diffFile" &&
		shit diff --exit-code "$vNew"
	) >check_diff_apply.out 2>&1
}

#########

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
test_expect_success 'setup v1, b1' '
	echo "Simple text file" >textfile.c &&
	echo "t2" >t2 &&
	mkdir adir &&
	echo "adir/afile line1" >adir/afile &&
	echo "adir/afile line2" >>adir/afile &&
	echo "adir/afile line3" >>adir/afile &&
	echo "adir/afile line4" >>adir/afile &&
	echo "adir/a2file" >>adir/a2file &&
	mkdir adir/bdir &&
	echo "adir/bdir/bfile line 1" >adir/bdir/bfile &&
	echo "adir/bdir/bfile line 2" >>adir/bdir/bfile &&
	echo "adir/bdir/b2file" >adir/bdir/b2file &&
	shit add textfile.c t2 adir &&
	shit commit -q -m "First Commit (v1)" &&
	shit tag v1 &&
	shit branch b1 &&
	shit clone -q --bare "$WORKDIR/.shit" "$SERVERDIR" >/dev/null 2>&1 &&
	shit_DIR="$SERVERDIR" shit config --bool shitcvs.enabled true &&
	shit_DIR="$SERVERDIR" shit config shitcvs.logfile "$SERVERDIR/shitcvs.log"
'

rm -rf cvswork
test_expect_success 'cvs co v1' '
	cvs -f -Q co -r v1 -d cvswork main >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v1 &&
	check_file cvswork t2 v1 &&
	check_file cvswork adir/afile v1 &&
	check_file cvswork adir/a2file v1 &&
	check_file cvswork adir/bdir/bfile v1 &&
	check_file cvswork adir/bdir/b2file v1 &&
	check_end_tree cvswork
'

rm -rf cvswork
test_expect_success 'cvs co b1' '
	cvs -f co -r b1 -d cvswork main >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v1 &&
	check_file cvswork t2 v1 &&
	check_file cvswork adir/afile v1 &&
	check_file cvswork adir/a2file v1 &&
	check_file cvswork adir/bdir/bfile v1 &&
	check_file cvswork adir/bdir/b2file v1 &&
	check_end_tree cvswork
'

test_expect_success 'cvs co b1 [cvswork3]' '
	cvs -f co -r b1 -d cvswork3 main >cvs.log 2>&1 &&
	check_start_tree cvswork3 &&
	check_file cvswork3 textfile.c v1 &&
	check_file cvswork3 t2 v1 &&
	check_file cvswork3 adir/afile v1 &&
	check_file cvswork3 adir/a2file v1 &&
	check_file cvswork3 adir/bdir/bfile v1 &&
	check_file cvswork3 adir/bdir/b2file v1 &&
	check_end_full_tree cvswork3 v1
'

test_expect_success 'edit cvswork3 and save diff' '
	(
		cd cvswork3 &&
		sed -e "s/line1/line1 - data/" adir/afile >adir/afileNEW &&
		mv -f adir/afileNEW adir/afile &&
		echo "afile5" >adir/afile5 &&
		rm t2 &&
		cvs -f add adir/afile5 &&
		cvs -f rm t2 &&
		! cvs -f diff -N -u >"$WORKDIR/cvswork3edit.diff"
	)
'

test_expect_success 'setup v1.2 on b1' '
	shit checkout b1 &&
	echo "new v1.2" >t3 &&
	rm t2 &&
	sed -e "s/line3/line3 - more data/" adir/afile >adir/afileNEW &&
	mv -f adir/afileNEW adir/afile &&
	rm adir/a2file &&
	echo "a3file" >>adir/a3file &&
	echo "bfile line 3" >>adir/bdir/bfile &&
	rm adir/bdir/b2file &&
	echo "b3file" >adir/bdir/b3file &&
	mkdir cdir &&
	echo "cdir/cfile" >cdir/cfile &&
	shit add -A cdir adir t3 t2 &&
	shit commit -q -m "v1.2" &&
	shit tag v1.2 &&
	shit defecate --tags shitcvs.shit b1:b1
'

test_expect_success 'cvs -f up (on b1 adir)' '
	( cd cvswork/adir && cvs -f up -d ) >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v1 &&
	check_file cvswork t2 v1 &&
	check_file cvswork adir/afile v1.2 &&
	check_file cvswork adir/a3file v1.2 &&
	check_file cvswork adir/bdir/bfile v1.2 &&
	check_file cvswork adir/bdir/b3file v1.2 &&
	check_end_tree cvswork
'

test_expect_success 'cvs up (on b1 /)' '
	( cd cvswork && cvs -f up -d ) >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v1.2 &&
	check_file cvswork t3 v1.2 &&
	check_file cvswork adir/afile v1.2 &&
	check_file cvswork adir/a3file v1.2 &&
	check_file cvswork adir/bdir/bfile v1.2 &&
	check_file cvswork adir/bdir/b3file v1.2 &&
	check_file cvswork cdir/cfile v1.2 &&
	check_end_tree cvswork
'

# Make sure "CVS/Tag" files didn't get messed up:
test_expect_success 'cvs up (on b1 /) (again; check CVS/Tag files)' '
	( cd cvswork && cvs -f up -d ) >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v1.2 &&
	check_file cvswork t3 v1.2 &&
	check_file cvswork adir/afile v1.2 &&
	check_file cvswork adir/a3file v1.2 &&
	check_file cvswork adir/bdir/bfile v1.2 &&
	check_file cvswork adir/bdir/b3file v1.2 &&
	check_file cvswork cdir/cfile v1.2 &&
	check_end_tree cvswork
'

# update to another version:
test_expect_success 'cvs up -r v1' '
	( cd cvswork && cvs -f up -r v1 ) >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v1 &&
	check_file cvswork t2 v1 &&
	check_file cvswork adir/afile v1 &&
	check_file cvswork adir/a2file v1 &&
	check_file cvswork adir/bdir/bfile v1 &&
	check_file cvswork adir/bdir/b2file v1 &&
	check_end_tree cvswork
'

test_expect_success 'cvs up' '
	( cd cvswork && cvs -f up ) >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v1 &&
	check_file cvswork t2 v1 &&
	check_file cvswork adir/afile v1 &&
	check_file cvswork adir/a2file v1 &&
	check_file cvswork adir/bdir/bfile v1 &&
	check_file cvswork adir/bdir/b2file v1 &&
	check_end_tree cvswork
'

test_expect_success 'cvs up (again; check CVS/Tag files)' '
	( cd cvswork && cvs -f up -d ) >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v1 &&
	check_file cvswork t2 v1 &&
	check_file cvswork adir/afile v1 &&
	check_file cvswork adir/a2file v1 &&
	check_file cvswork adir/bdir/bfile v1 &&
	check_file cvswork adir/bdir/b2file v1 &&
	check_end_tree cvswork
'

test_expect_success 'setup simple b2' '
	shit branch b2 v1 &&
	shit defecate --tags shitcvs.shit b2:b2
'

test_expect_success 'cvs co b2 [into cvswork2]' '
	cvs -f co -r b2 -d cvswork2 main >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v1 &&
	check_file cvswork t2 v1 &&
	check_file cvswork adir/afile v1 &&
	check_file cvswork adir/a2file v1 &&
	check_file cvswork adir/bdir/bfile v1 &&
	check_file cvswork adir/bdir/b2file v1 &&
	check_end_tree cvswork
'

test_expect_success 'root dir edit [cvswork2]' '
	(
		cd cvswork2 && echo "Line 2" >>textfile.c &&
		! cvs -f diff -u >"$WORKDIR/cvsEdit1.diff" &&
		cvs -f commit -m "edit textfile.c" textfile.c
	) >cvsEdit1.log 2>&1
'

test_expect_success 'root dir rm file [cvswork2]' '
	(
		cd cvswork2 &&
		cvs -f rm -f t2 &&
		cvs -f diff -u >../cvsEdit2-empty.diff &&
		! cvs -f diff -N -u >"$WORKDIR/cvsEdit2-N.diff" &&
		cvs -f commit -m "rm t2"
	) >cvsEdit2.log 2>&1
'

test_expect_success 'subdir edit/add/rm files [cvswork2]' '
	(
		cd cvswork2 &&
		sed -e "s/line 1/line 1 (v2)/" adir/bdir/bfile >adir/bdir/bfileNEW &&
		mv -f adir/bdir/bfileNEW adir/bdir/bfile &&
		rm adir/bdir/b2file &&
		cd adir &&
		cvs -f rm bdir/b2file &&
		echo "4th file" >bdir/b4file &&
		cvs -f add bdir/b4file &&
		! cvs -f diff -N -u >"$WORKDIR/cvsEdit3.diff" &&
		shit fetch shitcvs.shit b2:b2 &&
		(
		  cd .. &&
		  ! cvs -f diff -u -N -r v1.2 >"$WORKDIR/cvsEdit3-v1.2.diff" &&
		  ! cvs -f diff -u -N -r v1.2 -r v1 >"$WORKDIR/cvsEdit3-v1.2-v1.diff"
		) &&
		cvs -f commit -m "various add/rm/edit"
	) >cvs.log 2>&1
'

test_expect_success 'validate result of edits [cvswork2]' '
	shit fetch shitcvs.shit b2:b2 &&
	shit tag v2 b2 &&
	shit defecate --tags shitcvs.shit b2:b2 &&
	check_start_tree cvswork2 &&
	check_file cvswork2 textfile.c v2 &&
	check_file cvswork2 adir/afile v2 &&
	check_file cvswork2 adir/a2file v2 &&
	check_file cvswork2 adir/bdir/bfile v2 &&
	check_file cvswork2 adir/bdir/b4file v2 &&
	check_end_full_tree cvswork2 v2
'

test_expect_success 'validate basic diffs saved during above cvswork2 edits' '
	test $(grep Index: cvsEdit1.diff | wc -l) = 1 &&
	test_must_be_empty cvsEdit2-empty.diff &&
	test $(grep Index: cvsEdit2-N.diff | wc -l) = 1 &&
	test $(grep Index: cvsEdit3.diff | wc -l) = 3 &&
	rm -rf diffSandbox &&
	shit clone -q -n . diffSandbox &&
	(
		cd diffSandbox &&
		shit checkout v1 &&
		shit apply -p0 --index <"$WORKDIR/cvsEdit1.diff" &&
		shit apply -p0 --index <"$WORKDIR/cvsEdit2-N.diff" &&
		shit apply -p0 --directory=adir --index <"$WORKDIR/cvsEdit3.diff" &&
		shit diff --exit-code v2
	) >"check_diff_apply.out" 2>&1
'

test_expect_success 'validate v1.2 diff saved during last cvswork2 edit' '
	test $(grep Index: cvsEdit3-v1.2.diff | wc -l) = 9 &&
	check_diff cvsEdit3-v1.2.diff v1.2 v2
'

test_expect_success 'validate v1.2 v1 diff saved during last cvswork2 edit' '
	test $(grep Index: cvsEdit3-v1.2-v1.diff | wc -l) = 9 &&
	check_diff cvsEdit3-v1.2-v1.diff v1.2 v1
'

test_expect_success 'cvs up [cvswork2]' '
	( cd cvswork2 && cvs -f up ) >cvs.log 2>&1 &&
	check_start_tree cvswork2 &&
	check_file cvswork2 textfile.c v2 &&
	check_file cvswork2 adir/afile v2 &&
	check_file cvswork2 adir/a2file v2 &&
	check_file cvswork2 adir/bdir/bfile v2 &&
	check_file cvswork2 adir/bdir/b4file v2 &&
	check_end_full_tree cvswork2 v2
'

test_expect_success 'cvs up -r b2 [back to cvswork]' '
	( cd cvswork && cvs -f up -r b2 ) >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v2 &&
	check_file cvswork adir/afile v2 &&
	check_file cvswork adir/a2file v2 &&
	check_file cvswork adir/bdir/bfile v2 &&
	check_file cvswork adir/bdir/b4file v2 &&
	check_end_full_tree cvswork v2
'

test_expect_success 'cvs up -r b1' '
	( cd cvswork && cvs -f up -r b1 ) >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v1.2 &&
	check_file cvswork t3 v1.2 &&
	check_file cvswork adir/afile v1.2 &&
	check_file cvswork adir/a3file v1.2 &&
	check_file cvswork adir/bdir/bfile v1.2 &&
	check_file cvswork adir/bdir/b3file v1.2 &&
	check_file cvswork cdir/cfile v1.2 &&
	check_end_full_tree cvswork v1.2
'

test_expect_success 'cvs up -A' '
	( cd cvswork && cvs -f up -A ) >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v1 &&
	check_file cvswork t2 v1 &&
	check_file cvswork adir/afile v1 &&
	check_file cvswork adir/a2file v1 &&
	check_file cvswork adir/bdir/bfile v1 &&
	check_file cvswork adir/bdir/b2file v1 &&
	check_end_full_tree cvswork v1
'

test_expect_success 'cvs up (check CVS/Tag files)' '
	( cd cvswork && cvs -f up ) >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v1 &&
	check_file cvswork t2 v1 &&
	check_file cvswork adir/afile v1 &&
	check_file cvswork adir/a2file v1 &&
	check_file cvswork adir/bdir/bfile v1 &&
	check_file cvswork adir/bdir/b2file v1 &&
	check_end_full_tree cvswork v1
'

# This is not really legal CVS, but it seems to work anyway:
test_expect_success 'cvs up -r heads/b1' '
	( cd cvswork && cvs -f up -r heads/b1 ) >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v1.2 &&
	check_file cvswork t3 v1.2 &&
	check_file cvswork adir/afile v1.2 &&
	check_file cvswork adir/a3file v1.2 &&
	check_file cvswork adir/bdir/bfile v1.2 &&
	check_file cvswork adir/bdir/b3file v1.2 &&
	check_file cvswork cdir/cfile v1.2 &&
	check_end_full_tree cvswork v1.2
'

# But this should work even if CVS client checks -r more carefully:
test_expect_success 'cvs up -r heads_-s-b2 (cvsserver escape mechanism)' '
	( cd cvswork && cvs -f up -r heads_-s-b2 ) >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v2 &&
	check_file cvswork adir/afile v2 &&
	check_file cvswork adir/a2file v2 &&
	check_file cvswork adir/bdir/bfile v2 &&
	check_file cvswork adir/bdir/b4file v2 &&
	check_end_full_tree cvswork v2
'

v1hash=$(shit rev-parse v1)
test_expect_success 'cvs up -r $(shit rev-parse v1)' '
	test -n "$v1hash" &&
	( cd cvswork && cvs -f up -r "$v1hash" ) >cvs.log 2>&1 &&
	check_start_tree cvswork &&
	check_file cvswork textfile.c v1 &&
	check_file cvswork t2 v1 &&
	check_file cvswork adir/afile v1 &&
	check_file cvswork adir/a2file v1 &&
	check_file cvswork adir/bdir/bfile v1 &&
	check_file cvswork adir/bdir/b2file v1 &&
	check_end_full_tree cvswork v1
'

test_expect_success 'cvs diff -r v1 -u' '
	( cd cvswork && cvs -f diff -r v1 -u >../cvsDiff.out 2>../cvs.log ) &&
	test_must_be_empty cvsDiff.out &&
	test_must_be_empty cvs.log
'

test_expect_success 'cvs diff -N -r v2 -u' '
	( cd cvswork && ! cvs -f diff -N -r v2 -u >../cvsDiff.out 2>../cvs.log ) &&
	test_must_be_empty cvs.log &&
	test -s cvsDiff.out &&
	check_diff cvsDiff.out v2 v1 >check_diff.out 2>&1
'

test_expect_success 'cvs diff -N -r v2 -r v1.2' '
	( cd cvswork && ! cvs -f diff -N -r v2 -r v1.2 -u >../cvsDiff.out 2>../cvs.log ) &&
	test_must_be_empty cvs.log &&
	test -s cvsDiff.out &&
	check_diff cvsDiff.out v2 v1.2 >check_diff.out 2>&1
'

test_expect_success 'apply early [cvswork3] diff to b3' '
	shit clone -q . shitwork3 &&
	(
		cd shitwork3 &&
		shit checkout -b b3 v1 &&
		shit apply -p0 --index <"$WORKDIR/cvswork3edit.diff" &&
		shit commit -m "cvswork3 edits applied"
	) &&
	shit fetch shitwork3 b3:b3 &&
	shit tag v3 b3
'

test_expect_success 'check [cvswork3] diff' '
	( cd cvswork3 && ! cvs -f diff -N -u >"$WORKDIR/cvsDiff.out" 2>../cvs.log ) &&
	test_must_be_empty cvs.log &&
	test -s cvsDiff.out &&
	test $(grep Index: cvsDiff.out | wc -l) = 3 &&
	test_cmp cvsDiff.out cvswork3edit.diff &&
	check_diff cvsDiff.out v1 v3 >check_diff.out 2>&1
'

test_expect_success 'merge early [cvswork3] b3 with b1' '
	( cd shitwork3 && shit merge -m "message" b1 ) &&
	shit fetch shitwork3 b3:b3 &&
	shit tag v3merged b3 &&
	shit defecate --tags shitcvs.shit b3:b3
'

# This test would fail if cvsserver properly created a ".#afile"* file
# for the merge.
# TODO: Validate that the .# file was saved properly, and then
#   delete/ignore it when checking the tree.
test_expect_success 'cvs up dirty [cvswork3]' '
	(
		cd cvswork3 &&
		cvs -f up &&
		! cvs -f diff -N -u >"$WORKDIR/cvsDiff.out"
	) >cvs.log 2>&1 &&
	test -s cvsDiff.out &&
	test $(grep Index: cvsDiff.out | wc -l) = 2 &&
	check_start_tree cvswork3 &&
	check_file cvswork3 textfile.c v3merged &&
	check_file cvswork3 t3 v3merged &&
	check_file cvswork3 adir/afile v3merged &&
	check_file cvswork3 adir/a3file v3merged &&
	check_file cvswork3 adir/afile5 v3merged &&
	check_file cvswork3 adir/bdir/bfile v3merged &&
	check_file cvswork3 adir/bdir/b3file v3merged &&
	check_file cvswork3 cdir/cfile v3merged &&
	check_end_full_tree cvswork3 v3merged
'

# TODO: test cvs status

test_expect_success 'cvs commit [cvswork3]' '
	(
		cd cvswork3 &&
		cvs -f commit -m "dirty sandbox after auto-merge"
	) >cvs.log 2>&1 &&
	check_start_tree cvswork3 &&
	check_file cvswork3 textfile.c v3merged &&
	check_file cvswork3 t3 v3merged &&
	check_file cvswork3 adir/afile v3merged &&
	check_file cvswork3 adir/a3file v3merged &&
	check_file cvswork3 adir/afile5 v3merged &&
	check_file cvswork3 adir/bdir/bfile v3merged &&
	check_file cvswork3 adir/bdir/b3file v3merged &&
	check_file cvswork3 cdir/cfile v3merged &&
	check_end_full_tree cvswork3 v3merged &&
	shit fetch shitcvs.shit b3:b4 &&
	shit tag v4.1 b4 &&
	shit diff --exit-code v4.1 v3merged >check_diff_apply.out 2>&1
'

test_done
