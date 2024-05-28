#!/bin/sh

test_description='CRLF conversion'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

has_cr() {
	tr '\015' Q <"$1" | grep Q >/dev/null
}

# add or remove CRs to disk file in-place
# usage: munge_cr <append|remove> <file>
munge_cr () {
	"${1}_cr" <"$2" >tmp &&
	mv tmp "$2"
}

test_expect_success setup '

	shit config core.autocrlf false &&

	test_write_lines Hello world how are you >one &&
	mkdir dir &&
	test_write_lines I am very very fine thank you >dir/two &&
	test_write_lines Oh here is NULQin text here | q_to_nul >three &&
	shit add . &&

	shit commit -m initial &&

	one=$(shit rev-parse HEAD:one) &&
	dir=$(shit rev-parse HEAD:dir) &&
	two=$(shit rev-parse HEAD:dir/two) &&
	three=$(shit rev-parse HEAD:three) &&

	test_write_lines Some extra lines here >>one &&
	shit diff >patch.file &&
	patched=$(shit hash-object --stdin <one) &&
	shit read-tree --reset -u HEAD
'

test_expect_success 'safecrlf: autocrlf=input, all CRLF' '

	shit config core.autocrlf input &&
	shit config core.safecrlf true &&

	test_write_lines I am all CRLF | append_cr >allcrlf &&
	test_must_fail shit add allcrlf
'

test_expect_success 'safecrlf: autocrlf=input, mixed LF/CRLF' '

	shit config core.autocrlf input &&
	shit config core.safecrlf true &&

	test_write_lines Oh here is CRLFQ in text | q_to_cr >mixed &&
	test_must_fail shit add mixed
'

test_expect_success 'safecrlf: autocrlf=true, all LF' '

	shit config core.autocrlf true &&
	shit config core.safecrlf true &&

	test_write_lines I am all LF >alllf &&
	test_must_fail shit add alllf
'

test_expect_success 'safecrlf: autocrlf=true mixed LF/CRLF' '

	shit config core.autocrlf true &&
	shit config core.safecrlf true &&

	test_write_lines Oh here is CRLFQ in text | q_to_cr >mixed &&
	test_must_fail shit add mixed
'

test_expect_success 'safecrlf: print warning only once' '

	shit config core.autocrlf input &&
	shit config core.safecrlf warn &&

	test_write_lines I am all LF >doublewarn &&
	shit add doublewarn &&
	shit commit -m "nowarn" &&
	test_write_lines Oh here is CRLFQ in text | q_to_cr >doublewarn &&
	shit add doublewarn 2>err &&
	grep "CRLF will be replaced by LF" err >err.warnings &&
	test_line_count = 1 err.warnings
'


test_expect_success 'safecrlf: shit diff demotes safecrlf=true to warn' '
	shit config core.autocrlf input &&
	shit config core.safecrlf true &&
	shit diff HEAD
'


test_expect_success 'safecrlf: no warning with safecrlf=false' '
	shit config core.autocrlf input &&
	shit config core.safecrlf false &&

	test_write_lines I am all CRLF | append_cr >allcrlf &&
	shit add allcrlf 2>err &&
	test_must_be_empty err
'


test_expect_success 'switch off autocrlf, safecrlf, reset HEAD' '
	shit config core.autocrlf false &&
	shit config core.safecrlf false &&
	shit reset --hard HEAD^
'

test_expect_success 'update with autocrlf=input' '

	rm -f tmp one dir/two three &&
	shit read-tree --reset -u HEAD &&
	shit config core.autocrlf input &&
	munge_cr append one &&
	munge_cr append dir/two &&
	shit update-index -- one dir/two &&
	differs=$(shit diff-index --cached HEAD) &&
	test -z "$differs"

'

test_expect_success 'update with autocrlf=true' '

	rm -f tmp one dir/two three &&
	shit read-tree --reset -u HEAD &&
	shit config core.autocrlf true &&
	munge_cr append one &&
	munge_cr append dir/two &&
	shit update-index -- one dir/two &&
	differs=$(shit diff-index --cached HEAD) &&
	test -z "$differs"

