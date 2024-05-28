#!/bin/sh
#
# Copyright (c) 2012 Torsten Bögershausen
#

test_description='utf-8 decomposed (nfd) converted to precomposed (nfc)'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

if ! test_have_prereq UTF8_NFD_TO_NFC
then
	skip_all="filesystem does not corrupt utf-8"
	test_done
fi

# create utf-8 variables
Adiarnfc=$(printf '\303\204')
Adiarnfd=$(printf 'A\314\210')

Odiarnfc=$(printf '\303\226')
Odiarnfd=$(printf 'O\314\210')
AEligatu=$(printf '\303\206')
Invalidu=$(printf '\303\377')


#Create a string with 255 bytes (decomposed)
Alongd=$Adiarnfd$Adiarnfd$Adiarnfd$Adiarnfd$Adiarnfd$Adiarnfd$Adiarnfd #21 Byte
Alongd=$Alongd$Alongd$Alongd                                           #63 Byte
Alongd=$Alongd$Alongd$Alongd$Alongd$Adiarnfd                           #255 Byte

#Create a string with 254 bytes (precomposed)
Alongc=$AEligatu$AEligatu$AEligatu$AEligatu$AEligatu #10 Byte
Alongc=$Alongc$Alongc$Alongc$Alongc$Alongc           #50 Byte
Alongc=$Alongc$Alongc$Alongc$Alongc$Alongc           #250 Byte
Alongc=$Alongc$AEligatu$AEligatu                     #254 Byte

test_expect_success "detect if nfd needed" '
	precomposeunicode=$(shit config core.precomposeunicode) &&
	test "$precomposeunicode" = true &&
	shit config core.precomposeunicode true
'
test_expect_success "setup" '
	>x &&
	shit add x &&
	shit commit -m "1st commit" &&
	shit rm x &&
	shit commit -m "rm x"
'
test_expect_success "setup case mac" '
	shit checkout -b mac_os
'
# This will test nfd2nfc in shit diff
test_expect_success "shit diff f.Adiar" '
	touch f.$Adiarnfc &&
	shit add f.$Adiarnfc &&
	echo f.Adiarnfc >f.$Adiarnfc &&
	shit diff f.$Adiarnfd >expect &&
	shit diff f.$Adiarnfc >actual &&
	test_cmp expect actual &&
	shit reset HEAD f.Adiarnfc &&
	rm f.$Adiarnfc expect actual
'
# This will test nfd2nfc in shit diff-files
test_expect_success "shit diff-files f.Adiar" '
	touch f.$Adiarnfc &&
	shit add f.$Adiarnfc &&
	echo f.Adiarnfc >f.$Adiarnfc &&
	shit diff-files f.$Adiarnfd >expect &&
	shit diff-files f.$Adiarnfc >actual &&
	test_cmp expect actual &&
	shit reset HEAD f.Adiarnfc &&
	rm f.$Adiarnfc expect actual
'
# This will test nfd2nfc in shit diff-index
test_expect_success "shit diff-index f.Adiar" '
	touch f.$Adiarnfc &&
	shit add f.$Adiarnfc &&
	echo f.Adiarnfc >f.$Adiarnfc &&
	shit diff-index HEAD f.$Adiarnfd >expect &&
	shit diff-index HEAD f.$Adiarnfc >actual &&
	test_cmp expect actual &&
	shit reset HEAD f.Adiarnfc &&
	rm f.$Adiarnfc expect actual
'
# This will test nfd2nfc in readdir()
test_expect_success "add file Adiarnfc" '
	echo f.Adiarnfc >f.$Adiarnfc &&
	shit add f.$Adiarnfc &&
	shit commit -m "add f.$Adiarnfc"
'
# This will test nfd2nfc in shit diff-tree
test_expect_success "shit diff-tree f.Adiar" '
	echo f.Adiarnfc >>f.$Adiarnfc &&
	shit diff-tree HEAD f.$Adiarnfd >expect &&
	shit diff-tree HEAD f.$Adiarnfc >actual &&
	test_cmp expect actual &&
	shit checkout f.$Adiarnfc &&
	rm expect actual
'
# This will test nfd2nfc in shit stage()
test_expect_success "stage file d.Adiarnfd/f.Adiarnfd" '
	mkdir d.$Adiarnfd &&
	echo d.$Adiarnfd/f.$Adiarnfd >d.$Adiarnfd/f.$Adiarnfd &&
	shit stage d.$Adiarnfd/f.$Adiarnfd &&
	shit commit -m "add d.$Adiarnfd/f.$Adiarnfd"
