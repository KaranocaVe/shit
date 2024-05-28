#!/bin/sh

test_description=shitattributes

TEST_PASSES_SANITIZE_LEAK=true
TEST_CREATE_REPO_NO_TEMPLATE=1
. ./test-lib.sh

attr_check_basic () {
	path="$1" expect="$2" shit_opts="$3" &&

	shit $shit_opts check-attr test -- "$path" >actual 2>err &&
	echo "$path: test: $expect" >expect &&
	test_cmp expect actual
}

attr_check () {
	attr_check_basic "$@" &&
	test_must_be_empty err
}

attr_check_object_mode_basic () {
	path="$1" &&
	expect="$2" &&
	check_opts="$3" &&
	shit check-attr $check_opts builtin_objectmode -- "$path" >actual 2>err &&
	echo "$path: builtin_objectmode: $expect" >expect &&
	test_cmp expect actual
}

attr_check_object_mode () {
	attr_check_object_mode_basic "$@" &&
	test_must_be_empty err
}

attr_check_quote () {
	path="$1" quoted_path="$2" expect="$3" &&

	shit check-attr test -- "$path" >actual &&
	echo "\"$quoted_path\": test: $expect" >expect &&
	test_cmp expect actual
}

attr_check_source () {
	path="$1" expect="$2" source="$3" shit_opts="$4" &&

	echo "$path: test: $expect" >expect &&

	shit $shit_opts check-attr --source $source test -- "$path" >actual 2>err &&
	test_cmp expect actual &&
	test_must_be_empty err &&

	shit $shit_opts --attr-source="$source" check-attr test -- "$path" >actual 2>err &&
	test_cmp expect actual &&
	test_must_be_empty err

	shit $shit_opts -c "attr.tree=$source" check-attr test -- "$path" >actual 2>err &&
	test_cmp expect actual &&
	test_must_be_empty err

	shit_ATTR_SOURCE="$source" shit $shit_opts check-attr test -- "$path" >actual 2>err &&
	test_cmp expect actual &&
	test_must_be_empty err
}

test_expect_success 'open-quoted pathname' '
	echo "\"a test=a" >.shitattributes &&
	attr_check a unspecified
'