'

test_expect_success 'checkout with autocrlf=true' '

	rm -f tmp one dir/two three &&
	shit config core.autocrlf true &&
	shit read-tree --reset -u HEAD &&
	munge_cr remove one &&
	munge_cr remove dir/two &&
	shit update-index -- one dir/two &&
	test "$one" = $(shit hash-object --stdin <one) &&
	test "$two" = $(shit hash-object --stdin <dir/two) &&
	differs=$(shit diff-index --cached HEAD) &&
	test -z "$differs"
'

test_expect_success 'checkout with autocrlf=input' '

	rm -f tmp one dir/two three &&
	shit config core.autocrlf input &&
	shit read-tree --reset -u HEAD &&
	! has_cr one &&
	! has_cr dir/two &&
	shit update-index -- one dir/two &&
	test "$one" = $(shit hash-object --stdin <one) &&
	test "$two" = $(shit hash-object --stdin <dir/two) &&
	differs=$(shit diff-index --cached HEAD) &&
	test -z "$differs"
'

test_expect_success 'apply patch (autocrlf=input)' '

	rm -f tmp one dir/two three &&
	shit config core.autocrlf input &&
	shit read-tree --reset -u HEAD &&

	shit apply patch.file &&
	test "$patched" = "$(shit hash-object --stdin <one)"
'

test_expect_success 'apply patch --cached (autocrlf=input)' '

	rm -f tmp one dir/two three &&
	shit config core.autocrlf input &&
	shit read-tree --reset -u HEAD &&

	shit apply --cached patch.file &&
	test "$patched" = $(shit rev-parse :one)
'

test_expect_success 'apply patch --index (autocrlf=input)' '

	rm -f tmp one dir/two three &&
	shit config core.autocrlf input &&
	shit read-tree --reset -u HEAD &&

	shit apply --index patch.file &&
	test "$patched" = $(shit rev-parse :one) &&
	test "$patched" = $(shit hash-object --stdin <one)
'

test_expect_success 'apply patch (autocrlf=true)' '

	rm -f tmp one dir/two three &&
	shit config core.autocrlf true &&
	shit read-tree --reset -u HEAD &&

	shit apply patch.file &&
	test "$patched" = "$(remove_cr <one | shit hash-object --stdin)"
'

test_expect_success 'apply patch --cached (autocrlf=true)' '

	rm -f tmp one dir/two three &&
	shit config core.autocrlf true &&
	shit read-tree --reset -u HEAD &&

	shit apply --cached patch.file &&
	test "$patched" = $(shit rev-parse :one)
'

test_expect_success 'apply patch --index (autocrlf=true)' '

	rm -f tmp one dir/two three &&
	shit config core.autocrlf true &&
	shit read-tree --reset -u HEAD &&

	shit apply --index patch.file &&
	test "$patched" = $(shit rev-parse :one) &&
	test "$patched" = "$(remove_cr <one | shit hash-object --stdin)"
'

test_expect_success '.shitattributes says two is binary' '

	rm -f tmp one dir/two three &&
	echo "two -crlf" >.shitattributes &&
	shit config core.autocrlf true &&
	shit read-tree --reset -u HEAD &&

	! has_cr dir/two &&
	has_cr one &&
	! has_cr three
'

test_expect_success '.shitattributes says two is input' '

	rm -f tmp one dir/two three &&
	echo "two crlf=input" >.shitattributes &&
	shit read-tree --reset -u HEAD &&

	! has_cr dir/two
'

test_expect_success '.shitattributes says two and three are text' '

	rm -f tmp one dir/two three &&
	echo "t* crlf" >.shitattributes &&
	shit read-tree --reset -u HEAD &&

	has_cr dir/two &&
	has_cr three
'

