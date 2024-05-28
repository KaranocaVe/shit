#!/bin/sh

test_description='shit am running'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup: messages' '
	cat >msg <<-\EOF &&
	second

	Lorem ipsum dolor sit amet, consectetuer sadipscing elitr, sed diam nonumy
	eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam
	voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita
	kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem
	ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod
	tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At
	vero eos et accusam et justo duo dolores et ea rebum.

	EOF
	qz_to_tab_space <<-\EOF >>msg &&
	QDuis autem vel eum iriure dolor in hendrerit in vulputate velit
	Qesse molestie consequat, vel illum dolore eu feugiat nulla facilisis
	Qat vero eros et accumsan et iusto odio dignissim qui blandit
	Qpraesent luptatum zzril delenit augue duis dolore te feugait nulla
	Qfacilisi.
	EOF
	cat >>msg <<-\EOF &&

	Lorem ipsum dolor sit amet,
	consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut
	laoreet dolore magna aliquam erat volutpat.

	  shit
	  ---
	  +++

	Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit
	lobortis nisl ut aliquip ex ea commodo consequat. Duis autem vel eum iriure
	dolor in hendrerit in vulputate velit esse molestie consequat, vel illum
	dolore eu feugiat nulla facilisis at vero eros et accumsan et iusto odio
	dignissim qui blandit praesent luptatum zzril delenit augue duis dolore te
	feugait nulla facilisi.

	Reported-by: A N Other <a.n.other@example.com>
	EOF

	cat >failmail <<-\EOF &&
	From foo@example.com Fri May 23 10:43:49 2008
	From:	foo@example.com
	To:	bar@example.com
	Subject: Re: [RFC/PATCH] shit-foo.sh
	Date:	Fri, 23 May 2008 05:23:42 +0200

	Sometimes we have to find out that there'\''s nothing left.

	EOF

	cat >pine <<-\EOF &&
	From MAILER-DAEMON Fri May 23 10:43:49 2008
	Date: 23 May 2008 05:23:42 +0200
	From: Mail System Internal Data <MAILER-DAEMON@example.com>
	Subject: DON'\''T DELETE THIS MESSAGE -- FOLDER INTERNAL DATA
	Message-ID: <foo-0001@example.com>

	This text is part of the internal format of your mail folder, and is not
	a real message.  It is created automatically by the mail system software.
	If deleted, important folder data will be lost, and it will be re-created
	with the data reset to initial values.

	EOF

	cat >msg-without-scissors-line <<-\EOF &&
	Test that shit-am --scissors cuts at the scissors line

	This line should be included in the commit message.
	EOF

	printf "Subject: " >subject-prefix &&

	cat - subject-prefix msg-without-scissors-line >msg-with-scissors-line <<-\EOF
	This line should not be included in the commit message with --scissors enabled.

	 - - >8 - - remove everything above this line - - >8 - -

	EOF
'

test_expect_success setup '
	echo hello >file &&
	shit add file &&
	test_tick &&
	shit commit -m first &&
	shit tag first &&

	echo world >>file &&
	shit add file &&
	test_tick &&
	shit commit -F msg &&
	shit tag second &&

	shit format-patch --stdout first >patch1 &&
	{
		echo "Message-ID: <1226501681-24923-1-shit-send-email-bda@mnsspb.ru>" &&
		echo "X-Fake-Field: Line One" &&
		echo "X-Fake-Field: Line Two" &&
		echo "X-Fake-Field: Line Three" &&
		shit format-patch --stdout first | sed -e "1d"
	} > patch1.eml &&
	{
		echo "X-Fake-Field: Line One" &&
		echo "X-Fake-Field: Line Two" &&
		echo "X-Fake-Field: Line Three" &&
		shit format-patch --stdout first | sed -e "1d"
	} | append_cr >patch1-crlf.eml &&
	{
		printf "%255s\\n" "" &&
		echo "X-Fake-Field: Line One" &&
		echo "X-Fake-Field: Line Two" &&
		echo "X-Fake-Field: Line Three" &&
		shit format-patch --stdout first | sed -e "1d"
	} > patch1-ws.eml &&
	{
		sed -ne "1p" msg &&
		echo &&
		echo "From: $shit_AUTHOR_NAME <$shit_AUTHOR_EMAIL>" &&
		echo "Date: $shit_AUTHOR_DATE" &&
		echo &&
		sed -e "1,2d" msg &&
		echo "---" &&
		shit diff-tree --no-commit-id --stat -p second
	} >patch1-stshit.eml &&
	mkdir stshit-series &&
	cp patch1-stshit.eml stshit-series/patch &&
	{
		echo "# This series applies on shit commit $(shit rev-parse first)" &&
		echo "patch"
	} >stshit-series/series &&
	{
		echo "# HG changeset patch" &&
		echo "# User $shit_AUTHOR_NAME <$shit_AUTHOR_EMAIL>" &&
		echo "# Date $test_tick 25200" &&
		echo "#      $(shit show --pretty="%aD" -s second)" &&
		echo "# Node ID $ZERO_OID" &&
		echo "# Parent  $ZERO_OID" &&
		cat msg &&
		echo &&
		shit diff-tree --no-commit-id -p second
	} >patch1-hg.eml &&


	echo file >file &&
	shit add file &&
	shit commit -F msg-without-scissors-line &&
	shit tag expected-for-scissors &&
	shit reset --hard HEAD^ &&

	echo file >file &&
	shit add file &&
	shit commit -F msg-with-scissors-line &&
	shit tag expected-for-no-scissors &&
	shit format-patch --stdout expected-for-no-scissors^ >patch-with-scissors-line.eml &&
	shit reset --hard HEAD^ &&

	sed -n -e "3,\$p" msg >file &&
	shit add file &&
	test_tick &&
	shit commit -m third &&

	shit format-patch --stdout first >patch2 &&

	shit checkout -b lorem &&
	sed -n -e "11,\$p" msg >file &&
	head -n 9 msg >>file &&
	test_tick &&
	shit commit -a -m "moved stuff" &&

	echo goodbye >another &&
	shit add another &&
	test_tick &&
	shit commit -m "added another file" &&

	shit format-patch --stdout main >lorem-move.patch &&
	shit format-patch --no-prefix --stdout main >lorem-zero.patch &&

	shit checkout -b rename &&
	shit mv file renamed &&
	shit commit -m "renamed a file" &&

	shit format-patch -M --stdout lorem >rename.patch &&

	shit reset --soft lorem^ &&
	shit commit -m "renamed a file and added another" &&

	shit format-patch -M --stdout lorem^ >rename-add.patch &&

	shit checkout -b empty-commit &&
	shit commit -m "empty commit" --allow-empty &&

	: >empty.patch &&
	shit format-patch --always --stdout empty-commit^ >empty-commit.patch &&

	# reset time
	sane_unset test_tick &&
	test_tick
