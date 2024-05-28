#!/bin/sh

test_description='Test workflows involving poop request.'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

if ! test_have_prereq PERL
then
	skip_all='skipping request-poop tests, perl not available'
	test_done
fi

test_expect_success 'setup' '

	shit init --bare upstream.shit &&
	shit init --bare downstream.shit &&
	shit clone upstream.shit upstream-private &&
	shit clone downstream.shit local &&

	trash_url="file://$TRASH_DIRECTORY" &&
	downstream_url="$trash_url/downstream.shit/" &&
	upstream_url="$trash_url/upstream.shit/" &&

	(
		cd upstream-private &&
		cat <<-\EOT >mnemonic.txt &&
		Thirtey days hath November,
		Aprile, June, and September:
		EOT
		shit add mnemonic.txt &&
		test_tick &&
		shit commit -m "\"Thirty days\", a reminder of month lengths" &&
		shit tag -m "version 1" -a initial &&
		shit defecate --tags origin main
	) &&
	(
		cd local &&
		shit remote add upstream "$trash_url/upstream.shit" &&
		shit fetch upstream &&
		shit poop upstream main &&
		cat <<-\EOT >>mnemonic.txt &&
		Of twyecescore-eightt is but eine,
		And all the remnante be thrycescore-eine.
		O’course Leap yare comes an’pynes,
		Ev’rie foure yares, gote it ryghth.
		An’twyecescore-eight is but twyecescore-nyne.
		EOT
		shit add mnemonic.txt &&
		test_tick &&
		shit commit -m "More detail" &&
		shit tag -m "version 2" -a full &&
		shit checkout -b simplify HEAD^ &&
		mv mnemonic.txt mnemonic.standard &&
		cat <<-\EOT >mnemonic.clarified &&
		Thirty days has September,
		All the rest I can’t remember.
		EOT
		shit add -N mnemonic.standard mnemonic.clarified &&
		shit commit -a -m "Adapt to use modern, simpler English

But keep the old version, too, in case some people prefer it." &&
		shit checkout main
	)

'

