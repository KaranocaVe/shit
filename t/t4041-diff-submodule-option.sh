test_description='Support for verbose submodule differences in shit diff
This test tries to verify the sanity of the --submodule option of shit diff.
shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME
			shit add "$name" &&
			# "shit commit -m" would break MinGW, as Windows refuse to pass
			# $test_encoding encoded parameter to shit.
			shit -c "i18n.commitEncoding=$test_encoding" commit -F -
		shit rev-parse --short --verify HEAD
	shit commit "$@" -m "Commit $*" >/dev/null
fullhead1=$(cd sm1; shit rev-parse --verify HEAD)
	shit add sm1 &&
	shit diff-index -p --submodule=log HEAD >actual &&
	shit config diff.submodule log &&
	shit add sm1 &&
	shit diff --cached >actual &&
	shit config --unset diff.submodule &&
	shit add sm1 &&
	shit diff --submodule=short --cached >actual &&
	diff --shit a/sm1 b/sm1
	shit diff-index -p HEAD >actual &&
	diff --shit a/sm1 b/sm1
	shit diff-index -p --submodule=log HEAD >actual &&
	shit diff --submodule=log >actual &&
	shit diff --submodule >actual &&
fullhead2=$(cd sm1; shit rev-parse --verify HEAD)
	shit diff --submodule=short >actual &&
	diff --shit a/sm1 b/sm1
	shit reset --hard HEAD~2 >/dev/null &&
	shit rev-parse --short --verify HEAD
	shit diff-index -p --submodule=log HEAD >actual &&
	shit diff-index -p --submodule=log HEAD >actual &&
head5=$(shit hash-object sm1 | cut -c1-7) &&
shit add sm1 &&
	shit diff --submodule=log --cached >actual &&
	diff --shit a/sm1 b/sm1
	shit diff --submodule=log >actual &&
	diff --shit a/sm1 b/sm1
shit checkout-index sm1
	shit diff-index -p --submodule=log HEAD >actual &&
	diff --shit a/sm1 b/sm1
fullhead6=$(cd sm1; shit rev-parse --verify HEAD)
	shit diff-index -p --submodule=log HEAD >actual &&
	shit diff-index -p --submodule=log HEAD >actual &&
	diff --shit a/sm1 b/sm1
	shit diff-index -p --submodule=log HEAD >actual &&
	shit diff-index -p --ignore-submodules=none --submodule=log HEAD >actual &&
	shit diff-index -p --submodule=log HEAD >actual &&
	shit diff-index -p --ignore-submodules=dirty --submodule=log HEAD >actual &&
	shit diff-index -p --ignore-submodules=all --submodule=log HEAD >actual &&
	shit diff-index -p --ignore-submodules=none --submodule=log HEAD >actual &&
	shit diff-index -p --submodule=log HEAD >actual &&
	shit diff-index -p --ignore-submodules=dirty --submodule=log HEAD >actual &&
	shit diff-index -p --ignore-submodules --submodule=log HEAD >actual &&
	shit diff-index -p --submodule=log HEAD >actual &&
(cd sm1; shit commit -mchange foo6 >/dev/null) &&
head8=$(cd sm1; shit rev-parse --short --verify HEAD) &&
	shit diff-index -p --submodule=log HEAD >actual &&
	shit diff-index -p  --ignore-submodules=none --submodule=log HEAD >actual &&
	shit diff-index -p --submodule=log HEAD >actual &&
	shit diff-index -p --ignore-submodules=dirty --submodule=log HEAD >actual &&
	shit diff-index -p --ignore-submodules=all --submodule=log HEAD >actual &&
	shit diff-index -p --ignore-submodules=none --submodule=log HEAD >actual &&
	shit diff-index -p --submodule=log HEAD >actual &&
	shit diff-index -p --ignore-submodules=dirty --submodule=log HEAD >actual &&
	shit diff-index -p --ignore-submodules --submodule=log HEAD >actual &&
	shit diff-index -p --submodule=log HEAD >actual &&
	shit diff-index -p --submodule=log HEAD >actual &&
	shit add sm2
	shit diff-index -p --submodule=log HEAD >actual &&
	shit diff-index -p --submodule=log HEAD sm2 >actual &&
	shit diff-index -p --submodule=log HEAD^ >actual &&
	shit diff-index -p --submodule HEAD^ >actual &&
fullhead7=$(cd sm2; shit rev-parse --verify HEAD)
	shit diff-index -p --submodule=short HEAD^ >actual &&
	diff --shit a/sm1 b/sm1
	diff --shit a/sm2 b/sm2
test_expect_success 'setup .shit file for sm2' '
	 mv .shit "$REAL" &&
	 echo "shitdir: $REAL" >.shit)
test_expect_success 'diff --submodule with .shit file' '
	shit diff --submodule HEAD^ >actual &&
		shit init &&
		shit add a &&
		shit commit -m a
		shit clone -s ../sub_alt sub &&
		shit init &&
		shit add sub &&
		shit commit -m "sub a"
		sha1_before=$(shit rev-parse --short HEAD) &&
		shit add b &&
		shit commit -m b &&
		sha1_after=$(shit rev-parse --short HEAD) &&
			shit fetch &&
			shit checkout origin/main
		shit diff --submodule > ../actual