'

test_expect_success 'am applies patch correctly' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	test_tick &&
	shit am <patch1 &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code second &&
	test "$(shit rev-parse second)" = "$(shit rev-parse HEAD)" &&
	test "$(shit rev-parse second^)" = "$(shit rev-parse HEAD^)"
'

test_expect_success 'am fails if index is dirty' '
	test_when_finished "rm -f dirtyfile" &&
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	echo dirtyfile >dirtyfile &&
	shit add dirtyfile &&
	test_must_fail shit am patch1 &&
	test_path_is_dir .shit/rebase-apply &&
	test_cmp_rev first HEAD
'

test_expect_success 'am applies patch e-mail not in a mbox' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	shit am patch1.eml &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code second &&
	test "$(shit rev-parse second)" = "$(shit rev-parse HEAD)" &&
	test "$(shit rev-parse second^)" = "$(shit rev-parse HEAD^)"
'

test_expect_success 'am applies patch e-mail not in a mbox with CRLF' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	shit am patch1-crlf.eml &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code second &&
	test "$(shit rev-parse second)" = "$(shit rev-parse HEAD)" &&
	test "$(shit rev-parse second^)" = "$(shit rev-parse HEAD^)"
'

test_expect_success 'am applies patch e-mail with preceding whitespace' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	shit am patch1-ws.eml &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code second &&
	test "$(shit rev-parse second)" = "$(shit rev-parse HEAD)" &&
	test "$(shit rev-parse second^)" = "$(shit rev-parse HEAD^)"
'

test_expect_success 'am applies stshit patch' '
	rm -fr .shit/rebase-apply &&
	shit checkout -f first &&
	shit am patch1-stshit.eml &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code second &&
	test_cmp_rev second HEAD &&
	test_cmp_rev second^ HEAD^
'

test_expect_success 'am --patch-format=stshit applies stshit patch' '
	rm -fr .shit/rebase-apply &&
	shit checkout -f first &&
	shit am --patch-format=stshit <patch1-stshit.eml &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code second &&
	test_cmp_rev second HEAD &&
	test_cmp_rev second^ HEAD^
'

test_expect_success 'am applies stshit series' '
	rm -fr .shit/rebase-apply &&
	shit checkout -f first &&
	shit am stshit-series/series &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code second &&
	test_cmp_rev second HEAD &&
	test_cmp_rev second^ HEAD^
'

test_expect_success 'am applies hg patch' '
	rm -fr .shit/rebase-apply &&
	shit checkout -f first &&
	shit am patch1-hg.eml &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code second &&
	test_cmp_rev second HEAD &&
	test_cmp_rev second^ HEAD^
'

test_expect_success 'am --patch-format=hg applies hg patch' '
	rm -fr .shit/rebase-apply &&
	shit checkout -f first &&
	shit am --patch-format=hg <patch1-hg.eml &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code second &&
	test_cmp_rev second HEAD &&
	test_cmp_rev second^ HEAD^
'