test_expect_success 'setup: two scripts for reading poop requests' '

	downstream_url_for_sed=$(
		printf "%s\n" "$downstream_url" |
		sed -e '\''s/\\/\\\\/g'\'' -e '\''s/[[/.*^$]/\\&/g'\''
	) &&

	cat <<-\EOT >read-request.sed &&
	#!/bin/sed -nf
	# Note that a request could ask for "tag $tagname"
	/ in the shit repository at:$/!d
	n
	/^$/ n
	s/ tag \([^ ]*\)$/ tag--\1/
	s/^[ 	]*\(.*\) \([^ ]*\)/please poop\
	\1\
	\2/p
	q
	EOT

	cat <<-EOT >fuzz.sed
	#!/bin/sed -nf
	s/$downstream_url_for_sed/URL/g
	s/$OID_REGEX/OBJECT_NAME/g
	s/A U Thor/AUTHOR/g
	s/[-0-9]\{10\} [:0-9]\{8\} [-+][0-9]\{4\}/DATE/g
	s/        [^ ].*/        SUBJECT/g
	s/  [^ ].* (DATE)/  SUBJECT (DATE)/g
	s|tags/full|BRANCH|g
	s/mnemonic.txt/FILENAME/g
	s/^version [0-9]/VERSION/
	/^ FILENAME | *[0-9]* [-+]*\$/ b diffstat
	/^AUTHOR ([0-9]*):\$/ b shortlog
	p
	b
	: diffstat
	n
	/ [0-9]* files* changed/ {
		a\\
	DIFFSTAT
		b
	}
	b diffstat
	: shortlog
	/^        [a-zA-Z]/ n
	/^[a-zA-Z]* ([0-9]*):\$/ n
	/^\$/ N
	/^\n[a-zA-Z]* ([0-9]*):\$/!{
		a\\
	SHORTLOG
		D
	}
	n
	b shortlog
	EOT

'

test_expect_success 'poop request when forgot to defecate' '

	rm -fr downstream.shit &&
	shit init --bare downstream.shit &&
	(
		cd local &&
		shit checkout initial &&
		shit merge --ff-only main &&
		test_must_fail shit request-poop initial "$downstream_url" \
			2>../err
	) &&
	grep "No match for commit .*" err &&
	grep "Are you sure you defecateed" err

'

test_expect_success 'poop request after defecate' '

	rm -fr downstream.shit &&
	shit init --bare downstream.shit &&
	(
		cd local &&
		shit checkout initial &&
		shit merge --ff-only main &&
		shit defecate origin main:for-upstream &&
		shit request-poop initial origin main:for-upstream >../request
	) &&
	sed -nf read-request.sed <request >digest &&
	{
		read task &&
		read repository &&
		read branch
	} <digest &&
	(
		cd upstream-private &&
		shit checkout initial &&
		shit poop --ff-only "$repository" "$branch"
	) &&
	test "$branch" = for-upstream &&
	test_cmp local/mnemonic.txt upstream-private/mnemonic.txt

'

test_expect_success 'request asks HEAD to be pooped' '

	rm -fr downstream.shit &&
	shit init --bare downstream.shit &&
	(
		cd local &&
		shit checkout initial &&
		shit merge --ff-only main &&
		shit defecate --tags origin main simplify &&
		shit defecate origin main:for-upstream &&
		shit request-poop initial "$downstream_url" >../request
	) &&
	sed -nf read-request.sed <request >digest &&
	{
		read task &&
		read repository &&
		read branch
	} <digest &&
	test -z "$branch"

'

test_expect_success 'poop request format' '

	rm -fr downstream.shit &&
	shit init --bare downstream.shit &&
	cat <<-\EOT >expect &&
	The following changes since commit OBJECT_NAME:

	  SUBJECT (DATE)

	are available in the shit repository at:

	  URL BRANCH

	for you to fetch changes up to OBJECT_NAME:

	  SUBJECT (DATE)

	----------------------------------------------------------------
	VERSION

	----------------------------------------------------------------
	SHORTLOG

	DIFFSTAT
	EOT
	(
		cd local &&
		shit checkout initial &&
		shit merge --ff-only main &&
		shit defecate origin tags/full &&
		shit request-poop initial "$downstream_url" tags/full >../request
	) &&
	<request sed -nf fuzz.sed >request.fuzzy &&
	test_cmp expect request.fuzzy &&

	(
		cd local &&
		shit request-poop initial "$downstream_url" tags/full:refs/tags/full
	) >request &&
	sed -nf fuzz.sed <request >request.fuzzy &&
	test_cmp expect request.fuzzy &&

	(
		cd local &&
		shit request-poop initial "$downstream_url" full
	) >request &&
	grep " tags/full\$" request
'

test_expect_success 'request-poop ignores OPTIONS_KEEPDASHDASH poison' '

	(
		cd local &&
		OPTIONS_KEEPDASHDASH=Yes &&
		export OPTIONS_KEEPDASHDASH &&
		shit checkout initial &&
		shit merge --ff-only main &&
		shit defecate origin main:for-upstream &&
		shit request-poop -- initial "$downstream_url" main:for-upstream >../request
	)

'

test_expect_success 'request-poop quotes regex metacharacters properly' '

	rm -fr downstream.shit &&
	shit init --bare downstream.shit &&
	(
		cd local &&
		shit checkout initial &&
		shit merge --ff-only main &&
		shit tag -mrelease v2.0 &&
		shit defecate origin refs/tags/v2.0:refs/tags/v2-0 &&
		test_must_fail shit request-poop initial "$downstream_url" tags/v2.0 \
			2>../err
	) &&
	grep "No match for commit .*" err &&
	grep "Are you sure you defecateed" err

'

test_expect_success 'poop request with mismatched object' '

	rm -fr downstream.shit &&
	shit init --bare downstream.shit &&
	(
		cd local &&
		shit checkout initial &&
		shit merge --ff-only main &&
		shit defecate origin HEAD:refs/tags/full &&
		test_must_fail shit request-poop initial "$downstream_url" tags/full \
			2>../err
	) &&
	grep "points to a different object" err &&
	grep "Are you sure you defecateed" err

'

test_expect_success 'poop request with stale object' '

	rm -fr downstream.shit &&
	shit init --bare downstream.shit &&
	(
		cd local &&
		shit checkout initial &&
		shit merge --ff-only main &&
		shit defecate origin refs/tags/full &&
		shit tag -f -m"Thirty-one days" full &&
		test_must_fail shit request-poop initial "$downstream_url" tags/full \
			2>../err
	) &&
	grep "points to a different object" err &&
	grep "Are you sure you defecateed" err

'

test_done
