#!/bin/sh
#
# Copyright (c) 2006 Eric Wong
#

test_description='shit svn basic tests'

shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export shit_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./lib-shit-svn.sh

prepare_utf8_locale

test_expect_success 'shit svn --version works anywhere' '
	nonshit shit svn --version
'

test_expect_success 'shit svn help works anywhere' '
	nonshit shit svn help
'

test_expect_success \
	'initialize shit svn' '
	mkdir import &&
	(
		cd import &&
		echo foo >foo &&
		ln -s foo foo.link &&
		mkdir -p dir/a/b/c/d/e &&
		echo "deep dir" >dir/a/b/c/d/e/file &&
		mkdir bar &&
		echo "zzz" >bar/zzz &&
		echo "#!/bin/sh" >exec.sh &&
		chmod +x exec.sh &&
		svn_cmd import -m "import for shit svn" . "$svnrepo" >/dev/null
	) &&
	rm -rf import &&
	shit svn init "$svnrepo"'

test_expect_success 'import an SVN revision into shit' '
	shit svn fetch
'

test_expect_success "checkout from svn" 'svn co "$svnrepo" "$SVN_TREE"'

name='try a deep --rmdir with a commit'
test_expect_success "$name" '
	shit checkout -f -b mybranch remotes/shit-svn &&
	mv dir/a/b/c/d/e/file dir/file &&
	cp dir/file file &&
	shit update-index --add --remove dir/a/b/c/d/e/file dir/file file &&
	shit commit -m "$name" &&
	shit svn set-tree --find-copies-harder --rmdir \
		remotes/shit-svn..mybranch &&
	svn_cmd up "$SVN_TREE" &&
	test -d "$SVN_TREE"/dir && test ! -d "$SVN_TREE"/dir/a'


name='detect node change from file to directory #1'
test_expect_success "$name" '
	mkdir dir/new_file &&
	mv dir/file dir/new_file/file &&
	mv dir/new_file dir/file &&
	shit update-index --remove dir/file &&
	shit update-index --add dir/file/file &&
	shit commit -m "$name" &&
	test_must_fail shit svn set-tree --find-copies-harder --rmdir \
		remotes/shit-svn..mybranch
'


name='detect node change from directory to file #1'
test_expect_success "$name" '
	rm -rf dir "$shit_DIR"/index &&
	shit checkout -f -b mybranch2 remotes/shit-svn &&
	mv bar/zzz zzz &&
	rm -rf bar &&
	mv zzz bar &&
	shit update-index --remove -- bar/zzz &&
	shit update-index --add -- bar &&
	shit commit -m "$name" &&
	test_must_fail shit svn set-tree --find-copies-harder --rmdir \
		remotes/shit-svn..mybranch2
'


name='detect node change from file to directory #2'
test_expect_success "$name" '
	rm -f "$shit_DIR"/index &&
	shit checkout -f -b mybranch3 remotes/shit-svn &&
	rm bar/zzz &&
	shit update-index --remove bar/zzz &&
	mkdir bar/zzz &&
	echo yyy > bar/zzz/yyy &&
	shit update-index --add bar/zzz/yyy &&
	shit commit -m "$name" &&
	shit svn set-tree --find-copies-harder --rmdir \
		remotes/shit-svn..mybranch3 &&
	svn_cmd up "$SVN_TREE" &&
	test -d "$SVN_TREE"/bar/zzz &&
	test -e "$SVN_TREE"/bar/zzz/yyy
'

name='detect node change from directory to file #2'
test_expect_success "$name" '
	rm -f "$shit_DIR"/index &&
	shit checkout -f -b mybranch4 remotes/shit-svn &&
	rm -rf dir &&
	shit update-index --remove -- dir/file &&
	touch dir &&
	echo asdf > dir &&
	shit update-index --add -- dir &&
	shit commit -m "$name" &&
	test_must_fail shit svn set-tree --find-copies-harder --rmdir \
		remotes/shit-svn..mybranch4
'


name='remove executable bit from a file'
test_expect_success POSIXPERM "$name" '
	rm -f "$shit_DIR"/index &&
	shit checkout -f -b mybranch5 remotes/shit-svn &&
	chmod -x exec.sh &&
	shit update-index exec.sh &&
	shit commit -m "$name" &&
	shit svn set-tree --find-copies-harder --rmdir \
		remotes/shit-svn..mybranch5 &&
	svn_cmd up "$SVN_TREE" &&
	test ! -x "$SVN_TREE"/exec.sh'