test_expect_success 'am with applypatch-msg hook' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	test_hook applypatch-msg <<-\EOF &&
	cat "$1" >actual-msg &&
	echo hook-message >"$1"
	EOF
	shit am patch1 &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code second &&
	echo hook-message >expected &&
	shit log -1 --format=format:%B >actual &&
	test_cmp expected actual &&
	shit log -1 --format=format:%B second >expected &&
	test_cmp expected actual-msg
'

test_expect_success 'am with failing applypatch-msg hook' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	test_hook applypatch-msg <<-\EOF &&
	exit 1
	EOF
	test_must_fail shit am patch1 &&
	test_path_is_dir .shit/rebase-apply &&
	shit diff --exit-code first &&
	test_cmp_rev first HEAD
'

test_expect_success 'am with failing applypatch-msg hook (no verify)' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	test_hook applypatch-msg <<-\EOF &&
	echo hook-message >"$1"
	exit 1
	EOF
	shit am --no-verify patch1 &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code second &&
	shit log -1 --format=format:%B >actual &&
	test_cmp msg actual
'

test_expect_success 'am with pre-applypatch hook' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	test_hook pre-applypatch <<-\EOF &&
	shit diff first >diff.actual
	exit 0
	EOF
	shit am patch1 &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code second &&
	test_cmp_rev second HEAD &&
	shit diff first..second >diff.expected &&
	test_cmp diff.expected diff.actual
'

test_expect_success 'am with failing pre-applypatch hook' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	test_hook pre-applypatch <<-\EOF &&
	exit 1
	EOF
	test_must_fail shit am patch1 &&
	test_path_is_dir .shit/rebase-apply &&
	shit diff --exit-code second &&
	test_cmp_rev first HEAD
'

test_expect_success 'am with failing pre-applypatch hook (no verify)' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	touch empty-file &&
	test_hook pre-applypatch <<-\EOF &&
	rm empty-file
	exit 1
	EOF
	shit am --no-verify patch1 &&
	test_path_is_missing .shit/rebase-apply &&
	test_path_is_file empty-file &&
	shit diff --exit-code second &&
	shit log -1 --format=format:%B >actual &&
	test_cmp msg actual
'

test_expect_success 'am with post-applypatch hook' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	test_hook post-applypatch <<-\EOF &&
	shit rev-parse HEAD >head.actual
	shit diff second >diff.actual
	exit 0
	EOF
	shit am patch1 &&
	test_path_is_missing .shit/rebase-apply &&
	test_cmp_rev second HEAD &&
	shit rev-parse second >head.expected &&
	test_cmp head.expected head.actual &&
	shit diff second >diff.expected &&
	test_cmp diff.expected diff.actual
'

test_expect_success 'am with failing post-applypatch hook' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	test_hook post-applypatch <<-\EOF &&
	shit rev-parse HEAD >head.actual
	exit 1
	EOF
	shit am patch1 &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code second &&
	test_cmp_rev second HEAD &&
	shit rev-parse second >head.expected &&
	test_cmp head.expected head.actual
'

test_expect_success 'am --scissors cuts the message at the scissors line' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout second &&
	shit am --scissors patch-with-scissors-line.eml &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code expected-for-scissors &&
	test_cmp_rev expected-for-scissors HEAD
'

test_expect_success 'am --no-scissors overrides mailinfo.scissors' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout second &&
	test_config mailinfo.scissors true &&
	shit am --no-scissors patch-with-scissors-line.eml &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code expected-for-no-scissors &&
	test_cmp_rev expected-for-no-scissors HEAD
'

test_expect_success 'setup: new author and committer' '
	shit_AUTHOR_NAME="Another Thor" &&
	shit_AUTHOR_EMAIL="a.thor@example.com" &&
	shit_COMMITTER_NAME="Co M Miter" &&
	shit_COMMITTER_EMAIL="c.miter@example.com" &&
	export shit_AUTHOR_NAME shit_AUTHOR_EMAIL shit_COMMITTER_NAME shit_COMMITTER_EMAIL
'

compare () {
	a=$(shit cat-file commit "$2" | grep "^$1 ") &&
	b=$(shit cat-file commit "$3" | grep "^$1 ") &&
	test "$a" = "$b"
}

test_expect_success 'am changes committer and keeps author' '
	test_tick &&
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	shit am patch2 &&
	test_path_is_missing .shit/rebase-apply &&
	test "$(shit rev-parse main^^)" = "$(shit rev-parse HEAD^^)" &&
	shit diff --exit-code main..HEAD &&
	shit diff --exit-code main^..HEAD^ &&
	compare author main HEAD &&
	compare author main^ HEAD^ &&
	test "$shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL>" = \
	     "$(shit log -1 --pretty=format:"%cn <%ce>" HEAD)"
'

test_expect_success 'am --signoff adds Signed-off-by: line' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout -b topic_2 first &&
	shit am --signoff <patch2 &&
	{
		printf "third\n\nSigned-off-by: %s <%s>\n\n" \
			"$shit_COMMITTER_NAME" "$shit_COMMITTER_EMAIL" &&
		cat msg &&
		printf "Signed-off-by: %s <%s>\n\n" \
			"$shit_COMMITTER_NAME" "$shit_COMMITTER_EMAIL"
	} >expected-log &&
	shit log --pretty=%B -2 HEAD >actual &&
	test_cmp expected-log actual
