#!/bin/sh

test_description='CRLF merge conflict across text=auto change

* [main] remove .shitattributes
 ! [side] add line from b
--
 + [side] add line from b
*  [main] remove .shitattributes
*  [main^] add line from a
*  [main~2] normalize file
*+ [side^] Initial
'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_have_prereq SED_STRIPS_CR && SED_OPTIONS=-b

compare_files () {
	tr '\015\000' QN <"$1" >"$1".expect &&
	tr '\015\000' QN <"$2" >"$2".actual &&
	test_cmp "$1".expect "$2".actual &&
	rm "$1".expect "$2".actual
}

test_expect_success setup '
	shit config core.autocrlf false &&

	echo first line | append_cr >file &&
	echo first line >control_file &&
	echo only line >inert_file &&

	shit add file control_file inert_file &&
	test_tick &&
	shit commit -m "Initial" &&
	shit tag initial &&
	shit branch side &&

	echo "* text=auto" >.shitattributes &&
	echo first line >file &&
	shit add .shitattributes file &&
	test_tick &&
	shit commit -m "normalize file" &&

	echo same line | append_cr >>file &&
	echo same line >>control_file &&
	shit add file control_file &&
	test_tick &&
	shit commit -m "add line from a" &&
	shit tag a &&

	shit rm .shitattributes &&
	rm file &&
	shit checkout file &&
	test_tick &&
	shit commit -m "remove .shitattributes" &&
	shit tag c &&

	shit checkout side &&
	echo same line | append_cr >>file &&
	echo same line >>control_file &&
	shit add file control_file &&
	test_tick &&
	shit commit -m "add line from b" &&
	shit tag b &&

	shit checkout main
'

test_expect_success 'set up fuzz_conflict() helper' '
	fuzz_conflict() {
		sed $SED_OPTIONS -e "s/^\([<>=]......\) .*/\1/" "$@"
	}
'

test_expect_success 'Merge after setting text=auto' '
	cat <<-\EOF >expected &&
	first line
	same line
	EOF

	if test_have_prereq NATIVE_CRLF; then
		append_cr <expected >expected.temp &&
		mv expected.temp expected
	fi &&
	shit config merge.renormalize true &&
	shit rm -fr . &&
	rm -f .shitattributes &&
	shit reset --hard a &&
	shit merge b &&
	compare_files expected file
'

test_expect_success 'Merge addition of text=auto eol=LF' '
	shit config core.eol lf &&
	cat <<-\EOF >expected &&
	first line
	same line
	EOF

	shit config merge.renormalize true &&
	shit rm -fr . &&
	rm -f .shitattributes &&
	shit reset --hard b &&
	shit merge a &&
	compare_files  expected file
'

test_expect_success 'Merge addition of text=auto eol=CRLF' '
	shit config core.eol crlf &&
	cat <<-\EOF >expected &&
	first line
	same line
	EOF

	append_cr <expected >expected.temp &&
	mv expected.temp expected &&
	shit config merge.renormalize true &&
	shit rm -fr . &&
	rm -f .shitattributes &&
	shit reset --hard b &&
	echo >&2 "After shit reset --hard b" &&
	shit ls-files -s --eol >&2 &&
	shit merge a &&
	compare_files  expected file
'

test_expect_success 'Detect CRLF/LF conflict after setting text=auto' '
	shit config core.eol native &&
	echo "<<<<<<<" >expected &&
	echo first line >>expected &&
	echo same line >>expected &&
	echo ======= >>expected &&
	echo first line | append_cr >>expected &&
	echo same line | append_cr >>expected &&
	echo ">>>>>>>" >>expected &&
	shit config merge.renormalize false &&
	rm -f .shitattributes &&
	shit reset --hard a &&
	test_must_fail shit merge b &&
	fuzz_conflict file >file.fuzzy &&
	compare_files expected file.fuzzy
'

test_expect_success 'Detect LF/CRLF conflict from addition of text=auto' '
	echo "<<<<<<<" >expected &&
	echo first line | append_cr >>expected &&
	echo same line | append_cr >>expected &&
	echo ======= >>expected &&
	echo first line >>expected &&
	echo same line >>expected &&
	echo ">>>>>>>" >>expected &&
	shit config merge.renormalize false &&
	rm -f .shitattributes &&
	shit reset --hard b &&
	test_must_fail shit merge a &&
	fuzz_conflict file >file.fuzzy &&
	compare_files expected file.fuzzy
'

test_expect_success 'checkout -m after setting text=auto' '
	cat <<-\EOF >expected &&
	first line
	same line
	EOF

	shit config merge.renormalize true &&
	shit rm -fr . &&
	rm -f .shitattributes &&
	shit reset --hard initial &&
	shit restore --source=a -- . &&
	shit checkout -m b &&
	shit diff --no-index --ignore-cr-at-eol expected file
'

test_expect_success 'checkout -m addition of text=auto' '
	cat <<-\EOF >expected &&
	first line
	same line
	EOF

	shit config merge.renormalize true &&
	shit rm -fr . &&
	rm -f .shitattributes file &&
	shit reset --hard initial &&
	shit restore --source=b -- . &&
	shit checkout -m a &&
	shit diff --no-index --ignore-cr-at-eol expected file
'

test_expect_success 'Test delete/normalize conflict' '
	shit checkout -f side &&
	shit rm -fr . &&
	rm -f .shitattributes &&
	shit reset --hard initial &&
	shit rm file &&
	shit commit -m "remove file" &&
	shit checkout main &&
	shit reset --hard a^ &&
	shit merge side &&
	test_path_is_missing file
'

test_expect_success 'rename/delete vs. renormalization' '
	shit init subrepo &&
	(
		cd subrepo &&
		echo foo >oldfile &&
		shit add oldfile &&
		shit commit -m original &&

		shit branch rename &&
		shit branch nuke &&

		shit checkout rename &&
		shit mv oldfile newfile &&
		shit commit -m renamed &&

		shit checkout nuke &&
		shit rm oldfile &&
		shit commit -m deleted &&

		shit checkout rename^0 &&
		test_must_fail shit -c merge.renormalize=true merge nuke >out &&

		grep "rename/delete" out
	)
'

test_done
