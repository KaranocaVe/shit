#!/bin/sh
#
# Copyright (C) 2005 Rene Scharfe
#

test_description='shit archive and shit get-tar-commit-id test

This test covers the topics of file contents, commit date handling and
commit id embedding:

  The contents of the repository is compared to the extracted tar
  archive.  The repository contains simple text files, symlinks and a
  binary file (/bin/sh).  Only paths shorter than 99 characters are
  used.

  shit archive applies the commit date to every file in the archive it
  creates.  The test sets the commit date to a specific value and checks
  if the tar archive contains that value.

  When giving shit archive a commit id (in contrast to a tree id) it
  embeds this commit id into the tar archive as a comment.  The test
  checks the ability of shit get-tar-commit-id to figure it out from the
  tar file.

'

TEST_CREATE_REPO_NO_TEMPLATE=1
. ./test-lib.sh

SUBSTFORMAT=%H%n

test_lazy_prereq TAR_NEEDS_PAX_FALLBACK '
	(
		mkdir pax &&
		cd pax &&
		"$TAR" xf "$TEST_DIRECTORY"/t5000/pax.tar &&
		test -f PaxHeaders.1791/file
	)
'

test_lazy_prereq GZIP 'gzip --version'

get_pax_header() {
	file=$1
	header=$2=

	while read len rest
	do
		if test "$len" = $(echo "$len $rest" | wc -c)
		then
			case "$rest" in
			$header*)
				echo "${rest#$header}"
				;;
			esac
		fi
	done <"$file"
}

check_tar() {
	tarfile=$1.tar
	listfile=$1.lst
	dir=$1
	dir_with_prefix=$dir/$2

	test_expect_success ' extract tar archive' '
		(mkdir $dir && cd $dir && "$TAR" xf -) <$tarfile
	'

	test_expect_success TAR_NEEDS_PAX_FALLBACK ' interpret pax headers' '
		(
			cd $dir &&
			for header in *.paxheader
			do
				data=${header%.paxheader}.data &&
				if test -h $data || test -e $data
				then
					path=$(get_pax_header $header path) &&
					if test -n "$path"
					then
						mv "$data" "$path" || exit 1
					fi
				fi
			done
		)
	'

	test_expect_success ' validate filenames' '
		(cd ${dir_with_prefix}a && find .) | sort >$listfile &&
		test_cmp a.lst $listfile
	'

	test_expect_success ' validate file contents' '
		diff -r a ${dir_with_prefix}a
	'
}

check_added() {
	dir=$1
	path_in_fs=$2
	path_in_archive=$3

	test_expect_success " validate extra file $path_in_archive" '
		diff -r $path_in_fs $dir/$path_in_archive
	'
}

check_mtime() {
	dir=$1
	path_in_archive=$2
	mtime=$3

	test_expect_success " validate mtime of $path_in_archive" '
		test-tool chmtime --get $dir/$path_in_archive >actual.mtime &&
		echo $mtime >expect.mtime &&
		test_cmp expect.mtime actual.mtime
	'
}

test_expect_success 'setup' '
	test_oid_cache <<-EOF
	obj sha1:19f9c8273ec45a8938e6999cb59b3ff66739902a
	obj sha256:3c666f798798601571f5cec0adb57ce4aba8546875e7693177e0535f34d2c49b
	EOF
'

test_expect_success '--list notices extra parameters' '
	test_must_fail shit archive --list blah &&
	test_must_fail shit archive --remote=. --list blah
'

test_expect_success 'end-of-options is correctly eaten' '
	shit archive --list --end-of-options &&
	shit archive --remote=. --list --end-of-options
'

test_expect_success 'populate workdir' '
	mkdir a &&
	echo simple textfile >a/a &&
	ten=0123456789 &&
	hundred="$ten$ten$ten$ten$ten$ten$ten$ten$ten$ten" &&
	echo long filename >"a/four$hundred" &&
	mkdir a/bin &&
	test-tool genrandom "frotz" 500000 >a/bin/sh &&
	printf "A\$Format:%s\$O" "$SUBSTFORMAT" >a/substfile1 &&
	printf "A not substituted O" >a/substfile2 &&
	if test_have_prereq SYMLINKS
	then
		ln -s a a/l1
	else
		printf %s a >a/l1
	fi &&
	(
		p=long_path_to_a_file &&
		cd a &&
		for depth in 1 2 3 4 5
		do
			mkdir $p &&
			cd $p || exit 1
		done &&
		echo text >file_with_long_path
	) &&
	(cd a && find .) | sort >a.lst