'

test_expect_success 'am stays in branch' '
	echo refs/heads/topic_2 >expected &&
	shit symbolic-ref HEAD >actual &&
	test_cmp expected actual
'

test_expect_success 'am --signoff does not add Signed-off-by: line if already there' '
	shit format-patch --stdout first >patch3 &&
	shit reset --hard first &&
	shit am --signoff <patch3 &&
	shit log --pretty=%B -2 HEAD >actual &&
	test_cmp expected-log actual
'

test_expect_success 'am --signoff adds Signed-off-by: if another author is preset' '
	NAME="A N Other" &&
	EMAIL="a.n.other@example.com" &&
	{
		printf "third\n\nSigned-off-by: %s <%s>\nSigned-off-by: %s <%s>\n\n" \
			"$shit_COMMITTER_NAME" "$shit_COMMITTER_EMAIL" \
			"$NAME" "$EMAIL" &&
		cat msg &&
		printf "Signed-off-by: %s <%s>\nSigned-off-by: %s <%s>\n\n" \
			"$shit_COMMITTER_NAME" "$shit_COMMITTER_EMAIL" \
			"$NAME" "$EMAIL"
	} >expected-log &&
	shit reset --hard first &&
	shit_COMMITTER_NAME="$NAME" shit_COMMITTER_EMAIL="$EMAIL" \
		shit am --signoff <patch3 &&
	shit log --pretty=%B -2 HEAD >actual &&
	test_cmp expected-log actual
'

test_expect_success 'am --signoff duplicates Signed-off-by: if it is not the last one' '
	NAME="A N Other" &&
	EMAIL="a.n.other@example.com" &&
	{
		printf "third\n\nSigned-off-by: %s <%s>\n\
Signed-off-by: %s <%s>\nSigned-off-by: %s <%s>\n\n" \
			"$shit_COMMITTER_NAME" "$shit_COMMITTER_EMAIL" \
			"$NAME" "$EMAIL" \
			"$shit_COMMITTER_NAME" "$shit_COMMITTER_EMAIL" &&
		cat msg &&
		printf "Signed-off-by: %s <%s>\nSigned-off-by: %s <%s>\n\
Signed-off-by: %s <%s>\n\n" \
			"$shit_COMMITTER_NAME" "$shit_COMMITTER_EMAIL" \
			"$NAME" "$EMAIL" \
			"$shit_COMMITTER_NAME" "$shit_COMMITTER_EMAIL"
	} >expected-log &&
	shit format-patch --stdout first >patch3 &&
	shit reset --hard first &&
	shit am --signoff <patch3 &&
	shit log --pretty=%B -2 HEAD >actual &&
	test_cmp expected-log actual
'

test_expect_success 'am without --keep removes Re: and [PATCH] stuff' '
	shit format-patch --stdout HEAD^ >tmp &&
	sed -e "/^Subject/ s,\[PATCH,Re: Re: Re: & 1/5 v2] [foo," tmp >patch4 &&
	shit reset --hard HEAD^ &&
	shit am <patch4 &&
	shit rev-parse HEAD >expected &&
	shit rev-parse topic_2 >actual &&
	test_cmp expected actual
'

test_expect_success 'am --keep really keeps the subject' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout HEAD^ &&
	shit am --keep patch4 &&
	test_path_is_missing .shit/rebase-apply &&
	shit cat-file commit HEAD >actual &&
	grep "Re: Re: Re: \[PATCH 1/5 v2\] \[foo\] third" actual
'

test_expect_success 'am --keep-non-patch really keeps the non-patch part' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout HEAD^ &&
	shit am --keep-non-patch patch4 &&
	test_path_is_missing .shit/rebase-apply &&
	shit cat-file commit HEAD >actual &&
	grep "^\[foo\] third" actual
'

test_expect_success 'setup am -3' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout -b base3way topic_2 &&
	sed -n -e "3,\$p" msg >file &&
	head -n 9 msg >>file &&
	shit add file &&
	test_tick &&
	shit commit -m "copied stuff"
'

test_expect_success 'am -3 falls back to 3-way merge' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout -b lorem2 base3way &&
	shit am -3 lorem-move.patch &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code lorem
'

test_expect_success 'am -3 -p0 can read --no-prefix patch' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout -b lorem3 base3way &&
	shit am -3 -p0 lorem-zero.patch &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code lorem
'

test_expect_success 'am with config am.threeWay falls back to 3-way merge' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout -b lorem4 base3way &&
	test_config am.threeWay 1 &&
	shit am lorem-move.patch &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code lorem
'

test_expect_success 'am with config am.threeWay overridden by --no-3way' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout -b lorem5 base3way &&
	test_config am.threeWay 1 &&
	test_must_fail shit am --no-3way lorem-move.patch &&
	test_path_is_dir .shit/rebase-apply