test_expect_success 'setup' '
	mkdir -p a/b/d a/c b &&
	(
		echo "[attr]notest !test" &&
		echo "\" d \"	test=d" &&
		echo " e	test=e" &&
		echo " e\"	test=e" &&
		echo "f	test=f" &&
		echo "a/i test=a/i" &&
		echo "onoff test -test" &&
		echo "offon -test test" &&
		echo "no notest" &&
		echo "A/e/F test=A/e/F"
	) >.shitattributes &&
	(
		echo "g test=a/g" &&
		echo "b/g test=a/b/g"
	) >a/.shitattributes &&
	(
		echo "h test=a/b/h" &&
		echo "d/* test=a/b/d/*" &&
		echo "d/yes notest"
	) >a/b/.shitattributes &&
	(
		echo "global test=global"
	) >"$HOME"/global-shitattributes &&
	cat <<-EOF >expect-all
	f: test: f
	a/f: test: f
	a/c/f: test: f
	a/g: test: a/g
	a/b/g: test: a/b/g
	b/g: test: unspecified
	a/b/h: test: a/b/h
	a/b/d/g: test: a/b/d/*
	onoff: test: unset
	offon: test: set
	no: notest: set
	no: test: unspecified
	a/b/d/no: notest: set
	a/b/d/no: test: a/b/d/*
	a/b/d/yes: notest: set
	a/b/d/yes: test: unspecified
	EOF
'

test_expect_success 'setup branches' '
	mkdir -p foo/bar &&
	test_commit --printf "add .shitattributes" foo/bar/.shitattributes \
		"f test=f\na/i test=n\n" tag-1 &&
	test_commit --printf "add .shitattributes" foo/bar/.shitattributes \
		"g test=g\na/i test=m\n" tag-2 &&
	rm foo/bar/.shitattributes
'

test_expect_success 'command line checks' '
	test_must_fail shit check-attr &&
	test_must_fail shit check-attr -- &&
	test_must_fail shit check-attr test &&
	test_must_fail shit check-attr test -- &&
	test_must_fail shit check-attr -- f &&
	test_must_fail shit check-attr --source &&
	test_must_fail shit check-attr --source not-a-valid-ref &&
	echo "f" | test_must_fail shit check-attr --stdin &&
	echo "f" | test_must_fail shit check-attr --stdin -- f &&
	echo "f" | test_must_fail shit check-attr --stdin test -- f &&
	test_must_fail shit check-attr "" -- f
'

test_expect_success 'attribute test' '

	attr_check " d " d &&
	attr_check e e &&
	attr_check_quote e\" e\\\" e &&

	attr_check f f &&
	attr_check a/f f &&
	attr_check a/c/f f &&
	attr_check a/g a/g &&
	attr_check a/b/g a/b/g &&
	attr_check b/g unspecified &&
	attr_check a/b/h a/b/h &&
	attr_check a/b/d/g "a/b/d/*" &&
	attr_check onoff unset &&
	attr_check offon set &&
	attr_check no unspecified &&
	attr_check a/b/d/no "a/b/d/*" &&
	attr_check a/b/d/yes unspecified
'

test_expect_success 'attribute matching is case sensitive when core.ignorecase=0' '

	attr_check F unspecified "-c core.ignorecase=0" &&
	attr_check a/F unspecified "-c core.ignorecase=0" &&
	attr_check a/c/F unspecified "-c core.ignorecase=0" &&
	attr_check a/G unspecified "-c core.ignorecase=0" &&
	attr_check a/B/g a/g "-c core.ignorecase=0" &&
	attr_check a/b/G unspecified "-c core.ignorecase=0" &&
	attr_check a/b/H unspecified "-c core.ignorecase=0" &&
	attr_check a/b/D/g a/g "-c core.ignorecase=0" &&
	attr_check oNoFf unspecified "-c core.ignorecase=0" &&
	attr_check oFfOn unspecified "-c core.ignorecase=0" &&
	attr_check NO unspecified "-c core.ignorecase=0" &&
	attr_check a/b/D/NO unspecified "-c core.ignorecase=0" &&
	attr_check a/b/d/YES a/b/d/* "-c core.ignorecase=0" &&
	attr_check a/E/f f "-c core.ignorecase=0"

'

test_expect_success 'attribute matching is case insensitive when core.ignorecase=1' '

	attr_check F f "-c core.ignorecase=1" &&
	attr_check a/F f "-c core.ignorecase=1" &&
	attr_check a/c/F f "-c core.ignorecase=1" &&
	attr_check a/G a/g "-c core.ignorecase=1" &&
	attr_check a/B/g a/b/g "-c core.ignorecase=1" &&
	attr_check a/b/G a/b/g "-c core.ignorecase=1" &&
	attr_check a/b/H a/b/h "-c core.ignorecase=1" &&
	attr_check a/b/D/g "a/b/d/*" "-c core.ignorecase=1" &&
	attr_check oNoFf unset "-c core.ignorecase=1" &&
	attr_check oFfOn set "-c core.ignorecase=1" &&
	attr_check NO unspecified "-c core.ignorecase=1" &&
	attr_check a/b/D/NO "a/b/d/*" "-c core.ignorecase=1" &&
	attr_check a/b/d/YES unspecified "-c core.ignorecase=1" &&
	attr_check a/E/f "A/e/F" "-c core.ignorecase=1"

'

test_expect_success CASE_INSENSITIVE_FS 'additional case insensitivity tests' '
	attr_check a/B/D/g a/g "-c core.ignorecase=0" &&
	attr_check A/B/D/NO unspecified "-c core.ignorecase=0" &&
	attr_check A/b/h a/b/h "-c core.ignorecase=1" &&
	attr_check a/B/D/g "a/b/d/*" "-c core.ignorecase=1" &&
	attr_check A/B/D/NO "a/b/d/*" "-c core.ignorecase=1"
'

test_expect_success 'unnormalized paths' '
	attr_check ./f f &&
	attr_check ./a/g a/g &&
	attr_check a/./g a/g &&
	attr_check a/c/../b/g a/b/g
'

test_expect_success 'relative paths' '
	(cd a && attr_check ../f f) &&
	(cd a && attr_check f f) &&
	(cd a && attr_check i a/i) &&
	(cd a && attr_check g a/g) &&
	(cd a && attr_check b/g a/b/g) &&
	(cd b && attr_check ../a/f f) &&
	(cd b && attr_check ../a/g a/g) &&
	(cd b && attr_check ../a/b/g a/b/g)
'

test_expect_success 'prefixes are not confused with leading directories' '
	attr_check a_plus/g unspecified &&
	cat >expect <<-\EOF &&
	a/g: test: a/g
	a_plus/g: test: unspecified
	EOF
	shit check-attr test a/g a_plus/g >actual &&
	test_cmp expect actual
'

test_expect_success 'core.attributesfile' '
	attr_check global unspecified &&
	shit config core.attributesfile "$HOME/global-shitattributes" &&
	attr_check global global &&
	shit config core.attributesfile "~/global-shitattributes" &&
	attr_check global global &&
	echo "global test=precedence" >>.shitattributes &&
	attr_check global precedence
'

test_expect_success 'attribute test: read paths from stdin' '
	grep -v notest <expect-all >expect &&
	sed -e "s/:.*//" <expect | shit check-attr --stdin test >actual &&
	test_cmp expect actual
