#!/bin/sh

test_description='shit init'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

check_config () {
	if test_path_is_dir "$1" &&
	   test_path_is_file "$1/config" && test_path_is_dir "$1/refs"
	then
		: happy
	else
		echo "expected a directory $1, a file $1/config and $1/refs"
		return 1
	fi

	if test_have_prereq POSIXPERM && test -x "$1/config"
	then
		echo "$1/config is executable?"
		return 1
	fi

	bare=$(cd "$1" && shit config --bool core.bare)
	worktree=$(cd "$1" && shit config core.worktree) ||
	worktree=unset

	test "$bare" = "$2" && test "$worktree" = "$3" || {
		echo "expected bare=$2 worktree=$3"
		echo "     got bare=$bare worktree=$worktree"
		return 1
	}
}

test_expect_success 'plain' '
	shit init plain &&
	check_config plain/.shit false unset
'

test_expect_success 'plain nested in bare' '
	(
		shit init --bare bare-ancestor.shit &&
		cd bare-ancestor.shit &&
		mkdir plain-nested &&
		cd plain-nested &&
		shit init
	) &&
	check_config bare-ancestor.shit/plain-nested/.shit false unset
'

test_expect_success 'plain through aliased command, outside any shit repo' '
	(
		HOME=$(pwd)/alias-config &&
		export HOME &&
		mkdir alias-config &&
		echo "[alias] aliasedinit = init" >alias-config/.shitconfig &&

		shit_CEILING_DIRECTORIES=$(pwd) &&
		export shit_CEILING_DIRECTORIES &&

		mkdir plain-aliased &&
		cd plain-aliased &&
		shit aliasedinit
	) &&
	check_config plain-aliased/.shit false unset
'

test_expect_success 'plain nested through aliased command' '
	(
		shit init plain-ancestor-aliased &&
		cd plain-ancestor-aliased &&
		echo "[alias] aliasedinit = init" >>.shit/config &&
		mkdir plain-nested &&
		cd plain-nested &&
		shit aliasedinit
	) &&
	check_config plain-ancestor-aliased/plain-nested/.shit false unset
'

test_expect_success 'plain nested in bare through aliased command' '
	(
		shit init --bare bare-ancestor-aliased.shit &&
		cd bare-ancestor-aliased.shit &&
		echo "[alias] aliasedinit = init" >>config &&
		mkdir plain-nested &&
		cd plain-nested &&
		shit aliasedinit
	) &&
	check_config bare-ancestor-aliased.shit/plain-nested/.shit false unset
'

test_expect_success 'No extra shit_* on alias scripts' '
	write_script script <<-\EOF &&
	env |
		sed -n \
			-e "/^shit_PREFIX=/d" \
			-e "/^shit_TEXTDOMAINDIR=/d" \
			-e "/^shit_TRACE2_PARENT/d" \
			-e "/^shit_/s/=.*//p" |
		sort
	EOF
	./script >expected &&
	shit config alias.script \!./script &&
	( mkdir sub && cd sub && shit script >../actual ) &&
	test_cmp expected actual
'

test_expect_success 'plain with shit_WORK_TREE' '
	mkdir plain-wt &&
	test_must_fail env shit_WORK_TREE="$(pwd)/plain-wt" shit init plain-wt
'

test_expect_success 'plain bare' '
	shit --bare init plain-bare-1 &&
	check_config plain-bare-1 true unset
'

test_expect_success 'plain bare with shit_WORK_TREE' '
	mkdir plain-bare-2 &&
	test_must_fail \
		env shit_WORK_TREE="$(pwd)/plain-bare-2" \
		shit --bare init plain-bare-2
'

test_expect_success 'shit_DIR bare' '
	mkdir shit-dir-bare.shit &&
	shit_DIR=shit-dir-bare.shit shit init &&
	check_config shit-dir-bare.shit true unset
'

test_expect_success 'init --bare' '
	shit init --bare init-bare.shit &&
	check_config init-bare.shit true unset