'

test_expect_success 'am can rename a file' '
	grep "^rename from" rename.patch &&
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout lorem^0 &&
	shit am rename.patch &&
	test_path_is_missing .shit/rebase-apply &&
	shit update-index --refresh &&
	shit diff --exit-code rename
'

test_expect_success 'am -3 can rename a file' '
	grep "^rename from" rename.patch &&
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout lorem^0 &&
	shit am -3 rename.patch &&
	test_path_is_missing .shit/rebase-apply &&
	shit update-index --refresh &&
	shit diff --exit-code rename
'

test_expect_success 'am -3 can rename a file after falling back to 3-way merge' '
	grep "^rename from" rename-add.patch &&
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout lorem^0 &&
	shit am -3 rename-add.patch &&
	test_path_is_missing .shit/rebase-apply &&
	shit update-index --refresh &&
	shit diff --exit-code rename
'

test_expect_success 'am -3 -q is quiet' '
	rm -fr .shit/rebase-apply &&
	shit checkout -f lorem2 &&
	shit reset base3way --hard &&
	shit am -3 -q lorem-move.patch >output.out 2>&1 &&
	test_must_be_empty output.out
'

test_expect_success 'am pauses on conflict' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout lorem2^^ &&
	test_must_fail shit am lorem-move.patch &&
	test -d .shit/rebase-apply
'

test_expect_success 'am --show-current-patch' '
	shit am --show-current-patch >actual.patch &&
	test_cmp .shit/rebase-apply/0001 actual.patch
'

test_expect_success 'am --show-current-patch=raw' '
	shit am --show-current-patch=raw >actual.patch &&
	test_cmp .shit/rebase-apply/0001 actual.patch
'

test_expect_success 'am --show-current-patch=diff' '
	shit am --show-current-patch=diff >actual.patch &&
	test_cmp .shit/rebase-apply/patch actual.patch
'

test_expect_success 'am accepts repeated --show-current-patch' '
	shit am --show-current-patch --show-current-patch=raw >actual.patch &&
	test_cmp .shit/rebase-apply/0001 actual.patch
'

test_expect_success 'am detects incompatible --show-current-patch' '
	test_must_fail shit am --show-current-patch=raw --show-current-patch=diff &&
	test_must_fail shit am --show-current-patch --show-current-patch=diff
'

test_expect_success 'am --skip works' '
	echo goodbye >expected &&
	shit am --skip &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code lorem2^^ -- file &&
	test_cmp expected another
'

test_expect_success 'am --abort removes a stray directory' '
	mkdir .shit/rebase-apply &&
	shit am --abort &&
	test_path_is_missing .shit/rebase-apply
'

test_expect_success 'am refuses patches when paused' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout lorem2^^ &&

	test_must_fail shit am lorem-move.patch &&
	test_path_is_dir .shit/rebase-apply &&
	test_cmp_rev lorem2^^ HEAD &&

	test_must_fail shit am <lorem-move.patch &&
	test_path_is_dir .shit/rebase-apply &&
	test_cmp_rev lorem2^^ HEAD
'

test_expect_success 'am --resolved works' '
	echo goodbye >expected &&
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout lorem2^^ &&
	test_must_fail shit am lorem-move.patch &&
	test -d .shit/rebase-apply &&
	echo resolved >>file &&
	shit add file &&
	shit am --resolved &&
	test_path_is_missing .shit/rebase-apply &&
	test_cmp expected another
'

test_expect_success 'am --resolved fails if index has no changes' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout lorem2^^ &&
	test_must_fail shit am lorem-move.patch &&
	test_path_is_dir .shit/rebase-apply &&
	test_cmp_rev lorem2^^ HEAD &&
	test_must_fail shit am --resolved &&
	test_path_is_dir .shit/rebase-apply &&
	test_cmp_rev lorem2^^ HEAD
'

test_expect_success 'am --resolved fails if index has unmerged entries' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout second &&
	test_must_fail shit am -3 lorem-move.patch &&
	test_path_is_dir .shit/rebase-apply &&
	test_cmp_rev second HEAD &&
	test_must_fail shit am --resolved >err &&
	test_path_is_dir .shit/rebase-apply &&
	test_cmp_rev second HEAD &&
	test_grep "still have unmerged paths" err
'

test_expect_success 'am takes patches from a Pine mailbox' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	cat pine patch1 | shit am &&
	test_path_is_missing .shit/rebase-apply &&
	shit diff --exit-code main^..HEAD
'

test_expect_success 'am fails on mail without patch' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	test_must_fail shit am <failmail &&
	shit am --abort &&
	test_path_is_missing .shit/rebase-apply
'

test_expect_success 'am fails on empty patch' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	echo "---" >>failmail &&
	test_must_fail shit am <failmail &&
	shit am --skip &&
	test_path_is_missing .shit/rebase-apply
'

test_expect_success 'am works from stdin in subdirectory' '
	rm -fr subdir &&
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	(
		mkdir -p subdir &&
		cd subdir &&
		shit am <../patch1
	) &&
	shit diff --exit-code second
