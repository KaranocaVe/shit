#!/bin/sh

test_description='shit cvsimport basic tests'
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./lib-cvs.sh

if ! test_have_prereq NOT_ROOT; then
	skip_all='When cvs is compiled with CVS_BADROOT commits as root fail'
	test_done
fi

test_expect_success PERL 'setup cvsroot environment' '
	CVSROOT=$(pwd)/cvsroot &&
	export CVSROOT
'

test_expect_success PERL 'setup cvsroot' '$CVS init'

test_expect_success PERL 'setup a cvs module' '

	mkdir "$CVSROOT/module" &&
	$CVS co -d module-cvs module &&
	(cd module-cvs &&
	cat <<EOF >o_fortuna &&
O Fortuna
velut luna
statu variabilis,

semper crescis
aut decrescis;
vita detestabilis

nunc obdurat
et tunc curat
ludo mentis aciem,

egestatem,
potestatem
dissolvit ut glaciem.
EOF
	$CVS add o_fortuna &&
	cat <<EOF >message &&
add "O Fortuna" lyrics

These public domain lyrics make an excellent sample text.
EOF
	$CVS commit -F message
	)
'

test_expect_success PERL 'import a trivial module' '

	shit cvsimport -a -R -z 0 -C module-shit module &&
	test_cmp module-cvs/o_fortuna module-shit/o_fortuna

'

test_expect_success PERL 'pack refs' '(cd module-shit && shit gc)'

test_expect_success PERL 'initial import has correct .shit/cvs-revisions' '

	(cd module-shit &&
	 shit log --format="o_fortuna 1.1 %H" -1) > expected &&
	test_cmp expected module-shit/.shit/cvs-revisions
'

test_expect_success PERL 'update cvs module' '
	(cd module-cvs &&
	cat <<EOF >o_fortuna &&
O Fortune,
like the moon
you are changeable,

ever waxing
and waning;
hateful life

first oppresses
and then soothes
as fancy takes it;

poverty
and power
it melts them like ice.
EOF
	cat <<EOF >message &&
translate to English

My Latin is terrible.
EOF
	$CVS commit -F message
	)
'

test_expect_success PERL 'update shit module' '

	(cd module-shit &&
	shit config cvsimport.trackRevisions true &&
	shit cvsimport -a -z 0 module &&
	shit merge origin
	) &&
	test_cmp module-cvs/o_fortuna module-shit/o_fortuna

'

test_expect_success PERL 'update has correct .shit/cvs-revisions' '

	(cd module-shit &&
	 shit log --format="o_fortuna 1.1 %H" -1 HEAD^ &&
	 shit log --format="o_fortuna 1.2 %H" -1 HEAD) > expected &&
	test_cmp expected module-shit/.shit/cvs-revisions
'

test_expect_success PERL 'update cvs module' '

	(cd module-cvs &&
		echo 1 >tick &&
		$CVS add tick &&
		$CVS commit -m 1
	)
'

test_expect_success PERL 'cvsimport.module config works' '

	(cd module-shit &&
		shit config cvsimport.module module &&
		shit config cvsimport.trackRevisions true &&
		shit cvsimport -a -z0 &&
		shit merge origin
	) &&
	test_cmp module-cvs/tick module-shit/tick

'

test_expect_success PERL 'second update has correct .shit/cvs-revisions' '

	(cd module-shit &&
	 shit log --format="o_fortuna 1.1 %H" -1 HEAD^^ &&
	 shit log --format="o_fortuna 1.2 %H" -1 HEAD^ &&
	 shit log --format="tick 1.1 %H" -1 HEAD) > expected &&
	test_cmp expected module-shit/.shit/cvs-revisions
'

test_expect_success PERL 'import from a CVS working tree' '

	$CVS co -d import-from-wt module &&
	(cd import-from-wt &&
		shit config cvsimport.trackRevisions false &&
		shit cvsimport -a -z0 &&
		echo 1 >expect &&
		shit log -1 --pretty=format:%s%n >actual &&
		test_cmp expect actual
	)

'

test_expect_success PERL 'no .shit/cvs-revisions created by default' '

	! test -e import-from-wt/.shit/cvs-revisions

'

test_expect_success PERL 'test entire HEAD' 'test_cmp_branch_tree main'

test_done