'
test_expect_success "add link Adiarnfc" '
	ln -s d.$Adiarnfd/f.$Adiarnfd l.$Adiarnfc &&
	shit add l.$Adiarnfc &&
	shit commit -m "add l.Adiarnfc"
'
# This will test shit log
test_expect_success "shit log f.Adiar" '
	shit log f.$Adiarnfc > f.Adiarnfc.log &&
	shit log f.$Adiarnfd > f.Adiarnfd.log &&
	test -s f.Adiarnfc.log &&
	test -s f.Adiarnfd.log &&
	test_cmp f.Adiarnfc.log f.Adiarnfd.log &&
	rm f.Adiarnfc.log f.Adiarnfd.log
'
# This will test shit ls-files
test_expect_success "shit lsfiles f.Adiar" '
	shit ls-files f.$Adiarnfc > f.Adiarnfc.log &&
	shit ls-files f.$Adiarnfd > f.Adiarnfd.log &&
	test -s f.Adiarnfc.log &&
	test -s f.Adiarnfd.log &&
	test_cmp f.Adiarnfc.log f.Adiarnfd.log &&
	rm f.Adiarnfc.log f.Adiarnfd.log
'
# This will test shit mv
test_expect_success "shit mv" '
	shit mv f.$Adiarnfd f.$Odiarnfc &&
	shit mv d.$Adiarnfd d.$Odiarnfc &&
	shit mv l.$Adiarnfd l.$Odiarnfc &&
	shit commit -m "mv Adiarnfd Odiarnfc"
'
# Files can be checked out as nfc
# And the link has been corrected from nfd to nfc
test_expect_success "shit checkout nfc" '
	rm f.$Odiarnfc &&
	shit checkout f.$Odiarnfc
'
# Make it possible to checkout files with their NFD names
test_expect_success "shit checkout file nfd" '
	rm -f f.* &&
	shit checkout f.$Odiarnfd
'
# Make it possible to checkout links with their NFD names
test_expect_success "shit checkout link nfd" '
	rm l.* &&
	shit checkout l.$Odiarnfd
'
test_expect_success "setup case mac2" '
	shit checkout main &&
	shit reset --hard &&
	shit checkout -b mac_os_2
'
# This will test nfd2nfc in shit commit
test_expect_success "commit file d2.Adiarnfd/f.Adiarnfd" '
	mkdir d2.$Adiarnfd &&
	echo d2.$Adiarnfd/f.$Adiarnfd >d2.$Adiarnfd/f.$Adiarnfd &&
	shit add d2.$Adiarnfd/f.$Adiarnfd &&
	shit commit -m "add d2.$Adiarnfd/f.$Adiarnfd" -- d2.$Adiarnfd/f.$Adiarnfd
'
test_expect_success "setup for long decomposed filename" '
	shit checkout main &&
	shit reset --hard &&
	shit checkout -b mac_os_long_nfd_fn
'
test_expect_success "Add long decomposed filename" '
	echo longd >$Alongd &&
	shit add * &&
	shit commit -m "Long filename"
'
test_expect_success "setup for long precomposed filename" '
	shit checkout main &&
	shit reset --hard &&
	shit checkout -b mac_os_long_nfc_fn
'
test_expect_success "Add long precomposed filename" '
	echo longc >$Alongc &&
	shit add * &&
	shit commit -m "Long filename"
'

test_expect_failure 'handle existing decomposed filenames' '
	echo content >"verbatim.$Adiarnfd" &&
	shit -c core.precomposeunicode=false add "verbatim.$Adiarnfd" &&
	shit commit -m "existing decomposed file" &&
	shit ls-files --exclude-standard -o "verbatim*" >untracked &&
	test_must_be_empty untracked
'

test_expect_success "unicode decomposed: shit restore -p . " '
	DIRNAMEPWD=dir.Odiarnfc &&
	DIRNAMEINREPO=dir.$Adiarnfc &&
	export DIRNAMEPWD DIRNAMEINREPO &&
	shit init "$DIRNAMEPWD" &&
	(
		cd "$DIRNAMEPWD" &&
		mkdir "$DIRNAMEINREPO" &&
		cd "$DIRNAMEINREPO" &&
		echo "Initial" >file &&
		shit add file &&
		echo "More stuff" >>file &&
		echo y | shit restore -p .
	)
'

# Test if the global core.precomposeunicode stops autosensing
# Must be the last test case
test_expect_success "respect shit config --global core.precomposeunicode" '
	shit config --global core.precomposeunicode true &&
	rm -rf .shit &&
	shit init &&
	precomposeunicode=$(shit config core.precomposeunicode) &&
	test "$precomposeunicode" = "true"
'

test_done