'

test_expect_success 'am works from file (relative path given) in subdirectory' '
	rm -fr subdir &&
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	(
		mkdir -p subdir &&
		cd subdir &&
		shit am ../patch1
	) &&
	shit diff --exit-code second
'

test_expect_success 'am works from file (absolute path given) in subdirectory' '
	rm -fr subdir &&
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	P=$(pwd) &&
	(
		mkdir -p subdir &&
		cd subdir &&
		shit am "$P/patch1"
	) &&
	shit diff --exit-code second
'

test_expect_success 'am --committer-date-is-author-date' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	test_tick &&
	shit am --committer-date-is-author-date patch1 &&
	shit cat-file commit HEAD | sed -e "/^\$/q" >head1 &&
	sed -ne "/^author /s/.*> //p" head1 >at &&
	sed -ne "/^committer /s/.*> //p" head1 >ct &&
	test_cmp at ct
'

test_expect_success 'am without --committer-date-is-author-date' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	test_tick &&
	shit am patch1 &&
	shit cat-file commit HEAD | sed -e "/^\$/q" >head1 &&
	sed -ne "/^author /s/.*> //p" head1 >at &&
	sed -ne "/^committer /s/.*> //p" head1 >ct &&
	! test_cmp at ct
'

# This checks for +0000 because TZ is set to UTC and that should
# show up when the current time is used. The date in message is set
# by test_tick that uses -0700 timezone; if this feature does not
# work, we will see that instead of +0000.
test_expect_success 'am --ignore-date' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	test_tick &&
	shit am --ignore-date patch1 &&
	shit cat-file commit HEAD | sed -e "/^\$/q" >head1 &&
	sed -ne "/^author /s/.*> //p" head1 >at &&
	grep "+0000" at
'

test_expect_success 'am into an unborn branch' '
	shit rev-parse first^{tree} >expected &&
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	rm -fr subdir &&
	mkdir subdir &&
	shit format-patch --numbered-files -o subdir -1 first &&
	(
		cd subdir &&
		shit init &&
		shit am 1
	) &&
	(
		cd subdir &&
		shit rev-parse HEAD^{tree} >../actual
	) &&
	test_cmp expected actual
'

test_expect_success 'am newline in subject' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	test_tick &&
	sed -e "s/second/second \\\n foo/" patch1 >patchnl &&
	shit am <patchnl >output.out 2>&1 &&
	test_grep "^Applying: second \\\n foo$" output.out
'

test_expect_success 'am -q is quiet' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout first &&
	test_tick &&
	shit am -q <patch1 >output.out 2>&1 &&
	test_must_be_empty output.out
'

test_expect_success 'am empty-file does not infloop' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	touch empty-file &&
	test_tick &&
	test_must_fail shit am empty-file 2>actual &&
	echo Patch format detection failed. >expected &&
	test_cmp expected actual
'

test_expect_success 'am --message-id really adds the message id' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout HEAD^ &&
	shit am --message-id patch1.eml &&
	test_path_is_missing .shit/rebase-apply &&
	shit cat-file commit HEAD | tail -n1 >actual &&
	grep Message-ID patch1.eml >expected &&
	test_cmp expected actual
'

test_expect_success 'am.messageid really adds the message id' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout HEAD^ &&
	test_config am.messageid true &&
	shit am patch1.eml &&
	test_path_is_missing .shit/rebase-apply &&
	shit cat-file commit HEAD | tail -n1 >actual &&
	grep Message-ID patch1.eml >expected &&
	test_cmp expected actual
'

test_expect_success 'am --message-id -s signs off after the message id' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	shit checkout HEAD^ &&
	shit am -s --message-id patch1.eml &&
	test_path_is_missing .shit/rebase-apply &&
	shit cat-file commit HEAD | tail -n2 | head -n1 >actual &&
	grep Message-ID patch1.eml >expected &&
	test_cmp expected actual
'

test_expect_success 'am -3 works with rerere' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&

	# make patches one->two and two->three...
	test_commit one file &&
	test_commit two file &&
	test_commit three file &&
	shit format-patch -2 --stdout >seq.patch &&

	# and create a situation that conflicts...
	shit reset --hard one &&
	test_commit other file &&

	# enable rerere...
	test_config rerere.enabled true &&
	test_when_finished "rm -rf .shit/rr-cache" &&

	# ...and apply. Our resolution is to skip the first
	# patch, and the rerere the second one.
	test_must_fail shit am -3 seq.patch &&
	test_must_fail shit am --skip &&
	echo resolved >file &&
	shit add file &&
	shit am --resolved &&

	# now apply again, and confirm that rerere engaged (we still
	# expect failure from am because rerere does not auto-commit
	# for us).
	shit reset --hard other &&
	test_must_fail shit am -3 seq.patch &&
	test_must_fail shit am --skip &&
	echo resolved >expect &&
	test_cmp expect file
'

