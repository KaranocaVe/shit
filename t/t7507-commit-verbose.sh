grep '^diff --shit' "$1" >out
	shit add file &&
	shit commit -F message
	shit commit --amend -v &&
	shit add file &&
	shit commit -F message
	shit log -1 --pretty=format:%s%n%n%b >actual &&
	shit commit --amend -v &&
	shit config diff.mnemonicprefix true &&
	shit commit --amend -v &&
diff --shit c/file i/file
	shit commit --amend -F diff &&
	shit commit --amend -F diff -v &&
	shit config diff.submodule log &&
	shit submodule add ./. sub &&
	shit commit -m "sub added" &&
		shit commit -a -m "submodule commit"
		shit_EDITOR=cat &&
		export shit_EDITOR &&
		test_must_fail shit commit -a -v 2>err
		shit_EDITOR=cat &&
		export shit_EDITOR &&
		test_must_fail shit -c core.commentchar=";" commit -a -v 2>err
		shit_EDITOR=cat &&
		export shit_EDITOR &&
		test_must_fail shit -c core.commentchar="foo>" commit -a -v >out 2>err
	shit status >actual &&
	! grep "^diff --shit" actual
		shit -c commit.verbose=$i commit --amend &&
		shit -c commit.verbose=$i commit --amend &&
		shit -c commit.verbose=$i commit --amend &&
		shit -c commit.verbose=$i commit --amend --verbose &&
		shit -c commit.verbose=$i commit --amend --no-verbose &&
		shit -c commit.verbose=$i commit --amend -v -v &&
	shit -c commit.verbose=true status >actual &&
	! grep "^diff --shit actual"