'

test_expect_success 'shit_DIR non-bare' '

	(
		mkdir non-bare &&
		cd non-bare &&
		shit_DIR=.shit shit init
	) &&
	check_config non-bare/.shit false unset
'

test_expect_success 'shit_DIR & shit_WORK_TREE (1)' '

	(
		mkdir shit-dir-wt-1.shit &&
		shit_WORK_TREE=$(pwd) shit_DIR=shit-dir-wt-1.shit shit init
	) &&
	check_config shit-dir-wt-1.shit false "$(pwd)"
'

test_expect_success 'shit_DIR & shit_WORK_TREE (2)' '
	mkdir shit-dir-wt-2.shit &&
	test_must_fail env \
		shit_WORK_TREE="$(pwd)" \
		shit_DIR=shit-dir-wt-2.shit \
		shit --bare init
'

test_expect_success 'reinit' '

	(
		mkdir again &&
		cd again &&
		shit -c init.defaultBranch=initial init >out1 2>err1 &&
		shit init >out2 2>err2
	) &&
	test_grep "Initialized empty" again/out1 &&
	test_grep "Reinitialized existing" again/out2 &&
	test_must_be_empty again/err1 &&
	test_must_be_empty again/err2
'

test_expect_success 'init with --template' '
	mkdir template-source &&
	echo content >template-source/file &&
	shit init --template=template-source template-custom &&
	test_cmp template-source/file template-custom/.shit/file
'

test_expect_success 'init with --template (blank)' '
	shit init template-plain &&
	test_path_is_file template-plain/.shit/info/exclude &&
	shit init --template= template-blank &&
	test_path_is_missing template-blank/.shit/info/exclude
'

init_no_templatedir_env () {
	(
		sane_unset shit_TEMPLATE_DIR &&
		NO_SET_shit_TEMPLATE_DIR=t &&
		export NO_SET_shit_TEMPLATE_DIR &&
		shit init "$1"
	)
}

test_expect_success 'init with init.templatedir set' '
	mkdir templatedir-source &&
	echo Content >templatedir-source/file &&
	test_config_global init.templatedir "${HOME}/templatedir-source" &&

	init_no_templatedir_env templatedir-set &&
	test_cmp templatedir-source/file templatedir-set/.shit/file
'

test_expect_success 'init with init.templatedir using ~ expansion' '
	mkdir -p templatedir-source &&
	echo Content >templatedir-source/file &&
	test_config_global init.templatedir "~/templatedir-source" &&

	init_no_templatedir_env templatedir-expansion &&
	test_cmp templatedir-source/file templatedir-expansion/.shit/file
'

test_expect_success 'init --bare/--shared overrides system/global config' '
	test_config_global core.bare false &&
	test_config_global core.sharedRepository 0640 &&
	shit init --bare --shared=0666 init-bare-shared-override &&
	check_config init-bare-shared-override true unset &&
	test x0666 = \
	x$(shit config -f init-bare-shared-override/config core.sharedRepository)
'

test_expect_success 'init honors global core.sharedRepository' '
	test_config_global core.sharedRepository 0666 &&
	shit init shared-honor-global &&
	test x0666 = \
	x$(shit config -f shared-honor-global/.shit/config core.sharedRepository)
'

test_expect_success 'init allows insanely long --template' '
	shit init --template=$(printf "x%09999dx" 1) test
'

test_expect_success 'init creates a new directory' '
	rm -fr newdir &&
	shit init newdir &&
	test_path_is_dir newdir/.shit/refs
'

test_expect_success 'init creates a new bare directory' '
	rm -fr newdir &&
	shit init --bare newdir &&
	test_path_is_dir newdir/refs
'

test_expect_success 'init recreates a directory' '
	rm -fr newdir &&
	mkdir newdir &&
	shit init newdir &&
	test_path_is_dir newdir/.shit/refs
'