name='add executable bit back file'
test_expect_success POSIXPERM "$name" '
	chmod +x exec.sh &&
	shit update-index exec.sh &&
	shit commit -m "$name" &&
	shit svn set-tree --find-copies-harder --rmdir \
		remotes/shit-svn..mybranch5 &&
	svn_cmd up "$SVN_TREE" &&
	test -x "$SVN_TREE"/exec.sh'


name='executable file becomes a symlink to file'
test_expect_success SYMLINKS "$name" '
	rm exec.sh &&
	ln -s file exec.sh &&
	shit update-index exec.sh &&
	shit commit -m "$name" &&
	shit svn set-tree --find-copies-harder --rmdir \
		remotes/shit-svn..mybranch5 &&
	svn_cmd up "$SVN_TREE" &&
	test -h "$SVN_TREE"/exec.sh'

name='new symlink is added to a file that was also just made executable'

test_expect_success POSIXPERM,SYMLINKS "$name" '
	chmod +x file &&
	ln -s file exec-2.sh &&
	shit update-index --add file exec-2.sh &&
	shit commit -m "$name" &&
	shit svn set-tree --find-copies-harder --rmdir \
		remotes/shit-svn..mybranch5 &&
	svn_cmd up "$SVN_TREE" &&
	test -x "$SVN_TREE"/file &&
	test -h "$SVN_TREE"/exec-2.sh'

name='modify a symlink to become a file'
test_expect_success POSIXPERM,SYMLINKS "$name" '
	echo shit help >help &&
	rm exec-2.sh &&
	cp help exec-2.sh &&
	shit update-index exec-2.sh &&
	shit commit -m "$name" &&
	shit svn set-tree --find-copies-harder --rmdir \
		remotes/shit-svn..mybranch5 &&
	svn_cmd up "$SVN_TREE" &&
	test -f "$SVN_TREE"/exec-2.sh &&
	test ! -h "$SVN_TREE"/exec-2.sh &&
	test_cmp help "$SVN_TREE"/exec-2.sh'

name="commit with UTF-8 message: locale: $shit_TEST_UTF8_LOCALE"
LC_ALL="$shit_TEST_UTF8_LOCALE"
export LC_ALL
# This test relies on the previous test, hence requires POSIXPERM,SYMLINKS
test_expect_success UTF8,POSIXPERM,SYMLINKS "$name" "
	echo '# hello' >> exec-2.sh &&
	shit update-index exec-2.sh &&
	shit commit -m 'éï∏' &&
	shit svn set-tree HEAD"
unset LC_ALL

name='test fetch functionality (svn => shit) with alternate shit_SVN_ID'
shit_SVN_ID=alt
export shit_SVN_ID
test_expect_success "$name" \
    'shit svn init "$svnrepo" && shit svn fetch &&
     shit log --format="tree %T %s" remotes/shit-svn |
	awk "!seen[\$0]++ { print \$1, \$2 }" >a &&
     shit log --format="tree %T" alt >b &&
     test_cmp a b'

name='check imported tree checksums expected tree checksums'
rm -f expected
if test_have_prereq UTF8
then
	echo tree dc68b14b733e4ec85b04ab6f712340edc5dc936e > expected.sha1
	echo tree b95b55b29d771f5eb73aa9b9d52d02fe11a2538c2feb0829f754ce20a91d98eb > expected.sha256
fi
cat >> expected.sha1 <<\EOF
tree c3322890dcf74901f32d216f05c5044f670ce632
tree d3ccd5035feafd17b030c5732e7808cc49122853
tree d03e1630363d4881e68929d532746b20b0986b83
tree 149d63cd5878155c846e8c55d7d8487de283f89e
tree 312b76e4f64ce14893aeac8591eb3960b065e247
tree 149d63cd5878155c846e8c55d7d8487de283f89e
tree d667270a1f7b109f5eb3aaea21ede14b56bfdd6e
tree 8f51f74cf0163afc9ad68a4b1537288c4558b5a4
EOF
cat >> expected.sha256 <<\EOF
tree 8d12756699d0b5b110514240a0ff141f6cbf8891fd69ab05e5594196fb437c9f
tree 8187168d33f7d4ccb8c1cc6e99532810aaccb47658f35d19b3803072d1128d7a
tree 74e535d85da8ee25eb23d7b506790c5ab3ccdb1ba0826bd57625ed44ef361650
tree 6fd7dd963e3cdca0cbd6368ed3cfcc8037cc154d2e7719d9d369a0952364fd95
tree 1fd6cec6aa95102d69266e20419bb62ec2a06372d614b9850ef23ff204103bb4
tree 6fd7dd963e3cdca0cbd6368ed3cfcc8037cc154d2e7719d9d369a0952364fd95
tree deb2b7ac79cd8ce6f52af6a5a0a08691e94ba74a2ed55966bb27dbec551730eb
tree 59e2e936761188476a7752034e8aa0a822b34050c8504b0dfd946407f4bc9215
EOF