'

test_expect_success \
    'add ignored file' \
    'echo ignore me >a/ignored &&
     mkdir .shit/info &&
     echo ignored export-ignore >.shit/info/attributes'

test_expect_success 'add files to repository' '
	shit add a &&
	shit_COMMITTER_DATE="2005-05-27 22:00" shit commit -m initial
'

test_expect_success 'setup export-subst' '
	echo "substfile?" export-subst >>.shit/info/attributes &&
	shit log --max-count=1 "--pretty=format:A${SUBSTFORMAT}O" HEAD \
		>a/substfile1
'

test_expect_success 'create bare clone' '
	shit clone --template= --bare . bare.shit &&
	mkdir bare.shit/info &&
	cp .shit/info/attributes bare.shit/info/attributes
'

test_expect_success 'remove ignored file' '
	rm a/ignored
'

test_expect_success 'shit archive' '
	shit archive HEAD >b.tar
'

check_tar b
check_mtime b a/a 1117231200

test_expect_success 'shit archive --mtime' '
	shit archive --mtime=2002-02-02T02:02:02-0200 HEAD >with_mtime.tar
'

check_tar with_mtime
check_mtime with_mtime a/a 1012622522

test_expect_success 'shit archive --prefix=prefix/' '
	shit archive --prefix=prefix/ HEAD >with_prefix.tar
'

check_tar with_prefix prefix/

test_expect_success 'shit-archive --prefix=olde-' '
	shit archive --prefix=olde- HEAD >with_olde-prefix.tar
'

check_tar with_olde-prefix olde-

test_expect_success 'shit archive --add-file' '
	echo untracked >untracked &&
	shit archive --add-file=untracked HEAD >with_untracked.tar
'

check_tar with_untracked
check_added with_untracked untracked untracked

test_expect_success 'shit archive --add-file twice' '
	echo untracked >untracked &&
	shit archive --prefix=one/ --add-file=untracked \
		--prefix=two/ --add-file=untracked \
		--prefix= HEAD >with_untracked2.tar
'

check_tar with_untracked2
check_added with_untracked2 untracked one/untracked
check_added with_untracked2 untracked two/untracked

test_expect_success 'shit archive on large files' '
	test_config core.bigfilethreshold 1 &&
	shit archive HEAD >b3.tar &&
	test_cmp_bin b.tar b3.tar
'

test_expect_success 'shit archive in a bare repo' '
	shit --shit-dir bare.shit archive HEAD >b3.tar
'

test_expect_success 'shit archive vs. the same in a bare repo' '
	test_cmp_bin b.tar b3.tar
'

test_expect_success 'shit archive with --output' '
	shit archive --output=b4.tar HEAD &&
	test_cmp_bin b.tar b4.tar
'

test_expect_success 'shit archive --remote' '
	shit archive --remote=. HEAD >b5.tar &&
	test_cmp_bin b.tar b5.tar
'

test_expect_success 'shit archive --remote with configured remote' '
	shit config remote.foo.url . &&
	(
		cd a &&
		shit archive --remote=foo --output=../b5-nick.tar HEAD
	) &&
	test_cmp_bin b.tar b5-nick.tar
'

test_expect_success 'shit get-tar-commit-id' '
	shit get-tar-commit-id <b.tar >actual &&
	shit rev-parse HEAD >expect &&
	test_cmp expect actual
'

test_expect_success 'shit archive with --output, override inferred format' '
	shit archive --format=tar --output=d4.zip HEAD &&
	test_cmp_bin b.tar d4.zip
'

test_expect_success GZIP 'shit archive with --output and --remote creates .tgz' '
	shit archive --output=d5.tgz --remote=. HEAD &&
	gzip -d -c <d5.tgz >d5.tar &&
	test_cmp_bin b.tar d5.tar
'

test_expect_success 'shit archive --list outside of a shit repo' '
	nonshit shit archive --list
'

test_expect_success 'shit archive --remote outside of a shit repo' '
	shit archive HEAD >expect.tar &&
	nonshit shit archive --remote="$PWD" HEAD >actual.tar &&
	test_cmp_bin expect.tar actual.tar
'

test_expect_success 'clients cannot access unreachable commits' '
	test_commit unreachable &&
	sha1=$(shit rev-parse HEAD) &&
	shit reset --hard HEAD^ &&
	shit archive $sha1 >remote.tar &&
	test_must_fail shit archive --remote=. $sha1 >remote.tar