'

test_expect_success 'setup --all option' '
	grep -v unspecified <expect-all | sort >specified-all &&
	sed -e "s/:.*//" <expect-all | uniq >stdin-all
'

test_expect_success 'attribute test: --all option' '
	shit check-attr --stdin --all <stdin-all >tmp &&
	sort tmp >actual &&
	test_cmp specified-all actual
'

test_expect_success 'attribute test: --cached option' '
	shit check-attr --cached --stdin --all <stdin-all >tmp &&
	sort tmp >actual &&
	test_must_be_empty actual &&
	shit add .shitattributes a/.shitattributes a/b/.shitattributes &&
	shit check-attr --cached --stdin --all <stdin-all >tmp &&
	sort tmp >actual &&
	test_cmp specified-all actual
'

test_expect_success 'root subdir attribute test' '
	attr_check a/i a/i &&
	attr_check subdir/a/i unspecified
'

test_expect_success 'negative patterns' '
	echo "!f test=bar" >.shitattributes &&
	shit check-attr test -- '"'"'!f'"'"' 2>errors &&
	test_grep "Negative patterns are ignored" errors
'

test_expect_success 'patterns starting with exclamation' '
	echo "\!f test=foo" >.shitattributes &&
	attr_check "!f" foo
'

test_expect_success '"**" test' '
	echo "**/f foo=bar" >.shitattributes &&
	cat <<\EOF >expect &&
f: foo: bar
a/f: foo: bar
a/b/f: foo: bar
a/b/c/f: foo: bar
EOF
	shit check-attr foo -- "f" >actual 2>err &&
	shit check-attr foo -- "a/f" >>actual 2>>err &&
	shit check-attr foo -- "a/b/f" >>actual 2>>err &&
	shit check-attr foo -- "a/b/c/f" >>actual 2>>err &&
	test_cmp expect actual &&
	test_must_be_empty err
'

test_expect_success '"**" with no slashes test' '
	echo "a**f foo=bar" >.shitattributes &&
	shit check-attr foo -- "f" >actual &&
	cat <<\EOF >expect &&
f: foo: unspecified
af: foo: bar
axf: foo: bar
a/f: foo: unspecified
a/b/f: foo: unspecified
a/b/c/f: foo: unspecified
EOF
	shit check-attr foo -- "f" >actual 2>err &&
	shit check-attr foo -- "af" >>actual 2>err &&
	shit check-attr foo -- "axf" >>actual 2>err &&
	shit check-attr foo -- "a/f" >>actual 2>>err &&
	shit check-attr foo -- "a/b/f" >>actual 2>>err &&
	shit check-attr foo -- "a/b/c/f" >>actual 2>>err &&
	test_cmp expect actual &&
	test_must_be_empty err
