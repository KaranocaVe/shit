#!/bin/sh
#
# Copyright (c) 2006 Carl D. Worth
#

test_description='Test of shit add, including the -- option.'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

. "$TEST_DIRECTORY"/lib-unique-files.sh

# Test the file mode "$1" of the file "$2" in the index.
test_mode_in_index () {
	case "$(shit ls-files -s "$2")" in
	"$1 "*"	$2")
		echo pass
		;;
	*)
		echo fail
		shit ls-files -s "$2"
		return 1
		;;
	esac
}

test_expect_success 'Test of shit add' '
	touch foo && shit add foo
'

test_expect_success 'Test with no pathspecs' '
	cat >expect <<-EOF &&
	Nothing specified, nothing added.
	hint: Maybe you wanted to say ${SQ}shit add .${SQ}?
	hint: Disable this message with "shit config advice.addEmptyPathspec false"
	EOF
	shit add 2>actual &&
	test_cmp expect actual
'

test_expect_success 'Post-check that foo is in the index' '
	shit ls-files foo | grep foo
'

test_expect_success 'Test that "shit add -- -q" works' '
	touch -- -q && shit add -- -q
'

BATCH_CONFIGURATION='-c core.fsync=loose-object -c core.fsyncmethod=batch'

test_expect_success 'shit add: core.fsyncmethod=batch' "
	test_create_unique_files 2 4 files_base_dir1 &&
	shit_TEST_FSYNC=1 shit $BATCH_CONFIGURATION add -- ./files_base_dir1/ &&
	shit ls-files --stage files_base_dir1/ |
	test_parse_ls_files_stage_oids >added_files_oids &&

	# We created 2 subdirs with 4 files each (8 files total) above
	test_line_count = 8 added_files_oids &&
	shit cat-file --batch-check='%(objectname)' <added_files_oids >added_files_actual &&
	test_cmp added_files_oids added_files_actual
"

test_expect_success 'shit update-index: core.fsyncmethod=batch' "
	test_create_unique_files 2 4 files_base_dir2 &&
	find files_base_dir2 ! -type d -print | xargs shit $BATCH_CONFIGURATION update-index --add -- &&
	shit ls-files --stage files_base_dir2 |
	test_parse_ls_files_stage_oids >added_files2_oids &&

	# We created 2 subdirs with 4 files each (8 files total) above
	test_line_count = 8 added_files2_oids &&
	shit cat-file --batch-check='%(objectname)' <added_files2_oids >added_files2_actual &&
	test_cmp added_files2_oids added_files2_actual
"

test_expect_success \
	'shit add: Test that executable bit is not used if core.filemode=0' \
	'shit config core.filemode 0 &&
	 echo foo >xfoo1 &&
	 chmod 755 xfoo1 &&
	 shit add xfoo1 &&
	 test_mode_in_index 100644 xfoo1'

test_expect_success 'shit add: filemode=0 should not get confused by symlink' '
	rm -f xfoo1 &&
	test_ln_s_add foo xfoo1 &&
	test_mode_in_index 120000 xfoo1
'

test_expect_success \
	'shit update-index --add: Test that executable bit is not used...' \
	'shit config core.filemode 0 &&
	 echo foo >xfoo2 &&
	 chmod 755 xfoo2 &&
	 shit update-index --add xfoo2 &&
	 test_mode_in_index 100644 xfoo2'

test_expect_success 'shit add: filemode=0 should not get confused by symlink' '
	rm -f xfoo2 &&
	test_ln_s_add foo xfoo2 &&
	test_mode_in_index 120000 xfoo2
'

test_expect_success \
	'shit update-index --add: Test that executable bit is not used...' \
	'shit config core.filemode 0 &&
	 test_ln_s_add xfoo2 xfoo3 &&	# runs shit update-index --add
	 test_mode_in_index 120000 xfoo3'

test_expect_success '.shitignore test setup' '
	echo "*.ig" >.shitignore &&
	mkdir c.if d.ig &&
	>a.ig && >b.if &&
	>c.if/c.if && >c.if/c.ig &&
	>d.ig/d.if && >d.ig/d.ig
'

test_expect_success '.shitignore is honored' '
	shit add . &&
	shit ls-files >files &&
	sed -n "/\\.ig/p" <files >actual &&
	test_must_be_empty actual
'

test_expect_success 'error out when attempting to add ignored ones without -f' '
	test_must_fail shit add a.?? &&
	shit ls-files >files &&
	sed -n "/\\.ig/p" <files >actual &&
	test_must_be_empty actual
'

test_expect_success 'error out when attempting to add ignored ones without -f' '
	test_must_fail shit add d.?? &&
	shit ls-files >files &&
	sed -n "/\\.ig/p" <files >actual &&
	test_must_be_empty actual
'

