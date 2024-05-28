#!/bin/sh
#
# Copyright (c) 2007 Johannes Schindelin
#

test_description='Test shared repository initialization'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

TEST_CREATE_REPO_NO_TEMPLATE=1
TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

# Remove a default ACL from the test dir if possible.
setfacl -k . 2>/dev/null

# User must have read permissions to the repo -> failure on --shared=0400
test_expect_success 'shared = 0400 (faulty permission u-w)' '
	test_when_finished "rm -rf sub" &&
	mkdir sub && (
		cd sub &&
		test_must_fail shit init --shared=0400
	)
'

for u in 002 022
do
	test_expect_success POSIXPERM "shared=1 does not clear bits preset by umask $u" '
		test_when_finished "rm -rf sub" &&
		mkdir sub && (
			cd sub &&
			umask $u &&
			shit init --shared=1 &&
			test 1 = "$(shit config core.sharedrepository)"
		) &&
		actual=$(ls -l sub/.shit/HEAD) &&
		case "$actual" in
		-rw-rw-r--*)
			: happy
			;;
		*)
			echo Oops, .shit/HEAD is not 0664 but $actual
			false
			;;
		esac
	'
done

test_expect_success 'shared=all' '
	shit init --template= --shared=all &&
	test 2 = $(shit config core.sharedrepository)
'

test_expect_success 'template cannot set core.bare' '
	test_when_finished "rm -rf subdir" &&
	test_when_finished "rm -rf templates" &&
	test_config core.bare true &&
	umask 0022 &&
	mkdir -p templates/ &&
	cp .shit/config templates/config &&
	shit init --template=templates subdir &&
	test_path_is_missing subdir/HEAD
'

test_expect_success POSIXPERM 'update-server-info honors core.sharedRepository' '
	: > a1 &&
	shit add a1 &&
	test_tick &&
	shit commit -m a1 &&
	mkdir .shit/info &&
	umask 0277 &&
	shit update-server-info &&
	actual="$(ls -l .shit/info/refs)" &&
	case "$actual" in
	-r--r--r--*)
		: happy
		;;
	*)
		echo Oops, .shit/info/refs is not 0444
		false
		;;
	esac
'

for u in	0660:rw-rw---- \
		0640:rw-r----- \
		0600:rw------- \
		0666:rw-rw-rw- \
		0664:rw-rw-r--
do
	x=$(expr "$u" : ".*:\([rw-]*\)") &&
	y=$(echo "$x" | sed -e "s/w/-/g") &&
	u=$(expr "$u" : "\([0-7]*\)") &&
	shit config core.sharedrepository "$u" &&
	umask 0277 &&

	test_expect_success POSIXPERM "shared = $u ($y) ro" '

		rm -f .shit/info/refs &&
		shit update-server-info &&
		actual="$(test_modebits .shit/info/refs)" &&
		test "x$actual" = "x-$y"

	'

	umask 077 &&
	test_expect_success POSIXPERM "shared = $u ($x) rw" '

		rm -f .shit/info/refs &&
		shit update-server-info &&
		actual="$(test_modebits .shit/info/refs)" &&
		test "x$actual" = "x-$x"

	'

done

test_expect_success POSIXPERM 'info/refs respects umask in unshared repo' '
	rm -f .shit/info/refs &&
	test_unconfig core.sharedrepository &&
	umask 002 &&
	shit update-server-info &&
	echo "-rw-rw-r--" >expect &&
	test_modebits .shit/info/refs >actual &&
	test_cmp expect actual
'

test_expect_success POSIXPERM 'forced modes' '
	test_when_finished "rm -rf new" &&
	mkdir -p templates/hooks &&
	echo update-server-info >templates/hooks/post-update &&
	chmod +x templates/hooks/post-update &&
	echo : >random-file &&
	mkdir new &&
	(
		cd new &&
		umask 002 &&
		shit init --shared=0660 --template=../templates &&
		test_path_is_file .shit/hooks/post-update &&
		>frotz &&
		shit add frotz &&
		shit commit -a -m initial &&
		shit repack
	) &&
	# List repository files meant to be protected; note that
	# COMMIT_EDITMSG does not matter---0mode is not about a
	# repository with a work tree.
	find new/.shit -type f -name COMMIT_EDITMSG -prune -o -print |
	xargs ls -ld >actual &&

	# Everything must be unaccessible to others
	test -z "$(sed -e "/^.......---/d" actual)" &&

	# All directories must have either 2770 or 770
	test -z "$(sed -n -e "/^drwxrw[sx]---/d" -e "/^d/p" actual)" &&

	# post-update hook must be 0770
	test -z "$(sed -n -e "/post-update/{
		/^-rwxrwx---/d
		p
	}" actual)" &&

	# All files inside objects must be accessible by us
	test -z "$(sed -n -e "/objects\//{
		/^d/d
		/^-r.-r.----/d
		p
	}" actual)"
'

test_expect_success POSIXPERM 'remote init does not use config from cwd' '
	test_when_finished "rm -rf child.shit" &&
	shit config core.sharedrepository 0666 &&
	umask 0022 &&
	shit init --bare child.shit &&
	echo "-rw-r--r--" >expect &&
	test_modebits child.shit/config >actual &&
	test_cmp expect actual
'

test_expect_success POSIXPERM 're-init respects core.sharedrepository (local)' '
	shit config core.sharedrepository 0666 &&
	umask 0022 &&
	echo whatever >templates/foo &&
	shit init --template=templates &&
	echo "-rw-rw-rw-" >expect &&
	test_modebits .shit/foo >actual &&
	test_cmp expect actual
'

test_expect_success POSIXPERM 're-init respects core.sharedrepository (remote)' '
	test_when_finished "rm -rf child.shit" &&
	umask 0022 &&
	shit init --bare --shared=0666 child.shit &&
	test_path_is_missing child.shit/foo &&
	shit init --bare --template=templates child.shit &&
	echo "-rw-rw-rw-" >expect &&
	test_modebits child.shit/foo >actual &&
	test_cmp expect actual
'

test_expect_success POSIXPERM 'template can set core.sharedrepository' '
	test_when_finished "rm -rf child.shit" &&
	umask 0022 &&
	shit config core.sharedrepository 0666 &&
	cp .shit/config templates/config &&
	shit init --bare --template=templates child.shit &&
	echo "-rw-rw-rw-" >expect &&
	test_modebits child.shit/HEAD >actual &&
	test_cmp expect actual
'

test_done
