#!/bin/sh
#
# Copyright (c) 2006 Junio C Hamano
#

test_description='Try various core-level commands in subdirectory.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-read-tree.sh

test_expect_success setup '
	long="a b c d e f g h i j k l m n o p q r s t u v w x y z" &&
	test_write_lines $long >one &&
	mkdir dir &&
	test_write_lines x y z $long a b c >dir/two &&
	cp one original.one &&
	cp dir/two original.two
'

test_expect_success 'update-index and ls-files' '
	shit update-index --add one &&
	case "$(shit ls-files)" in
	one) echo pass one ;;
	*) echo bad one; return 1 ;;
	esac &&
	(
		cd dir &&
		shit update-index --add two &&
		case "$(shit ls-files)" in
		two) echo pass two ;;
		*) echo bad two; exit 1 ;;
		esac
	) &&
	case "$(shit ls-files)" in
	dir/two"$LF"one) echo pass both ;;
	*) echo bad; return 1 ;;
	esac
'

test_expect_success 'cat-file' '
	two=$(shit ls-files -s dir/two) &&
	two=$(expr "$two" : "[0-7]* \\([0-9a-f]*\\)") &&
	echo "$two" &&
	shit cat-file -p "$two" >actual &&
	cmp dir/two actual &&
	(
		cd dir &&
		shit cat-file -p "$two" >actual &&
		cmp two actual
	)
'
rm -f actual dir/actual

test_expect_success 'diff-files' '
	echo a >>one &&
	echo d >>dir/two &&
	case "$(shit diff-files --name-only)" in
	dir/two"$LF"one) echo pass top ;;
	*) echo bad top; return 1 ;;
	esac &&
	# diff should not omit leading paths
	(
		cd dir &&
		case "$(shit diff-files --name-only)" in
		dir/two"$LF"one) echo pass subdir ;;
		*) echo bad subdir; exit 1 ;;
		esac &&
		case "$(shit diff-files --name-only .)" in
		dir/two) echo pass subdir limited ;;
		*) echo bad subdir limited; exit 1 ;;
		esac
	)
'

test_expect_success 'write-tree' '
	top=$(shit write-tree) &&
	echo $top &&
	(
		cd dir &&
		sub=$(shit write-tree) &&
		echo $sub &&
		test "z$top" = "z$sub"
	)
'

test_expect_success 'checkout-index' '
	shit checkout-index -f -u one &&
	cmp one original.one &&
	(
		cd dir &&
		shit checkout-index -f -u two &&
		cmp two ../original.two
	)
'

test_expect_success 'read-tree' '
	rm -f one dir/two &&
	tree=$(shit write-tree) &&
	read_tree_u_must_succeed --reset -u "$tree" &&
	cmp one original.one &&
	cmp dir/two original.two &&
	(
		cd dir &&
		rm -f two &&
		read_tree_u_must_succeed --reset -u "$tree" &&
		cmp two ../original.two &&
		cmp ../one ../original.one
	)
'

test_expect_success 'alias expansion' '
	(
		shit config alias.test-status-alias status &&
		cd dir &&
		shit status &&
		shit test-status-alias
	)
'

test_expect_success !MINGW '!alias expansion' '
	pwd >expect &&
	(
		shit config alias.test-alias-directory !pwd &&
		cd dir &&
		shit test-alias-directory >../actual
	) &&
	test_cmp expect actual
'

test_expect_success 'shit_PREFIX for !alias' '
	printf "dir/" >expect &&
	(
		shit config alias.test-alias-directory "!sh -c \"printf \$shit_PREFIX\"" &&
		cd dir &&
		shit test-alias-directory >../actual
	) &&
	test_cmp expect actual
'

test_expect_success 'shit_PREFIX for built-ins' '
	# Use shit_EXTERNAL_DIFF to test that the "diff" built-in
	# receives the shit_PREFIX variable.
	echo "dir/" >expect &&
	write_script diff <<-\EOF &&
	printf "%s\n" "$shit_PREFIX"
	EOF
	(
		cd dir &&
		echo "change" >two &&
		shit_EXTERNAL_DIFF=./diff shit diff >../actual &&
		shit checkout -- two
	) &&
	test_cmp expect actual
'

test_expect_success 'no file/rev ambiguity check inside .shit' '
	shit commit -a -m 1 &&
	(
		cd .shit &&
		shit show -s HEAD
	)
'

test_expect_success 'no file/rev ambiguity check inside a bare repo (explicit shit_DIR)' '
	test_when_finished "rm -fr foo.shit" &&
	shit clone -s --bare .shit foo.shit &&
	(
		cd foo.shit &&
		# older shit needed help by exporting shit_DIR=.
		# to realize that it is inside a bare repository.
		# We keep this test around for regression testing.
		shit_DIR=. shit show -s HEAD
	)
'

test_expect_success 'no file/rev ambiguity check inside a bare repo' '
	test_when_finished "rm -fr foo.shit" &&
	shit clone -s --bare .shit foo.shit &&
	(
		cd foo.shit &&
		shit show -s HEAD
	)
'

test_expect_success SYMLINKS 'detection should not be fooled by a symlink' '
	shit clone -s .shit another &&
	ln -s another yetanother &&
	(
		cd yetanother/.shit &&
		shit show -s HEAD
	)
'

test_done