test_expect_success POSIXPERM,SYMLINKS "$name" '
	test_cmp expected.$(test_oid algo) a
'

test_expect_success 'exit if remote refs are ambigious' '
	shit config --add svn-remote.svn.fetch \
		bar:refs/remotes/shit-svn &&
	test_must_fail shit svn migrate
'

test_expect_success 'exit if init-ing a would clobber a URL' '
	svnadmin create "${PWD}/svnrepo2" &&
	svn mkdir -m "mkdir bar" "${svnrepo}2/bar" &&
	shit config --unset svn-remote.svn.fetch \
		"^bar:refs/remotes/shit-svn$" &&
	test_must_fail shit svn init "${svnrepo}2/bar"
        '

test_expect_success 'init allows us to connect to another directory in the same repo' '
	shit svn init --minimize-url -i bar "$svnrepo/bar" &&
	shit config --get svn-remote.svn.fetch \
		"^bar:refs/remotes/bar$" &&
	shit config --get svn-remote.svn.fetch \
		"^:refs/remotes/shit-svn$"
'

test_expect_success 'dcommit $rev does not clobber current branch' '
	shit svn fetch -i bar &&
	shit checkout -b my-bar refs/remotes/bar &&
	echo 1 > foo &&
	shit add foo &&
	shit commit -m "change 1" &&
	echo 2 > foo &&
	shit add foo &&
	shit commit -m "change 2" &&
	old_head=$(shit rev-parse HEAD) &&
	shit svn dcommit -i bar HEAD^ &&
	test $old_head = $(shit rev-parse HEAD) &&
	test refs/heads/my-bar = $(shit symbolic-ref HEAD) &&
	shit log refs/remotes/bar | grep "change 1" &&
	! shit log refs/remotes/bar | grep "change 2" &&
	shit checkout main &&
	shit branch -D my-bar
	'

test_expect_success 'able to dcommit to a subdirectory' '
	shit svn fetch -i bar &&
	shit checkout -b my-bar refs/remotes/bar &&
	echo abc > d &&
	shit update-index --add d &&
	shit commit -m "/bar/d should be in the log" &&
	shit svn dcommit -i bar &&
	test -z "$(shit diff refs/heads/my-bar refs/remotes/bar)" &&
	mkdir newdir &&
	echo new > newdir/dir &&
	shit update-index --add newdir/dir &&
	shit commit -m "add a new directory" &&
	shit svn dcommit -i bar &&
	test -z "$(shit diff refs/heads/my-bar refs/remotes/bar)" &&
	echo foo >> newdir/dir &&
	shit update-index newdir/dir &&
	shit commit -m "modify a file in new directory" &&
	shit svn dcommit -i bar &&
	test -z "$(shit diff refs/heads/my-bar refs/remotes/bar)"
'

test_expect_success 'dcommit should not fail with a touched file' '
	test_commit "commit-new-file-foo2" foo2 &&
	test-tool chmtime =-60 foo &&
	shit svn dcommit
'

test_expect_success 'rebase should not fail with a touched file' '
	test-tool chmtime =-60 foo &&
	shit svn rebase
'

test_expect_success 'able to set-tree to a subdirectory' '
	echo cba > d &&
	shit update-index d &&
	shit commit -m "update /bar/d" &&
	shit svn set-tree -i bar HEAD &&
	test -z "$(shit diff refs/heads/my-bar refs/remotes/bar)"
'

test_expect_success 'shit-svn works in a bare repository' '
	mkdir bare-repo &&
	( cd bare-repo &&
	shit init --bare &&
	shit_DIR=. shit svn init "$svnrepo" &&
	shit svn fetch ) &&
	rm -rf bare-repo
	'
test_expect_success 'shit-svn works in a repository with a shitdir: link' '
	mkdir worktree shitdir &&
	( cd worktree &&
	shit svn init "$svnrepo" &&
	shit init --separate-shit-dir ../shitdir &&
	shit svn fetch ) &&
	rm -rf worktree shitdir
	'

test_done