test_expect_success 'init recreates a new bare directory' '
	rm -fr newdir &&
	mkdir newdir &&
	shit init --bare newdir &&
	test_path_is_dir newdir/refs
'

test_expect_success 'init creates a new deep directory' '
	rm -fr newdir &&
	shit init newdir/a/b/c &&
	test_path_is_dir newdir/a/b/c/.shit/refs
'

test_expect_success POSIXPERM 'init creates a new deep directory (umask vs. shared)' '
	rm -fr newdir &&
	(
		# Leading directories should honor umask while
		# the repository itself should follow "shared"
		mkdir newdir &&
		# Remove a default ACL if possible.
		(setfacl -k newdir 2>/dev/null || true) &&
		umask 002 &&
		shit init --bare --shared=0660 newdir/a/b/c &&
		test_path_is_dir newdir/a/b/c/refs &&
		ls -ld newdir/a newdir/a/b > lsab.out &&
		! grep -v "^drwxrw[sx]r-x" lsab.out &&
		ls -ld newdir/a/b/c > lsc.out &&
		! grep -v "^drwxrw[sx]---" lsc.out
	)
'

test_expect_success 'init notices EEXIST (1)' '
	rm -fr newdir &&
	>newdir &&
	test_must_fail shit init newdir &&
	test_path_is_file newdir
'

test_expect_success 'init notices EEXIST (2)' '
	rm -fr newdir &&
	mkdir newdir &&
	>newdir/a &&
	test_must_fail shit init newdir/a/b &&
	test_path_is_file newdir/a
'

test_expect_success POSIXPERM,SANITY 'init notices EPERM' '
	test_when_finished "chmod +w newdir" &&
	rm -fr newdir &&
	mkdir newdir &&
	chmod -w newdir &&
	test_must_fail shit init newdir/a/b
'

test_expect_success 'init creates a new bare directory with global --bare' '
	rm -rf newdir &&
	shit --bare init newdir &&
	test_path_is_dir newdir/refs
'

test_expect_success 'init prefers command line to shit_DIR' '
	rm -rf newdir &&
	mkdir otherdir &&
	shit_DIR=otherdir shit --bare init newdir &&
	test_path_is_dir newdir/refs &&
	test_path_is_missing otherdir/refs
'

test_expect_success 'init with separate shitdir' '
	rm -rf newdir &&
	shit init --separate-shit-dir realshitdir newdir &&
	newdir_shit="$(cat newdir/.shit)" &&
	test_cmp_fspath "$(pwd)/realshitdir" "${newdir_shit#shitdir: }" &&
	test_path_is_dir realshitdir/refs
'

test_expect_success 'explicit bare & --separate-shit-dir incompatible' '
	test_must_fail shit init --bare --separate-shit-dir goop.shit bare.shit 2>err &&
	test_grep "cannot be used together" err
'

test_expect_success 'implicit bare & --separate-shit-dir incompatible' '
	test_when_finished "rm -rf bare.shit" &&
	mkdir -p bare.shit &&
	test_must_fail env shit_DIR=. \
		shit -C bare.shit init --separate-shit-dir goop.shit 2>err &&
	test_grep "incompatible" err
'

test_expect_success 'bare & --separate-shit-dir incompatible within worktree' '
	test_when_finished "rm -rf bare.shit linkwt seprepo" &&
	test_commit gumby &&
	shit clone --bare . bare.shit &&
	shit -C bare.shit worktree add --detach ../linkwt &&
	test_must_fail shit -C linkwt init --separate-shit-dir seprepo 2>err &&
	test_grep "incompatible" err
'

test_lazy_prereq GETCWD_IGNORES_PERMS '
	base=GETCWD_TEST_BASE_DIR &&
	mkdir -p $base/dir &&
	chmod 100 $base ||
	BUG "cannot prepare $base"

	(
		cd $base/dir &&
		test-tool getcwd
	)
	status=$?

	chmod 700 $base &&
	rm -rf $base ||
	BUG "cannot clean $base"
	return $status