'

test_expect_success 'using --shit-dir and --work-tree' '
	mkdir unreal real &&
	shit init real &&
	echo "file test=in-real" >real/.shitattributes &&
	(
		cd unreal &&
		attr_check file in-real "--shit-dir ../real/.shit --work-tree ../real"
	)
'

test_expect_success 'using --source' '
	attr_check_source foo/bar/f f tag-1 &&
	attr_check_source foo/bar/a/i n tag-1 &&
	attr_check_source foo/bar/f unspecified tag-2 &&
	attr_check_source foo/bar/a/i m tag-2 &&
	attr_check_source foo/bar/g g tag-2 &&
	attr_check_source foo/bar/g unspecified tag-1
'

test_expect_success 'setup bare' '
	shit clone --template= --bare . bare.shit
'

test_expect_success 'bare repository: check that .shitattribute is ignored' '
	(
		cd bare.shit &&
		(
			echo "f	test=f" &&
			echo "a/i test=a/i"
		) >.shitattributes &&
		attr_check f unspecified &&
		attr_check a/f unspecified &&
		attr_check a/c/f unspecified &&
		attr_check a/i unspecified &&
		attr_check subdir/a/i unspecified
	)
'

bad_attr_source_err="fatal: bad --attr-source or shit_ATTR_SOURCE"

test_expect_success '--attr-source is bad' '
	test_when_finished rm -rf empty &&
	shit init empty &&
	(
		cd empty &&
		echo "$bad_attr_source_err" >expect_err &&
		test_must_fail shit --attr-source=HEAD check-attr test -- f/path 2>err &&
		test_cmp expect_err err
	)
'

test_expect_success 'attr.tree when HEAD is unborn' '
	test_when_finished rm -rf empty &&
	shit init empty &&
	(
		cd empty &&
		echo "f/path: test: unspecified" >expect &&
		shit -c attr.tree=HEAD check-attr test -- f/path >actual 2>err &&
		test_must_be_empty err &&
		test_cmp expect actual
	)
'

test_expect_success 'bad attr source defaults to reading .shitattributes file' '
	test_when_finished rm -rf empty &&
	shit init empty &&
	(
		cd empty &&
		echo "f/path test=val" >.shitattributes &&
		echo "f/path: test: val" >expect &&
		shit -c attr.tree=HEAD check-attr test -- f/path >actual 2>err &&
		test_must_be_empty err &&
		test_cmp expect actual
	)
'

test_expect_success 'bare repo no longer defaults to reading .shitattributes from HEAD' '
	test_when_finished rm -rf test bare_with_shitattribute &&
	shit init test &&
	test_commit -C test shitattributes .shitattributes "f/path test=val" &&
	shit clone --bare test bare_with_shitattribute &&

	echo "f/path: test: unspecified" >expect &&
	shit -C bare_with_shitattribute check-attr test -- f/path >actual &&
	test_cmp expect actual &&

	echo "f/path: test: val" >expect &&
	shit -C bare_with_shitattribute -c attr.tree=HEAD \
		check-attr test -- f/path >actual &&
	test_cmp expect actual
'