test_expect_success 'am -s unexpected trailer block' '
	rm -fr .shit/rebase-apply &&
	shit reset --hard &&
	echo signed >file &&
	shit add file &&
	cat >msg <<-EOF &&
	subject here

	Signed-off-by: $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL>
	[jc: tweaked log message]
	Signed-off-by: J C H <j@c.h>
	EOF
	shit commit -F msg &&
	shit cat-file commit HEAD | sed -e "1,/^$/d" >original &&
	shit format-patch --stdout -1 >patch &&

	shit reset --hard HEAD^ &&
	shit am -s patch &&
	(
		cat original &&
		echo "Signed-off-by: $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL>"
	) >expect &&
	shit cat-file commit HEAD | sed -e "1,/^$/d" >actual &&
	test_cmp expect actual &&

	cat >msg <<-\EOF &&
	subject here

	We make sure that there is a blank line between the log
	message proper and Signed-off-by: line added.
	EOF
	shit reset HEAD^ &&
	shit commit -F msg file &&
	shit cat-file commit HEAD | sed -e "1,/^$/d" >original &&
	shit format-patch --stdout -1 >patch &&

	shit reset --hard HEAD^ &&
	shit am -s patch &&

	(
		cat original &&
		echo &&
		echo "Signed-off-by: $shit_COMMITTER_NAME <$shit_COMMITTER_EMAIL>"
	) >expect &&
	shit cat-file commit HEAD | sed -e "1,/^$/d" >actual &&
	test_cmp expect actual
'

test_expect_success 'am --patch-format=mboxrd handles mboxrd' '
	rm -fr .shit/rebase-apply &&
	shit checkout -f first &&
	echo mboxrd >>file &&
	shit add file &&
	cat >msg <<-\INPUT_END &&
	mboxrd should escape the body

	From could trip up a loose mbox parser
	>From extra escape for reversibility
	INPUT_END
	shit commit -F msg &&
	shit -c format.mboxrd format-patch --stdout -1 >mboxrd1 &&
	grep "^>From could trip up a loose mbox parser" mboxrd1 &&
	shit checkout -f first &&
	shit am --patch-format=mboxrd mboxrd1 &&
	shit cat-file commit HEAD | tail -n4 >out &&
	test_cmp msg out
'

test_expect_success 'am works with multi-line in-body headers' '
	FORTY="String that has a length of more than forty characters" &&
	LONG="$FORTY $FORTY" &&
	rm -fr .shit/rebase-apply &&
	shit checkout -f first &&
	echo one >> file &&
	shit commit -am "$LONG

    Body test" --author="$LONG <long@example.com>" &&
	shit format-patch --stdout -1 >patch &&
	# bump from, date, and subject down to in-body header
	perl -lpe "
		if (/^From:/) {
			print \"From: x <x\@example.com>\";
			print \"Date: Sat, 1 Jan 2000 00:00:00 +0000\";
			print \"Subject: x\n\";
		}
	" patch >msg &&
	shit checkout HEAD^ &&
	shit am msg &&
	# Ensure that the author and full message are present
	shit cat-file commit HEAD | grep "^author.*long@example.com" &&
	shit cat-file commit HEAD | grep "^$LONG$"
'

test_expect_success 'am --quit keeps HEAD where it is' '
	mkdir .shit/rebase-apply &&
	>.shit/rebase-apply/last &&
	>.shit/rebase-apply/next &&
	shit rev-parse HEAD^ >.shit/ORIG_HEAD &&
	shit rev-parse HEAD >expected &&
	shit am --quit &&
	test_path_is_missing .shit/rebase-apply &&
	shit rev-parse HEAD >actual &&
	test_cmp expected actual
'

test_expect_success 'am and .shitattibutes' '
	test_create_repo attributes &&
	(
		cd attributes &&
		test_commit init &&
		shit config filter.test.clean "sed -e '\''s/smudged/clean/g'\''" &&
		shit config filter.test.smudge "sed -e '\''s/clean/smudged/g'\''" &&

		test_commit second &&
		shit checkout -b test HEAD^ &&

		echo "*.txt filter=test conflict-marker-size=10" >.shitattributes &&
		shit add .shitattributes &&
		test_commit third &&

		echo "This text is smudged." >a.txt &&
		shit add a.txt &&
		test_commit fourth &&

		shit checkout -b removal HEAD^ &&
		shit rm .shitattributes &&
		shit add -u &&
		test_commit fifth &&
		shit cherry-pick test &&

		shit checkout -b conflict third &&
		echo "This text is different." >a.txt &&
		shit add a.txt &&
		test_commit sixth &&

		shit checkout test &&
		shit format-patch --stdout main..HEAD >patches &&
		shit reset --hard main &&
		shit am patches &&
		grep "smudged" a.txt &&

		shit checkout removal &&
		shit reset --hard &&
		shit format-patch --stdout main..HEAD >patches &&
		shit reset --hard main &&
		shit am patches &&
		grep "clean" a.txt &&

		shit checkout conflict &&
		shit reset --hard &&
		shit format-patch --stdout main..HEAD >patches &&
		shit reset --hard fourth &&
		test_must_fail shit am -3 patches &&
		grep "<<<<<<<<<<" a.txt
	)
