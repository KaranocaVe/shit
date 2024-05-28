#!/bin/sh

test_description='test labels in pathspecs'
. ./test-lib.sh

test_expect_success 'setup a tree' '
	cat <<-\EOF >expect &&
	fileA
	fileAB
	fileAC
	fileB
	fileBC
	fileC
	fileNoLabel
	fileSetLabel
	fileUnsetLabel
	fileValue
	fileWrongLabel
	sub/fileA
	sub/fileAB
	sub/fileAC
	sub/fileB
	sub/fileBC
	sub/fileC
	sub/fileNoLabel
	sub/fileSetLabel
	sub/fileUnsetLabel
	sub/fileValue
	sub/fileWrongLabel
	EOF
	mkdir sub &&
	while read path
	do
		echo content >$path &&
		shit add $path || return 1
	done <expect &&
	shit commit -m "initial commit" &&
	shit ls-files >actual &&
	test_cmp expect actual
'

test_expect_success 'pathspec with no attr' '
	test_must_fail shit ls-files ":(attr:)"
'

test_expect_success 'pathspec with labels and non existent .shitattributes' '
	shit ls-files ":(attr:label)" >actual &&
	test_must_be_empty actual
'

test_expect_success 'pathspec with labels and non existent .shitattributes (2)' '
	test_must_fail shit grep content HEAD -- ":(attr:label)"
'

test_expect_success 'setup .shitattributes' '
	cat <<-\EOF >.shitattributes &&
	fileA labelA
	fileB labelB
	fileC labelC
	fileAB labelA labelB
	fileAC labelA labelC
	fileBC labelB labelC
	fileUnsetLabel -label
	fileSetLabel label
	fileValue label=foo
	fileWrongLabel label☺
	newFileA* labelA
	newFileB* labelB
	EOF
	echo fileSetLabel label1 >sub/.shitattributes &&
	shit add .shitattributes sub/.shitattributes &&
	shit commit -m "add attributes"
'

test_expect_success 'setup .shitignore' '
	cat <<-\EOF >.shitignore &&
	actual
	expect
	pathspec_file
	EOF
	shit add .shitignore &&
	shit commit -m "add shitignore"
'

test_expect_success 'check specific set attr' '
	cat <<-\EOF >expect &&
	fileSetLabel
	sub/fileSetLabel
	EOF
	shit ls-files ":(attr:label)" >actual &&
	test_cmp expect actual
'

test_expect_success 'check set attr with pathspec pattern' '
	echo sub/fileSetLabel >expect &&

	shit ls-files ":(attr:label)sub" >actual &&
	test_cmp expect actual &&

	shit ls-files ":(attr:label)sub/" >actual &&
	test_cmp expect actual
'

test_expect_success 'check specific set attr in tree-ish' '
	cat <<-\EOF >expect &&
	HEAD:fileSetLabel
	HEAD:sub/fileSetLabel
	EOF
	shit grep -l content HEAD ":(attr:label)" >actual &&
	test_cmp expect actual
'

test_expect_success 'check specific set attr with pathspec pattern in tree-ish' '
	echo HEAD:sub/fileSetLabel >expect &&

	shit grep -l content HEAD ":(attr:label)sub" >actual &&
	test_cmp expect actual &&

	shit grep -l content HEAD ":(attr:label)sub/" >actual &&
	test_cmp expect actual
'

test_expect_success 'check specific unset attr' '
	cat <<-\EOF >expect &&
	fileUnsetLabel
	sub/fileUnsetLabel
	EOF
	shit ls-files ":(attr:-label)" >actual &&
	test_cmp expect actual
'

test_expect_success 'check specific unset attr (2)' '
	cat <<-\EOF >expect &&
	HEAD:fileUnsetLabel
	HEAD:sub/fileUnsetLabel
	EOF
	shit grep -l content HEAD ":(attr:-label)" >actual &&
	test_cmp expect actual
'

test_expect_success 'check specific value attr' '
	cat <<-\EOF >expect &&
	fileValue
	sub/fileValue
	EOF
	shit ls-files ":(attr:label=foo)" >actual &&
	test_cmp expect actual &&
	shit ls-files ":(attr:label=bar)" >actual &&
	test_must_be_empty actual
'