test_expect_success 'precedence of --attr-source, shit_ATTR_SOURCE, then attr.tree' '
	test_when_finished rm -rf empty &&
	shit init empty &&
	(
		cd empty &&
		shit checkout -b attr-source &&
		test_commit "val1" .shitattributes "f/path test=val1" &&
		shit checkout -b attr-tree &&
		test_commit "val2" .shitattributes "f/path test=val2" &&
		shit checkout attr-source &&
		echo "f/path: test: val1" >expect &&
		shit_ATTR_SOURCE=attr-source shit -c attr.tree=attr-tree --attr-source=attr-source \
		check-attr test -- f/path >actual &&
		test_cmp expect actual &&
		shit_ATTR_SOURCE=attr-source shit -c attr.tree=attr-tree \
		check-attr test -- f/path >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'bare repository: with --source' '
	(
		cd bare.shit &&
		attr_check_source foo/bar/f f tag-1 &&
		attr_check_source foo/bar/a/i n tag-1 &&
		attr_check_source foo/bar/f unspecified tag-2 &&
		attr_check_source foo/bar/a/i m tag-2 &&
		attr_check_source foo/bar/g g tag-2 &&
		attr_check_source foo/bar/g unspecified tag-1
	)
'

test_expect_success 'bare repository: check that --cached honors index' '
	(
		cd bare.shit &&
		shit_INDEX_FILE=../.shit/index \
		shit check-attr --cached --stdin --all <../stdin-all |
		sort >actual &&
		test_cmp ../specified-all actual
	)
'

test_expect_success 'bare repository: test info/attributes' '
	(
		cd bare.shit &&
		mkdir info &&
		(
			echo "f	test=f" &&
			echo "a/i test=a/i"
		) >info/attributes &&
		attr_check f f &&
		attr_check a/f f &&
		attr_check a/c/f f &&
		attr_check a/i a/i &&
		attr_check subdir/a/i unspecified
	)
'

test_expect_success 'binary macro expanded by -a' '
	echo "file binary" >.shitattributes &&
	cat >expect <<-\EOF &&
	file: binary: set
	file: diff: unset
	file: merge: unset
	file: text: unset
	EOF
	shit check-attr -a file >actual &&
	test_cmp expect actual
'

test_expect_success 'query binary macro directly' '
	echo "file binary" >.shitattributes &&
	echo file: binary: set >expect &&
	shit check-attr binary file >actual &&
	test_cmp expect actual
'

test_expect_success SYMLINKS 'set up symlink tests' '
	echo "* test" >attr &&
	rm -f .shitattributes
'

test_expect_success SYMLINKS 'symlinks respected in core.attributesFile' '
	test_when_finished "rm symlink" &&
	ln -s attr symlink &&
	test_config core.attributesFile "$(pwd)/symlink" &&
	attr_check file set
'

test_expect_success SYMLINKS 'symlinks respected in info/attributes' '
	test_when_finished "rm .shit/info/attributes" &&
	mkdir .shit/info &&
	ln -s ../../attr .shit/info/attributes &&
	attr_check file set
'

test_expect_success SYMLINKS 'symlinks not respected in-tree' '
	test_when_finished "rm -rf .shitattributes subdir" &&
	ln -s attr .shitattributes &&
	mkdir subdir &&
	ln -s ../attr subdir/.shitattributes &&
	attr_check_basic subdir/file unspecified &&
	test_grep "unable to access.*shitattributes" err
'

test_expect_success 'large attributes line ignored in tree' '
	test_when_finished "rm .shitattributes" &&
	printf "path %02043d" 1 >.shitattributes &&
	shit check-attr --all path >actual 2>err &&
	echo "warning: ignoring overly long attributes line 1" >expect &&
	test_cmp expect err &&
	test_must_be_empty actual
'

test_expect_success 'large attributes line ignores trailing content in tree' '
	test_when_finished "rm .shitattributes" &&
	# older versions of shit broke lines at 2048 bytes; the 2045 bytes
	# of 0-padding here is accounting for the three bytes of "a 1", which
	# would knock "trailing" to the "next" line, where it would be
	# erroneously parsed.
	printf "a %02045dtrailing attribute\n" 1 >.shitattributes &&
	shit check-attr --all trailing >actual 2>err &&
	echo "warning: ignoring overly long attributes line 1" >expect &&
	test_cmp expect err &&
	test_must_be_empty actual
'

test_expect_success EXPENSIVE 'large attributes file ignored in tree' '
	test_when_finished "rm .shitattributes" &&
	dd if=/dev/zero of=.shitattributes bs=1048576 count=101 2>/dev/null &&
	shit check-attr --all path >/dev/null 2>err &&
	echo "warning: ignoring overly large shitattributes file ${SQ}.shitattributes${SQ}" >expect &&
	test_cmp expect err
'

test_expect_success 'large attributes line ignored in index' '
	test_when_finished "shit update-index --remove .shitattributes" &&
	blob=$(printf "path %02043d" 1 | shit hash-object -w --stdin) &&
	shit update-index --add --cacheinfo 100644,$blob,.shitattributes &&
	shit check-attr --cached --all path >actual 2>err &&
	echo "warning: ignoring overly long attributes line 1" >expect &&
	test_cmp expect err &&
	test_must_be_empty actual
'

test_expect_success 'large attributes line ignores trailing content in index' '
	test_when_finished "shit update-index --remove .shitattributes" &&
	blob=$(printf "a %02045dtrailing attribute\n" 1 | shit hash-object -w --stdin) &&
	shit update-index --add --cacheinfo 100644,$blob,.shitattributes &&
	shit check-attr --cached --all trailing >actual 2>err &&
	echo "warning: ignoring overly long attributes line 1" >expect &&
	test_cmp expect err &&
	test_must_be_empty actual
'

test_expect_success EXPENSIVE 'large attributes file ignored in index' '
	test_when_finished "shit update-index --remove .shitattributes" &&
	blob=$(dd if=/dev/zero bs=1048576 count=101 2>/dev/null | shit hash-object -w --stdin) &&
	shit update-index --add --cacheinfo 100644,$blob,.shitattributes &&
	shit check-attr --cached --all path >/dev/null 2>err &&
	echo "warning: ignoring overly large shitattributes blob ${SQ}.shitattributes${SQ}" >expect &&
	test_cmp expect err
'

test_expect_success EXPENSIVE 'large attributes blob ignored' '
	test_when_finished "shit update-index --remove .shitattributes" &&
	blob=$(dd if=/dev/zero bs=1048576 count=101 2>/dev/null | shit hash-object -w --stdin) &&
	shit update-index --add --cacheinfo 100644,$blob,.shitattributes &&
	tree="$(shit write-tree)" &&
	shit check-attr --cached --all --source="$tree" path >/dev/null 2>err &&
	echo "warning: ignoring overly large shitattributes blob ${SQ}.shitattributes${SQ}" >expect &&
	test_cmp expect err
'

test_expect_success 'builtin object mode attributes work (dir and regular paths)' '
	>normal &&
	attr_check_object_mode normal 100644 &&
	mkdir dir &&
	attr_check_object_mode dir 040000
'

test_expect_success POSIXPERM 'builtin object mode attributes work (executable)' '
	>exec &&
	chmod +x exec &&
	attr_check_object_mode exec 100755
'

test_expect_success SYMLINKS 'builtin object mode attributes work (symlinks)' '
	ln -s to_sym sym &&
	attr_check_object_mode sym 120000
'

test_expect_success 'native object mode attributes work with --cached' '
	>normal &&
	shit add normal &&
	empty_blob=$(shit rev-parse :normal) &&
	shit update-index --index-info <<-EOF &&
	100755 $empty_blob 0	exec
	120000 $empty_blob 0	symlink
	EOF
	attr_check_object_mode normal 100644 --cached &&
	attr_check_object_mode exec 100755 --cached &&
	attr_check_object_mode symlink 120000 --cached
'

test_expect_success 'check object mode attributes work for submodules' '
	mkdir sub &&
	(
		cd sub &&
		shit init &&
		mv .shit .real &&
		echo "shitdir: .real" >.shit &&
		test_commit first
	) &&
	attr_check_object_mode sub 160000 &&
	attr_check_object_mode sub unspecified --cached &&
	shit add sub &&
	attr_check_object_mode sub 160000 --cached
'

test_expect_success 'we do not allow user defined builtin_* attributes' '
	echo "foo* builtin_foo" >.shitattributes &&
	shit add .shitattributes 2>actual &&
	echo "builtin_foo is not a valid attribute name: .shitattributes:1" >expect &&
	test_cmp expect actual
'

test_expect_success 'user defined builtin_objectmode values are ignored' '
	echo "foo* builtin_objectmode=12345" >.shitattributes &&
	shit add .shitattributes &&
	>foo_1 &&
	attr_check_object_mode_basic foo_1 100644 &&
	echo "builtin_objectmode is not a valid attribute name: .shitattributes:1" >expect &&
	test_cmp expect err
'

test_done