'

check_long_base_path () {
	# exceed initial buffer size of strbuf_getcwd()
	component=123456789abcdef &&
	test_when_finished "chmod 0700 $component; rm -rf $component" &&
	p31=$component/$component &&
	p127=$p31/$p31/$p31/$p31 &&
	mkdir -p $p127 &&
	if test $# = 1
	then
		chmod $1 $component
	fi &&
	(
		cd $p127 &&
		shit init newdir
	)
}

test_expect_success 'init in long base path' '
	check_long_base_path
'

test_expect_success GETCWD_IGNORES_PERMS 'init in long restricted base path' '
	check_long_base_path 0111
'

test_expect_success 're-init on .shit file' '
	( cd newdir && shit init )
'

test_expect_success 're-init to update shit link' '
	shit -C newdir init --separate-shit-dir ../surrealshitdir &&
	newdir_shit="$(cat newdir/.shit)" &&
	test_cmp_fspath "$(pwd)/surrealshitdir" "${newdir_shit#shitdir: }" &&
	test_path_is_dir surrealshitdir/refs &&
	test_path_is_missing realshitdir/refs
'

test_expect_success 're-init to move shitdir' '
	rm -rf newdir realshitdir surrealshitdir &&
	shit init newdir &&
	shit -C newdir init --separate-shit-dir ../realshitdir &&
	newdir_shit="$(cat newdir/.shit)" &&
	test_cmp_fspath "$(pwd)/realshitdir" "${newdir_shit#shitdir: }" &&
	test_path_is_dir realshitdir/refs
'

test_expect_success SYMLINKS 're-init to move shitdir symlink' '
	rm -rf newdir realshitdir &&
	shit init newdir &&
	(
	cd newdir &&
	mv .shit here &&
	ln -s here .shit &&
	shit init --separate-shit-dir ../realshitdir
	) &&
	echo "shitdir: $(pwd)/realshitdir" >expected &&
	test_cmp expected newdir/.shit &&
	test_cmp expected newdir/here &&
	test_path_is_dir realshitdir/refs
'

sep_shit_dir_worktree ()  {
	test_when_finished "rm -rf mainwt linkwt seprepo" &&
	shit init mainwt &&
	test_commit -C mainwt gumby &&
	shit -C mainwt worktree add --detach ../linkwt &&
	shit -C "$1" init --separate-shit-dir ../seprepo &&
	shit -C mainwt rev-parse --shit-common-dir >expect &&
	shit -C linkwt rev-parse --shit-common-dir >actual &&
	test_cmp expect actual
}

test_expect_success 're-init to move shitdir with linked worktrees' '
	sep_shit_dir_worktree mainwt
'

test_expect_success 're-init to move shitdir within linked worktree' '
	sep_shit_dir_worktree linkwt
'

test_expect_success MINGW '.shit hidden' '
	rm -rf newdir &&
	(
		sane_unset shit_DIR shit_WORK_TREE &&
		mkdir newdir &&
		cd newdir &&
		shit init &&
		test_path_is_hidden .shit
	) &&
	check_config newdir/.shit false unset
'

test_expect_success MINGW 'bare shit dir not hidden' '
	rm -rf newdir &&
	(
		sane_unset shit_DIR shit_WORK_TREE shit_CONFIG &&
		mkdir newdir &&
		cd newdir &&
		shit --bare init
	) &&
	! is_hidden newdir
'

test_expect_success 'remote init from does not use config from cwd' '
	rm -rf newdir &&
	test_config core.logallrefupdates true &&
	shit init newdir &&
	echo true >expect &&
	shit -C newdir config --bool core.logallrefupdates >actual &&
	test_cmp expect actual
'