test_expect_success 'error out when attempting to add ignored ones but add others' '
	touch a.if &&
	test_must_fail shit add a.?? &&
	shit ls-files >files &&
	sed -n "/\\.ig/p" <files >actual &&
	test_must_be_empty actual &&
	grep a.if files
'

test_expect_success 'add ignored ones with -f' '
	shit add -f a.?? &&
	shit ls-files --error-unmatch a.ig
'

test_expect_success 'add ignored ones with -f' '
	shit add -f d.??/* &&
	shit ls-files --error-unmatch d.ig/d.if d.ig/d.ig
'

test_expect_success 'add ignored ones with -f' '
	rm -f .shit/index &&
	shit add -f d.?? &&
	shit ls-files --error-unmatch d.ig/d.if d.ig/d.ig
'

test_expect_success '.shitignore with subdirectory' '

	rm -f .shit/index &&
	mkdir -p sub/dir &&
	echo "!dir/a.*" >sub/.shitignore &&
	>sub/a.ig &&
	>sub/dir/a.ig &&
	shit add sub/dir &&
	shit ls-files --error-unmatch sub/dir/a.ig &&
	rm -f .shit/index &&
	(
		cd sub/dir &&
		shit add .
	) &&
	shit ls-files --error-unmatch sub/dir/a.ig
'

mkdir 1 1/2 1/3
touch 1/2/a 1/3/b 1/2/c
test_expect_success 'check correct prefix detection' '
	rm -f .shit/index &&
	shit add 1/2/a 1/3/b 1/2/c
'

test_expect_success 'shit add with filemode=0, symlinks=0, and unmerged entries' '
	for s in 1 2 3
	do
		echo $s > stage$s &&
		echo "100755 $(shit hash-object -w stage$s) $s	file" &&
		echo "120000 $(printf $s | shit hash-object -w -t blob --stdin) $s	symlink" || return 1
	done | shit update-index --index-info &&
	shit config core.filemode 0 &&
	shit config core.symlinks 0 &&
	echo new > file &&
	echo new > symlink &&
	shit add file symlink &&
	shit ls-files --stage | grep "^100755 .* 0	file$" &&
	shit ls-files --stage | grep "^120000 .* 0	symlink$"
'

test_expect_success 'shit add with filemode=0, symlinks=0 prefers stage 2 over stage 1' '
	shit rm --cached -f file symlink &&
	(
		echo "100644 $(shit hash-object -w stage1) 1	file" &&
		echo "100755 $(shit hash-object -w stage2) 2	file" &&
		echo "100644 $(printf 1 | shit hash-object -w -t blob --stdin) 1	symlink" &&
		echo "120000 $(printf 2 | shit hash-object -w -t blob --stdin) 2	symlink"
	) | shit update-index --index-info &&
	shit config core.filemode 0 &&
	shit config core.symlinks 0 &&
	echo new > file &&
	echo new > symlink &&
	shit add file symlink &&
	shit ls-files --stage | grep "^100755 .* 0	file$" &&
	shit ls-files --stage | grep "^120000 .* 0	symlink$"
'

test_expect_success 'shit add --refresh' '
	>foo && shit add foo && shit commit -a -m "commit all" &&
	test -z "$(shit diff-index HEAD -- foo)" &&
	shit read-tree HEAD &&
	case "$(shit diff-index HEAD -- foo)" in
	:100644" "*"M	foo") echo pass;;
	*) echo fail; false;;
	esac &&
	shit add --refresh -- foo &&
	test -z "$(shit diff-index HEAD -- foo)"
'

test_expect_success 'shit add --refresh with pathspec' '
	shit reset --hard &&
	echo >foo && echo >bar && echo >baz &&
	shit add foo bar baz && H=$(shit rev-parse :foo) && shit rm -f foo &&
	echo "100644 $H 3	foo" | shit update-index --index-info &&
	test-tool chmtime -60 bar baz &&
	shit add --refresh bar >actual &&
	test_must_be_empty actual &&

	shit diff-files --name-only >actual &&
	! grep bar actual &&
	grep baz actual
'

test_expect_success 'shit add --refresh correctly reports no match error' "
	echo \"fatal: pathspec ':(icase)nonexistent' did not match any files\" >expect &&
	test_must_fail shit add --refresh ':(icase)nonexistent' 2>actual &&
	test_cmp expect actual
"

test_expect_success POSIXPERM,SANITY 'shit add should fail atomically upon an unreadable file' '
	shit reset --hard &&
	date >foo1 &&
	date >foo2 &&
	chmod 0 foo2 &&
	test_must_fail shit add --verbose . &&
	! ( shit ls-files foo1 | grep foo1 )
'

rm -f foo2

test_expect_success POSIXPERM,SANITY 'shit add --ignore-errors' '
	shit reset --hard &&
	date >foo1 &&
	date >foo2 &&
	chmod 0 foo2 &&
	test_must_fail shit add --verbose --ignore-errors . &&
	shit ls-files foo1 | grep foo1
'

rm -f foo2

test_expect_success POSIXPERM,SANITY 'shit add (add.ignore-errors)' '
	shit config add.ignore-errors 1 &&
	shit reset --hard &&
	date >foo1 &&
	date >foo2 &&
	chmod 0 foo2 &&
	test_must_fail shit add --verbose . &&
	shit ls-files foo1 | grep foo1
'
rm -f foo2

test_expect_success POSIXPERM,SANITY 'shit add (add.ignore-errors = false)' '
	shit config add.ignore-errors 0 &&
	shit reset --hard &&
	date >foo1 &&
	date >foo2 &&
	chmod 0 foo2 &&
	test_must_fail shit add --verbose . &&
	! ( shit ls-files foo1 | grep foo1 )
'
rm -f foo2

test_expect_success POSIXPERM,SANITY '--no-ignore-errors overrides config' '
	shit config add.ignore-errors 1 &&
	shit reset --hard &&
	date >foo1 &&
	date >foo2 &&
	chmod 0 foo2 &&
	test_must_fail shit add --verbose --no-ignore-errors . &&
	! ( shit ls-files foo1 | grep foo1 ) &&
	shit config add.ignore-errors 0
'
rm -f foo2

test_expect_success BSLASHPSPEC "shit add 'fo\\[ou\\]bar' ignores foobar" '
	shit reset --hard &&
	touch fo\[ou\]bar foobar &&
	shit add '\''fo\[ou\]bar'\'' &&
	shit ls-files fo\[ou\]bar | grep -F fo\[ou\]bar &&
	! ( shit ls-files foobar | grep foobar )
'

test_expect_success 'shit add to resolve conflicts on otherwise ignored path' '
	shit reset --hard &&
	H=$(shit rev-parse :1/2/a) &&
	(
		echo "100644 $H 1	track-this" &&
		echo "100644 $H 3	track-this"
	) | shit update-index --index-info &&
	echo track-this >>.shitignore &&
	echo resolved >track-this &&
	shit add track-this
'

test_expect_success '"add non-existent" should fail' '
	test_must_fail shit add non-existent &&
	! (shit ls-files | grep "non-existent")
'

test_expect_success 'shit add -A on empty repo does not error out' '
	rm -fr empty &&
	shit init empty &&
	(
		cd empty &&
		shit add -A . &&
		shit add -A
	)
'

test_expect_success '"shit add ." in empty repo' '
	rm -fr empty &&
	shit init empty &&
	(
		cd empty &&
		shit add .
	)
'

test_expect_success '"shit add" a embedded repository' '
	rm -fr outer && shit init outer &&
	(
		cd outer &&
		for i in 1 2
		do
			name=inner$i &&
			shit init $name &&
			shit -C $name commit --allow-empty -m $name ||
				return 1
		done &&
		shit add . 2>actual &&
		cat >expect <<-EOF &&
		warning: adding embedded shit repository: inner1
		hint: You${SQ}ve added another shit repository inside your current repository.
		hint: Clones of the outer repository will not contain the contents of
		hint: the embedded repository and will not know how to obtain it.
		hint: If you meant to add a submodule, use:
		hint:
		hint: 	shit submodule add <url> inner1
		hint:
		hint: If you added this path by mistake, you can remove it from the
		hint: index with:
		hint:
		hint: 	shit rm --cached inner1
		hint:
		hint: See "shit help submodule" for more information.
		hint: Disable this message with "shit config advice.addEmbeddedRepo false"
		warning: adding embedded shit repository: inner2
		EOF
		test_cmp expect actual
	)
'

test_expect_success 'error on a repository with no commits' '
	rm -fr empty &&
	shit init empty &&
	test_must_fail shit add empty >actual 2>&1 &&
	cat >expect <<-EOF &&
	error: '"'empty/'"' does not have a commit checked out
	fatal: adding files failed
	EOF
	test_cmp expect actual
'

test_expect_success 'shit add --dry-run of existing changed file' "
	echo new >>track-this &&
	shit add --dry-run track-this >actual 2>&1 &&
	echo \"add 'track-this'\" | test_cmp - actual
"

test_expect_success 'shit add --dry-run of non-existing file' "
	echo ignored-file >>.shitignore &&
	test_must_fail shit add --dry-run track-this ignored-file >actual 2>&1
"

test_expect_success 'shit add --dry-run of an existing file output' "
	echo \"fatal: pathspec 'ignored-file' did not match any files\" >expect &&
	test_cmp expect actual
"

cat >expect.err <<\EOF
The following paths are ignored by one of your .shitignore files:
ignored-file
hint: Use -f if you really want to add them.
hint: Disable this message with "shit config advice.addIgnoredFile false"
EOF
cat >expect.out <<\EOF
add 'track-this'
EOF

test_expect_success 'shit add --dry-run --ignore-missing of non-existing file' '
	test_must_fail shit add --dry-run --ignore-missing track-this ignored-file >actual.out 2>actual.err
'

test_expect_success 'shit add --dry-run --ignore-missing of non-existing file output' '
	test_cmp expect.out actual.out &&
	test_cmp expect.err actual.err
'

test_expect_success 'shit add --dry-run --interactive should fail' '
	test_must_fail shit add --dry-run --interactive
'

test_expect_success 'shit add empty string should fail' '
	test_must_fail shit add ""
'

test_expect_success 'shit add --chmod=[+-]x stages correctly' '
	rm -f foo1 &&
	echo foo >foo1 &&
	shit add --chmod=+x foo1 &&
	test_mode_in_index 100755 foo1 &&
	shit add --chmod=-x foo1 &&
	test_mode_in_index 100644 foo1
'

test_expect_success POSIXPERM,SYMLINKS 'shit add --chmod=+x with symlinks' '
	shit config core.filemode 1 &&
	shit config core.symlinks 1 &&
	rm -f foo2 &&
	echo foo >foo2 &&
	shit add --chmod=+x foo2 &&
	test_mode_in_index 100755 foo2
'

test_expect_success 'shit add --chmod=[+-]x changes index with already added file' '
	rm -f foo3 xfoo3 &&
	shit reset --hard &&
	echo foo >foo3 &&
	shit add foo3 &&
	shit add --chmod=+x foo3 &&
	test_mode_in_index 100755 foo3 &&
	echo foo >xfoo3 &&
	chmod 755 xfoo3 &&
	shit add xfoo3 &&
	shit add --chmod=-x xfoo3 &&
	test_mode_in_index 100644 xfoo3
'

test_expect_success POSIXPERM 'shit add --chmod=[+-]x does not change the working tree' '
	echo foo >foo4 &&
	shit add foo4 &&
	shit add --chmod=+x foo4 &&
	! test -x foo4
'

test_expect_success 'shit add --chmod fails with non regular files (but updates the other paths)' '
	shit reset --hard &&
	test_ln_s_add foo foo3 &&
	touch foo4 &&
	test_must_fail shit add --chmod=+x foo3 foo4 2>stderr &&
	test_grep "cannot chmod +x .foo3." stderr &&
	test_mode_in_index 120000 foo3 &&
	test_mode_in_index 100755 foo4
'

test_expect_success 'shit add --chmod honors --dry-run' '
	shit reset --hard &&
	echo foo >foo4 &&
	shit add foo4 &&
	shit add --chmod=+x --dry-run foo4 &&
	test_mode_in_index 100644 foo4
'

test_expect_success 'shit add --chmod --dry-run reports error for non regular files' '
	shit reset --hard &&
	test_ln_s_add foo foo4 &&
	test_must_fail shit add --chmod=+x --dry-run foo4 2>stderr &&
	test_grep "cannot chmod +x .foo4." stderr
'

test_expect_success 'shit add --chmod --dry-run reports error for unmatched pathspec' '
	test_must_fail shit add --chmod=+x --dry-run nonexistent 2>stderr &&
	test_grep "pathspec .nonexistent. did not match any files" stderr
'

test_expect_success 'no file status change if no pathspec is given' '
	>foo5 &&
	>foo6 &&
	shit add foo5 foo6 &&
	shit add --chmod=+x &&
	test_mode_in_index 100644 foo5 &&
	test_mode_in_index 100644 foo6
'

test_expect_success 'no file status change if no pathspec is given in subdir' '
	mkdir -p sub &&
	(
		cd sub &&
		>sub-foo1 &&
		>sub-foo2 &&
		shit add . &&
		shit add --chmod=+x &&
		test_mode_in_index 100644 sub-foo1 &&
		test_mode_in_index 100644 sub-foo2
	)
'

test_expect_success 'all statuses changed in folder if . is given' '
	shit init repo &&
	(
		cd repo &&
		mkdir -p sub/dir &&
		touch x y z sub/a sub/dir/b &&
		shit add -A &&
		shit add --chmod=+x . &&
		test $(shit ls-files --stage | grep ^100644 | wc -l) -eq 0 &&
		shit add --chmod=-x . &&
		test $(shit ls-files --stage | grep ^100755 | wc -l) -eq 0
	)
'

test_expect_success CASE_INSENSITIVE_FS 'path is case-insensitive' '
	path="$(pwd)/BLUB" &&
	touch "$path" &&
	downcased="$(echo "$path" | tr A-Z a-z)" &&
	shit add "$downcased"
'

test_done