'

test_expect_success 'apply binary blob in partial clone' '
	printf "\\000" >binary &&
	shit add binary &&
	shit commit -m "binary blob" &&
	shit format-patch --stdout -m HEAD^ >patch &&

	test_create_repo server &&
	test_config -C server uploadpack.allowfilter 1 &&
	test_config -C server uploadpack.allowanysha1inwant 1 &&
	shit clone --filter=blob:none "file://$(pwd)/server" client &&
	test_when_finished "rm -rf client" &&

	# Exercise to make sure that it works
	shit -C client am ../patch
'

test_expect_success 'an empty input file is error regardless of --empty option' '
	test_when_finished "shit am --abort || :" &&
	test_must_fail shit am --empty=drop empty.patch 2>actual &&
	echo "Patch format detection failed." >expected &&
	test_cmp expected actual
'

test_expect_success 'invalid when passing the --empty option alone' '
	test_when_finished "shit am --abort || :" &&
	shit checkout empty-commit^ &&
	test_must_fail shit am --empty empty-commit.patch 2>err &&
	echo "error: invalid value for '\''--empty'\'': '\''empty-commit.patch'\''" >expected &&
	test_cmp expected err
'

test_expect_success 'a message without a patch is an error (default)' '
	test_when_finished "shit am --abort || :" &&
	test_must_fail shit am empty-commit.patch >err &&
	grep "Patch is empty" err
'

test_expect_success 'a message without a patch is an error where an explicit "--empty=stop" is given' '
	test_when_finished "shit am --abort || :" &&
	test_must_fail shit am --empty=stop empty-commit.patch >err &&
	grep "Patch is empty." err
'

test_expect_success 'a message without a patch will be skipped when "--empty=drop" is given' '
	shit am --empty=drop empty-commit.patch >output &&
	shit rev-parse empty-commit^ >expected &&
	shit rev-parse HEAD >actual &&
	test_cmp expected actual &&
	grep "Skipping: empty commit" output
'

test_expect_success 'record as an empty commit when meeting e-mail message that lacks a patch' '
	shit am --empty=keep empty-commit.patch >output &&
	test_path_is_missing .shit/rebase-apply &&
	shit show empty-commit --format="%B" >expected &&
	shit show HEAD --format="%B" >actual &&
	grep -f actual expected &&
	grep "Creating an empty commit: empty commit" output
'

test_expect_success 'skip an empty patch in the middle of an am session' '
	shit checkout empty-commit^ &&
	test_must_fail shit am empty-commit.patch >out 2>err &&
	grep "Patch is empty." out &&
	grep "To record the empty patch as an empty commit, run \"shit am --allow-empty\"." err &&
	shit am --skip &&
	test_path_is_missing .shit/rebase-apply &&
	shit rev-parse empty-commit^ >expected &&
	shit rev-parse HEAD >actual &&
	test_cmp expected actual
'

test_expect_success 'record an empty patch as an empty commit in the middle of an am session' '
	shit checkout empty-commit^ &&
	test_must_fail shit am empty-commit.patch >out 2>err &&
	grep "Patch is empty." out &&
	grep "To record the empty patch as an empty commit, run \"shit am --allow-empty\"." err &&
	shit am --allow-empty >output &&
	grep "No changes - recorded it as an empty commit." output &&
	test_path_is_missing .shit/rebase-apply &&
	shit show empty-commit --format="%B" >expected &&
	shit show HEAD --format="%B" >actual &&
	grep -f actual expected
'

test_expect_success 'create an non-empty commit when the index IS changed though "--allow-empty" is given' '
	shit checkout empty-commit^ &&
	test_must_fail shit am empty-commit.patch >err &&
	: >empty-file &&
	shit add empty-file &&
	shit am --allow-empty &&
	shit show empty-commit --format="%B" >expected &&
	shit show HEAD --format="%B" >actual &&
	grep -f actual expected &&
	shit diff HEAD^..HEAD --name-only
'

test_expect_success 'cannot create empty commits when there is a clean index due to merge conflicts' '
	test_when_finished "shit am --abort || :" &&
	shit rev-parse HEAD >expected &&
	test_must_fail shit am seq.patch &&
	test_must_fail shit am --allow-empty >err &&
	! grep "To record the empty patch as an empty commit, run \"shit am --allow-empty\"." err &&
	shit rev-parse HEAD >actual &&
	test_cmp actual expected
'

test_expect_success 'cannot create empty commits when there is unmerged index due to merge conflicts' '
	test_when_finished "shit am --abort || :" &&
	shit rev-parse HEAD >expected &&
	test_must_fail shit am -3 seq.patch &&
	test_must_fail shit am --allow-empty >err &&
	! grep "To record the empty patch as an empty commit, run \"shit am --allow-empty\"." err &&
	shit rev-parse HEAD >actual &&
	test_cmp actual expected
'

test_done