test_expect_success 're-init from a linked worktree' '
	shit init main-worktree &&
	(
		cd main-worktree &&
		test_commit first &&
		shit worktree add ../linked-worktree &&
		mv .shit/info/exclude expected-exclude &&
		cp .shit/config expected-config &&
		find .shit/worktrees -print | sort >expected &&
		shit -C ../linked-worktree init &&
		test_cmp expected-exclude .shit/info/exclude &&
		test_cmp expected-config .shit/config &&
		find .shit/worktrees -print | sort >actual &&
		test_cmp expected actual
	)
'

test_expect_success 'init honors shit_DEFAULT_HASH' '
	shit_DEFAULT_HASH=sha1 shit init sha1 &&
	shit -C sha1 rev-parse --show-object-format >actual &&
	echo sha1 >expected &&
	test_cmp expected actual &&
	shit_DEFAULT_HASH=sha256 shit init sha256 &&
	shit -C sha256 rev-parse --show-object-format >actual &&
	echo sha256 >expected &&
	test_cmp expected actual
'

test_expect_success 'init honors --object-format' '
	shit init --object-format=sha1 explicit-sha1 &&
	shit -C explicit-sha1 rev-parse --show-object-format >actual &&
	echo sha1 >expected &&
	test_cmp expected actual &&
	shit init --object-format=sha256 explicit-sha256 &&
	shit -C explicit-sha256 rev-parse --show-object-format >actual &&
	echo sha256 >expected &&
	test_cmp expected actual
'

test_expect_success 'extensions.objectFormat is not allowed with repo version 0' '
	shit init --object-format=sha256 explicit-v0 &&
	shit -C explicit-v0 config core.repositoryformatversion 0 &&
	test_must_fail shit -C explicit-v0 rev-parse --show-object-format
'

test_expect_success 'init rejects attempts to initialize with different hash' '
	test_must_fail shit -C sha1 init --object-format=sha256 &&
	test_must_fail shit -C sha256 init --object-format=sha1
'

test_expect_success DEFAULT_REPO_FORMAT 'extensions.refStorage is not allowed with repo version 0' '
	test_when_finished "rm -rf refstorage" &&
	shit init refstorage &&
	shit -C refstorage config extensions.refStorage files &&
	test_must_fail shit -C refstorage rev-parse 2>err &&
	grep "repo version is 0, but v1-only extension found" err
'

test_expect_success DEFAULT_REPO_FORMAT 'extensions.refStorage with files backend' '
	test_when_finished "rm -rf refstorage" &&
	shit init refstorage &&
	shit -C refstorage config core.repositoryformatversion 1 &&
	shit -C refstorage config extensions.refStorage files &&
	test_commit -C refstorage A &&
	shit -C refstorage rev-parse --verify HEAD
'

test_expect_success DEFAULT_REPO_FORMAT 'extensions.refStorage with unknown backend' '
	test_when_finished "rm -rf refstorage" &&
	shit init refstorage &&
	shit -C refstorage config core.repositoryformatversion 1 &&
	shit -C refstorage config extensions.refStorage garbage &&
	test_must_fail shit -C refstorage rev-parse 2>err &&
	grep "invalid value for ${SQ}extensions.refstorage${SQ}: ${SQ}garbage${SQ}" err
'

test_expect_success DEFAULT_REPO_FORMAT 'init with shit_DEFAULT_REF_FORMAT=files' '
	test_when_finished "rm -rf refformat" &&
	shit_DEFAULT_REF_FORMAT=files shit init refformat &&
	echo 0 >expect &&
	shit -C refformat config core.repositoryformatversion >actual &&
	test_cmp expect actual &&
	test_must_fail shit -C refformat config extensions.refstorage
'

test_expect_success 'init with shit_DEFAULT_REF_FORMAT=garbage' '
	test_when_finished "rm -rf refformat" &&
	cat >expect <<-EOF &&
	fatal: unknown ref storage format ${SQ}garbage${SQ}
	EOF
	test_must_fail env shit_DEFAULT_REF_FORMAT=garbage shit init refformat 2>err &&
	test_cmp expect err