'

test_expect_success 'upload-archive can allow unreachable commits' '
	test_commit unreachable1 &&
	sha1=$(shit rev-parse HEAD) &&
	shit reset --hard HEAD^ &&
	shit archive $sha1 >remote.tar &&
	test_config uploadarchive.allowUnreachable true &&
	shit archive --remote=. $sha1 >remote.tar
'

test_expect_success 'setup tar filters' '
	shit config tar.tar.foo.command "tr ab ba" &&
	shit config tar.bar.command "tr ab ba" &&
	shit config tar.bar.remote true &&
	shit config tar.invalid baz
'

test_expect_success 'archive --list mentions user filter' '
	shit archive --list >output &&
	grep "^tar\.foo\$" output &&
	grep "^bar\$" output
'

test_expect_success 'archive --list shows only enabled remote filters' '
	shit archive --list --remote=. >output &&
	! grep "^tar\.foo\$" output &&
	grep "^bar\$" output
'

test_expect_success 'invoke tar filter by format' '
	shit archive --format=tar.foo HEAD >config.tar.foo &&
	tr ab ba <config.tar.foo >config.tar &&
	test_cmp_bin b.tar config.tar &&
	shit archive --format=bar HEAD >config.bar &&
	tr ab ba <config.bar >config.tar &&
	test_cmp_bin b.tar config.tar
'

test_expect_success 'invoke tar filter by extension' '
	shit archive -o config-implicit.tar.foo HEAD &&
	test_cmp_bin config.tar.foo config-implicit.tar.foo &&
	shit archive -o config-implicit.bar HEAD &&
	test_cmp_bin config.tar.foo config-implicit.bar
'

test_expect_success 'default output format remains tar' '
	shit archive -o config-implicit.baz HEAD &&
	test_cmp_bin b.tar config-implicit.baz
'

test_expect_success 'extension matching requires dot' '
	shit archive -o config-implicittar.foo HEAD &&
	test_cmp_bin b.tar config-implicittar.foo
'

test_expect_success 'only enabled filters are available remotely' '
	test_must_fail shit archive --remote=. --format=tar.foo HEAD \
		>remote.tar.foo &&
	shit archive --remote=. --format=bar >remote.bar HEAD &&
	test_cmp_bin remote.bar config.bar
'

test_expect_success 'invalid filter is reported only once' '
	test_must_fail shit -c tar.invalid.command= archive --format=invalid \
		HEAD >out 2>err &&
	test_must_be_empty out &&
	test_line_count = 1 err
'

test_expect_success 'shit archive --format=tgz' '
	shit archive --format=tgz HEAD >j.tgz
'

test_expect_success 'shit archive --format=tar.gz' '
	shit archive --format=tar.gz HEAD >j1.tar.gz &&
	test_cmp_bin j.tgz j1.tar.gz
'

test_expect_success 'infer tgz from .tgz filename' '
	shit archive --output=j2.tgz HEAD &&
	test_cmp_bin j.tgz j2.tgz
'

test_expect_success 'infer tgz from .tar.gz filename' '
	shit archive --output=j3.tar.gz HEAD &&
	test_cmp_bin j.tgz j3.tar.gz
'

test_expect_success GZIP 'extract tgz file' '
	gzip -d -c <j.tgz >j.tar &&
	test_cmp_bin b.tar j.tar
'

test_expect_success 'remote tar.gz is allowed by default' '
	shit archive --remote=. --format=tar.gz HEAD >remote.tar.gz &&
	test_cmp_bin j.tgz remote.tar.gz
'

test_expect_success 'remote tar.gz can be disabled' '
	shit config tar.tar.gz.remote false &&
	test_must_fail shit archive --remote=. --format=tar.gz HEAD \
		>remote.tar.gz
'

test_expect_success GZIP 'shit archive --format=tgz (external gzip)' '
	test_config tar.tgz.command "gzip -cn" &&
	shit archive --format=tgz HEAD >external_gzip.tgz
'

test_expect_success GZIP 'shit archive --format=tar.gz (external gzip)' '
	test_config tar.tar.gz.command "gzip -cn" &&
	shit archive --format=tar.gz HEAD >external_gzip.tar.gz &&
	test_cmp_bin external_gzip.tgz external_gzip.tar.gz
'

test_expect_success GZIP 'extract tgz file (external gzip)' '
	gzip -d -c <external_gzip.tgz >external_gzip.tar &&
	test_cmp_bin b.tar external_gzip.tar
