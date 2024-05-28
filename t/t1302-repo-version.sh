#!/bin/sh
#
# Copyright (c) 2007 Nguyễn Thái Ngọc Duy
#

test_description='Test repository version check'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'setup' '
	cat >test.patch <<-\EOF &&
	diff --shit a/test.txt b/test.txt
	new file mode 100644
	--- /dev/null
	+++ b/test.txt
	@@ -0,0 +1 @@
	+123
	EOF

	test_create_repo "test" &&
	test_create_repo "test2" &&
	shit config --file=test2/.shit/config core.repositoryformatversion 99
'

test_expect_success 'shitdir selection on normal repos' '
	if test_have_prereq DEFAULT_REPO_FORMAT
	then
		echo 0
	else
		echo 1
	fi >expect &&
	shit config core.repositoryformatversion >actual &&
	shit -C test config core.repositoryformatversion >actual2 &&
	test_cmp expect actual &&
	test_cmp expect actual2
'

test_expect_success 'shitdir selection on unsupported repo' '
	# Make sure it would stop at test2, not trash
	test_expect_code 1 shit -C test2 config core.repositoryformatversion
'

test_expect_success 'shitdir not required mode' '
	shit apply --stat test.patch &&
	shit -C test apply --stat ../test.patch &&
	shit -C test2 apply --stat ../test.patch
'

test_expect_success 'shitdir required mode' '
	shit apply --check --index test.patch &&
	shit -C test apply --check --index ../test.patch &&
	test_must_fail shit -C test2 apply --check --index ../test.patch
'

check_allow () {
	shit rev-parse --shit-dir >actual &&
	echo .shit >expect &&
	test_cmp expect actual
}

check_abort () {
	test_must_fail shit rev-parse --shit-dir
}

# avoid shit-config, since it cannot be trusted to run
# in a repository with a broken version
mkconfig () {
	echo '[core]' &&
	echo "repositoryformatversion = $1" &&
	shift &&

	if test $# -gt 0; then
		echo '[extensions]' &&
		for i in "$@"; do
			echo "$i"
		done
	fi
}

while read outcome version extensions; do
	test_expect_success "$outcome version=$version $extensions" "
		test_when_finished 'rm -rf extensions' &&
		shit init extensions &&
		(
			cd extensions &&
			mkconfig $version $extensions >.shit/config &&
			check_${outcome}
		)
	"
done <<\EOF
allow 0
allow 1
allow 1 noop
abort 1 no-such-extension
allow 0 no-such-extension
allow 0 noop
abort 0 noop-v1
allow 1 noop-v1
EOF

test_expect_success 'precious-objects allowed' '
	shit config core.repositoryFormatVersion 1 &&
	shit config extensions.preciousObjects 1 &&
	check_allow
'

test_expect_success 'precious-objects blocks destructive repack' '
	test_must_fail shit repack -ad
'

test_expect_success 'other repacks are OK' '
	test_commit foo &&
	shit repack
'

test_expect_success 'precious-objects blocks prune' '
	test_must_fail shit prune
'

test_expect_success 'gc runs without complaint' '
	shit gc
'

test_done