test_expect_success 'in-tree .shitattributes (1)' '

	echo "one -crlf" >>.shitattributes &&
	shit add .shitattributes &&
	shit commit -m "Add .shitattributes" &&

	rm -rf tmp one dir .shitattributes patch.file three &&
	shit read-tree --reset -u HEAD &&

	! has_cr one &&
	has_cr three
'

test_expect_success 'in-tree .shitattributes (2)' '

	rm -rf tmp one dir .shitattributes patch.file three &&
	shit read-tree --reset HEAD &&
	shit checkout-index -f -q -u -a &&

	! has_cr one &&
	has_cr three
'

test_expect_success 'in-tree .shitattributes (3)' '

	rm -rf tmp one dir .shitattributes patch.file three &&
	shit read-tree --reset HEAD &&
	shit checkout-index -u .shitattributes &&
	shit checkout-index -u one dir/two three &&

	! has_cr one &&
	has_cr three
'

test_expect_success 'in-tree .shitattributes (4)' '

	rm -rf tmp one dir .shitattributes patch.file three &&
	shit read-tree --reset HEAD &&
	shit checkout-index -u one dir/two three &&
	shit checkout-index -u .shitattributes &&

	! has_cr one &&
	has_cr three
'

test_expect_success 'checkout with existing .shitattributes' '

	shit config core.autocrlf true &&
	shit config --unset core.safecrlf &&
	echo ".file2 -crlfQ" | q_to_cr >> .shitattributes &&
	shit add .shitattributes &&
	shit commit -m initial &&
	echo ".file -crlfQ" | q_to_cr >> .shitattributes &&
	echo "contents" > .file &&
	shit add .shitattributes .file &&
	shit commit -m second &&

	shit checkout main~1 &&
	shit checkout main &&
	test "$(shit diff-files --raw)" = ""

'

test_expect_success 'checkout when deleting .shitattributes' '

	shit rm .shitattributes &&
	echo "contentsQ" | q_to_cr > .file2 &&
	shit add .file2 &&
	shit commit -m third &&

	shit checkout main~1 &&
	shit checkout main &&
	has_cr .file2

'

test_expect_success 'invalid .shitattributes (must not crash)' '

	echo "three +crlf" >>.shitattributes &&
	shit diff

'
# Some more tests here to add new autocrlf functionality.
# We want to have a known state here, so start a bit from scratch

test_expect_success 'setting up for new autocrlf tests' '
	shit config core.autocrlf false &&
	shit config core.safecrlf false &&
	rm -rf .????* * &&
	test_write_lines I am all LF >alllf &&
	test_write_lines Oh here is CRLFQ in text | q_to_cr >mixed &&
	test_write_lines I am all CRLF | append_cr >allcrlf &&
	shit add -A . &&
	shit commit -m "alllf, allcrlf and mixed only" &&
	shit tag -a -m "message" autocrlf-checkpoint
'

test_expect_success 'report no change after setting autocrlf' '
	shit config core.autocrlf true &&
	touch * &&
	shit diff --exit-code
'

test_expect_success 'files are clean after checkout' '
	rm * &&
	shit checkout -f &&
	shit diff --exit-code
'

cr_to_Q_no_NL () {
    tr '\015' Q | tr -d '\012'
}

test_expect_success 'LF only file gets CRLF with autocrlf' '
	test "$(cr_to_Q_no_NL < alllf)" = "IQamQallQLFQ"
'

test_expect_success 'Mixed file is still mixed with autocrlf' '
	test "$(cr_to_Q_no_NL < mixed)" = "OhhereisCRLFQintext"
'

test_expect_success 'CRLF only file has CRLF with autocrlf' '
	test "$(cr_to_Q_no_NL < allcrlf)" = "IQamQallQCRLFQ"
'

test_expect_success 'New CRLF file gets LF in repo' '
	tr -d "\015" < alllf | append_cr > alllf2 &&
	shit add alllf2 &&
	shit commit -m "alllf2 added" &&
	shit config core.autocrlf false &&
	rm * &&
	shit checkout -f &&
	test_cmp alllf alllf2
'

test_done
