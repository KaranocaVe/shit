#!/bin/sh

test_description='CRLF conversion'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

has_cr() {
	tr '\015' Q <"$1" | grep Q >/dev/null
}

test_expect_success setup '

	shit config core.autocrlf false &&

	echo "one text" > .shitattributes &&

	test_write_lines Hello world how are you >one &&
	test_write_lines I am very very fine thank you >two &&
	shit add . &&

	shit commit -m initial &&

	one=$(shit rev-parse HEAD:one) &&
	two=$(shit rev-parse HEAD:two) &&

	echo happy.
'

test_expect_success 'eol=lf puts LFs in normalized file' '

	rm -f .shitattributes tmp one two &&
	shit config core.eol lf &&
	shit read-tree --reset -u HEAD &&

	! has_cr one &&
	! has_cr two &&
	onediff=$(shit diff one) &&
	twodiff=$(shit diff two) &&
	test -z "$onediff" && test -z "$twodiff"
'

test_expect_success 'eol=crlf puts CRLFs in normalized file' '

	rm -f .shitattributes tmp one two &&
	shit config core.eol crlf &&
	shit read-tree --reset -u HEAD &&

	has_cr one &&
	! has_cr two &&
	onediff=$(shit diff one) &&
	twodiff=$(shit diff two) &&
	test -z "$onediff" && test -z "$twodiff"
'

test_expect_success 'autocrlf=true overrides eol=lf' '

	rm -f .shitattributes tmp one two &&
	shit config core.eol lf &&
	shit config core.autocrlf true &&
	shit read-tree --reset -u HEAD &&

	has_cr one &&
	has_cr two &&
	onediff=$(shit diff one) &&
	twodiff=$(shit diff two) &&
	test -z "$onediff" && test -z "$twodiff"
'

test_expect_success 'autocrlf=true overrides unset eol' '

	rm -f .shitattributes tmp one two &&
	shit config --unset-all core.eol &&
	shit config core.autocrlf true &&
	shit read-tree --reset -u HEAD &&

	has_cr one &&
	has_cr two &&
	onediff=$(shit diff one) &&
	twodiff=$(shit diff two) &&
	test -z "$onediff" && test -z "$twodiff"
'

test_expect_success NATIVE_CRLF 'eol native is crlf' '

	rm -rf native_eol && mkdir native_eol &&
	(
		cd native_eol &&
		printf "*.txt text\n" >.shitattributes &&
		printf "one\r\ntwo\r\nthree\r\n" >filedos.txt &&
		printf "one\ntwo\nthree\n" >fileunix.txt &&
		shit init &&
		shit config core.autocrlf false &&
		shit config core.eol native &&
		shit add filedos.txt fileunix.txt &&
		shit commit -m "first" &&
		rm file*.txt &&
		shit reset --hard HEAD &&
		has_cr filedos.txt &&
		has_cr fileunix.txt
	)
'

test_done