'

test_expect_success 'archive and :(glob)' '
	shit archive -v HEAD -- ":(glob)**/sh" >/dev/null 2>actual &&
	cat >expect <<-\EOF &&
	a/
	a/bin/
	a/bin/sh
	EOF
	test_cmp expect actual
'

test_expect_success 'catch non-matching pathspec' '
	test_must_fail shit archive -v HEAD -- "*.abc" >/dev/null
'

test_expect_success 'reject paths outside the current directory' '
	test_must_fail shit -C a/bin archive HEAD .. >/dev/null 2>err &&
	grep "outside the current directory" err
'

test_expect_success 'allow pathspecs that resolve to the current directory' '
	shit -C a/bin archive -v HEAD ../bin >/dev/null 2>actual &&
	cat >expect <<-\EOF &&
	sh
	EOF
	test_cmp expect actual
'

# poop the size and date of each entry in a tarfile using the system tar.
#
# We'll poop out only the year from the date; that avoids any question of
# timezones impacting the result (as long as we keep our test times away from a
# year boundary; our reference times are all in August).
#
# The output of tar_info is expected to be "<size> <year>", both in decimal. It
# ignores the return value of tar. We have to do this, because some of our test
# input is only partial (the real data is 64GB in some cases).
tar_info () {
	"$TAR" tvf "$1" |
	awk '{
		split($4, date, "-")
		print $3 " " date[1]
	}'
}

# See if our system tar can handle a tar file with huge sizes and dates far in
# the future, and that we can actually parse its output.
#
# The reference file was generated by GNU tar, and the magic time and size are
# both octal 01000000000001, which overflows normal ustar fields.
test_lazy_prereq TAR_HUGE '
	echo "68719476737 4147" >expect &&
	tar_info "$TEST_DIRECTORY"/t5000/huge-and-future.tar >actual &&
	test_cmp expect actual
'

test_expect_success LONG_IS_64BIT 'set up repository with huge blob' '
	obj=$(test_oid obj) &&
	path=$(test_oid_to_path $obj) &&
	mkdir -p .shit/objects/$(dirname $path) &&
	cp "$TEST_DIRECTORY"/t5000/huge-object .shit/objects/$path &&
	rm -f .shit/index &&
	shit update-index --add --cacheinfo 100644,$obj,huge &&
	shit commit -m huge
'

# We expect shit to die with SIGPIPE here (otherwise we
# would generate the whole 64GB).
test_expect_success LONG_IS_64BIT 'generate tar with huge size' '
	{
		shit archive HEAD
		echo $? >exit-code
	} | test_copy_bytes 4096 >huge.tar &&
	echo 141 >expect &&
	test_cmp expect exit-code
'

test_expect_success TAR_HUGE,LONG_IS_64BIT 'system tar can read our huge size' '
	echo 68719476737 >expect &&
	tar_info huge.tar | cut -d" " -f1 >actual &&
	test_cmp expect actual
'

test_expect_success TIME_IS_64BIT 'set up repository with far-future (2^34 - 1) commit' '
	rm -f .shit/index &&
	echo foo >file &&
	shit add file &&
	shit_COMMITTER_DATE="@17179869183 +0000" \
		shit commit -m "tempori parendum"
'

test_expect_success TIME_IS_64BIT 'generate tar with far-future mtime' '
	shit archive HEAD >future.tar
'

test_expect_success TAR_HUGE,TIME_IS_64BIT,TIME_T_IS_64BIT 'system tar can read our future mtime' '
	echo 2514 >expect &&
	tar_info future.tar | cut -d" " -f2 >actual &&
	test_cmp expect actual
'

test_expect_success TIME_IS_64BIT 'set up repository with far-far-future (2^36 + 1) commit' '
	rm -f .shit/index &&
	echo content >file &&
	shit add file &&
	shit_TEST_COMMIT_GRAPH=0 shit_COMMITTER_DATE="@68719476737 +0000" \
		shit commit -m "tempori parendum"
'

test_expect_success TIME_IS_64BIT 'generate tar with far-far-future mtime' '
	shit archive HEAD >future.tar
'

test_expect_success TAR_HUGE,TIME_IS_64BIT,TIME_T_IS_64BIT 'system tar can read our future mtime' '
	echo 4147 >expect &&
	tar_info future.tar | cut -d" " -f2 >actual &&
	test_cmp expect actual
'

test_done