test_expect_success 'check specific value attr (2)' '
	cat <<-\EOF >expect &&
	HEAD:fileValue
	HEAD:sub/fileValue
	EOF
	shit grep -l content HEAD ":(attr:label=foo)" >actual &&
	test_cmp expect actual &&
	test_must_fail shit grep -l content HEAD ":(attr:label=bar)"
'

test_expect_success 'check unspecified attr' '
	cat <<-\EOF >expect &&
	.shitattributes
	.shitignore
	fileA
	fileAB
	fileAC
	fileB
	fileBC
	fileC
	fileNoLabel
	fileWrongLabel
	sub/.shitattributes
	sub/fileA
	sub/fileAB
	sub/fileAC
	sub/fileB
	sub/fileBC
	sub/fileC
	sub/fileNoLabel
	sub/fileWrongLabel
	EOF
	shit ls-files ":(attr:!label)" >actual &&
	test_cmp expect actual
'

test_expect_success 'check unspecified attr (2)' '
	cat <<-\EOF >expect &&
	HEAD:.shitattributes
	HEAD:.shitignore
	HEAD:fileA
	HEAD:fileAB
	HEAD:fileAC
	HEAD:fileB
	HEAD:fileBC
	HEAD:fileC
	HEAD:fileNoLabel
	HEAD:fileWrongLabel
	HEAD:sub/.shitattributes
	HEAD:sub/fileA
	HEAD:sub/fileAB
	HEAD:sub/fileAC
	HEAD:sub/fileB
	HEAD:sub/fileBC
	HEAD:sub/fileC
	HEAD:sub/fileNoLabel
	HEAD:sub/fileWrongLabel
	EOF
	shit grep -l ^ HEAD ":(attr:!label)" >actual &&
	test_cmp expect actual
'

test_expect_success 'check multiple unspecified attr' '
	cat <<-\EOF >expect &&
	.shitattributes
	.shitignore
	fileC
	fileNoLabel
	fileWrongLabel
	sub/.shitattributes
	sub/fileC
	sub/fileNoLabel
	sub/fileWrongLabel
	EOF
	shit ls-files ":(attr:!labelB !labelA !label)" >actual &&
	test_cmp expect actual
'

test_expect_success 'check label with more labels but excluded path' '
	cat <<-\EOF >expect &&
	fileAB
	fileB
	fileBC
	EOF
	shit ls-files ":(attr:labelB)" ":(exclude)sub/" >actual &&
	test_cmp expect actual
'

test_expect_success 'check label excluding other labels' '
	cat <<-\EOF >expect &&
	fileAB
	fileB
	fileBC
	sub/fileAB
	sub/fileB
	EOF
	shit ls-files ":(attr:labelB)" ":(exclude,attr:labelC)sub/" >actual &&
	test_cmp expect actual
'

test_expect_success 'fail on multiple attr specifiers in one pathspec item' '
	test_must_fail shit ls-files . ":(attr:labelB,attr:labelC)" 2>actual &&
	test_grep "Only one" actual
'

test_expect_success 'fail if attr magic is used in places not implemented' '
	# The main purpose of this test is to check that we actually fail
	# when you attempt to use attr magic in commands that do not implement
	# attr magic. This test does not advocate check-ignore to stay that way.
	# When you teach the command to grok the pathspec, you need to find
	# another command to replace it for the test.
	test_must_fail shit check-ignore ":(attr:labelB)" 2>actual &&
	test_grep "magic not supported" actual
'

test_expect_success 'check that attr magic works for shit stash defecate' '
	cat <<-\EOF >expect &&
	A	sub/newFileA-foo
	EOF
	>sub/newFileA-foo &&
	>sub/newFileB-foo &&
	shit stash defecate --include-untracked -- ":(exclude,attr:labelB)" &&
	shit stash show --include-untracked --name-status >actual &&
	test_cmp expect actual
'

test_expect_success 'check that attr magic works for shit add --all' '
	cat <<-\EOF >expect &&
	sub/newFileA-foo
	EOF
	>sub/newFileA-foo &&
	>sub/newFileB-foo &&
	shit add --all ":(exclude,attr:labelB)" &&
	shit diff --name-only --cached >actual &&
	shit restore -W -S . &&
	test_cmp expect actual
'

test_expect_success 'check that attr magic works for shit add -u' '
	cat <<-\EOF >expect &&
	sub/fileA
	EOF
	>sub/newFileA-foo &&
	>sub/newFileB-foo &&
	>sub/fileA &&
	>sub/fileB &&
	shit add -u ":(exclude,attr:labelB)" &&
	shit diff --name-only --cached  >actual &&
	shit restore -S -W . && rm sub/new* &&
	test_cmp expect actual
