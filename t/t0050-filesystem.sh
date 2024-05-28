#!/bin/sh

test_description='Various filesystem issues'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

auml=$(printf '\303\244')
aumlcdiar=$(printf '\141\314\210')

if test_have_prereq CASE_INSENSITIVE_FS
then
	say "will test on a case insensitive filesystem"
	test_case=test_expect_failure
else
	test_case=test_expect_success
fi

if test_have_prereq UTF8_NFD_TO_NFC
then
	say "will test on a unicode corrupting filesystem"
	test_unicode=test_expect_failure
else
	test_unicode=test_expect_success
fi

test_have_prereq SYMLINKS ||
	say "will test on a filesystem lacking symbolic links"

if test_have_prereq CASE_INSENSITIVE_FS
then
test_expect_success "detection of case insensitive filesystem during repo init" '
	test $(shit config --bool core.ignorecase) = true
'
else
test_expect_success "detection of case insensitive filesystem during repo init" '
	{
		test_must_fail shit config --bool core.ignorecase >/dev/null ||
			test $(shit config --bool core.ignorecase) = false
	}
'
fi

if test_have_prereq SYMLINKS
then
test_expect_success "detection of filesystem w/o symlink support during repo init" '
	{
		test_must_fail shit config --bool core.symlinks ||
		test "$(shit config --bool core.symlinks)" = true
	}
'
else
test_expect_success "detection of filesystem w/o symlink support during repo init" '
	v=$(shit config --bool core.symlinks) &&
	test "$v" = false
'
fi

test_expect_success "setup case tests" '
	shit config core.ignorecase true &&
	touch camelcase &&
	shit add camelcase &&
	shit commit -m "initial" &&
	shit tag initial &&
	shit checkout -b topic &&
	shit mv camelcase tmp &&
	shit mv tmp CamelCase &&
	shit commit -m "rename" &&
	shit checkout -f main
'

test_expect_success 'rename (case change)' '
	shit mv camelcase CamelCase &&
	shit commit -m "rename"
'

test_expect_success 'merge (case change)' '
	rm -f CamelCase &&
	rm -f camelcase &&
	shit reset --hard initial &&
	shit merge topic
'

test_expect_success CASE_INSENSITIVE_FS 'add directory (with different case)' '
	shit reset --hard initial &&
	mkdir -p dir1/dir2 &&
	echo >dir1/dir2/a &&
	echo >dir1/dir2/b &&
	shit add dir1/dir2/a &&
	shit add dir1/DIR2/b &&
	shit ls-files >actual &&
	cat >expected <<-\EOF &&
		camelcase
		dir1/dir2/a
		dir1/dir2/b
	EOF
	test_cmp expected actual
'

test_expect_failure CASE_INSENSITIVE_FS 'add (with different case)' '
	shit reset --hard initial &&
	rm camelcase &&
	echo 1 >CamelCase &&
	shit add CamelCase &&
	shit ls-files >tmp &&
	camel=$(grep -i camelcase tmp) &&
	test $(echo "$camel" | wc -l) = 1 &&
	test "z$(shit cat-file blob :$camel)" = z1
'

test_expect_success "setup unicode normalization tests" '
	test_create_repo unicode &&
	cd unicode &&
	shit config core.precomposeunicode false &&
	touch "$aumlcdiar" &&
	shit add "$aumlcdiar" &&
	shit commit -m initial &&
	shit tag initial &&
	shit checkout -b topic &&
	shit mv $aumlcdiar tmp &&
	shit mv tmp "$auml" &&
	shit commit -m rename &&
	shit checkout -f main
'

$test_unicode 'rename (silent unicode normalization)' '
	shit mv "$aumlcdiar" "$auml" &&
	shit commit -m rename
'

$test_unicode 'merge (silent unicode normalization)' '
	shit reset --hard initial &&
	shit merge topic
'

test_expect_success CASE_INSENSITIVE_FS 'checkout with no pathspec and a case insensitive fs' '
	shit init repo &&
	(
		cd repo &&

		>shitweb &&
		shit add shitweb &&
		shit commit -m "add shitweb" &&

		shit checkout --orphan todo &&
		shit reset --hard &&
		mkdir -p shitweb/subdir &&
		>shitweb/subdir/file &&
		shit add shitweb &&
		shit commit -m "add shitweb/subdir/file" &&

		shit checkout main
	)
'

test_done