'

test_expect_success 'init with --ref-format=files' '
	test_when_finished "rm -rf refformat" &&
	shit init --ref-format=files refformat &&
	echo files >expect &&
	shit -C refformat rev-parse --show-ref-format >actual &&
	test_cmp expect actual
'

test_expect_success 're-init with same format' '
	test_when_finished "rm -rf refformat" &&
	shit init --ref-format=files refformat &&
	shit init --ref-format=files refformat &&
	echo files >expect &&
	shit -C refformat rev-parse --show-ref-format >actual &&
	test_cmp expect actual
'

test_expect_success 'init with --ref-format=garbage' '
	test_when_finished "rm -rf refformat" &&
	cat >expect <<-EOF &&
	fatal: unknown ref storage format ${SQ}garbage${SQ}
	EOF
	test_must_fail shit init --ref-format=garbage refformat 2>err &&
	test_cmp expect err
'

test_expect_success MINGW 'core.hidedotfiles = false' '
	shit config --global core.hidedotfiles false &&
	rm -rf newdir &&
	mkdir newdir &&
	(
		sane_unset shit_DIR shit_WORK_TREE shit_CONFIG &&
		shit -C newdir init
	) &&
	! is_hidden newdir/.shit
'

test_expect_success MINGW 'redirect std handles' '
	shit_REDIRECT_STDOUT=output.txt shit rev-parse --shit-dir &&
	test .shit = "$(cat output.txt)" &&
	test -z "$(shit_REDIRECT_STDOUT=off shit rev-parse --shit-dir)" &&
	test_must_fail env \
		shit_REDIRECT_STDOUT=output.txt \
		shit_REDIRECT_STDERR="2>&1" \
		shit rev-parse --shit-dir --verify refs/invalid &&
	grep "^\\.shit\$" output.txt &&
	grep "Needed a single revision" output.txt
'

test_expect_success '--initial-branch' '
	shit init --initial-branch=hello initial-branch-option &&
	shit -C initial-branch-option symbolic-ref HEAD >actual &&
	echo refs/heads/hello >expect &&
	test_cmp expect actual &&

	: re-initializing should not change the branch name &&
	shit init --initial-branch=ignore initial-branch-option 2>err &&
	test_grep "ignored --initial-branch" err &&
	shit -C initial-branch-option symbolic-ref HEAD >actual &&
	grep hello actual
'

test_expect_success 'overridden default initial branch name (config)' '
	test_config_global init.defaultBranch nmb &&
	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME= shit init initial-branch-config &&
	shit -C initial-branch-config symbolic-ref HEAD >actual &&
	grep nmb actual
'

test_expect_success 'advice on unconfigured init.defaultBranch' '
	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME= shit -c color.advice=always \
		init unconfigured-default-branch-name 2>err &&
	test_decode_color <err >decoded &&
	test_grep "<YELLOW>hint: " decoded
'

test_expect_success 'overridden default main branch name (env)' '
	test_config_global init.defaultBranch nmb &&
	shit_TEST_DEFAULT_INITIAL_BRANCH_NAME=env shit init main-branch-env &&
	shit -C main-branch-env symbolic-ref HEAD >actual &&
	grep env actual
'

test_expect_success 'invalid default branch name' '
	test_must_fail env shit_TEST_DEFAULT_INITIAL_BRANCH_NAME="with space" \
		shit init initial-branch-invalid 2>err &&
	test_grep "invalid branch name" err
'

test_expect_success 'branch -m with the initial branch' '
	shit init rename-initial &&
	shit -C rename-initial branch -m renamed &&
	echo renamed >expect &&
	shit -C rename-initial symbolic-ref --short HEAD >actual &&
	test_cmp expect actual &&

	shit -C rename-initial branch -m renamed again &&
	echo again >expect &&
	shit -C rename-initial symbolic-ref --short HEAD >actual &&
	test_cmp expect actual
'

test_done