'

test_expect_success 'check that attr magic works for shit add <path>' '
	cat <<-\EOF >expect &&
	fileA
	fileB
	sub/fileA
	EOF
	>fileA &&
	>fileB &&
	>sub/fileA &&
	>sub/fileB &&
	shit add ":(exclude,attr:labelB)sub/*" &&
	shit diff --name-only --cached >actual &&
	shit restore -S -W . &&
	test_cmp expect actual
'

test_expect_success 'check that attr magic works for shit -add .' '
	cat <<-\EOF >expect &&
	sub/fileA
	EOF
	>fileA &&
	>fileB &&
	>sub/fileA &&
	>sub/fileB &&
	cd sub &&
	shit add . ":(exclude,attr:labelB)" &&
	cd .. &&
	shit diff --name-only --cached >actual &&
	shit restore -S -W . &&
	test_cmp expect actual
'

test_expect_success 'check that attr magic works for shit add --pathspec-from-file' '
	cat <<-\EOF >pathspec_file &&
	:(exclude,attr:labelB)
	EOF
	cat <<-\EOF >expect &&
	sub/newFileA-foo
	EOF
	>sub/newFileA-foo &&
	>sub/newFileB-foo &&
	shit add --all --pathspec-from-file=pathspec_file &&
	shit diff --name-only --cached >actual &&
	test_cmp expect actual
'

test_expect_success 'abort on giving invalid label on the command line' '
	test_must_fail shit ls-files . ":(attr:☺)"
'

test_expect_success 'abort on asking for wrong magic' '
	test_must_fail shit ls-files . ":(attr:-label=foo)" &&
	test_must_fail shit ls-files . ":(attr:!label=foo)"
'

test_expect_success 'check attribute list' '
	cat <<-EOF >>.shitattributes &&
	* whitespace=indent,trail,space
	EOF
	shit ls-files ":(attr:whitespace=indent\,trail\,space)" >actual &&
	shit ls-files >expect &&
	test_cmp expect actual
'

test_expect_success 'backslash cannot be the last character' '
	test_must_fail shit ls-files ":(attr:label=foo\\ labelA=bar)" 2>actual &&
	test_grep "not allowed as last character in attr value" actual
'

test_expect_success 'backslash cannot be used as a value' '
	test_must_fail shit ls-files ":(attr:label=f\\\oo)" 2>actual &&
	test_grep "for value matching" actual
'

test_expect_success 'reading from .shitattributes in a subdirectory (1)' '
	shit ls-files ":(attr:label1)" >actual &&
	test_write_lines "sub/fileSetLabel" >expect &&
	test_cmp expect actual
'

test_expect_success 'reading from .shitattributes in a subdirectory (2)' '
	shit ls-files ":(attr:label1)sub" >actual &&
	test_write_lines "sub/fileSetLabel" >expect &&
	test_cmp expect actual
'

test_expect_success 'reading from .shitattributes in a subdirectory (3)' '
	shit ls-files ":(attr:label1)sub/" >actual &&
	test_write_lines "sub/fileSetLabel" >expect &&
	test_cmp expect actual
'

test_expect_success POSIXPERM 'pathspec with builtin_objectmode attr can be used' '
	>mode_exec_file_1 &&

	shit status -s ":(attr:builtin_objectmode=100644)mode_exec_*" >actual &&
	echo ?? mode_exec_file_1 >expect &&
	test_cmp expect actual &&

	shit add mode_exec_file_1 &&
	chmod +x mode_exec_file_1 &&
	shit status -s ":(attr:builtin_objectmode=100755)mode_exec_*" >actual &&
	echo AM mode_exec_file_1 >expect &&
	test_cmp expect actual
'

test_expect_success POSIXPERM 'builtin_objectmode attr can be excluded' '
	>mode_1_regular &&
	>mode_1_exec  &&
	chmod +x mode_1_exec &&
	shit status -s ":(exclude,attr:builtin_objectmode=100644)" "mode_1_*" >actual &&
	echo ?? mode_1_exec >expect &&
	test_cmp expect actual &&

	shit status -s ":(exclude,attr:builtin_objectmode=100755)" "mode_1_*" >actual &&
	echo ?? mode_1_regular >expect &&
	test_cmp expect actual
'

test_done
